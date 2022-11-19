`include control_loop_cmds.vh
`define ERR_WID (ADC_WID + 1)

module control_loop
#(
	parameter ADC_WID = 18,
	parameter ADC_WID_SIZ = 5,
	parameter ADC_CYCLE_HALF_WAIT = 1,
	parameter ADC_CYCLE_HALF_WAIT_SIZ = 1,
	parameter ADC_POLARITY = 1,
	parameter ADC_PHASE = 0,
	/* The ADC takes maximum 527 ns to capture a value.
	 * The clock ticks at 10 ns. Change for different clocks!
	 */
	parameter ADC_CONV_WAIT = 53,
	parameter ADC_CONV_WAIT_SIZ = 6,

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
	parameter CYCLE_COUNT_WID = 18,
	parameter DAC_WID = 24,
	/* Analog Devices DACs have a register code in the upper 4 bits.
	 * The data follows it. There may be some padding, but the length
	 * of a message is always 24 bits.
	 */
	parameter DAC_WID_SIZ = 5,
	parameter DAC_DATA_WID = 20,
	parameter DAC_POLARITY = 0,
	parameter DAC_PHASE = 1,
	parameter DAC_CYCLE_HALF_WAIT = 10,
	parameter DAC_CYCLE_HALF_WAIT_SIZ = 4,
	parameter DAC_SS_WAIT = 2,
	parameter DAC_SS_WAIT_SIZ = 3
) (
	input clk,

	output dac_mosi,
	input dac_miso,
	output dac_ss_L,
	output dac_sck,

	input adc_miso,
	output adc_conv,
	output adc_sck,

	/* Hacky ad-hoc read-write interface. */
	input reg [CONTROL_LOOP_CMD_WIDTH-1:0] cmd,
	input reg [DATA_WIDTH-1:0] word_in,
	output reg [DATA_WIDTH-1:0] word_out,
	input start_cmd,
	output reg finish_cmd
);

/************ ADC and DAC modules ***************/

reg dac_arm;
reg dac_finished;
reg [DAC_WID-1:0] to_dac;
wire [DAC_WID-1:0] from_dac;
spi_master_ss #(
	.WID(DAC_WID),
	.WID_LEN(DAC_WID_SIZ),
	.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
	.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
	.POLARITY(DAC_POLARITY),
	.PHASE(DAC_PHASE),
	.SS_WAIT(DAC_SS_WAIT),
	.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
) dac_master (
	.clk(clk),
	.arm(dac_arm),
	.mosi(dac_mosi),
	.miso(dac_miso),
	.sck_wire(dac_sck),
	.ss_L(dac_ss_L),
	.finished(dac_finished),
	.arm(dac_arm),
	.from_slave(from_dac),
	.to_slave(to_dac)
);

reg adc_arm;
reg adc_finished;
wire [ADC_WID-1:0] measured_value;

localparam [3-1:0] DAC_REGISTER = 3b'001;

spi_master_ss_no_write #(
	.WID(ADC_WID),
	.WID_LEN(ADC_WID_SIZ),
	.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
	.TIMER_LEN(ADC_CYCLE_HALF_WAIT_SIZ),
	.POLARITY(ADC_POLARITY),
	.PHASE(ADC_PHASE),
	.SS_WAIT(ADC_CONV_WAIT),
	.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ)
) adc_master (
	.clk(clk),
	.arm(adc_arm),
	.from_slave(measured_value),
	.miso(adc_miso),
	.sck_wire(adc_sck),
	.ss_L(!ss_conv),
	.finished(adc_finished)
);

/***************** PI Parameters *****************
 * Parameters can be adjusted on the fly by the user. The modifications
 * cannot happen during a calculation, but calculations occur in a matter
 * of milliseconds. Instead, modifications are checked and applied at the
 * start of each iteration (CYCLE_START). Before this, the new values
 * have to be buffered.
 */

/* Setpoint: what should the ADC read */
reg signed [ADC_WID-1:0] setpt = 0;
reg signed [ADC_WID-1:0] setpt_buffer = 0;

/* Integral parameter */
reg signed [`CONSTS_WID-1:0] cl_I_reg = 0;
reg signed [`CONSTS_WID-1:0] cl_I_reg_buffer = 0;

/* Proportional parameter */
reg signed [`CONSTS_WID-1:0] cl_p_reg = 0;
reg signed [`CONSTS_WID-1:0] cl_p_reg_buffer = 0;

/* Delay parameter (to make the loop run slower) */
reg [DELAY_WID-1:0] dely = 0;
reg [DELAY_WID-1:0] dely_buffer = 0;

/************ Loop Control and Internal Parameters *************/

reg running = 0;

reg signed [DAC_DATA_WID-1:0] stored_dac_val = 0;
reg [CYCLE_COUNT_WID-1:0] last_timer = 0;
reg [CYCLE_COUNT_WID-1:0] debug_timer = 0;
reg [`CONSTS_WID-1:0] adjval_prev = 0;

reg signed [`E_WID-1:0] err_prev = 0;
wire signed [`E_WID-1:0] e_cur = 0;
wire signed [`CONSTS_WID-1:0] adj_val = 0;

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

wire write_control = state == CYCLE_START;
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
		CONTROL_LOOP_I: begin
			word_out <= cl_I_reg;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_I | CONTROL_LOOP_WRITE_BIT: begin
			if (write_control) begin
				cl_I_reg_buffer <= word_in;
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
			to_dac <= {1, DAC_REGISTER, 20b'0};
			dac_arm <= 1;
			state <= WAIT_FOR_DAC_READ;
		end
	end
	WAIT_FOR_DAC_READ: begin
		if (dac_finished) begin
			state <= WAIT_FOR_DAC_RESPONSE;
			dac_arm <= 0;
			timer <= 1;
		end
	end
	WAIT_FOR_DAC_RESPONSE: begin
		if (timer < READ_DAC_DELAY && timer != 0) begin
			timer <= timer + 1;
		end else if (timer == READ_DAC_DELAY) begin
			dac_arm <= 1;
			to_dac <= 24b'0;
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
		end
	end
	WAIT_ON_ADC: if (adc_finished) begin
			adc_arm <= 0;
			arm_math <= 1;
			state <= WAIT_ON_MATH;
		end
	WAIT_ON_MATH: if (math_finished) begin
			arm_math <= 0;
			dac_arm <= 1;
			stored_dac_val <= (stored_dac_val + adj_val[`CONSTS_WID-1:CONSTS_FRAC]);
			to_dac <= {0, DAC_REGISTER, (dac_adj_val + adj_val[`CONSTS_WID-1:CONSTS_FRAC]);
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
