/* Write a waveform to a DAC. */
/* TODO: Add "how many values to go" counter. */
module waveform #(
	parameter DAC_WID = 24,
	parameter DAC_WID_SIZ = 5,
	parameter DAC_POLARITY = 0,
	parameter DAC_PHASE = 1,
	parameter DAC_CYCLE_HALF_WAIT = 10,
	parameter DAC_CYCLE_HALF_WAIT_SIZ = 4,
	parameter DAC_SS_WAIT = 5,
	parameter DAC_SS_WAIT_SIZ = 3,
	parameter TIMER_WID = 32,
	parameter WORD_WID = 20,
	parameter WORD_AMNT_WID = 11,
	parameter [WORD_AMNT_WID-1:0] WORD_AMNT = 2047,
	parameter RAM_WID = 32,
	parameter RAM_WORD_WID = 16,
	parameter RAM_WORD_INCR = 2
) (
	input clk,
	input rst_L,
	input arm,
	input halt_on_finish,
	/* NOTE:
	 * finished is used when a module wants to wait for a
	 * waveform with the halt_on_finish flag finishes
	 * one waveform.
	 *
	 * running is used when a module wants to know when
	 * the waveform module has finished running after
	 * deasserting arm.
	 *
	 * When in doubt, deassert arm and wait for running
	 * to be deasserted.
	 */
	output reg finished,
	output running,
	input [TIMER_WID-1:0] time_to_wait,

	/* User interface */
	input refresh_start,
	input [RAM_WID-1:0] start_addr,
	output reg refresh_finished,

	/* RAM interface */
	output reg [RAM_WID-1:0] ram_dma_addr,
	input [RAM_WORD_WID-1:0] ram_word,
	output reg ram_read,
	input ram_valid,

	/* DAC wires. */
	output mosi,
	output sck,
	output ss_L
);

wire [WORD_WID-1:0] word;
reg word_next = 0;
wire word_ok;
wire word_last;
reg word_rst = 1;

bram_interface #(
	.WORD_WID(WORD_WID),
	.WORD_AMNT_WID(WORD_AMNT_WID),
	.WORD_AMNT(WORD_AMNT),
	.RAM_WID(RAM_WID),
	.RAM_WORD_WID(RAM_WORD_WID),
	.RAM_WORD_INCR(RAM_WORD_INCR)
) bram (
	.clk(clk),
	.rst_L(rst_L),
	.word(word),
	.word_next(word_next),
	.word_last(word_last),
	.word_ok(word_ok),
	.word_rst(word_rst),

	.refresh_start(refresh_start),
	.start_addr(start_addr),
	.refresh_finished(refresh_finished),

	.ram_dma_addr(ram_dma_addr),
	.ram_word(ram_word),
	.ram_read(ram_read),
	.ram_valid(ram_valid)
);

wire dac_finished;
reg dac_arm = 0;
reg [DAC_WID-1:0] dac_out = 0;
wire dac_ready_to_arm_unused;

spi_master_ss_no_read #(
	.WID(DAC_WID),
	.WID_LEN(DAC_WID_SIZ),
	.CYCLE_HALF_WAIT(DAC_CYCLE_HALF_WAIT),
	.TIMER_LEN(DAC_CYCLE_HALF_WAIT_SIZ),
	.POLARITY(DAC_POLARITY),
	.PHASE(DAC_PHASE),
	.SS_WAIT(DAC_SS_WAIT),
	.SS_WAIT_TIMER_LEN(DAC_SS_WAIT_SIZ)
) dac_master (
	.clk(clk),
	.rst_L(rst_L),
	.ready_to_arm(dac_ready_to_arm_unused),
	.mosi(mosi),
	.sck_wire(sck),
	.ss_L(ss_L),
	.finished(dac_finished),
	.arm(dac_arm),
	.to_slave(dac_out)
);

localparam WAIT_ON_ARM = 0;
localparam DO_WAIT = 1;
localparam RECV_WORD = 2;
localparam WAIT_ON_DAC = 3;
localparam WAIT_ON_DISARM = 4;
reg [2:0] state = WAIT_ON_ARM;

reg [TIMER_WID-1:0] wait_timer = 0;

assign running = state != WAIT_ON_ARM;

always @ (posedge clk) if (!rst_L) begin
	state <= WAIT_ON_ARM;
	wait_timer <= 0;
	finished <= 0;
	word_rst <= 1;
	word_next <= 0;
	dac_out <= 0;
	dac_arm <= 0;
end else case (state)
WAIT_ON_ARM: begin
	finished <= 0;
	if (arm) begin
		state <= DO_WAIT;
		word_rst <= 0;
		wait_timer <= time_to_wait;
	end else begin
		word_rst <= 1;
	end
end
DO_WAIT: if (!arm) begin
	state <= WAIT_ON_ARM;
end else if (wait_timer == 0) begin
	word_next <= 1;
	state <= RECV_WORD;
	wait_timer <= time_to_wait;
end else begin
	wait_timer <= wait_timer - 1;
end
RECV_WORD: begin
`ifdef VERILATOR_SIMULATION
	if (!word_next) begin
		$error("RECV_WORD: word_next not asserted means hang");
	end
`endif

	if (word_ok) begin
		dac_out <= {4'b0001, word};
		dac_arm <= 1;

		word_next <= 0;
		state <= WAIT_ON_DAC;
	end
end
WAIT_ON_DAC: begin
`ifdef VERILATOR_SIMULATION
	if (!dac_arm) begin
		$error("WAIT_ON_DAC: dac_arm not asserted means hang");
	end
`endif

	if (dac_finished) begin
		dac_arm <= 0;
		/* Was the last word read *the* last word? */
		if (word_last && halt_on_finish) begin
			state <= WAIT_ON_DISARM;
			finished <= 1;
		end else begin
			state <= DO_WAIT;
			wait_timer <= time_to_wait;
		end
	end
end
WAIT_ON_DISARM: if (!arm) begin
	state <= WAIT_ON_ARM;
end
endcase

/* Warning! This will crash verilator with a segmentation fault!
`ifdef VERILATOR
initial begin
	$dumpfile("waveform.fst");
	$dumpvars();
end
`endif
*/

endmodule
`undefineall
