/*
 *  Copyright 2024 (C) Adam Mooers
 *
 *  This file is a part of Upsilon, a free and open source software project.
 *  For license terms, refer to the files in `doc/copying` in the Upsilon
 *  source distribution.
 *
 *  F4PGA & Yosys do not infer 32x32 signed multiplication correctly to Xilinx DSP48
 *  blocks unless given the correct incantation. It may be possible to further simplify
 *  the pipeline, but any changes should be tested extensively to verify that they do
 *  not exhibit any unintended behavior. Specifically, be sure that Yosys/ABC does not
 *  limit the multiplication to 25x18. This happened without warning during testing.
 */

 module mult32 (
	input clk, 

	input [32-1:0] multiplicand,
	input [32-1:0] multiplier,

	output [64-1:0] product
);
    reg [33-1:0] multiplicand_q;
    reg [33-1:0] multiplier_q;
	reg [64-1:0] product_buffer;

	// Stage 0
	always @(posedge clk) begin
		/* verilator lint_off WIDTH */
		multiplicand_q <= $signed(multiplicand);
		multiplier_q <= $signed(multiplier);
		/* verilator lint_on WIDTH */
	end

	// Stage 1
	always @(posedge clk) begin
		product_buffer <= $signed(multiplicand_q)*$signed(multiplier_q);
	end

	assign product = product_buffer[63:0];
endmodule
