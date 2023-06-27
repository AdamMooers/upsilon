from mmio import *
from comm import *
from sys import argv

# The DAC always have to be init and reset
dac_init(0)

write_dac_sel(1 << 1, 0)
write_adc_sel(2 << 1, 0)

def cl_cmd_write(cmd, val):
    write_cl_word_in(val)
    write_cl_cmd(1 << 7 | cmd)
    write_cl_start_cmd(1)
    while not read_cl_finish_cmd():
        print('aa')
    write_cl_start_cmd(0)

def cl_cmd_read(cmd):
    write_cl_cmd(cmd)
    write_cl_start_cmd(1)
    while not read_cl_finish_cmd():
        print('aa')
    write_cl_start_cmd(0)
    return read_cl_word_out()

cl_cmd_write(2, int(argv[1])) # Setpoint
cl_cmd_write(3, int(argv[2])) # P
cl_cmd_write(4, int(argv[3])) # I
cl_cmd_write(8, int(argv[4])) # Delay
cl_cmd_write(1, 1)
