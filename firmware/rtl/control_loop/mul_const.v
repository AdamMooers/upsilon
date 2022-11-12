module mul_const #(
	parameter CONSTS_WHOLE = 8,
	parameter CONSTS_FRAC = 40,
`define CONSTS_WID (CONSTS_WHOLE + CONSTS_FRAC)
	parameter IN_WHOLE = CONSTS_WHOLE,
	parameter IN_FRAC = CONSTS_FRAC,
`define IN_WID (IN_WHOLE + IN_FRAC)
	parameter OUT_WHOLE = 20,
	parameter OUT_FRAC = 40
`define OUT_WID (OUT_WHOLE + OUT_FRAC)
) (
	input clk,
	input signed [`IN_WID-1:0] inp,
	input signed [`CONSTS_WID-1:0] const_in,
	input arm,

	output signed [`OUT_WID-1:0] outp,
	output finished
);

`define UNSAT_WID (`CONSTS_WID + `IN_WID)
wire signed [`UNSAT_WID-1:0] unsat;

boothmul #(
	.A1_LEN(`CONSTS_WID),
	.A2_LEN(`IN_WID)
) mul (
	.clk(clk),
	.arm(arm),
	.a1(const_in),
	.a2(inp),
	.outn(unsat),
	.fin(finished)
);

`define RIGHTTRUNC_WID (CONSTS_WHOLE + IN_WHOLE + OUT_FRAC)
`define UNSAT_FRAC (CONSTS_FRAC + IN_FRAC)
wire signed [`RIGHTTRUNC_WID-1:0] rtrunc =
	unsat[`UNSAT_WID-1:(`UNSAT_FRAC - OUT_FRAC)];

generate if (OUT_WHOLE < CONSTS_WHOLE + IN_WHOLE) begin
	intsat #(
		.IN_LEN(`RIGHTTRUNC_WID),
		.LTRUNC(CONSTS_WHOLE + IN_WHOLE - OUT_WHOLE)
	) sat (
		.inp(rtrunc),
		.outp(outp)
	);
end else if (OUT_WHOLE == CONSTS_WHOLE + IN_WHOLE) begin
	assign outp = rtrunc;
end else begin
	assign outp[`RIGHTTRUNC_WID-1:0] = rtrunc;
	assign outp[`OUT_WID-1:`RIGHTTRUNC_WID] = {
		(`OUT_WID-`RIGHTTRUNC_WID){rtrunc[`RIGHTTRUNC_WID-1]}
	};
end endgenerate

`ifdef VERILATOR
initial begin
	$dumpfile("mul_const.fst");
	$dumpvars();
end
`endif

endmodule
