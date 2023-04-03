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
#include <zephyr/logging/log.h>
#include "converters.h"
#include "pin_io.h"

LOG_MODULE_REGISTER(access);

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

static struct k_mutex_t dac_mutex[DAC_MAX];
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

	*to_dac[dac] = send;
	*dac_arm[adc] = 1;

	/* Recursive locks should busy wait. */
	/* 10ns * (2 * 10 cycles per half DAC cycle)
	        * 24 bits
	 */
	if (dac_locked[dac] > 1)
		k_sleep(K_NSEC(10*2*10*24));
	while (!*dac_finished[dac]);

	if (recv)
		*recv = sign_extend(*from_dac[dac], 20);
	*dac_arm[dac] = 0;

	dac_release(dac);
	return 0;
}

/**********************
 * adc read
 *********************/

static struct k_mutex_t adc_mutex[ADC_MAX];
static __thread int adc_locked[ADC_MAX];

int
adc_take(int adc, int timeout)
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
adc_read(int adc, int timeout, creole_word *wrd)
{
	int e;
	if ((e = adc_take(adc, timeout)) != 0)
		return e;

	*adc_arm[adc] = 1;

	/* Recursive locks should busy wait. */
	if (adc_locked[adc] > 1)
		k_sleep(K_NSEC(550 + 24*2*10*10));
	while (!*adc_finished[adc]);

	*wrd = sign_extend(*from_adc[adc]);
	*adc_arm[adc] = 0;

	adc_release(adc);
	return 0;
}

/********
 * Control loop
 *******/

static struct k_mutex_t cloop_mutex;
static __thread cloop_locked;

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
	/* If being unlocked for the last time. */
	if (cloop_locked == 1) {
		*cl_cmd = CONTROL_LOOP_WRITE_BIT | CONTROL_LOOP_STATUS;
		cl_word_out[0] = 0;
		cl_word_out[1] = 0;
		*cl_start_cmd = 1;
		while (!*cl_finish_cmd);
		*cl_start_cmd = 0;
	}
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
	if (cloop_take(timeout) != 0)
		return 0;

	*cl_cmd = code;
	*cl_start_cmd = 1;
	while (!*cl_finish_cmd);
	*high_reg = cl_word_out[0];
	*low_reg = cl_word_out[1];
	*cl_start_cmd = 0;

	cloop_release();
	return 1;
}

int
cloop_write(int code, uint32_t high_reg, uint32_t low_reg,
            k_timeout_t timeout)
{
	if (cloop_take(timeout) != 0)
		return 0;

	*cl_cmd = code;
	cl_word_in[0] = high_val;
	cl_word_in[1] = low_val;

	*cl_start_cmd = 1;
	while (!*cl_finish_cmd);
	*cl_start_cmd = 0;

	cloop_release();
	return 1;
}

/************
 * Waveforms
 ***********/

static struct k_mutex_t waveform_mutex[DAC_MAX];
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

int
waveform_release(int waveform)
{
	if (waveform < 0 || waveform >= DAC_MAX)
		return -EFAULT;

	if (waveform_locked[waveform] == 1) {
		*wf_arm[waveform] = 0;
		while (*wf_running[waveform]);
	}

	int e k_mutex_unlock(waveform_mutex + waveform);
	if (e == 0) {
		waveform_locked[e]--;
	}
}

size_t
creole_to_array(const struct creole_reader *start, creole_word *buf, size_t buflen)
{
	size_t i = 0;
	struct creole_word w;
	struct creole_reader r = start;

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

	if (load_into_array(env->dats[db], buf, ARRAY_SIZE(buf))
	    != MAX_WL_SIZE)
		goto ret;

	*wf_start_addr[slot] = &buf;
	*wf_refresh_start[slot] = 1;
	while (!*wf_refresh_finished[slot]);
	*wf_refresh_start[slot] = 0;

	waveform_release(slot);
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

	*wf_halt_on_finished[slot] = halt_on_finish;
	*wf_time_to_wait[slot] = wait;
	*wf_arm[slot] = 1;

	return 1;
}

int
waveform_disarm(int slot)
{
	*wf_arm[slot] = 0;
	while (*wf_running[slot]);
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
		LOG_WRN("cloop mutex counter mismatch");
		cloop_locked = 0;
	}

	for (int i = 0; i < DAC_MAX; i++) {
		while (dac_release(i) == 0);
			dac_locked[i]--;
		if (dac_locked[i] != 0) {
			LOG_WRN("dac mutex %d counter mismatch", i);
			dac_locked[i] = 0;
		}

		while (waveform_release(i) == 0)
			waveform_locked[i]--;
		if (waveform_locked[i] != 0) {
			LOG_WRN("waveform mutex %d counter mismatch", i);
			waveform_locked[i] = 0;
		}
	}

	for (int i = 0; i < DAC_MAX; i++) {
	}

	for (int i = 0; i < ADC_MAX; i++) {
		while (adc_release(i) == 0)
			adc_locked[i]--;
		if (adc_locked[i] != 0) {
			LOG_WRN("adc mutex %d counter mismatch", i);
			adc_locked[i] = 0;
		}
	}
}

int
access_init(void)
{
	k_mutex_init(cloop_mutex);

	for (int i = 0; i < DAC_NUM; i++) {
		k_mutex_init(dac_mutex + i);
		k_mutex_init(waveform_mutex + i);
	}

	for (int i = 0; i < ADC_NUM; i++) {
		k_mutex_init(adc_mutex + i);
	}
}
