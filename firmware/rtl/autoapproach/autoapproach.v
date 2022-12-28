/* Autoapproach module. This module applies a waveform located in memory
 * (and copied into Block RAM). This waveform is arbitrary but of fixed
 * length.
 */
module autoapproach #(
	parameter DAC_WID = 24
) (
	input clk,
	input arm,
	output stopped,
	output detected,

	input polarity,
	input [`ADC_WID-1:0] setpoint,

	/* BRAM memory interface. Each pulse returns the next value in
	 * the sequence, and also informs the module if the sequence
	 * is completed. The kernel interacts primarily with this interface.
	 */
	input [`DAC_DATA_WID-1:0] word,
	output word_next,
	input  word_last,
	input  word_ok,
	output word_rst,

	/* DAC wires. */
	input dac_finished,
	output dac_arm,
	input [`DAC_WID-1:0] dac_in,
	output [`DAC_WID-1:0] dac_out,

	input adc_finished,
	output adc_arm,
	input [`ADC_WID-1:0] measurement
);


localparam WAIT_ON_ARM = 0;
localparam RECV_WORD = 1;
localparam WAIT_ON_DAC = 2;
localparam WAIT_ON_DETECTION = 3;
localparam DETECTED = 4;
reg [2:0] state = WAIT_ON_ARM;
reg save_word_last = 0;

always @ (posedge clk) case (state)
WAIT_ON_ARM: if (arm) begin
	state <= RECV_WORD;
	word_next <= 1;
	stopped <= 0;
end else begin
	stopped <= 1;
	word_rst <= 1;
end
RECV_WORD: if (word_ok) begin
	dac_out <= {4'b0001, word};
	dac_arm <= 1;
	save_word_last <= word_last;
	word_next <= 0;
	state <= WAIT_ON_DAC;
end
WAIT_ON_DAC: if (dac_finished) begin
	dac_arm <= 0;
	if (save_word_last) begin
		state <= WAIT_ON_DETECTION;
		adc_arm <= 0;
	end else begin
		state <= WAIT_ON_ARM;
	end
endcase
WAIT_ON_DETECTION: if (adc_finished) begin
	if (polarity && measurement >= setpt) begin
		state <= DETECTED;
		detected <= 1;
	end else if (measurement <= setpt) begin
		state <= WAIT_ON_ARM;
	end
end
DETECTED: if (!arm) begin
	state <= WAIT_ON_ARM;
	detected <= 0;
end
endcase

endmodule
