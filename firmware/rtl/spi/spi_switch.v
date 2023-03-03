/* This module is a co-operative crossbar for the wires only. Each end
 * implements its own SPI master.
 *
 * This crossbar is entirely controlled by the kernel.
 */
module spi_crossbar #(
	parameter PORTS = 8,
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

`define do_select(n)           \
	mosi = mosi_ports[n];  \
	miso = miso_ports[n];  \
	sck = sck_ports[n];    \
	ss = ss_ports[n]

`define check_select(n)        \
	if (select[n]) begin   \
		do_select(n);  \
	end

always @(*) begin
	check_select(7)
	else check_select(6)
	else check_select(5)
	else check_select(4)
	else check_select(3)
	else check_select(2)
	else check_select(1)
	else do_select(0)
end

endmodule
`undefineall
