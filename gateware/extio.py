# Copyright 2023-2024 (C) Peter McGoron, Adam Mooers
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

from migen import *
from litex.soc.interconnect.wishbone import Interface

from util import *
from region import *

class Waveform(LiteXModule):
    """ A Wishbone bus master that sends a waveform to a SPI master
        by reading from RAM. """

    public_registers = {
            # go from 0 to 1 to run the waveform.
            # If "do_loop" is 0, then it will run once and then stop.
            # run needs to be set to 0 and then 1 again to run another
            # waveform.
            # If "do_loop" is 1, then the waveform will loop until
            # "run" becomes 0, after which it will finish the waveform
            # and stop.

            "run" : Register(
                origin=0,
                bitwidth=1,
                rw=True,
            ),

            # Current sample the waveform is on.
            "cntr": Register(
                origin=0x4,
                bitwidth=16,
                rw=False,
            ),

            # See "run".
            "do_loop": Register(
                origin=0x8,
                bitwidth= 1,
                rw= True,
            ),

            # Bit 0 is the "ready" bit. "Ready" means that "run" can be
            # set to "1" to enable a waveform run.
            #
            # Bit 1 is the "finished" bit. "Finished" means that the
            # waveform has finished an output and is waiting for "run"
            # to be set back to 0. This only happens when "do_loop" is 0.
            "finished_or_ready": Register(
                origin=0xC,
                bitwidth= 2,
                rw= False,
            ),

            # Size of the waveform in memory, in words.
            "wform_width": Register(
                origin=0x10,
                bitwidth=16,
                rw= True,
            ),

            # Current value of the timer. See below.
            "timer": Register(
                origin=0x14,
                bitwidth= 16,
                rw= False,
            ),

            # Amount of cycles to wait in between outputting each sample.
            "timer_spacing": Register(
                origin= 0x18,
                bitwidth= 16,
                rw= True,
            ),

            # Forcibly stop the output of the waveform. The SPI bus may be
            # in an unknown state after this.
            "force_stop" : Register (
                origin=0x1C,
                bitwidth=1,
                rw=True,
            ),
    }

    width = 0x20

    def mmio(self, origin):
        r = ""
        for name, reg in self.public_registers.items():
            r += f'{name} = Register(loc={origin + reg.origin}, bitwidth={reg.bitwidth}, rw={reg.rw}),'
        return r

    def __init__(self,
            ram_start_addr = 0,
            spi_start_addr = 0x10000000,
            counter_max_wid = 16,
            timer_wid = 16,
    ):
        # This is Waveform's bus to control SPI and RAM devices it owns.
        self.masterbus = Interface(address_width=32, data_width=32, addressing="byte")
        # This is the Waveform's interface that is controlled by the Main CPU.
        self.slavebus = b = Interface(address_width=32, data_width=32, addressing="byte")

        self.mmap = MemoryMap(self.masterbus)
        self.mmap.add_region("ram",
                BasicRegion(ram_start_addr, None))
        self.mmap.add_region("spi",
                BasicRegion(spi_start_addr, None))

        run = Signal()
        cntr = Signal(counter_max_wid)
        do_loop = Signal()
        ready = Signal()
        finished = Signal()
        wform_size = Signal(counter_max_wid)
        timer = Signal(timer_wid)
        timer_spacing = Signal(timer_wid)
        force_stop = Signal()

        self.sync += If(b.cyc & b.stb & ~b.ack,
                Case(b.adr[0:5], {
                    0x0: If(b.we,
                           run.eq(b.dat_w[0]),
                         ).Else(
                           b.dat_r.eq(run)
                         ),
                    0x4: [
                        b.dat_r.eq(cntr),
                    ],
                    0x8: [
                        If(b.we,
                            do_loop.eq(b.dat_w[0]),
                        ).Else(
                            b.dat_r.eq(do_loop),
                        )
                    ],
                    0xC: [
                        b.dat_r.eq(finished << 1 | ready),
                    ],
                    0x10: If(b.we,
                            wform_size.eq(b.dat_w[0:counter_max_wid]),
                        ).Else(
                            b.dat_r.eq(wform_size)
                        ),
                    0x14: b.dat_r.eq(timer),
                    0x18: If(b.we,
                            timer_spacing.eq(b.dat_w[0:timer_wid]),
                        ).Else(
                            b.dat_r.eq(timer_spacing),
                        ),
                    0x1C: If(b.we,
                            force_stop.eq(b.dat_w[0]),
                        ).Else(
                            b.dat_r.eq(force_stop),
                        ),
                        # (W)A(V)EFO(RM)
                    "default": b.dat_r.eq(0xAEF0AEF0),
                    }
                ),
                b.ack.eq(1),
            ).Elif(~b.cyc,
                    b.ack.eq(0),
            )

        self.specials += Instance("waveform",
                p_RAM_START_ADDR = ram_start_addr,
                p_SPI_START_ADDR = spi_start_addr,
                p_COUNTER_MAX_WID = counter_max_wid,
                p_TIMER_WID = timer_wid,

                i_clk = ClockSignal(),

                i_run = run,
                i_force_stop = force_stop,
                o_cntr = cntr,
                i_do_loop = do_loop,
                o_finished = finished,
                o_ready = ready,
                i_wform_size = wform_size,
                o_timer = timer,
                i_timer_spacing = timer_spacing,

                o_wb_adr = self.masterbus.adr,
                o_wb_cyc = self.masterbus.cyc,
                o_wb_we = self.masterbus.we,
                o_wb_stb = self.masterbus.stb,
                o_wb_sel = self.masterbus.sel,
                o_wb_dat_w = self.masterbus.dat_w,
                i_wb_dat_r = self.masterbus.dat_r,
                i_wb_ack = self.masterbus.ack,
        )

    def add_ram(self, bus, size):
        self.mmap.regions['ram'].bus = bus
        self.mmap.regions['ram'].size = size

    def add_spi(self, bus):
        # Waveform code has the SPI hardcoded in, because it is a Verilog
        # module.
        self.mmap.regions['spi'].bus = bus
        self.mmap.regions['spi'].size = SPIMaster.width

    def do_finalize(self):
        self.mmap.finalize()

class SPIMaster(Module):
    # IF THESE ARE CHANGED, CHANGE waveform.v !!
    AD5791_PARAMS = {
        "polarity" :0,
        "phase" :1,
        "spi_cycle_half_wait" : 5,
        "ss_wait" : 5,
        "enable_miso" : 1,
        "enable_mosi" : 1,
        "spi_wid" : 24,
    }

    # t_CONV+t_DSDOBUSYL = 3.005 uS max so we wait 3.02 uS for ss_wait
    # to have a little bit of a buffer
    LT_ADC_PARAMS = {
        "polarity" : 1,
        "phase" : 0,
        "spi_cycle_half_wait" : 5,
        "ss_wait" : 302,
        "enable_mosi" : 0,
    }

    width = 0x20

    public_registers = {
            # The first bit is the "ready" bit, when the master is
            # not armed and ready to be armed.
            # The second bit is the "finished" bit, when the master is
            # armed and finished with a transmission.
            "finished_or_ready": Register(
                origin= 0,
                bitwidth= 2,
                rw=False,
            ),

            # One bit to initiate a transmission cycle. Transmission
            # cycles CANNOT be interrupted.
            "arm" : Register(
                origin=4,
                bitwidth=1,
                rw=True,
            ),

            # Data sent from the SPI slave.
            "from_slave": Register(
                origin=8,
                bitwidth=32,
                rw=False,
            ),

            # Data sent to the SPI slave.
            "to_slave": Register(
                origin=0xC,
                bitwidth=32,
                rw=True
            ),

            # Same as ready_or_finished, but halts until ready or finished
            # goes high. Dangerous, might cause cores to hang!
            "wait_finished_or_ready": Register(
                origin=0x10,
                bitwidth=2,
                rw= False,
            ),
    }

    def mmio(self, origin):
        r = ""
        for name, reg in self.public_registers.items():
            r += f'{name} = Register(loc={origin + reg.origin},bitwidth={reg.bitwidth},rw={reg.rw}),'
        return r

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
                    Case(self.bus.adr[0:5], {
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
                            ],
                        0x8: [
                            self.bus.dat_r[spi_wid:].eq(0),
                            self.bus.dat_r[0:spi_wid].eq(from_slave),
                            self.bus.ack.eq(1),
                            ],
                        0xC: [
                            If(self.bus.we,
                                to_slave.eq(self.bus.dat_w[0:spi_wid]),
                            ).Else(
                                self.bus.dat_r[spi_wid:].eq(0),
                                self.bus.dat_r[0:spi_wid].eq(to_slave),
                            ),
                            self.bus.ack.eq(1),
                            ],
                        0x10: If(finished_or_ready[0] | finished_or_ready[1],
                            self.bus.dat_r[2:].eq(0),
                            self.bus.dat_r[0:2].eq(finished_or_ready),
                            self.bus.ack.eq(1),
                        ),
                        "default":
                        # 0xSPI00SPI
                            self.bus.dat_r.eq(0x57100571),
                    }),
                ).Elif(~self.bus.cyc,
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
            # module_reset is active high
            i_rst_L = ~rst,
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

class PDPipeline(Module):
    def __init__(self, input_width = 18, output_width = 32):
        """
        :param input_width: Width of input signals
        :param output_width: Width of output signals
        """

        self.registers = RegisterInterface()

        # The kp term input for the PD calculation
        self.registers.add_register("kp", False, input_width)

        # The ki term input for the PD calculation
        self.registers.add_register("ki", False, input_width)

        # The setpoint input for the PD calculation
        self.registers.add_register("setpoint", False, input_width)

        # The actual measured input for the PD calculation
        self.registers.add_register("actual", False, input_width)

        # The current integral input for the PD calculation
        self.registers.add_register("integral_input", False, output_width)

        # The integral + error output from the PD pipeline 
        self.registers.add_register("integral_result", True, output_width)

        # The updated pd output from the PD pipeline
        self.registers.add_register("pd_result", True, output_width)

        self.specials += Instance("pd_pipeline",
            p_INPUT_WIDTH = input_width,
            p_OUTPUT_WIDTH = output_width,

            i_clk = ClockSignal(),
            i_kp = self.registers.signals["kp"],
            i_ki = self.registers.signals["ki"],
            i_setpoint = self.registers.signals["setpoint"],
            i_actual = self.registers.signals["actual"],
            i_integral_input = self.registers.signals["integral_input"],

            o_integral_result = self.registers.signals["integral_result"],
            o_pd_result = self.registers.signals["pd_result"],
        )