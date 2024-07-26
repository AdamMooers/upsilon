/* Copyright 2024 (C) Adam Mooers, William Spettel
 *
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 *
 */

module pi_pipeline #(
	parameter INPUT_WIDTH = 18,
	parameter OUTPUT_WIDTH = 32,
	parameter signed PI_SATURATION_LOWER_BOUND /*verilator public*/ = -32'sh80000,
	parameter signed PI_SATURATION_UPPER_BOUND /*verilator public*/ = 32'sh7FFFF
) (
	input clk, 

	input [OUTPUT_WIDTH-1:0] kp,
	input [OUTPUT_WIDTH-1:0] ki,
	input [INPUT_WIDTH-1:0] setpoint,
	input [INPUT_WIDTH-1:0] actual,
	input [OUTPUT_WIDTH-1:0] integral_input,

	output [OUTPUT_WIDTH-1:0] integral_result,
	output reg [OUTPUT_WIDTH-1:0] pi_result
);
	localparam integer UNCLAMPED_PI_RESULT_WIDTH = OUTPUT_WIDTH*2;

	reg [OUTPUT_WIDTH-1:0] error;
	reg [OUTPUT_WIDTH-1:0] updated_integral;

	reg [UNCLAMPED_PI_RESULT_WIDTH-1:0] weighted_integral;
	reg [UNCLAMPED_PI_RESULT_WIDTH-1:0] weighted_proportional;

	/* verilator lint_off UNUSEDSIGNAL */
	reg [UNCLAMPED_PI_RESULT_WIDTH-1:0] pi_result_unclamped;
	/* verilator lint_on UNUSEDSIGNAL */

	reg pi_result_unclamped_upper_word_has_ones; // Is the upper word, excluding the sign, all zeros?
	reg pi_result_unclamped_upper_word_all_ones; // Is the upper word, excluding the sign, all ones?
	reg pi_result_unclamped_lower_word_lt_lb;  // Less than lower bound
	reg pi_result_unclamped_lower_word_gt_ub;  // greater than upper bound

	wire [OUTPUT_WIDTH-1:0] actual_sign_extended;
	wire [OUTPUT_WIDTH-1:0] setpoint_sign_extended;
	wire pi_result_unclamped_sign;

	assign actual_sign_extended = {{OUTPUT_WIDTH-INPUT_WIDTH{actual[INPUT_WIDTH-1]}},actual};
	assign setpoint_sign_extended = {{OUTPUT_WIDTH-INPUT_WIDTH{setpoint[INPUT_WIDTH-1]}},setpoint};
	assign pi_result_unclamped_sign = pi_result_unclamped[UNCLAMPED_PI_RESULT_WIDTH-1];

	// Stage 1
	always @(posedge clk) begin
		error <= $signed(actual_sign_extended) - $signed(setpoint_sign_extended);
	end

	// Stage 2
	always @(posedge clk) begin
		updated_integral <= $signed(integral_input) + $signed(error);
	end

	// Stage 3
	always @(posedge clk) begin
		weighted_integral <= $signed(updated_integral) * $signed(ki);
		weighted_proportional <= $signed(error) * $signed(kp);
	end

/*
	// Stages 3,4
	mult32 mul_updated_integral_by_ki (
		.clk(clk),
		.multiplier(updated_integral),
		.multiplicand(ki),
		.product(weighted_integral)
	);

	mult32 mul_error_by_kp (
		.clk(clk),
		.multiplier($signed(error)),
		.multiplicand($signed(kp)),
		.product(weighted_proportional)
	);
*/

	// Stage 4
	always @(posedge clk) begin
		pi_result_unclamped <= $signed(weighted_integral) + $signed(weighted_proportional);
	end

	//Stage 5
	always @(posedge clk) begin
		pi_result_unclamped_upper_word_has_ones <= |pi_result_unclamped[UNCLAMPED_PI_RESULT_WIDTH-2:OUTPUT_WIDTH-1];
		pi_result_unclamped_upper_word_all_ones <= &pi_result_unclamped[UNCLAMPED_PI_RESULT_WIDTH-2:OUTPUT_WIDTH-1];
		pi_result_unclamped_lower_word_gt_ub <= $signed(pi_result_unclamped[OUTPUT_WIDTH-1:0]) > PI_SATURATION_UPPER_BOUND;
		pi_result_unclamped_lower_word_lt_lb <= $signed(pi_result_unclamped[OUTPUT_WIDTH-1:0]) < PI_SATURATION_LOWER_BOUND;
	end

	// Stage 6
	always @(posedge clk) begin
		if (~pi_result_unclamped_sign && (pi_result_unclamped_upper_word_has_ones || pi_result_unclamped_lower_word_gt_ub)) begin
			pi_result <= PI_SATURATION_UPPER_BOUND;
		end
		else if (pi_result_unclamped_sign && (~pi_result_unclamped_upper_word_all_ones || pi_result_unclamped_lower_word_lt_lb)) begin
			pi_result <= PI_SATURATION_LOWER_BOUND;
		end
		else begin
			pi_result <= pi_result_unclamped[OUTPUT_WIDTH-1:0];
		end
	end

	assign integral_result = updated_integral;

endmodule
