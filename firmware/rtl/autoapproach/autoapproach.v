/* Autoapproach module. This module applies a waveform located in memory
 * (and copied into Block RAM). This waveform is arbitrary but of fixed
 * length.
 * time in between sent sample, total period 10-50ms
 */
module autoapproach #(
	parameter DAC_WID = 24,
	parameter DAC_DATA_WID = 20,
	parameter ADC_WID = 24,
	parameter TIMER_WID = 32,
	parameter WORD_WID = 24,
	parameter WORD_AMNT_WID = 11,
	parameter [WORD_AMNT_WID-1:0] WORD_AMNT = 2047,
	parameter RAM_WID = 32,
	parameter RAM_WORD_WID = 16,
	parameter RAM_WORD_INCR = 2
) (
	input clk,
	input arm,
	output stopped,
	output detected,

	input polarity,
	input [ADC_WID-1:0] setpoint,
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
	input dac_finished,
	output dac_arm,
	output [DAC_WID-1:0] dac_out,

	input adc_finished,
	output adc_arm,
	input [ADC_WID-1:0] measurement
);

bram_interface #(
	.WORD_WID(WORD_WID),
	.WORD_AMNT_WID(WORD_AMNT_WID),
	.WORD_AMNT(WORD_AMNT),
	.RAM_WID(RAM_WID),
	.RAM_WORD_WID(RAM_WORD_WID),
	.RAM_WORD_INCR(RAM_WORD_INCR)
) bram (
	.clk(clk),
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

localparam WAIT_ON_ARM = 0;
localparam DO_WAIT = 1;
localparam RECV_WORD = 2;
localparam WAIT_ON_DAC = 3;
localparam WAIT_ON_DETECTION = 4;
localparam DETECTED = 5;
reg [2:0] state = WAIT_ON_ARM;

reg [TIMER_WID-1:0] wait_timer = 0;

always @ (posedge clk) case (state)
WAIT_ON_ARM: if (arm) begin
	state <= DO_WAIT;
	stopped <= 0;
	wait_timer <= time_to_wait;
end else begin
	stopped <= 1;
	word_rst <= 1;
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
RECV_WORD: if (word_ok) begin
	dac_out <= {4'b0001, word};
	dac_arm <= 1;

	word_next <= 0;
	state <= WAIT_ON_DAC;
end
WAIT_ON_DAC: if (dac_finished) begin
	dac_arm <= 0;
	/* Was the last word read *the* last word? */
	if (word_last) begin
		state <= WAIT_ON_DETECTION;
		adc_arm <= 1;
	end else begin
		state <= WAIT_ON_ARM;
	end
endcase
WAIT_ON_DETECTION: if (adc_finished) begin
	if ((polarity && measurement >= setpt) ||
	    (!polarity && measurement <= setpt)) begin
		state <= DETECTED;
		detected <= 1;
	end
end
DETECTED: if (!arm) begin
	state <= WAIT_ON_ARM;
	detected <= 0;
end
endcase

endmodule
