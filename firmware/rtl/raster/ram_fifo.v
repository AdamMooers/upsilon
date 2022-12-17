module ram_fifo #(
	parameter DAT_WID = 24,
	parameter FIFO_DEPTH = 1500,
	parameter FIFO_DEPTH_WID = 11
) (
	input clk,
	input rst,

	input read_enable,
	input write_enable,

	input signed [DAT_WID-1:0] write_dat,
	output signed [DAT_WID-1:0] read_dat
);

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

endmodule
