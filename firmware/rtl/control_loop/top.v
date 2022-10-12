module top
#(
	parameter ADC_WID = 18,
	parameter DAC_WID = 24,
	parameter ADC_POLARITY = 1,
	parameter ADC_PHASE = 0,
	parameter DAC_DATA_WID = 20,
	parameter CONSTS_WID = 48,
	parameter DELAY_WID = 16
(
	input clk,
	input signed [ADC_WID-1:0] read_data,
	output signed [DAC_WID-1:0] write_data,
	input signed [ADC_WID-1:0] setpt,
	input signed [CONSTS_WID-1:0] alpha,
	input signed [CONSTS_WID-1:0] cl_p,
	input [DELAY_WID-1:0] dy,

	output signed [ADC_WID:0] err,
	output signed [CONSTS_WID-1:0] adj
);

wire adc_sck;
wire adc_ss;
wire adc_mosi;

spi_slave_no_write #(
	.WID(ADC_WID),
	.WID(5),
	.

control_loop #(
	.ADC_WID(ADC_WID),
	.DAC_WID(DAC_WID),
	.DAC_DATA_WID(DAC_DATA_WID),
	.CONSTS_WID(CONSTS_WID),
	.DELAY_WID(DELAY_WID)
) cloop (

);

endmodule
