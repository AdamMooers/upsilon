#include <zephyr/zephyr.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include "pin_io.h"

void
main(void)
{
	uint32_t out_pins = 0;
	uint32_t in_pin;

	LOG_PRINTK("hello, world\n");
	for (;;) {
		k_sleep(K_MSEC(1000));
		*dac_ctrl[0] = out_pins;
		out_pins++;
		if (out_pins == 7)
			out_pins = 0;
		in_pin = *dac_miso[0];

		LOG_PRINTK("out: %d; in: %d\n", out_pins, in_pin);
	}
}
