import machine
from mmio import *

trapcode = [
        "normal",
        "illegal rs1",
        "illegal rs2",
        "misalligned word",
        "misalligned halfword",
        "misalligned instruction",
        "ebreak",
]

reg_names = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "t1", "t2",
    "s0/fp", "s1", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7", "s2",
    "s3", "s4", "s5", "s6", "s7", "t3", "t4", "t5", "t6",
]

def u(n):
    # Converts possibly signed number to unsigned 32 bit.
    return hex(n & 0xFFFFFFFF)

def dump():
    print("Running:", "yes" if machine.mem32[pico0_enable] else "no")
    print("Trap status:", trapcode[machine.mem32[pico0_trap]])
    print("Bus address:", u(machine.mem32[pico0_d_adr]))
    print("Bus write value:", u(machine.mem32[pico0_d_dat_w]))
    print("Instruction address:", u(machine.mem32[pico0_dbg_insn_addr]))
    print("Opcode:", u(machine.mem32[pico0_dbg_insn_opcode]))

    # Skip the zero register, since it's always zero.
    for num, name in enumerate(reg_names[1:],start=1):
        print(name + ":", u(machine.mem32[pico0_dbg_reg[name]['origin'] + 0x4*num]))
