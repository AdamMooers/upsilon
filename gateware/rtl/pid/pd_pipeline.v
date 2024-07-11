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

	input signed [INPUT_WIDTH-1:0] i_kp,
	input signed [INPUT_WIDTH-1:0] i_ki,
	input signed [INPUT_WIDTH-1:0] i_setpoint,
	input signed [INPUT_WIDTH-1:0] i_actual,
	input signed [OUTPUT_WIDTH-1:0] i_integral,

	output signed [OUTPUT_WIDTH-1:0] o_integral,
	output reg signed [OUTPUT_WIDTH-1:0] o_pd_out
);

	reg [OUTPUT_WIDTH-1:0] error;
	reg [OUTPUT_WIDTH-1:0] updated_integral;
	reg [OUTPUT_WIDTH-1:0] weighted_integral;
	reg [OUTPUT_WIDTH-1:0] weighted_proportional;

	// Stage 0
	always @(posedge clk) begin
		error <= {{OUTPUT_WIDTH-INPUT_WIDTH{i_actual[INPUT_WIDTH-1]}},i_actual} -
		{{OUTPUT_WIDTH-INPUT_WIDTH{i_setpoint[INPUT_WIDTH-1]}},i_setpoint};
	end

	// Stage 1
	always @(posedge clk) begin
		updated_integral <= i_integral + error;
	end

	// Stage 2
	always @(posedge clk) begin
		weighted_integral <= updated_integral * i_ki;
		weighted_proportional <= error * i_kp;
	end

	// Stage 3
	always @(posedge clk) begin
		o_pd_out <= weighted_integral + weighted_proportional;
	end

	assign o_integral = updated_integral;

// Request ADC output

// Wait for ADC output
// Update actual
// Update integral
// Wait for pipeline to propagate result
// Request ADC output (maybe add update&arm?)
// Set DAC to result (maybe add update&arm?)

endmodule
