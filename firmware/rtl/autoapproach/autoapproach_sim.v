module autoapproach_sim #(
	parameter DAC_WID = 24,
	parameter DAC_DATA_WID = 20,
	parameter ADC_WID = 24,
	parameter TIMER_WID = 32,
	parameter WORD_WID = 24,
	parameter WORD_AMNT_WID = 11,
	parameter [WORD_AMNT_WID-1:0] WORD_AMNT = 2047,
	parameter RAM_WID = 32,
	parameter RAM_WORD_WID = 16,
	parameter RAM_WORD_INCR = 2,
	parameter TOTAL_RAM_WORD_MINUS_ONE = 4095
) (
	input clk,
	input arm,
	output stopped,
	output detected,

	input polarity,
	input [ADC_WID-1:0] setpoint,
	input [TIMER_WID-1:0] time_to_wait,

	/* User interface */
	input refresh_start,
	input [RAM_WID-1:0] start_addr,
	output refresh_finished,

	/* DAC wires. */
	input dac_finished,
	output dac_arm,
	output [DAC_WID-1:0] dac_out,

	input adc_finished,
	output adc_arm,
	input [ADC_WID-1:0] measurement

	input[RAM_WORD_WID-1:0] backing_store [TOTAL_RAM_WORD_MINUS_ONE:0]
);

wire [RAM_WID-1:0] ram_dma_addr;
wire [RAM_WORD_WID-1:0] ram_word;
wire ram_read;
wire ram_valid;

dma_sim #(
	.RAM_WID(RAM_WID),
	.RAM_WORD_WID(RAM_WORD_WID),
	.RAM_REAL_START(RAM_REAL_START),
	.RAM_CNTR_LEN(RAM_CNTR_LEN),
	.TOTAL_RAM_WORD_MINUS_ONE(TOTAL_RAM_WORD_MINUS_ONE),
	.DELAY_CNTR_LEN(DELAY_CNTR_LEN),
	.DELAY_TOTAL(DELAY_TOTAL)
) dma_sim (
	.clk(clk),
	.ram_dma_addr(ram_dma_addr),
	.ram_word(ram_word),
	.ram_read(ram_read),
	.ram_valid(ram_valid),
	.backing_store(backing_store)
);

autoapproach #(
	.DAC_WID(DAC_WID),
	.DAC_DATA_WID(DAC_DATA_WID),
	.ADC_WID(ADC_WID),
	.TIMER_WID(TIMER_WID),
	.WORD_WID(WORD_WID),
	.WORD_AMNT_WID(WORD_AMNT_WID),
	.WORD_AMNT(WORD_AMNT),
	.RAM_WID(RAM_WID),
	.RAM_WORD_WID(RAM_WORD_WID),
	.RAM_WORD_INCR(RAM_WORD_INCR)
) aa (
	.clk(clk),
	.arm(arm),
	.stopped(stopped),
	.detected(detected),
	.polarity(polarity),
	.setpoint(setpoint),
	.time_to_wait(time_to_wait),
	.refresh_start(refresh_start),
	.start_addr(start_addr),
	.refresh_finished(refresh_finished),
	.ram_dma_addr(ram_dma_addr),
	.ram_word(ram_word),
	.ram_read(ram_read),
	.ram_valid(ram_valid),
	.dac_finished(dac_finished),
	.dac_arm(dac_arm),
	.dac_out(dac_out),
	.adc_finished(adc_finished),
	.adc_arm(adc_arm),
	.measurement(measurement)
);

endmodule
