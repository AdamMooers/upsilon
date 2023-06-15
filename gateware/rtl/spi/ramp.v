/* Copyright 2023 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
/* Dynamically adjustable DAC ramping.
 * Given an increment voltage and a speed setting, increase the voltage
 * to that voltage in increments over a period of time.
 * This might not be neccessary for now but I wrote it for possible future
 * use.
 */
module ramp #(
	parameter DAC_DATA_WID = 20,
	parameter DAC_WID = 24,
	parameter WAIT_WID = 8,
	parameter [WAIT_WID-1:0] READ_WAIT = 10
) (
	input clk,
	input arm,
	input read_setting,
	output reg finished,
	output reg ready,

	input [DAC_WID-1:0] mosi,
	output [DAC_WID-1:0] miso,
	output reg arm_transfer,
	input finished_transfer

	input signed [DAC_DATA_WID-1:0] move_to,
	input signed [DAC_DATA_WID-1:0] stepsiz,
	input signed [DAC_DATA_WID-1:0] wait_time,
	output reg signed [DAC_DATA_WID-1:0] setting
);

localparam WAIT_ON_ARM = 0;
localparam WAIT_ON_READ_PART_1 = 1;
localparam WAIT_ON_READ_PART_2 = 2;
localparam WAIT_ON_WRITE = 3;
localparam WAIT_ON_TRANSFER = 4;
localparam WAIT_ON_DISARM = 5;
localparam WAIT_ON_READ_DISARM = 6;

reg [3-1:0] state = WAIT_ON_ARM;
reg [WAIT_WID-1:0] timer = 0;

localparam SIGN_POS = 0;
localparam SIGN_NEG = 1;
reg step_sign = 0;
reg last_transfer = 0;

`define DAC_CMD_WID (DAC_WID - DAC_DATA_WID)
localparam [`DAC_CMD_WID-1:0] read_reg = 4'b1001;
localparam [`DAC_CMD_WID-1:0] write_reg = 4'b0001;

task start_transfer();
	case (step_sign)
	SIGN_POS: if (setting + stepsiz >= move_to) begin
			mosi[DAC_DATA_WID-1:0] <= setting;
			last_transfer <= 1;
		end else begin
			mosi[DAC_DATA_WID-1:0] <= setting + stepsiz;
		end
	SIGN_NEG: if (setting - stepsiz <= move_to) begin
			mosi[DAC_DATA_WID-1:0] <= setting;
			last_transfer <= 1;
		end else begin
			mosi[DAC_DATA_WID-1:0] <= setting - stepsiz;
		end
	endcase
	arm_transfer <= 1;
endtask

always @ (posedge clk) begin
	case (state)
	WAIT_ON_ARM: if (read_setting) begin
		mosi <= {read_reg, {(DAC_DATA_WID){1'b0}}};
		arm_transfer <= 1;
		state <= WAIT_ON_READ;
		ready <= 0;
	end else if (arm) begin
		ready <= 0;
		last_transfer <= 0;

		if (realstep != 0) begin
			state <= WAIT_ON_WRITE;
		end

		mosi[DAC_WID-1:DAC_DATA_WID] <= write_reg;
		/* 0 for positve, 1 for negative */
		step_sign <= move_to > setting;
		timer <= wait_time;
	end else begin
		ready <= 1;
	end

	/* Why put the wait here? If ramping is necessary then any abrupt
	 * changes in voltages can be disastrous. After each write the
	 * design always waits, even if ramping is stopped or done, so
	 * the next ramp always executes when a safe time has elapsed.
	 */
	WAIT_ON_WRITE: if (timer < wait_time) begin
		timer <= timer + 1;
	end else if (!arm || last_transfer) begin
		state <= WAIT_ON_DISARM;
		finished <= 1;
	end else if (arm) begin
		start_transfer();
		state <= WAIT_ON_TRANSFER;
	end

	WAIT_ON_TRANSFER: if (finished_transfer) begin
		setting <= mosi[DAC_DATA_WID-1:0];
		timer <= 0;
		state <= WAIT_ON_WRITE;
		finished <= 1;
	end

	WAIT_ON_DISARM: if (!arm) begin
		state <= WAIT_ON_ARM;
		finished <= 0;
	end

	WAIT_ON_READ_PART_1: if (finished_transfer) begin
		state <= WAIT_ON_READ_PART_2;
		arm_transfer <= 0;
		mosi <= 0;
		timer <= 0;
	end

	WAIT_ON_READ_PART_2: if (timer < read_wait) begin
		read_wait <= read_wait + 1;
	end else if (!arm_transfer) begin
		arm_transfer <= 1;
	end else if (finished_transfer) begin
		state <= WAIT_ON_READ_DISARM;
		finished <= 1;
		arm_transfer <= 0;
		setting <= miso[DAC_DATA_WID-1:0];
	end

	WAIT_ON_READ_DISARM: if (!read_setting) begin
		state <= WAIT_ON_ARM;
		finished <= 0;
	end
	endcase
end

endmodule
