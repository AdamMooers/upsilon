import machine
from micropython import const

dac_0_arm = Const(4026531852)
dac_0_finished = Const(4026531848)

machine.mem8[dac_0_arm] = 1
while machine.mem8[dac_0_finished] != 1:
    pass
machine.mem8[dac_0_arm] = 0
