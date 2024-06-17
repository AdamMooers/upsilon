# Copyright 2024 (C) Adam Mooers
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

""" 
This is a simple wrapper for Linear Technolgies ADCs (such as the LTC2336) 
intended to be used on the Upsilon main CPU.
"""

class LTC_ADC():
    def __init__(self,
                spi_master,
                input_range = 10.24,
                single_ended = True,
                adc_bits = 18):
        """
        :param spi_master: The SPI master which controls the ADC
        :param input_range: The allowed differential input range, in
            volts, for the ADC (see the ADC reference section of the
            datasheet). By default, the value for the internal ADC
            reference is provided
        :param single_ended: indicates if the ADC is configured for
            single-end inputs for differential inputs. This is necessary
            for calculating the input voltage since the negative input
            is the inverted positive input in single-ended setups.
        :adc_bits: the number of bits in the ADC
        """
        self._spi_master = spi_master
        self._input_range = input_range
        self._single_ended = single_ended
        self._adc_bits = adc_bits

        self._volts_per_lsb = 10.24/pow(2,adc_bits)

        if single_ended:
            self._volts_per_lsb *= 2.0

        '''
        Pre-calculated masks to make bit operations on ADC data
        more legible. These are calculated from the the bit width
        of the ADC during initialization.
        '''
        self._adc_sign_bit_mask = 1 << (adc_bits - 1)
        self._adc_magnitude_bit_mask = self._adc_sign_bit_mask - 1

    def __sign_extend(self, v):
        """
        :param v: the value to sign-extend
        :return: the value sign-extended
        """
        return (v&self._adc_magnitude_bit_mask) - (v&self._adc_sign_bit_mask)

    def read_voltage(self, conv_to_volts=True):
        """
        Initiates a conversion cycle, reads the raw (LSB) voltage from 
        the ADC, performs sign-extension on the 2's complement result.
        :conv_to_volts: If true, the result is converted to volts, taking
            into account whether the input is single-ended. Otherwise, the
            voltage is returned in raw LSB units.
        :return: the voltage in the desired units
        """
        voltage_lsb = self.__sign_extend(self._spi_master.send(0))
        return voltage_lsb*_volts_per_lsb if conv_to_volts else voltage_lsb