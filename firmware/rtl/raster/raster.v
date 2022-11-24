module raster #(
	parameter SAMPLEWID = 9,
	parameter DAC_DATA_WID = 20,
	parameter DAC_WID = 24,
	parameter DAC_WAIT_BETWEEN_CMD = 10,
	parameter TIMER_WID = 4,
	parameter STEPWID = 16,
	parameter MAX_ADC_DATA_WID = 24
) (
	input clk,
	input arm,
	output reg finshed,
	output reg running,

	/* Amount of steps per sample. */
	input [STEPWID-1:0] steps_per_sample_in,
	/* Amount of samples in one line (forward) */
	input [SAMPLEWID-1:0] max_samples_in,
	/* Amount of lines in the output. */
	input [SAMPLEWID-1:0] max_lines_in,
	/* Wait time after each step. */
	input [TIMER_WID-1:0] settle_time,

	/* Each step goes (x,y) -> (x + dx, y + dy) forward for each line of
	 * the output. */
	input signed [DAC_DATA_WID-1:0] dx_in,
	input signed [DAC_DATA_WID-1:0] dy_in,

	/* Vertical steps to go to the next line. */
	input signed [DAC_DATA_WID-1:0] dx_vert_in,
	input signed [DAC_DATA_WID-1:0] dy_vert_in,

	/* X and Y DAC piezos */
	output x_arm,
	output [DAC_DATA_WID-1:0] x_to_dac,
	input [DAC_DATA_WID-1:0] x_from_dac,
	output x_finished,

	output y_arm,
	output [DAC_DATA_WID-1:0] y_to_dac,
	input [DAC_DATA_WID-1:0] y_from_dac,
	output y_finished,

	/* Connections to all possible ADCs. These are connected to SPI masters
	 * and they will automatically extend ADC value lengths to their highest
	 * values. */
	output reg [ADCNUM-1:0] adc_arm,
	input [MAX_ADC_DATA_WID-1:0] adc_data [ADCNUM-1:0],
	input [ADCNUM-1:0] adc_finished,

	/* Bitmap for which ADCs are used. */
	input [ADCNUM-1:0] adc_used_in,

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
localparam SEND_VALUE = 5;
localparam ADVANCE_DAC_WRITE = 6;
localparam WAIT_ADVANCE = 7;
localparam ON_ADC_FINISHED = 8;
localparam NEXT_LINE  = 9;
localparam WAIT_ON_ARM_DEASSERT = 10;
localparam STATE_WID = 4;

/********** Loop State ***********/
reg [STATE_WID-1:0] state = WAIT_ON_ARM;
reg [SAMPLEWID-1:0] sample = 0;
reg [SAMPLEWID-1:0] line = 0;
reg [TIMER_WID-1:0] counter = 0;
reg [DAC_DATA_WID-1:0] x_val = 0;
reg [DAC_DATA_WID-1:0] y_val = 0;

/* Buffer to store all measured ADC values. This
 * is shifted until it is all zeros to determine
 * which ADC values should be read off.
 */
reg [ADCNUM-1:0] adc_used_tmp = 0;

/* Buffer to store ADC data. The buffers are permuted in order
 * for the design to read off the proper values into RAM.
 */
reg [MAX_ADC_DATA_WID-1:0] adc_data_tmp [ADCNUM-1:0];

/********** Loop Parameters *************/
reg [ADCNUM-1:0] adc_used_in = 0;
reg is_reverse = 0;
reg signed [DAC_DATA_WID-1:0] dx = 0;
reg signed [DAC_DATA_WID-1:0] dy = 0;
reg signed [DAC_DATA_WID-1:0] dx_vert = 0;
reg signed [DAC_DATA_WID-1:0] dy_vert = 0;

reg [SAMPLEWID-1:0] max_samples = 0;
reg [SAMPLEWID-1:0] max_lines = 0;
reg [STEPWID-1:0] steps_per_sample = 0;

/* Reading ADC data.
 * If this doesn't work, a gigantic vector with large bit shifts
 * can also work.
 */

genvar ii;
generate for (ii = 0; ii < ADCNUM - 1; ii = ii + 1) begin
	always @ (posedge clk) begin
		if (state == SCAN_ADC_VALUES) begin
			adc_data_tmp[ii] <= adc_data_tmp[ii+1];
		end
	end
end endgenerate

always @ (posedge clk) begin
	case (state)
	WAIT_ON_ARM: begin if (arm) begin
		if (adc_used_in != 0) begin
			state <= REQUEST_DAC_VALUES;
		end
		adc_used <= adc_used_in;
		dx <= dx_in;
		dy <= dy_in;
		dx_vert <= dx_vert_in;
		dy_vert <= dy_vert_in;
		max_samples <= max_samples_in;
		max_lines <= max_lines_in;
		steps_per_sample <= steps_per_sample_in;

		is_reverse <= 0;
		sample <= 0;
		line <= 0;

		x_to_dac <= {4'b1001, 20'b0};
		y_to_dac <= {4'b1001, 20'b0};
		x_arm <= 1;
		y_arm <= 1;

		adc_arm <= 0;
	end else begin
		running <= 0;
	end end
	REQUEST_DAC_VALUES: begin
		if (x_finished && y_finished) begin
			x_to_dac <= 0;
			y_to_dac <= 0;
			x_arm <= 0;
			y_arm <= 0;
			state <= OBTAIN_DAC_VALUES;
			counter <= 0;
		end
	end
	OBTAIN_DAC_VALUES: begin if (counter < DAC_WAIT_BETWEEN_CMD) begin
		counter <= counter + 1;
		if (!arm) state <= WAIT_ON_ARM;
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

	WAIT_ADVANCE: begin
		if (counter < settle_time) begin
			if (!arm) state <= WAIT_ON_ARM;
			counter <= counter + 1;
		end else begin
			adc_arm <= adc_used;
			adc_used_tmp <= adc_used;
			state <= MEASURE;
		end
	end
	MEASURE: begin
		if (adc_finished == adc_arm) begin
			adc_arm <= 0;
			state <= SCAN_ADC_VALUES;
			counter <= 0;
		end
	end
	SCAN_ADC_VALUES: begin
		if (adc_used_tmp == 0) begin
			state <= ON_ADC_FINISHED;
			if (sample == max_samples) begin
				dx <= ~dx + 1;
				dy <= ~dy + 1;
				is_reverse <= !is_reverse;
				sample <= 0;

				if (is_reverse) begin
					state <= NEXT_LINE;
				end else begin
					state <= ADVANCE_DAC_WRITE;
				end
			end else begin
				state <= ADVANCE_DAC_WRITE;
			end
		end else begin
			adc_used_tmp <= adc_used_tmp << 1;
			if (adc_used_tmp[ADCNUM-1]) begin
				state <= SEND_VALUE;
				data <= adc_data_tmp[ADCNUM-1];
				mem_commit <= 1;
			end
		end
	end

	SEND_VALUE: if (mem_finished) begin
		if (!arm) state <= WAIT_ON_ARM;
		state <= SCAN_ADC_VALUES;
	end
	ADVANCE_DAC_WRITE: begin
		if (!x_arm || !y_arm) begin
			x_val <= x_val + dx;
			y_val <= y_val + dy;
			x_to_dac <= {4b'0001, x_val + dx};
			y_to_dac <= {4b'0001, y_val + dy};
			x_arm <= 1;
			y_arm <= 1;
			sample <= sample + 1;
		end else if (x_finished && y_finished) begin
			counter <= 0;
			state <= WAIT_ADVANCE;
			x_arm <= 0;
			y_arm <= 0;
		end
	end

	NEXT_LINE: begin
		if (!x_arm && !y_arm) begin
			if (line == max_lines) begin
				state <= WAIT_ON_ARM_DEASSERT;
				finished <= 1;
				running <= 0;
			end else begin
				x_val <= x_val + dx_vert;
				x_to_dac <= {4b'0001, x_val + dx_vert};
				x_arm <= 1;
				y_val <= y_val + dy_vert;
				y_to_dac <= {4b'0001, y_val + dy_vert};
				y_arm <= 1;
				line <= line + 1;
			end
		end else if (x_finished && y_finished) begin
			counter <= 0;
			state <= WAIT_ADVANCE_LINE;
			x_arm <= 0;
			y_arm <= 0;
		end
	end
	WAIT_ON_ARM_DEASSERT: begin
		if (!arm) begin
			state <= WAIT_ON_ARM;
			finished <= 0;
		end
	end
	endcase
end

endmodule
