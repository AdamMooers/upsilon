/* Booth Multiplication v0.1
 * Written by Peter McGoron, 2022.
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
	input arm,
	input [A1_LEN-1:0] a1,
	input [A2_LEN-1:0] a2,
	output [A1_LEN+A2_LEN-1:0] outn,
	output reg fin
);

/***********************
 * Booth Parameters
 **********************/

localparam OUT_LEN = A1_LEN + A2_LEN;
localparam REG_LEN = OUT_LEN + 2;

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

reg signed [REG_LEN-1:0] a;
reg signed [REG_LEN-1:0] s;
reg signed [REG_LEN-1:0] p = 0;

assign outn[OUT_LEN-1:0] = p[REG_LEN-2:1];

/**********************
 * Loop Implementation
 *********************/

reg[A2LEN_SIZ-1:0] loop_accul = 0;

always @ (posedge clk) begin
	if (!arm) begin
		loop_accul <= 0;
		fin <= 0;
	end else if (loop_accul == 0) begin
		p[0] <= 0;
		p[A2_LEN:1] <= a2;
		p[REG_LEN-1:A2_LEN+1] <= 0;

		a[A2_LEN:0] <= 0;
		a[REG_LEN-2:A2_LEN + 1] <= a1;
		a[REG_LEN-1] <= a1[A1_LEN-1]; // Sign extension

		s[A2_LEN:0] <= 0;
		// Extend before negation to ensure size
		s[REG_LEN-1:A2_LEN+1] <= ~{a1[A1_LEN-1],a1} + 1;

		loop_accul <= loop_accul + 1;
	end else if (loop_accul < A2_LEN + 1) begin
		/* The loop counter starts from 1, so it must go to
		 * A2_LEN + 1 exclusive.
		 *         (i = 0; i < len;     i++)
		 * becomes (i = 1; i < len + 1; i++)
		 */
		loop_accul <= loop_accul + 1;
		case (p[1:0])
		2'b00, 2'b11: p <= p >>> 1;
		2'b10: p <= (p + s) >>> 1;
		2'b01: p <= (p + a) >>> 1;
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
