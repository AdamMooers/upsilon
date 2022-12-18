/* YOSYS has a difficult time infering single port BRAM. It can infer
 * double-port block ram, however. This module is written as a double
 * port block ram, even though both clocks will end up being the same.
 * TODO:
 *   "empty" and "full" status indiciators for simulation

 * https://stackoverflow.com/questions/62703942/trouble-getting-yosys-to-infer-block-ram-array-rather-than-using-logic-cells-v
 * The answer by "TinLethax" infers a BRAM.
 */
module ram_fifo_dual_port #(
	parameter DAT_WID = 24,
	parameter FIFO_DEPTH = 1500,
	parameter FIFO_DEPTH_WID = 11
) (
	input RCLK,
	input WCLK,
	input rst,

	input read_enable,
	input write_enable,

	input signed [DAT_WID-1:0] write_dat,
	output reg signed [DAT_WID-1:0] read_dat
);

reg [DAT_WID-1:0] memory [FIFO_DEPTH-1:0];
initial memory[0] = 24'b0;

/* Read domain */

reg [FIFO_DEPTH_WID-1:0] read_ptr = 0;
always @ (posedge RCLK) begin
	if (rst) begin
		read_ptr <= 0;
	end else if (read_enable) begin
		read_dat <= memory[read_ptr];
		if (read_ptr == FIFO_DEPTH-1)
			read_ptr <= 0;
		else
			read_ptr <= read_ptr + 1;
	end
end

/* Write domain */
reg [FIFO_DEPTH_WID-1:0] write_ptr = 0;
always @ (posedge WCLK) begin
	if (rst) begin
		write_ptr <= 0;
	end else if (write_enable) begin
		memory[write_ptr] <= write_dat;
		if (write_ptr == FIFO_DEPTH-1)
			write_ptr <= 0;
		else
			write_ptr <= write_ptr + 1;
	end
end

endmodule
