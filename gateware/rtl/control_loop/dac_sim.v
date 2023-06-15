/* Copyright 2023 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
module dac_sim #(
	parameter POLARITY = 0,
	parameter PHASE = 1,
	parameter WID = 24,
	parameter DATA_WID = 20,
	parameter WID_LEN = 5
) (
	input clk,
	input rst_L,

	output reg [DATA_WID-1:0] curset,

	input mosi,
	output miso,
	input sck,
	input ss_L,
	output err
);

wire [WID-1:0] from_master;
reg [WID-1:0] to_master = 0;
reg rdy = 1;
wire spi_fin;
reg [WID-4-1:0] ctrl_register = 0;

always @ (posedge clk) begin
	if (!rst_L) begin
		curset <= 0;
		to_master <= 0;
		rdy <= 0;
		ctrl_register <= 0;
	end else if (spi_fin) begin
		rdy <= 0;
		case (from_master[WID-1:WID-4])
		4'b1001: begin
			to_master <= {4'b1001, curset};
		end
		4'b0001: begin
			curset <= from_master [DATA_WID-1:0];
			to_master <= 0;
		end
		4'b0010: begin
			ctrl_register <= to_master[WID-1-4:0];
			to_master <= 0;
		end
		4'b1010: begin
			to_master <= {4'b1010, ctrl_register};
		end
		default: to_master <= 0;
		endcase
	end else if (!rdy) begin
		rdy <= 1;
	end
end

spi_slave #(
	.WID(WID),
	.WID_LEN(WID_LEN),
	.POLARITY(POLARITY),
	.PHASE(PHASE)
) spi (
	.clk(clk),
	.sck(sck),
	.ss_L(ss_L),
	.rst_L(rst_L),
	.miso(miso),
	.mosi(mosi),
	.from_master(from_master),
	.to_master(to_master),
	.finished(spi_fin),
	.rdy(rdy),
	.err(err)
);

endmodule
`undefineall
