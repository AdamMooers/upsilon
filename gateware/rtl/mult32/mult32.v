/* Copyright 2024 (C) Adam Mooers
 *
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 *
 * F4PGA + Yosys does not infer DSP48E1 blocks correctly for multiplication. Results
 * on the 18-bit input are truncated. This module uses 16x16bit partial products to 
 * bypass the issue.
 *
 * The module uses the following math:
 * Let x_1, x_2, y_1, and y_2 be 16-bit numbers s.t.
 *
 * x = x_1*2^16 + x_2
 * y = y_1*2^16 + y_2
 *
 * x*y = (x_2*y_2*2^32) + (x_1*y_2*2^16) + (x_2*y_1*2^16) + (x_1*y_1)
 *
 * Letting p_0 = x_1*y_1, p_1 = x_2*y_1, p_2 = x_1*y_2, and p_3 = x_2*y_2, we can
 * rewrite the above equation:
 *
 * x*y = (p_3*2^32) + (p_2*2^16) + (p_1*2^16) + p_0
 *
 * The p_3 and p_0 terms have no overlapping terms so we can concatenate them to
 * add them. The p_2 and p_1 terms have the same offset so we add them together
 * first to prevent excess bit growth.
 */

 module mult32 (
	input clk, 

	input [32-1:0] multiplicand,
	input [32-1:0] multiplier,

	output reg signed [64-1:0] product
);

    reg [32-1:0] p0;
    reg [32-1:0] p1;
    reg [32-1:0] p2;
    reg [32-1:0] p3;
    reg [32-1:0] sump1p2;

	// Stage 1
	always @(posedge clk) begin
		p0 <= multiplicand[16-1:0]*multiplier[16-1:0];
        p1 <= multiplicand[16-1:0]*multiplier[32-1:16];
        p2 <= multiplicand[32-1:16]*multiplier[16-1:0];
        p3 <= multiplicand[32-1:16]*multiplier[32-1:16];
	end

	// Stage 2
	always @(posedge clk) begin
        sump1p2 = p1+p2;
    end

    // Stage 3
	always @(posedge clk) begin
        product = {p3, p0} + {{16{0}},sump1p2,{16{0}}};
    end