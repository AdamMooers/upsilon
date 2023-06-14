The continuous form of a PI loop is

    A(t) = P e(t) + I ∫e(t')dt'

where e(t) is the error (setpoint - measured), and the integral goes
from 0 to the current time 't'.

In digital systems the integral must be approximated.  The normal way
of doing this is a first-order approximation of the derivative of
A(t).

    dA(t)/dt = P de(t)/dt + Ie(t)
    A(t_n) - A(t_{n-1}) ≅ P (e(t_n) - e(t_{n-1})) + Ie(t_n)Δt
    A(t_n) ≅ A(t_{n-1}) + e(t_n)(P + IΔt) - Pe(t_{n-1})

Using α = P + IΔt, and denoting A(t_{n-1}) as A_p,

    A ≅ A_p + αe - Pe_p.

The formula above is what this module implements.  This way, the
controller only has to store two values between each run of the loop:
the previous error and the previous output.  This also reduces the
amount of (redundant) computations the loop must execute each
iteration.

Calculating α requires knowing the precise timing of each control loop
cycle, which in turn requires knowing the ADC and DAC timings.  This
is done outside the Verilog code.  and can be calculated from
simulating one iteration of the control loop.

# Fixed Point Integers

A regular number is stored in decimal: 123056.
This is equal to

    6*10^0 + 5*10^1 + 0*10^2 + 3*10^3 + 2*10^4 + 1*10^5.

A whole binary number is only ones and zeros: 1101, and is equal to

    1*2^0 + 0*2^1 + 1*2^2 + 1*2^3.

Fixed-point integers shift the exponent of each number by a fixed
amount.  For instance, 123.056 is

    6*10^-3 + 5*10^-2 + 0*10^-1 + 3*10^0 + 2*10^1 + 1*10^2.

Similarly, the fixed point binary integer 11.01 is

    1*2^-2 + 0*2^-1 + 1*2^0 + 1*2^1.

To a computer, a whole binary number and a fixed point binary number
are stored in exactly the same way: no decimal point is stored.  It is
only the interpretation of the data that changes.

Fixed point numbers are denoted WHOLE.FRAC or [WHOLE].[FRAC], where
WHOLE is the amount of whole number bits (including sign) and FRAC is
the amount of fractional bits (2^-1, 2^-2, etc.).

The rules for how many digits the output has given an input is the
same for fixed point binary and regular decimals.

Addition: W1.F1 + W2.F2 = [max(W1,W2)+1].[max(F1,F2)]

Multiplication: W1.F1W2.F2 = [W1+W2].[F1+F2]


When multiplying two fixed point integers, where the decimal points
do not correspond to the same points, then:

* the output has the same number of bits as a normal addition/multiplication
* for multiplication, the LSB is interpreted as position `m+n`, where
  `m` is the interpretation of the LSB of the first integer and `n` as
  the LSB of the second.

# Hardware

The DAC is *not* ramped in software: the updated value is directly written
without smoothing the change. In the setup for which this code was designed
for, this is not a problem because the DAC is connected to an amplifier which
cannot respond that quickly
and will smooth out changes itself. For your design, you may need to use
code found in `firmware/rtl/spi/ramp.v`.
