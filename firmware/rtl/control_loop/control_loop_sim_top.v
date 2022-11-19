`include control_loop_cmds.vh

module top
#(
	parameter ADC_WID = 18,
	parameter ADC_WID_LEN = 5,
	parameter ADC_POLARITY = 1,
	parameter ADC_PHASE = 0,
	parameter ADC_CYCLE_HALF_WAIT = 5,
	parameter ADC_TIMER_LEN = 3,

	parameter DAC_POLARITY = 0,
	parameter DAC_PHASE = 1,
	parameter DAC_DATA_WID = 20,
	parameter DAC_WID = 24,
	parameter DAC_WID_LEN = 5,
	parameter DAC_CYCLE_HALF_WAIT = 10,
	parameter DAC_TIMER_LEN = 4,

	parameter CONSTS_WID = 48,
	parameter DELAY_WID = 16
)(
	input clk,

	input signed [ADC_WID-1:0] measured_data,
	input [DAC_DATA_WID-1:0] dac_in,
	output [DAC_DATA_WID-1:0] dac_out,
	output dac_input_ready,

	input [CONSTS_WID-1:0] word_into_loop,
	output [CONSTS_WID-1:0] word_outof_loop,
	input start_cmd,
	output finish_cmd,
	input [CONTROL_LOOP_CMD_WIDTH-1:0] cmd
);

wire dac_miso;
wire dac_mosi;
wire dac_sck;
wire ss_L;

spi_master #(
	.WID(DAC_WID),
	.WID_LEN(DAC_WID_LEN),
	.POLARITY(DAC_POLARITY),
	.PHASE(DAC_PHASE),
	.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
	.TIMER_LEN(DAC_TIMER_LEN)
) dac_master (
	.clk(clk),
	.from_slave(dac_set_data),
	.miso(dac_miso),
	.to_slave(
	.mosi(dac_mosi),

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

);

endmodule
