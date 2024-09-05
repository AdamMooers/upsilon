# Copyright 2024 (C) Adam Mooers
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

.include "custom_ops.s"
.include "swic0_mmio.s"

.extern main

.globl reset_vec
.globl irq_vec
.globl helper_routines
.globl picorv32_set_irq_mask
.globl picorv32_waitirq
.globl picorv32_set_timer

# The ISR starts at 0x10010 so we need to keep the
# reset_vec routine limited to 4 instructions or less.
# The loop command is a safeguard to prevent the SWIC 
# from running the ISR if we return from the main function.

.section .reset_vec,"a"

reset_vec:
    jal main

loop:
    j loop

.section .irq_vec,"a"
irq_vec:
    #picorv32_setq_insn q2, ra
    #jal IRQ_handler
    #picorv32_getq_insn ra, q2
    picorv32_retirq_insn

.section .helper_routines,"a"

picorv32_set_irq_mask:
    picorv32_maskirq_insn a0, a0
    ret

picorv32_waitirq:
    picorv32_waitirq_insn a0
    ret

picorv32_set_timer:
    picorv32_timer_insn a0, a0
    ret
