module raster #(
	parameter SAMPLEWID = 9,
	parameter DAC_DATA_WID = 20,
	parameter DAC_WID = 24,
	parameter STEPWID = 16,
	parameter MAX_ADC_DATA_WID = 24
) (
	input clk,
	input arm,

	/* Amount of steps per sample. */
	input [STEPWID-1:0] steps,
	/* Amount of samples in one line (forward) */
	input [SAMPLEWID-1:0] samples,
	/* Amount of lines in the output. */
	input [SAMPLEWID-1:0] lines,

	/* Each step goes (x,y) -> (dx,dy) forward for each line of
	 * the output. */
	input signed [DAC_DATA_WID-1:0] dx,
	input signed [DAC_DATA_WID-1:0] dy,

	/* Vertical steps to go to the next line. */
	input signed [DAC_DATA_WID-1:0] dx_vert,
	input signed [DAC_DATA_WID-1:0] dy_vert,

	/* X and Y DAC piezos */
	input x_ready,
	output [DACWID-1:0] x_to_dac,
	input [DACWID-1:0] x_from_dac,
	output x_finished,

	input y_ready,
	output [DACWID-1:0] y_to_dac,
	input [DACWID-1:0] y_from_dac,
	output y_finished,

	/* Connections to all possible ADCs. These are connected to SPI masters
	 * and they will automatically extend ADC value lengths to their highest
	 * values. */
	input adc_in [0:ADCNUM-1],
	output [MAX_ADC_DATA_WID-1:0] adc_conv [0:ADCNUM-1],
	output adc_finished [0:ADCNUM-1],

	/* Bitmap for which ADCs are used. */
	input [ADCNUM-1:0] adc_used,

	output signed [MAX_ADC_DATA_WID-1:0] fifo_data,
	output fifo_ready,
	input fifo_valid
);

/* State machine:
 ┏━━━━ WAIT ON ARM
 ↑         ↓ (arm -> 1)
 ┃     GET DAC VALUES
 ┃         ↓ (when x and y values are obtained)
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
localparam INCREMENT_XVAL = 2;
localparam GET_ADC_VAL = 3;
localparam SEND_FIFO = 4;
localparam WAIT_FOR_REARM = 5;

reg [2:0] stepstate = WAIT_ON_ARM;
reg is_forward = 1;
reg [SAMPLEWID-1:0] samplenum;
reg [STEPWID-1:0] stepnum;

always @ (posedge clk) begin

end

endmodule
