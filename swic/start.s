.include "custom_ops.s"

.globl reset_vec
.globl IRQ_handler

# The ISR starts at 0x10010 so we need to keep the
# reset_vec routine limited to 4 instructions or less.
# The loop command is a safeguard to prevent the SWIC 
# from running the ISR if we return from the main function.

.section .reset_vec,"a"

reset_vec:
    call main

loop:
    j loop

.section .IRQ_handler,"a"

IRQ_handler:
    picorv32_retirq_insn
