m4_changequote(`⟨', `⟩')
m4_changecom(⟨/*⟩, ⟨*/⟩)

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
	output reg [BUS_WID-1:0] wb_dat_r,
);

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
reg [WORD_WID-1:0] buffer [(ADDR_MASK >> 2):0];

/* Current index into the buffer. */
wire [13-1:0] ind = (wb_addr & ADDR_MASK) >> 2;

m4_define(⟨bufwrite⟩,  ⟨begin
	buffer[ind] <= (buffer[ind] & $1) | wb_dat_w[$2];
end⟩)

always @ (posedge clk) if (wb_cyc && wb_stb && !wb_ack)
	if (!wb_we) begin
		wb_dat_r <= buffer[ind];
		wb_ack <= 1;
	end else begin
		wb_ack <= 1;
		case (wb_sel)
		4'b1111: buffer[ind] <= wb_dat_w;
		4'b0011: bufwrite(32'hFFFF0000, 15:0)
		4'b1100: bufwrite(32'h0000FFFF, 31:16)
		4'b0001: bufwrite(32'hFFFFFF00, 7:0)
		4'b0010: bufwrite(32'hFFFF00FF, 15:8)
		4'b0100: bufwrite(32'hFF00FFFF, 23:16)
		4'b1000: bufwrite(32'h00FFFFFF, 31:24)
		default: ;
		endcase
	end
else if (!wb_stb) begin
	wb_ack <= 0;
end

endmodule
