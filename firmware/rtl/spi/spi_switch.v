/* This module is a co-operative crossbar for the wires only. Each end
 * implements its own SPI master.
 *
 * This crossbar is entirely controlled by the kernel.
 */
module spi_crossbar #(
	parameter PORTS = 2,
(
	input select[PORTS-1:0],

	output mosi,
	input miso,
	output sck,
	output ss,

	input mosi_ports[PORTS-1:0],
	output miso_ports[PORTS-1:0],
	input sck_ports[PORTS-1:0],
	input ss_ports[PORTS-1:0]
);

/* Avoid using for loops, they might not synthesize correctly.
   Do things the old, dumb way instead.
 */

always @(*) begin
	if (select[1]) begin
		mosi = mosi_ports[1];
		miso = miso_ports[1];
		sck = sck_ports[1];
		ss = ss_ports[1];
	end else begin
		/* Select zeroth slot by default. No latches. */
		mosi = mosi_ports[0];
		miso = miso_ports[0];
		sck = sck_ports[0];
		ss = ss_ports[0];
	end
end

endmodule
