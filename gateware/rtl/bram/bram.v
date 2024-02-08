/* Copyright 2024 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 *
 * This BRAM can only handle aligned accesses.
 */
module bram #(
	/* Width of the memory bus */
	parameter BUS_WID = 32,
	/* Width of a request. */
	parameter WORD_WID = 32,
	/* Bitmask used to extract the RAM location in the buffer. */
	parameter ADDR_MASK = 32'h1FFF
) (
	input clk,

	input wb_cyc,
	input wb_stb,
	input wb_we,
	input [4-1:0] wb_sel,
	input [BUS_WID-1:0] wb_addr,
	input [BUS_WID-1:0] wb_dat_w,
	output reg wb_ack,
	output reg [BUS_WID-1:0] wb_dat_r
);

initial wb_ack <= 0;
initial wb_dat_r <= 0;

/* When the size of the memory is a power of 2, the mask is the
 * last addressable index in the array.
 *
 * Since this buffer stores words, this is divided by 4 (32 bits).
 * When accessing a single byte, the address
 * 0b......Xab
 * is shifted to the right by two bits, throwing away "ab". This indexes
 * the 32 bit word that contains the address. This applies to halfwords
 * and words as long as the accesses are aligned.
 */
(* ram_style = "block" *)
reg [WORD_WID-1:0] buffer [(ADDR_MASK >> 2):0];

/* Current index into the buffer. */
wire [13-1:0] ind = (wb_addr & ADDR_MASK) >> 2;

always @ (posedge clk) if (wb_cyc && wb_stb && !wb_ack) begin
	wb_ack <= 1;
	if (wb_we) begin
		if (wb_sel[0])
			buffer[ind][7:0] <= wb_dat_w[7:0];
		if (wb_sel[1])
			buffer[ind][15:8] <= wb_dat_w[15:8];
		if (wb_sel[2])
			buffer[ind][23:16] <= wb_dat_w[23:16];
		if (wb_sel[3])
			buffer[ind][31:24] <= wb_dat_w[31:24];
	end else begin
		wb_dat_r <= buffer[ind];
	end
end else if (!wb_stb) begin
	wb_ack <= 0;
end

endmodule
