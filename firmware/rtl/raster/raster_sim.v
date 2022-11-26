module raster_sim #(
	parameter SAMPLEWID = 9,
	parameter DAC_DATA_WID = 20,
	parameter DAC_WID = 24,
	parameter DAC_WAIT_BETWEEN_CMD = 10,
	parameter TIMER_WID = 4,
	parameter STEPWID = 16,
	parameter ADCNUM = 9,
	parameter MAX_ADC_DATA_WID = 24,

	parameter BASE_ADDR = 32'h1000000,
	parameter MAX_BYTE_WID = 13,
	parameter DAT_WID = 24,
	parameter RAM_WORD = 16,
	parameter RAM_WID = 32
) (
	input clk,
	input arm,
	output reg finished,
	output reg running,

	/* Amount of steps per sample. */
	input [STEPWID-1:0] steps_per_sample_in,
	/* Amount of samples in one line (forward) */
	input [SAMPLEWID-1:0] max_samples_in,
	/* Amount of lines in the output. */
	input [SAMPLEWID-1:0] max_lines_in,
	/* Wait time after each step. */
	input [TIMER_WID-1:0] settle_time_in,

	/* Each step goes (x,y) -> (x + dx, y + dy) forward for each line of
	 * the output. */
	input signed [DAC_DATA_WID-1:0] dx_in,
	input signed [DAC_DATA_WID-1:0] dy_in,

	/* Vertical steps to go to the next line. */
	input signed [DAC_DATA_WID-1:0] dx_vert_in,
	input signed [DAC_DATA_WID-1:0] dy_vert_in,

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
	input [MAX_ADC_DATA_WID-1:0] adc_data [ADCNUM-1:0],
	input [ADCNUM-1:0] adc_finished,

	/* Bitmap for which ADCs are used. */
	input [ADCNUM-1:0] adc_used_in,

	/* DMA interface */
	output [RAM_WORD-1:0] word,
	output [RAM_WID-1:0] addr,
	output ram_write,
	input ram_valid
);

wire signed [DAT_WID-1:0] ram_data;
wire ram_commit;
wire ram_write_finished;

ram_shim #(
	.BASE_ADDR(BASE_ADDR),
	.MAX_BYTE_WID(MAX_BYTE_WID),
	.DAT_WID(DAT_WID),
	.RAM_WORD(RAM_WORD),
	.RAM_WID(RAM_WID)
) ram (
	.clk(clk),
	.data(ram_data),
	.commit(ram_commit),
	.finished(ram_write_finished),
	.word(word),
	.addr(addr),
	.write(ram_write),
	.valid(ram_valid)
);

raster #(
	.SAMPLEWID(SAMPLEWID),
	.DAC_DATA_WID(DAC_DATA_WID),
	.DAC_WID(DAC_WID),
	.DAC_WAIT_BETWEEN_CMD(DAC_WAIT_BETWEEN_CMD),
	.TIMER_WID(TIMER_WID),
	.STEPWID(STEPWID),
	.MAX_ADC_DATA_WID(MAX_ADC_DATA_WID)
) raster (
	.clk(clk),
	.arm(arm),
	.finished(finished),
	.running(running),
	.steps_per_sample_in(steps_per_sample_in),
	.max_samples_in(max_samples_in),
	.max_lines_in(max_lines_in),
	.settle_time_in(settle_time_in),
	.dx_in(dx_in),
	.dy_in(dy_in),
	.dx_vert_in(dx_vert_in),
	.dy_vert_in(dy_vert_in),

	.x_arm(x_arm),
	.x_to_dac(x_to_dac),
	.x_from_dac(x_from_dac),
	.x_finished(x_finished),

	.y_arm(y_arm),
	.y_to_dac(y_to_dac),
	.y_from_dac(y_from_dac),
	.y_finished(y_finished),

	.adc_arm(adc_arm),
	.adc_data(adc_data),
	.adc_finished(adc_finished),

	.adc_used_in(adc_used_in),

	.data(ram_data),
	.mem_commit(ram_commit),
	.mem_finished(ram_write_finished)
);

endmodule
