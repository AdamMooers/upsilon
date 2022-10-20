/************ Introduction to PI Controllers
 * The continuous form of a PI loop is
 *
 *   A(t) = P e(t) + I ∫e(t')dt'
 * where e(t) is the error (setpoint - measured), and
 * the integral goes from 0 to the current time 't'.
 *
 * In digital systems the integral must be approximated.
 * The normal way of doing this is a first-order approximation
 * of the derivative of A(t).
 *
 *   dA(t)/dt = P de(t)/dt + Ie(t)
 *   A(t_n) - A(t_{n-1}) ≅ P (e(t_n) - e(t_{n-1})) + Ie(t_n)Δt
 *   A(t_n) ≅ A(t_{n-1}) + e(t_n)(P + IΔt) - Pe(t_{n-1})
 *
 * Using α = P + IΔt, and denoting A(t_{n-1}) as A_p,
 *
 *   A ≅ A_p + αe - Pe_p.
 *
 * The formula above is what this module implements. This way,
 * the controller only has to store two values between each
 * run of the loop: the previous error and the previous output.
 * This also reduces the amount of (redundant) computations
 * the loop must execute each iteration.
 *
 * Calculating α requires knowing the precise timing of each
 * control loop cycle, which in turn requires knowing the
 * ADC and DAC timings. This is done outside the Verilog code.
 * and can be calculated from simulating one iteration of the
 * control loop.
 *
 *************** Fixed Point Integers *************
 * A regular number is stored in decimal: 123056.
 * This is equal to
 *  6*10^0 + 5*10^1 + 0*10^2 + 3*10^3 + 2*10^4 + 1*10^5.
 * A whole binary number is only ones and zeros: 1101, and is
 * equal to
 *  1*2^0 + 0*2^1 + 1*2^2 + 1*2^3.
 *
 * Fixed-point integers shift the exponent of each number by a
 * fixed amount. For instance, 123.056 is
 * 6*10^-3 + 5*10^-2 + 0*10^-1 + 3*10^0 + 2*10^1 + 1*10^2.
 * Similarly, the fixed point binary integer 11.01 is
 * 1*2^-2 + 0*2^-1 + 1*2^0 + 1*2^1.
 *
 * To a computer, a whole binary number and a fixed point binary
 * number are stored in exactly the same way: no decimal point
 * is stored. It is only the *interpretation* of the data that
 * changes.
 *
 * Fixed point numbers are denoted WHOLE.FRAC or [WHOLE].[FRAC],
 * where WHOLE is the amount of whole number bits (including sign)
 * and FRAC is the amount of fractional bits (2^-1, 2^-2, etc.).
 *
 * The rules for how many digits the output has given an input
 * is the same for fixed point binary and regular decimals.
 *
 *  Addition: W1.F1 + W2.F2 = [max(W1,W2)+1].[max(F1,F2)]
 *  Multiplication: W1.F1 * W2.F2 = [W1+W2].[F1+F2]
 *
 *************** Precision **************
 * The control loop is designed around these values, but generally
 * does not hardcode them.
 *
 * Since α and P are precalculated outside of the loop, their
 * conversion to numbers the loop understands is done outside of
 * the loop and in the kernel.
 *
 * The 18-bit ADC is twos-compliment, -10.24V to 10.24V,
 * with 78μV per increment.
 * The 20-bit DAC is twos-compliment, -10V to 10V.
 *
 * The `P` constant has a minimum value of 1e-7 with a precision
 * of 1e-9, and a maxmimum value of 1.
 *
 * The `I` constant has a minimum value of 1e-4 with a precision
 * of 1e-6 and a maximum value of 100.
 *
 * Δt is cycles/100MHz. This makes Δt at least 10 ns, with a
 * maximum of 1 ms.
 *
 * Intermediate values are 48-bit fixed-point integers multiplied
 * by the step size of the ADC. The first 18 bits are the whole
 * number and sign bits. This means intermediate values correspond
 * exactly to values as understood by the ADC, with extra precision.
 *
 * To get the normal fixed-point value of an intermediate value,
 * multiply it by 78e-6. To convert a normal fixed-point integer
 * to an intermediate value, multiply it by 1/78e-6. In both
 * cases, the conversion constant is a normal fixed-point integer.
 *
 * For instance, to encode the value 78e-6 as an intermediate
 * value, multiply it by 1/78e-6 to obtain 1. Thus the value
 * should be stored as 1 (whole bit) followed by zeros (fractional
 * bits).
 */

/*
 * 0x3214*78e-6 = 0.9996 + lower order (storable as 15 whole bits)
 */

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
	parameter READ_DAC_DELAY = 5
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

reg signed [ADC_WID-1:0] setpt = 0;
reg signed [CONSTS_WID-1:0] cl_alpha_reg = 0;
reg signed [CONSTS_WID-1:0] cl_p_reg = 0;
reg [DELAY_WID-1:0] saved_delay = 0;
reg running = 0;

/* Registers for PI calculations */
reg signed [ERR_WID-1:0] err_prev = 0;

/****** State machine
 *
 *    INITIATE_READ_FROM_DAC
 *         ↓
 *    WAIT_FOR_DAC_READ
 *         ↓
 *    WAIT_FOR_DAC_RESPONSE
 *         ↓ (when value is read)
 * ┏━━CYCLE_START
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
 * loop must reset.
 */

localparam CYCLE_START = 0;
localparam WAIT_ON_ADC = 1;
localparam WAIT_ON_MUL = 2;
localparam WAIT_ON_DAC = 3;
localparam INIT_READ_FROM_DAC = 4;
localparam WAIT_FOR_DAC_READ = 5;
localparam WAIT_FOR_DAC_RESPONSE = 6;
localparam STATESIZ = 3;

reg [STATESIZ-1:0] state = WAIT_ON_ARM;

/**** Precision Propogation
 *
 *    Measured value: ADC_WID.0
 *    Setpoint: ADC_WID.0
 * - ----------------------------|
 *      e: ERR_WID.0
 *
 *   α: CONSTS_WHOLE.CONSTS_FRAC |         P: CONSTS_WHOLE.CONSTS_FRAC
 *   e: ERR_WID.0                |         e_p: ERR_WID.0
 * x ----------------------------|        x-----------------------------
 *   αe: CONSTS_WHOLE+ERR_WID.CONSTS_FRAC  -   Pe_p: CONSTS_WHOLE+ERR_WID.CONSTS_FRAC
 *              + A_p: CONSTS_WHOLE+ERR_WID.CONSTS_FRAC
 * --------------------------------------------------------------
 *   A_p + αe - Pe_p: CONSTS_WHOLE+ERR_WID+1.CONSTS_FRAC
 *   --> discard fractional bits: CONSTS_WHOLE+ADC_WID+1.(DAC_DATA_WID - ADC_WID)
 *   --> Saturate-truncate: ADC_WID.(DAC_DATA_WID-ADC_WID)
 *   --> reinterpret and write into DAC: DAC_DATA_WID.0
 */

/**** Calculate Error ****/
wire [ERR_WID-1:0] err_cur = measured_value - setpoint;

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
wire signed [SUB_WID-1:0] newadj = adj_old + alpha_err - p_err_prev;

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
	.inp(newadj_rtrunc),
	.outp(dac_adj_val)
);

reg signed[DAC_DATA_WID-1:0] stored_dac_val;

wire [DAC_DATA_WID:0] total_dac_val_add = stored_dac_val + dac_adj_val;
wire [DAC_DATA_WID-1:0] total_dac_val;

intsat #(
	.IN_LEN(DAC_DATA_WID),
	.LTRUNC(1)
) total_dac_trunc (
	.inp(total_dac_val_add),
	.outp(total_dac_val)
);

/**** Write to DAC ****/

reg [DELAY_WID-1:0] timer = 0;
/* Reset is asserted when any change happens to the inputs.
 * It is deasserted when the input pin is deasserted.
 * This always takes at least 1 cycle so the loop will
 * always halt.
 */
reg reset_from_input = 0;

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
			reset_from_input <= 1;
		CONTROL_LOOP_SETPT: begin
			word_out[DATA_WID-1:ADC_WID] <= 0;
			word_out[ADC_WID-1:0] <= setpt;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_SETPT | CONTROL_LOOP_WRITE_BIT:
			setpt <= word_in[ADC_WID-1:0];
			reset_from_input <= 1;
			finish_cmd <= 1;
		CONTROL_LOOP_P: begin
			word_out <= cl_p_reg;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_P | CONTROL_LOOP_WRITE_BIT: begin
			cl_p_reg <= word_in;
			reset_from_input <= 1;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_ALPHA: begin
			word_out <= cl_alpha_reg;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_ALPHA | CONTROL_LOOP_WRITE_BIT: begin
			cl_alpha_reg <= word_in;
			reset_from_input <= 1;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_DELAY: begin
			word_out[DATA_WID-1:DELAY_WID] <= 0;
			word_out[DELAY_WID-1:0] <= saved_delay;
			finish_cmd <= 1;
		end
		CONTROL_LOOP_DELAY | CONTROL_LOOP_WRITE_BIT: begin
			saved_delay <= word_in[DELAY_WID-1:0];
			reset_from_input <= 1;
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
	end else if (!start_cmd) begin
		finish_cmd <= 0;
		reset_from_input <= 0;
	end
end

/* This is not a race condition as long as two variables are
 * not being assigned at the same time. Instead, the lower
 * assign block will use the older values (i.e. the upper assign
 * block only takes effect next clock cycle).
 */

always @ (posedge clk) begin
	if (reset_from_input) begin
		state <= INIT_READ_FROM_DAC;
		adj_prev <= 0;
		err_prev <= 0;
		timer <= 0;
	end else if (running) begin case (state)
	INIT_READ_FROM_DAC: begin
		/* 1001[0....] is read from dac register */
		to_dac <= b'1001 << DAC_DATA_WID;
		dac_ss <= 1;
		dac_arm <= 1;
		state <= WAIT_FOR_DAC_READ;
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
		if (timer < saved_delay) begin
			timer <= timer + 1;
		end else begin
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
			stored_dac_val <= total_dac_val;
			to_dac <= b'0001 << DAC_DATA_WID | total_dac_val;
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
