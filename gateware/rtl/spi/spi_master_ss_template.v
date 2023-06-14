/* (c) Peter McGoron 2022 v0.3
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v.2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */
/* spi master with integrated ability to wait a certain amount of cycles
 * after activating SS.
 */

module `SPI_MASTER_SS_NAME
#(
	parameter WID = 24,
	parameter WID_LEN = 5,
	parameter CYCLE_HALF_WAIT = 1,
	parameter TIMER_LEN = 3,

	parameter SS_WAIT = 1,
	parameter SS_WAIT_TIMER_LEN = 2,

	parameter POLARITY = 0,
	parameter PHASE = 0
)
(
	input clk,
	input rst_L,
`ifndef SPI_MASTER_NO_READ
	output [WID-1:0] from_slave,
	input miso,
`endif
`ifndef SPI_MASTER_NO_WRITE
	input [WID-1:0] to_slave,
	output reg mosi,
`endif
	output sck_wire,
	output finished,
	output ready_to_arm,
	output ss_L,
	input arm
);

reg ss = 0;
reg arm_master = 0;
assign ss_L = !ss;

`SPI_MASTER_NAME #(
	.WID(WID),
	.WID_LEN(WID_LEN),
	.CYCLE_HALF_WAIT(CYCLE_HALF_WAIT),
	.TIMER_LEN(TIMER_LEN),
	.POLARITY(POLARITY),
	.PHASE(PHASE)
) master (
	.clk(clk),
	.rst_L(rst_L),
`ifndef SPI_MASTER_NO_READ
	.from_slave(from_slave),
	.miso(miso),
`endif
`ifndef SPI_MASTER_NO_WRITE
	.to_slave(to_slave),
	.mosi(mosi),
`endif
	.sck_wire(sck_wire),
	.finished(finished),
	.ready_to_arm(ready_to_arm),
	.arm(arm_master)
);

localparam WAIT_ON_ARM = 0;
localparam WAIT_ON_SS = 1;
localparam WAIT_ON_MASTER = 2;
localparam WAIT_ON_ARM_DEASSERT = 3;
reg [2:0] state = WAIT_ON_ARM;
reg [SS_WAIT_TIMER_LEN-1:0] timer = 0;

task master_arm();
	arm_master <= 1;
	state <= WAIT_ON_MASTER;
endtask

always @ (posedge clk) begin
	if (!rst_L) begin
		state <= WAIT_ON_ARM;
		timer <= 0;
		arm_master <= 0;
		ss <= 0;
	end else case (state)
	WAIT_ON_ARM: begin
		if (arm) begin
			timer <= 1;
			if (SS_WAIT == 0) begin
				master_arm();
			end else begin
				timer <= 1;
				state <= WAIT_ON_SS;
			end
			ss <= 1;
		end
	end
	WAIT_ON_SS: begin
		if (timer == SS_WAIT) begin
			master_arm();
		end else begin
			timer <= timer + 1;
		end
	end
	WAIT_ON_MASTER: begin
		if (finished) begin
			state <= WAIT_ON_ARM_DEASSERT;
			ss <= 0;
		end
	end
	WAIT_ON_ARM_DEASSERT: begin
		if (!arm) begin
			state <= WAIT_ON_ARM;
			arm_master <= 0;
		end
	end
	endcase
end

endmodule
`undefineall
