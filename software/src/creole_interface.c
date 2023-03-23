#include <sys_clock.h>
#include <sys/util.h>
#include "control_loop_cmds.h"
#include "creole.h"
#include "creole_upsilon.h"
#include "pin_io.h"
#include "creole.h"

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

creole_word
upsilon_get_adc(creole_word adc)
{
	if (adc < 0 || adc >= ADC_MAX)
		return 0;

	*adc_arm[adc] = 1;
	/* TODO: sleep 550 ns */
	while (!*adc_finished[adc]);

	creole_word w = sign_extend(*from_adc[adc]);
	*adc_arm[adc] = 0;

	return w;
}

static uint32_t
send_dac(creole_word dac, uint32_t val)
{
	*to_dac[dac] = val;
	*dac_arm[dac] = 1;
	/* TODO: sleep */
	while (!*dac_finished[dac]);
	uint32_t w = sign_extend(*from_dac[dac], 20);
	*dac_arm[dac] = 0;

	return w;
}

creole_word
upsilon_get_dac(creole_word dac)
{
	if (dac < 0 || dac >= DAC_MAX)
		return 0;

	send_dac(dac, 0x1 << 23 | 0x1 << 20);
	return send_dac(dac, 0);
}

creole_word
upsilon_write_dac(creole_word dac, creole_word val)
{
	if (dac < 0 || dac >= DAC_MAX)
		return 0;
	send_dac(dac, 0x1 << 20 | val);
	return 1;
}

creole_word
upsilon_usec(creole_word usec)
{
	k_sleep(K_USEC(usec));
	return 1;
}

creole_word
upsilon_control_loop_read(creole_word *high_reg,
                          creole_word *low_reg,
                          creole_word code)
{
	*cl_cmd = code;
	*cl_start_cmd = 1;
	while (!*cl_finish_cmd);
	*high_reg = cl_word_out[0];
	*low_reg = cl_word_out[1];
	*cl_start_cmd = 0;

	return 1;
}

creole_word
upsilon_control_loop_write(creole_word high_val,
                           creole_word low_val,
                           creole_word code)
{
	*cl_cmd = CONTROL_LOOP_WRITE_BIT | code;
	cl_word_in[0] = high_val;
	cl_word_in[1] = low_val;
	*cl_start_cmd = 1;
	while (!*cl_finish_cmd);
	*cl_start_cmd = 0;

	return 1;
}

static size_t
load_into_array(const struct creole_reader *start, creole_word *buf, size_t buflen)
{
	size_t i = 0;
	struct creole_word w;
	struct creole_reader r = start;

	while (creole_decode(&r, &w) && i < buflen) {
		buf[i++] = w.word;
	}

	return i;
}

#define MAX_WL_SIZE 4096
creole_word
upsilon_load_waveform(struct creole_env *env, creole_word slot,
                      creole_word db)
{
	creole_word buf[MAX_WL_SIZE];
	size_t len = load_into_array(env->dats[db], buf, ARRAY_SIZE(buf));

	if (len != MAX_WL_SIZE)
		return 0;

	*wf_start_addr[slot] = &buf;
	*wf_refresh_start[slot] = 1;
	while (!*wf_refresh_finished[slot]);
	*wf_refresh_start[slot] = 0;

	return 1;
}
creole_word
upsilon_arm_waveform(creole_word slot, creole_word hof, creole_word wait)
{
	*wf_halt_on_finished[slot] = hof;
	*wf_time_to_wait[slot] = wait;
	*wf_arm[slot] = 1;

	if (wait) {
		while (!*wf_finished[slot]);
		*wf_arm[slot] = 0;
	}

	return 1;
}

creole_word
upsilon_disarm_waveform(creole_word slot)
{
	*wf_arm[slot] = 0;
	return 1;
}

creole_word
upsilon_sendval(struct creole_env *env, creole_word num)
{
	char buf[32];
	struct bufptr bp = {buf, sizeof(buf)};

	return sock_printf(env->fd, &bp, "%u", num) == BUF_OK;
}

creole_word
upsilon_senddat(struct creole_env *env, creole_word db)
{
	char buf[128];
	struct bufptr bp = {buf, 0};
	struct creole_word w;
	struct creole_reader r = start;

	while (creole_decode(&r, &w) && bp.left < buflen) {
		if (w.word > 0xFF)
			return 0;
		buf[bp.left++] = w.word;
	}

	return sock_write_buf(env->fd, &bp);
}
