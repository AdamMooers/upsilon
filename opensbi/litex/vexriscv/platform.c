/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2020 Dolu1990 <charles.papon.90@gmail.com>
 * Copyright (C) 2023 Peter McGoron
 *
 */

#include <sbi/riscv_asm.h>
#include <sbi/riscv_encoding.h>
#include <sbi/riscv_io.h>
#include <sbi/sbi_const.h>
#include <sbi/sbi_hart.h>
#include <sbi/sbi_platform.h>
#include <sbi_utils/ipi/aclint_mswi.h>
#include <sbi_utils/irqchip/plic.h>
#include <sbi_utils/timer/aclint_mtimer.h>

// LiteX VexRISC-V only supports CLINT, not updated ACLINT

/* clang-format off */

#define VEX_HART_COUNT         1
#define VEX_PLATFORM_FEATURES  (SBI_PLATFORM_HAS_MFAULTS_DELEGATION)
// hardcoded in SoC Generator
#define VEX_CLINT_ADDR         0xF0010000
#define VEX_PLIC_ADDR          0xF0C00000
#define VEX_HART_STACK_SIZE	   SBI_PLATFORM_DEFAULT_HART_STACK_SIZE
#define VEX_MSWI_ADDR (VEX_CLINT_ADDR + CLINT_MSWI_OFFSET)
#define VEX_MTIMER_ADDR (VEX_CLINT_ADDR + CLINT_MTIMER_OFFSET)
#define VEX_MTIMER_FREQ 100000000 // XXX: System clock frequency?

/* clang-format on */

static struct aclint_mswi_data clint_mswi = {
	.addr = VEX_CLINT_ADDR + CLINT_MSWI_OFFSET,
	.first_hartid = 0,
	.hart_count = VEX_HART_COUNT,
	.size = ACLINT_MSWI_SIZE
};

static struct aclint_mtimer_data mtimer = {
	.mtime_freq = VEX_MTIMER_FREQ,
	.mtime_addr = VEX_MTIMER_ADDR +
		      ACLINT_DEFAULT_MTIME_OFFSET,
	.mtime_size = ACLINT_DEFAULT_MTIME_SIZE,
	.mtimecmp_addr = VEX_MTIMER_ADDR +
			 ACLINT_DEFAULT_MTIMECMP_OFFSET,
	.mtimecmp_size = ACLINT_DEFAULT_MTIMECMP_SIZE,
	.first_hartid = 0,
	.hart_count = VEX_HART_COUNT,
	.has_64bit_mmio = true
};

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
		rc = aclint_mswi_cold_init(&clint_mswi);
		if (rc)
			return rc;
	}

	return aclint_mswi_warm_init();
}

static int vex_timer_init(bool cold_boot)
{
	int rc;
	if (cold_boot) {
		rc = aclint_mtimer_cold_init(&mtimer, NULL); /* Timer has no reference */
		if (rc)
			return rc;
	}

	return aclint_mtimer_warm_init();
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

