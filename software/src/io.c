#include <zephyr/zephyr.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(adc_dac_io);

#include <string.h>
#define CSR_LOCATIONS
#include "pin_io.h"

int32_t
adc_read(size_t num, unsigned wid)
{
	uint32_t buf = 0;

	if (num >= ADC_MAX) {
		LOG_ERR("Bad ADC %d\n", num);
		k_fatal_halt(K_ERR_KERNEL_OOPS);
	}
	if (wid > 32) {
		LOG_ERR("Bad ADC Width %u\n", wid);
		k_fatal_halt(K_ERR_KERNEL_OOPS);
	}

	/* SCK is set low because data is changed at the rising edge. */
	*adc_sck[num] = 0;
	*adc_conv[num] = 1;

	/* Wait setup time.
	 * The ADC sends an interrupt signal to notify the master that
	 * the ADC is ready to read out the data, but the evaluation boards
	 * do not expose that signal. This code relies on the maximum times
	 * listed in the datasheets.
	 *
	 * The ADCs have different maximum conversion times, so the longest
	 * one (LTC2328) is used. This number also includes t_BUSYLH.
	 */
	k_sleep(K_NSEC(550));
	*adc_conv[num] = 0;

	for (int i = 0; i < wid; i++) {
		k_sleep(K_NSEC(20));
		buf <<= 1;
		buf |= *adc_sdo[num];

		*adc_sck[num] = 1;
		k_sleep(K_NSEC(20));
		*adc_sck[num] = 0;
	}

	/* Sign extension.
	 * LT ADCs return twos-complement integers. They can be either positive
	 * or negative, and this is determined by the MSB (MSB = 1 means
	 * negative number).
	 *
	 * The ADCs do not send 32 bit integers, so the integers that are
	 * received must be sign extended.
	 *
	 * If a number is positive, no conversion is necessary.
	 *
	 * If a number is negative, then all bits beyond the original MSB
	 * must be set to 1. This can be done by ANDing the received number
	 * with all-bits-1.
	 *
	 * As an example, the negative 6-bit number
	 *   101101
	 * can be sign extended to 8-bit by
	 *     11111111
	 *   & 00101101
	 *   ==========
	 *     11101101
	 *      (101101)
	 */
	if (buf >> wid)
		return (int32_t) (~((uint32_t) 0) & buf);
	else
		return (int32_t) buf;
}

#define DAC_SS(n, v) *dac_ctrl[(n)] |= (v & 1) << 2
#define DAC_SCK(n, v) *dac_ctrl[(n)] |= (v & 1) << 1
#define DAC_MOSI(n, v) *dac_ctrl[(n)] |= (v & 1)
#define DAC_MISO(n) *dac_miso[(n)]

/* Thankfully we only have one type of DAC (for now).
 * AD DACs are register-based devices. To write to a register,
 * 1) Set SCK high.
 * 2) Set SS high in software (SYNC is active-low), wait setup time.
 * 3) Set SCK low.
 * 4) Read MISO, write MOSI.
 * 5) Set SCK high, wait setup time.
*/
uint32_t
dac_write_raw(size_t n, uint32_t data)
{
	uint32_t r = 0;
	DAC_SCK(n, 1);
	DAC_SS(n, 1);
	k_sleep(K_NSEC(10));

	if (n >= DAC_MAX) {
		LOG_ERR("dac_write_raw got bad ADC %d\n", n);
		k_fatal_halt(K_ERR_KERNEL_OOPS);
	}

	for (int i = 0; i < 24; i++) {
		DAC_SCK(n, 0);
		DAC_MOSI(n, data >> 31 & 1);
		k_sleep(K_NSEC(500));

		r <<= 1;
		data <<= 1;
		r |= DAC_MISO(n) & 1;
		DAC_SCK(n, 1);
		k_sleep(K_NSEC(500));
	}

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
