`timescale 10ns/10ns
module raster_sim #(
	parameter SAMPLEWID = 9,
	parameter DAC_DATA_WID = 20,
	parameter DAC_WID = 24,
	parameter DAC_WAIT_BETWEEN_CMD = 10,
	parameter TIMER_WID = 4,
	parameter STEPWID = 16,
	parameter ADCNUM = 9,
	parameter MAX_ADC_DATA_WID = 24,

	parameter BASE_ADDR = 32'h1000000,
	parameter MAX_BYTE_WID = 13,
	parameter DAT_WID = 24,
	parameter RAM_WORD = 16,
	parameter RAM_WID = 32,

	parameter RAM_SIM_WAIT_TIME = 54,
	parameter ADC_SIM_WAIT_TIME = 54
) (
	input clk,
	input arm,
	output reg finished,
	output reg running,

	/* Amount of samples in one line (forward) */
	input [SAMPLEWID-1:0] max_samples_in,
	/* Amount of lines in the output. */
	input [SAMPLEWID-1:0] max_lines_in,
	/* Wait time after each step. */
	input [TIMER_WID-1:0] settle_time_in,

	/* Each step goes (x,y) -> (x + dx, y + dy) forward for each line of
	 * the output. */
	input signed [DAC_DATA_WID-1:0] dx_in,
	input signed [DAC_DATA_WID-1:0] dy_in,

	/* Vertical steps to go to the next line. */
	input signed [DAC_DATA_WID-1:0] dx_vert_in,
	input signed [DAC_DATA_WID-1:0] dy_vert_in,

	output reg [DAC_DATA_WID-1:0] coord_dac [1:0],

	/* Connections to all possible ADCs. These are connected to SPI masters
	 * and they will automatically extend ADC value lengths to their highest
	 * values. */
	output reg [ADCNUM-1:0] adc_arm,
	input [MAX_ADC_DATA_WID-1:0] adc_data [ADCNUM-1:0],
	input [ADCNUM-1:0] adc_finished,

	/* Bitmap for which ADCs are used. */
	input [ADCNUM-1:0] adc_used_in,

	/* DMA interface */
	output [RAM_WORD-1:0] word,
	output [RAM_WID-1:0] addr,
	output reg ram_write,
	input ram_valid
);

/**** DAC simulation ****/

reg [DAC_WID-1:0] coord_write_buf [1:0];
reg [DAC_WID-1:0] coord_to_dac [1:0];
reg [DAC_WID-1:0] coord_from_dac [1:0];
wire coord_arm [1:0];
reg coord_finished [1:0];

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

			case (coord_from_dac[ci][DAC_WID-1:DAC_WID-4])
			4'b1001: begin
				coord_write_buf[ci] <= {4'b1001, coord_dac[ci]};
			end
			4'b0001: begin
				coord_write_buf[ci] <= 0;
				coord_dac[ci] <= coord_from_dac[ci][DAC_WID-4-1:0];
			end
			endcase

		end else if (!coord_arm[ci]) begin
			coord_finished[ci] <= 0;
		end
	end
end endgenerate

/**** ADC Shim ****/

wire adc_arm_internal;
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
	end
end

/**** RAM Shim ****/

/* Check all addresses are valid. */
property address_in_range;
	@(posedge clk)
	ram_commit |->
	BASE_ADDR <= addr && addr < BASE_ADDR + (1 << MAX_BYTE_WID);
endproperty
address_in_range_assert: assert property (address_in_range);

wire signed [DAT_WID-1:0] ram_data;
wire ram_commit;
wire ram_write_finished;

wire ram_write_internal = 0;
reg [31:0] ram_cntr = 0;

always @ (posedge clk) begin
	if (ram_commit) begin
		if (ram_cntr < RAM_SIM_WAIT_TIME) begin
			ram_cntr <= ram_cntr + 1;
		end else begin
			ram_write <= 1;
		end
	end else begin
		ram_cntr <= 0;
		ram_write <= 0;
	end
end

ram_shim #(
	.BASE_ADDR(BASE_ADDR),
	.MAX_BYTE_WID(MAX_BYTE_WID),
	.DAT_WID(DAT_WID),
	.RAM_WORD(RAM_WORD),
	.RAM_WID(RAM_WID)
) ram (
	.clk(clk),
	.data(ram_data),
	.commit(ram_commit),
	.finished(ram_write_finished),
	.word(word),
	.addr(addr),
	.write(ram_write_internal),
	.valid(ram_valid)
);

raster #(
	.SAMPLEWID(SAMPLEWID),
	.DAC_DATA_WID(DAC_DATA_WID),
	.DAC_WID(DAC_WID),
	.DAC_WAIT_BETWEEN_CMD(DAC_WAIT_BETWEEN_CMD),
	.TIMER_WID(TIMER_WID),
	.STEPWID(STEPWID),
	.MAX_ADC_DATA_WID(MAX_ADC_DATA_WID)
) raster (
	.clk(clk),
	.arm(arm),
	.finished(finished),
	.running(running),
	.steps_per_sample_in(steps_per_sample_in),
	.max_samples_in(max_samples_in),
	.max_lines_in(max_lines_in),
	.settle_time_in(settle_time_in),
	.dx_in(dx_in),
	.dy_in(dy_in),
	.dx_vert_in(dx_vert_in),
	.dy_vert_in(dy_vert_in),

	.x_arm(x_arm),
	.x_to_dac(x_to_dac),
	.x_from_dac(x_from_dac),
	.x_finished(x_finished),

	.y_arm(y_arm),
	.y_to_dac(y_to_dac),
	.y_from_dac(y_from_dac),
	.y_finished(y_finished),

	.adc_arm(adc_arm_internal),
	.adc_data(adc_data),
	.adc_finished(adc_finished),

	.adc_used_in(adc_used_in),

	.data(ram_data),
	.mem_commit(ram_commit),
	.mem_finished(ram_write_finished)
);

endmodule
