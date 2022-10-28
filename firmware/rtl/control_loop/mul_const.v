module mul_const #(
	parameter CONSTS_WHOLE = 8,
	parameter CONSTS_FRAC = 40,
	parameter CONSTS_WID = CONSTS_WHOLE + CONSTS_FRAC,
	parameter IN_WHOLE = CONSTS_WHOLE,
	parameter IN_FRAC = CONSTS_FRAC,
	parameter IN_WID = IN_WHOLE + IN_FRAC
) (
	input clk,
	input signed [IN_WID-1:0] inp,
	input signed [CONSTS_WID-1:0] const_in,
	input arm,

	output signed [CONSTS_WID-1:0] outp,
	output finished
);

localparam UNSAT_WID = CONSTS_WID + IN_WID;
wire signed [UNSAT_WID-1:0] unsat;

boothmul #(
	.A1_LEN(CONSTS_WID),
	.A2_LEN(IN_WID)
) mul (
	.clk(clk),
	.arm(arm),
	.a1(const_in),
	.a2(inp),
	.outn(unsat),
	.fin(finished)
);

localparam RIGHTTRUNC_WID = UNSAT_WID - IN_FRAC;
wire signed [RIGHTTRUNC_WID-1:0] rtrunc =
	unsat[UNSAT_WID-1:IN_FRAC];

generate if (IN_WHOLE > 0) begin
	intsat #(
		.IN_LEN(RIGHTTRUNC_WID),
		.LTRUNC(IN_WHOLE)
	) sat (
		.inp(rtrunc),
		.outp(outp)
	);
end else begin
	assign outp = rtrunc;
end endgenerate

`ifdef VERILATOR
initial begin
	$dumpfile("mul_const.fst");
	$dumpvars();
end
`endif

endmodule
