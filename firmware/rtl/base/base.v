

/*********************************************************/
/********************** M4 macros ************************/
/*********************************************************/








/*********************************************************/
/*********************** Verilog *************************/
/*********************************************************/

`include "control_loop_cmds.vh"
module base #(
	parameter DAC_PORTS = 2,
`define DAC_PORTS_CONTROL_LOOP (DAC_PORTS + 1)

	parameter DAC_NUM = 8,
	parameter DAC_WID = 24,
	parameter DAC_WID_LEN = 5,
	parameter DAC_POLARITY = 0,
	parameter DAC_PHASE = 1,
	parameter DAC_CYCLE_HALF_WAIT = 10,
	parameter DAC_CYCLE_HALF_WAIT_SIZ = 4,
	parameter DAC_SS_WAIT = 5,
	parameter DAC_SS_WAIT_SIZ = 3,
	parameter WF_TIMER_WID = 32,
	parameter WF_WORD_WID = 24,
	parameter WF_WORD_AMNT_WID = 11,
	parameter [WORD_AMNT_WID-1:0] WF_WORD_AMNT = 2047,
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

	
	input [`DAC_PORTS_CONTROL_LOOP-1:0] dac_sel_0,
	output dac_finished_0,
	input dac_arm_0,
	output [DAC_WID-1:0] from_dac_0,
	input [DAC_WID-1:0] to_dac_0,

	input wf_arm_0,
	input [TIMER_WID-1:0] wf_time_to_wait_0,
	input wf_refresh_start_0,
	input [RAM_WID-1:0] wf_start_addr_0,
	output wf_refresh_finished_0,

	output [RAM_WID-1:0] wf_ram_dma_addr_0,
	input [RAM_WORD_WID-1:0] wf_ram_word_0,
	output wf_ram_read_0,
	input wf_ram_valid_0
,
	
	input [DAC_PORTS-1:0] dac_sel_1,
	output dac_finished_1,
	input dac_arm_1,
	output [DAC_WID-1:0] from_dac_1,
	input [DAC_WID-1:0] to_dac_1,

	input wf_arm_1,
	input [TIMER_WID-1:0] wf_time_to_wait_1,
	input wf_refresh_start_1,
	input [RAM_WID-1:0] wf_start_addr_1,
	output wf_refresh_finished_1,

	output [RAM_WID-1:0] wf_ram_dma_addr_1,
	input [RAM_WORD_WID-1:0] wf_ram_word_1,
	output wf_ram_read_1,
	input wf_ram_valid_1
,
	
	input [DAC_PORTS-1:0] dac_sel_2,
	output dac_finished_2,
	input dac_arm_2,
	output [DAC_WID-1:0] from_dac_2,
	input [DAC_WID-1:0] to_dac_2,

	input wf_arm_2,
	input [TIMER_WID-1:0] wf_time_to_wait_2,
	input wf_refresh_start_2,
	input [RAM_WID-1:0] wf_start_addr_2,
	output wf_refresh_finished_2,

	output [RAM_WID-1:0] wf_ram_dma_addr_2,
	input [RAM_WORD_WID-1:0] wf_ram_word_2,
	output wf_ram_read_2,
	input wf_ram_valid_2
,
	
	input [DAC_PORTS-1:0] dac_sel_3,
	output dac_finished_3,
	input dac_arm_3,
	output [DAC_WID-1:0] from_dac_3,
	input [DAC_WID-1:0] to_dac_3,

	input wf_arm_3,
	input [TIMER_WID-1:0] wf_time_to_wait_3,
	input wf_refresh_start_3,
	input [RAM_WID-1:0] wf_start_addr_3,
	output wf_refresh_finished_3,

	output [RAM_WID-1:0] wf_ram_dma_addr_3,
	input [RAM_WORD_WID-1:0] wf_ram_word_3,
	output wf_ram_read_3,
	input wf_ram_valid_3
,
	
	input [DAC_PORTS-1:0] dac_sel_4,
	output dac_finished_4,
	input dac_arm_4,
	output [DAC_WID-1:0] from_dac_4,
	input [DAC_WID-1:0] to_dac_4,

	input wf_arm_4,
	input [TIMER_WID-1:0] wf_time_to_wait_4,
	input wf_refresh_start_4,
	input [RAM_WID-1:0] wf_start_addr_4,
	output wf_refresh_finished_4,

	output [RAM_WID-1:0] wf_ram_dma_addr_4,
	input [RAM_WORD_WID-1:0] wf_ram_word_4,
	output wf_ram_read_4,
	input wf_ram_valid_4
,
	
	input [DAC_PORTS-1:0] dac_sel_5,
	output dac_finished_5,
	input dac_arm_5,
	output [DAC_WID-1:0] from_dac_5,
	input [DAC_WID-1:0] to_dac_5,

	input wf_arm_5,
	input [TIMER_WID-1:0] wf_time_to_wait_5,
	input wf_refresh_start_5,
	input [RAM_WID-1:0] wf_start_addr_5,
	output wf_refresh_finished_5,

	output [RAM_WID-1:0] wf_ram_dma_addr_5,
	input [RAM_WORD_WID-1:0] wf_ram_word_5,
	output wf_ram_read_5,
	input wf_ram_valid_5
,
	
	input [DAC_PORTS-1:0] dac_sel_6,
	output dac_finished_6,
	input dac_arm_6,
	output [DAC_WID-1:0] from_dac_6,
	input [DAC_WID-1:0] to_dac_6,

	input wf_arm_6,
	input [TIMER_WID-1:0] wf_time_to_wait_6,
	input wf_refresh_start_6,
	input [RAM_WID-1:0] wf_start_addr_6,
	output wf_refresh_finished_6,

	output [RAM_WID-1:0] wf_ram_dma_addr_6,
	input [RAM_WORD_WID-1:0] wf_ram_word_6,
	output wf_ram_read_6,
	input wf_ram_valid_6
,
	
	input [DAC_PORTS-1:0] dac_sel_7,
	output dac_finished_7,
	input dac_arm_7,
	output [DAC_WID-1:0] from_dac_7,
	input [DAC_WID-1:0] to_dac_7,

	input wf_arm_7,
	input [TIMER_WID-1:0] wf_time_to_wait_7,
	input wf_refresh_start_7,
	input [RAM_WID-1:0] wf_start_addr_7,
	output wf_refresh_finished_7,

	output [RAM_WID-1:0] wf_ram_dma_addr_7,
	input [RAM_WORD_WID-1:0] wf_ram_word_7,
	output wf_ram_read_7,
	input wf_ram_valid_7
,

	input [`ADC_PORTS_CONTROL_LOOP-1:0] adc_sel_0,

	
	output adc_finished_0,
	input adc_arm_0,
	output [ADC_TYPE1_WID-1:0] from_adc_0
,
	
	output adc_finished_1,
	input adc_arm_1,
	output [ADC_TYPE1_WID-1:0] from_adc_1
,
	
	output adc_finished_2,
	input adc_arm_2,
	output [ADC_TYPE1_WID-1:0] from_adc_2
,
	
	output adc_finished_3,
	input adc_arm_3,
	output [ADC_TYPE1_WID-1:0] from_adc_3
,
	
	output adc_finished_4,
	input adc_arm_4,
	output [ADC_TYPE1_WID-1:0] from_adc_4
,
	
	output adc_finished_5,
	input adc_arm_5,
	output [ADC_TYPE1_WID-1:0] from_adc_5
,
	
	output adc_finished_6,
	input adc_arm_6,
	output [ADC_TYPE1_WID-1:0] from_adc_6
,
	
	output adc_finished_7,
	input adc_arm_7,
	output [ADC_TYPE1_WID-1:0] from_adc_7
,

	output cl_in_loop,
	input [`CONTROL_LOOP_CMD_WIDTH-1:0] cl_cmd,
	input [`CL_DATA_WID-1:0] cl_word_in,
	output reg [`CL_DATA_WID-1:0] cl_word_out,
	input cl_start_cmd,
	output reg cl_finish_cmd
);

wire [ADC_NUM-1:0] adc_conv_L;
assign adc_conv = !adc_conv_L;


	wire [`DAC_PORTS_CONTROL_LOOP-1:0] mosi_port_0;
	wire [`DAC_PORTS_CONTROL_LOOP-1:0] miso_port_0;
	wire [`DAC_PORTS_CONTROL_LOOP-1:0] sck_port_0;
	wire [`DAC_PORTS_CONTROL_LOOP-1:0] ss_L_port_0;

	spi_switch #(
		.PORTS(`DAC_PORTS_CONTROL_LOOP)
	) switch_0 (
		.select(dac_sel_0),
		.mosi(dac_mosi[0]),
		.miso(dac_miso[0]),
		.sck(dac_sck[0]),
		.ss(dac_ss_L[0]),

		.mosi_ports(mosi_port_0),
		.miso_ports(miso_port_0),
		.sck_ports(sck_port_0),
		.ss_ports(ss_L_port_0)
	);

	spi_master_ss #(
		.WID(DAC_WID),
		.WID_LEN(DAC_WID_SIZ),
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
		.POLARITY(DAC_POLARITY),
		.PHASE(DAC_PHASE),
		.SS_WAIT(DAC_SS_WAIT),
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
	) dac_master_0 (
		.clk(clk),
		.mosi(mosi_port_0[0]),
		.miso(miso_port_0[0]),
		.sck_wire(sck_port_0[0]),
		.ss_L(ss_port_0[0]),
		.finished(dac_finished_0),
		.arm(dac_arm_0),
		.from_slave(from_dac_0),
		.to_slave(to_dac_0)
	);

	waveform #(
		.DAC_WID(DAC_WID),
		.DAC_WID_SIZ(DAC_WID_SIZ),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
		.DAC_SS_WAIT(DAC_SS_WAIT),
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
		.TIMER_WID(WF_TIMER_WID),
		.WORD_WID(WF_WORD_WID),
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
		.WORD_AMNT(WF_WORD_AMNT),
		.RAM_WID(WF_RAM_WID),
		.RAM_WORD_WID(WF_RAM_WORD_WID),
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
	) waveform_0 (
		.clk(clk),
		.arm(wf_arm_0),
		.time_to_wait(wf_time_to_wait_0),
		.refresh_start(wf_refresh_start_0),
		.start_addr(wf_start_addr_0),
		.refresh_finished(wf_refresh_finished_0),
		.ram_dma_adr(wf_ram_dma_addr_0),
		.ram_word(wf_ram_word_0),
		.ram_read(wf_ram_read_0),
		.ram_valid(wf_ram_valid_0),
		.mosi(mosi_port_0[1]),
		.miso(miso_port_0[1]),
		.sck(sck_port_0[1]),
		.ss_L(ss_port_0[1])
	)
;

	wire [DAC_PORTS-1:0] mosi_port_1;
	wire [DAC_PORTS-1:0] miso_port_1;
	wire [DAC_PORTS-1:0] sck_port_1;
	wire [DAC_PORTS-1:0] ss_L_port_1;

	spi_switch #(
		.PORTS(`DAC_PORTS_CONTROL_LOOP)
	) switch_1 (
		.select(dac_sel_1),
		.mosi(dac_mosi[0]),
		.miso(dac_miso[0]),
		.sck(dac_sck[0]),
		.ss(dac_ss_L[0]),

		.mosi_ports(mosi_port_1),
		.miso_ports(miso_port_1),
		.sck_ports(sck_port_1),
		.ss_ports(ss_L_port_1)
	);

	spi_master_ss #(
		.WID(DAC_WID),
		.WID_LEN(DAC_WID_SIZ),
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
		.POLARITY(DAC_POLARITY),
		.PHASE(DAC_PHASE),
		.SS_WAIT(DAC_SS_WAIT),
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
	) dac_master_1 (
		.clk(clk),
		.mosi(mosi_port_1[0]),
		.miso(miso_port_1[0]),
		.sck_wire(sck_port_1[0]),
		.ss_L(ss_port_1[0]),
		.finished(dac_finished_1),
		.arm(dac_arm_1),
		.from_slave(from_dac_1),
		.to_slave(to_dac_1)
	);

	waveform #(
		.DAC_WID(DAC_WID),
		.DAC_WID_SIZ(DAC_WID_SIZ),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
		.DAC_SS_WAIT(DAC_SS_WAIT),
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
		.TIMER_WID(WF_TIMER_WID),
		.WORD_WID(WF_WORD_WID),
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
		.WORD_AMNT(WF_WORD_AMNT),
		.RAM_WID(WF_RAM_WID),
		.RAM_WORD_WID(WF_RAM_WORD_WID),
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
	) waveform_1 (
		.clk(clk),
		.arm(wf_arm_1),
		.time_to_wait(wf_time_to_wait_1),
		.refresh_start(wf_refresh_start_1),
		.start_addr(wf_start_addr_1),
		.refresh_finished(wf_refresh_finished_1),
		.ram_dma_adr(wf_ram_dma_addr_1),
		.ram_word(wf_ram_word_1),
		.ram_read(wf_ram_read_1),
		.ram_valid(wf_ram_valid_1),
		.mosi(mosi_port_1[1]),
		.miso(miso_port_1[1]),
		.sck(sck_port_1[1]),
		.ss_L(ss_port_1[1])
	)
;

	wire [DAC_PORTS-1:0] mosi_port_2;
	wire [DAC_PORTS-1:0] miso_port_2;
	wire [DAC_PORTS-1:0] sck_port_2;
	wire [DAC_PORTS-1:0] ss_L_port_2;

	spi_switch #(
		.PORTS(`DAC_PORTS_CONTROL_LOOP)
	) switch_2 (
		.select(dac_sel_2),
		.mosi(dac_mosi[0]),
		.miso(dac_miso[0]),
		.sck(dac_sck[0]),
		.ss(dac_ss_L[0]),

		.mosi_ports(mosi_port_2),
		.miso_ports(miso_port_2),
		.sck_ports(sck_port_2),
		.ss_ports(ss_L_port_2)
	);

	spi_master_ss #(
		.WID(DAC_WID),
		.WID_LEN(DAC_WID_SIZ),
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
		.POLARITY(DAC_POLARITY),
		.PHASE(DAC_PHASE),
		.SS_WAIT(DAC_SS_WAIT),
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
	) dac_master_2 (
		.clk(clk),
		.mosi(mosi_port_2[0]),
		.miso(miso_port_2[0]),
		.sck_wire(sck_port_2[0]),
		.ss_L(ss_port_2[0]),
		.finished(dac_finished_2),
		.arm(dac_arm_2),
		.from_slave(from_dac_2),
		.to_slave(to_dac_2)
	);

	waveform #(
		.DAC_WID(DAC_WID),
		.DAC_WID_SIZ(DAC_WID_SIZ),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
		.DAC_SS_WAIT(DAC_SS_WAIT),
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
		.TIMER_WID(WF_TIMER_WID),
		.WORD_WID(WF_WORD_WID),
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
		.WORD_AMNT(WF_WORD_AMNT),
		.RAM_WID(WF_RAM_WID),
		.RAM_WORD_WID(WF_RAM_WORD_WID),
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
	) waveform_2 (
		.clk(clk),
		.arm(wf_arm_2),
		.time_to_wait(wf_time_to_wait_2),
		.refresh_start(wf_refresh_start_2),
		.start_addr(wf_start_addr_2),
		.refresh_finished(wf_refresh_finished_2),
		.ram_dma_adr(wf_ram_dma_addr_2),
		.ram_word(wf_ram_word_2),
		.ram_read(wf_ram_read_2),
		.ram_valid(wf_ram_valid_2),
		.mosi(mosi_port_2[1]),
		.miso(miso_port_2[1]),
		.sck(sck_port_2[1]),
		.ss_L(ss_port_2[1])
	)
;

	wire [DAC_PORTS-1:0] mosi_port_3;
	wire [DAC_PORTS-1:0] miso_port_3;
	wire [DAC_PORTS-1:0] sck_port_3;
	wire [DAC_PORTS-1:0] ss_L_port_3;

	spi_switch #(
		.PORTS(`DAC_PORTS_CONTROL_LOOP)
	) switch_3 (
		.select(dac_sel_3),
		.mosi(dac_mosi[0]),
		.miso(dac_miso[0]),
		.sck(dac_sck[0]),
		.ss(dac_ss_L[0]),

		.mosi_ports(mosi_port_3),
		.miso_ports(miso_port_3),
		.sck_ports(sck_port_3),
		.ss_ports(ss_L_port_3)
	);

	spi_master_ss #(
		.WID(DAC_WID),
		.WID_LEN(DAC_WID_SIZ),
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
		.POLARITY(DAC_POLARITY),
		.PHASE(DAC_PHASE),
		.SS_WAIT(DAC_SS_WAIT),
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
	) dac_master_3 (
		.clk(clk),
		.mosi(mosi_port_3[0]),
		.miso(miso_port_3[0]),
		.sck_wire(sck_port_3[0]),
		.ss_L(ss_port_3[0]),
		.finished(dac_finished_3),
		.arm(dac_arm_3),
		.from_slave(from_dac_3),
		.to_slave(to_dac_3)
	);

	waveform #(
		.DAC_WID(DAC_WID),
		.DAC_WID_SIZ(DAC_WID_SIZ),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
		.DAC_SS_WAIT(DAC_SS_WAIT),
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
		.TIMER_WID(WF_TIMER_WID),
		.WORD_WID(WF_WORD_WID),
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
		.WORD_AMNT(WF_WORD_AMNT),
		.RAM_WID(WF_RAM_WID),
		.RAM_WORD_WID(WF_RAM_WORD_WID),
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
	) waveform_3 (
		.clk(clk),
		.arm(wf_arm_3),
		.time_to_wait(wf_time_to_wait_3),
		.refresh_start(wf_refresh_start_3),
		.start_addr(wf_start_addr_3),
		.refresh_finished(wf_refresh_finished_3),
		.ram_dma_adr(wf_ram_dma_addr_3),
		.ram_word(wf_ram_word_3),
		.ram_read(wf_ram_read_3),
		.ram_valid(wf_ram_valid_3),
		.mosi(mosi_port_3[1]),
		.miso(miso_port_3[1]),
		.sck(sck_port_3[1]),
		.ss_L(ss_port_3[1])
	)
;

	wire [DAC_PORTS-1:0] mosi_port_4;
	wire [DAC_PORTS-1:0] miso_port_4;
	wire [DAC_PORTS-1:0] sck_port_4;
	wire [DAC_PORTS-1:0] ss_L_port_4;

	spi_switch #(
		.PORTS(`DAC_PORTS_CONTROL_LOOP)
	) switch_4 (
		.select(dac_sel_4),
		.mosi(dac_mosi[0]),
		.miso(dac_miso[0]),
		.sck(dac_sck[0]),
		.ss(dac_ss_L[0]),

		.mosi_ports(mosi_port_4),
		.miso_ports(miso_port_4),
		.sck_ports(sck_port_4),
		.ss_ports(ss_L_port_4)
	);

	spi_master_ss #(
		.WID(DAC_WID),
		.WID_LEN(DAC_WID_SIZ),
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
		.POLARITY(DAC_POLARITY),
		.PHASE(DAC_PHASE),
		.SS_WAIT(DAC_SS_WAIT),
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
	) dac_master_4 (
		.clk(clk),
		.mosi(mosi_port_4[0]),
		.miso(miso_port_4[0]),
		.sck_wire(sck_port_4[0]),
		.ss_L(ss_port_4[0]),
		.finished(dac_finished_4),
		.arm(dac_arm_4),
		.from_slave(from_dac_4),
		.to_slave(to_dac_4)
	);

	waveform #(
		.DAC_WID(DAC_WID),
		.DAC_WID_SIZ(DAC_WID_SIZ),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
		.DAC_SS_WAIT(DAC_SS_WAIT),
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
		.TIMER_WID(WF_TIMER_WID),
		.WORD_WID(WF_WORD_WID),
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
		.WORD_AMNT(WF_WORD_AMNT),
		.RAM_WID(WF_RAM_WID),
		.RAM_WORD_WID(WF_RAM_WORD_WID),
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
	) waveform_4 (
		.clk(clk),
		.arm(wf_arm_4),
		.time_to_wait(wf_time_to_wait_4),
		.refresh_start(wf_refresh_start_4),
		.start_addr(wf_start_addr_4),
		.refresh_finished(wf_refresh_finished_4),
		.ram_dma_adr(wf_ram_dma_addr_4),
		.ram_word(wf_ram_word_4),
		.ram_read(wf_ram_read_4),
		.ram_valid(wf_ram_valid_4),
		.mosi(mosi_port_4[1]),
		.miso(miso_port_4[1]),
		.sck(sck_port_4[1]),
		.ss_L(ss_port_4[1])
	)
;

	wire [DAC_PORTS-1:0] mosi_port_5;
	wire [DAC_PORTS-1:0] miso_port_5;
	wire [DAC_PORTS-1:0] sck_port_5;
	wire [DAC_PORTS-1:0] ss_L_port_5;

	spi_switch #(
		.PORTS(`DAC_PORTS_CONTROL_LOOP)
	) switch_5 (
		.select(dac_sel_5),
		.mosi(dac_mosi[0]),
		.miso(dac_miso[0]),
		.sck(dac_sck[0]),
		.ss(dac_ss_L[0]),

		.mosi_ports(mosi_port_5),
		.miso_ports(miso_port_5),
		.sck_ports(sck_port_5),
		.ss_ports(ss_L_port_5)
	);

	spi_master_ss #(
		.WID(DAC_WID),
		.WID_LEN(DAC_WID_SIZ),
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
		.POLARITY(DAC_POLARITY),
		.PHASE(DAC_PHASE),
		.SS_WAIT(DAC_SS_WAIT),
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
	) dac_master_5 (
		.clk(clk),
		.mosi(mosi_port_5[0]),
		.miso(miso_port_5[0]),
		.sck_wire(sck_port_5[0]),
		.ss_L(ss_port_5[0]),
		.finished(dac_finished_5),
		.arm(dac_arm_5),
		.from_slave(from_dac_5),
		.to_slave(to_dac_5)
	);

	waveform #(
		.DAC_WID(DAC_WID),
		.DAC_WID_SIZ(DAC_WID_SIZ),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
		.DAC_SS_WAIT(DAC_SS_WAIT),
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
		.TIMER_WID(WF_TIMER_WID),
		.WORD_WID(WF_WORD_WID),
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
		.WORD_AMNT(WF_WORD_AMNT),
		.RAM_WID(WF_RAM_WID),
		.RAM_WORD_WID(WF_RAM_WORD_WID),
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
	) waveform_5 (
		.clk(clk),
		.arm(wf_arm_5),
		.time_to_wait(wf_time_to_wait_5),
		.refresh_start(wf_refresh_start_5),
		.start_addr(wf_start_addr_5),
		.refresh_finished(wf_refresh_finished_5),
		.ram_dma_adr(wf_ram_dma_addr_5),
		.ram_word(wf_ram_word_5),
		.ram_read(wf_ram_read_5),
		.ram_valid(wf_ram_valid_5),
		.mosi(mosi_port_5[1]),
		.miso(miso_port_5[1]),
		.sck(sck_port_5[1]),
		.ss_L(ss_port_5[1])
	)
;

	wire [DAC_PORTS-1:0] mosi_port_6;
	wire [DAC_PORTS-1:0] miso_port_6;
	wire [DAC_PORTS-1:0] sck_port_6;
	wire [DAC_PORTS-1:0] ss_L_port_6;

	spi_switch #(
		.PORTS(`DAC_PORTS_CONTROL_LOOP)
	) switch_6 (
		.select(dac_sel_6),
		.mosi(dac_mosi[0]),
		.miso(dac_miso[0]),
		.sck(dac_sck[0]),
		.ss(dac_ss_L[0]),

		.mosi_ports(mosi_port_6),
		.miso_ports(miso_port_6),
		.sck_ports(sck_port_6),
		.ss_ports(ss_L_port_6)
	);

	spi_master_ss #(
		.WID(DAC_WID),
		.WID_LEN(DAC_WID_SIZ),
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
		.POLARITY(DAC_POLARITY),
		.PHASE(DAC_PHASE),
		.SS_WAIT(DAC_SS_WAIT),
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
	) dac_master_6 (
		.clk(clk),
		.mosi(mosi_port_6[0]),
		.miso(miso_port_6[0]),
		.sck_wire(sck_port_6[0]),
		.ss_L(ss_port_6[0]),
		.finished(dac_finished_6),
		.arm(dac_arm_6),
		.from_slave(from_dac_6),
		.to_slave(to_dac_6)
	);

	waveform #(
		.DAC_WID(DAC_WID),
		.DAC_WID_SIZ(DAC_WID_SIZ),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
		.DAC_SS_WAIT(DAC_SS_WAIT),
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
		.TIMER_WID(WF_TIMER_WID),
		.WORD_WID(WF_WORD_WID),
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
		.WORD_AMNT(WF_WORD_AMNT),
		.RAM_WID(WF_RAM_WID),
		.RAM_WORD_WID(WF_RAM_WORD_WID),
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
	) waveform_6 (
		.clk(clk),
		.arm(wf_arm_6),
		.time_to_wait(wf_time_to_wait_6),
		.refresh_start(wf_refresh_start_6),
		.start_addr(wf_start_addr_6),
		.refresh_finished(wf_refresh_finished_6),
		.ram_dma_adr(wf_ram_dma_addr_6),
		.ram_word(wf_ram_word_6),
		.ram_read(wf_ram_read_6),
		.ram_valid(wf_ram_valid_6),
		.mosi(mosi_port_6[1]),
		.miso(miso_port_6[1]),
		.sck(sck_port_6[1]),
		.ss_L(ss_port_6[1])
	)
;

	wire [DAC_PORTS-1:0] mosi_port_7;
	wire [DAC_PORTS-1:0] miso_port_7;
	wire [DAC_PORTS-1:0] sck_port_7;
	wire [DAC_PORTS-1:0] ss_L_port_7;

	spi_switch #(
		.PORTS(`DAC_PORTS_CONTROL_LOOP)
	) switch_7 (
		.select(dac_sel_7),
		.mosi(dac_mosi[0]),
		.miso(dac_miso[0]),
		.sck(dac_sck[0]),
		.ss(dac_ss_L[0]),

		.mosi_ports(mosi_port_7),
		.miso_ports(miso_port_7),
		.sck_ports(sck_port_7),
		.ss_ports(ss_L_port_7)
	);

	spi_master_ss #(
		.WID(DAC_WID),
		.WID_LEN(DAC_WID_SIZ),
		.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
		.POLARITY(DAC_POLARITY),
		.PHASE(DAC_PHASE),
		.SS_WAIT(DAC_SS_WAIT),
		.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
	) dac_master_7 (
		.clk(clk),
		.mosi(mosi_port_7[0]),
		.miso(miso_port_7[0]),
		.sck_wire(sck_port_7[0]),
		.ss_L(ss_port_7[0]),
		.finished(dac_finished_7),
		.arm(dac_arm_7),
		.from_slave(from_dac_7),
		.to_slave(to_dac_7)
	);

	waveform #(
		.DAC_WID(DAC_WID),
		.DAC_WID_SIZ(DAC_WID_SIZ),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_POLARITY(DAC_POLARITY),
		.DAC_PHASE(DAC_PHASE),
		.DAC_CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
		.DAC_CYCLE_HALF_WAIT_SIZ(DAC_CYCLE_HALF_WAIT_SIZ),
		.DAC_SS_WAIT(DAC_SS_WAIT),
		.DAC_SS_WAIT_SIZ(DAC_SS_WAIT_SIZ),
		.TIMER_WID(WF_TIMER_WID),
		.WORD_WID(WF_WORD_WID),
		.WORD_AMNT_WID(WF_WORD_AMNT_WID),
		.WORD_AMNT(WF_WORD_AMNT),
		.RAM_WID(WF_RAM_WID),
		.RAM_WORD_WID(WF_RAM_WORD_WID),
		.RAM_WORD_INCR(WF_RAM_WORD_INCR)
	) waveform_7 (
		.clk(clk),
		.arm(wf_arm_7),
		.time_to_wait(wf_time_to_wait_7),
		.refresh_start(wf_refresh_start_7),
		.start_addr(wf_start_addr_7),
		.refresh_finished(wf_refresh_finished_7),
		.ram_dma_adr(wf_ram_dma_addr_7),
		.ram_word(wf_ram_word_7),
		.ram_read(wf_ram_read_7),
		.ram_valid(wf_ram_valid_7),
		.mosi(mosi_port_7[1]),
		.miso(miso_port_7[1]),
		.sck(sck_port_7[1]),
		.ss_L(ss_port_7[1])
	)
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
	.ss(adc_conv_L[0]),

	.mosi_ports(adc_mosi_port_0_unassigned),
	.miso_ports(adc_sdo_port_0),
	.sck_ports(adc_sck_port_0),
	.ss_ports(adc_conv_port_0)
);

spi_master_no_write #(
	.WID(ADC_TYPE1_WID),
	.WID_LEN(ADC_WID_SIZ),
	.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
	.TIMER_LEN(ADC_CYCLE_HALF_WAIT_LEN),
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


	spi_master_no_write #(
		.WID(ADC_TYPE1_WID),
		.WID_LEN(ADC_WID_SIZ),
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_LEN),
		.SS_WAIT(ADC_CONV_WAIT),
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
		.POLARITY(ADC_POLARITY),
		.PHASE(ADC_PHASE)
	) adc_master_1 (
		.clk(clk),
		.miso(adc_sdo[1]),
		.sck_wire(adc_sck[1]),
		.ss_L(adc_conv_L[1]),
		.finished(adc_finished_1),
		.arm(adc_arm_1),
		.from_slave(from_adc_1)
	)
;

	spi_master_no_write #(
		.WID(ADC_TYPE1_WID),
		.WID_LEN(ADC_WID_SIZ),
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_LEN),
		.SS_WAIT(ADC_CONV_WAIT),
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
		.POLARITY(ADC_POLARITY),
		.PHASE(ADC_PHASE)
	) adc_master_2 (
		.clk(clk),
		.miso(adc_sdo[2]),
		.sck_wire(adc_sck[2]),
		.ss_L(adc_conv_L[2]),
		.finished(adc_finished_2),
		.arm(adc_arm_2),
		.from_slave(from_adc_2)
	)
;

	spi_master_no_write #(
		.WID(ADC_TYPE1_WID),
		.WID_LEN(ADC_WID_SIZ),
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_LEN),
		.SS_WAIT(ADC_CONV_WAIT),
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
		.POLARITY(ADC_POLARITY),
		.PHASE(ADC_PHASE)
	) adc_master_3 (
		.clk(clk),
		.miso(adc_sdo[3]),
		.sck_wire(adc_sck[3]),
		.ss_L(adc_conv_L[3]),
		.finished(adc_finished_3),
		.arm(adc_arm_3),
		.from_slave(from_adc_3)
	)
;

	spi_master_no_write #(
		.WID(ADC_TYPE1_WID),
		.WID_LEN(ADC_WID_SIZ),
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_LEN),
		.SS_WAIT(ADC_CONV_WAIT),
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
		.POLARITY(ADC_POLARITY),
		.PHASE(ADC_PHASE)
	) adc_master_4 (
		.clk(clk),
		.miso(adc_sdo[4]),
		.sck_wire(adc_sck[4]),
		.ss_L(adc_conv_L[4]),
		.finished(adc_finished_4),
		.arm(adc_arm_4),
		.from_slave(from_adc_4)
	)
;

	spi_master_no_write #(
		.WID(ADC_TYPE1_WID),
		.WID_LEN(ADC_WID_SIZ),
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_LEN),
		.SS_WAIT(ADC_CONV_WAIT),
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
		.POLARITY(ADC_POLARITY),
		.PHASE(ADC_PHASE)
	) adc_master_5 (
		.clk(clk),
		.miso(adc_sdo[5]),
		.sck_wire(adc_sck[5]),
		.ss_L(adc_conv_L[5]),
		.finished(adc_finished_5),
		.arm(adc_arm_5),
		.from_slave(from_adc_5)
	)
;

	spi_master_no_write #(
		.WID(ADC_TYPE1_WID),
		.WID_LEN(ADC_WID_SIZ),
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_LEN),
		.SS_WAIT(ADC_CONV_WAIT),
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
		.POLARITY(ADC_POLARITY),
		.PHASE(ADC_PHASE)
	) adc_master_6 (
		.clk(clk),
		.miso(adc_sdo[6]),
		.sck_wire(adc_sck[6]),
		.ss_L(adc_conv_L[6]),
		.finished(adc_finished_6),
		.arm(adc_arm_6),
		.from_slave(from_adc_6)
	)
;

	spi_master_no_write #(
		.WID(ADC_TYPE1_WID),
		.WID_LEN(ADC_WID_SIZ),
		.CYCLE_HALF_WAIT(ADC_CYCLE_HALF_WAIT),
		.TIMER_LEN(ADC_CYCLE_HALF_WAIT_LEN),
		.SS_WAIT(ADC_CONV_WAIT),
		.SS_WAIT_TIMER_LEN(ADC_CONV_WAIT_SIZ),
		.POLARITY(ADC_POLARITY),
		.PHASE(ADC_PHASE)
	) adc_master_7 (
		.clk(clk),
		.miso(adc_sdo[7]),
		.sck_wire(adc_sck[7]),
		.ss_L(adc_conv_L[7]),
		.finished(adc_finished_7),
		.arm(adc_arm_7),
		.from_slave(from_adc_7)
	)
;

endmodule
`undefineall
