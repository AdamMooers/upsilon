.globl start
.section .start

# The ISR starts at 0x10010 so we need to keep the
# start routine limited to 4 instructions or less.
# The loop command is a safeguard to prevent the SWIC 
# from running the ISR if we return from the main function.

start:
    call main

loop:
    j loop
