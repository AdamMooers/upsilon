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
	input clk,
	input reset,
	input start,

	input signed [INPUT_WIDTH-1:0] i_kp,
	input signed [INPUT_WIDTH-1:0] i_ki,
	input signed [INPUT_WIDTH-1:0] i_setpoint,
	input signed [INPUT_WIDTH-1:0] i_actual,

	output reg signed [OUTPUT_WIDTH-1:0] o_integral,
	output reg signed [OUTPUT_WIDTH-1:0] o_pd_out,
	output complete
);

	reg [INPUT_WIDTH-1:0] error;
	reg [OUTPUT_WIDTH-1:0] weighted_integral;
	reg [OUTPUT_WIDTH-1:0] weighted_proportional;

	reg start_delay;
	reg ce_stage_1;
	reg ce_stage_2;
	reg ce_stage_3;
	reg ce_stage_4;

	always @(posedge clk) begin
		start_delay <= start;
	end

	// Stage 0
	always @(posedge clk) begin
		// The pipeline runs only once on the positive edge of start
		if (start & ~start_delay) begin
			error <= i_actual - i_setpoint;
			ce_stage_1 <= start;
		end
	end

	// Stage 1
	always @(posedge clk) begin
		if (reset) begin
			o_integral <= 0;
		end else if (ce_stage_1) begin
			o_integral <= o_integral + {{OUTPUT_WIDTH-INPUT_WIDTH{error[INPUT_WIDTH-1]}},error};
			ce_stage_2 <= ce_stage_1;
		end
	end

	// Stage 2
	always @(posedge clk) begin
		if (ce_stage_2) begin
			weighted_integral <= o_integral * i_ki;
			weighted_proportional <= error * i_kp;
			ce_stage_3 <= ce_stage_2;
		end
	end

	// Stage 3
	always @(posedge clk) begin
		if (ce_stage_3) begin
			o_pd_out <= weighted_integral + weighted_proportional;
			ce_stage_4 <= ce_stage_3;
		end
	end

	assign complete = ce_stage_4;

// Request ADC output

// Wait for ADC output
// Update actual
// Wait for pipeline to propagate result
// Request ADC output (maybe add update&arm?)
// Set DAC to result (maybe add update&arm?)

endmodule
