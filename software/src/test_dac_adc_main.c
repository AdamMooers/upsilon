#include <zephyr/zephyr.h>
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <stdbool.h>
#include "pin_io.h"
#include "io.h"

LOG_MODULE_REGISTER(dac_adc_test_main);

#define ATTEMPTS 5

static bool dac_ready[DAC_MAX] = {0};

static void
init_dacs(void)
{
	for (size_t i = 0; i < DAC_MAX; i++) {
		for (int j = 0; j < ATTEMPTS; j++) {
			if (dac_init(i)) {
				LOG_INF("DAC #%zu initialized, attempt %d\n", i, j);
				dac_ready[i] = 1;
				break;
			}
		}

		if (!dac_ready[i])
			LOG_WRN("DAC #%zu disconnected!\n", i);
	}
}

K_MUTEX_DEFINE(print_mutex);

static void
print_mutex_unlock_impl(const char *func)
{
	if (k_mutex_unlock(&print_mutex) != 0) {
		LOG_ERR("Fatal error in mutex_unlock in %s\n", func);
		k_fatal_halt(K_ERR_KERNEL_PANIC);
	}
}

#define print_mutex_unlock() print_mutex_unlock_impl(__func__)

struct dac_info {
	float lo;
	float hi;
	unsigned num;
};

#ifdef PRINT_DAC
#define MAX_DAC (1 << 20) - 1

static void
print_dac(const struct dac_info *info, uint32_t val)
{
	k_mutex_lock(&print_mutex, K_FOREVER);

	float volt = (info->hi - info->lo) * val / MAX_DAC
	             + info->lo;
	LOG_PRINTK("DAC\t%u\t%f\n", info->num, volt);

	print_mutex_unlock();
}
#endif

static void
dac_thread(void *p1, void *p2, void *p3)
{
	ARG_UNUSED(p2);
	ARG_UNUSED(p3);

	const struct dac_info *info = p1;
	uint32_t val = (1 << 19);
	int incr = 1;
#ifdef PRINT_DAC
	int print_cntr = 0;
#endif

	for (;;) {
		dac_write_v(info->num, val);
		if (val == 0xFFFFF) {
			incr = -1;
		} else if (val == 0) {
			incr = 1;
		}
		val += incr;
#ifdef PRINT_DAC
		if (print_cntr == 8000) {
			print_cntr = 0;
			print_dac(info);
		}
#endif
		k_sleep(K_NSEC(125));
	}
}

struct adc_info {
	float hi;
	unsigned num;
	unsigned wid;
};

static void
print_adc(const struct adc_info *info, int32_t val)
{
	k_mutex_lock(&print_mutex, K_FOREVER);

	const uint32_t bitnum = (1 << info->wid) - 1;
	float volt = info->hi / bitnum * val;
	LOG_PRINTK("ADC\t%u\t%f\n", info->num, volt);

	print_mutex_unlock();
}

static void
adc_thread(void *p1, void *p2, void *p3)
{
	ARG_UNUSED(p2);
	ARG_UNUSED(p3);
	const struct adc_info *info = p1;
	int32_t v;

	for (;;) {
		v = adc_read(info->num, info->wid);
		print_adc(info, v);
		k_sleep(K_MSEC(1000));
	}
}

#define MK_DAC_INFO(n, lo, hi) [n] = {lo, hi, n}
const struct dac_info dac_info[DAC_MAX] = {
	MK_DAC_INFO(0, -10, 10),
	MK_DAC_INFO(1, -10, 10),
	MK_DAC_INFO(2, -10, 10),
	MK_DAC_INFO(3, -10, 10),
	MK_DAC_INFO(4, -10, 10),
	MK_DAC_INFO(5, -10, 10),
	MK_DAC_INFO(6, -10, 10),
	MK_DAC_INFO(7, -10, 10)
};

#undef MK_DAC_INFO

#define STACKSIZ 2048
#define MKSTACK(name, num) \
	K_THREAD_STACK_DEFINE(name##_stk_##num, STACKSIZ)

#define DAC_STACK(n) MKSTACK(dac, n)
DAC_STACK(0);
DAC_STACK(1);
DAC_STACK(2);
DAC_STACK(3);
DAC_STACK(4);
DAC_STACK(5);
DAC_STACK(6);
DAC_STACK(7);
#undef DAC_STACK

const struct adc_info adc_info[ADC_MAX] = {
	// TODO
};

#define ADC_STACK(n) MKSTACK(adc, n)
ADC_STACK(0);
ADC_STACK(1);
ADC_STACK(2);
ADC_STACK(3);
ADC_STACK(4);
ADC_STACK(5);
ADC_STACK(6);
ADC_STACK(7);
#undef ADC_STACK

#undef MKSTACK

void
main(void)
{
	struct k_thread dac_tids[8];
	struct k_thread adc_tids[8];

	LOG_PRINTK("DAC ADC test program.\n");
	init_dacs();

#define CREATE_THREAD(name, num) \
	k_thread_create(&name##_tids[num], \
			(k_thread_stack_t *) name##_stk_##num,        \
			K_THREAD_STACK_SIZEOF(&name##_stk_##num),     \
			name##_thread, &name##_info[num], NULL, NULL, \
			-1, K_FP_REGS, K_MSEC(10))

	CREATE_THREAD(dac, 0);
	CREATE_THREAD(dac, 1);
	CREATE_THREAD(dac, 2);
	CREATE_THREAD(dac, 3);
	CREATE_THREAD(dac, 4);
	CREATE_THREAD(dac, 5);
	CREATE_THREAD(dac, 6);
	CREATE_THREAD(dac, 7);

	CREATE_THREAD(adc, 0);
	CREATE_THREAD(adc, 1);
	CREATE_THREAD(adc, 2);
	CREATE_THREAD(adc, 3);
	CREATE_THREAD(adc, 4);
	CREATE_THREAD(adc, 5);
	CREATE_THREAD(adc, 6);
	CREATE_THREAD(adc, 7);

#undef CREATE_THREAD
}
