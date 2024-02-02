/* (c) Peter McGoron 2022 v0.4
 *
 * This code is disjunctively dual-licensed under the MPL v2.0, or the
 * CERN-OHL-W v2.
 */

module spi_master_ss_wb
#(
	parameter BUS_WID = 32, /* Width of a request on the bus. */

	parameter SS_WAIT = 1,
	parameter SS_WAIT_TIMER_LEN = 2,

	parameter ENABLE_MISO = 1,
	parameter ENABLE_MOSI = 1,
	parameter WID = 24,
	parameter WID_LEN = 5,
	parameter CYCLE_HALF_WAIT = 1,
	parameter TIMER_LEN = 3,

	parameter POLARITY = 0,
	parameter PHASE = 0
) (
	input clk,
	input rst_L,

	input miso,
	output mosi,
	output sck_wire,
	output ss_L

	input wb_cyc,
	input wb_stb,
	input wb_we,
	input [(BUS_WID)/4-1:0] wb_sel,
	input [BUS_WID-1:0] wb_addr,
	input [BUS_WID-1:0] wb_dat_w,
	output reg wb_ack,
	output reg [BUS_WID-1:0] wb_dat_r,
);

/* Address map:

   All words are little endian. Access must be word-aligned and word-level
   or undefined behavior will occur.

   word 0: ready_to_arm | (finished << 1) (RW)
   word 1: arm (RO)
   word 2: from_slave (RO)
   word 3: to_slave (RW)
*/

wire [WID-1:0] from_slave;
reg [WID-1:0] to_slave;
wire finished;
wire ready_to_arm;
reg arm;

spi_master_ss #(
	.SS_WAIT(SS_WAIT),
	.SS_WAIT_TIMER_LEN(SS_WAIT_TIMER_LEN),

	.ENABLE_MISO(ENABLE_MISO),
	.ENABLE_MOSI(ENABLE_MOSI),
	.WID(WID),
	.WID_LEN(WID_LEN),
	.CYCLE_HALF_WAIT(CYCLE_HALF_WAIT),
	.TIMER_LEN(TIMER_LEN),

	.POLARITY(POLARITY),
	.PHASE(PHASE)
) spi (
	.clk(clk),
	.rst_L(rst_L),

	.from_slave(from_slave),
	.miso(miso),

	.to_slave(to_slave),
	.mosi(mosi),

	.sck_wire(sck_wire),
	.finished(finished),
	.ready_to_arm(ready_to_arm),
	.ss_L(ss_L),
	.arm(arm)
);

always @ (posedge clk) if (wb_cyc && wb_stb && !wb_ack) begin
	if (!wb_we) case (wb_addr[4-1:0])
	4'h0: wb_dat_r <= {30'b0, finished, ready_to_arm};
	4'h4: wb_dat_r <= {31'b0, arm};
	4'h8: wb_dat_r <= from_slave;
	4'hC: wb_dat_r <= to_slave;
	default: wb_dat_r <= 0;
	endcase else case (wb_addr[4-1:0])
	4'h4: arm <= wb_dat_w[0];
	4'hC: to_slave <= wb_dat_w;
	default: ;
	end
	wb_ack <= 1;
end else begin
	wb_ack <= 0;
end

endmodule
