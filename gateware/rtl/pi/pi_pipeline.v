/* Copyright 2024 (C) Adam Mooers, William Spettel
 *
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 *
 */

module pi_pipeline #(
	parameter INPUT_WIDTH = 18,
	parameter OUTPUT_WIDTH = 32
) (
	input clk, 

	input signed [OUTPUT_WIDTH-1:0] kp,
	input signed [OUTPUT_WIDTH-1:0] ki,
	input signed [INPUT_WIDTH-1:0] setpoint,
	input signed [INPUT_WIDTH-1:0] actual,
	input signed [OUTPUT_WIDTH-1:0] integral_input,
	input signed [OUTPUT_WIDTH-1:0] pi_result_lower_bound,
	input signed [OUTPUT_WIDTH-1:0] pi_result_upper_bound,

	output signed [OUTPUT_WIDTH-1:0] integral_result,
	output reg signed [OUTPUT_WIDTH-1:0] pi_result
);

	localparam integer UNCLAMPED_PI_RESULT_WIDTH = OUTPUT_WIDTH*2;

	reg [OUTPUT_WIDTH-1:0] error;
	reg [OUTPUT_WIDTH-1:0] updated_integral;
	reg [UNCLAMPED_PI_RESULT_WIDTH-1:0] weighted_integral;
	reg [UNCLAMPED_PI_RESULT_WIDTH-1:0] weighted_proportional;
	reg [UNCLAMPED_PI_RESULT_WIDTH-1:0] pi_result_unclamped;

	// Stage 1
	always @(posedge clk) begin
		error <= {{OUTPUT_WIDTH-INPUT_WIDTH{actual[INPUT_WIDTH-1]}},actual} -
		{{OUTPUT_WIDTH-INPUT_WIDTH{setpoint[INPUT_WIDTH-1]}},setpoint};
	end

	// Stage 2
	always @(posedge clk) begin
		updated_integral <= integral_input + error;
	end

	// Stage 3
	always @(posedge clk) begin
		weighted_integral <= updated_integral * {{UNCLAMPED_PI_RESULT_WIDTH-OUTPUT_WIDTH{ki[OUTPUT_WIDTH-1]}},ki};
		weighted_proportional <= error * {{UNCLAMPED_PI_RESULT_WIDTH-OUTPUT_WIDTH{kp[OUTPUT_WIDTH-1]}},kp};
	end

	// Stage 4
	always @(posedge clk) begin
		pi_result_unclamped <= weighted_integral + weighted_proportional;
	end

	assign integral_result = updated_integral;

endmodule
