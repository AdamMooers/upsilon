#include <stdint.h>
#include "swic0_mmio.h"

#define DELAY (uint32_t)(10000)
#define DAC_WRITE_MASK (uint32_t)(0x100000)
#define OUTPUT (uint32_t *)(0x10100)
#define I (uint32_t *)(0x10104)

void _start(void)
{
	*OUTPUT = 0;
	*PARAMS_ZPOS = 0;

	for (;;)
	{
		*OUTPUT = (*OUTPUT + 128)%(1 << 16);

		// Wait for the DAC to become available
		//while (*DAC0_WAIT_FINISHED_OR_READY == 0);

		// Write voltage to the DAC
		*DAC0_TO_SLAVE = DAC_WRITE_MASK | *OUTPUT;
		*DAC0_ARM = 1;
		*DAC0_ARM = 0;

		// Request voltage from the ADC
		*ADC0_TO_SLAVE = 0;
		*ADC0_ARM = 1;
		*ADC0_ARM = 0;

		//while (*ADC0_WAIT_FINISHED_OR_READY == 0) {
		//	*PARAMS_ZPOS += 1;
		//}

		for (*I=0;*I<DELAY;(*I)++);

		*PARAMS_ZPOS = *ADC0_FROM_SLAVE;
	}
}
