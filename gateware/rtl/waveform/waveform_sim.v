/* Copyright 2024 (C) Peter McGoron
 *
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */

module waveform_sim #(
	parameter RAM_START_ADDR = 32'h0,
	parameter SPI_START_ADDR = 32'h10000000,
	parameter COUNTER_MAX_WID = 16,
	parameter TIMER_WID = 16
) (
	input clk,

	/* Waveform output control */
	input run,
	input force_stop,
	output [COUNTER_MAX_WID-1:0] cntr,
	input do_loop,
	output finished,
	output ready,
	input [COUNTER_MAX_WID-1:0] wform_size,
	output [TIMER_WID-1:0] timer,
	input [TIMER_WID-1:0] timer_spacing,

	/* data requests to Verilator */

	output reg [32-1:0] offset,
	output reg [32-1:0] spi_data,
	input [32-1:0] ram_data,
	output reg [1:0] enable,
	input ram_finished,

	/* Misc */
	input [32-1:0] spi_max_wait
);

wire [32-1:0] wb_adr;
wire wb_cyc;
wire wb_we;
wire wb_stb;
wire [32-1:0] wb_dat_w;
reg [32-1:0] wb_dat_r;
wire [4-1:0] wb_sel;
reg wb_ack = 0;

waveform #(
	.RAM_START_ADDR(RAM_START_ADDR),
	.SPI_START_ADDR(SPI_START_ADDR),
	.COUNTER_MAX_WID(COUNTER_MAX_WID),
	.TIMER_WID(TIMER_WID)
) wf (
	.clk(clk),
	.run(run),
	.force_stop(force_stop),
	.cntr(cntr),
	.do_loop(do_loop),
	.finished(finished),
	.ready(ready),
	.wform_size(wform_size),
	.timer(timer),
	.timer_spacing(timer_spacing),
	.wb_adr(wb_adr),
	.wb_cyc(wb_cyc),
	.wb_we(wb_we),
	.wb_stb(wb_stb),
	.wb_dat_w(wb_dat_w),
	.wb_dat_r(wb_dat_r),
	.wb_ack(wb_ack),
	.wb_sel(wb_sel)
);

reg [32-1:0] spi_cntr = 0;
reg spi_armed = 0;
reg spi_running = 0;
reg spi_ready_to_arm = 1;
reg spi_finished = 0;

/* SPI Delay simulation */

always @ (posedge clk) if ((spi_armed || spi_running) && !spi_finished) begin
	spi_running <= 1;
	spi_ready_to_arm <= 0;
	if (spi_cntr == spi_max_wait) begin
		spi_cntr <= 0;
		spi_finished <= 1;
	end else begin
		spi_cntr <= spi_cntr + 1;
	end
end else if (spi_finished) begin
	spi_running <= 0;
	if (!spi_armed) begin
		spi_finished <= 0;
		spi_ready_to_arm <= 1;
	end
end

/* Bus handlers */

always @* if (wb_we && wb_sel != 4'b1111)
	$error("Write request without writing entire word");

always @ (posedge clk) if (wb_cyc & wb_stb & ~wb_ack) begin
	if (wb_adr >= SPI_START_ADDR) case (wb_adr)
	SPI_START_ADDR | 32'h4: if (wb_we) begin
		spi_armed <= wb_dat_w[0];
		wb_ack <= 1;
	end else begin
		wb_dat_r[0] <= spi_armed;
		wb_ack <= 1;
	end
	SPI_START_ADDR | 32'hC: begin
		if (!wb_we) $error("Waveform should never read the to_slave register");

		/* Write SPI Data to verilator immediately, but have a counter
		 * running in the background to simulate SPI transfer */
		spi_data <= wb_dat_w;
		enable <= 2'b10;
		if (ram_finished) begin
			enable <= 0;
			wb_ack <= 1;
		end
	end
	SPI_START_ADDR | 32'h10: begin
		if (wb_we) $error("Blocking SPI status check is read only register");
		if (spi_ready_to_arm  || spi_finished) begin
			wb_dat_r[0] <= spi_ready_to_arm;
			wb_dat_r[1] <= spi_finished;
			wb_ack <= 1;
		end
	end
	default: begin
		$error("Invalid SPI address");
	end
	endcase else begin
		offset <= wb_adr;
		enable <= 2'b01;
		if (ram_finished) begin
			wb_dat_r <= ram_data;
			enable <= 0;
			wb_ack <= 1;
		end
	end
end else if (~wb_cyc) begin
	wb_ack <= 0;
end

initial begin
	$dumpfile("waveform.fst");
	$dumpvars;
end

endmodule
