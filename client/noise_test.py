"""
Copyright 2023 (C) Peter McGoron

This file is a part of Upsilon, a free and open source software project.
For license terms, refer to the files in `doc/copying` in the Upsilon
source distribution.
"""

from pssh.clients import SSHClient
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import sys

def sign_extend(value, bits):
    is_signed = (value >> (bits - 1)) & 1 == 1
    if not is_signed:
        return value
    return -((~value + 1) & ((1 << (bits - 1)) - 1))

client = SSHClient('192.168.1.50', user='root', pkey='~/.ssh/upsilon_key')
client.scp_send('../linux/noise_test.py', '/root/noise_test.py')
out = client.run_command('micropython noise_test.py')

current_dac = None
current_adc = []
x_ax = []
y_ax = []
for line in out.stdout:
    l = line.split(' ')
    if l[0] != current_dac:
        if current_dac is not None:
            m = np.mean(current_adc)
            sdev = np.std(current_adc)
            print(current_dac, m, sdev)
            x_ax.append(current_dac)
            y_ax.append(m)
        current_adc = [sign_extend(int(l[1]), 18)]
        current_dac = l[0]
    else:
        current_adc.append(sign_extend(int(l[1]),18))

df = pd.DataFrame({"x": x_ax, "y": y_ax})
df.to_csv(f"{sys.argv[1]}.csv")
plt.plot(df.x, df.y)
plt.show()
