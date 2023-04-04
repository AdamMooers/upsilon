#pragma once
#include <zephyr/kernel.h>
#include "creole.h"

int dac_take(int dac, k_timeout_t timeout);
int dac_release(int dac);
int dac_read_write(int dac, creole_word send, k_timeout_t timeout,
                   creole_word *recv);

int adc_take(int adc, k_timeout_t timeout);
int adc_release(int adc);
int adc_read(int adc, k_timeout_t timeout, creole_word *wrd);

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
