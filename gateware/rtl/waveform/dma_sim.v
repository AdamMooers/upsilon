/* Copyright 2023 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
/* This module is used to simulate direct memory access, where only
 * a small amount of memory is valid to read.
 */
module dma_sim #(
	parameter RAM_WID = 32,
	parameter RAM_WORD_WID = 16,
	parameter RAM_REAL_START = 32'h12340,
	parameter RAM_CNTR_LEN = 12,
	parameter TOTAL_RAM_WORD_MINUS_ONE = 4095,
	parameter DELAY_CNTR_LEN = 8,
	parameter DELAY_TOTAL = 12
) (
	input clk,

	/* DMA interface */
	input [RAM_WID-1:0] ram_dma_addr,
	output reg [RAM_WORD_WID-1:0] ram_word,
	input ram_read,
	output reg ram_valid,

	/*- Verilator interface */
	input [RAM_WORD_WID-1:0] backing_store[TOTAL_RAM_WORD_MINUS_ONE:0]
);

reg [DELAY_CNTR_LEN-1:0] delay_cntr = 0;

always @ (posedge clk) begin
	if (!ram_read) begin
		delay_cntr <= 0;
		ram_valid <= 0;
	end else if (delay_cntr < DELAY_TOTAL) begin
		delay_cntr <= delay_cntr + 1;
	end else if (!ram_valid) begin
		if (ram_dma_addr < RAM_REAL_START || ram_dma_addr > RAM_REAL_START + 2*TOTAL_RAM_WORD_MINUS_ONE) begin
			$display("ram_dma_addr %x out of bounds", ram_dma_addr);
			$stop();
		end else begin
			ram_word <= backing_store[(RAM_CNTR_LEN)'((ram_dma_addr - RAM_REAL_START)/2)];
			ram_valid <= 1;
		end
	end
end

endmodule
`undefineall
