/* Ram shim. This is an interface designed for a LiteX RAM
 * DMA module. It can also be connected to a simulator.
 *
 * The read end is implemented in C since all of this is
 * backed by memory.
 *
 * THIS MODULE ASSUMES that RAM_WORD < DAT_WID < RAM_WORD*2.
 *
 * TODO: Buffer the data (using something like block ram) and
 * write it out asynchronously. This will require instantiating
 * the block ram primitive directly for Yosys. This should make
 * writes to RAM smoother, and reads smoother when the CPU is
 * reading the data.
 */
module ram_shim #(
	parameter BASE_ADDR = 32'h1000000,
	parameter MAX_BYTE_WID = 13,
	parameter DAT_WID = 24,
	parameter RAM_WORD = 16,
	parameter RAM_WID = 32
) (
	input clk,
	input signed [DAT_WID-1:0] data,
	input commit,
	output reg finished,

	/* Used by the kernel code to request the current
	 * location of the FIFO head. Used to memcpy data,
	 * it might better than repeatedly calling a FIFO
	 * read.
	 */
	input read_end_req_off,
	output reg [RAM_WID-1:0] read_end_addr,
	output reg read_end_req_valid,

	output reg [RAM_WORD-1:0] word,
	output [RAM_WID-1:0] addr,
	output reg write,
	input valid
);

localparam WAIT_ON_COMMIT = 0;
localparam HIGH_WORD_LOAD = 1;
localparam WAIT_ON_HIGH_WORD = 2;
localparam WAIT_ON_COMMIT_DEASSERT = 3;
reg [2:0] state = WAIT_ON_COMMIT;

reg [MAX_BYTE_WID-1:0] offset = 0;
assign addr = BASE_ADDR + {{(RAM_WID - MAX_BYTE_WID){1'b0}}, offset};
initial read_end_req_valid = 0;

always @ (posedge clk) begin
	if (read_end_req_off && !read_end_req_valid) begin
		read_end_req_valid = 1;
		read_end_addr <= addr;
	end else if (read_end_req_valid && !read_end_req_off) begin
		read_end_req_valid <= 0;
	end
end

always @ (posedge clk) begin
	case (state)
	WAIT_ON_COMMIT: if (commit) begin
		word <= data[RAM_WORD-1:0];
		write <= 1;
		state <= HIGH_WORD_LOAD;
	end
	HIGH_WORD_LOAD: if (valid) begin
		offset <= offset + (RAM_WORD/2);
		write <= 0;
		word <= {{(RAM_WORD*2 - DAT_WID){data[DAT_WID-1]}},
		         data[DAT_WID-1:RAM_WORD]};
		state <= WAIT_ON_HIGH_WORD;
	end
	WAIT_ON_HIGH_WORD: if (!write) begin
		write <= 1;
	end else if (valid) begin
		offset <= offset + (RAM_WORD / 2);
		state <= WAIT_ON_COMMIT_DEASSERT;
		finished <= 1;
	end
	WAIT_ON_COMMIT_DEASSERT: if (!commit) begin
		finished <= 0;
	end
	endcase
end

endmodule
