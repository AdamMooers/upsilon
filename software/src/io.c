#include <zephyr/zephyr.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(adc_dac_io);

#include <string.h>
#define CSR_LOCATIONS
#include "pin_io.h"

static int32_t
sign_extend(uint32_t n, unsigned wid)
{
	if (n >> (wid - 1))
		return (int32_t) (~((uint32_t) 0) & n);
	else
		return (int32_t) n;
}

int32_t
adc_read(size_t num, unsigned wid)
{
	if (num >= ADC_MAX) {
		LOG_ERR("adc_read got bad ADC %zd\n", num);
		k_fatal_halt(K_ERR_KERNEL_OOPS);
	}
	if (wid > 32) {
		LOG_ERR("adc_read got bad width %u\n", wid);
		k_fatal_halt(K_ERR_KERNEL_OOPS);
	}

	*adc_conv[num] = 1;
	k_sleep(K_NSEC(550));
	*adc_arm[num] = 1;
	*adc_conv[num] = 0;
	// XXX: Guess
	k_sleep(K_MSEC(40));
	while (!*adc_finished[num]);

	uint32_t buf = *adc_from_slave[num];
	*adc_arm[num] = 0;
	return sign_extend(buf);
}

uint32_t
dac_write_raw(size_t n, uint32_t data)
{
	if (n >= DAC_MAX) {
		LOG_ERR("dac_write_raw got bad ADC %d\n", n);
		k_fatal_halt(K_ERR_KERNEL_OOPS);
	}

	*dac_to_slave[n] = data;
	*dac_ss[n] = 1;
	k_sleep(K_NSEC(20));
	*dac_arm[n] = 1;
	// XXX: Guess
	k_sleep(K_MSEC(50));
	while (!*dac_finished[num]);

	*dac_ss[n] = 0;
	uint32_t r = *dac_from_slave[n];
	*dac_arm[n] = 0;
	return r;
}

void
dac_write_v(size_t n, uint32_t v)
{
	dac_write_raw(n, (1 << 20) | (v & 0xFFFFF));
}

int
dac_init(size_t n)
{
	/* Write to control register. */
	const uint32_t msg =
		(1 << 1) // RBUF
		| (1 << 4) // Binary Offset
	;
	dac_write_raw(n, (1 << 21) | msg);
	// Read from the control register
	dac_write_raw(n, (1 << 21) | (1 << 23));
	// Send NOP to read the returned data.
	return dac_write_raw(n, 0) == msg;
}
