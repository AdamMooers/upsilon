# Copyright 2023-2024 (C) Adam Mooers
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

"""
Keep this diagram up to date! This is the wiring diagram from the ADC to
the named Verilog pins.

Refer to `A7-constraints.xdc` for pin names.
DAC: SS MOSI MISO SCK
  0:  1    2    3   4 (PMOD A top, right to left)
  1:  1    2    3   4 (PMOD A bottom, right to left)
  2:  1    2    3   4 (PMOD B top, right to left)
  3:  0    1    2   3 (Analog header)
  4:  0    1    2   3 (PMOD C top, right to left)
  5:  4    5    6   8 (Analog header)
  6:  1    2    3   4 (PMOD D top, right to left)
  7:  1    2    3   4 (PMOD D bottom, right to left)


Outer chip header (C=CONV, K=SCK, D=SDO, XX=not connected)
26  27  28  29  30  31  32  33  34  35  36  37  38  39  40  41
C4  K4  D4  C5  K5  D5  XX  XX  C6  K6  D6  C7  K7  D7  XX  XX
C0  K0  D0  C1  K1  D1  XX  XX  C2  K2  D2  C3  K3  D3
0   1   2   3   4   5   6   7   8   9   10  11  12  13

The `io` list maps hardware pins to names used by the SoC
generator. These pins are then connected to Verilog modules.

If there is more than one pin in the Pins string, the resulting
name will be a vector of pins.

TODO: generate declaratively from constraints file.
"""
io = [
#    ("differential_output_low", 0, Pins("J17 J18 K15 J15 U14 V14 T13 U13 B6 E5 A3"), IOStandard("LVCMOS33")),
    ("dac_ss_L_0", 0, Pins("G13"), IOStandard("LVCMOS33")),
    ("dac_mosi_0", 0, Pins("B11"), IOStandard("LVCMOS33")),
    ("dac_miso_0", 0, Pins("A11"), IOStandard("LVCMOS33")),
    ("dac_sck_0", 0, Pins("D12"), IOStandard("LVCMOS33")),

    ("dac_ss_L_1", 0, Pins("D13"), IOStandard("LVCMOS33")),
    ("dac_mosi_1", 0, Pins("B18"), IOStandard("LVCMOS33")),
    ("dac_miso_1", 0, Pins("A18"), IOStandard("LVCMOS33")),
    ("dac_sck_1", 0, Pins("K16"), IOStandard("LVCMOS33")),

    ("dac_ss_L_2", 0, Pins("E15"), IOStandard("LVCMOS33")),
    ("dac_mosi_2", 0, Pins("E16"), IOStandard("LVCMOS33")),
    ("dac_miso_2", 0, Pins("D15"), IOStandard("LVCMOS33")),
    ("dac_sck_2", 0, Pins("C15"), IOStandard("LVCMOS33")),

    ("dac_ss_L_3", 0, Pins("F5"), IOStandard("LVCMOS33")),
    ("dac_mosi_3", 0, Pins("D8"), IOStandard("LVCMOS33")),
    ("dac_miso_3", 0, Pins("C7"), IOStandard("LVCMOS33")),
    ("dac_sck_3", 0, Pins("E7"), IOStandard("LVCMOS33")),

    ("dac_ss_L_4", 0, Pins("U12"), IOStandard("LVCMOS33")),
    ("dac_mosi_4", 0, Pins("V12"), IOStandard("LVCMOS33")),
    ("dac_miso_4", 0, Pins("V10"), IOStandard("LVCMOS33")),
    ("dac_sck_4", 0, Pins("V11"), IOStandard("LVCMOS33")),

    ("dac_ss_L_5", 0, Pins("D7"), IOStandard("LVCMOS33")),
    ("dac_mosi_5", 0, Pins("D5"), IOStandard("LVCMOS33")),
    ("dac_miso_5", 0, Pins("B7"), IOStandard("LVCMOS33")),
    ("dac_sck_5", 0, Pins("E6"), IOStandard("LVCMOS33")),

    ("dac_ss_L_6", 0, Pins("D4"), IOStandard("LVCMOS33")),
    ("dac_mosi_6", 0, Pins("D3"), IOStandard("LVCMOS33")),
    ("dac_miso_6", 0, Pins("F4"), IOStandard("LVCMOS33")),
    ("dac_sck_6", 0, Pins("F3"), IOStandard("LVCMOS33")),

    ("dac_ss_L_7", 0, Pins("E2"), IOStandard("LVCMOS33")),
    ("dac_mosi_7", 0, Pins("D2"), IOStandard("LVCMOS33")),
    ("dac_miso_7", 0, Pins("H2"), IOStandard("LVCMOS33")),
    ("dac_sck_7", 0, Pins("G2"), IOStandard("LVCMOS33")),

    ("adc_conv_0", 0, Pins("V15"), IOStandard("LVCMOS33")),
    ("adc_sck_0", 0, Pins("U16"), IOStandard("LVCMOS33")),
    ("adc_sdo_0", 0, Pins("P14"), IOStandard("LVCMOS33")),

    ("adc_conv_1", 0, Pins("T11"), IOStandard("LVCMOS33")),
    ("adc_sck_1", 0, Pins("R12"), IOStandard("LVCMOS33")),
    ("adc_sdo_1", 0, Pins("T14"), IOStandard("LVCMOS33")),

    ("adc_conv_2", 0, Pins("N15"), IOStandard("LVCMOS33")),
    ("adc_sck_2", 0, Pins("M16"), IOStandard("LVCMOS33")),
    ("adc_sdo_2", 0, Pins("V17"), IOStandard("LVCMOS33")),

    ("adc_conv_3", 0, Pins("U18"), IOStandard("LVCMOS33")),
    ("adc_sck_3", 0, Pins("R17"), IOStandard("LVCMOS33")),
    ("adc_sdo_3", 0, Pins("P17"), IOStandard("LVCMOS33")),

    ("adc_conv_4", 0, Pins("U11"), IOStandard("LVCMOS33")),
    ("adc_sck_4", 0, Pins("V16"), IOStandard("LVCMOS33")),
    ("adc_sdo_4", 0, Pins("M13"), IOStandard("LVCMOS33")),

    ("adc_conv_5", 0, Pins("R10"), IOStandard("LVCMOS33")),
    ("adc_sck_5", 0, Pins("R11"), IOStandard("LVCMOS33")),
    ("adc_sdo_5", 0, Pins("R13"), IOStandard("LVCMOS33")),

    ("adc_conv_6", 0, Pins("R16"), IOStandard("LVCMOS33")),
    ("adc_sck_6", 0, Pins("N16"), IOStandard("LVCMOS33")),
    ("adc_sdo_6", 0, Pins("N14"), IOStandard("LVCMOS33")),

    ("adc_conv_7", 0, Pins("U17"), IOStandard("LVCMOS33")),
    ("adc_sck_7", 0, Pins("T18"), IOStandard("LVCMOS33")),
    ("adc_sdo_7", 0, Pins("R18"), IOStandard("LVCMOS33")),

    ("module_reset", 0, Pins("D9"), IOStandard("LVCMOS33")),
#    ("test_clock", 0, Pins("P18"), IOStandard("LVCMOS33"))
]