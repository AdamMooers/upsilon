#pragma once
#include <zephyr/kernel.h>
#include "creole.h"

int dac_take(int dac, k_timeout_t timeout);
int dac_release(int dac);
int dac_read_write(int dac, creole_word send, k_timeout_t timeout,
                   creole_word *recv);

/* These ports are defined in firmware/rtl/base/base.v.m4 */
#define DAC_SPI_PORT 0
#define DAC_WF_PORT 1
#define DAC_CLOOP_PORT 2
int dac_switch(int dac, int setting, k_timeout_t timeout);

int adc_take(int adc, k_timeout_t timeout);
int adc_release(int adc);
int adc_read(int adc, k_timeout_t timeout, creole_word *wrd);

#define ADC_SPI_PORT 0
#define ADC_CLOOP_PORT 1
int adc_switch(int adc, int setting, k_timeout_t timeout);

int cloop_take(k_timeout_t timeout);
int cloop_read(int code, uint32_t *high_reg, uint32_t *low_reg,
               k_timeout_t timeout);
int cloop_write(int code, uint32_t high_val, uint32_t low_val,
                k_timeout_t timeout);
int cloop_release(void);

int waveform_take(int waveform, k_timeout_t timeout);
int waveform_release(int waveform);

#define MAX_WL_SIZE 4096
int waveform_load(uint32_t buf[MAX_WL_SIZE], int slot, k_timeout_t timeout);
int waveform_arm(int slot, bool halt_on_finish, uint32_t wait, k_timeout_t timeout);
int waveform_disarm(int slot);


/* Zephyr OS does not automatically clean up mutex resources.
 * This will release all held locks.
 */
void access_release_thread(void);

/* Called once on initializion. */
void access_init(void);
