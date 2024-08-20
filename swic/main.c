#include <stdint.h>
#include "swic0_mmio.h"

#define DELAY (uint32_t)(10000)
#define DAC_WRITE_MASK (uint32_t)(0x100000)

void IRQ_handler(uint32_t irq_mask) __attribute__((section(".IRQ_handler")));

void main(void)
{
	int32_t output = 0;

	*PARAMS_ZPOS = 0;

	for (;;)
	{
		output = (output + 128)%(1 << 16);

		// Wait for the DAC to become available
		//while (*DAC0_WAIT_FINISHED_OR_READY == 0);

		// Write voltage to the DAC
		*DAC0_TO_SLAVE = DAC_WRITE_MASK | output;
		*DAC0_ARM = 1;
		*DAC0_ARM = 0;

		// Request voltage from the ADC
		*ADC0_TO_SLAVE = 0;
		*ADC0_ARM = 1;
		*ADC0_ARM = 0;

		//while (*ADC0_WAIT_FINISHED_OR_READY == 0) {
		//	*PARAMS_ZPOS += 1;
		//}

		for (uint32_t i=0;i<DELAY;i++);

		*PARAMS_ZPOS = output;
	}
}

/*
The IRQ Handler is not yet functional because the registers are not preserved during
interrupt calls and will likely be clobbered if used.*/
void IRQ_handler(uint32_t irq_mask)
{
	//*DAC0_ARM = 1;
	//*DAC0_ARM = 0;
}