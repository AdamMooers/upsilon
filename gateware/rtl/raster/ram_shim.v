/* Copyright 2023 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
/* Ram shim. This is an interface designed for a LiteX RAM DMA module.
 * It can also be connected to a simulator.
 *
 * The read end is implemented in C since all of this is backed by memory.
 *
 * In between the system RAM and the raster scan is a block RAM FIFO so
 * scanning is not interrupted by transient RAM accesses from the system.
 *
 * THIS MODULE ASSUMES that RAM_WORD < DAT_WID < RAM_WORD*2.
 */
`include "ram_shim_cmds.vh"
`timescale 10ns/10ns
module ram_shim #(
	parameter DAT_WID = 24,
	parameter RAM_WORD = 16,
	parameter RAM_WID = 32
) (
	input clk,
	input rst,

	/* Raster control interface. The kernel allocates memory and informs the
	 * shim what the memory location is, and how long it is (max certain length).
	 * This is also where the current write pointer is found so that the
	 * kernel can read data from the scanner into memory and out to the
	 * controlling computer. */
	input [RAM_WID-1:0] cmd_data,
	input [`RAM_SHIM_CMD_WID-1:0] cmd,
	input cmd_active,
	output reg cmd_finished,
	output [RAM_WID-1:0] cmd_data_out,

	input [DAT_WID-1:0] data,
	input data_commit,
	output reg finished,

`ifdef RAM_SHIM_DEBUG
	wire fifo_steady,
`endif

	/* RAM DMA interface. */
	output reg [RAM_WORD-1:0] word,
	output [RAM_WID-1:0] addr,
	output reg write,
	input valid
);

/* Control interface code.
 * Each of these are BYTE level addresses. Most numbers in Verilog are
 * BITS. When converting from bits to bytes, divide by 8. */

reg [RAM_WID-1:0] loc_start = 0;
reg [RAM_WID-1:0] loc_len = 0;
reg [RAM_WID-1:0] loc_off = 0;

assign addr = loc_start + loc_off;

always @ (posedge clk) begin
	if (cmd_active && !cmd_finished) case (cmd)
	`RAM_SHIM_WRITE_LOC: begin
		loc_start <= cmd_data;
		loc_off <= 0;
		cmd_finished <= 1;
	end
	`RAM_SHIM_WRITE_LEN: begin
		loc_len <= cmd_data;
		loc_off <= 0;
		cmd_finished <= 1;
	end
	`RAM_SHIM_READ_PTR: begin
		cmd_data_out <= addr;
		cmd_finished <= 1;
	end
	endcase else begin
		cmd_finished <= 0;
	end
end

/* Block RAM FIFO controller. */

reg read_enable = 0;
reg write_enable = 0;
reg [DAT_WID-1:0] write_dat = 0;
wire [DAT_WID-1:0] read_dat;
wire empty;
wire full;
ram_fifo #(
	.DAT_WID(DAT_WID)
) pre_fifo (
	.clk(clk),
	.rst(rst),
	.read_enable(read_enable),
	.write_enable(write_enable),
	.write_dat(write_dat),
	.read_dat(read_dat),
	.empty(empty),
	.full(full)
);

/* Code to take data from Block RAM and put it into System RAM. */

localparam WAIT_ON_EMPTY = 0;
localparam READ_OFF_FIFO = 1;
localparam HIGH_WORD_LOAD = 2;
localparam WAIT_ON_HIGH_WORD = 3;
reg [1:0] writestate = WAIT_ON_EMPTY;

/* Originally the simulation code checked if the intermediate FIFO was
 * empty, and then stopped running the simulation. This led to an off
 * by one error where the very last value pushed was not read. Instead,
 * the simulator now checks for steady-ness, which means that the always
 * block has idled at the WAIT_ON_EMPTY state for two cycles.
 */
`ifdef RAM_SHIM_DEBUG
reg [1:0] prev_writestate;
always @ (posedge clk) prev_writestate <= writestate;
assign fifo_steady = prev_writestate == WAIT_ON_EMPTY && writestate == WAIT_ON_EMPTY;
`endif

always @ (posedge clk) begin
	case (writestate)
	WAIT_ON_EMPTY: if (!empty) begin
		writestate <= READ_OFF_FIFO;
		/* This value is raised on the at the beginning of the
		 * next clock cycle. A read takes one clock cycle, so
		 * the next clock cycle has to disarm read_enable, and
		 * then the cycle *after that* must read the data from
		 * the FIFO.
		 */
		read_enable <= 1;
	end
	READ_OFF_FIFO: if (read_enable) begin
		read_enable <= 0;
	end else begin
		word <= read_dat[RAM_WORD-1:0];
		write <= 1;
		writestate <= HIGH_WORD_LOAD;
	end
	HIGH_WORD_LOAD: if (valid) begin
		if (loc_off == loc_len - 1)
			loc_off <= 0;
		else
			loc_off <= loc_off + RAM_WORD/8;

		write <= 0;
		word <= {{(RAM_WORD*2 - DAT_WID){read_dat[DAT_WID-1]}},
		         read_dat[DAT_WID-1:RAM_WORD]};
		writestate <= WAIT_ON_HIGH_WORD;
	end
	WAIT_ON_HIGH_WORD: if (!write) begin
		write <= 1;
	end else if (valid) begin
		if (loc_off == loc_len - 1)
			loc_off <= 0;
		else
			loc_off <= loc_off + RAM_WORD/8;
		writestate <= WAIT_ON_EMPTY;
		write <= 0;
	end
	endcase
end

/* read to memory */
always @ (posedge clk) begin
	if (data_commit && !write_enable && !full) begin
		write_dat <= data;
		write_enable <= 1;
	end else if (data_commit && write_enable) begin
		write_enable <= 0;
		finished <= 1;
	end else if (!data_commit && finished) begin
		finished <= 0;
		write_enable <= 0;
	end
end

/*
`ifdef VERILATOR
initial begin
	$dumpfile("ram_shim.vcd");
	$dumpvars;
end
`endif
*/

endmodule
