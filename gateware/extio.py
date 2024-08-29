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

    def __init__(
        self,
        ram_start_addr = 0,
        spi_start_addr = 0x10000000,
        counter_max_wid = 16,
        timer_wid = 16,
    ):
        # This is Waveform's bus to control SPI and RAM devices it owns.
        self.masterbus = Interface(address_width=32, data_width=32, addressing="byte")
        self.mmap = MemoryMap(self.masterbus)
        self.mmap.add_region("ram", BasicRegion(ram_start_addr, None))
        self.mmap.add_region("spi", BasicRegion(spi_start_addr, None))

        self.submodules.registers = RegisterInterface()

        # run: 
        #   go from 0 to 1 to run the waveform.
        #   If "do_loop" is 0, then it will run once and then stop.
        #   run needs to be set to 0 and then 1 again to run another
        #   waveform.
        #   If "do_loop" is 1, then the waveform will loop until
        #   "run" becomes 0, after which it will finish the waveform
        #   and stop.
        # cntr: 
        #   Current sample the waveform is on.
        # do_loop:
        #   See "run".
        # finished_or_ready:
        #   Bit 0 is the "ready" bit. "Ready" means that "run" can be
        #   set to "1" to enable a waveform run.
        #
        #   Bit 1 is the "finished" bit. "Finished" means that the
        #   waveform has finished an output and is waiting for "run"
        #   to be set back to 0. This only happens when "do_loop" is 0.
        # wform_width:
        #   Size of the waveform in memory, in words.
        # timer:
        #   Current value of the timer. See below.
        # timer_spacing:
        #   Amount of cycles to wait in between outputting each sample.
        # force_stop:
        #   Forcibly stop the output of the waveform. The SPI bus may be
        #   in an unknown state after this.
        self.registers.add_registers([
            {
                'name':'run', 
                'read_only':False, 
                'bitwidth_or_sig':1
            },
            {
                'name':'cntr', 
                'read_only':True, 
                'bitwidth_or_sig':counter_max_wid
            },
            {
                'name':'do_loop', 
                'read_only':False, 
                'bitwidth_or_sig':1
            },
            {
                'name':'finished_or_ready', 
                'read_only':True, 
                'bitwidth_or_sig':2
            },
            {
                'name':'wform_width', 
                'read_only':False, 
                'bitwidth_or_sig':counter_max_wid
            },
            {
                'name':'timer', 
                'read_only':True, 
                'bitwidth_or_sig':timer_wid
            },
            {
                'name':'timer_spacing', 
                'read_only':False, 
                'bitwidth_or_sig':timer_wid
            },
            {
                'name':'force_stop', 
                'read_only':False, 
                'bitwidth_or_sig':1
            },
        ])

        self.specials += Instance("waveform",
                p_RAM_START_ADDR = ram_start_addr,
                p_SPI_START_ADDR = spi_start_addr,
                p_COUNTER_MAX_WID = counter_max_wid,
                p_TIMER_WID = timer_wid,

                i_clk = ClockSignal(),

                i_run = self.registers.signals["run"],
                i_force_stop = self.registers.signals["force_stop"],
                o_cntr = self.registers.signals["cntr"],
                i_do_loop = self.registers.signals["do_loop"],
                o_finished = self.registers.signals["finished_or_ready"][1],
                o_ready = self.registers.signals["finished_or_ready"][0],
                i_wform_size = self.registers.signals["wform_width"],
                o_timer = self.registers.signals["timer"],
                i_timer_spacing = self.registers.signals["timer_spacing"],

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

    def add_spi(self, bus, width):
        # Waveform code has the SPI hardcoded in, because it is a Verilog
        # module.
        self.mmap.regions['spi'].bus = bus
        self.mmap.regions['spi'].size = width

    def pre_finalize(self):
        self.registers.pre_finalize()

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

    """ Wrapper for the SPI master verilog code. """
    def __init__(
        self, 
        rst, 
        miso, 
        mosi, 
        sck, 
        ss_L,
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

        finished_or_ready = Signal(2)
        finished_or_ready_flag = Signal()

        self.sync += [
            finished_or_ready_flag.eq(finished_or_ready[0] | finished_or_ready[1])
        ]

        self.submodules.registers = RegisterInterface()

        # finished_or_ready: 
        #   The first bit is the "ready" bit, when the master is
        #   not armed and ready to be armed.
        #   The second bit is the "finished" bit, when the master is
        #   armed and finished with a transmission.
        # arm: 
        #   One bit to initiate a transmission cycle. Transmission
        #   cycles CANNOT be interrupted.
        # from_slave:
        #   Data sent from the SPI slave.
        # to_slave:
        #   Data sent to the SPI slave.
        # wait_finished_or_ready:
        #   Same as ready_or_finished, but halts until ready or finished
        #   goes high. Dangerous, might cause cores to hang!
        self.registers.add_registers([
            {
                'name':'finished_or_ready', 
                'read_only':True, 
                'bitwidth_or_sig':finished_or_ready
            },
            {
                'name':'arm', 
                'read_only':False, 
                'bitwidth_or_sig':1
            },
            {
                'name':'from_slave', 
                'read_only':True, 
                'bitwidth_or_sig':spi_wid
            },
            {
                'name':'to_slave', 
                'read_only':False, 
                'bitwidth_or_sig':spi_wid
            },
            {
                'name':'wait_finished_or_ready', 
                'read_only':True, 
                'bitwidth_or_sig':finished_or_ready, 
                'ack_signal':finished_or_ready_flag
            },
        ])

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

            o_from_slave = self.registers.signals["from_slave"],
            i_to_slave = self.registers.signals["to_slave"],
            o_finished = finished_or_ready[0],
            o_ready_to_arm = finished_or_ready[1],
            i_arm = self.registers.signals["arm"],
        )

    def pre_finalize(self):
        self.registers.pre_finalize()

class PIPipeline(Module):
    def __init__(self, input_width = 18, output_width = 32):
        """
        :param input_width: Width of input signals
        :param output_width: Width of output signals
        """

        result_valid_flag = Signal()
        pi_pipeline_actual = Signal(input_width)
        pi_pipeline_integral_result = Signal(output_width)
        pi_pipeline_pi_result = Signal(output_width)

        self.submodules.registers = RegisterInterface()

        # Registers available to the main CPU
        self.submodules.controller_registers = RegisterInterface()

        # Registers available to the feedback loop
        self.submodules.feedback_registers = RegisterInterface()

        # Note that for the controller registers, we do not specify the ack flag so reads may
        # occur even while a result is being processed. We do this to ensure that 1) the main
        # CPU never hangs and 2) that the Wishbone specification is being followed since the
        # cycle line is driven by the feedback register bus (ack only responds to the cyc signal
        # of one bus)

        # Add the following registers to the controller registers and feedback registers.
        # kp: the kp input term for the PI calculation
        # ki: the ki term input for the PI calculation
        # setpoint: the setpoint input for the PI calculation
        # actual: the actual measured input for the PI calculation
        # integral_input: the current integral input for the PI calculation
        # integral_result: the integral + error output from the PI pipeline
        # pi_result: The updated PI output from the PI pipeline
        # pi_result_wait_finished: The updated PI output from the PI pipeline

        self.controller_registers.add_registers([
            {
                'name':'kp',
                'read_only':False, 
                'bitwidth_or_sig':output_width
            },
            {
                'name':'ki', 
                'read_only':False, 
                'bitwidth_or_sig':output_width
            },
            {
                'name':'setpoint', 
                'read_only':False, 
                'bitwidth_or_sig':input_width
            },
            {
                'name':'actual', 
                'read_only':True,
                'bitwidth_or_sig':pi_pipeline_actual
            },
            {
                'name':'integral_result', 
                'read_only':True, 
                'bitwidth_or_sig':pi_pipeline_integral_result
            },
            {
                'name':'pi_result', 
                'read_only':True,
                'bitwidth_or_sig':pi_pipeline_pi_result
            }
        ])

        self.feedback_registers.add_registers([
            {
                'name':'actual', 
                'read_only':False, 
                'bitwidth_or_sig':pi_pipeline_actual
            },
            {
                'name':'integral_input', 
                'read_only':False, 
                'bitwidth_or_sig':output_width
            },
            {
                'name':'integral_result', 
                'read_only':True, 
                'bitwidth_or_sig':pi_pipeline_integral_result
            },
            {
                'name':'pi_result_wait_finished', 
                'read_only':True, 
                'bitwidth_or_sig':pi_pipeline_pi_result,
                'ack_signal':result_valid_flag
            },
            {
                'name':'pi_result_flags', 
                'read_only':True, 
                'bitwidth_or_sig':2
            },
        ])

        self.specials += Instance("pi_pipeline",
            p_INPUT_WIDTH = input_width,
            p_OUTPUT_WIDTH = output_width,

            i_clk = ClockSignal(),
            i_cyc = self.feedback_registers.bus.cyc,
            i_kp = self.controller_registers.signals["kp"],
            i_ki = self.controller_registers.signals["ki"],
            i_setpoint = self.controller_registers.signals["setpoint"],
            i_actual = pi_pipeline_actual,
            i_integral_input = self.feedback_registers.signals["integral_input"],

            o_result_valid = result_valid_flag,
            o_integral_result = pi_pipeline_integral_result,
            o_pi_result = pi_pipeline_pi_result,
            o_pi_result_overflow_detected = self.feedback_registers.signals["pi_result_flags"][0],
            o_pi_result_underflow_detected = self.feedback_registers.signals["pi_result_flags"][1],
        )

    def pre_finalize(self):
        self.controller_registers.pre_finalize()
        self.feedback_registers.pre_finalize()