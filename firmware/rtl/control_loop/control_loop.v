/* TODO: standardised access that isn't ad-hoc: wishbone
 * bus */

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
	parameter ADC_POLARITY = 1,
	parameter ADC_PHASE = 0,
	parameter DAC_POLARITY = 0,
	parameter DAC_PHASE = 1
) (
	input clk,
	input arm,
	output running,

	input signed [ADC_WID-1:0] measured_value,
	output adc_conv,
	output adc_arm,
	input adc_finished,

	output signed [DAC_WID-1:0] to_dac,
	output dac_ss,
	output dac_arm,
	input dac_finished

	input reg read_err_cur,
	output reg read_err_cur_finished,
	output signed [ERR_WID-1:0] err_cur,
	output signed [CONSTS_WID-1:0] adj,

	input signed [ADC_WID-1:0] setpt_in,
	input signed [CONSTS_WID-1:0] cl_alpha_in,
	input signed [CONSTS_WID-1:0] cl_p_in,
	input [DELAY_WID-1:0] delay_in
);

/* Registers used to lock in values at the start of each iteration */
reg signed [ADC_WID-1:0] setpt = 0;
reg signed [CONSTS_WID-1:0] cl_alpha_reg = 0;
reg signed [CONSTS_WID-1:0] cl_p_reg = 0;
reg [DELAY_WID-1:0] saved_delay = 0;

/* Registers for PI calculations */
reg signed [ERR_WID-1:0] err_prev = 0;

/****** State machine
 *
 * -> WAIT_ON_ARM -> WAIT_ON_ADC -> WAIT_ON_MUL -\
 *             \------\------------ WAIT_ON_DAC </
 *
 * The loop will stop and reset all stored data if `arm` is not 1 at
 * the end of the loop.
 * The loop stores all data from the input into registers at
 * `WAIT_ON_ADC`, so the program can change constants and setpoints
 * on the fly.
 */

localparam WAIT_ON_ARM = 0;
localparam WAIT_ON_ADC = 1;
localparam WAIT_ON_MUL = 2;
localparam WAIT_ON_DAC = 3;
localparam STATESIZ = 2;

reg [STATESIZ-1:0] state = WAIT_ON_ARM;

/***** Outline *****
 * The loop will only iterate when armed. If it is running and `arm`
 * is deasserted, then it will complete the iteration it is in and
 * stop.
 *
 * At the start of each loop, the constants are read into registers,
 * so the constants can change while the loop is running.
 *
 * First the loop reads from the ADC, and then computes the error
 * from the setpoint. The setpoint is specified in the same units
 * as the ADC.
 *
 * Afterwards the loop computes the multiplications in the PI loop.
 * This changes the size of the values in the loop.
 *
 * Combinatorially, the new adjusted value is calculated. The original
 * value has to be stored in the same width as the multiplied values.
 *
 * Then the value is truncated to the width of the DAC, with saturation
 * if necessary, and written out to the DAC.
 *
 **** Precision Propogation
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
assign err_cur = measured_value - setpoint;

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

reg signed [SUB_WID-1:0] adj_old;
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

wire signed rtrunc[RTRUNC_WID-1:0] =
	newadj[SUB_WID-1:SUB_FRAC_WID-RTRUNC_FRAC_WID];

/**** Truncate-Saturate ****
 * Truncate the result into a value acceptable to the DAC.
 * [      SUB_WHOLE_WID      ].[RTRUNC_FRAC_WID]############
 *         [ADC_WID].[DAC_DATA_WID - ADC_WID]
 *         reinterpreted as
 *         [DAC_DATA_WID].0
 */

wire signed dac_adj_val[DAC_DATA_WID-1:0];

intsat #(
	.IN_LEN(RTRUNC_WID),
	.LTRUNC(DAC_DATA_WID)
) sat_newadj_rtrunc (
	.inp(newadj_rtrunc),
	.outp(dac_adj_val)
);

/**** Write to DAC ****/

assign to_dac = {4'b0010,dac_adj_val};

reg [DELAY_WID-1:0] timer = 0;

always @ (posedge clk) begin
	case (state)
	WAIT_ON_ARM: begin
		if (!arm) begin
			adj_prev <= 0;
			err_prev <= 0;
			timer <= 0;
			running <= 0;
		end else if (timer == 0) begin
			saved_delay <= delay_in;
			timer <= 1;
			running <= 1;
			setpt <= setpt_in;
			/* TODO: cl_alpha change only when loop is stopped */
			cl_alpha_reg <= cl_alpha_in;
			cl_p_reg <= cl_p_in;
			state <= WAIT_LOOP_DELAY;
		end else if (timer < saved_delay) begin
			timer <= timer + 1;
			setpt <= setpt_in;
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
			state <= WAIT_ON_DAC;
		end
	WAIT_ON_DAC: if (dac_finished) begin
			state <= WAIT_ON_ARM;
			dac_ss <= 0;
			dac_arm <= 0;
		end
end

endmodule
