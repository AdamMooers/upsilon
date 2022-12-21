/* Raster scanner. This module sweeps two DACs (the X and Y piezos)
 * across a box, where the X and Y axes may be at an angle. After
 * a single step, the ADCs connected to the raster scanner are
 * activated, with each value read into system memory (see ram_shim).
 * The kernel then reads these values and sends them to the controller
 * over ethernet.
 */
`include "raster_cmds.vh"
`timescale 10ns/10ns
module raster #(
	parameter SAMPLEWID = 9,
	parameter DAC_DATA_WID = 20,
	parameter DAC_WID = 24,
	parameter DAC_WAIT_BETWEEN_CMD = 10,
	parameter TIMER_WID = 4,
	parameter STEPWID = 16,
	parameter ADCNUM = 9,
	parameter MAX_ADC_DATA_WID = 24
) (
	input clk,

	/* Kernel interface. */
	input [`RASTER_CMD_WID-1:0] kernel_cmd,
	input [`RASTER_DATA_WID-1:0] kernel_data_in,
	output reg [`RASTER_DATA_WID-1:0] kernel_data_out,
	input kernel_ready,
	output reg kernel_finished,

	/* X and Y DAC piezos */
	output x_arm,
	output [DAC_WID-1:0] x_to_dac,
	/* verilator lint_off UNUSED */
	input [DAC_WID-1:0] x_from_dac,
	input x_finished,

	output y_arm,
	output [DAC_WID-1:0] y_to_dac,
	/* verilator lint_off UNUSED */
	input [DAC_WID-1:0] y_from_dac,
	input y_finished,

	/* Connections to all possible ADCs. These are connected to SPI masters
	 * and they will automatically extend ADC value lengths to their highest
	 * values. */
	output reg [ADCNUM-1:0] adc_arm,

	/* Yosys does not support input arrays. */
	input [ADCNUM*MAX_ADC_DATA_WID-1:0] adc_data,
	input [ADCNUM-1:0] adc_finished,

	/* RAM DMA. This is generally not directly connected to the
	 * DMA IP. A shim is used in order to write multiple words
	 * to memory. */
	output reg [MAX_ADC_DATA_WID-1:0] data,
	output reg mem_commit,
	input mem_finished
);

/* During a scan, some of the ADCs will be scanned, but some will not.
 * The data are packed in such a way so that the most significant
 * word will contain the highest enabled ADC number, and the least
 * significant word will contain the lowest enabled ADC number (and so
 * on in between).
 *
 * There's not a good way to precalculate this so instead the check
 * is done at each "send" stage.
 */

/* State machine:
 ┏━━━━ WAIT ON ARM
 ↑         ↓ (arm -> 1)
 ┃     REQUEST DAC VALUES
 ┃         ↓ (when x and y values are requested)
 ┃     OBTAIN DAC VALUES
 ┃         ↓ (when x and y values are measured)
 ┃   ┏━LOOP FORWARD WITHOUT MEASUREMENT
 ┃   ↑     ↓ (when enough steps are taken)
 ┃   ┃ GET ADC VALUES
 ┃   ┃     ↓ (when all ADC values are obtained)
 ┃   ┃ SEND THROUGH FIFO
 ┃   ┃     ↓ (when finished)
 ┃ ┏━┫     ┃
 ┃ ↑ ┗━━━←━┫
 ┃ ┃       ┃ (when at the end of a line)
 ┃ ┃       ┃
 ┃ ┃ ┏━LOOP BACKWARD WITHOUT MEASUREMENT
 ┃ ┃ ↑     ↓ (when enough steps are taken)
 ┃ ┃ ┃ GET ADC VALUES, BACKWARDS MEASUREMENT
 ┃ ┃ ┃     ↓ (when all ADC values are obtained)
 ┃ ┃ ┃ SEND THROUGH FIFO, BACKWARDS MEASUREMENT
 ┃ ┃ ┃     ↓ (when finished)
 ┃ ┃ ┃     ┃
 ┃ ┃ ┗━━━←━┫
 ┃ ┃       ↓
 ┃ ┗━━━━━━━┫
 ┃         ↓ (when the image is finished)
 ┃         ┃
 ┃   WAIT FOR ARM DEASSERT
 ┃         ↓ (when arm = 0)
 ┗━━━━━━━━━┛
*/

localparam WAIT_ON_ARM = 0;
localparam GET_DAC_VALUES = 1;
localparam REQUEST_DAC_VALUES = 2;
localparam MEASURE = 3;
localparam SCAN_ADC_VALUES = 4;
localparam ADVANCE_DAC_WRITE = 5;
localparam WAIT_ADVANCE = 6;
localparam NEXT_LINE  = 7;
localparam WAIT_ON_ARM_DEASSERT = 8;
localparam STATE_WID = 4;

/********** Loop State ***********/
reg [STATE_WID-1:0] state = WAIT_ON_ARM;
reg [SAMPLEWID-1:0] sample = 0;
reg [SAMPLEWID-1:0] line = 0;
reg [TIMER_WID-1:0] counter = 0;
reg signed [DAC_DATA_WID-1:0] x_val = 0;
reg signed [DAC_DATA_WID-1:0] y_val = 0;

/* Buffer to store all measured ADC values. This
 * is shifted until it is all zeros to determine
 * which ADC values should be read off.
 */
reg [ADCNUM-1:0] adc_used_tmp = 0;
reg [ADCNUM*MAX_ADC_DATA_WID-1:0] adc_data_tmp = 0;

/********** Loop Parameters *************/
reg [ADCNUM-1:0] adc_used = 0;
reg is_reverse = 0;
reg arm = 0;
reg running = 0;
reg signed [DAC_DATA_WID-1:0] dx = 0;
reg signed [DAC_DATA_WID-1:0] dy = 0;
reg [TIMER_WID-1:0] settle_time = 0;

reg [SAMPLEWID-1:0] max_samples = 0;
reg [SAMPLEWID-1:0] max_lines = 0;
reg [STEPWID-1:0] steps_per_sample = 0;

/********** Control Interface ************ 
 * This code assumes that RASTER_DATA_WID is greater than all registers.
 * If a register is equal to the length, omit zero extension.
 *
 * This uses a macro since each register is exactly the same code, just
 * with different length. The arm register is special: it can be adjusted
 * while the loop is running (in order to terminate the scan), but
 * otherwise each register can only be modified when the loop is not
 * running.
 */

// Generates code to handle read requests from the kernel.
`define generate_register_read(code, width, register)     \
code: begin                                               \
	kernel_data_out[(width)-1:0] <= register;         \
	kernel_data_out[`RASTER_DATA_WID-1:(width)] <= 0; \
	kernel_finished <= 1;                             \
end

// Generates code to handle write requests from the kernel.
`define generate_register(code, width, register)         \
`generate_register_read(code, width, register)           \
code | `RASTER_WRITE_BIT: begin                          \
	if (!running && (code) != `RASTER_ARM) begin     \
		register <= kernel_data_in[(width)-1:0]; \
		kernel_finished <= 1;                    \
	end                                              \
end

always @ (posedge clk) begin
	if (!kernel_ready) kernel_finished <= 0;
	else if (kernel_ready) begin case (kernel_cmd)
	`generate_register(`RASTER_MAX_SAMPLES, SAMPLEWID, max_samples)
	`generate_register(`RASTER_MAX_LINES, SAMPLEWID, max_lines)
	`generate_register(`RASTER_SETTLE_TIME, TIMER_WID, settle_time)
	`generate_register(`RASTER_DX, DAC_DATA_WID, dx)
	`generate_register(`RASTER_DY, DAC_DATA_WID, dy)
	`generate_register(`RASTER_USED_ADCS, ADCNUM, adc_used)
	`generate_register(`RASTER_STEPS_PER_SAMPLE, STEPWID, steps_per_sample)
	`generate_register(`RASTER_ARM, 1, arm)
	`generate_register_read(`RASTER_RUNNING, 1, running)
	endcase end
end
`undef generate_register_read
`undef generate_register

task check_arm();
	if (!arm) begin
		state <= WAIT_ON_ARM;
		running <= 0;
	end
endtask

`ifdef VERILATOR
task check_deassert_dac_arm();
	if (x_arm) $error("x_arm asserted");
	if (y_arm) $error("y_arm asserted");
endtask
`define CHECK_DAC_ARM check_deassert_dac_arm();
`else
`define CHECK_DAC_ARM
`endif

always @ (posedge clk) begin
	case (state)
	WAIT_ON_ARM: if (arm) begin
		running <= 1;
		is_reverse <= 0;
		sample <= 0;
		line <= 0;

		x_to_dac <= {4'b1001, 20'b0};
		y_to_dac <= {4'b1001, 20'b0};
		x_arm <= 1;
		y_arm <= 1;

		adc_arm <= 0;
		state <= REQUEST_DAC_VALUES;
	end
	REQUEST_DAC_VALUES: if (x_finished && y_finished) begin
		x_to_dac <= 0;
		y_to_dac <= 0;
		x_arm <= 0;
		y_arm <= 0;
		state <= GET_DAC_VALUES;
		counter <= 0;
	end
	GET_DAC_VALUES: if (counter < DAC_WAIT_BETWEEN_CMD) begin
		`CHECK_DAC_ARM
		counter <= counter + 1;
		check_arm();
	end else if (!x_arm || !y_arm) begin
		x_arm <= 1;
		y_arm <= 1;
	end else if (x_finished && y_finished) begin
		x_val <= x_from_dac[DAC_DATA_WID-1:0];
		y_val <= y_from_dac[DAC_DATA_WID-1:0];

		x_arm <= 0;
		y_arm <= 0;
		counter <= 0;
		state <= WAIT_ADVANCE;
	end

	WAIT_ADVANCE: if (counter < settle_time) begin
		check_arm();
		counter <= counter + 1;
		`CHECK_DAC_ARM
	end else begin
		`CHECK_DAC_ARM
		adc_arm <= adc_used;
		adc_used_tmp <= adc_used;
		state <= MEASURE;
	end
	MEASURE: if (adc_finished == adc_arm) begin
		`CHECK_DAC_ARM
		adc_arm <= 0;
		adc_data_tmp <= adc_data;
		state <= SCAN_ADC_VALUES;
		counter <= 0;
	end
	SCAN_ADC_VALUES: if (adc_used_tmp == 0 && !mem_commit) begin
		`CHECK_DAC_ARM
		if (sample == max_samples) begin
			dx <= ~dx + 1;
			dy <= ~dy + 1;

			if (is_reverse) begin
				state <= NEXT_LINE;
			end else begin
				state <= ADVANCE_DAC_WRITE;
			end

			is_reverse <= !is_reverse;
			sample <= 0;
		end else begin
			state <= ADVANCE_DAC_WRITE;
		end
	end else if (mem_finished) begin
		`CHECK_DAC_ARM
		state <= SCAN_ADC_VALUES;
		mem_commit <= 0;
	end else begin
		`CHECK_DAC_ARM
		adc_used_tmp <= adc_used_tmp << 1;
		adc_data_tmp <= adc_data_tmp << MAX_ADC_DATA_WID;
		if (adc_used_tmp[ADCNUM-1]) begin
			data <= adc_data_tmp[ADCNUM*MAX_ADC_DATA_WID-1:(ADCNUM-1)*MAX_ADC_DATA_WID];
			mem_commit <= 1;
		end
	end

	ADVANCE_DAC_WRITE: if (!x_arm || !y_arm) begin
		x_val <= x_val + dx;
		y_val <= y_val + dy;
		x_to_dac <= {4'b0001, x_val + dx};
		y_to_dac <= {4'b0001, y_val + dy};
		x_arm <= 1;
		y_arm <= 1;
		sample <= sample + 1;
	end else if (x_finished && y_finished) begin
		counter <= 0;
		state <= WAIT_ADVANCE;
		x_arm <= 0;
		y_arm <= 0;
	end
	NEXT_LINE: if (!x_arm || !y_arm) begin
		if (line == max_lines) begin
			state <= WAIT_ON_ARM_DEASSERT;
			running <= 0;
		end else begin
			/* rotation of (dx,dy) by 90° -> (dy, -dx) */
			x_val <= x_val + dy;
			x_to_dac <= {4'b0001, x_val + dy};
			x_arm <= 1;
			y_val <= y_val - dx;
			y_to_dac <= {4'b0001, y_val - dx};
			y_arm <= 1;
			line <= line + 1;
		end
	end else if (x_finished && y_finished) begin
		counter <= 0;
		state <= WAIT_ADVANCE;
		x_arm <= 0;
		y_arm <= 0;
	end
	WAIT_ON_ARM_DEASSERT: if (!arm) begin
		state <= WAIT_ON_ARM;
	end
	endcase
end

endmodule
`undefineall
