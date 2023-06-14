`timescale 10ns/10ns
`include "raster_cmds.vh"
`include "ram_shim_cmds.vh"
module raster_sim #(
	parameter DAC_WAIT_BETWEEN_CMD = 10,

	parameter DAT_WID = 24,
	parameter RAM_WORD = 16,
	parameter RAM_WID = 32,

	parameter RAM_SIM_WAIT_TIME = 72,
	parameter ADC_SIM_WAIT_TIME = 54
) (
	input clk,
	output is_running,

	input [`RASTER_CMD_WID-1:0] kernel_cmd,
	input [`RASTER_DATA_WID-1:0] kernel_data_in,
	output [`RASTER_DATA_WID-1:0] kernel_data_out,
	input kernel_ready,
	output kernel_finished,

	output [`DAC_DATA_WID-1:0] x_dac,
	output [`DAC_DATA_WID-1:0] y_dac,

	output reg [`ADCNUM-1:0] adc_arm,
	input [`MAX_ADC_DATA_WID-1:0] adc_data [`ADCNUM-1:0],
	input [`ADCNUM-1:0] adc_finished,

	/* DMA interface */
	output [RAM_WORD-1:0] word,
	output [RAM_WID-1:0] addr,
	output reg ram_write,
	input ram_valid,

	/* RAM shim control interface */
	input [RAM_WID-1:0] shim_cmd_data,
	input [`RAM_SHIM_CMD_WID-1:0] shim_cmd,
	input shim_cmd_active,
	output shim_cmd_finished,
	output [RAM_WID-1:0] shim_cmd_data_out
);

/**** DAC simulation.
 * The code to handle each axis (X and Y) are similar.
 ****/

reg [`DAC_WID-1:0] coord_write_buf [1:0];
/* verilator lint_off UNUSEDSIGNAL */
reg [`DAC_WID-1:0] coord_to_dac [1:0];
/* verilator lint_on UNUSEDSIGNAL */
reg [`DAC_WID-1:0] coord_from_dac [1:0];
wire coord_arm [1:0];
reg coord_finished [1:0];

reg [`DAC_DATA_WID-1:0] coord_dac [1:0];
assign x_dac = coord_dac[0];
assign y_dac = coord_dac[1];

genvar ci;
generate for (ci = 0; ci < 2; ci = ci + 1) begin
	initial begin
		coord_write_buf[ci] = 0;
		coord_to_dac[ci] = 0;
		coord_from_dac[ci] = 0;
		coord_finished[ci] = 0;
	end

	always @ (posedge clk) begin
		if (coord_arm[ci] && !coord_finished[ci]) begin
			coord_to_dac[ci] <= coord_write_buf[ci];
			coord_finished[ci] <= 1;

			case (coord_from_dac[ci][`DAC_WID-1:`DAC_DATA_WID])
			4'b1001: begin
				coord_write_buf[ci] <= {4'b1001, coord_dac[ci]};
			end
			4'b0001: begin
				coord_write_buf[ci] <= 0;
				coord_dac[ci] <= coord_from_dac[ci][`DAC_DATA_WID-1:0];
			end
			default: ;
			endcase

		end else if (!coord_arm[ci]) begin
			coord_finished[ci] <= 0;
		end
	end
end endgenerate

/**** ADC Shim
 * This shim and the shim below implement delays to simulate the actual
 * acquisition process. The values are then floated up to the Verilator
 * simulator so the C++ code doesn't have to implement timers manually.
 ****/

wire [`ADCNUM-1:0] adc_arm_internal;
reg [31:0] adc_wait_cntr = 0;

always @ (posedge clk) begin
	if (adc_arm_internal != 0) begin
		if (adc_wait_cntr < ADC_SIM_WAIT_TIME) begin
			adc_wait_cntr <= adc_wait_cntr + 1;
		end else begin
			adc_arm <= adc_arm_internal;
		end
	end else begin
		adc_wait_cntr <= 0;
		adc_arm <= 0;
	end
end

/**** RAM Shim ****/

wire ram_write_internal;
reg [31:0] ram_wait_cntr = 0;

always @ (posedge clk) begin
	if (!ram_write_internal) begin
		ram_wait_cntr <= 0;
		ram_write <= 0;
	end else if (ram_wait_cntr < RAM_SIM_WAIT_TIME) begin
		ram_wait_cntr <= ram_wait_cntr + 1;
	end else begin
		ram_write <= 1;
	end
end

wire [`MAX_ADC_DATA_WID-1:0] ram_data;
wire ram_commit;
wire ram_finished;

ram_shim #(
	.DAT_WID(DAT_WID),
	.RAM_WORD(RAM_WORD),
	.RAM_WID(RAM_WID)
) ram (
	.clk(clk),
	.rst(0),
	.data(ram_data),
	.data_commit(ram_commit),
	.finished(ram_finished),
	.word(word),
	.addr(addr),
	.write(ram_write_internal),
	.valid(ram_valid),

	.cmd_data(shim_cmd_data),
	.cmd(shim_cmd),
	.cmd_active(shim_cmd_active),
	.cmd_finished(shim_cmd_finished),
	.cmd_data_out(shim_cmd_data_out)
);

/* Converting array to vector, arrays are easier to handle in Verilator. */
wire [`ADCNUM*`MAX_ADC_DATA_WID-1:0] adc_data_internal;
genvar ii;
generate for (ii = 0; ii < `ADCNUM; ii = ii + 1) begin
	assign adc_data_internal[(ii+1)*`MAX_ADC_DATA_WID-1:ii*`MAX_ADC_DATA_WID]
	       = adc_data[ii];
end endgenerate

raster #(
	.DAC_WAIT_BETWEEN_CMD(DAC_WAIT_BETWEEN_CMD)
) raster (
	.clk(clk),
	.is_running(is_running),

	.kernel_cmd(kernel_cmd),
	.kernel_data_in(kernel_data_in),
	.kernel_data_out(kernel_data_out),
	.kernel_ready(kernel_ready),
	.kernel_finished(kernel_finished),

	.x_arm(coord_arm[0]),
	.x_to_dac(coord_to_dac[0]),
	.x_from_dac(coord_from_dac[0]),
	.x_finished(coord_finished[0]),

	.y_arm(coord_arm[1]),
	.y_to_dac(coord_to_dac[1]),
	.y_from_dac(coord_from_dac[1]),
	.y_finished(coord_finished[1]),

	.adc_arm(adc_arm_internal),
	.adc_data(adc_data_internal),
	.adc_finished(adc_finished),

	.data(ram_data),
	.mem_commit(ram_commit),
	.mem_finished(ram_finished)
);

initial begin
	$dumpfile("raster.fst");
	$dumpvars;
end

endmodule
`undefineall
