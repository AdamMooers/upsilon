`include "control_loop_cmds.vh"

module control_loop
#(
	parameter ADC_WID = 18,
	parameter ADC_WID_SIZ = 5,
	parameter ADC_CYCLE_HALF_WAIT = 5,
	parameter ADC_CYCLE_HALF_WAIT_SIZ = 3,
	parameter ADC_POLARITY = 1,
	parameter ADC_PHASE = 0,
	/* The ADC takes maximum 527 ns to capture a value.
	 * The clock ticks at 10 ns. Change for different clocks!
	 */
	parameter ADC_CONV_WAIT = 53,
	parameter ADC_CONV_WAIT_SIZ = 6,

	parameter CONSTS_WHOLE = 21,
	parameter CONSTS_FRAC = 43,
	parameter CONSTS_SIZ = 7,
`define CONSTS_WID (CONSTS_WHOLE + CONSTS_FRAC)
	parameter DELAY_WID = 16,
`define DATA_WID `CONSTS_WID
	parameter READ_DAC_DELAY = 5,
	parameter CYCLE_COUNT_WID = 18,
	parameter DAC_WID = 24,
	/* Analog Devices DACs have a register code in the upper 4 bits.
	 * The data follows it. There may be some padding, but the length
	 * of a message is always 24 bits.
	 */
	parameter DAC_WID_SIZ = 5,
	parameter DAC_DATA_WID = 20,
`define E_WID (DAC_DATA_WID + 1)
	parameter DAC_POLARITY = 0,
	parameter DAC_PHASE = 1,
	parameter DAC_CYCLE_HALF_WAIT = 10,
	parameter DAC_CYCLE_HALF_WAIT_SIZ = 4,
	parameter DAC_SS_WAIT = 5,
	parameter DAC_SS_WAIT_SIZ = 3
) (
	input clk,

	output dac_mosi,
	input dac_miso,
	output dac_ss_L,
	output dac_sck,

	input adc_miso,
	output adc_conv_L,
	output adc_sck,

	/* Hacky ad-hoc read-write interface. */
	input [`CONTROL_LOOP_CMD_WIDTH-1:0] cmd,
	input [`DATA_WID-1:0] word_in,
	output reg [`DATA_WID-1:0] word_out,
	input start_cmd,
	output reg finish_cmd
);

/************ ADC and DAC modules ***************/

reg dac_arm;
reg dac_finished;

reg [DAC_WID-1:0] to_dac;
/* verilator lint_off UNUSED */
wire [DAC_WID-1:0] from_dac;
/* verilator lint_on UNUSED */
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

localparam [3-1:0] DAC_REGISTER = 3'b001;

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
	.ss_L(adc_conv_L),
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
reg [CYCLE_COUNT_WID-1:0] counting_timer = 0;
reg [`CONSTS_WID-1:0] adjval_prev = 0;

reg signed [`E_WID-1:0] err_prev = 0;
wire signed [`E_WID-1:0] e_cur;
wire signed [`CONSTS_WID-1:0] adj_val;
wire signed [DAC_DATA_WID-1:0] new_dac_val;

reg arm_math = 0;
wire math_finished;
control_loop_math #(
	.CONSTS_WHOLE(CONSTS_WHOLE),
	.CONSTS_FRAC(CONSTS_FRAC),
	.CONSTS_SIZ(CONSTS_SIZ),
	.ADC_WID(ADC_WID),
	.DAC_WID(DAC_DATA_WID),
	.CYCLE_COUNT_WID(CYCLE_COUNT_WID),
	.SEC_PER_CYCLE('b10101011110011000),
	.ADC_TO_DAC({32'b01000001100, 32'b01001001101110100101111000110101})
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
	.stored_dac_val(stored_dac_val),
	.new_dac_val(new_dac_val),
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
localparam WAIT_ON_DAC = 6;
localparam INIT_READ_FROM_DAC = 3;
localparam WAIT_FOR_DAC_READ = 4;
localparam WAIT_FOR_DAC_RESPONSE = 5;
localparam STATESIZ = 3;

reg [STATESIZ-1:0] state = INIT_READ_FROM_DAC;

reg [DELAY_WID-1:0] timer = 0;

/**** Timing. ****/
always @ (posedge clk) begin
	if (state == CYCLE_START && timer == 0) begin
		counting_timer <= 1;
		last_timer <= counting_timer;
	end else if (running) begin
		counting_timer <= counting_timer + 1;
	end
end

/**** Read-Write control interface.
 * `write_control` ensures that writes to the dirty bit do not happen when
 * the main loop is clearing the dirty bit.
 */

wire write_control = state == CYCLE_START || !running;
reg dirty_bit = 0;

always @ (posedge clk) begin
	if (start_cmd && !finish_cmd) begin
		case (cmd)
		`CONTROL_LOOP_NOOP:
			finish_cmd <= 1;
		`CONTROL_LOOP_NOOP | `CONTROL_LOOP_WRITE_BIT:
			finish_cmd <= 1;
		`CONTROL_LOOP_STATUS: begin
			word_out[`DATA_WID-1:1] <= 0;
			word_out[0] <= running;
			finish_cmd <= 1;
		end
		`CONTROL_LOOP_STATUS | `CONTROL_LOOP_WRITE_BIT:
			if (write_control) begin
				running <= word_in[0];
				finish_cmd <= 1;
				dirty_bit <= 1;
			end
		`CONTROL_LOOP_SETPT: begin
			word_out[`DATA_WID-1:ADC_WID] <= 0;
			word_out[ADC_WID-1:0] <= setpt;
			finish_cmd <= 1;
		end
		`CONTROL_LOOP_SETPT | `CONTROL_LOOP_WRITE_BIT:
			if (write_control) begin
				setpt_buffer <= word_in[ADC_WID-1:0];
				finish_cmd <= 1;
				dirty_bit <= 1;
			end
		`CONTROL_LOOP_P: begin
			word_out <= cl_p_reg;
			finish_cmd <= 1;
		end
		`CONTROL_LOOP_P | `CONTROL_LOOP_WRITE_BIT: begin
			if (write_control) begin
				cl_p_reg_buffer <= word_in;
				finish_cmd <= 1;
				dirty_bit <= 1;
			end
		end
		`CONTROL_LOOP_I: begin
			word_out <= cl_I_reg;
			finish_cmd <= 1;
		end
		`CONTROL_LOOP_I | `CONTROL_LOOP_WRITE_BIT: begin
			if (write_control) begin
				cl_I_reg_buffer <= word_in;
				finish_cmd <= 1;
				dirty_bit <= 1;
			end
		end
		`CONTROL_LOOP_DELAY: begin
			word_out[`DATA_WID-1:DELAY_WID] <= 0;
			word_out[DELAY_WID-1:0] <= dely;
			finish_cmd <= 1;
		end
		`CONTROL_LOOP_DELAY | `CONTROL_LOOP_WRITE_BIT: begin
			if (write_control) begin
				dely_buffer <= word_in[DELAY_WID-1:0];
				finish_cmd <= 1;
				dirty_bit <= 1;
			end
		end
		`CONTROL_LOOP_ERR: begin
			word_out[`DATA_WID-1:`E_WID] <= 0;
			word_out[`E_WID-1:0] <= err_prev;
			finish_cmd <= 1;
		end
		`CONTROL_LOOP_Z: begin
			word_out[`DATA_WID-1:DAC_DATA_WID] <= 0;
			word_out[DAC_DATA_WID-1:0] <= stored_dac_val;
			finish_cmd <= 1;
		end
		`CONTROL_LOOP_CYCLES: begin
			word_out[`DATA_WID-1:CYCLE_COUNT_WID] <= 0;
			word_out[CYCLE_COUNT_WID-1:0] <= last_timer;
			finish_cmd <= 0;
		end
		endcase
	end else if (!start_cmd) begin
		finish_cmd <= 0;
	end
end

always @ (posedge clk) begin
	case (state)
	INIT_READ_FROM_DAC: begin
		if (running) begin
			to_dac <= {1'b1, DAC_REGISTER, 20'b0};
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
			to_dac <= 24'b0;
			timer <= 0;
		end else if (dac_finished) begin
			state <= CYCLE_START;
			dac_arm <= 0;
			timer <= 0;
			stored_dac_val <= from_dac[DAC_DATA_WID-1:0];
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
				dely <= dely_buffer;
				cl_I_reg <= cl_I_reg_buffer;
				cl_p_reg <= cl_p_reg_buffer;
				adjval_prev <= 0;
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
			stored_dac_val <= new_dac_val;
			to_dac <= {1'b0, DAC_REGISTER, new_dac_val};
			state <= WAIT_ON_DAC;
		end
	WAIT_ON_DAC: if (dac_finished) begin
			state <= CYCLE_START;
			dac_arm <= 0;

			err_prev <= e_cur;
			adjval_prev <= adj_val;
		end
	endcase
end

endmodule
`undefineall
