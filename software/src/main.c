#include <zephyr/zephyr.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include "pin_io.h"

void
main(void)
{
	uint32_t v = 0;
	uint32_t r = 0;
	LOG_PRINTK("hello, world\n");
	for (;;) {
		k_sleep(K_MSEC(1000));
#if 0 // ADC code
		*adc_conv[0] = v;
		v = !v;
		r = *adc_sdo[0];
#endif 
		*dac_ctrl[0] = v;
		v++;
		if (v == 8)
			v = 0;
		r = *dac_miso[0];
		LOG_PRINTK("out: %d; in: %d\n", v, r);
	}
}
