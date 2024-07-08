/* Copyright 2024 (C) Adam Mooers, William Spettel
 *
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */

module waveform #() (
	input clk,
	input signed [1:0] reset,

	input signed [18-1:0] kp,
	input signed [18-1:0] ki,
	input signed [9-1:0] dt,
	input signed [18-1:0] setpoint,
	input signed [18-1:0] actual,

	output signed reg [36-1:0] integral,
	output signed [36-1:0] result
);

	reg [18-1:0] error;
	reg [36-1:0] weighted_integral;
	reg [36-1:0] weighted_proportional;
	reg [36-1:0] adjustment;

// TODO: Get reset working
// TODO: Parameterize the inputs and outputs

	always @(posedge clk) begin
		error <= actual - setpoint;
	end

	always @(posedge clk) begin
		integral <= integral + error;
	end

	always @(posedge clk) begin
		weighted_integral <= integral * ki;
		weighted_proportional <= error * kp;
	end

	always @(posedge clk) begin
		adjustment <= weighted_integral + weighted_proportional
	end

	assign result = adjustment

endmodule
