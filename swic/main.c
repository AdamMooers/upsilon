/*
 * Copyright 2024 (C) Adam Mooers
 *
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */

#include <stdint.h>
#include "swic0_mmio.h"

#define DELAY (uint32_t)(1000)
#define DAC_WRITE_MASK (uint32_t)(0x100000)

#define TIMER_IRQ_MASK (uint32_t)(0xFFFFFFFE)

// TODO: DEFINE THESE
#define DAC_SET_MAX (uint32_t)(0x100000)
#define DAC_SET_MIN (uint32_t)(0x100000)

/**
 * Sets the IRQ mask
 *
 * @return The previous IRQ mask
 */
extern uint32_t picorv32_set_irq_mask(uint32_t mask);

/**
 * Pauses the execution of the program until the next interrupt 
 * request (IRQ) occurs. It returns a bit vector containing
 * the pending IRQs.
 *
 * @return A bit vector containing pending IRQs.
 */
extern uint32_t picorv32_waitirq();

/**
 * Sets the hardware timer to the indicated number of clock cycles.
 * The clock counts down and triggers an interrupt if IRQ0 is enabled. 
 */
extern void picorv32_set_timer(uint32_t delay_clock_cycles);

void main(void)
{
/*
	int finished_or_ready_holder;
	int32_t pi_result_flags;

	*PI_PIPELINE0_INTEGRAL_INPUT = 0;

	for (;;)
	{
		// Request voltage from the ADC
		*ADC0_TO_SLAVE = 0;

		// Arm the ADC then wait until a value becomes available
		// Note WAIT_FINISHED_OR_READY stalls the processor until
		// the ADC has a result ready.
		*ADC0_ARM = 1;
		*ADC0_ARM = 0;
		finished_or_ready_holder = *ADC0_WAIT_FINISHED_OR_READY;

		// Update the PI pipeline actual input with the raw ADC value
		*PI_PIPELINE0_ACTUAL = *ADC0_FROM_SLAVE;

		// Collect results from the PI pipeline:
		// Note that this stalls until the pipeline results are ready.
		// We need to set the integral output to the integral input
		// because the pipeline is internally stateless.
		*PI_PIPELINE0_INTEGRAL_INPUT = *PI_PIPELINE0_INTEGRAL_RESULT;

		// We copy the flags to a local variable (presumably a register)
		// to avoid reading the volatile variable twice
		pi_result_flags = *PI_PIPELINE0_PI_RESULT_FLAGS;

		if (pi_result_flags == 0b01) 
		{
			// Overflow detected: saturate at maximum
			*DAC0_TO_SLAVE = DAC_SET_MAX;
		} 
		else if (pi_result_flags == 0b10) 
		{
			// Underflow detected: saturate at minimum
			*DAC0_TO_SLAVE = DAC_SET_MIN;
		} 
		else 
		{
			*DAC0_TO_SLAVE = DAC_WRITE_MASK | *PI_PIPELINE0_PI_RESULT;
		}

		// Arm the DAC and wait until the DAC has updated before
		// starting the wait period in order to assure that we
		// don't read the ADC while the DAC is updating.
		// While it is faster to read the ADC while the DAC is writing,
		// We avoid this because it creates a measurement race condition
		// which could destabilize the PID loop. Furthermore, the output
		// will take some time to settle so we pause between setting the
		// DAC and reading the ADC.
		*DAC0_ARM = 1;
		*DAC0_ARM = 0;
		finished_or_ready_holder = *DAC0_WAIT_FINISHED_OR_READY;

		// TODO: sleep until it is time to start next iteration
	}
*/

	picorv32_set_irq_mask(TIMER_IRQ_MASK);

	*PARAMS_ZPOS = 0;
	int32_t output = 0;

	picorv32_set_timer(DELAY);

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

		*PARAMS_ZPOS = *ADC0_FROM_SLAVE;
		picorv32_waitirq();
		picorv32_set_timer(DELAY);
	}
}
