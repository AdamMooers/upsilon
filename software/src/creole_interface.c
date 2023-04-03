#include <zephyr/sys_clock.h>
#include <zephyr/kernel.h>
#include <zephyr/sys/util.h>
#include "control_loop_cmds.h"
#include "creole.h"
#include "creole_upsilon.h"
#include "pin_io.h"
#include "creole.h"

creole_word
upsilon_get_adc(creole_word adc, creole_word *ret)
{
	return adc_read(adc, K_FOREVER, ret);
}

creole_word
upsilon_get_dac(creole_word dac, creole_word *ret)
{
	int e;
	e = dac_read_write(dac, 0x1 << 23 | 0x1 << 20, K_FOREVER, NULL);
	if (e != 0)
		return e;
	return dac_read_write(dac, 0, K_FOREVER, ret);
}

creole_word
upsilon_write_dac(creole_word dac, creole_word val)
{
	return dac_read_write(dac, 0x1 << 20 | val, K_FOREVER, NULL);
}

creole_word
upsilon_usec(creole_word usec)
{
	k_sleep(K_USEC(usec));
	return 0;
}

creole_word
upsilon_control_loop_read(creole_word *high_reg,
                          creole_word *low_reg,
                          creole_word code)
{
	return cloop_read(code, high_reg, low_reg, K_FOREVER);
}

creole_word
upsilon_control_loop_write(creole_word high_val,
                           creole_word low_val,
                           creole_word code)
{
	return cloop_write(code, high_val, low_val, K_FOREVER);
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
	if (len < MAX_WL_SIZE)
		return 0;
	return waveform_load(buf, slot, K_FOREVER);
}

creole_word
upsilon_arm_waveform(creole_word slot, creole_word hof, creole_word wait)
{
	return waveform_arm(slot, hof, wait, K_FOREVER);
}

creole_word
upsilon_disarm_waveform(creole_word slot)
{
	return waveform_disarm(slot);
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

creole_word
upsilon_take_adc(creole_word slot, creole_word timeout)
{
	return adc_take(slot, K_USEC(timeout));
}

creole_word
upsilon_release_adc(creole_word slot)
{
	return adc_release(slot);
}

creole_word
upsilon_take_dac(creole_word slot, creole_word timeout)
{
	return dac_take(slot, K_USEC(timeout));
}

creole_word
upsilon_release_dac(creole_word slot)
{
	return dac_release(slot);
}

creole_word
upsilon_take_wf(creole_word slot, creole_word timeout)
{
	return waveform_take(slot, K_USEC(timeout));
}

creole_word
upsilon_release_wf(creole_word slot)
{
	return waveform_release(slot);
}

creole_word
upsilon_take_cloop(creole_word timeout)
{
	return cloop_take(K_USEC(timeout));
}

creole_word
upsilon_release_cloop(void)
{
	return cloop_release();
}
