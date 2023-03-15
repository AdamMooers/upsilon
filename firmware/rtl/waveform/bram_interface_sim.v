module bram_interface_sim #(
	parameter WORD_WID = 20,
	parameter WORD_AMNT_WID = 11,
	parameter [WORD_AMNT_WID-1:0] WORD_AMNT = 2047,
	parameter RAM_WID = 32,
	parameter RAM_WORD_WID = 16,
	parameter RAM_REAL_START = 32'h12340,
	parameter RAM_CNTR_LEN = 12,
	parameter TOTAL_RAM_WORD_MINUS_ONE = 4095,
	parameter DELAY_CNTR_LEN = 8,
	parameter DELAY_TOTAL = 12,
	parameter RAM_WORD_INCR = 2
) (
	input clk,

	/* autoapproach interface */
	output [WORD_WID-1:0] word,
	input word_next,
	output word_last,
	output word_ok,
	input word_rst,

	/* User interface */
	input refresh_start,
	input [RAM_WID-1:0] start_addr,
	output refresh_finished,

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

bram_interface #(
	.WORD_WID(WORD_WID),
	.WORD_AMNT_WID(WORD_AMNT_WID),
	.WORD_AMNT(WORD_AMNT),
	.RAM_WID(RAM_WID),
	.RAM_WORD_WID(RAM_WORD_WID),
	.RAM_WORD_INCR(RAM_WORD_INCR)
) bram_interface (
	.clk(clk),
	.word(word),
	.word_next(word_next),
	.word_last(word_last),
	.word_ok(word_ok),
	.word_rst(word_rst),
	.refresh_start(refresh_start),
	.start_addr(start_addr),
	.refresh_finished(refresh_finished),
	.ram_dma_addr(ram_dma_addr),
	.ram_word(ram_word),
	.ram_read(ram_read),
	.ram_valid(ram_valid)
);

initial begin
	$dumpfile("bram.fst");
	$dumpvars();
end

endmodule
