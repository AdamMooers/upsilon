/* (c) Peter McGoron 2022-2024 v0.4
 *
 * This code is disjunctively dual-licensed under the MPL v2.0, or the
 * CERN-OHL-W v2.
 */

/* CYCLE_HALF_WAIT should take into account the setup time of the slave
 * device, and also master buffering (MISO is one cycle off to stabilize
 * the input).
 */

module spi_master #(
	parameter ENABLE_MISO = 1, // Enable MISO and from_slave port
	parameter ENABLE_MOSI = 1, // Enable MOSI and to_slave port
	parameter WID = 24, // Width of bits per transaction.
	parameter WID_LEN = 5, // Length in bits required to store WID
	parameter CYCLE_HALF_WAIT = 1, // Half of the wait time of a cycle minus 1.
	                               // One SCK cycle is 2*(CYCLE_HALF_WAIT + 1) clock cycles.
	parameter TIMER_LEN = 3, // Length in bits required to store CYCLE_HALF_WAIT
	parameter POLARITY = 0, // 0 = sck idle low, 1 = sck idle high
	parameter PHASE = 0 // 0 = rising-read falling-write, 1 = rising-write falling-read.
) (
	input clk,
	input rst_L,

	output reg [WID-1:0] from_slave,
	input miso,

	input [WID-1:0] to_slave,
	output reg mosi,

	output reg sck_wire,
	output reg finished,
	output reg ready_to_arm,
	input arm
);

/* MISO is almost always an external wire, so buffer it.
 * This might not be necessary, since the master and slave do not respond
 * immediately to changes in the wires, but this is just to be safe.
 * It is trivial to change, just do
 *    wire read_miso = miso;
 */

reg miso_hot = 0;
reg read_miso = 0;

always @ (posedge clk) if (ENABLE_MISO == 1) begin
	read_miso <= miso_hot;
	miso_hot <= miso;
end

parameter WAIT_ON_ARM = 0;
parameter ON_CYCLE = 1;
parameter CYCLE_WAIT = 2;
parameter WAIT_FINISHED = 3;

reg [1:0] state = WAIT_ON_ARM;
reg [WID_LEN-1:0] bit_counter = 0;
reg [TIMER_LEN-1:0] timer = 0;

reg [WID-1:0] send_buf = 0;

reg sck = 0;
assign sck_wire = sck;

task idle_state();
	if (POLARITY == 0) begin
		sck <= 0;
	end else begin
		sck <= 1;
	end
	if (ENABLE_MOSI == 1) mosi <= 0;
	timer <= 0;
	bit_counter <= 0;
endtask

task read_data();
	if (ENABLE_MISO == 1) begin
		from_slave <= from_slave << 1;
		from_slave[0] <= read_miso;
	end
endtask

task write_data();
	if (ENABLE_MOSI == 1) begin
		mosi <= send_buf[WID-1];
		send_buf <= send_buf << 1;
	end
endtask

task setup_bits();
	/* at Mode 00, the transmission starts with
	 * a rising edge, and at mode 11, it starts with a falling
	 * edge. For both modes, these are READs.
	 *
	 * For mode 01 and mode 10, the first action is a WRITE.
	 */
	if (POLARITY == PHASE) begin
		if (ENABLE_MOSI == 1) begin
			mosi <= to_slave[WID-1];
			send_buf <= to_slave << 1;
		end
		state <= CYCLE_WAIT;
	end else begin
		if (ENABLE_MISO == 1) begin
			send_buf <= to_slave;
		end
		state <= ON_CYCLE;
	end
endtask

task cycle_change();
	// Stop transfer when the clock returns to its original polarity.
	if (bit_counter == WID[WID_LEN-1:0] && sck == POLARITY[0]) begin
		state <= WAIT_FINISHED;
	end else begin
		sck <= !sck;
		state <= ON_CYCLE;
	end
endtask

initial ready_to_arm = 1;

always @ (posedge clk) begin
	if (!rst_L) begin
		idle_state();
		finished <= 0;
		state <= WAIT_ON_ARM;
		ready_to_arm <= 1;
		if (ENABLE_MISO == 1) from_slave <= 0;
		if (ENABLE_MOSI == 1) send_buf <= 0;
	end else case (state)
	WAIT_ON_ARM: begin
`ifdef SIMULATION
		if (!ready_to_arm)
			$error("not ready to arm in wait_on_arm");
`endif
		if (!arm) begin
			idle_state();
			finished <= 0;
		end else begin
			setup_bits();
			ready_to_arm <= 0;
		end
	end
	ON_CYCLE: begin
`ifdef SIMULATION
		if (ready_to_arm)
			$error("ready_to_arm while on cycle");
`endif
		if (sck) begin // rising edge
			if (PHASE == 1) begin
				write_data();
			end else begin
				read_data();
			end

			if (POLARITY == 0) begin
				bit_counter <= bit_counter + 1;
			end
		end else begin // falling edge
			if (PHASE == 1) begin
				read_data();
			end else begin
				write_data();
			end

			if (POLARITY == 1) begin
				bit_counter <= bit_counter + 1;
			end
		end

		if (CYCLE_HALF_WAIT == 0) begin
			cycle_change();
		end else begin
			state <= CYCLE_WAIT;
		end
	end
	CYCLE_WAIT: begin
`ifdef SIMULATION
		if (ready_to_arm)
			$error("ready_to_arm while in cycle wait");
`endif
		if (timer == CYCLE_HALF_WAIT) begin
			timer <= 1;
			cycle_change();
		end else begin
			timer <= timer + 1;
		end
	end
	WAIT_FINISHED: begin
`ifdef SIMULATION
		if (ready_to_arm)
			$error("ready_to_arm while in wait finished");
`endif
		finished <= 1;
		idle_state();
		if (!arm) begin
			state <= WAIT_ON_ARM;
			ready_to_arm <= 1;
		end
	end
	endcase
end

endmodule
