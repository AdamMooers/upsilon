/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2020 Florent Kermarrec <florent@enjoy-digital.fr>
 * Copyright (c) 2020 Dolu1990 <charles.papon.90@gmail.com>
 *
 */

#include <stdint.h>

#define UART_EV_TX	0x1
#define UART_EV_RX	0x2

#define MMPTR(a) (*((volatile uint32_t *)(a)))

static inline void csr_write_simple(unsigned long v, unsigned long a)
{
	MMPTR(a) = v;
}

static inline unsigned long csr_read_simple(unsigned long a)
{
	return MMPTR(a);
}

#define CSR_BASE 0xf0000000L

static inline uint8_t uart_rxtx_read(void) {
	return csr_read_simple(CSR_BASE + 0x1000L);
}
static inline void uart_rxtx_write(uint8_t v) {
	csr_write_simple(v, CSR_BASE + 0x1000L);
}

static inline uint8_t uart_txfull_read(void) {
	return csr_read_simple(CSR_BASE + 0x1004L);
}

static inline uint8_t uart_rxempty_read(void) {
	return csr_read_simple(CSR_BASE + 0x1008L);
}

static inline void uart_ev_pending_write(uint8_t v) {
	csr_write_simple(v, CSR_BASE + 0x1010L);
}

static inline uint8_t uart_txempty_read(void) {
	return csr_read_simple(CSR_BASE + 0x1018L);
}
static inline uint8_t uart_rxfull_read(void) {
	return csr_read_simple(CSR_BASE + 0x101cL);
}


void vex_putc(char c){
	while (uart_txfull_read());
	uart_rxtx_write(c);
	uart_ev_pending_write(UART_EV_TX);
}

int vex_getc(void){
	char c;
	if (uart_rxempty_read()) return -1;
	c = uart_rxtx_read();
	uart_ev_pending_write(UART_EV_RX);
	return c;
}
