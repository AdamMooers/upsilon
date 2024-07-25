/* Copyright 2024 (C) Adam Mooers, William Spettel
 *
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 *
 */

`ifndef MULT32_V
	`include "../mult32/mult32.v"
`endif

module pi_pipeline #(
	parameter INPUT_WIDTH = 18,
	parameter OUTPUT_WIDTH = 32,
	parameter signed PI_SATURATION_LOWER_BOUND /*verilator public*/ = -64'sh80000,
	parameter signed PI_SATURATION_UPPER_BOUND /*verilator public*/ = 64'sh7FFFF
) (
	input clk, 

	input signed [OUTPUT_WIDTH-1:0] kp,
	input signed [OUTPUT_WIDTH-1:0] ki,
	input signed [INPUT_WIDTH-1:0] setpoint,
	input signed [INPUT_WIDTH-1:0] actual,
	input signed [OUTPUT_WIDTH-1:0] integral_input,

	output signed [OUTPUT_WIDTH-1:0] integral_result,
	output reg signed [OUTPUT_WIDTH-1:0] pi_result
);
	localparam integer UNCLAMPED_PI_RESULT_WIDTH = OUTPUT_WIDTH*2;

	reg signed [OUTPUT_WIDTH-1:0] error;
	reg signed [OUTPUT_WIDTH-1:0] updated_integral;

	reg signed [UNCLAMPED_PI_RESULT_WIDTH-1:0] weighted_integral;
	reg signed [UNCLAMPED_PI_RESULT_WIDTH-1:0] weighted_proportional;

	/* verilator lint_off UNUSEDSIGNAL */
	reg signed [UNCLAMPED_PI_RESULT_WIDTH-1:0] pi_result_unclamped;
	/* verilator lint_on UNUSEDSIGNAL */

	wire signed [OUTPUT_WIDTH-1:0] actual_sign_extended;
	wire signed [OUTPUT_WIDTH-1:0] setpoint_sign_extended;

	assign actual_sign_extended = {{OUTPUT_WIDTH-INPUT_WIDTH{actual[INPUT_WIDTH-1]}},actual};
	assign setpoint_sign_extended = {{OUTPUT_WIDTH-INPUT_WIDTH{setpoint[INPUT_WIDTH-1]}},setpoint};

	// Stage 1
	always @(posedge clk) begin
		error <= actual_sign_extended - setpoint_sign_extended;
	end

	// Stage 2
	always @(posedge clk) begin
		updated_integral <= integral_input + error;
	end

	// Stages 3,4
	mult32 mul_updated_integral_by_ki (
		.clk(clk),
		.multiplier(updated_integral),
		.multiplicand(ki),
		.product(weighted_integral)
	);

	mult32 mul_error_by_kp (
		.clk(clk),
		.multiplier(error),
		.multiplicand(kp),
		.product(weighted_proportional)
	);

	// Stage 5
	always @(posedge clk) begin
		pi_result_unclamped <= weighted_integral + weighted_proportional;
	end

	// Stage 6
	always @(posedge clk) begin
		if (pi_result_unclamped > PI_SATURATION_UPPER_BOUND) begin
			pi_result <= PI_SATURATION_UPPER_BOUND[OUTPUT_WIDTH-1:0];
		end
		else if (pi_result_unclamped < PI_SATURATION_LOWER_BOUND) begin
			pi_result <= PI_SATURATION_LOWER_BOUND[OUTPUT_WIDTH-1:0];
		end
		else begin
			pi_result <= pi_result_unclamped[OUTPUT_WIDTH-1:0];
		end
	end

	assign integral_result = updated_integral;

endmodule
