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
	parameter OUTPUT_SATURATION_BITS = 20
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
	localparam integer PI_SATURATION_LOWER_BOUND = -(1 << OUTPUT_SATURATION_BITS);
	localparam integer PI_SATURATION_UPPER_BOUND = (1 << OUTPUT_SATURATION_BITS) - 1;

	reg signed [OUTPUT_WIDTH-1:0] error;
	reg signed [OUTPUT_WIDTH-1:0] updated_integral;
	reg signed [UNCLAMPED_PI_RESULT_WIDTH-1:0] weighted_integral;
	reg signed [UNCLAMPED_PI_RESULT_WIDTH-1:0] weighted_proportional;
	reg signed [UNCLAMPED_PI_RESULT_WIDTH-1:0] pi_result_unclamped;

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

	// Stage 5
	always @(posedge clk) begin
		if (weighted_integral > PI_SATURATION_UPPER_BOUND) begin
			pi_result <= PI_SATURATION_UPPER_BOUND;
		end
		else if (weighted_integral < PI_SATURATION_LOWER_BOUND) begin
			pi_result <= PI_SATURATION_LOWER_BOUND;
		end
		else begin
			pi_result <= pi_result_unclamped[OUTPUT_WIDTH-1:0];
		end
	end


	assign integral_result = updated_integral;

endmodule
