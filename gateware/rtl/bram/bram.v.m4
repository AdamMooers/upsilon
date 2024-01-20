m4_changequote(`⟨', `⟩')
m4_changecom(⟨/*⟩, ⟨*/⟩)

/* Copyright 2024 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 *
 * BRAM to Wishbone interface.
 */
module bram_interface #(
	/* This is the last INDEX of the word array, which is indexed in
	 * words, not octets. */
	parameter [WORD_AMNT_WID-1:0] WORD_AMNT = 2047,
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
	input [BUS_WID-1:0] wb_data_i,
	output reg wb_ack,
	output wb_stall,
	output reg [BUS_WID-1:0] wb_data_o,
);

assign wb_stall = wb_ack;

reg [BUS_WID-1:0] buffer [WORD_AMNT:0];

m4_define(⟨bufwrite⟩,  ⟨begin
	buffer[mem_addr & ADDR_MASK] <=
		(buffer[wb_addr & ADDR_MASK] & $1)
		| wb_data_i[$2];
end⟩)

always @ (posedge clk) if (wb_cyc && wb_stb && !wb_ack)
	if (!wb_we) begin
		wb_data_o <= buffer[wb_addr & ADDR_MASK];
		wb_ack <= 1;
	end else begin
		wb_ack <= 1;
		case (wb_sel)
		4'b1111: buffer[wb_addr & ADDR_MASK] <= wb_data_o;
		4'b0001: bufwrite(32'hFFFFFF00, 7:0)
		4'b0010: bufwrite(32'hFFFF00FF, 15:8)
		4'b0011: bufwrite(32'hFFFF0000, 15:0)
		4'b0100: bufwrite(32'hFF00FFFF, 23:16)
		4'b1000: bufwrite(32'h00FFFFFF, 31:24)
		4'b1100: bufwrite(32'h0000FFFF, 31:16)
		default: mem_ready <= 1;
		endcase
	end
else if (!wb_stb) begin
	wb_ack <= 0;
end

endmodule
