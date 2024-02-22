import machine
from mmio import *

def read_file(filename):
    with open(filename, 'rb') as f:
        return f.read()

def check_running():
    print("Running:", machine.mem32[pico0_enable])
    print("Trap status:", machine.mem32[pico0_trap])
    print("Bus address:", hex(machine.mem32[pico0_d_adr]))
    print("Bus write value:", hex(machine.mem32[pico0_d_dat_w]))
    print("Instruction address:", hex(machine.mem32[pico0_dbg_insn_addr]))
    print("Opcode:", hex(machine.mem32[pico0_dbg_insn_opcode]))

def run_program(prog, cl_I):
    # Reset PicoRV32
    machine.mem32[pico0_enable] = 0
    machine.mem32[pico0ram_iface_master_select] = 0

    offset = pico0_ram
    for b in prog:
        machine.mem8[offset] = b
        offset += 1

    for i in range(len(prog)):
        assert machine.mem8[pico0_ram + i] == prog[i]

    machine.mem32[pico0_params_cl_I] = cl_I
    machine.mem32[pico0ram_iface_master_select] = 1
    assert machine.mem8[pico0_ram] == 0
    machine.mem32[pico0_enable] = 1
    return machine.mem32[pico0_params_zset]