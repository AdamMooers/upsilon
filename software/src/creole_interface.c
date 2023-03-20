#include <sys_clock.h>
#include "control_loop_cmds.h"
#include "creole.h"
#include "creole_upsilon.h"
#include "pin_io.h"

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
	return 0;
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

	return 0;
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

	return 0;
}

creole_word
upsilon_load_waveform(struct creole_env *env, creole_word slot,
                      creole_word db)
{
	/* TODO */
	return 0;
}
creole_word
upsilon_exec_waveform(creole_word slot, creole_word dac)
{
	/* TODO */
	return 0;
}
creole_word
upsilon_sendval(creole_word num)
{
	/* TODO */
	return 0;
}

creole_word
upsilon_senddat(struct creole_env *env, creole_word db)
{
	/* TODO */
	return 0;
}
