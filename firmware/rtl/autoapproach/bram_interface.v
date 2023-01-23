module bram_interface #(
	parameter WORD_WID = 24,
	parameter WORD_AMNT_WID = 11,
	/* This is the last INDEX, not the LENGTH of the word array. */
	parameter [WORD_AMNT_WID-1:0] WORD_AMNT = 2047,
	parameter RAM_WID = 32,
	parameter RAM_WORD_WID = 16,
	parameter RAM_WORD_INCR = 2
) (
	input clk,

	/* autoapproach interface */
	output reg [WORD_WID-1:0] word,
	input word_next,
	output reg word_last,
	output reg word_ok,
	input word_rst,

	/* User interface */
	input refresh_start,
	input [RAM_WID-1:0] start_addr,
	output reg refresh_finished,

	/* RAM interface */
	output reg [RAM_WID-1:0] ram_dma_addr,
	input [RAM_WORD_WID-1:0] ram_word,
	output reg ram_read,
	input ram_valid
);

initial word = 0;
initial word_last = 0;
initial word_ok = 0;
initial refresh_finished = 0;
initial ram_dma_addr = 0;
initial ram_read = 0;

reg [WORD_WID-1:0] backing_buffer [WORD_AMNT:0];

localparam WAIT_ON_REFRESH = 0;
localparam READ_LOW_WORD = 1;
localparam READ_HIGH_WORD = 2;
localparam WAIT_ON_REFRESH_DEASSERT = 3;

reg [1:0] refresh_state = 0;
reg [WORD_AMNT_WID-1:0] word_cntr_refresh = 0;

always @ (posedge clk) case (refresh_state)
WAIT_ON_REFRESH: if (refresh_start) begin
	ram_dma_addr <= start_addr;
	refresh_state <= READ_LOW_WORD;
	word_cntr_refresh <= 0;
end
READ_LOW_WORD: if (!ram_read) begin
	ram_read <= 1;
end else if (ram_valid) begin
	refresh_state <= READ_HIGH_WORD;
	ram_dma_addr <= ram_dma_addr + RAM_WORD_INCR;
	ram_read <= 0;
	backing_buffer[word_cntr_refresh][RAM_WORD_WID-1:0] <= ram_word;
end
READ_HIGH_WORD: if (!ram_read) begin
	ram_read <= 1;
end else if (ram_valid) begin
	ram_dma_addr <= ram_dma_addr + RAM_WORD_INCR;
	ram_read <= 0;
	word_cntr_refresh <= word_cntr_refresh + 1;
	backing_buffer[word_cntr_refresh][WORD_WID-1:RAM_WORD_WID] <= ram_word[WORD_WID-RAM_WORD_WID-1:0];

	if (word_cntr_refresh == WORD_AMNT)
		refresh_state <= WAIT_ON_REFRESH_DEASSERT;
	else
		refresh_state <= READ_LOW_WORD;
end
WAIT_ON_REFRESH_DEASSERT: begin
	if (!refresh_start) begin
		refresh_finished <= 0;
		refresh_state <= WAIT_ON_REFRESH;
	end else begin
		refresh_finished <= 1;
	end
end
endcase

reg [WORD_AMNT_WID-1:0] auto_cntr = 0;

always @ (posedge clk) if (word_rst) begin
	auto_cntr <= 0;
end else if (word_next && !word_ok) begin
	if (refresh_state == WAIT_ON_REFRESH) begin
		word <= backing_buffer[auto_cntr];
		word_ok <= 1;
		if (auto_cntr == WORD_AMNT) begin
			auto_cntr <= 0;
			word_last <= 1;
		end else begin
			auto_cntr <= auto_cntr + 1;
			word_last <= 0;
		end
	end
end else if (!word_next && word_ok) begin
	word_ok <= 0;
end

`ifdef VERILATOR
initial begin
	$dumpfile("bram.fst");
	$dumpvars;
end
`endif

endmodule
