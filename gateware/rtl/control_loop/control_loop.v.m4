m4_changequote(`⟨', `⟩')
m4_changecom(⟨/*⟩, ⟨*/⟩)
m4_define(generate_macro, ⟨m4_define(M4_$1, $2)⟩)
/* Copyright 2023 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */

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
m4_define(M4_CONSTS_WID, (CONSTS_WHOLE + CONSTS_FRAC))
	parameter DELAY_WID = 16,
	parameter READ_DAC_DELAY = 5,
	parameter CYCLE_COUNT_WID = 18,
	parameter DAC_WID = 24,
	/* Analog Devices DACs have a register code in the upper 4 bits.
	 * The data follows it. There may be some padding, but the length
	 * of a message is always 24 bits.
	 */
	parameter DAC_WID_SIZ = 5,
	parameter DAC_DATA_WID = 20,
m4_define(M4_E_WID, (DAC_DATA_WID + 1))
	parameter DAC_POLARITY = 0,
	parameter DAC_PHASE = 1,
	parameter DAC_CYCLE_HALF_WAIT = 10,
	parameter DAC_CYCLE_HALF_WAIT_SIZ = 4,
	parameter DAC_SS_WAIT = 5,
	parameter DAC_SS_WAIT_SIZ = 3
) (
	input clk,
	input rst_L,

	output dac_mosi,
	input dac_miso,
	output dac_ss_L,
	output dac_sck,

	input adc_miso,
	output adc_conv_L,
	output adc_sck,

	output in_loop,

	input assert_change,
	output reg change_made,

	input run_loop_in,
	input [ADC_WID-1:0] setpt_in,
	input [M4_CONSTS_WID-1:0] P_in,
	input [M4_CONSTS_WID-1:0] I_in,
	input [DELAY_WID-1:0] delay_in,

	output [CYCLE_COUNT_WID-1:0] cycle_count,
	output [DAC_DATA_WID-1:0] z_pos,
	output [ADC_WID-1:0] z_measured
);

/************ ADC and DAC modules ***************/

reg dac_arm;
reg dac_finished;
wire dac_ready_to_arm_unused;

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
	.rst_L(rst_L),
	.ready_to_arm(dac_ready_to_arm_unused),
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
assign z_measured = measured_value;
wire adc_ready_to_arm_unused;

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
	.ready_to_arm(adc_ready_to_arm_unused),
	.rst_L(rst_L),
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
 * start of each iteration (CYCLE_START).
 */

/* Setpoint: what should the ADC read */
reg signed [ADC_WID-1:0] setpt = 0;

/* Integral parameter */
reg signed [M4_CONSTS_WID-1:0] cl_I_reg = 0;

/* Proportional parameter */
reg signed [M4_CONSTS_WID-1:0] cl_p_reg = 0;

/* Delay parameter (to make the loop run slower) */
reg [DELAY_WID-1:0] dely = 0;

/************ Loop Control and Internal Parameters *************/

reg running = 0;

reg signed [DAC_DATA_WID-1:0] stored_dac_val = 0;
assign z_pos = stored_dac_val;

reg [CYCLE_COUNT_WID-1:0] last_timer = 0;
assign cycle_count = last_timer;
reg [CYCLE_COUNT_WID-1:0] counting_timer = 0;
reg [M4_CONSTS_WID-1:0] adjval_prev = 0;

reg signed [M4_E_WID-1:0] err_prev = 0;
wire signed [M4_E_WID-1:0] e_cur;
wire signed [M4_CONSTS_WID-1:0] adj_val;
wire signed [DAC_DATA_WID-1:0] new_dac_val;

reg arm_math = 0;
wire math_finished;
control_loop_math #(
	.CONSTS_WHOLE(CONSTS_WHOLE),
	.CONSTS_FRAC(CONSTS_FRAC),
	.CONSTS_SIZ(CONSTS_SIZ),
	.ADC_WID(ADC_WID),
	.DAC_WID(DAC_DATA_WID),
	.CYCLE_COUNT_WID(CYCLE_COUNT_WID)
) math (
	.clk(clk),
	.rst_L(rst_L),
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
	if (!rst_L) begin
		counting_timer <= 0;
		last_timer <= 0;
	end else if (state == CYCLE_START && timer == 0) begin
		counting_timer <= 1;
		last_timer <= counting_timer;
	end else if (running) begin
		counting_timer <= counting_timer + 1;
	end
end

assign in_loop = state != INIT_READ_FROM_DAC || running;

/* Reset the change acknowledge interface after the master
 * stops its transfer.
 *
 * The module only writes to change_made in the main always block
 * when state == CYCLE_START, so make sure that this does not
 * compete with CYCLE_START.
 */
always @ (posedge clk) begin
	if (state != CYCLE_START && !assert_change && change_made)
		change_made <= 0;
end

task reset_loop();
	to_dac <= 0;
	dac_arm <= 0;
	state <= INIT_READ_FROM_DAC;
	timer <= 0;
	stored_dac_val <= 0;
	setpt <= 0;
	dely <= 0;
	cl_I_reg <= 0;
	adjval_prev <= 0;
	err_prev <= 0;

	adc_arm <= 0;
	arm_math <= 0;
endtask

always @ (posedge clk) begin
	if (!rst_L) begin
		reset_loop();
	end else case (state)
	INIT_READ_FROM_DAC: begin
		if (run_loop_in) begin
			running <= 1;
			to_dac <= {1'b1, DAC_REGISTER, 20'b0};
			dac_arm <= 1;
			state <= WAIT_FOR_DAC_READ;
		end else begin
			reset_loop();
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
		if (!run_loop_in) begin
			reset_loop();
		end else if (timer < dely) begin
			timer <= timer + 1;
		end else begin
			/* On change of constants, previous values are invalidated. */
			if (assert_change && !change_made) begin
				change_made <= 1;

				setpt <= setpt_in;
				dely <= delay_in;
				cl_I_reg <= I_in;
				cl_p_reg <= P_in;
				adjval_prev <= 0;
				err_prev <= 0;
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
