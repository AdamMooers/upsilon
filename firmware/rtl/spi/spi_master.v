/* (c) Peter McGoron 2022
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v.2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

module
`ifdef SPI_MASTER_NO_READ
spi_master_no_read
`else
`ifdef SPI_MASTER_NO_WRITE
spi_master_no_write
`else
spi_master
`endif
`endif

#(
	parameter WID = 24, // Width of bits per transaction.
	parameter WID_LEN = 5, // Length in bits required to store WID
	parameter CYCLE_HALF_WAIT = 1, // Half of the wait time of a cycle
	parameter TIMER_LEN = 3, // Length in bits required to store CYCLE_HALF_WAIT
	parameter POLARITY = 0, // 0 = sck idle low, 1 = sck idle high
	parameter PHASE = 0 // 0 = rising-read falling-write, 1 = rising-write falling-read.
)
(
	input clk,
`ifndef SPI_MASTER_NO_READ
	output reg [WID-1:0] from_slave,
	input miso,
`endif
`ifndef SPI_MASTER_NO_WRITE
	input [WID-1:0] to_slave,
	output mosi,
`endif
	output sck_wire,
	output finished,
	input arm
);

parameter WAIT_ON_ARM = 0;
parameter ON_CYCLE = 1;
parameter CYCLE_WAIT = 2;
parameter WAIT_FINISHED = 3;

reg [1:0] state = WAIT_ON_ARM;
reg [WID_LEN-1:0] bit_counter = 0;
reg [TIMER_LEN-1:0] timer = 0;

`ifndef SPI_MASTER_NO_WRITE
reg [WID-1:0] send_buf = 0;
`endif

reg sck = 0;
assign sck_wire = sck;

task idle_state();
	if (POLARITY == 0) begin
		sck <= 0;
	end else begin
		sck <= 1;
	end
`ifndef SPI_MASTER_NO_WRITE
	mosi <= 0;
`endif
	timer <= 0;
	bit_counter <= 0;
endtask

task read_data();
`ifndef SPI_MASTER_NO_READ
	from_slave <= from_slave << 1;
	from_slave[0] <= miso;
`endif
endtask

task write_data();
`ifndef SPI_MASTER_NO_WRITE
	mosi <= send_buf[WID-1];
	send_buf <= send_buf << 1;
`endif
endtask

task setup_bits();
	/* at Mode 00, the transmission starts with
	 * a rising edge, and at mode 11, it starts with a falling
	 * edge. For both modes, these are READs.
	 *
	 * For mode 01 and mode 10, the first action is a WRITE.
	 */
	if (POLARITY == PHASE) begin
`ifndef SPI_MASTER_NO_WRITE
		mosi <= to_slave[WID-1];
		send_buf <= to_slave << 1;
`endif
		state <= CYCLE_WAIT;
	end else begin
`ifndef SPI_MASTER_NO_WRITE
		send_buf <= to_slave;
`endif
		state <= ON_CYCLE;
	end
endtask

always @ (posedge clk) begin
	case (state)
	WAIT_ON_ARM: begin
		if (!arm) begin
			idle_state();
			finished <= 0;
		end else begin
			setup_bits();
		end
	end
	ON_CYCLE: begin
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
		state <= CYCLE_WAIT;
	end
	CYCLE_WAIT: begin
		if (timer == CYCLE_HALF_WAIT) begin
			timer <= 0;
			// Stop transfer when the clock returns
			// to its original polarity.
			if (bit_counter == WID && sck == POLARITY) begin
				state <= WAIT_FINISHED;
			end else begin
				state <= ON_CYCLE;
				sck <= !sck;
			end
		end else begin
			timer <= timer + 1;
		end
	end
	WAIT_FINISHED: begin
		finished <= 1;
		idle_state();
		if (!arm) begin
			state <= WAIT_ON_ARM;
		end
	end
	endcase
end

endmodule