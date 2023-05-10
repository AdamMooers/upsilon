m4_changequote(`⟨', `⟩')
m4_changecom(⟨/*⟩, ⟨*/⟩)
/*************** Precision **************
 * The control loop is designed around these values, but generally
 * does not hardcode them.
 *
 * Since I and P are precalculated outside of the loop, their
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
 * [1 : sign][20: whole][43: fractional]
 */

module control_loop_math #(
	parameter CONSTS_WHOLE = 21,
	parameter CONSTS_FRAC = 43,
m4_define(M4_CONSTS_WID, (CONSTS_WHOLE + CONSTS_FRAC))
	parameter CONSTS_SIZ=7,

	parameter ADC_WID = 18,
	parameter [M4_CONSTS_WID-1:0] SEC_PER_CYCLE = 'b10101011110011000,
	/* The conversion between the ADC bit (20/2**18) and DAC bit (20.48/2**20)
	 * is 0.256.
	 */
	parameter [M4_CONSTS_WID-1:0] ADC_TO_DAC = 64'b0100000110001001001101110100101111000110101,
	parameter CYCLE_COUNT_WID = 18,
	parameter DAC_WID = 20
m4_define(M4_E_WID, (DAC_WID + 1))
) (
	input clk,
	input arm,
	input rst_L,
	output reg finished,

	input signed [ADC_WID-1:0] setpt,
	input signed [ADC_WID-1:0] measured,
	input signed [M4_CONSTS_WID-1:0] cl_P,
	input signed [M4_CONSTS_WID-1:0] cl_I,
	input signed [CYCLE_COUNT_WID-1:0] cycles,
	input signed [M4_E_WID-1:0] e_prev,
	input signed [M4_CONSTS_WID-1:0] adjval_prev,
	input signed [DAC_WID-1:0] stored_dac_val,

`ifdef DEBUG_CONTROL_LOOP_MATH
	output reg [M4_CONSTS_WID-1:0] dt_reg,
	output reg [M4_CONSTS_WID-1:0] idt_reg,
	output reg [M4_CONSTS_WID-1:0] epidt_reg,
	output reg [M4_CONSTS_WID-1:0] ep_reg,
`endif

	output reg signed [M4_E_WID-1:0] e_cur,
	output signed [DAC_WID-1:0] new_dac_val,
	output signed [M4_CONSTS_WID-1:0] adj_val
);

/*******
 * Multiplier segment.
 * Multiplies two 64 bit numbers and right-saturate + truncates it
 * to be a 64 bit output, according to fixed-point rules.
 */

reg signed [M4_CONSTS_WID-1:0] a1;
reg signed [M4_CONSTS_WID-1:0] a2;
/* verilator lint_off UNUSED */
wire signed [M4_CONSTS_WID+M4_CONSTS_WID-1:0] out_untrunc;
wire mul_fin;
reg mul_arm = 0;

boothmul #(
	.A1_LEN(M4_CONSTS_WID),
	.A2_LEN(M4_CONSTS_WID),
	.A2LEN_SIZ(CONSTS_SIZ)
) multiplier (
	.a1(a1),
	.a2(a2),
	.clk(clk),
	.rst_L(rst_L),
	.outn(out_untrunc),
	.fin(mul_fin),
	.arm(mul_arm)
);

/****************************
 * QX.Y * QX.Y = Q(2X).(2Y)
 * This right-truncation gets rid of the lowest Y bits.
 * Q(2X).Y
 */

m4_define(M4_OUT_RTRUNC_WID, (M4_CONSTS_WID+M4_CONSTS_WID-CONSTS_FRAC))
wire signed [M4_OUT_RTRUNC_WID-1:0] out_rtrunc
	= out_untrunc[M4_CONSTS_WID+M4_CONSTS_WID-1:CONSTS_FRAC];

wire signed [M4_CONSTS_WID-1:0] mul_out;

/***************************
 * Saturate higher X bits away.
 * Q(2X).Y -> QX.Y
 */

intsat #(
	.IN_LEN(M4_OUT_RTRUNC_WID),
	.LTRUNC(CONSTS_WHOLE)
) multiplier_saturate (
	.inp(out_rtrunc),
	.outp(mul_out)
);

/*************************
 * Safely get rid of high bit in addition.
 ************************/

reg signed [M4_CONSTS_WID+1-1:0] add_sat;
wire signed [M4_CONSTS_WID-1:0] saturated_add;

intsat #(
	.IN_LEN(M4_CONSTS_WID + 1),
	.LTRUNC(1)
) addition_saturate (
	.inp(add_sat),
	.outp(saturated_add)
);

/************************
 * Safely truncate down adjustment value.
 ***********************/
reg signed [CONSTS_WHOLE-1:0] adj_sat;
wire signed [DAC_WID-1:0] adj_final;
intsat #(
	.IN_LEN(CONSTS_WHOLE),
	.LTRUNC(CONSTS_WHOLE - DAC_WID)
) adj_saturate (
	.inp(adj_sat),
	.outp(adj_final)
);

/************************
 * Safely calculate new DAC value.
 ************************/
reg signed [DAC_WID+1-1:0] add_sat_dac;
intsat #(
	.IN_LEN(DAC_WID+1),
	.LTRUNC(1)
) dac_saturate (
	.inp(add_sat_dac),
	.outp(new_dac_val)
);

localparam WAIT_ON_ARM = 0;
localparam CALCULATE_ERR = 9;
localparam CALCULATE_DAC_E = 7;
localparam WAIT_ON_CALCULATE_DT = 1;
localparam CALCULATE_IDT = 2;
localparam CALCULATE_EPIDT = 3;
localparam CALCULATE_EP = 4;
localparam CALCULATE_A_PART_1 = 5;
localparam CALCULATE_A_PART_2 = 6;
localparam CALCULATE_NEW_DAC_VALUE_PART_1 = 10;
localparam CALCULATE_NEW_DAC_VALUE_PART_2 = 11;
localparam WAIT_ON_DISARM = 8;

reg [4:0] state = WAIT_ON_ARM;
reg signed [M4_CONSTS_WID+1-1:0] tmpstore = 0;
wire signed [M4_CONSTS_WID-1:0] tmpstore_view = tmpstore[M4_CONSTS_WID-1:0];


always @ (posedge clk) begin
	if (!rst_L) begin
		state <= WAIT_ON_ARM;
		a1 <= 0;
		finished <= 0;
		mul_arm <= 0;
		a2 <= 0;
		e_cur <= 0;
`ifdef DEBUG_CONTROL_LOOP_MATH
		dt_reg <= 0;
		idt_reg <= 0;
		epidt_reg <= 0;
		ep_reg <= 0;
`endif
		add_sat <= 0;
		adj_val <= 0;
		tmpstore <= 0;
	end else case (state)
	WAIT_ON_ARM:
		if (arm) begin
			a1[CONSTS_FRAC-1:0] <= 0;
			a1[CONSTS_FRAC+ADC_WID + 1-1:CONSTS_FRAC] <= setpt - measured;
			state <= CALCULATE_ERR;
		end else begin
			finished <= 0;
			mul_arm <= 0;
		end
	CALCULATE_ERR: begin
		/* Sign-extend */
		a1[M4_CONSTS_WID-1:CONSTS_FRAC + ADC_WID + 1] <=
			{(M4_CONSTS_WID-(CONSTS_FRAC + ADC_WID + 1)){a1[ADC_WID+1-1+CONSTS_FRAC]}};
		a2 <= ADC_TO_DAC;
		mul_arm <= 1;
		state <= CALCULATE_DAC_E;
	end
	CALCULATE_DAC_E:
		if (mul_fin) begin
			/* Discard other bits. This works without saturation because
			 * CONSTS_WHOLE = E_WID. */
			e_cur <= mul_out[M4_CONSTS_WID-1:CONSTS_FRAC];

			a1 <= SEC_PER_CYCLE;
			/* No sign extension, cycles is positive */
			a2 <= {{(CONSTS_WHOLE - CYCLE_COUNT_WID){1'b0}}, cycles, {(CONSTS_FRAC){1'b0}}};
			mul_arm <= 0;
			state <= WAIT_ON_CALCULATE_DT;
		end
	WAIT_ON_CALCULATE_DT:
	if (!mul_arm) begin
			mul_arm <= 1;
	end else if (mul_fin) begin
			mul_arm <= 0;

			`ifdef DEBUG_CONTROL_LOOP_MATH
				dt_reg <= mul_out;
			`endif

			a1 <= mul_out; /* a1 = Δt */
			a2 <= cl_I;
			state <= CALCULATE_IDT;
	end
	CALCULATE_IDT:
		if (!mul_arm) begin
			mul_arm <= 1;
		end else if (mul_fin) begin
			mul_arm <= 0;
			add_sat <= (mul_out + cl_P);

			`ifdef DEBUG_CONTROL_LOOP_MATH
				idt_reg <= mul_out;
			`endif

			a2 <= {{(CONSTS_WHOLE-M4_E_WID){e_cur[M4_E_WID-1]}},e_cur, {(CONSTS_FRAC){1'b0}}};
			state <= CALCULATE_EPIDT;
		end
	CALCULATE_EPIDT:
		if (!mul_arm) begin
			a1 <= saturated_add;
			mul_arm <= 1;
		end else if (mul_fin) begin
			mul_arm <= 0;
			tmpstore <= {mul_out[M4_CONSTS_WID-1],mul_out};

			`ifdef DEBUG_CONTROL_LOOP_MATH
				epidt_reg <= mul_out;
			`endif

			a1 <= cl_P;
			a2 <= {{(CONSTS_WHOLE-M4_E_WID){e_prev[M4_E_WID-1]}},e_prev, {(CONSTS_FRAC){1'b0}}};
			state <= CALCULATE_EP;
		end
	CALCULATE_EP:
		if (!mul_arm) begin
			mul_arm <= 1;
		end else if (mul_fin) begin
			`ifdef DEBUG_CONTROL_LOOP_MATH
				ep_reg <= mul_out;
			`endif

			mul_arm <= 0;
			add_sat <= (tmpstore_view - mul_out);
			state <= CALCULATE_A_PART_1;
		end
	CALCULATE_A_PART_1: begin
		tmpstore <= saturated_add + adjval_prev;
		state <= CALCULATE_A_PART_2;
	end
	CALCULATE_A_PART_2: begin
		add_sat <= tmpstore;
		state <= CALCULATE_NEW_DAC_VALUE_PART_1;
	end
	CALCULATE_NEW_DAC_VALUE_PART_1: begin
		adj_sat <= saturated_add[M4_CONSTS_WID-1:CONSTS_FRAC];
		adj_val <= saturated_add;
		state <= CALCULATE_NEW_DAC_VALUE_PART_2;
	end
	CALCULATE_NEW_DAC_VALUE_PART_2: begin
		add_sat_dac <= adj_final + stored_dac_val;
		state <= WAIT_ON_DISARM;
	end
	WAIT_ON_DISARM: begin
		adj_val <= saturated_add;
		if (!arm) begin
			state <= WAIT_ON_ARM;
			finished <= 0;
		end else begin
			finished <= 1;
		end
	end
	endcase
end

`ifdef VERILATOR
initial begin
	$dumpfile("control_loop_math.fst");
	$dumpvars;
end
`endif

endmodule
