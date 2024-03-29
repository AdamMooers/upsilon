/* Copyright 2023 (C) Peter McGoron
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */
/* This module is a co-operative crossbar for the wires only. Each end
 * implements its own SPI master.
 *
 * This crossbar is entirely controlled by the kernel.
 */
module spi_switch #(
	parameter PORTS = 3
) (
	/* verilator lint_off UNUSEDSIGNAL */
	input [PORTS-1:0] select,
	/* verilator lint_on UNUSEDSIGNAL */

	output reg mosi,
	input miso,
	output reg sck,
	output reg ss_L,

	input  [PORTS-1:0] mosi_ports,
	output reg [PORTS-1:0] miso_ports,
	input  [PORTS-1:0] sck_ports,
	input  [PORTS-1:0] ss_L_ports
);

/* Avoid using for loops, they might not synthesize correctly.
 * Do things the old, dumb way instead.
 *
 * TODO: Instead of bit vector, use regular numbers
 */

`define do_select(n)            \
	mosi = mosi_ports[n];   \
	miso_ports = {{(PORTS-1){1'b0}},miso} << n; \
	sck = sck_ports[n];     \
	ss_L = ss_L_ports[n]

`define check_select(n)        \
	if (select[n]) begin   \
		`do_select(n); \
	end

generate if (PORTS == 3) always @(*) begin
	`check_select(2)
	else `check_select(1)
	else begin
		`do_select(0);
	end
end else always @(*) begin
	`check_select(1)
	else begin
		`do_select(0);
	end
end endgenerate

endmodule
`undefineall
