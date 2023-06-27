"""
Copyright 2023 (C) Peter McGoron

This file is a part of Upsilon, a free and open source software project.
For license terms, refer to the files in `doc/copying` in the Upsilon
source distribution.
"""

from pssh.clients import SSHClient # require parallel-ssh
import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import sys

def sign_extend(value, bits):
    """
    Interpret ``value`` as a twos-complement integer of ``bits`` length.

    :param value: Twos-complement integer with finite bit width.
    :param bits: Bit length of ``value``.
    :return: ``value`` converted to a Python integer.
    """

    # Check the sign bit of the integer.
    is_signed = (value >> (bits - 1)) & 1 == 1
    # If not signed, just return the integer.
    if not is_signed:
        return value
    # Otherwise,
    # 1. Do an explicit twos-complement negation
    # 2. Mask all the non-sign bits
    # This returns the positive value as a standard Python integer.
    # Then the function negates the positive integer to get the negative
    # one back.
    return -((~value + 1) & ((1 << (bits - 1)) - 1))

###################
# Boilerplate
###################

# Start a SSH connection to the server.
print('connecting')
client = SSHClient('192.168.1.50', user='root', pkey='~/.ssh/upsilon_key')
# Upload the script.
print('connected')
client.scp_send('../linux/noise_test.py', '/root/noise_test.py')
# Run the script.
out = client.run_command('micropython noise_test.py')

################
# Script Handler
################
"""
The ramp script outputs a list of lines, each with two values separated by one
space. The first value is the DAC setting, the second value is the ADC setting.
This script gets all of those values, averages them by DAC value, and plots
it.
"""

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
