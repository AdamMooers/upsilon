#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2020 Florent Kermarrec <florent@enjoy-digital.fr>
# Copyright (c) 2020 Dolu1990 <charles.papon.90@gmail.com>
# Copyright (c) 2023 Peter McGoron
#

# Command for platform specific "make run"
platform-runcmd = echo LiteX/VexRiscv

PLATFORM_RISCV_XLEN = 32
PLATFORM_RISCV_ABI = ilp32
#PLATFORM_RISCV_ISA = rv32ima ## XXX: Broken on new binutils
PLATFORM_RISCV_ISA = rv32ima_zicsr_zifencei
PLATFORM_RISCV_CODE_MODEL = medany
platform-objs-y += platform.o

# Blobs to build
FW_TEXT_START=0x40F00000
FW_JUMP=y
FW_JUMP_ADDR=0x40000000
FW_JUMP_FDT_ADDR=0x40EF0000
