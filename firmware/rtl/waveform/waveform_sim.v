module waveform_sim #(
	parameter DAC_WID = 24,
	parameter DAC_WID_SIZ = 5,
	parameter DAC_POLARITY = 0,
	parameter DAC_PHASE = 1,
	parameter DAC_CYCLE_HALF_WAIT = 10,
	parameter DAC_CYCLE_HALF_WAIT_SIZ = 4,
	parameter DAC_SS_WAIT = 5,
	parameter DAC_SS_WAIT_SIZ = 3,
	parameter TIMER_WID = 32,
	parameter WORD_WID = 20,
	parameter WORD_AMNT_WID = 11,
	parameter [WORD_AMNT_WID-1:0] WORD_AMNT = 2047,
	parameter RAM_REAL_START = 32'h12340,
	parameter RAM_CNTR_LEN = 12,
	parameter TOTAL_RAM_WORD_MINUS_ONE = 4095,
	parameter DELAY_CNTR_LEN = 8,
	parameter DELAY_TOTAL = 12,
	parameter RAM_WID = 32,
	parameter RAM_WORD_WID = 16,
	parameter RAM_WORD_INCR = 2
) (
	input clk,
	input arm,
	input halt_on_finish,
	output waveform_finished,
	output running,
	input [TIMER_WID-1:0] time_to_wait,

	/* User interface */
	input refresh_start,
	input [RAM_WID-1:0] start_addr,
	output reg refresh_finished,

	output [DAC_WID-1:0] from_master,
	output finished,
	input rdy,
	output spi_err,

	input[RAM_WORD_WID-1:0] backing_store [TOTAL_RAM_WORD_MINUS_ONE:0]
);

wire sck;
wire ss_L;
wire mosi;

spi_slave_no_write #(
	.WID(DAC_WID),
	.WID_LEN(DAC_WID_SIZ),
	.POLARITY(DAC_POLARITY),
	.PHASE(DAC_PHASE)
) slave (
	.clk(clk),
	.sck(sck),
	.ss_L(ss_L),
	.mosi(mosi),
	.from_master(from_master),
	.finished(finished),
	.rdy(rdy),
	.err(spi_err)
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

waveform #(
	.DAC_WID(DAC_WID),
	.DAC_WID_SIZ(DAC_WID_SIZ),
	.DAC_POLARITY(DAC_POLARITY),
	.DAC_PHASE(DAC_PHASE),
	.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
	.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
	.DAC_SS_WAIT(DAC_SS_WAIT),
	.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
	.TIMER_WID(TIMER_WID),
	.WORD_WID(WORD_WID),
	.WORD_AMNT_WID(WORD_AMNT_WID),
	.WORD_AMNT(WORD_AMNT),
	.RAM_WID(RAM_WID),
	.RAM_WORD_WID(RAM_WORD_WID),
	.RAM_WORD_INCR(RAM_WORD_INCR)
) waveform (
	.clk(clk),
	.arm(arm),
	.halt_on_finish(halt_on_finish),
	.running(running),
	.finished(waveform_finished),
	.time_to_wait(time_to_wait),

	.refresh_start(refresh_start),
	.start_addr(start_addr),
	.refresh_finished(refresh_finished),

	.ram_dma_addr(ram_dma_addr),
	.ram_word(ram_word),
	.ram_read(ram_read),
	.ram_valid(ram_valid),

	.mosi(mosi),
	.sck(sck),
	.ss_L(ss_L)
);

endmodule
`undefineall
