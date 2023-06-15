/* Copyright 2023 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
module sign_extend #(
	parameter WID1 = 18,
	parameter WID2 = 24
) (
	input [WID1-1:0] b1,
	output [WID2-1:0] b2
);

assign b2[WID1-1:0] = b1;
/* Assign the high bits of b2 to be the extension of the
 * highest bit of b1. If the MSB of b1 is 1 (i.e. b1 is
 * negative), then all high bits of b2 must be negative.
 * If the MSB of b1 is 0, then the high bits of b2 must
 * be zero.
 */
assign b2[WID2-1:WID1] = {(WID2-WID1){b1[WID1-1]}};

endmodule

