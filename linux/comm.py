from mmio import *

def dac_write_value(val, num):
    write_dac_send_buf(1 << 20 | val & 0xFFFFF, num) # 20 bit DAC
    write_dac_arm(1, num)
    write_dac_arm(0, num)

def dac_read_value(val, num):
    write_dac_send_buf(1 << 23 | val, num)
    write_dac_arm(1, num)
    write_dac_arm(0, num)
    return read_dac_recv_buf(num)

def dac_init(num):
    write_dac_sel(0,num)
    dac_write_value(0, num)
    write_dac_send_buf(1 << 22 | 1 << 2, num)
    write_dac_arm(1, num)
    write_dac_arm(0, num)
    return dac_read_value(1 << 22, num)

def adc_read_value(num):
    write_adc_arm(1, num)
    write_adc_arm(0, num)
    return read_from_adc(num) 
