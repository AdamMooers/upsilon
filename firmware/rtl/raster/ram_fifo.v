/* Implements a synchronous(!) FIFO using inferred Block RAM. This
 * must wrap "ram_fifo_dual_port" due to difficulties YOSYS has with
 * inferring Block RAM: refer to that module for details.
 */
`timescale 10ns/10ns
module ram_fifo #(
	parameter DAT_WID = 24,
	parameter FIFO_DEPTH_WID = 11,
	parameter [FIFO_DEPTH_WID-1:0] FIFO_DEPTH = 1500
) (
	input clk,
	input rst,

	input read_enable,
	input write_enable,

	input signed [DAT_WID-1:0] write_dat,
	output signed [DAT_WID-1:0] read_dat,
	output empty,
	output full
);

reg [FIFO_DEPTH_WID-1:0] fifo_size;
initial fifo_size = 0;
assign empty = fifo_size == 0;
assign full = fifo_size == FIFO_DEPTH;

ram_fifo_dual_port #(
	.DAT_WID(DAT_WID),
	.FIFO_DEPTH(FIFO_DEPTH),
	.FIFO_DEPTH_WID(FIFO_DEPTH_WID)
) m (
	.WCLK(clk),
	.RCLK(clk),
	.rst(rst),
	.read_enable(read_enable),
	.write_enable(write_enable),
	.write_dat(write_dat),
	.read_dat(read_dat)
);

always @ (posedge clk) begin
	if (rst) begin
		fifo_size <= 0;
	end else if (read_enable && !write_enable) begin
		fifo_size <= fifo_size - 1;
`ifdef VERILATOR
		if (fifo_size == 0) begin
			$error("fifo underflow");
		end
`endif
	end else if (write_enable && !read_enable) begin
		fifo_size <= fifo_size + 1;
`ifdef VERILATOR
		if (fifo_size == FIFO_DEPTH) begin
			$error("fifo overflow");
		end
`endif
	end
end

/*
`ifdef VERILATOR
initial begin
	$dumpfile("ram_fifo.vcd");
	$dumpvars;
end
`endif
*/

endmodule
