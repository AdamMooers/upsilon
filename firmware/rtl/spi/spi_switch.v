/* This module is a co-operative crossbar for the wires only. Each end
 * implements its own SPI master.
 *
 * This crossbar is entirely controlled by the kernel.
 */
module spi_switch #(
	parameter PORTS = 3,
(
	input select[PORTS-1:0],

	output mosi,
	input miso,
	output sck,
	output ss_L,

	input  [PORTS-1:0] mosi_ports,
	output  [PORTS-1:0] miso_ports,
	input  [PORTS-1:0] sck_ports,
	input  [PORTS-1:0] ss_L_ports
);

/* Avoid using for loops, they might not synthesize correctly.
   Do things the old, dumb way instead.
 */

`define do_select(n)           \
	mosi = mosi_ports[n];  \
	miso = miso_ports[n];  \
	sck = sck_ports[n];    \
	ss_L = ss_L_ports[n]

`define check_select(n)        \
	if (select[n]) begin   \
		do_select(n);  \
	end

generate if (PORTS == 2) always @(*) begin
	check_select(2)
	else check_select(1)
	else do_select(0)
end else always @(*) begin
	check_select(1)
	else do_select(0)
end endgenerate

endmodule
`undefineall
