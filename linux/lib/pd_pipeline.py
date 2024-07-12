from registers import *

class PDPipeline(Immutable):
    def __init__(self, pd_pipeline_pi, regs):
        super().__init__()

        self.pd_pipeline_pi = pd_pipeline_pi
        self.regs = regs

        self.make_immutable()

    def run_pd_pipeline(self, kp, ki, setpoint, actual, integral_input):
        """
        A simple helper function which loads the inputs and returns the outputs
        to document how the pipeline is used. All values are signed (refer to the
        individual register size for 2's complement conversion if necessary)

        Note that the pipeline has an integral input and output. This allows
        the pipeline to be entirely stateless, simplifying the hardware design.
        Whenever a new iteration of the loop is to be run, the output must be
        copied back to the input.

        :param kp: kp parameter of the pd control loop
        :param ki: ki parameter of the pd control loop
        :param setpoint: the desired value of the pd control input
        :param actual: the current value of the pd control input
        :param integral_input: the current integral value
        :return: the output variables of the pipeline
        """
        if self.pd_pipeline_pi.v != 0:
            if not force_control:
                raise Exception("PD Pipeline is not controlled by master")
            self.pd_pipeline_pi.v = 0

        self.regs.kp.v = kp
        self.regs.ki.v = ki
        self.regs.setpoint.v = setpoint
        self.regs.actual.v = actual
        self.regs.integral_input.v = integral_input

        # Now we need to wait 4 clock cycles for the registers to propagate
        # The below loop is not necessary since micropython is slow but helps
        # document the quirk
        for i in range(0,4):
            pass

        return {
            'integral_result':self.regs.integral_result.v,
            'pd_result':self.regs.pd_result.v}

    def dump(self):
        """ Dump contents of control registers. """
        return self.regs.dump()
