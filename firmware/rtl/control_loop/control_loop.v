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
	 * The data follows it.
	 */
	parameter DAC_DATA_WID = 20,
	parameter CONSTS_WID = 48, // larger than ADC_WID
	parameter CONSTS_FRAC_WID = CONSTS_WID-15,
	parameter DELAY_WID = 16,
	/* [ERR_WID_SIZ-1:0] must be able to store
	 * ERR_WID (ADC_WID + 1).
	 */
	parameter ERR_WID_SIZ = 6,
	parameter DATA_WID = CONSTS_WID,
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

reg signed [CONSTS_WID-1:0] cl_alpha_reg = 0;
reg signed [CONSTS_WID-1:0] cl_alpha_reg_buffer = 0;

reg signed [CONSTS_WID-1:0] cl_p_reg = 0;
reg signed [CONSTS_WID-1:0] cl_p_reg_buffer = 0;

reg [DELAY_WID-1:0] dely = 0;
reg [DELAY_WID-1:0] dely_buffer = 0;

reg running = 0;
reg signed[DAC_DATA_WID-1:0] stored_dac_val = 0;

/* Registers for PI calculations */
reg signed [ERR_WID-1:0] err_prev = 0;

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
localparam WAIT_ON_MUL = 2;
localparam WAIT_ON_DAC = 3;
localparam INIT_READ_FROM_DAC = 4;
localparam WAIT_FOR_DAC_READ = 5;
localparam WAIT_FOR_DAC_RESPONSE = 6;
localparam STATESIZ = 3;

reg [STATESIZ-1:0] state = INIT_READ_FROM_DAC;

/**** Precision Propogation
 *
 *    Measured value: ADC_WID.0
 *    Setpoint: ADC_WID.0
 * - ----------------------------|
 *      e_unsc: ERR_WID.0
 *  x   78e-6: 0.CONSTS_FRAC
 * - ----------------------------|
 *      e_uncropped: ERR_WID.CONSTS_FRAC
 * -------------------------------------
 *      e: CONSTS_WID.CONSTS_FRAC
 *
 *
 *   α: CONSTS_WHOLE.CONSTS_FRAC |         P: CONSTS_WHOLE.CONSTS_FRAC
 *   e: ERR_WID.0                |         e_p: ERR_WID.0
 * x ----------------------------|        x-----------------------------
 *   αe: CONSTS_WHOLE+ERR_WID.CONSTS_FRAC  -   Pe_p: CONSTS_WHOLE+ERR_WID.CONSTS_FRAC
 *              + A_p: CONSTS_WHOLE+ERR_WID.CONSTS_FRAC
 *              + stored_dac_val << CONSTS_FRAC: DAC_DATA_WID.CONSTS_FRAC
 * --------------------------------------------------------------
 *   A_p + αe - Pe_p + stored_dac_val: CONSTS_WHOLE+ERR_WID+1.CONSTS_FRAC
 *   --> discard fractional bits: CONSTS_WHOLE+ADC_WID+1.(DAC_DATA_WID - ADC_WID)
 *   --> Saturate-truncate: ADC_WID.(DAC_DATA_WID-ADC_WID)
 *   --> reinterpret and write into DAC: DAC_DATA_WID.0
 */

/**** Calculate Error ****/
wire [ERR_WID-1:0] e_unsc = measured_value - setpoint;

/**** convert error value to real value ****/

wire [ERR_WID+CONSTS_FRAC-1:0] e_uncrop;
reg mul_scale_err_fin = 0;

boothmul #(
	.A1_LEN(ERR_WID),
	.A2_LEN(CONSTS_FRAC)
) mul_scale_err (
	.clk(clk),
	.arm(arm_err_scale),
	.a1(e_unsc),
	.a2(adc_int_to_real),
	.outn(e_uncrop),
	.fin(mul_scale_err_fin)
);

wire [CONSTS_WID-1:0] e;

intsat #(
	.A1_LEN(ERR_WID + CONSTS_FRAC),
	.A2_LEN(CONSTS_WID)
) mul_scale_err_crop (
	.inp(e_uncrop),
	.outp(e)
);

/****** Multiplication *******
 * Truncation of a fixed-point integer to a smaller buffer requires
 * 1) truncating higher order bits
 * 2) removing lower order bits
 *
 * The ADC number has no fractional digits, so the fixed point output
 * is [CONSTS_WHOLE + ERR_WID].CONSTS_FRAC_WID
 * with total width CONSTS_WID + ERR_WID
 *
 * Both multipliers are armed at the same time.
 * Their output wires are ANDed together so the state machine
 * progresses when both are finished.
 */

localparam MUL_WHOLE_WID = CONSTS_WHOLE + ERR_WID;
localparam MUL_FRAC_WID = CONSTS_FRAC;
localparam MUL_WID = MUL_WHOLE_WID + MUL_FRAC_WID;

reg arm_mul = 0;

wire alpha_err_fin;
wire signed [MUL_WID-1:0] alpha_err;
wire p_err_prev_fin;
wire signed [MUL_WID-1:0] p_err_prev;

wire mul_finished = alpha_err_fin & p_err_fin;

/* αe */
boothmul #(
	.A1_LEN(CONSTS_WID),
	.A2_LEN(ERR_WID),
	.A2LEN_SIZ(ERR_WID_SIZ)
) boothmul_alpha_err_mul (
	.clk(clk),
	.arm(arm_mul),
	.a1(cl_alpha_reg),
	.a2(err),
	.outn(alpha_err),
	.fin(alpha_err_fin)
);

/* Pe_p */
boothmul #(
	.A1_LEN(CONSTS_WID),
	.A2_LEN(ERR_WID),
	.A2LEN_SIZ(ERR_WID_SIZ)
) booth_mul_P_err_mul (
	.clk(clk),
	.arm(arm_mul),
	.a1(cl_p_reg),
	.a2(err_prev),
	.outn(p_err_prev),
	.fin(p_err_prev_fin)
);

/**** Subtraction after multiplication ****/
localparam SUB_WHOLE_WID = MUL_WHOLE_WID + 1;
localparam SUB_FRAC_WID = MUL_FRAC_WID;
localparam SUB_WID = SUB_WHOLE_WID + SUB_FRAC_WID;

reg signed [SUB_WID-1:0] adj_old = 0;
wire signed [SUB_WID-1:0] newadj = adj_old + alpha_err - p_err_prev
                                 + (stored_dac_val << CONSTS_FRAC);

/**** Discard fractional bits ****
 * The truncation of the subtraction result first takes off the lower
 * order bits:
 * [      SUB_WHOLE_WID      ].[        SUB_FRAC_WID       ]
 * [      SUB_WHOLE_WID      ].[RTRUNC_FRAC_WID]############
 *                         (SUB_FRAC_WID - RTRUNC_FRAC_WID)^
 */

localparam RTRUNC_FRAC_WID = DAC_DATA_WID - ADC_WID;
localparam RTRUNC_WHOLE_WID = SUB_WHOLE_WID;
localparam RTRUNC_WID = RTRUNC_WHOLE_WID + RTRUNC_FRAC_WID;

wire signed[RTRUNC_WID-1:0] rtrunc =
	newadj[SUB_WID-1:SUB_FRAC_WID-RTRUNC_FRAC_WID];

/**** Truncate-Saturate ****
 * Truncate the result into a value acceptable to the DAC.
 * [      SUB_WHOLE_WID      ].[RTRUNC_FRAC_WID]############
 *         [ADC_WID].[DAC_DATA_WID - ADC_WID]
 *         reinterpreted as
 *         [DAC_DATA_WID].0
 */

wire signed[DAC_DATA_WID-1:0] dac_adj_val;

intsat #(
	.IN_LEN(RTRUNC_WID),
	.LTRUNC(DAC_DATA_WID)
) sat_newadj_rtrunc (
	.inp(rtrunc),
	.outp(dac_adj_val)
);

reg [DELAY_WID-1:0] timer = 0;

reg [CYCLE_COUNT_WID-1:0] last_timer = 0;
reg [CYCLE_COUNT_WID-1:0] debug_timer = 0;
/**** Timing debug. ****/
always @ (posedge clk) begin
	if (state == INIT_READ_FROM_DAC) begin
		debug_timer <= 1;
		last_timer <= debug_timer;
	end else begin
		debug_timer <= debug_timer + 1;
	end
end

/**** Read-Write control interface. ****/

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
			running <= word_in[0];
			finish_cmd <= 1;
		CONTROL_LOOP_SETPT: begin
			word_out[DATA_WID-1:ADC_WID] <= 0;
			word_out[ADC_WID-1:0] <= setpt;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_SETPT | CONTROL_LOOP_WRITE_BIT:
			setpt_buffer <= word_in[ADC_WID-1:0];
			finish_cmd <= 1;
		CONTROL_LOOP_P: begin
			word_out <= cl_p_reg;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_P | CONTROL_LOOP_WRITE_BIT: begin
			cl_p_reg_buffer <= word_in;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_ALPHA: begin
			word_out <= cl_alpha_reg;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_ALPHA | CONTROL_LOOP_WRITE_BIT: begin
			cl_alpha_reg_buffer <= word_in;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_DELAY: begin
			word_out[DATA_WID-1:DELAY_WID] <= 0;
			word_out[DELAY_WID-1:0] <= dely;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_DELAY | CONTROL_LOOP_WRITE_BIT: begin
			dely_buffer <= word_in[DELAY_WID-1:0];
			finish_cmd <= 1;
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

/* This is not a race condition as long as two variables are
 * not being assigned at the same time. Instead, the lower
 * assign block will use the older values (i.e. the upper assign
 * block only takes effect next clock cycle).
 */

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
			if (setpt != setpt_buffer ||
			  cl_alpha_reg != cl_alpha_reg_buffer ||
			  cl_p_reg != cl_p_reg_buffer) begin
				setpt <= setpt_buffer;
				dely <= dely_buf;
				cl_alpha_reg <= cl_alpha_reg_buffer;
				cl_p_reg <= cl_p_reg_buffer;
				adj_prev <= 0;
				err_prev <= 0;
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
			arm_mul <= 1;
			state <= WAIT_ON_MUL;
		end
	WAIT_ON_MUL: if (mul_finished) begin
			arm_mul <= 0;
			dac_arm <= 1;
			dac_ss <= 1;
			stored_dac_val <= dac_adj_val;
			to_dac <= b'0001 << DAC_DATA_WID | dac_adj_val;
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
