/* (c) Peter McGoron 2022 v0.1
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v.2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

module
`ifdef SPI_SLAVE_NO_READ
spi_slave_no_read
`elsif SPI_SLAVE_NO_WRITE
spi_slave_no_write
`else
spi_slave
`endif
#(
	parameter WID = 24, // Width of bits per transaction.
	parameter WID_LEN = 5, // Length in bits required to store WID
	parameter POLARITY = 0,
	parameter PHASE = 0 // 0 = rising-read falling-write, 1 = rising-write falling-read.
)
(
	input clk,
	input sck,
	input ss_L,
`ifndef SPI_SLAVE_NO_READ
	output reg [WID-1:0] from_master,
	input reg mosi,
`endif
`ifndef SPI_SLAVE_NO_WRITE
	input [WID-1:0] to_master,
	output reg miso,
`endif
	output reg finished,
	input rdy,
	output reg err
);

wire ss = !ss_L;
reg sck_delay = 0;
reg [WID_LEN-1:0] bit_counter = 0;
reg ss_delay = 0;
reg ready_at_start = 0;

`ifndef SPI_SLAVE_NO_WRITE
reg [WID-1:0] send_buf = 0;
`endif

task read_data();
`ifndef SPI_SLAVE_NO_READ
	from_master <= from_master << 1;
	from_master[0] <= mosi;
`endif
endtask

task write_data();
`ifndef SPI_SLAVE_NO_WRITE
	send_buf <= send_buf << 1;
	miso <= send_buf[WID-1];
`endif
endtask

task setup_bits();
`ifndef SPI_SLAVE_NO_WRITE
	/* at Mode 00, the transmission starts with
	 * a rising edge, and at mode 11, it starts with a falling
	 * edge. For both modes, these are READs.
	 *
	 * For mode 01 and mode 10, the first action is a WRITE.
	 */
	if (POLARITY == PHASE) begin
		miso <= to_master[WID-1];
		send_buf <= to_master << 1;
	end else begin
		send_buf <= to_master;
	end
`endif
endtask

task check_counter();
	if (bit_counter == WID) begin
		err <= ready_at_start;
	end else begin
		bit_counter <= bit_counter + 1;
	end
endtask

always @ (posedge clk) begin
	sck_delay <= sck;
	ss_delay <= ss;

	case ({ss_delay, ss})
	2'b01: begin // rising edge of SS
		bit_counter <= 0;
		finished <= 0;
		err <= 0;
		ready_at_start <= rdy;

		setup_bits();
	end
	2'b10: begin // falling edge
		finished <= ready_at_start;
	end
	2'b11: begin
		case ({sck_delay, sck})
		2'b01: begin // rising edge
			if (PHASE == 1) begin
				write_data();
			end else begin
				read_data();
			end

			if (POLARITY == 0) begin
				check_counter();
			end
		end
		2'b10: begin // falling edge
			if (PHASE == 1) begin
				read_data();
			end else begin
				write_data();
			end

			if (POLARITY == 1) begin
				check_counter();
			end
		end
		default: ;
		endcase
	end
	2'b00: if (!rdy) begin
		finished <= 0;
		err <= 0;
	end
	endcase
end

endmodule
