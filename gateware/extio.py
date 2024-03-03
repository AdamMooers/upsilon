# Copyright 2023-2024 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

from migen import *
from litex.soc.interconnect.wishbone import Interface

from util import *
from region import *

'''
class Waveform(LiteXModule):
    """ Read from a memory location and output the values in that location
        to a DAC. """

    def __init__(self, max_size=16):
        # Interface used by Waveform to read and write data
        self.bus = Interface(data_width = 32, address_width = 32, addressing="byte")

        # Interface used by Main CPU to control Waveform
        self.mainbus = Interface(data_width = 32, address_width = 32, addressing="byte")
        self.mmap = MemoryMap()

        self.start = Signal()
        self.cntr = Signal(max_size)
        self.loop = Signal()
        self.finished = Signal()
        self.ready = Signal()

        self.comb += [
                If(self.mainbus.cyc & self.mainbus.stb & ~self.mainbus.ack,
                    Cases(self.mainbus.adr[0:4], {
                        0x0: self.mainbus.dat_r.eq(self.finished << 1 | self.ready),
                        0x4: If(self.mainbus.we,
                                self.start.eq(self.mainbus.dat_w[0]),
                                self.loop.eq(self.mainbus.dat_w[1]),
                            ).Else(
                                self.mainbus.dat_r.eq(self.start << 1 | self.loop),
                            ),
                        0x8: self.mainbus.dat_r.eq(self.cntr)
                    }),
                    self.mainbus.ack.eq(1),
                ).Elif(~self.mainbus.cyc,
                    self.mainbus.ack.eq(0),
                ),
        ]
'''

class SPIMaster(Module):
    AD5791_PARAMS = {
                "polarity" :0,
                "phase" :1,
                "spi_cycle_half_wait" : 10,
                "ss_wait" : 5,
                "enable_miso" : 1,
                "enable_mosi" : 1,
                "spi_wid" : 24,
    }

    LT_ADC_PARAMS = {
            "polarity" : 1,
            "phase" : 0,
            "spi_cycle_half_wait" : 5,
            "ss_wait" : 60,
            "enable_mosi" : 0,
    }

    width = 0x20

    public_registers = {
            # The first bit is the "finished" bit, when the master is
            # armed and finished with a transmission.
            # The second bit is the "ready" bit, when the master is
            # not armed and ready to be armed.
            "ready_or_finished": {
                "origin" : 0,
                "width" : 4,
                "rw": False,
            },

            # One bit to initiate a transmission cycle. Transmission
            # cycles CANNOT be interrupted.
            "arm" : {
                "origin": 4,
                "width": 4,
                "rw": True,
            },

            # Data sent from the SPI slave.
            "from_slave": {
                "origin": 8,
                "width": 4,
                "rw": False,
            },

            # Data sent to the SPI slave.
            "to_slave": {
                "origin": 0xC,
                "width": 4,
                "rw": True
            },

            # Same as ready_or_finished, but halts until ready or finished
            # goes high. Dangerous, might cause cores to hang!
            "wait_ready_or_finished": {
                "origin": 0x10,
                "width": 4,
                "rw" : False,
            },
    }

    """ Wrapper for the SPI master verilog code. """
    def __init__(self, rst, miso, mosi, sck, ss_L,
                polarity = 0,
                phase = 0,
                ss_wait = 1,
                enable_miso = 1,
                enable_mosi = 1,
                spi_wid = 24,
                spi_cycle_half_wait = 1,
        ):
        """
        :param rst: Reset signal.
        :param miso: MISO signal.
        :param mosi: MOSI signal.
        :param sck: SCK signal.
        :param ss: SS signal.
        :param phase: Phase of SPI master. This phase is not the standard
          SPI phase because it is defined in terms of the rising edge, not
          the leading edge. See https://software.mcgoron.com/peter/spi
        :param polarity: See https://software.mcgoron.com/peter/spi.
        :param enable_miso: If ``False``, the module does not read data
          from MISO into a register.
        :param enable_mosi: If ``False``, the module does not write data
          to MOSI from a register.
        :param spi_wid: Verilog parameter: see file.
        :param spi_cycle_half_wait: Verilog parameter: see file.
        """

        self.bus = Interface(data_width = 32, address_width=32, addressing="byte")

        from_slave = Signal(spi_wid)
        to_slave = Signal(spi_wid)
        finished_or_ready = Signal(2)
        arm = Signal()

        self.comb += [
                self.bus.err.eq(0),
        ]

        self.sync += [
                If(self.bus.cyc & self.bus.stb & ~self.bus.ack,
                    Cases(self.bus.adr[0:5], {
                        0x0: [
                            self.bus.dat_r[2:].eq(0),
                            self.bus.dat_r[0:2].eq(finished_or_ready),
                            self.bus.ack.eq(1),
                        ],
                        0x4: [
                            If(self.bus.we,
                                arm.eq(self.bus.dat_w[0]),
                            ).Else(
                                self.bus.dat_r[1:].eq(0),
                                self.bus.dat_r[0].eq(arm),
                            ),
                            self.bus.ack.eq(1),
                            ]
                        0x8: [
                            self.bus.dat_r[wid:].eq(0),
                            self.bus.dat_r[0:wid].eq(from_slave),
                            self.bus.ack.eq(1),
                            ],
                        0xC: [
                            If(self.bus.we,
                            to_slave.eq(self.bus.dat_r[0:wid]),
                            ).Else(
                                self.bus.dat_r[wid:].eq(0),
                                self.bus.dat_r[0:wid].eq(to_slave),
                            ),
                            self.bus.ack.eq(1),
                            ]
                        0x10: If(finished | ready_to_arm,
                            self.bus.dat_r[1:].eq(0),
                            self.bus.dat_r.eq(finished_or_ready),
                        ),
                        "default":
                        # 0xSPI00SPI
                            self.bus.dat_r.eq(0x57100571),
                    }),
                ).Elif(~self.bus.clk,
                    self.bus.ack.eq(0)
                )
            ]

        self.specials += Instance("spi_master_ss",
            p_SS_WAIT = ss_wait,
            p_SS_WAIT_TIMER_LEN = minbits(ss_wait),
            p_CYCLE_HALF_WAIT = spi_cycle_half_wait,
            p_TIMER_LEN = minbits(spi_cycle_half_wait),
            p_WID = spi_wid,
            p_WID_LEN = minbits(spi_wid),
            p_ENABLE_MISO = enable_miso,
            p_ENABLE_MOSI = enable_mosi,
            p_POLARITY = polarity,
            p_PHASE = phase,

            i_clk = ClockSignal(),
            i_rst_L = rst,
            i_miso = miso,
            o_mosi = mosi,
            o_sck_wire = sck,
            o_ss_L = ss_L,

            o_from_slave = from_slave,
            i_to_slave = to_slave,
            o_finished = finished_or_ready[1],
            o_ready_to_arm = finished_or_ready[0],
            i_arm = arm,
        )
