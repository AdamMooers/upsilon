import machine
from mmio import *

def read_file(filename):
    with open(filename, 'rb') as f:
        return f.read()

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

    machine.mem32[pico0ram_iface_master_select] = 1
    assert machine.mem8[pico0_ram] == 0
    machine.mem32[pico0_enable] = 1
