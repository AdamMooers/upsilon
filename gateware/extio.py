# Copyright 2023-2024 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

from migen import *
from litex.soc.interconnect.wishbone import Interface

from util import *

class SPIMaster(Module):
    """ Wrapper for the SPI master verilog code. """
    def __init__(self, rst, miso, mosi, sck, ss,
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
          the leading edge. See <https://software.mcgoron.com/peter/spi>
        :param polarity: See <https://software.mcgoron.com/peter/spi>.
        :param enable_miso: If ``False``, the module does not read data
          from MISO into a register.
        :param enable_mosi: If ``False``, the module does not write data
          to MOSI from a register.
        :param spi_wid: Verilog parameter: see file.
        :param spi_cycle_half_wait: Verilog parameter: see file.
        """

        self.bus = Interface(data_width = 32, address_width=32, addressing="byte")
        self.addr_space_size = 0x10

        self.comb += [
                self.bus.err.eq(0),
        ]

        self.specials += Instance("spi_master_ss_wb",
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
            o_ss_L = ss,

            i_wb_cyc = self.bus.cyc,
            i_wb_stb = self.bus.stb,
            i_wb_we = self.bus.we,
            i_wb_sel = self.bus.sel,
            i_wb_addr = self.bus.adr,
            i_wb_dat_w = self.bus.dat_w,
            o_wb_ack = self.bus.ack,
            o_wb_dat_r = self.bus.dat_r,
        )
