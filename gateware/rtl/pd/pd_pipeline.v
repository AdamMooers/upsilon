/* Copyright 2024 (C) Adam Mooers, William Spettel
 *
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 *
 */

module pd_pipeline #(
	parameter INPUT_WIDTH = 18,
	parameter OUTPUT_WIDTH = 32
) (
	input clk, // clk instead of i_clk for verilog testbench compatibility

	input signed [INPUT_WIDTH-1:0] kp,
	input signed [INPUT_WIDTH-1:0] ki,
	input signed [INPUT_WIDTH-1:0] setpoint,
	input signed [INPUT_WIDTH-1:0] actual,
	input signed [OUTPUT_WIDTH-1:0] integral_input,

	output signed [OUTPUT_WIDTH-1:0] integral_result,
	output reg signed [OUTPUT_WIDTH-1:0] pd_result
);

	reg [OUTPUT_WIDTH-1:0] error;
	reg [OUTPUT_WIDTH-1:0] updated_integral;
	reg [OUTPUT_WIDTH-1:0] weighted_integral;
	reg [OUTPUT_WIDTH-1:0] weighted_proportional;

	// Stage 0
	always @(posedge clk) begin
		error <= {{OUTPUT_WIDTH-INPUT_WIDTH{actual[INPUT_WIDTH-1]}},actual} -
		{{OUTPUT_WIDTH-INPUT_WIDTH{setpoint[INPUT_WIDTH-1]}},setpoint};
	end

	// Stage 1
	always @(posedge clk) begin
		updated_integral <= integral_input + error;
	end

	// Stage 2
	always @(posedge clk) begin
		weighted_integral <= updated_integral * {{OUTPUT_WIDTH-INPUT_WIDTH{ki[INPUT_WIDTH-1]}},ki};
		weighted_proportional <= error * {{OUTPUT_WIDTH-INPUT_WIDTH{kp[INPUT_WIDTH-1]}},kp};
	end

	// Stage 3
	always @(posedge clk) begin
		pd_result <= weighted_integral + weighted_proportional;
	end

	assign integral_result = updated_integral;

endmodule
