import textwrap

class Descr:
    def __init__(self, name, blen, rwperm, num, descr):
        """
        :param name: Name of the pin without numerical suffix.
        :param blen: Bit length of the pin.
        :param doc: Restructured text documentation of the register.
        :param num: The amount of registers of the same type.
        :param read_only: A string that must be either "read-only" or "write-write".
        """
        self.name = name
        self.blen = blen
        self.doc = textwrap.dedent(descr)
        self.num = num
        self.rwperm = rwperm

    @classmethod
    def from_dict(cls, jsdict, name):
        return cls(name, jsdict[name]["len"], jsdict[name]["ro"], jsdict[name]["num"], jsdict[name]["doc"])
    def store_to_dict(self, d):
        d[self.name] = {
                "len": self.blen,
                "doc": self.doc,
                "num": self.num,
                "ro": ro
                }

registers = [
        Descr("adc_sel", 3, "read-write", 8, """\
                Select which on-FPGA SPI master controls the ADC.

                Valid settings:

                * ``0``: ADC is controlled by MMIO registers.
                * ``0b10``: ADC is controlled by MMIO registers, but conversion is
                   disabled. This is used to flush output from an out-of-sync ADC.
                * ``0b100``: ADC 0 only. ADC is controlled by control loop."""),
        Descr("adc_finished", 1, "read-only", 8, """\
                Signals that an ADC master has finished an SPI cycle.

                Values:

                * ``0``: MMIO master is either not armed or currently in a
                  SPI transfer.
                * ``1``: MMIO master has finished.

                This flag is on only when ``adc_arm`` is high. The flag does not
                mean that data has been received successfully, only that the master
                has finished it's SPI transfer."""),
        Descr("adc_arm", 1, "read-write", 8, """\
                Start a DAC master SPI transfer.

                If ``adc_arm`` is raised from and the master is currently not in a SPI
                transfer, the SPI master will start an SPI transfer and write data
                into ``adc_recv_buf``.

                If ``adc_arm`` is raised while the master is in an SPI transfer,
                nothing changes.

                If ``adc_arm`` is lowered while the master is in an SPI transfer,
                nothing changes. The SPI cycle will continue to execute and it will
                continue to write data to ``adc_recv_buf``.

                If the SPI transfer finishes and ``adc_arm`` is still set to
                1, then ``adc_finished`` is raised to 1. If ``adc_arm`` is lowered
                in this state, then ``adc_finished`` is lowered.

                Linear Technologies ADCs must not have their SPI transfers
                interrupted. The transfer can be interrupted by

                1. Interrupt the signal physically (i.e. pulling out cable connecting
                   the FPGA to the ADC)
                2. Reset of the ADC master
                3. Reset of the FPGA
                4. Switching ``adc_sel`` to the control loop

                If the ADC is interrupted then it will be in an unknown transfer
                state. To recover from an unknown transfer state, set ``adc_sel``
                to ``0b10`` and run a SPI transfer cycle. This will run the SPI
                clock and flush the ADC buffer. The only other way is to power-cycle
                the ADC.

                If ``adc_sel`` is not set to 0 then the transfer will proceed
                as normal, but no data will be received from the ADC."""),
        Descr("adc_recv_buf", 18, "read-only", 8, """\
                ADC Master receive buffer.

                This buffer is stable if there is no ADC transfer caused by ``adc_arm``
                is in process.

                This register only changes if an SPI transfer is triggered by the MMIO
                registers. SPI transfers by other masters will not affect this register.
                buffer."""),

        Descr("dac_sel", 2, "read-write", 8, """\
                Select which on-FPGA SPI master controls the DAC.

                Valid settings:

                * ``0``: DAC is controlled by MMIO registers.
                * ``0b10``: DAC 0 only. DAC is controlled by control loop."""),
        Descr("dac_finished", 1, "read-only", 8, """\
                Signals that the DAC master has finished transmitting data.

                Values:

                * ``0``: MMIO master is either not armed or currently in a
                  SPI transfer.
                * ``1``: MMIO master has finished transmitting.

                This flag is on only when ``dac_arm`` is high. The flag does not
                mean that data has been received or transmitted successfully, only that
                the master has finished it's SPI transfer."""),
        Descr("dac_arm", 1, "read-write", 8, """\
                Start a DAC master SPI transfer.

                If ``dac_arm`` is raised from and the master is currently not in a SPI
                transfer, the SPI master reads from the ``dac_send_buf`` register and sends
                it over the wire to the DAC, while reading data from the DAC into
                ``dac_recv_buf``.

                If ``dac_arm`` is raised while the master is in an SPI transfer,
                nothing changes.

                If ``dac_arm`` is lowered while the master is in an SPI transfer,
                nothing changes. The SPI cycle will continue to execute and it will
                continue to write data to ``dac_recv_buf``.

                If the SPI transfer finishes and ``dac_arm`` is still set to
                1, then ``dac_finished`` is raised to 1. If ``dac_arm`` is lowered
                in this state, then ``dac_finished`` is lowered.

                Analog Devices DACs can have their SPI transfers interrupted without
                issue. However it is currently not possible to interrupt SPI transfers
                in software without resetting the entire device.

                If ``dac_sel`` is set to another master then the transfer will proceed
                as normal, but no data will be sent to or received from the DAC."""),
        Descr("dac_recv_buf", 24, "read-only", 8, """\
                DAC master receive buffer.

                This buffer is stable if there is no DAC transfer caused by ``dac_arm``
                is in process.

                This register only changes if an SPI transfer is triggered by the MMIO
                registers. SPI transfers by other masters will not affect this register.
                buffer."""),
        Descr("dac_send_buf", 24, "read-write", 8, """\
                DAC master send buffer.

                Fill this buffer with a 24 bit Analog Devices DAC command. Updating
                this buffer does not start an SPI transfer. To send data to the DAC,
                fill this buffer and raise ``dac_arm``.

                The DAC copies this buffer into an internal register when writing data.
                Modifying this buffer during a transfer does not disrupt an in-process
                transfer."""),

        Descr("cl_assert_change", 1, "read-write", 1, """\
                Flush parameter changes to control loop.

                When this bit is raised from low to high, this signals the control
                loop that it should read in new values from the MMIO registers.
                While the bit is raised high, the control loop will read the constants
                at most once.

                When this bit is raised from high to low before ``cl_change_made``
                is asserted by the control loop, nothing happens."""),
        Descr("cl_change_made", 1, "read-only", 1, """\
                Signal from the control loop that the parameters have been applied.

                This signal goes high only while ``cl_assert_change`` is high. No
                change will be applied afterwards while both are high."""),

        Descr("cl_in_loop", 1, "read-only", 1, """\
                This bit is high if the control loop is running."""),
        Descr("cl_run_loop_in", 1, "read-write", 1, """\
                Set this bit high to start the control loop."""),
        Descr("cl_setpt_in", 18, "read-write", 1, """\
                Setpoint of the control loop.

                This is a twos-complement number in ADC units.

                This is a parameter: see ``cl_assert_change``."""),
        Descr("cl_P_in", 64, "read-write", 1, """\
                Proportional parameter of the control loop.

                This is a twos-complement fixed point number with 21 whole
                bits and 43 fractional bits. This is applied to the error
                in DAC units.

                This is a parameter: see ``cl_assert_change``."""),
        Descr("cl_I_in", 64, "read-write", 1, """\
                Integral parameter of the control loop.

                This is a twos-complement fixed point number with 21 whole
                bits and 43 fractional bits. This is applied to the error
                in DAC units.

                This is a parameter: see ``cl_assert_change``."""),
        Descr("cl_delay_in", 16, "read-write", 1, """\
                Delay parameter of the loop.

                This is an unsigned number denoting the number of cycles
                the loop should wait between loop executions.

                This is a parameter: see ``cl_assert_change``."""),

        Descr("cl_cycle_count", 18, "read-only", 1, """\
                Delay parameter of the loop.

                This is an unsigned number denoting the number of cycles
                the loop should wait between loop executions."""),
        Descr("cl_z_pos", 20, "read-only", 1, """\
                Control loop DAC Z position.
                """),
        Descr("cl_z_measured", 18, "read-only", 1, """\
                Control loop ADC Z position.
                """),
        ]
