module adc_sim #(
	parameter POLARITY = 1,
	parameter PHASE = 0,
	parameter WID = 18,
	parameter WID_LEN = 5
) (
	input clk,

	input [WID-1:0] indat,
	output reg request,
	input fulfilled,
	output err,

	output miso,
	input sck,
	input ss_L
);

wire ss = !ss_L;
reg ss_raised = 0;
reg fulfilled_raised = 0;

reg ss_buf_L = 1;
reg [WID-1:0] data = 0;
reg rdy = 0;
wire spi_fin;

always @ (posedge clk) begin
	if (ss && !ss_raised) begin
		request <= 1;
		ss_raised <= 1;
	end else if (ss_raised && !ss) begin
		ss_raised <= 0;
		ss_buf_L <= 1;
		rdy <= 0;
		request <= 0;
		fulfilled_raised <= 0;
	end else if (ss_raised && request && fulfilled && !fulfilled_raised) begin
		data <= indat;
		fulfilled_raised <= 1;
		request <= 0;
		rdy <= 1;
	end else if (ss_raised && !fulfilled && fulfilled_raised) begin
		fulfilled_raised <= 0;
		ss_buf_L <= 0;
	end else if (spi_fin) begin
		rdy <= 0;
	end
end

spi_slave_no_read #(
	.WID(WID),
	.WID_LEN(WID_LEN),
	.POLARITY(POLARITY),
	.PHASE(PHASE)
) spi (
	.clk(clk),
	.sck(sck),
	.ss_L(ss_buf_L),
	.miso(miso),
	.to_master(data),
	.finished(spi_fin),
	.rdy(rdy),
	.err(err)
);

endmodule
`undefineall
