`include "control_loop_cmds.vh"

module control_loop_sim_top #(
	parameter ADC_WID = 18,
	parameter ADC_WID_SIZ = 5,
	parameter ADC_POLARITY = 1,
	parameter ADC_PHASE = 0,

	parameter DAC_POLARITY = 0,
	parameter DAC_PHASE = 1,
	parameter DAC_DATA_WID = 20,
	parameter DAC_WID = 24,
	parameter DAC_WID_SIZ = 5,

	parameter CONSTS_WHOLE = 21,
	parameter CONSTS_FRAC = 43,
`define CONSTS_WID (CONSTS_WHOLE + CONSTS_FRAC)
	parameter CONSTS_SIZ = 7,
	parameter DELAY_WID = 16
)(
	input clk,

	output [DAC_DATA_WID-1:0] curset,
	output dac_err,

	input [ADC_WID-1:0] measured_value,
	output request,
	input fulfilled,
	output adc_err,

	input [`CONSTS_WID-1:0] word_into_loop,
	output [`CONSTS_WID-1:0] word_outof_loop,
	input start_cmd,
	output finish_cmd,
	input [`CONTROL_LOOP_CMD_WIDTH-1:0] cmd
);

/* Emulate a control loop environment with simulator controlled
   SPI interfaces.
 */

wire adc_miso;
wire adc_sck;
wire adc_ss_L;

/* ADC */

adc_sim #(
	.WID(ADC_WID),
	.WID_LEN(5),
	.POLARITY(ADC_POLARITY),
	.PHASE(ADC_PHASE)
) adc (
	.clk(clk),
	.indat(measured_value),
	.request(request),
	.fulfilled(fulfilled),
	.err(adc_err),

	.miso(adc_miso),
	.sck(adc_sck),
	.ss_L(adc_ss_L)
);

wire dac_miso;
wire dac_mosi;
wire dac_ss_L;
wire dac_sck;

/* DAC */
dac_sim #(
	.WID(DAC_WID),
	.DATA_WID(DAC_DATA_WID),
	.WID_LEN(5),
	.POLARITY(DAC_POLARITY),
	.PHASE(DAC_PHASE)
) dac (
	.clk(clk),
	.curset(curset),
	.mosi(dac_mosi),
	.miso(dac_miso),
	.sck(dac_sck),
	.ss_L(dac_ss_L),
	.err(dac_err)
);

control_loop #(
	.ADC_WID(ADC_WID),
	.ADC_WID_SIZ(ADC_WID_SIZ),
	.ADC_POLARITY(ADC_POLARITY),
	.ADC_PHASE(ADC_PHASE),
	/* Keeping cycle half wait and conv wait the same
	 * since it doesn't matter for this simulation */

	.CONSTS_WHOLE(CONSTS_WHOLE),
	.CONSTS_FRAC(CONSTS_FRAC),
	.CONSTS_SIZ(CONSTS_SIZ),
	.DELAY_WID(DELAY_WID),

	.DAC_WID(DAC_WID),
	.DAC_WID_SIZ(DAC_WID_SIZ),
	.DAC_DATA_WID(DAC_DATA_WID),
	.DAC_POLARITY(DAC_POLARITY),
	.DAC_PHASE(DAC_PHASE)
) cloop (
	.clk(clk),
	.dac_mosi(dac_mosi),
	.dac_miso(dac_miso),
	.dac_ss_L(dac_ss_L),
	.dac_sck(dac_sck),

	.adc_miso(adc_miso),
	.adc_conv_L(adc_ss_L),
	.adc_sck(adc_sck),

	.word_in(word_into_loop),
	.word_out(word_outof_loop),
	.start_cmd(start_cmd),
	.finish_cmd(finish_cmd),
	.cmd(cmd)
);

`ifdef VERILATOR
initial begin
	$dumpfile("control_loop.fst");
	$dumpvars;
end
`endif

endmodule
`undefineall
