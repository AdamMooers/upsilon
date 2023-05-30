/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2020 Dolu1990 <charles.papon.90@gmail.com>
 *
 */

#include <sbi/riscv_asm.h>
#include <sbi/riscv_encoding.h>
#include <sbi/riscv_io.h>
#include <sbi/sbi_const.h>
#include <sbi/sbi_hart.h>
#include <sbi/sbi_platform.h>
#include <sbi_utils/serial/litex_serial.h>
#include <sbi_utils/sys/clint.h>

/* clang-format off */

#define VEX_HART_COUNT         1
#define VEX_PLATFORM_FEATURES  (SBI_PLATFORM_HAS_TIMER_VALUE | SBI_PLATFORM_HAS_MFAULTS_DELEGATION)
#define VEX_CLINT_ADDR         0xF0010000
#define VEX_HART_STACK_SIZE	   SBI_PLATFORM_DEFAULT_STACK_SIZE

/* clang-format on */

static struct clint_data clint = {VEX_CLINT_ADDR, 0, VEX_HART_COUNT, true};

static int vex_early_init(bool cold_boot)
{
	return 0;
}

static int vex_final_init(bool cold_boot)
{
	return 0;
}

static int vex_irqchip_init(bool cold_boot)
{
	return 0;
}

static int vex_ipi_init(bool cold_boot)
{
	int rc;

	if (cold_boot) {
		rc = clint_cold_ipi_init(&clint);
		if (rc)
			return rc;
	}

	return clint_warm_ipi_init();
}

static int vex_timer_init(bool cold_boot)
{
	int rc;
	if (cold_boot) {
		rc = clint_cold_timer_init(&clint, NULL); /* Timer has no reference */
		if (rc)
			return rc;
	}

	return clint_warm_timer_init();
}

const struct sbi_platform_operations platform_ops = {
	.early_init = vex_early_init,
	.final_init = vex_final_init,
	.irqchip_init = vex_irqchip_init,
	.ipi_init = vex_ipi_init,
	.timer_init = vex_timer_init
};

const struct sbi_platform platform = {
	.opensbi_version = OPENSBI_VERSION,
	.platform_version = SBI_PLATFORM_VERSION(0x0, 0x01),
	.name = "LiteX / VexRiscv",
	.features = VEX_PLATFORM_FEATURES,
	.hart_count = VEX_HART_COUNT,
	.hart_stack_size = VEX_HART_STACK_SIZE,
	.platform_ops_addr = (unsigned long)&platform_ops
};

