/* Copyright 2024 (C) Peter McGoron
 *
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */

module waveform #(
	parameter RAM_START_ADDR = 32'h0,
	parameter SPI_START_ADDR = 32'h10000000,
	parameter COUNTER_MAX_WID = 16,
	parameter TIMER_WID = 16
) (
	input clk,

	/* Waveform output control */
	input run,
	input force_stop,
	output reg[COUNTER_MAX_WID-1:0] cntr,
	input do_loop,
	output reg finished,
	output reg ready,
	input [COUNTER_MAX_WID-1:0] wform_size,
	output reg [TIMER_WID-1:0] timer,
	input [TIMER_WID-1:0] timer_spacing,

	/* Bus master */
	output reg [32-1:0] wb_adr,
	output reg wb_cyc,
	output reg wb_we,
	output wb_stb,
	output [4-1:0] wb_sel,
	output reg [32-1:0] wb_dat_w,
	input [32-1:0] wb_dat_r,
	input wb_ack
);

/* When a Wishbone cycle starts, the output is stable. */
assign wb_stb = wb_cyc;

/* Always write 32 bits */
assign wb_sel = 4'b1111;

localparam CHECK_START = 0;
localparam CHECK_LEN = 1;
localparam WAIT_FINISHED = 2;
localparam READ_RAM = 3;
localparam WAIT_RAM = 4;
localparam WRITE_DAC_DATA_ADR = 5;
localparam WAIT_DAC_DATA_ADR = 6;
localparam WRITE_DAC_ARM_ADR = 7;
localparam WAIT_DAC_ARM_ADR = 8;
localparam WRITE_DAC_DISARM_ADR = 9;
localparam WAIT_DAC_DISARM_ADR = 10;
localparam READ_DAC_FIN_ADR = 11;
localparam WAIT_DAC_FIN_ADR = 12;
localparam WAIT_PERIOD = 13;

reg [4-1:0] state = CHECK_START;

always @ (posedge clk) if (force_stop) begin
	state <= CHECK_START;
end else case (state)
CHECK_START: if (run) begin
		cntr <= 0;
		ready <= 0;
		state <= CHECK_LEN;
	end else begin
		ready <= 1;
		finished <= 0;
	end
CHECK_LEN: if (cntr >= wform_size) begin
		if (do_loop) begin
			cntr <= 0;
			state <= READ_RAM;
		end else begin
			state <= WAIT_FINISHED;
		end
	end else begin
		state <= READ_RAM;
	end
WAIT_FINISHED: if (!run) begin
		state <= CHECK_START;
	end else if (do_loop) begin
		state <= READ_RAM;
		cntr <= 0;
	end else begin
		finished <= 1;
	end
READ_RAM: begin
	/* The address is byte indexed so we shift left to make it word-aligned */
	wb_adr <= RAM_START_ADDR + {16'b0, cntr << 2};
	wb_cyc <= 1; /* Always assigned STB when CYC is */
	wb_we <= 0;
	state <= WAIT_RAM;
end
WAIT_RAM: if (wb_ack) begin
	wb_cyc <= 0;
	wb_dat_w <= 1 << 20 | wb_dat_r;
	state <= WRITE_DAC_DATA_ADR;
end
WRITE_DAC_DATA_ADR: begin
	wb_adr <= SPI_START_ADDR + 32'hC;
	wb_cyc <= 1;
	wb_we <= 1;
	state <= WAIT_DAC_DATA_ADR;
end
WAIT_DAC_DATA_ADR: if (wb_ack) begin
	wb_cyc <= 0;
	/* This is not needed, since the next bus cycle is also a write. */
	/* wb_we <= 0; */
	state <= WRITE_DAC_ARM_ADR;
end
WRITE_DAC_ARM_ADR: begin
	wb_adr <= SPI_START_ADDR + 32'h4;
	wb_dat_w[0] <= 1;
	wb_cyc <= 1;
	/* wb_we <= 1; */
	state <= WAIT_DAC_ARM_ADR;
end
WAIT_DAC_ARM_ADR: if (wb_ack) begin
	wb_cyc <= 0;
	/* This is not needed, since the next bus cycle is also a write. */
	/* wb_we <= 0; */
	state <= WRITE_DAC_DISARM_ADR;
end
/*
 * After arming the SPI core, immediately disarm it.
 * The SPI core will continue to execute after being disarmed until
 * it completes a transmission cycle. Otherwise the core would spend
 * two extra clock cycles if it disarmed after checking that the SPI
 * master was done.
 */
WRITE_DAC_DISARM_ADR: begin
	wb_adr <= SPI_START_ADDR + 32'h4;
	wb_dat_w[0] <= 0;
	wb_cyc <= 1;
	/* This is not needed, since the previous bus cycle is also a write. */
	/* wb_we <= 1; */
	state <= WAIT_DAC_DISARM_ADR;
end
WAIT_DAC_DISARM_ADR: if (wb_ack) begin
	wb_cyc <= 0;
	/* Disable writes because next bus cycle is a write */
	wb_we <= 0;
	state <= READ_DAC_FIN_ADR;
end
/*
 * This core reads from "wait_ready_or_finished", which will
 * stall until the SPI core is ready to arm or finished with
 * it's transmission.
 * If the SPI device is disconnected it will just return 0 at all
 * times (see PreemptiveInterface). To avoid getting the core stuck
 * the FSM will continue without checking that the DAC is actually
 * ready or finished.
 */
READ_DAC_FIN_ADR: begin
	wb_adr <= SPI_START_ADDR + 32'h10;
	wb_cyc <= 1;
	state <= WAIT_DAC_FIN_ADR;
end
WAIT_DAC_FIN_ADR: if (wb_cyc) begin
	wb_cyc <= 0;
	state <= WAIT_PERIOD;
	timer <= 0;
end
/* If the core tells the block to stop running, stop when SPI is not
 * transmitting to the DAC.
 *
 * If you want the module to run until the end of the waveform, turn
 * off looping and wait until the waveform ends. If you want the module
 * to stop the waveform and keep the DAC in a known state, just turn
 * the running flag off. If you need to stop it immediately, flip the
 * master switch for the DAC to the main CPU.
 */
WAIT_PERIOD: if (!run) begin
	state <= CHECK_START;
end else if (timer < timer_spacing) begin
	timer <= timer + 1;
end else begin
	cntr <= cntr + 1;
	state <= CHECK_LEN;
end
default: state <= CHECK_START;
endcase
endmodule
