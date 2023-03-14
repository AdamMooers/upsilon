`line base.m4 1 0


/*********************************************************/
/********************** M4 macros ************************/
/*********************************************************/
`line base.m4 23 0


`line base.m4 29 0


`line base.m4 104 0


`line base.m4 125 0


/*********************************************************/
/*********************** Verilog *************************/
/*********************************************************/

`include "control_loop_cmds.vh"
module base #(
	parameter DAC_PORTS = 2,
`define DAC_PORTS_CONTROL_LOOP (DAC_PORTS + 1)

	parameter DAC_NUM = 8,
	parameter DAC_WID = 24,
	parameter DAC_DATA_WID = 20,
	parameter DAC_WID_SIZ = 5,
	parameter DAC_POLARITY = 0,
	parameter DAC_PHASE = 1,
	parameter DAC_CYCLE_HALF_WAIT = 10,
	parameter DAC_CYCLE_HALF_WAIT_SIZ = 4,
	parameter DAC_SS_WAIT = 5,
	parameter DAC_SS_WAIT_SIZ = 3,
	parameter WF_TIMER_WID = 32,
	parameter WF_WORD_WID = 20,
	parameter WF_WORD_AMNT_WID = 11,
	parameter [WF_WORD_AMNT_WID-1:0] WF_WORD_AMNT = 2047,
	parameter WF_RAM_WID = 32,
	parameter WF_RAM_WORD_WID = 16,
	parameter WF_RAM_WORD_INCR = 2,

	parameter ADC_PORTS = 1,
`define ADC_PORTS_CONTROL_LOOP (ADC_PORTS + 1)
	parameter ADC_NUM = 8,
	/* Three types of ADC. For now assume that their electronics
	 * are similar enough, just need different numbers for the width.
	 */
	parameter ADC_TYPE1_WID = 18,
	parameter ADC_TYPE2_WID = 16,
	parameter ADC_TYPE3_WID = 24,
	parameter ADC_WID_SIZ = 5,
	parameter ADC_CYCLE_HALF_WAIT = 5,
	parameter ADC_CYCLE_HALF_WAIT_SIZ = 3,
	parameter ADC_POLARITY = 1,
	parameter ADC_PHASE = 0,
	/* The ADC takes maximum 527 ns to capture a value.
	 * The clock ticks at 10 ns. Change for different clocks!
	 */
	parameter ADC_CONV_WAIT = 53,
	parameter ADC_CONV_WAIT_SIZ = 6,

	parameter CL_CONSTS_WHOLE = 21,
	parameter CL_CONSTS_FRAC = 43,
	parameter CL_CONSTS_SIZ = 7,
	parameter CL_DELAY_WID = 16,
`define CL_CONSTS_WID (CL_CONSTS_WHOLE + CL_CONSTS_FRAC)
`define CL_DATA_WID `CL_CONSTS_WID
	parameter CL_READ_DAC_DELAY = 5,
	parameter CL_CYCLE_COUNT_WID = 18
) (
	input clk,

	output [DAC_NUM-1:0] dac_mosi,
	input  [DAC_NUM-1:0] dac_miso,
	output [DAC_NUM-1:0] dac_sck,
	output [DAC_NUM-1:0] dac_ss_L,

	output [ADC_NUM-1:0] adc_conv,
	input [ADC_NUM-1:0] adc_sdo,
	output [ADC_NUM-1:0] adc_sck,

	
`line base.m4 194 0
	input [`DAC_PORTS_CONTROL_LOOP-1:0] dac_sel_0,
`line base.m4 194 0
	output dac_finished_0,
`line base.m4 194 0
	input dac_arm_0,
`line base.m4 194 0
	output [DAC_WID-1:0] from_dac_0,
`line base.m4 194 0
	input [DAC_WID-1:0] to_dac_0,
`line base.m4 194 0

`line base.m4 194 0
	input wf_arm_0,
`line base.m4 194 0
	input [WF_TIMER_WID-1:0] wf_time_to_wait_0,
`line base.m4 194 0
	input wf_refresh_start_0,
`line base.m4 194 0
	input [WF_RAM_WID-1:0] wf_start_addr_0,
`line base.m4 194 0
	output wf_refresh_finished_0,
`line base.m4 194 0

`line base.m4 194 0
	output [WF_RAM_WID-1:0] wf_ram_dma_addr_0,
`line base.m4 194 0
	input [WF_RAM_WORD_WID-1:0] wf_ram_word_0,
`line base.m4 194 0
	output wf_ram_read_0,
`line base.m4 194 0
	input wf_ram_valid_0
`line base.m4 194 0
,
	
`line base.m4 195 0
	input [DAC_PORTS-1:0] dac_sel_1,
`line base.m4 195 0
	output dac_finished_1,
`line base.m4 195 0
	input dac_arm_1,
`line base.m4 195 0
	output [DAC_WID-1:0] from_dac_1,
`line base.m4 195 0
	input [DAC_WID-1:0] to_dac_1,
`line base.m4 195 0

`line base.m4 195 0
	input wf_arm_1,
`line base.m4 195 0
	input [WF_TIMER_WID-1:0] wf_time_to_wait_1,
`line base.m4 195 0
	input wf_refresh_start_1,
`line base.m4 195 0
	input [WF_RAM_WID-1:0] wf_start_addr_1,
`line base.m4 195 0
	output wf_refresh_finished_1,
`line base.m4 195 0

`line base.m4 195 0
	output [WF_RAM_WID-1:0] wf_ram_dma_addr_1,
`line base.m4 195 0
	input [WF_RAM_WORD_WID-1:0] wf_ram_word_1,
`line base.m4 195 0
	output wf_ram_read_1,
`line base.m4 195 0
	input wf_ram_valid_1
`line base.m4 195 0
,
	
`line base.m4 196 0
	input [DAC_PORTS-1:0] dac_sel_2,
`line base.m4 196 0
	output dac_finished_2,
`line base.m4 196 0
	input dac_arm_2,
`line base.m4 196 0
	output [DAC_WID-1:0] from_dac_2,
`line base.m4 196 0
	input [DAC_WID-1:0] to_dac_2,
`line base.m4 196 0

`line base.m4 196 0
	input wf_arm_2,
`line base.m4 196 0
	input [WF_TIMER_WID-1:0] wf_time_to_wait_2,
`line base.m4 196 0
	input wf_refresh_start_2,
`line base.m4 196 0
	input [WF_RAM_WID-1:0] wf_start_addr_2,
`line base.m4 196 0
	output wf_refresh_finished_2,
`line base.m4 196 0

`line base.m4 196 0
	output [WF_RAM_WID-1:0] wf_ram_dma_addr_2,
`line base.m4 196 0
	input [WF_RAM_WORD_WID-1:0] wf_ram_word_2,
`line base.m4 196 0
	output wf_ram_read_2,
`line base.m4 196 0
	input wf_ram_valid_2
`line base.m4 196 0
,
	
`line base.m4 197 0
	input [DAC_PORTS-1:0] dac_sel_3,
`line base.m4 197 0
	output dac_finished_3,
`line base.m4 197 0
	input dac_arm_3,
`line base.m4 197 0
	output [DAC_WID-1:0] from_dac_3,
`line base.m4 197 0
	input [DAC_WID-1:0] to_dac_3,
`line base.m4 197 0

`line base.m4 197 0
	input wf_arm_3,
`line base.m4 197 0
	input [WF_TIMER_WID-1:0] wf_time_to_wait_3,
`line base.m4 197 0
	input wf_refresh_start_3,
`line base.m4 197 0
	input [WF_RAM_WID-1:0] wf_start_addr_3,
`line base.m4 197 0
	output wf_refresh_finished_3,
`line base.m4 197 0

`line base.m4 197 0
	output [WF_RAM_WID-1:0] wf_ram_dma_addr_3,
`line base.m4 197 0
	input [WF_RAM_WORD_WID-1:0] wf_ram_word_3,
`line base.m4 197 0
	output wf_ram_read_3,
`line base.m4 197 0
	input wf_ram_valid_3
`line base.m4 197 0
,
	
`line base.m4 198 0
	input [DAC_PORTS-1:0] dac_sel_4,
`line base.m4 198 0
	output dac_finished_4,
`line base.m4 198 0
	input dac_arm_4,
`line base.m4 198 0
	output [DAC_WID-1:0] from_dac_4,
`line base.m4 198 0
	input [DAC_WID-1:0] to_dac_4,
`line base.m4 198 0

`line base.m4 198 0
	input wf_arm_4,
`line base.m4 198 0
	input [WF_TIMER_WID-1:0] wf_time_to_wait_4,
`line base.m4 198 0
	input wf_refresh_start_4,
`line base.m4 198 0
	input [WF_RAM_WID-1:0] wf_start_addr_4,
`line base.m4 198 0
	output wf_refresh_finished_4,
`line base.m4 198 0

`line base.m4 198 0
	output [WF_RAM_WID-1:0] wf_ram_dma_addr_4,
`line base.m4 198 0
	input [WF_RAM_WORD_WID-1:0] wf_ram_word_4,
`line base.m4 198 0
	output wf_ram_read_4,
`line base.m4 198 0
	input wf_ram_valid_4
`line base.m4 198 0
,
	
`line base.m4 199 0
	input [DAC_PORTS-1:0] dac_sel_5,
`line base.m4 199 0
	output dac_finished_5,
`line base.m4 199 0
	input dac_arm_5,
`line base.m4 199 0
	output [DAC_WID-1:0] from_dac_5,
`line base.m4 199 0
	input [DAC_WID-1:0] to_dac_5,
`line base.m4 199 0

`line base.m4 199 0
	input wf_arm_5,
`line base.m4 199 0
	input [WF_TIMER_WID-1:0] wf_time_to_wait_5,
`line base.m4 199 0
	input wf_refresh_start_5,
`line base.m4 199 0
	input [WF_RAM_WID-1:0] wf_start_addr_5,
`line base.m4 199 0
	output wf_refresh_finished_5,
`line base.m4 199 0

`line base.m4 199 0
	output [WF_RAM_WID-1:0] wf_ram_dma_addr_5,
`line base.m4 199 0
	input [WF_RAM_WORD_WID-1:0] wf_ram_word_5,
`line base.m4 199 0
	output wf_ram_read_5,
`line base.m4 199 0
	input wf_ram_valid_5
`line base.m4 199 0
,
	
`line base.m4 200 0
	input [DAC_PORTS-1:0] dac_sel_6,
`line base.m4 200 0
	output dac_finished_6,
`line base.m4 200 0
	input dac_arm_6,
`line base.m4 200 0
	output [DAC_WID-1:0] from_dac_6,
`line base.m4 200 0
	input [DAC_WID-1:0] to_dac_6,
`line base.m4 200 0

`line base.m4 200 0
	input wf_arm_6,
`line base.m4 200 0
	input [WF_TIMER_WID-1:0] wf_time_to_wait_6,
`line base.m4 200 0
	input wf_refresh_start_6,
`line base.m4 200 0
	input [WF_RAM_WID-1:0] wf_start_addr_6,
`line base.m4 200 0
	output wf_refresh_finished_6,
`line base.m4 200 0

`line base.m4 200 0
	output [WF_RAM_WID-1:0] wf_ram_dma_addr_6,
`line base.m4 200 0
	input [WF_RAM_WORD_WID-1:0] wf_ram_word_6,
`line base.m4 200 0
	output wf_ram_read_6,
`line base.m4 200 0
	input wf_ram_valid_6
`line base.m4 200 0
,
	
`line base.m4 201 0
	input [DAC_PORTS-1:0] dac_sel_7,
`line base.m4 201 0
	output dac_finished_7,
`line base.m4 201 0
	input dac_arm_7,
`line base.m4 201 0
	output [DAC_WID-1:0] from_dac_7,
`line base.m4 201 0
	input [DAC_WID-1:0] to_dac_7,
`line base.m4 201 0

`line base.m4 201 0
	input wf_arm_7,
`line base.m4 201 0
	input [WF_TIMER_WID-1:0] wf_time_to_wait_7,
`line base.m4 201 0
	input wf_refresh_start_7,
`line base.m4 201 0
	input [WF_RAM_WID-1:0] wf_start_addr_7,
`line base.m4 201 0
	output wf_refresh_finished_7,
`line base.m4 201 0

`line base.m4 201 0
	output [WF_RAM_WID-1:0] wf_ram_dma_addr_7,
`line base.m4 201 0
	input [WF_RAM_WORD_WID-1:0] wf_ram_word_7,
`line base.m4 201 0
	output wf_ram_read_7,
`line base.m4 201 0
	input wf_ram_valid_7
`line base.m4 201 0
,

	input [`ADC_PORTS_CONTROL_LOOP-1:0] adc_sel_0,

	
`line base.m4 205 0
	output adc_finished_0,
`line base.m4 205 0
	input adc_arm_0,
`line base.m4 205 0
	output [ADC_TYPE1_WID-1:0] from_adc_0
`line base.m4 205 0
,
	
`line base.m4 206 0
	output adc_finished_1,
`line base.m4 206 0
	input adc_arm_1,
`line base.m4 206 0
	output [ADC_TYPE1_WID-1:0] from_adc_1
`line base.m4 206 0
,
	
`line base.m4 207 0
	output adc_finished_2,
`line base.m4 207 0
	input adc_arm_2,
`line base.m4 207 0
	output [ADC_TYPE1_WID-1:0] from_adc_2
`line base.m4 207 0
,
	
`line base.m4 208 0
	output adc_finished_3,
`line base.m4 208 0
	input adc_arm_3,
`line base.m4 208 0
	output [ADC_TYPE1_WID-1:0] from_adc_3
`line base.m4 208 0
,
	
`line base.m4 209 0
	output adc_finished_4,
`line base.m4 209 0
	input adc_arm_4,
`line base.m4 209 0
	output [ADC_TYPE1_WID-1:0] from_adc_4
`line base.m4 209 0
,
	
`line base.m4 210 0
	output adc_finished_5,
`line base.m4 210 0
	input adc_arm_5,
`line base.m4 210 0
	output [ADC_TYPE1_WID-1:0] from_adc_5
`line base.m4 210 0
,
	
`line base.m4 211 0
	output adc_finished_6,
`line base.m4 211 0
	input adc_arm_6,
`line base.m4 211 0
	output [ADC_TYPE1_WID-1:0] from_adc_6
`line base.m4 211 0
,
	
`line base.m4 212 0
	output adc_finished_7,
`line base.m4 212 0
	input adc_arm_7,
`line base.m4 212 0
	output [ADC_TYPE1_WID-1:0] from_adc_7
`line base.m4 212 0
,

	output cl_in_loop,
	input [`CONTROL_LOOP_CMD_WIDTH-1:0] cl_cmd,
	input [`CL_DATA_WID-1:0] cl_word_in,
	output reg [`CL_DATA_WID-1:0] cl_word_out,
	input cl_start_cmd,
	output reg cl_finish_cmd
);

wire [ADC_NUM-1:0] adc_conv_L;
assign adc_conv = ~adc_conv_L;


`line base.m4 225 0
	wire [`DAC_PORTS_CONTROL_LOOP-1:0] mosi_port_0;
`line base.m4 225 0
	wire [`DAC_PORTS_CONTROL_LOOP-1:0] miso_port_0;
`line base.m4 225 0
	wire [`DAC_PORTS_CONTROL_LOOP-1:0] sck_port_0;
`line base.m4 225 0
	wire [`DAC_PORTS_CONTROL_LOOP-1:0] ss_L_port_0;
`line base.m4 225 0

`line base.m4 225 0
	spi_switch #(
`line base.m4 225 0
		.PORTS(`DAC_PORTS_CONTROL_LOOP)
`line base.m4 225 0
	) switch_0 (
`line base.m4 225 0
		.select(dac_sel_0),
`line base.m4 225 0
		.mosi(dac_mosi[0]),
`line base.m4 225 0
		.miso(dac_miso[0]),
`line base.m4 225 0
		.sck(dac_sck[0]),
`line base.m4 225 0
		.ss_L(dac_ss_L[0]),
`line base.m4 225 0

`line base.m4 225 0
		.mosi_ports(mosi_port_0),
`line base.m4 225 0
		.miso_ports(miso_port_0),
`line base.m4 225 0
		.sck_ports(sck_port_0),
`line base.m4 225 0
		.ss_L_ports(ss_L_port_0)
`line base.m4 225 0
	);
`line base.m4 225 0

`line base.m4 225 0
	spi_master_ss #(
`line base.m4 225 0
		.WID(DAC_WID),
`line base.m4 225 0
		.WID_LEN(DAC_WID_SIZ),
`line base.m4 225 0
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 225 0
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 225 0
		.POLARITY(DAC_POLARITY),
`line base.m4 225 0
		.PHASE(DAC_PHASE),
`line base.m4 225 0
		.SS_WAIT(DAC_SS_WAIT),
`line base.m4 225 0
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
`line base.m4 225 0
	) dac_master_0 (
`line base.m4 225 0
		.clk(clk),
`line base.m4 225 0
		.mosi(mosi_port_0[0]),
`line base.m4 225 0
		.miso(miso_port_0[0]),
`line base.m4 225 0
		.sck_wire(sck_port_0[0]),
`line base.m4 225 0
		.ss_L(ss_L_port_0[0]),
`line base.m4 225 0
		.finished(dac_finished_0),
`line base.m4 225 0
		.arm(dac_arm_0),
`line base.m4 225 0
		.from_slave(from_dac_0),
`line base.m4 225 0
		.to_slave(to_dac_0)
`line base.m4 225 0
	);
`line base.m4 225 0

`line base.m4 225 0
	waveform #(
`line base.m4 225 0
		.DAC_WID(DAC_WID),
`line base.m4 225 0
		.DAC_WID_SIZ(DAC_WID_SIZ),
`line base.m4 225 0
		.DAC_POLARITY(DAC_POLARITY),
`line base.m4 225 0
		.DAC_PHASE(DAC_PHASE),
`line base.m4 225 0
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 225 0
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 225 0
		.DAC_SS_WAIT(DAC_SS_WAIT),
`line base.m4 225 0
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
`line base.m4 225 0
		.TIMER_WID(WF_TIMER_WID),
`line base.m4 225 0
		.WORD_WID(WF_WORD_WID),
`line base.m4 225 0
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
`line base.m4 225 0
		.WORD_AMNT(WF_WORD_AMNT),
`line base.m4 225 0
		.RAM_WID(WF_RAM_WID),
`line base.m4 225 0
		.RAM_WORD_WID(WF_RAM_WORD_WID),
`line base.m4 225 0
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
`line base.m4 225 0
	) waveform_0 (
`line base.m4 225 0
		.clk(clk),
`line base.m4 225 0
		.arm(wf_arm_0),
`line base.m4 225 0
		.time_to_wait(wf_time_to_wait_0),
`line base.m4 225 0
		.refresh_start(wf_refresh_start_0),
`line base.m4 225 0
		.start_addr(wf_start_addr_0),
`line base.m4 225 0
		.refresh_finished(wf_refresh_finished_0),
`line base.m4 225 0
		.ram_dma_addr(wf_ram_dma_addr_0),
`line base.m4 225 0
		.ram_word(wf_ram_word_0),
`line base.m4 225 0
		.ram_read(wf_ram_read_0),
`line base.m4 225 0
		.ram_valid(wf_ram_valid_0),
`line base.m4 225 0
		.mosi(mosi_port_0[1]),
`line base.m4 225 0
		.sck(sck_port_0[1]),
`line base.m4 225 0
		.ss_L(ss_L_port_0[1])
`line base.m4 225 0
	)
`line base.m4 225 0
;

`line base.m4 226 0
	wire [DAC_PORTS-1:0] mosi_port_1;
`line base.m4 226 0
	wire [DAC_PORTS-1:0] miso_port_1;
`line base.m4 226 0
	wire [DAC_PORTS-1:0] sck_port_1;
`line base.m4 226 0
	wire [DAC_PORTS-1:0] ss_L_port_1;
`line base.m4 226 0

`line base.m4 226 0
	spi_switch #(
`line base.m4 226 0
		.PORTS(DAC_PORTS)
`line base.m4 226 0
	) switch_1 (
`line base.m4 226 0
		.select(dac_sel_1),
`line base.m4 226 0
		.mosi(dac_mosi[1]),
`line base.m4 226 0
		.miso(dac_miso[1]),
`line base.m4 226 0
		.sck(dac_sck[1]),
`line base.m4 226 0
		.ss_L(dac_ss_L[1]),
`line base.m4 226 0

`line base.m4 226 0
		.mosi_ports(mosi_port_1),
`line base.m4 226 0
		.miso_ports(miso_port_1),
`line base.m4 226 0
		.sck_ports(sck_port_1),
`line base.m4 226 0
		.ss_L_ports(ss_L_port_1)
`line base.m4 226 0
	);
`line base.m4 226 0

`line base.m4 226 0
	spi_master_ss #(
`line base.m4 226 0
		.WID(DAC_WID),
`line base.m4 226 0
		.WID_LEN(DAC_WID_SIZ),
`line base.m4 226 0
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 226 0
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 226 0
		.POLARITY(DAC_POLARITY),
`line base.m4 226 0
		.PHASE(DAC_PHASE),
`line base.m4 226 0
		.SS_WAIT(DAC_SS_WAIT),
`line base.m4 226 0
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
`line base.m4 226 0
	) dac_master_1 (
`line base.m4 226 0
		.clk(clk),
`line base.m4 226 0
		.mosi(mosi_port_1[0]),
`line base.m4 226 0
		.miso(miso_port_1[0]),
`line base.m4 226 0
		.sck_wire(sck_port_1[0]),
`line base.m4 226 0
		.ss_L(ss_L_port_1[0]),
`line base.m4 226 0
		.finished(dac_finished_1),
`line base.m4 226 0
		.arm(dac_arm_1),
`line base.m4 226 0
		.from_slave(from_dac_1),
`line base.m4 226 0
		.to_slave(to_dac_1)
`line base.m4 226 0
	);
`line base.m4 226 0

`line base.m4 226 0
	waveform #(
`line base.m4 226 0
		.DAC_WID(DAC_WID),
`line base.m4 226 0
		.DAC_WID_SIZ(DAC_WID_SIZ),
`line base.m4 226 0
		.DAC_POLARITY(DAC_POLARITY),
`line base.m4 226 0
		.DAC_PHASE(DAC_PHASE),
`line base.m4 226 0
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 226 0
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 226 0
		.DAC_SS_WAIT(DAC_SS_WAIT),
`line base.m4 226 0
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
`line base.m4 226 0
		.TIMER_WID(WF_TIMER_WID),
`line base.m4 226 0
		.WORD_WID(WF_WORD_WID),
`line base.m4 226 0
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
`line base.m4 226 0
		.WORD_AMNT(WF_WORD_AMNT),
`line base.m4 226 0
		.RAM_WID(WF_RAM_WID),
`line base.m4 226 0
		.RAM_WORD_WID(WF_RAM_WORD_WID),
`line base.m4 226 0
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
`line base.m4 226 0
	) waveform_1 (
`line base.m4 226 0
		.clk(clk),
`line base.m4 226 0
		.arm(wf_arm_1),
`line base.m4 226 0
		.time_to_wait(wf_time_to_wait_1),
`line base.m4 226 0
		.refresh_start(wf_refresh_start_1),
`line base.m4 226 0
		.start_addr(wf_start_addr_1),
`line base.m4 226 0
		.refresh_finished(wf_refresh_finished_1),
`line base.m4 226 0
		.ram_dma_addr(wf_ram_dma_addr_1),
`line base.m4 226 0
		.ram_word(wf_ram_word_1),
`line base.m4 226 0
		.ram_read(wf_ram_read_1),
`line base.m4 226 0
		.ram_valid(wf_ram_valid_1),
`line base.m4 226 0
		.mosi(mosi_port_1[1]),
`line base.m4 226 0
		.sck(sck_port_1[1]),
`line base.m4 226 0
		.ss_L(ss_L_port_1[1])
`line base.m4 226 0
	)
`line base.m4 226 0
;

`line base.m4 227 0
	wire [DAC_PORTS-1:0] mosi_port_2;
`line base.m4 227 0
	wire [DAC_PORTS-1:0] miso_port_2;
`line base.m4 227 0
	wire [DAC_PORTS-1:0] sck_port_2;
`line base.m4 227 0
	wire [DAC_PORTS-1:0] ss_L_port_2;
`line base.m4 227 0

`line base.m4 227 0
	spi_switch #(
`line base.m4 227 0
		.PORTS(DAC_PORTS)
`line base.m4 227 0
	) switch_2 (
`line base.m4 227 0
		.select(dac_sel_2),
`line base.m4 227 0
		.mosi(dac_mosi[2]),
`line base.m4 227 0
		.miso(dac_miso[2]),
`line base.m4 227 0
		.sck(dac_sck[2]),
`line base.m4 227 0
		.ss_L(dac_ss_L[2]),
`line base.m4 227 0

`line base.m4 227 0
		.mosi_ports(mosi_port_2),
`line base.m4 227 0
		.miso_ports(miso_port_2),
`line base.m4 227 0
		.sck_ports(sck_port_2),
`line base.m4 227 0
		.ss_L_ports(ss_L_port_2)
`line base.m4 227 0
	);
`line base.m4 227 0

`line base.m4 227 0
	spi_master_ss #(
`line base.m4 227 0
		.WID(DAC_WID),
`line base.m4 227 0
		.WID_LEN(DAC_WID_SIZ),
`line base.m4 227 0
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 227 0
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 227 0
		.POLARITY(DAC_POLARITY),
`line base.m4 227 0
		.PHASE(DAC_PHASE),
`line base.m4 227 0
		.SS_WAIT(DAC_SS_WAIT),
`line base.m4 227 0
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
`line base.m4 227 0
	) dac_master_2 (
`line base.m4 227 0
		.clk(clk),
`line base.m4 227 0
		.mosi(mosi_port_2[0]),
`line base.m4 227 0
		.miso(miso_port_2[0]),
`line base.m4 227 0
		.sck_wire(sck_port_2[0]),
`line base.m4 227 0
		.ss_L(ss_L_port_2[0]),
`line base.m4 227 0
		.finished(dac_finished_2),
`line base.m4 227 0
		.arm(dac_arm_2),
`line base.m4 227 0
		.from_slave(from_dac_2),
`line base.m4 227 0
		.to_slave(to_dac_2)
`line base.m4 227 0
	);
`line base.m4 227 0

`line base.m4 227 0
	waveform #(
`line base.m4 227 0
		.DAC_WID(DAC_WID),
`line base.m4 227 0
		.DAC_WID_SIZ(DAC_WID_SIZ),
`line base.m4 227 0
		.DAC_POLARITY(DAC_POLARITY),
`line base.m4 227 0
		.DAC_PHASE(DAC_PHASE),
`line base.m4 227 0
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 227 0
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 227 0
		.DAC_SS_WAIT(DAC_SS_WAIT),
`line base.m4 227 0
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
`line base.m4 227 0
		.TIMER_WID(WF_TIMER_WID),
`line base.m4 227 0
		.WORD_WID(WF_WORD_WID),
`line base.m4 227 0
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
`line base.m4 227 0
		.WORD_AMNT(WF_WORD_AMNT),
`line base.m4 227 0
		.RAM_WID(WF_RAM_WID),
`line base.m4 227 0
		.RAM_WORD_WID(WF_RAM_WORD_WID),
`line base.m4 227 0
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
`line base.m4 227 0
	) waveform_2 (
`line base.m4 227 0
		.clk(clk),
`line base.m4 227 0
		.arm(wf_arm_2),
`line base.m4 227 0
		.time_to_wait(wf_time_to_wait_2),
`line base.m4 227 0
		.refresh_start(wf_refresh_start_2),
`line base.m4 227 0
		.start_addr(wf_start_addr_2),
`line base.m4 227 0
		.refresh_finished(wf_refresh_finished_2),
`line base.m4 227 0
		.ram_dma_addr(wf_ram_dma_addr_2),
`line base.m4 227 0
		.ram_word(wf_ram_word_2),
`line base.m4 227 0
		.ram_read(wf_ram_read_2),
`line base.m4 227 0
		.ram_valid(wf_ram_valid_2),
`line base.m4 227 0
		.mosi(mosi_port_2[1]),
`line base.m4 227 0
		.sck(sck_port_2[1]),
`line base.m4 227 0
		.ss_L(ss_L_port_2[1])
`line base.m4 227 0
	)
`line base.m4 227 0
;

`line base.m4 228 0
	wire [DAC_PORTS-1:0] mosi_port_3;
`line base.m4 228 0
	wire [DAC_PORTS-1:0] miso_port_3;
`line base.m4 228 0
	wire [DAC_PORTS-1:0] sck_port_3;
`line base.m4 228 0
	wire [DAC_PORTS-1:0] ss_L_port_3;
`line base.m4 228 0

`line base.m4 228 0
	spi_switch #(
`line base.m4 228 0
		.PORTS(DAC_PORTS)
`line base.m4 228 0
	) switch_3 (
`line base.m4 228 0
		.select(dac_sel_3),
`line base.m4 228 0
		.mosi(dac_mosi[3]),
`line base.m4 228 0
		.miso(dac_miso[3]),
`line base.m4 228 0
		.sck(dac_sck[3]),
`line base.m4 228 0
		.ss_L(dac_ss_L[3]),
`line base.m4 228 0

`line base.m4 228 0
		.mosi_ports(mosi_port_3),
`line base.m4 228 0
		.miso_ports(miso_port_3),
`line base.m4 228 0
		.sck_ports(sck_port_3),
`line base.m4 228 0
		.ss_L_ports(ss_L_port_3)
`line base.m4 228 0
	);
`line base.m4 228 0

`line base.m4 228 0
	spi_master_ss #(
`line base.m4 228 0
		.WID(DAC_WID),
`line base.m4 228 0
		.WID_LEN(DAC_WID_SIZ),
`line base.m4 228 0
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 228 0
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 228 0
		.POLARITY(DAC_POLARITY),
`line base.m4 228 0
		.PHASE(DAC_PHASE),
`line base.m4 228 0
		.SS_WAIT(DAC_SS_WAIT),
`line base.m4 228 0
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
`line base.m4 228 0
	) dac_master_3 (
`line base.m4 228 0
		.clk(clk),
`line base.m4 228 0
		.mosi(mosi_port_3[0]),
`line base.m4 228 0
		.miso(miso_port_3[0]),
`line base.m4 228 0
		.sck_wire(sck_port_3[0]),
`line base.m4 228 0
		.ss_L(ss_L_port_3[0]),
`line base.m4 228 0
		.finished(dac_finished_3),
`line base.m4 228 0
		.arm(dac_arm_3),
`line base.m4 228 0
		.from_slave(from_dac_3),
`line base.m4 228 0
		.to_slave(to_dac_3)
`line base.m4 228 0
	);
`line base.m4 228 0

`line base.m4 228 0
	waveform #(
`line base.m4 228 0
		.DAC_WID(DAC_WID),
`line base.m4 228 0
		.DAC_WID_SIZ(DAC_WID_SIZ),
`line base.m4 228 0
		.DAC_POLARITY(DAC_POLARITY),
`line base.m4 228 0
		.DAC_PHASE(DAC_PHASE),
`line base.m4 228 0
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 228 0
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 228 0
		.DAC_SS_WAIT(DAC_SS_WAIT),
`line base.m4 228 0
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
`line base.m4 228 0
		.TIMER_WID(WF_TIMER_WID),
`line base.m4 228 0
		.WORD_WID(WF_WORD_WID),
`line base.m4 228 0
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
`line base.m4 228 0
		.WORD_AMNT(WF_WORD_AMNT),
`line base.m4 228 0
		.RAM_WID(WF_RAM_WID),
`line base.m4 228 0
		.RAM_WORD_WID(WF_RAM_WORD_WID),
`line base.m4 228 0
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
`line base.m4 228 0
	) waveform_3 (
`line base.m4 228 0
		.clk(clk),
`line base.m4 228 0
		.arm(wf_arm_3),
`line base.m4 228 0
		.time_to_wait(wf_time_to_wait_3),
`line base.m4 228 0
		.refresh_start(wf_refresh_start_3),
`line base.m4 228 0
		.start_addr(wf_start_addr_3),
`line base.m4 228 0
		.refresh_finished(wf_refresh_finished_3),
`line base.m4 228 0
		.ram_dma_addr(wf_ram_dma_addr_3),
`line base.m4 228 0
		.ram_word(wf_ram_word_3),
`line base.m4 228 0
		.ram_read(wf_ram_read_3),
`line base.m4 228 0
		.ram_valid(wf_ram_valid_3),
`line base.m4 228 0
		.mosi(mosi_port_3[1]),
`line base.m4 228 0
		.sck(sck_port_3[1]),
`line base.m4 228 0
		.ss_L(ss_L_port_3[1])
`line base.m4 228 0
	)
`line base.m4 228 0
;

`line base.m4 229 0
	wire [DAC_PORTS-1:0] mosi_port_4;
`line base.m4 229 0
	wire [DAC_PORTS-1:0] miso_port_4;
`line base.m4 229 0
	wire [DAC_PORTS-1:0] sck_port_4;
`line base.m4 229 0
	wire [DAC_PORTS-1:0] ss_L_port_4;
`line base.m4 229 0

`line base.m4 229 0
	spi_switch #(
`line base.m4 229 0
		.PORTS(DAC_PORTS)
`line base.m4 229 0
	) switch_4 (
`line base.m4 229 0
		.select(dac_sel_4),
`line base.m4 229 0
		.mosi(dac_mosi[4]),
`line base.m4 229 0
		.miso(dac_miso[4]),
`line base.m4 229 0
		.sck(dac_sck[4]),
`line base.m4 229 0
		.ss_L(dac_ss_L[4]),
`line base.m4 229 0

`line base.m4 229 0
		.mosi_ports(mosi_port_4),
`line base.m4 229 0
		.miso_ports(miso_port_4),
`line base.m4 229 0
		.sck_ports(sck_port_4),
`line base.m4 229 0
		.ss_L_ports(ss_L_port_4)
`line base.m4 229 0
	);
`line base.m4 229 0

`line base.m4 229 0
	spi_master_ss #(
`line base.m4 229 0
		.WID(DAC_WID),
`line base.m4 229 0
		.WID_LEN(DAC_WID_SIZ),
`line base.m4 229 0
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 229 0
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 229 0
		.POLARITY(DAC_POLARITY),
`line base.m4 229 0
		.PHASE(DAC_PHASE),
`line base.m4 229 0
		.SS_WAIT(DAC_SS_WAIT),
`line base.m4 229 0
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
`line base.m4 229 0
	) dac_master_4 (
`line base.m4 229 0
		.clk(clk),
`line base.m4 229 0
		.mosi(mosi_port_4[0]),
`line base.m4 229 0
		.miso(miso_port_4[0]),
`line base.m4 229 0
		.sck_wire(sck_port_4[0]),
`line base.m4 229 0
		.ss_L(ss_L_port_4[0]),
`line base.m4 229 0
		.finished(dac_finished_4),
`line base.m4 229 0
		.arm(dac_arm_4),
`line base.m4 229 0
		.from_slave(from_dac_4),
`line base.m4 229 0
		.to_slave(to_dac_4)
`line base.m4 229 0
	);
`line base.m4 229 0

`line base.m4 229 0
	waveform #(
`line base.m4 229 0
		.DAC_WID(DAC_WID),
`line base.m4 229 0
		.DAC_WID_SIZ(DAC_WID_SIZ),
`line base.m4 229 0
		.DAC_POLARITY(DAC_POLARITY),
`line base.m4 229 0
		.DAC_PHASE(DAC_PHASE),
`line base.m4 229 0
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 229 0
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 229 0
		.DAC_SS_WAIT(DAC_SS_WAIT),
`line base.m4 229 0
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
`line base.m4 229 0
		.TIMER_WID(WF_TIMER_WID),
`line base.m4 229 0
		.WORD_WID(WF_WORD_WID),
`line base.m4 229 0
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
`line base.m4 229 0
		.WORD_AMNT(WF_WORD_AMNT),
`line base.m4 229 0
		.RAM_WID(WF_RAM_WID),
`line base.m4 229 0
		.RAM_WORD_WID(WF_RAM_WORD_WID),
`line base.m4 229 0
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
`line base.m4 229 0
	) waveform_4 (
`line base.m4 229 0
		.clk(clk),
`line base.m4 229 0
		.arm(wf_arm_4),
`line base.m4 229 0
		.time_to_wait(wf_time_to_wait_4),
`line base.m4 229 0
		.refresh_start(wf_refresh_start_4),
`line base.m4 229 0
		.start_addr(wf_start_addr_4),
`line base.m4 229 0
		.refresh_finished(wf_refresh_finished_4),
`line base.m4 229 0
		.ram_dma_addr(wf_ram_dma_addr_4),
`line base.m4 229 0
		.ram_word(wf_ram_word_4),
`line base.m4 229 0
		.ram_read(wf_ram_read_4),
`line base.m4 229 0
		.ram_valid(wf_ram_valid_4),
`line base.m4 229 0
		.mosi(mosi_port_4[1]),
`line base.m4 229 0
		.sck(sck_port_4[1]),
`line base.m4 229 0
		.ss_L(ss_L_port_4[1])
`line base.m4 229 0
	)
`line base.m4 229 0
;

`line base.m4 230 0
	wire [DAC_PORTS-1:0] mosi_port_5;
`line base.m4 230 0
	wire [DAC_PORTS-1:0] miso_port_5;
`line base.m4 230 0
	wire [DAC_PORTS-1:0] sck_port_5;
`line base.m4 230 0
	wire [DAC_PORTS-1:0] ss_L_port_5;
`line base.m4 230 0

`line base.m4 230 0
	spi_switch #(
`line base.m4 230 0
		.PORTS(DAC_PORTS)
`line base.m4 230 0
	) switch_5 (
`line base.m4 230 0
		.select(dac_sel_5),
`line base.m4 230 0
		.mosi(dac_mosi[5]),
`line base.m4 230 0
		.miso(dac_miso[5]),
`line base.m4 230 0
		.sck(dac_sck[5]),
`line base.m4 230 0
		.ss_L(dac_ss_L[5]),
`line base.m4 230 0

`line base.m4 230 0
		.mosi_ports(mosi_port_5),
`line base.m4 230 0
		.miso_ports(miso_port_5),
`line base.m4 230 0
		.sck_ports(sck_port_5),
`line base.m4 230 0
		.ss_L_ports(ss_L_port_5)
`line base.m4 230 0
	);
`line base.m4 230 0

`line base.m4 230 0
	spi_master_ss #(
`line base.m4 230 0
		.WID(DAC_WID),
`line base.m4 230 0
		.WID_LEN(DAC_WID_SIZ),
`line base.m4 230 0
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 230 0
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 230 0
		.POLARITY(DAC_POLARITY),
`line base.m4 230 0
		.PHASE(DAC_PHASE),
`line base.m4 230 0
		.SS_WAIT(DAC_SS_WAIT),
`line base.m4 230 0
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
`line base.m4 230 0
	) dac_master_5 (
`line base.m4 230 0
		.clk(clk),
`line base.m4 230 0
		.mosi(mosi_port_5[0]),
`line base.m4 230 0
		.miso(miso_port_5[0]),
`line base.m4 230 0
		.sck_wire(sck_port_5[0]),
`line base.m4 230 0
		.ss_L(ss_L_port_5[0]),
`line base.m4 230 0
		.finished(dac_finished_5),
`line base.m4 230 0
		.arm(dac_arm_5),
`line base.m4 230 0
		.from_slave(from_dac_5),
`line base.m4 230 0
		.to_slave(to_dac_5)
`line base.m4 230 0
	);
`line base.m4 230 0

`line base.m4 230 0
	waveform #(
`line base.m4 230 0
		.DAC_WID(DAC_WID),
`line base.m4 230 0
		.DAC_WID_SIZ(DAC_WID_SIZ),
`line base.m4 230 0
		.DAC_POLARITY(DAC_POLARITY),
`line base.m4 230 0
		.DAC_PHASE(DAC_PHASE),
`line base.m4 230 0
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 230 0
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 230 0
		.DAC_SS_WAIT(DAC_SS_WAIT),
`line base.m4 230 0
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
`line base.m4 230 0
		.TIMER_WID(WF_TIMER_WID),
`line base.m4 230 0
		.WORD_WID(WF_WORD_WID),
`line base.m4 230 0
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
`line base.m4 230 0
		.WORD_AMNT(WF_WORD_AMNT),
`line base.m4 230 0
		.RAM_WID(WF_RAM_WID),
`line base.m4 230 0
		.RAM_WORD_WID(WF_RAM_WORD_WID),
`line base.m4 230 0
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
`line base.m4 230 0
	) waveform_5 (
`line base.m4 230 0
		.clk(clk),
`line base.m4 230 0
		.arm(wf_arm_5),
`line base.m4 230 0
		.time_to_wait(wf_time_to_wait_5),
`line base.m4 230 0
		.refresh_start(wf_refresh_start_5),
`line base.m4 230 0
		.start_addr(wf_start_addr_5),
`line base.m4 230 0
		.refresh_finished(wf_refresh_finished_5),
`line base.m4 230 0
		.ram_dma_addr(wf_ram_dma_addr_5),
`line base.m4 230 0
		.ram_word(wf_ram_word_5),
`line base.m4 230 0
		.ram_read(wf_ram_read_5),
`line base.m4 230 0
		.ram_valid(wf_ram_valid_5),
`line base.m4 230 0
		.mosi(mosi_port_5[1]),
`line base.m4 230 0
		.sck(sck_port_5[1]),
`line base.m4 230 0
		.ss_L(ss_L_port_5[1])
`line base.m4 230 0
	)
`line base.m4 230 0
;

`line base.m4 231 0
	wire [DAC_PORTS-1:0] mosi_port_6;
`line base.m4 231 0
	wire [DAC_PORTS-1:0] miso_port_6;
`line base.m4 231 0
	wire [DAC_PORTS-1:0] sck_port_6;
`line base.m4 231 0
	wire [DAC_PORTS-1:0] ss_L_port_6;
`line base.m4 231 0

`line base.m4 231 0
	spi_switch #(
`line base.m4 231 0
		.PORTS(DAC_PORTS)
`line base.m4 231 0
	) switch_6 (
`line base.m4 231 0
		.select(dac_sel_6),
`line base.m4 231 0
		.mosi(dac_mosi[6]),
`line base.m4 231 0
		.miso(dac_miso[6]),
`line base.m4 231 0
		.sck(dac_sck[6]),
`line base.m4 231 0
		.ss_L(dac_ss_L[6]),
`line base.m4 231 0

`line base.m4 231 0
		.mosi_ports(mosi_port_6),
`line base.m4 231 0
		.miso_ports(miso_port_6),
`line base.m4 231 0
		.sck_ports(sck_port_6),
`line base.m4 231 0
		.ss_L_ports(ss_L_port_6)
`line base.m4 231 0
	);
`line base.m4 231 0

`line base.m4 231 0
	spi_master_ss #(
`line base.m4 231 0
		.WID(DAC_WID),
`line base.m4 231 0
		.WID_LEN(DAC_WID_SIZ),
`line base.m4 231 0
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 231 0
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 231 0
		.POLARITY(DAC_POLARITY),
`line base.m4 231 0
		.PHASE(DAC_PHASE),
`line base.m4 231 0
		.SS_WAIT(DAC_SS_WAIT),
`line base.m4 231 0
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
`line base.m4 231 0
	) dac_master_6 (
`line base.m4 231 0
		.clk(clk),
`line base.m4 231 0
		.mosi(mosi_port_6[0]),
`line base.m4 231 0
		.miso(miso_port_6[0]),
`line base.m4 231 0
		.sck_wire(sck_port_6[0]),
`line base.m4 231 0
		.ss_L(ss_L_port_6[0]),
`line base.m4 231 0
		.finished(dac_finished_6),
`line base.m4 231 0
		.arm(dac_arm_6),
`line base.m4 231 0
		.from_slave(from_dac_6),
`line base.m4 231 0
		.to_slave(to_dac_6)
`line base.m4 231 0
	);
`line base.m4 231 0

`line base.m4 231 0
	waveform #(
`line base.m4 231 0
		.DAC_WID(DAC_WID),
`line base.m4 231 0
		.DAC_WID_SIZ(DAC_WID_SIZ),
`line base.m4 231 0
		.DAC_POLARITY(DAC_POLARITY),
`line base.m4 231 0
		.DAC_PHASE(DAC_PHASE),
`line base.m4 231 0
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 231 0
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 231 0
		.DAC_SS_WAIT(DAC_SS_WAIT),
`line base.m4 231 0
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
`line base.m4 231 0
		.TIMER_WID(WF_TIMER_WID),
`line base.m4 231 0
		.WORD_WID(WF_WORD_WID),
`line base.m4 231 0
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
`line base.m4 231 0
		.WORD_AMNT(WF_WORD_AMNT),
`line base.m4 231 0
		.RAM_WID(WF_RAM_WID),
`line base.m4 231 0
		.RAM_WORD_WID(WF_RAM_WORD_WID),
`line base.m4 231 0
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
`line base.m4 231 0
	) waveform_6 (
`line base.m4 231 0
		.clk(clk),
`line base.m4 231 0
		.arm(wf_arm_6),
`line base.m4 231 0
		.time_to_wait(wf_time_to_wait_6),
`line base.m4 231 0
		.refresh_start(wf_refresh_start_6),
`line base.m4 231 0
		.start_addr(wf_start_addr_6),
`line base.m4 231 0
		.refresh_finished(wf_refresh_finished_6),
`line base.m4 231 0
		.ram_dma_addr(wf_ram_dma_addr_6),
`line base.m4 231 0
		.ram_word(wf_ram_word_6),
`line base.m4 231 0
		.ram_read(wf_ram_read_6),
`line base.m4 231 0
		.ram_valid(wf_ram_valid_6),
`line base.m4 231 0
		.mosi(mosi_port_6[1]),
`line base.m4 231 0
		.sck(sck_port_6[1]),
`line base.m4 231 0
		.ss_L(ss_L_port_6[1])
`line base.m4 231 0
	)
`line base.m4 231 0
;

`line base.m4 232 0
	wire [DAC_PORTS-1:0] mosi_port_7;
`line base.m4 232 0
	wire [DAC_PORTS-1:0] miso_port_7;
`line base.m4 232 0
	wire [DAC_PORTS-1:0] sck_port_7;
`line base.m4 232 0
	wire [DAC_PORTS-1:0] ss_L_port_7;
`line base.m4 232 0

`line base.m4 232 0
	spi_switch #(
`line base.m4 232 0
		.PORTS(DAC_PORTS)
`line base.m4 232 0
	) switch_7 (
`line base.m4 232 0
		.select(dac_sel_7),
`line base.m4 232 0
		.mosi(dac_mosi[7]),
`line base.m4 232 0
		.miso(dac_miso[7]),
`line base.m4 232 0
		.sck(dac_sck[7]),
`line base.m4 232 0
		.ss_L(dac_ss_L[7]),
`line base.m4 232 0

`line base.m4 232 0
		.mosi_ports(mosi_port_7),
`line base.m4 232 0
		.miso_ports(miso_port_7),
`line base.m4 232 0
		.sck_ports(sck_port_7),
`line base.m4 232 0
		.ss_L_ports(ss_L_port_7)
`line base.m4 232 0
	);
`line base.m4 232 0

`line base.m4 232 0
	spi_master_ss #(
`line base.m4 232 0
		.WID(DAC_WID),
`line base.m4 232 0
		.WID_LEN(DAC_WID_SIZ),
`line base.m4 232 0
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 232 0
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 232 0
		.POLARITY(DAC_POLARITY),
`line base.m4 232 0
		.PHASE(DAC_PHASE),
`line base.m4 232 0
		.SS_WAIT(DAC_SS_WAIT),
`line base.m4 232 0
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
`line base.m4 232 0
	) dac_master_7 (
`line base.m4 232 0
		.clk(clk),
`line base.m4 232 0
		.mosi(mosi_port_7[0]),
`line base.m4 232 0
		.miso(miso_port_7[0]),
`line base.m4 232 0
		.sck_wire(sck_port_7[0]),
`line base.m4 232 0
		.ss_L(ss_L_port_7[0]),
`line base.m4 232 0
		.finished(dac_finished_7),
`line base.m4 232 0
		.arm(dac_arm_7),
`line base.m4 232 0
		.from_slave(from_dac_7),
`line base.m4 232 0
		.to_slave(to_dac_7)
`line base.m4 232 0
	);
`line base.m4 232 0

`line base.m4 232 0
	waveform #(
`line base.m4 232 0
		.DAC_WID(DAC_WID),
`line base.m4 232 0
		.DAC_WID_SIZ(DAC_WID_SIZ),
`line base.m4 232 0
		.DAC_POLARITY(DAC_POLARITY),
`line base.m4 232 0
		.DAC_PHASE(DAC_PHASE),
`line base.m4 232 0
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
`line base.m4 232 0
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 232 0
		.DAC_SS_WAIT(DAC_SS_WAIT),
`line base.m4 232 0
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
`line base.m4 232 0
		.TIMER_WID(WF_TIMER_WID),
`line base.m4 232 0
		.WORD_WID(WF_WORD_WID),
`line base.m4 232 0
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
`line base.m4 232 0
		.WORD_AMNT(WF_WORD_AMNT),
`line base.m4 232 0
		.RAM_WID(WF_RAM_WID),
`line base.m4 232 0
		.RAM_WORD_WID(WF_RAM_WORD_WID),
`line base.m4 232 0
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
`line base.m4 232 0
	) waveform_7 (
`line base.m4 232 0
		.clk(clk),
`line base.m4 232 0
		.arm(wf_arm_7),
`line base.m4 232 0
		.time_to_wait(wf_time_to_wait_7),
`line base.m4 232 0
		.refresh_start(wf_refresh_start_7),
`line base.m4 232 0
		.start_addr(wf_start_addr_7),
`line base.m4 232 0
		.refresh_finished(wf_refresh_finished_7),
`line base.m4 232 0
		.ram_dma_addr(wf_ram_dma_addr_7),
`line base.m4 232 0
		.ram_word(wf_ram_word_7),
`line base.m4 232 0
		.ram_read(wf_ram_read_7),
`line base.m4 232 0
		.ram_valid(wf_ram_valid_7),
`line base.m4 232 0
		.mosi(mosi_port_7[1]),
`line base.m4 232 0
		.sck(sck_port_7[1]),
`line base.m4 232 0
		.ss_L(ss_L_port_7[1])
`line base.m4 232 0
	)
`line base.m4 232 0
;

/* 1st adc is Type 1 (18 bit) */

wire [`ADC_PORTS_CONTROL_LOOP-1:0] adc_conv_L_port_0;
wire [`ADC_PORTS_CONTROL_LOOP-1:0] adc_sdo_port_0;
wire [`ADC_PORTS_CONTROL_LOOP-1:0] adc_sck_port_0;
wire [`ADC_PORTS_CONTROL_LOOP-1:0] adc_mosi_port_0_unassigned;
wire adc_mosi_unassigned;

spi_switch #(
	.PORTS(`ADC_PORTS_CONTROL_LOOP)
) switch_adc_0 (
	.select(adc_sel_0),
	.mosi(adc_mosi_unassigned),
	.miso(adc_sdo[0]),
	.sck(adc_sck[0]),
	.ss_L(adc_conv_L[0]),

	.mosi_ports(adc_mosi_port_0_unassigned),
	.miso_ports(adc_sdo_port_0),
	.sck_ports(adc_sck_port_0),
	.ss_L_ports(adc_conv_L_port_0)
);

spi_master_ss_no_write #(
	.WID(ADC_TYPE1_WID),
	.WID_LEN(ADC_WID_SIZ),
	.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
	.TIMER_LEN(ADC_CYCLE_HALF_WAIT_SIZ),
	.SS_WAIT(ADC_CONV_WAIT),
	.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
	.POLARITY(ADC_POLARITY),
	.PHASE(ADC_PHASE)
) adc_master_0 (
	.clk(clk),
	.miso(adc_sdo_port_0[0]),
	.sck_wire(adc_sck_port_0[0]),
	.ss_L(adc_conv_L_port_0[0]),
	.finished(adc_finished_0),
	.arm(adc_arm_0),
	.from_slave(from_adc_0)
);

control_loop #(
	.ADC_WID(ADC_TYPE1_WID),
	.ADC_WID_SIZ(ADC_WID_SIZ),
	.ADC_CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
	.ADC_CYCLE_HALF_WAIT_SIZ(ADC_CYCLE_HALF_WAIT_SIZ),
	.ADC_POLARITY(ADC_POLARITY),
	.ADC_PHASE(ADC_PHASE),
	.ADC_CONV_WAIT(ADC_CONV_WAIT),
	.ADC_CONV_WAIT_SIZ(ADC_CONV_WAIT_SIZ),
	.CONSTS_WHOLE(CL_CONSTS_WHOLE),
	.CONSTS_FRAC(CL_CONSTS_FRAC),
	.CONSTS_SIZ(CL_CONSTS_SIZ),
	.DELAY_WID(CL_DELAY_WID),
	.READ_DAC_DELAY(CL_READ_DAC_DELAY),
	.CYCLE_COUNT_WID(CL_CYCLE_COUNT_WID),
	.DAC_WID(DAC_WID),
	.DAC_WID_SIZ(DAC_WID_SIZ),
	.DAC_DATA_WID(DAC_DATA_WID),
	.DAC_POLARITY(DAC_POLARITY),
	.DAC_PHASE(DAC_PHASE),
	.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
	.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
	.DAC_SS_WAIT(DAC_SS_WAIT),
	.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ)
) cl (
	.clk(clk),
	.in_loop(cl_in_loop),
	.dac_mosi(mosi_port_0[2]),
	.dac_miso(miso_port_0[2]),
	.dac_ss_L(ss_L_port_0[2]),
	.dac_sck(sck_port_0[2]),
	.adc_miso(adc_sdo_port_0[1]),
	.adc_conv_L(adc_conv_L_port_0[1]),
	.adc_sck(adc_sck_port_0[1]),
	.cmd(cl_cmd),
	.word_in(cl_word_in),
	.word_out(cl_word_out),
	.start_cmd(cl_start_cmd),
	.finish_cmd(cl_finish_cmd)
);


`line base.m4 317 0
	spi_master_ss_no_write #(
`line base.m4 317 0
		.WID(ADC_TYPE1_WID),
`line base.m4 317 0
		.WID_LEN(ADC_WID_SIZ),
`line base.m4 317 0
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
`line base.m4 317 0
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 317 0
		.SS_WAIT(ADC_CONV_WAIT),
`line base.m4 317 0
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
`line base.m4 317 0
		.POLARITY(ADC_POLARITY),
`line base.m4 317 0
		.PHASE(ADC_PHASE)
`line base.m4 317 0
	) adc_master_1 (
`line base.m4 317 0
		.clk(clk),
`line base.m4 317 0
		.miso(adc_sdo[1]),
`line base.m4 317 0
		.sck_wire(adc_sck[1]),
`line base.m4 317 0
		.ss_L(adc_conv_L[1]),
`line base.m4 317 0
		.finished(adc_finished_1),
`line base.m4 317 0
		.arm(adc_arm_1),
`line base.m4 317 0
		.from_slave(from_adc_1)
`line base.m4 317 0
	)
`line base.m4 317 0
;

`line base.m4 318 0
	spi_master_ss_no_write #(
`line base.m4 318 0
		.WID(ADC_TYPE1_WID),
`line base.m4 318 0
		.WID_LEN(ADC_WID_SIZ),
`line base.m4 318 0
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
`line base.m4 318 0
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 318 0
		.SS_WAIT(ADC_CONV_WAIT),
`line base.m4 318 0
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
`line base.m4 318 0
		.POLARITY(ADC_POLARITY),
`line base.m4 318 0
		.PHASE(ADC_PHASE)
`line base.m4 318 0
	) adc_master_2 (
`line base.m4 318 0
		.clk(clk),
`line base.m4 318 0
		.miso(adc_sdo[2]),
`line base.m4 318 0
		.sck_wire(adc_sck[2]),
`line base.m4 318 0
		.ss_L(adc_conv_L[2]),
`line base.m4 318 0
		.finished(adc_finished_2),
`line base.m4 318 0
		.arm(adc_arm_2),
`line base.m4 318 0
		.from_slave(from_adc_2)
`line base.m4 318 0
	)
`line base.m4 318 0
;

`line base.m4 319 0
	spi_master_ss_no_write #(
`line base.m4 319 0
		.WID(ADC_TYPE1_WID),
`line base.m4 319 0
		.WID_LEN(ADC_WID_SIZ),
`line base.m4 319 0
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
`line base.m4 319 0
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 319 0
		.SS_WAIT(ADC_CONV_WAIT),
`line base.m4 319 0
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
`line base.m4 319 0
		.POLARITY(ADC_POLARITY),
`line base.m4 319 0
		.PHASE(ADC_PHASE)
`line base.m4 319 0
	) adc_master_3 (
`line base.m4 319 0
		.clk(clk),
`line base.m4 319 0
		.miso(adc_sdo[3]),
`line base.m4 319 0
		.sck_wire(adc_sck[3]),
`line base.m4 319 0
		.ss_L(adc_conv_L[3]),
`line base.m4 319 0
		.finished(adc_finished_3),
`line base.m4 319 0
		.arm(adc_arm_3),
`line base.m4 319 0
		.from_slave(from_adc_3)
`line base.m4 319 0
	)
`line base.m4 319 0
;

`line base.m4 320 0
	spi_master_ss_no_write #(
`line base.m4 320 0
		.WID(ADC_TYPE1_WID),
`line base.m4 320 0
		.WID_LEN(ADC_WID_SIZ),
`line base.m4 320 0
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
`line base.m4 320 0
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 320 0
		.SS_WAIT(ADC_CONV_WAIT),
`line base.m4 320 0
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
`line base.m4 320 0
		.POLARITY(ADC_POLARITY),
`line base.m4 320 0
		.PHASE(ADC_PHASE)
`line base.m4 320 0
	) adc_master_4 (
`line base.m4 320 0
		.clk(clk),
`line base.m4 320 0
		.miso(adc_sdo[4]),
`line base.m4 320 0
		.sck_wire(adc_sck[4]),
`line base.m4 320 0
		.ss_L(adc_conv_L[4]),
`line base.m4 320 0
		.finished(adc_finished_4),
`line base.m4 320 0
		.arm(adc_arm_4),
`line base.m4 320 0
		.from_slave(from_adc_4)
`line base.m4 320 0
	)
`line base.m4 320 0
;

`line base.m4 321 0
	spi_master_ss_no_write #(
`line base.m4 321 0
		.WID(ADC_TYPE1_WID),
`line base.m4 321 0
		.WID_LEN(ADC_WID_SIZ),
`line base.m4 321 0
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
`line base.m4 321 0
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 321 0
		.SS_WAIT(ADC_CONV_WAIT),
`line base.m4 321 0
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
`line base.m4 321 0
		.POLARITY(ADC_POLARITY),
`line base.m4 321 0
		.PHASE(ADC_PHASE)
`line base.m4 321 0
	) adc_master_5 (
`line base.m4 321 0
		.clk(clk),
`line base.m4 321 0
		.miso(adc_sdo[5]),
`line base.m4 321 0
		.sck_wire(adc_sck[5]),
`line base.m4 321 0
		.ss_L(adc_conv_L[5]),
`line base.m4 321 0
		.finished(adc_finished_5),
`line base.m4 321 0
		.arm(adc_arm_5),
`line base.m4 321 0
		.from_slave(from_adc_5)
`line base.m4 321 0
	)
`line base.m4 321 0
;

`line base.m4 322 0
	spi_master_ss_no_write #(
`line base.m4 322 0
		.WID(ADC_TYPE1_WID),
`line base.m4 322 0
		.WID_LEN(ADC_WID_SIZ),
`line base.m4 322 0
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
`line base.m4 322 0
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 322 0
		.SS_WAIT(ADC_CONV_WAIT),
`line base.m4 322 0
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
`line base.m4 322 0
		.POLARITY(ADC_POLARITY),
`line base.m4 322 0
		.PHASE(ADC_PHASE)
`line base.m4 322 0
	) adc_master_6 (
`line base.m4 322 0
		.clk(clk),
`line base.m4 322 0
		.miso(adc_sdo[6]),
`line base.m4 322 0
		.sck_wire(adc_sck[6]),
`line base.m4 322 0
		.ss_L(adc_conv_L[6]),
`line base.m4 322 0
		.finished(adc_finished_6),
`line base.m4 322 0
		.arm(adc_arm_6),
`line base.m4 322 0
		.from_slave(from_adc_6)
`line base.m4 322 0
	)
`line base.m4 322 0
;

`line base.m4 323 0
	spi_master_ss_no_write #(
`line base.m4 323 0
		.WID(ADC_TYPE1_WID),
`line base.m4 323 0
		.WID_LEN(ADC_WID_SIZ),
`line base.m4 323 0
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
`line base.m4 323 0
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_SIZ),
`line base.m4 323 0
		.SS_WAIT(ADC_CONV_WAIT),
`line base.m4 323 0
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
`line base.m4 323 0
		.POLARITY(ADC_POLARITY),
`line base.m4 323 0
		.PHASE(ADC_PHASE)
`line base.m4 323 0
	) adc_master_7 (
`line base.m4 323 0
		.clk(clk),
`line base.m4 323 0
		.miso(adc_sdo[7]),
`line base.m4 323 0
		.sck_wire(adc_sck[7]),
`line base.m4 323 0
		.ss_L(adc_conv_L[7]),
`line base.m4 323 0
		.finished(adc_finished_7),
`line base.m4 323 0
		.arm(adc_arm_7),
`line base.m4 323 0
		.from_slave(from_adc_7)
`line base.m4 323 0
	)
`line base.m4 323 0
;

endmodule
`undefineall
