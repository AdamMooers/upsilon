/* Calculate and truncate Δt = cycles/100MhZ.
 * NOTE: boothmul is a SIGNED algorithm so both inputs are SIGNED.
 * This means that SEC_PER_CYCLE must have a leading 0
 * and that cycles must also have a leading zero.
 */

`undefineall
module calculate_dt #(
	/* This number is 1/(clock cycle).
	   The number is interpreted so the least significant bit
	   coincides with the LSB of a constant. */
	parameter SEC_PER_CYCLE_WID = 15,
	parameter [SEC_PER_CYCLE_WID-1:0] SEC_PER_CYCLE = 'b010101011110011,
	parameter CYCLE_COUNT_WID = 18,
	parameter MAX_WID = 48
) (
	input clk,
	input arm,
	output finished,

	input [CYCLE_COUNT_WID-1:0] cycles,

/* Multiplication of Q18.0 and 14 lower siginifcant bits. */
`define DT_WID_UNTRUNC (SEC_PER_CYCLE_WID + CYCLE_COUNT_WID)
`define DT_WID (`DT_WID_UNTRUNC > MAX_WID ? MAX_WID : `DT_WID_UNTRUNC)

	output [`DT_WID-1:0] dt
);

wire [`DT_WID_UNTRUNC-1:0] dt_untrunc;

boothmul #(
	.A1_LEN(CYCLE_COUNT_WID),
	.A2_LEN(SEC_PER_CYCLE_WID)
) mul (
	.clk(clk),
	.arm(arm),
	.a1(cycles),
	.a2(SEC_PER_CYCLE),
	.outn(dt_untrunc),
	.fin(finished)
);

generate if (`DT_WID_UNTRUNC > `DT_WID) begin
	intsat #(
		.IN_LEN(`DT_WID_UNTRUNC),
		.LTRUNC(`DT_WID_UNTRUNC - `DT_WID)
	) sat (
		.inp(dt_untrunc),
		.outp(dt)
	);
end else begin
	assign dt = dt_untrunc;
end endgenerate

`ifdef VERILATOR
initial begin
	$dumpfile("calculate_dt.fst");
	$dumpvars;
end
`endif

endmodule
