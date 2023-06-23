# Copyright 2023 (C) Peter McGoron
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.
#
# Upsilon Micropython Standard Library.

from mmio import *

# Write a 20 bit twos-complement value to a DAC.
def dac_write_volt(val, num):
    """
    Write a 20 bit twos-complement value to a DAC.

    :param val: Two's complement 20 bit integer. The number is bitmasked
    to the appropriate length, so negative Python integers are also
    accepted. This DOES NOT check if the integer actually fits in 20
    bits.

    :param num: DAC number.
    :raises Exception:
    """
    write_dac_send_buf(1 << 20 | (val & 0xFFFFF), num)
    write_dac_arm(1, num)
    write_dac_arm(0, num)

# Read a register from a DAC.
def dac_read_reg(val, num):
    write_dac_send_buf(1 << 23 | val, num)
    write_dac_arm(1, num)
    write_dac_arm(0, num)
    return read_dac_recv_buf(num)

# Initialize a DAC by setting it's output value to 0, and
# removing the output restriction from the settings register.
def dac_init(num):
    write_dac_sel(0,num)
    dac_write_volt(0, num)
    write_dac_send_buf(1 << 21 | 1 << 1, num)
    write_dac_arm(1, num)
    write_dac_arm(0, num)
    return dac_read_reg(1 << 21, num)

# Read a value from an ADC.
def adc_read(num):
    write_adc_arm(1, num)
    write_adc_arm(0, num)
    return read_adc_recv_buf(num) 
