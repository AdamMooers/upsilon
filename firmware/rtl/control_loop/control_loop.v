`include control_loop_cmds.vh
`define ERR_WID (ADC_WID + 1)

module control_loop
#(
	parameter ADC_WID = 18,
	/* Code assumes DAC_WID > ADC_WID. If/when this is not the
	 * case, truncation code must be changed.
	 */
	parameter DAC_WID = 24,
	/* Analog Devices DACs have a register code in the upper 4 bits.
	 * The data follows it. There may be some padding, but the length
	 * of a message is always 24 bits.
	 */
	parameter DAC_DATA_WID = 20,
	parameter CONSTS_WHOLE = 21,
	parameter CONSTS_FRAC = 43,
`define CONSTS_WID (CONSTS_WHOLE + CONSTS_FRAC)
	parameter DELAY_WID = 16,
	/* [ERR_WID_SIZ-1:0] must be able to store
	 * ERR_WID (= ADC_WID + 1).
	 */
	parameter ERR_WID_SIZ = 6,
`define DATA_WID `CONSTS_WID
`define E_WID (ADC_WID + 1)
	parameter READ_DAC_DELAY = 5,
	parameter CYCLE_COUNT_WID = 18
) (
	input clk,

	input signed [ADC_WID-1:0] measured_value,
	output adc_conv,
	output adc_arm,
	input adc_finished,

	output reg signed [DAC_WID-1:0] to_dac,
	input signed [DAC_WID-1:0] from_dac,
	output dac_ss,
	output dac_arm,
	input dac_finished,

	/* Hacky ad-hoc read-write interface. */
	input reg [CONTROL_LOOP_CMD_WIDTH-1:0] cmd,
	input reg [DATA_WIDTH-1:0] word_in,
	output reg [DATA_WIDTH-1:0] word_out,
	input start_cmd,
	output reg finish_cmd
);

/* The loop variables can be modified on the fly. Each
 * modification takes effect on the next loop cycle.
 * When a caller modifies a variable, the modified
 * variable is saved in [name]_buffer and loaded at CYCLE_START.
 */

reg signed [ADC_WID-1:0] setpt = 0;
reg signed [ADC_WID-1:0] setpt_buffer = 0;

reg signed [`CONSTS_WID-1:0] cl_I_reg = 0;
reg signed [`CONSTS_WID-1:0] cl_I_reg_buffer = 0;

reg signed [`CONSTS_WID-1:0] cl_p_reg = 0;
reg signed [`CONSTS_WID-1:0] cl_p_reg_buffer = 0;

reg [DELAY_WID-1:0] dely = 0;
reg [DELAY_WID-1:0] dely_buffer = 0;

reg running = 0;

reg signed [DAC_DATA_WID-1:0] stored_dac_val = 0;
reg [CYCLE_COUNT_WID-1:0] last_timer = 0;
reg [CYCLE_COUNT_WID-1:0] debug_timer = 0;
reg [`CONSTS_WID-1:0] adjval_prev = 0;

/* Misc. registers for PI calculations */
reg signed [`E_WID-1:0] err_prev = 0;
reg signed [`E_WID-1:0] e_cur = 0;
reg signed [`CONSTS_WID-1:0] adj_val = 0;

reg arm_math = 0;
reg math_finished = 0;
control_loop_math #(
	.CONSTS_WHOLE(CONSTS_WHOLE),
	.CONSTS_FRAC(CONSTS_FRAC),
	.CONSTS_SIZ(CONSTS_SIZ),
	.ADC_WID(ADC_WID),
	.CYCLE_COUNT_WID(CYCLE_COUNT_WID)
) math (
	.clk(clk),
	.arm(arm_math),
	.finished(math_finished),
	.setpt(setpt),
	.measured(measured_value),
	.cl_P(cl_p_reg),
	.cl_I(cl_I_reg),
	.cycles(last_timer),
	.e_prev(err_prev),
	.adjval_prev(adjval_prev),
	.e_cur(e_cur),
	.adj_val(adj_val)
);

/****** State machine
 * ┏━━━━━━━┓
 * ┃       ↓
 * ┗←━INITIATE_READ_FROM_DAC━━←━━━━┓
 *         ↓                       ┃
 *    WAIT_FOR_DAC_READ            ┃
 *         ↓                       ┃
 *    WAIT_FOR_DAC_RESPONSE        ┃ (on reset)
 *         ↓ (when value is read)  ┃
 * ┏━━CYCLE_START━━→━━━━━━━━━━━━━━━┛
 * ↑       ↓ (wait time delay)
 * ┃  WAIT_ON_ADC
 * ┃       ↓
 * ┃  WAIT_ON_MUL
 * ┃       ↓
 * ┃  WAIT_ON_DAC
 * ┃       ↓
 * ┗━━━━━━━┛
 ****** Outline
 * There are two systems: the read-write interface and the loop.
 * The read-write interface allows another module (i.e. the CPU)
 * to access and change constants. When a constant is changed the
 * loop must reset the values that are preserved between loops
 * (previous adjustment and previous delay).
 *
 * When the loop starts it must find the current value from the
 * DAC and write to it. The value from the DAC is then adjusted
 * with the output of the control loop. Afterwards it does not
 * need to query the DAC for the updated value since it was the one
 * that updated the value in the first place.
 */

localparam CYCLE_START = 0;
localparam WAIT_ON_ADC = 1;
localparam WAIT_ON_MATH = 2;
localparam INIT_READ_FROM_DAC = 3;
localparam WAIT_FOR_DAC_READ = 4;
localparam WAIT_FOR_DAC_RESPONSE = 5;
localparam STATESIZ = 3;

reg [STATESIZ-1:0] state = CYCLE_START;

reg [DELAY_WID-1:0] timer = 0;

/**** Timing. ****/
always @ (posedge clk) begin
	if (state == CYCLE_START) begin
		counting_timer <= 1;
		last_timer <= counting_timer;
	end else begin
		counting_timer <= counting_timer + 1;
	end
end

/**** Read-Write control interface.
 * `write_control` ensures that writes to the dirty bit do not happen when
 * the main loop is clearing the dirty bit.
 */

reg dirty_bit = 0;

always @ (posedge clk) begin
	if (start_cmd && !finish_cmd) begin
		case (cmd)
		CONTROL_LOOP_NOOP: CONTROL_LOOP_NOOP | CONTROL_LOOP_WRITE_BIT:
			finish_cmd <= 1;
		CONTROL_LOOP_STATUS: begin
			word_out[DATA_WID-1:1] <= 0;
			word_out[0] <= running;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_STATUS | CONTROL_LOOP_WRITE_BIT:
			if (write_control) begin
				running <= word_in[0];
				finish_cmd <= 1;
				dirty_bit <= 1;
			end
		CONTROL_LOOP_SETPT: begin
			word_out[DATA_WID-1:ADC_WID] <= 0;
			word_out[ADC_WID-1:0] <= setpt;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_SETPT | CONTROL_LOOP_WRITE_BIT:
			if (write_control) begin
				setpt_buffer <= word_in[ADC_WID-1:0];
				finish_cmd <= 1;
				dirty_bit <= 1;
			end
		CONTROL_LOOP_P: begin
			word_out <= cl_p_reg;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_P | CONTROL_LOOP_WRITE_BIT: begin
			if (write_control) begin
				cl_p_reg_buffer <= word_in;
				finish_cmd <= 1;
				dirty_bit <= 1;
			end
		end
		CONTROL_LOOP_ALPHA: begin
			word_out <= cl_alpha_reg;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_ALPHA | CONTROL_LOOP_WRITE_BIT: begin
			if (write_control) begin
				cl_alpha_reg_buffer <= word_in;
				finish_cmd <= 1;
				dirty_bit <= 1;
			end
		end
		CONTROL_LOOP_DELAY: begin
			word_out[DATA_WID-1:DELAY_WID] <= 0;
			word_out[DELAY_WID-1:0] <= dely;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_DELAY | CONTROL_LOOP_WRITE_BIT: begin
			if (write_control) begin
				dely_buffer <= word_in[DELAY_WID-1:0];
				finish_cmd <= 1;
				dirty_bit <= 1;
			end
		end
		CONTROL_LOOP_ERR: begin
			word_out[DATA_WID-1:ERR_WID] <= 0;
			word_out[ERR_WID-1:0] <= err_prev;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_Z: begin
			word_out[DATA_WID-1:DAC_DATA_WID] <= 0;
			word_out[DAC_DATA_WID-1:0] <= stored_dac_val;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_CYCLES: begin
			word_out[DATA_WID-1:CYCLE_COUNT_WID] <= 0;
			word_out[CYCLE_COUNT_WID-1:0] <= last_timer;
			finish_cmd <= 0;
		end
	end else if (!start_cmd) begin
		finish_cmd <= 0;
	end
end

always @ (posedge clk) begin
	case (state)
	INIT_READ_FROM_DAC: begin
		if (running) begin
			/* 1001[0....] is read from dac register */
			to_dac <= b'1001 << DAC_DATA_WID;
			dac_ss <= 1;
			dac_arm <= 1;
			state <= WAIT_FOR_DAC_READ;
		end
	end
	WAIT_FOR_DAC_READ: begin
		if (dac_finished) begin
			state <= WAIT_FOR_DAC_RESPONSE;
			dac_ss <= 0;
			dac_arm <= 0;
			timer <= 1;
		end
	end
	WAIT_FOR_DAC_RESPONSE: begin
		if (timer < READ_DAC_DELAY && timer != 0) begin
			timer <= timer + 1;
		end else if (timer == READ_DAC_DELAY) begin
			dac_ss <= 1;
			dac_arm <= 1;
			to_dac <= 0;
			timer <= 0;
		end else if (dac_finished) begin
			state <= CYCLE_START;
			dac_ss <= 0;
			dac_arm <= 0;
			stored_dac_val <= from_dac;
		end
	end
	CYCLE_START: begin
		if (!running) begin
			state <= INIT_READ_FROM_DAC;
		end else if (timer < dely) begin
			timer <= timer + 1;
		end else begin
			/* On change of constants, previous values are invalidated. */
			if (dirty_bit) begin
				setpt <= setpt_buffer;
				dely <= dely_buf;
				cl_alpha_reg <= cl_alpha_reg_buffer;
				cl_p_reg <= cl_p_reg_buffer;
				adj_prev <= 0;
				err_prev <= 0;

				dirty_bit <= 0;
			end

			state <= WAIT_ON_ADC;
			timer <= 0;
			adc_arm <= 1;
			adc_conv <= 1;
		end
	end
	WAIT_ON_ADC: if (adc_finished) begin
			adc_arm <= 0;
			adc_conv <= 0;
			arm_math <= 1;
			state <= WAIT_ON_MATH;
		end
	WAIT_ON_MATH: if (math_finished) begin
			arm_math <= 0;
			dac_arm <= 1;
			dac_ss <= 1;
			stored_dac_val <= (stored_dac_val + dac_adj_val);
			to_dac <= b'0001 << DAC_DATA_WID | (dac_adj_val + stored_dac_val);
			state <= WAIT_ON_DAC;
		end
	WAIT_ON_DAC: if (dac_finished) begin
			state <= CYCLE_START;
			dac_ss <= 0;
			dac_arm <= 0;

			err_prev <= err_cur;
			adj_old <= newadj;
		end
	end
end

endmodule
