from comm import *
from time import sleep_ms

for i in range(-300,300):
    dac_write_volt(i, 0)
    for j in range(0,20):
        print(i, adc_read(0))

