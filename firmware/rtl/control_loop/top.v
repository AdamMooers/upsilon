module top
#(
	parameter ADC_WID = 18,
	parameter DAC_WID = 24,
	parameter ADC_POLARITY = 1,
	parameter ADC_PHASE = 0,
	parameter DAC_DATA_WID = 20,
	parameter CONSTS_WID = 48,
	parameter DELAY_WID = 16
)(
	input clk,
	input arm,

	input signed [ADC_WID-1:0] measured_data,
	output signed [DAC_WID-1:0] output_data,
	input signed [ADC_WID-1:0] setpt,
	input signed [CONSTS_WID-1:0] alpha,
	input signed [CONSTS_WID-1:0] cl_p,
	input [DELAY_WID-1:0] dy,

	output signed [ADC_WID:0] err,
	output signed [CONSTS_WID-1:0] adj
);

wire adc_sck;
wire adc_ss;
wire adc_miso;
reg adc_finished = 0;

wire dac_mosi;
wire dac_sck;
wire dac_ss;
reg dac_finished = 0;

/* Emulate a control loop environment with simulator controlled
   SPI interfaces.
 */

/* ADC */
spi_slave_no_write #(
	.WID(ADC_WID),
	.WID_LEN(5),
	.ADC_POLARITY(ADC_POLARITY),
	.ADC_PHASE(ADC_PHASE)
)(
	.clk(clk),
	.to_master(measured_data),
	.sck(adc_sck),
	.ss_L(!adc_ss),
	.miso(adc_miso),
	.rdy(!dac_ss),
	.finished(adc_finished)
);

/* DAC */
spi_slave_no_read #(
	.WID(DAC_WID),
	.WID_LEN(5),
	.DAC_POLARITY(DAC_POLARITY),
	.DAC_PHASE(DAC_PHASE)
)(
	.clk(clk),
	.from_master(output_data),
	.mosi(dac_mosi),
	.sck(dac_sck),
	.ss_L(!dac_ss),
	.rdy(!dac_ss),
	.finished(dac_finished)
);

control_loop #(
	.ADC_WID(ADC_WID),
	.DAC_WID(DAC_WID),
	.DAC_DATA_WID(DAC_DATA_WID),
	.CONSTS_WID(CONSTS_WID),
	.DELAY_WID(DELAY_WID),
	.ADC_POLARITY(ADC_POLARITY),
	.ADC_PHASE(ADC_PHASE),
	.DAC_POLARITY(DAC_POLARITY),
	.DAC_PHASE(DAC_PHASE)
) cloop (
	.clk(clk),
	.arm(arm),

	.adc_sck(adc_sck),
	.adc_in(adc_miso),
	.adc_conv(adc_ss),

	.dac_sck(dac_sck),
	.dac_ss(dac_ss),
	.dac_out(dac_mosi),

	.setpt_in(setpt),
	.cl_alpha_in(alpha),
	.cl_p_in(cl),
	.delay_in(dy),

	.err(err_cur),
	.adj(adj)
);

endmodule
