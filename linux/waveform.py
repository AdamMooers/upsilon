from registers import *

class Waveform(Immutable):
    def __init__(self, ram, wf_pi, ram_pi, regs):
        super().__init__()

        self.wf_pi = wf_pi
        self.ram = ram
        self.ram_pi = ram_pi
        self.regs = regs

        self.make_immutable()

    def start(self, wf, timer_spacing, do_loop = False, force_control=False):
        """ Start waveform with signal.
        Note that a transfer of control of the SPI bus to the Waveform
        must be done manually.

        :param wf: Array of integers that describe the waveform.
           These are twos-complement 20-bit integers.
        :param timer_spacing: The amount of time to wait between
           points on the waveform.
        :param do_loop: If True, the waveform will repeat.
        :param force_control: If True, will take control of the Waveform
          even if it is being controlled by another Wishbone bus.
        """
        if self.wf_pi.v != 0:
            if not force_control:
                raise Exception("Waveform is not controlled by master")
            self.wf_pi.v = 0

        self.stop()

        self.ram_pi.v = 0
        self.ram.mem32.load(wf)

        self.regs.wform_width.v = len(wf)
        self.regs.timer_spacing.v = timer_spacing

        self.regs.do_loop.v = do_loop
        self.ram_pi.v = 1
        self.regs.run.v = 1

    def stop(self):
        """ Stop the waveform and wait until it is ready. """
        self.regs.run.v = 0
        self.regs.do_loop.v = 0

        while self.regs.finished_or_ready.v == 0:
            pass

    def force_stop(self):
        self.regs.force_stop.v = 1
        selff.regs.force_stop.v = 0

    def dump(self):
        """ Dump contents of control registers. """
        return self.regs.dump()
