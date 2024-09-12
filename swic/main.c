/*
 * Copyright 2024 (C) Adam Mooers
 *
 * This file is a part of Upsilon, a free and open source software project.
 * For license terms, refer to the files in `doc/copying` in the Upsilon
 * source distribution.
 */

#include <stdint.h>
#include "swic0_mmio.h"

#define DAC_WRITE_MASK (uint32_t)(0x100000)

#define TIMER_IRQ_MASK (uint32_t)(0xFFFFFFFE)

#define DAC_BITS 20
#define DAC_SIGN_BIT_MASK (int32_t)(1 << (_DAC_BITS - 1))
#define DAC_SET_MAX (uint32_t)(DAC_SIGN_BIT_MASK - 1)
#define DAC_SET_MIN (int32_t)(-DAC_SIGN_BIT_MASK)

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
 * The clock counts down and triggers an interrupt on the transition
 * from 1->0 if IRQ0 is unmasked. 
 */
extern void picorv32_set_timer(uint32_t delay_clock_cycles);

/**
 * The SPI peripherals have a special register which freezes the main
 * CPU until the SPI write is complete. GCC will optimize out calls to
 * these registers since we read without writing. This method provides
 * a fast and reliable way to ensure that these reads are not optimized out.
 * 
 * @param reg The register to read
 */
inline void wait_for_register(volatile uint32_t* reg)
{
	asm volatile (
		"lw x0, 0(%0)"
		:
		: "r" (reg)
	);
}

void main(void)
{
	picorv32_set_irq_mask(TIMER_IRQ_MASK);
	int32_t pi_result_flags;

	*PI_PIPELINE0_INTEGRAL_INPUT = 0;

	picorv32_set_timer(*PARAMS_DELTAT);
	for (;;)
	{
		// Request voltage from the ADC
		*ADC0_TO_SLAVE = 0;

		// Arm the ADC then wait until a value becomes available
		// Note WAIT_FINISHED_OR_READY stalls the processor until
		// the ADC has a result ready.
		*ADC0_ARM = 1;
		*ADC0_ARM = 0;
		wait_for_register(ADC0_WAIT_FINISHED_OR_READY);

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
		wait_for_register(DAC0_WAIT_FINISHED_OR_READY);

		picorv32_waitirq();
	}

	/*
	picorv32_set_irq_mask(TIMER_IRQ_MASK);

	*PARAMS_ZPOS = 0;
	int32_t output = 0;

	picorv32_set_timer(*PARAMS_DELTAT);

	for (;;)
	{
		output = (output + 1024)%(1 << 14);

		// Wait for the DAC to become available
		while (*DAC0_WAIT_FINISHED_OR_READY == 0);

		// Write voltage to the DAC
		*DAC0_TO_SLAVE = DAC_WRITE_MASK | output;
		*DAC0_ARM = 1;
		*DAC0_ARM = 0;
		wait_for_register(DAC0_WAIT_FINISHED_OR_READY);

		// Request voltage from the ADC
		*ADC0_TO_SLAVE = 0;
		*ADC0_ARM = 1;
		*ADC0_ARM = 0;
		wait_for_register(ADC0_WAIT_FINISHED_OR_READY);

		*PARAMS_ZPOS = output;

		picorv32_waitirq();
	}
	*/
}
