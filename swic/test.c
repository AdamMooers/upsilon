#include <stdint.h>
#include "pico0_mmio.h"

#define DELAY (uint32_t)(1000)
#define DAC_WRITE_MASK (uint32_t)(0x100000)
#define OUTPUT (uint32_t *)(0x10100)
#define I (uint32_t *)(0x10104)

void _start(void)
{
	*OUTPUT = 0;

	for (;;)
	{
		*OUTPUT = (*OUTPUT + 128)%(1 << 16);

		*PARAMS_ZPOS = *OUTPUT;

		// Wait for the DAC to become available
		//while (!*DAC0_WAIT_FINISHED_OR_READY);

		*DAC0_TO_SLAVE = DAC_WRITE_MASK | *OUTPUT;
		*DAC0_ARM = 1;
		*DAC0_ARM = 0;

		for (*I=0;*I<DELAY;(*I)++);
	}
}
