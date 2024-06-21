#include <stdint.h>
#include "pico0_mmio.h"

void _start(void)
{
	// On python side:
	// Reset DAC
	// Set DAC to two's complement and enable the output
	// Transfer SPI to pico
	// Load PARAMS_CL_I and PARAMS_CL_P
	// Load Pico with bin

	uint32_t output = 0;

	for (;;)
	{
		uint32_t output = (output + 1)%(1 << 16);

		// Wait for the DAC to become available
		while (!*DAC0_WAIT_FINISHED_OR_READY);

		DAC0_TO_SLAVE = 0x100000 | output;
		DAC0_ARM = 1
		DAC0_ARM = 0
	}
}
