from comm import *
from time import sleep_ms

dac_init(0)
write_adc_sel(0,0)
for i in range(-300,300):
    dac_write_volt(i, 0)
    for j in range(0,20):
        print(i, adc_read(0))

