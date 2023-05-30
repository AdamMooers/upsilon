/* Booth Multiplication v1.1
 * Written by Peter McGoron, 2022.
 *
 * This source describes Open Hardware and is licensed under the
 * CERN-OHL-W v2.
 * You may redistribute and modify this documentation and make products using
 * it under the terms of the CERN-OHL-W v2 (https:/cern.ch/cern-ohl), or, at
 * your option, any later version.
 *
 * This documentation is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY,
 * INCLUDING OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR
 * A PARTICULAR PURPOSE. Please see the CERN-OHL-W v2 for applicable
 * conditions.
 *
 * Source location: https://software.mcgoron.com/peter/boothmul
 */

module boothmul
#(
	parameter A1_LEN = 32,
	parameter A2_LEN = 32,
	// AZLEN_SIZ = floor(log2(A2_LEN + 2) + 1).
	// It must be able to store A2_LEN + 2.
	parameter A2LEN_SIZ = 6
)
(
	input clk,
	input rst_L,
	input arm,
	input [A1_LEN-1:0] a1,
	input [A2_LEN-1:0] a2,
	output [A1_LEN+A2_LEN-1:0] outn,
`ifdef DEBUG
	output [A1_LEN+A2_LEN+1:0] debug_a,
	output [A1_LEN+A2_LEN+1:0] debug_s,
	output [A1_LEN+A2_LEN+1:0] debug_p,
	output [A2LEN_SIZ-1:0] debug_state,
`endif
	output reg fin
);

/***********************
 * Booth Parameters
 **********************/

`define OUT_LEN (A1_LEN + A2_LEN)
`define REG_LEN (`OUT_LEN + 2)

/* The Booth multiplication algorithm is a sequential algorithm for
 * twos-compliment integers.
 *
 * Let REG_LEN be equal to 1 + len(a1) + len(a2) + 1.
 * Let P, S, and A be of length REG_LEN.
 * Let A = a1 << len(a2) + 1, where a1 sign extends to the upper bit.
 * Let S = -a1 << len(a2) + 1, where a1 sign extens to the upper bit.
 * Let P = a2 << 1.
 *
 * Repeat the following len(a2) times:
 *   case(P[1:0])
 *     2'b00, 2'b11: P <= P >>> 1;
 *     2'b01: P <= (P + A) >>> 1;
 *     2'b10: P <= (P + S) >>> 1;
 *   endcase
 * The final value is P[REG_LEN-2:1].
 *
 * Wires and registers of REG_LEN length are organized like:
 *
 *  /Overflow bit
 * [M][                REG_LEN                ][0]
 * [M][     A1_LEN      ][       A2_LEN       ][0]
 */

reg [A1_LEN-1:0] a1_reg;

wire [`REG_LEN-1:0] a;
assign a[A2_LEN:0] = 0;
assign a[`REG_LEN-2:A2_LEN+1] = a1_reg;
assign a[`REG_LEN-1] = a1_reg[A1_LEN-1];
wire signed [`REG_LEN-1:0] a_signed;
assign a_signed = a;

wire [`REG_LEN-1:0] s;
assign s[A2_LEN:0] = 0;
assign s[`REG_LEN-1:A2_LEN+1] = ~{a1_reg[A1_LEN-1],a1_reg} + 1;
wire signed [`REG_LEN-1:0] s_signed;
assign s_signed = s;

reg [`REG_LEN-1:0] p;
wire signed [`REG_LEN-1:0] p_signed;
assign p_signed = p;

assign outn = p[`REG_LEN-2:1];

/**********************
 * Loop Implementation
 *********************/

reg[A2LEN_SIZ-1:0] loop_accul = 0;

`ifdef DEBUG
assign debug_a = a;
assign debug_s = s;
assign debug_p = p;
assign debug_state = loop_accul;
`endif

always @ (posedge clk) begin
	if (!rst_L) begin
		loop_accul <= 0;
		fin <= 0;
		p <= 0;
		a1_reg <= 0;
	end else if (!arm) begin
		loop_accul <= 0;
		fin <= 0;
	end else if (loop_accul == 0) begin
		p[0] <= 0;
		p[A2_LEN:1] <= a2;
		p[`REG_LEN-1:A2_LEN+1] <= 0;

		a1_reg <= a1;

		loop_accul <= loop_accul + 1;
	/* verilator lint_off WIDTH */
	end else if (loop_accul < A2_LEN + 1) begin
	/* verilator lint_on WIDTH */	
		/* The loop counter starts from 1, so it must go to
		 * A2_LEN + 1 exclusive.
		 *         (i = 0; i < len;     i++)
		 * becomes (i = 1; i < len + 1; i++)
		 */
		loop_accul <= loop_accul + 1;
		case (p[1:0])
		2'b00, 2'b11: p <= p_signed >>> 1;
		2'b10: p <= (p_signed + s_signed) >>> 1;
		2'b01: p <= (p_signed + a_signed) >>> 1;
		endcase
	end else begin
		fin <= 1;
	end
end

`ifdef BOOTH_SIM
initial begin
	$dumpfile("booth.vcd");
	$dumpvars;
end
`endif

endmodule
