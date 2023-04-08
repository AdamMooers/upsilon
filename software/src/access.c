/* Verilog access control.
 *
 * Mutex management for hardware resources.
 * Each mutex has a thread-local lock counter associated with it, since in
 * Zephyr the recursive lock counter is not publically accessable.
 *
 * On the final unlock for a thread, the code will always take steps to
 * reset the state of the Verilog module so that another thread will
 * see a consistent start state.
 */

#include <zephyr/kernel.h>
#include <soc.h>
#include <zephyr/logging/log.h>
#include "upsilon.h"
#include "access.h"
#include "pin_io.h"
#include "control_loop_cmds.h"

LOG_MODULE_REGISTER(access);

/* The values from converters are not aligned to an 8-bit byte.
 * These values are still in twos compliment and have to be
 * manually sign-extended.
 */
static inline uint32_t
sign_extend(uint32_t in, unsigned len)
{
	if (in >> (len - 1) & 1) {
		uint32_t mask = (1 << len) - 1;
		return ~mask | (in & mask);
	} else {
		return in;
	}
}

/*********************
 * DAC
 *********************/

static struct k_mutex dac_mutex[DAC_MAX];
static __thread int dac_locked[DAC_MAX];

int
dac_take(int dac, k_timeout_t timeout)
{
	if (dac < 0 || dac >= DAC_MAX)
		return -EFAULT;

	int e = k_mutex_lock(dac_mutex + dac, timeout);
	if (e == 0) {
		dac_locked[dac] += 1;
	}
	return e;
}

int
dac_release(int dac)
{
	if (dac < 0 || dac >= DAC_MAX)
		return -EFAULT;

	if (dac_locked[dac] == 1) {
		*dac_arm[dac] = 0;
		while (!*dac_finished[dac]);
	}

	int e = k_mutex_unlock(dac_mutex + dac);
	if (e == 0) {
		dac_locked[dac] -= 1;
	}
	return e;
}

int
dac_read_write(int dac, creole_word send, k_timeout_t timeout, 
               creole_word *recv)
{
	int e = dac_take(dac, timeout);
	if (e != 0)
		return e;
	dac_switch(dac, DAC_SPI_PORT, K_NO_WAIT);

	litex_write32(send, to_dac[dac]);
	litex_write8(1, dac_arm[dac]);

	/* Recursive locks should busy wait. */
	/* 10ns * (2 * 10 cycles per half DAC cycle)
	        * 24 bits
	 */
	if (dac_locked[dac] > 1)
		k_sleep(K_NSEC(10*2*10*24));
	while (!litex_read8(dac_finished[dac]));

	if (recv)
		*recv = sign_extend(litex_read32(from_dac[dac]), 20);
	litex_write8(0, dac_arm[dac]);

	dac_release(dac);
	return 0;
}

int
dac_switch(int dac, int setting, k_timeout_t timeout)
{
	int e = dac_take(dac, timeout);
	if (e != 0)
		return e;

	litex_write8(setting, dac_sel[dac]);

	dac_release(dac);
	return 0;
}

/**********************
 * adc read
 *********************/

static struct k_mutex adc_mutex[ADC_MAX];
static __thread int adc_locked[ADC_MAX];

int
adc_take(int adc, k_timeout_t timeout)
{
	if (adc < 0 || adc >= ADC_MAX)
		return -EFAULT;

	int e = k_mutex_lock(adc_mutex + adc, timeout);
	if (e == 0) {
		adc_locked[adc] += 1;
	}
	return e;
}

int
adc_release(int adc)
{
	if (adc < 0 || adc >= ADC_MAX)
		return -EFAULT;

	if (adc_locked[adc] == 1) {
		*adc_arm[adc] = 0;
		while (!*adc_finished[adc]);
	}

	int e = k_mutex_unlock(adc_mutex + adc);
	if (e == 0) {
		adc_locked[adc] -= 1;
	}
	return e;
}

int
adc_switch(int adc, int setting, k_timeout_t timeout)
{
	/* As of now, only one ADC (the CLOOP adc) is used
	 * by two modules at the same time.
	 */
	if (adc != 0)
		return -ENOENT;

	int e = adc_take(adc, timeout);
	if (e != 0)
		return e;

	litex_write8(setting, adc_sel_0);

	adc_release(adc);
	return 0;
}

int
adc_read(int adc, k_timeout_t timeout, creole_word *wrd)
{
	int e;
	if ((e = adc_take(adc, timeout)) != 0)
		return e;

	adc_switch(adc, ADC_SPI_PORT, K_NO_WAIT);
	litex_write8(1, adc_arm[adc]);

	/* Recursive locks should busy wait. */
	if (adc_locked[adc] > 1)
		k_sleep(K_NSEC(550 + 24*2*10*10));
	while (!litex_read8(adc_finished[adc]));

	*wrd = sign_extend(litex_read32(from_adc[adc]), 20);
	litex_write8(0, adc_arm[adc]);

	adc_release(adc);
	return 0;
}

/********
 * Control loop
 *******/

static struct k_mutex cloop_mutex;
static __thread int cloop_locked;

int
cloop_take(k_timeout_t timeout)
{
	int e = k_mutex_lock(&cloop_mutex, timeout);
	if (e == 0) {
		cloop_locked++;
	}
	return e;
}

int
cloop_release(void)
{
	/* Do not attempt to reset the CLOOP interface.
	 * Other scripts will fight to modify the CLOOP constants
	 * while the loop is still running.
	 */
	int e = k_mutex_unlock(&cloop_mutex);
	if (e == 0) {
		cloop_locked--;
	}
	return e;
}

int
cloop_read(int code, uint32_t *high_reg, uint32_t *low_reg,
           k_timeout_t timeout)
{
	uint64_t v = 0;
	if (cloop_take(timeout) != 0)
		return 0;

	litex_write8(code, cl_cmd);
	litex_write8(1, cl_start_cmd);
	while (!litex_read8(cl_finish_cmd));
	v = litex_read64(cl_word_out);
	litex_write8(0, cl_start_cmd);

	*high_reg = v >> 32;
	*low_reg = v & 0xFFFFFFFF;

	cloop_release();
	return 1;
}

int
cloop_write(int code, uint32_t high_val, uint32_t low_val,
            k_timeout_t timeout)
{
	if (cloop_take(timeout) != 0)
		return 0;

	litex_write8(code, cl_cmd);
	litex_write64((uint64_t) high_val << 32 | low_val, cl_word_in);
	litex_write8(1, cl_start_cmd);
	while (!litex_read8(cl_finish_cmd));
	litex_write8(0, cl_start_cmd);

	cloop_release();
	return 1;
}

/************
 * Waveforms
 ***********/

static struct k_mutex waveform_mutex[DAC_MAX];
static __thread int waveform_locked[DAC_MAX];

int
waveform_take(int waveform, k_timeout_t timeout)
{
	if (waveform < 0 || waveform >= DAC_MAX)
		return -EFAULT;

	int e = k_mutex_lock(waveform_mutex + waveform, timeout);
	if (e == 0) {
		waveform_locked[e]++;
	}
	return e;
}

static void
waveform_disarm_wait(int wf)
{
	litex_write8(0, wf_arm[wf]);
	if (*wf_running[wf]) {
		// k_sleep(K_NSEC(10* *wf_time_to_wait[wf]));
		while (litex_read8(wf_running[wf]));
	}
}

int
waveform_release(int waveform)
{
	if (waveform < 0 || waveform >= DAC_MAX)
		return -EFAULT;

	if (waveform_locked[waveform] == 1) {
		waveform_disarm_wait(waveform);
	}

	int e = k_mutex_unlock(waveform_mutex + waveform);
	if (e == 0) {
		waveform_locked[e]--;
	}
	return e;
}

size_t
creole_to_array(const struct creole_reader *start, creole_word *buf, size_t buflen)
{
	size_t i = 0;
	struct creole_word w;
	struct creole_reader r = *start;

	while (creole_decode(&r, &w) && i < buflen) {
		buf[i++] = w.word;
	}

	return i;
}

int
waveform_load(uint32_t buf[MAX_WL_SIZE], int slot, k_timeout_t timeout)
{
	if (waveform_take(slot, timeout) != 0)
		return 0;

	litex_write32((uint32_t) buf, wf_start_addr[slot]);
	litex_write8(1, wf_refresh_start[slot]);
	while (!litex_read8(wf_refresh_finished[slot]));
	litex_write8(0, wf_refresh_start[slot]);

	waveform_release(slot);
	return 1;
}

int
waveform_halt_until_finished(int slot)
{
	litex_write8(1, wf_halt_on_finish[slot]);
	while (!litex_read(wf_finished[slot]));
	return 1;
}

int
waveform_arm(int slot, bool halt_on_finish, uint32_t wait, k_timeout_t timeout)
{
	if (waveform_take(slot, timeout) != 0)
		return 0;
	if (dac_take(slot, timeout) != 0) {
		waveform_release(slot);
		return 0;
	}

	dac_switch(slot, DAC_WF_PORT, K_NO_WAIT);

	litex_write8(halt_on_finish, wf_halt_on_finish[slot]);
	litex_write16(wait, wf_time_to_wait[slot]);
	litex_write8(1, wf_arm[slot]);

	return 1;
}

int
waveform_disarm(int slot)
{
	waveform_disarm_wait(slot);
	waveform_release(slot);
	dac_release(slot);
	return 1;
}

/**********
 * Init and deinit
 *********/

void
access_release_thread(void)
{
	while (cloop_release() == 0)
		cloop_locked--;
	if (cloop_locked != 0) {
		LOG_WRN("%s: cloop mutex counter mismatch", get_thread_name());
		cloop_locked = 0;
	}

	for (int i = 0; i < DAC_MAX; i++) {
		while (dac_release(i) == 0)
			dac_locked[i]--;
		if (dac_locked[i] != 0) {
			LOG_WRN("%s: dac mutex %d counter mismatch", get_thread_name(), i);
			dac_locked[i] = 0;
		}

		while (waveform_release(i) == 0)
			waveform_locked[i]--;
		if (waveform_locked[i] != 0) {
			LOG_WRN("%s: waveform mutex %d counter mismatch", get_thread_name(), i);
			waveform_locked[i] = 0;
		}
	}

	for (int i = 0; i < DAC_MAX; i++) {
	}

	for (int i = 0; i < ADC_MAX; i++) {
		while (adc_release(i) == 0)
			adc_locked[i]--;
		if (adc_locked[i] != 0) {
			LOG_WRN("%s: adc mutex %d counter mismatch", get_thread_name(), i);
			adc_locked[i] = 0;
		}
	}
}

void
access_init(void)
{
	if (k_mutex_init(&cloop_mutex) != 0) {
		LOG_ERR("err: cloop mutex");
		k_fatal_halt(K_ERR_KERNEL_PANIC);
	}

	for (int i = 0; i < DAC_MAX; i++) {
		if (k_mutex_init(dac_mutex + i) != 0) {
			LOG_ERR("err: dac mutex %d", i);
			k_fatal_halt(K_ERR_KERNEL_PANIC);
		}

		if (k_mutex_init(waveform_mutex + i) != 0) {
			LOG_ERR("err: waveform mutex %d", i);
			k_fatal_halt(K_ERR_KERNEL_PANIC);
		}
	}

	for (int i = 0; i < ADC_MAX; i++) {
		if (k_mutex_init(adc_mutex + i) != 0) {
			LOG_ERR("err: adc mutex %d", i);
			k_fatal_halt(K_ERR_KERNEL_PANIC);
		}
	}
}
