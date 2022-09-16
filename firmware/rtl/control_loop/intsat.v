/* Saturate integers. v0.1
 * Written by Peter McGoron, 2022.
 */

module intsat
#(
	parameter IN_LEN = 64,
	parameter LTRUNC = 32
)
(
	input signed [IN_LEN-1:0] inp,
	output signed [IN_LEN-LTRUNC-1:0] outp
);

/* Truncating a twos-complement integer can cause overflow.
 * To check for overflow, look at all truncated bits and
 * the most significant bit that will be kept.
 * If they are all 0 or all 1, then there is no truncation.
 */

localparam INP_TRUNC_START = IN_LEN - LTRUNC;
localparam INP_CHECK_START = INP_TRUNC_START - 1;
localparam OUT_LEN = IN_LEN - LTRUNC;

/*
 * [               IN_LEN                      ]
 * [     LTRUNC       |        OUT_LEN         ]
 *                   * &
 *   *: INP_TRUNC_START
 *   &: INP_CHECK_START
*/

always @ (*) begin
	if (inp[IN_LEN-1:INP_CHECK_START] == {(LTRUNC + 1){inp[IN_LEN-1]}}) begin
		outp[OUT_LEN-1:0] = inp[OUT_LEN-1:0];
	end else if (inp[IN_LEN-1]) begin
		// most negative number: 1000000....
		outp[OUT_LEN-1:0] = {1'b1,{(OUT_LEN-1){1'b0}}};
	end else begin
		// most positive number: 0111111....
		outp[OUT_LEN-1:0] = {1'b0,{(OUT_LEN-1){1'b1}}};
	end
end

endmodule
