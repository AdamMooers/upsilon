from registers import *

class Waveform(Immutable):
    def __init__(self, ram, ram_pi, regs):
        super().__init__()
        self.ram = ram
        self.ram_pi = ram_pi
        self.regs = regs

        self.make_immutable()

    def run_waveform(self, wf, timer, timer_spacing, do_loop):
        self.regs.run = 0
        self.regs.do_loop = 0

        while self.regs.finished_or_ready == 0:
            pass

        self.ram_pi.v = 0
        self.ram.load(wf)

        self.regs.wform_width.v = len(wf)
        self.regs.timer.v = timer
        self.regs.timer_spacing.v = timer_spacing

        self.regs.do_loop.v = do_loop
        self.ram_pi.v = 1
        self.regs.run.v = 1
