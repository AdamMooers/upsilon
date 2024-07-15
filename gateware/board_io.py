# Copyright 2023-2024 (C) Adam Mooers
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

from litex.build.generic_platform import IOStandard, Pins

"""
Refer to `A7-constraints.xdc` for pin names.

The `io` list maps hardware pins to names used by the SoC
generator. These pins are then connected to Verilog modules.

If there is more than one pin in the Pins string, the resulting
name will be a vector of pins.

JA-D correspond to the four PMOD headers. The following diagram shows
the pin numbering scheme for these headers as viewed from the front:

    6   5   4   3   2   1
    12  11  10  9   8   7

TODO: generate declaratively from constraints file.
"""

io = [
    # Arty Schematic Names:
    # Note A3/A4 (pins A10/11) are not currently used but A3 is included here for completeness
    # E16: JB pin 2
    # C15: JB pin 4
    # J18: JB pin 8
    # J15: JB pin 10
    # V12: JC pin 2
    # V11: JC pin 4
    # V14: JC pin 8
    # U13: JC pin 10
    # B6: ChipKit pin A7
    # E5: ChipKit pin A9
    # A3: ChipKit pin A11
    ("differential_output_low", 0, Pins("E16 C15 J18 J15 V12 V11 V14 U13 B6 E5 A3"), IOStandard("LVCMOS33")),

    ("dac_ss_L_0", 0, Pins("G13"), IOStandard("LVCMOS33")), #JA pin 1
    ("dac_mosi_0", 0, Pins("B11"), IOStandard("LVCMOS33")), #JA pin 2
    ("dac_miso_0", 0, Pins("A11"), IOStandard("LVCMOS33")), #JA pin 3
    ("dac_sck_0", 0, Pins("D12"), IOStandard("LVCMOS33")),  #JA pin 4

    ("dac_ss_L_1", 0, Pins("D13"), IOStandard("LVCMOS33")), #JA pin 7
    ("dac_mosi_1", 0, Pins("B18"), IOStandard("LVCMOS33")), #JA pin 8
    ("dac_miso_1", 0, Pins("A18"), IOStandard("LVCMOS33")), #JA pin 9
    ("dac_sck_1", 0, Pins("K16"), IOStandard("LVCMOS33")),  #JA pin 10

    ("dac_ss_L_2", 0, Pins("E15"), IOStandard("LVCMOS33")), #JB pin 1 (note: paired with E16)
    ("dac_mosi_2", 0, Pins("D15"), IOStandard("LVCMOS33")), #JB pin 3 (note: paired with C15)
    ("dac_miso_2", 0, Pins("J17"), IOStandard("LVCMOS33")), #JB pin 7 (note: paired with J18)
    ("dac_sck_2", 0, Pins("K15"), IOStandard("LVCMOS33")),  #JB pin 9 (note: paired with J15)

    ("dac_ss_L_3", 0, Pins("F5"), IOStandard("LVCMOS33")),  #ChipKit pin A0
    ("dac_mosi_3", 0, Pins("D8"), IOStandard("LVCMOS33")),  #ChipKit pin A1
    ("dac_miso_3", 0, Pins("C7"), IOStandard("LVCMOS33")),  #ChipKit pin A2
    ("dac_sck_3", 0, Pins("E7"), IOStandard("LVCMOS33")),   #ChipKit pin A3

    ("dac_ss_L_4", 0, Pins("U12"), IOStandard("LVCMOS33")), #JC pin 1 (note: paired with V12)
    ("dac_mosi_4", 0, Pins("V10"), IOStandard("LVCMOS33")), #JC pin 3 (note: paired with V11)
    ("dac_miso_4", 0, Pins("U14"), IOStandard("LVCMOS33")), #JC pin 7 (note: paired with V14)
    ("dac_sck_4", 0, Pins("T13"), IOStandard("LVCMOS33")),  #JC pin 9 (note: paired with U13)

    ("dac_ss_L_5", 0, Pins("D7"), IOStandard("LVCMOS33")),  #ChipKit pin A4
    ("dac_mosi_5", 0, Pins("D5"), IOStandard("LVCMOS33")),  #ChipKit pin A5
    ("dac_miso_5", 0, Pins("B7"), IOStandard("LVCMOS33")),  #ChipKit pin A6 (note: paired with B6)
    ("dac_sck_5", 0, Pins("E6"), IOStandard("LVCMOS33")),   #ChipKit pin A8 (note: paired with E5)

    ("dac_ss_L_6", 0, Pins("D4"), IOStandard("LVCMOS33")),  #JD pin 1
    ("dac_mosi_6", 0, Pins("D3"), IOStandard("LVCMOS33")),  #JD pin 2
    ("dac_miso_6", 0, Pins("F4"), IOStandard("LVCMOS33")),  #JD pin 3
    ("dac_sck_6", 0, Pins("F3"), IOStandard("LVCMOS33")),   #JD pin 4

    ("dac_ss_L_7", 0, Pins("E2"), IOStandard("LVCMOS33")),  #JD pin 7
    ("dac_mosi_7", 0, Pins("D2"), IOStandard("LVCMOS33")),  #JD pin 8
    ("dac_miso_7", 0, Pins("H2"), IOStandard("LVCMOS33")),  #JD pin 9
    ("dac_sck_7", 0, Pins("G2"), IOStandard("LVCMOS33")),   #JD pin 10

    ("adc_conv_0", 0, Pins("V15"), IOStandard("LVCMOS33")), #IO0
    ("adc_sck_0", 0, Pins("U16"), IOStandard("LVCMOS33")),  #IO1
    ("adc_sdo_0", 0, Pins("P14"), IOStandard("LVCMOS33")),  #IO2

    ("adc_conv_1", 0, Pins("T11"), IOStandard("LVCMOS33")), #IO3
    ("adc_sck_1", 0, Pins("R12"), IOStandard("LVCMOS33")),  #IO4
    ("adc_sdo_1", 0, Pins("T14"), IOStandard("LVCMOS33")),  #IO5

    ("adc_conv_2", 0, Pins("N15"), IOStandard("LVCMOS33")), #IO8
    ("adc_sck_2", 0, Pins("M16"), IOStandard("LVCMOS33")),  #IO9
    ("adc_sdo_2", 0, Pins("V17"), IOStandard("LVCMOS33")),  #IO10

    ("adc_conv_3", 0, Pins("U18"), IOStandard("LVCMOS33")), #IO11
    ("adc_sck_3", 0, Pins("R17"), IOStandard("LVCMOS33")),  #IO12
    ("adc_sdo_3", 0, Pins("P17"), IOStandard("LVCMOS33")),  #IO13

    ("adc_conv_4", 0, Pins("U11"), IOStandard("LVCMOS33")), #IO26
    ("adc_sck_4", 0, Pins("V16"), IOStandard("LVCMOS33")),  #IO27
    ("adc_sdo_4", 0, Pins("M13"), IOStandard("LVCMOS33")),  #IO28

    ("adc_conv_5", 0, Pins("R10"), IOStandard("LVCMOS33")), #IO29
    ("adc_sck_5", 0, Pins("R11"), IOStandard("LVCMOS33")),  #IO30
    ("adc_sdo_5", 0, Pins("R13"), IOStandard("LVCMOS33")),  #IO31

    ("adc_conv_6", 0, Pins("R16"), IOStandard("LVCMOS33")), #IO34
    ("adc_sck_6", 0, Pins("N16"), IOStandard("LVCMOS33")),  #IO35
    ("adc_sdo_6", 0, Pins("N14"), IOStandard("LVCMOS33")),  #IO36

    ("adc_conv_7", 0, Pins("U17"), IOStandard("LVCMOS33")), #IO37
    ("adc_sck_7", 0, Pins("T18"), IOStandard("LVCMOS33")),  #IO38
    ("adc_sdo_7", 0, Pins("R18"), IOStandard("LVCMOS33")),  #IO39

    ("module_reset", 0, Pins("D9"), IOStandard("LVCMOS33")), #Button 0
#    ("test_clock", 0, Pins("P18"), IOStandard("LVCMOS33"))
]

