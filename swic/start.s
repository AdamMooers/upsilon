#include "custom_ops.S"

.globl reset_vec
.section .reset_vec,"a"

.globl IRQ_handler
.section .IRQ_handler,"a"

# The ISR starts at 0x10010 so we need to keep the
# reset_vec routine limited to 4 instructions or less.
# The loop command is a safeguard to prevent the SWIC 
# from running the ISR if we return from the main function.

reset_vec:
    call main

loop:
    j loop

IRQ_handler:
    picorv32_retirq_insn()