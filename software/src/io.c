#include <zephyr/kernel.h>
#include "pin_io.h"

/* LT ADCs work like this:
 * 1) Send CONV signal high
 * 2) wait for conversion to happen
 * 3) read in from output (change on rising edge, read on lower)
 * The evaluation boards do not give access to the BUSY signal, so this
 * contoller cannot be interrupt driven. This is probably a blessing
 * in disguise because it's easier for me to write blocking code :-)
 */

struct adc_timing {
	unsigned conv_time;
	unsigned wid;
};

enum adc_types {
	LT2380_24, 
	LT2328_16,
	LT2328_18,
	ADC_TYPES_LEN
};

uint32_t
adc_read(size_t num, enum adc_types ty)
{
	uint32_t r = 0;
	// TODO
	static const struct time[ADC_TYPES_LEN] = {
		[LT2380_24] = {0},
		[LT2328_16] = {0},
		[LT2328_18] = {0}
	};

	if (ty < 0 || ty >= ADC_TYPES_LEN) {
		LOG_ERROR("adc_read got unknown ADC type\n");
		k_fatal_halt(K_ERR_KERNEL_OOPS);
	}
	if (num >= ADC_MAX) {
		LOG_ERROR("Bad ADC %d\n", num);
		k_fatal_halt(K_ERR_KERNEL_OOPS);
	}

	*adc_sck[num] = 0;
	*adc_conv[num] = 1;

	k_sleep(K_NSEC(time[ty].conv_time));
	*adc_conv[num] = 0;

	for (int i = 0; i < time[ty].wid; i++) {
		r <<= 1;
		r |= *adc_sdo[num];

		*adc_sck[num] = 1;
		/* 1 millisecond -> 1 MHz */
		k_sleep(K_NSEC(500));
		*adc_sck[num] = 0;
		k_sleep(K_NSEC(500));
	}

	return r;
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
		LOG_ERROR("dac_write_raw got bad ADC %d\n", n);
		k_fatal_halt(K_ERR_KERNEL_OOPS);
	}

	for (int i = 0; i < 20; i++) {
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
