# Functions for converting to and from fixed point in Python.
from math import log10, floor
from decimal import *

def string_to_fixed_point(s, fracnum):
	l = s.split('.')
	if len(l) == 1:
		return int(s) << fracnum
	elif len(l) != 2:
		return None

	dec = 10
	frac = 0

	frac_decimal = Decimal(f'0.{l[1]}')
	# get the smallest power of ten higher then frac_decimal
	frac = 0

	# Example:
	# 0.4567 = 0.abcdefgh...
	# where abcdefgh are binary digits.
	# multiply both sides by two:
	# 0.9134 = a.bcdefgh ...
	# therefore a = 0. Then remove the most significant digit.
	# Then multiply by 2 again. Then
	# 1.8268 = b.cdefgh ...
	# therefore b = 1. Then take 8268, and so on.
	for i in range(0,fracnum):
		frac_decimal = frac_decimal * 2	
		div = floor(frac_decimal)

		frac = div | (frac << 1)
		frac_decimal = frac_decimal - div

	whole = int(l[0])
	if whole < 0:
		return -((-whole) << fracnum | frac)
	else:
		return whole << fracnum | frac

def fixed_point_to_string(fxp, fracnum):
	whole = str(fxp >> fracnum)
	mask = (1 << fracnum) - 1
	fracbit = fxp & mask
	n = 1
	frac = ""

	if fracbit == 0:
		return whole

	# The same method can be applied backwards.
	#    0.1110101 = 0.abcdefgh ...
	# where abcdefgh... are decimal digits. Then multiply by 10 to
	# get
	# 1001.0010010 = a.bcdefgh ...
	# therefore a = 0b1001 = 9. Then use a bitmask to get
	#    0.0010010 = 0.bcdefgh ...
	# etc.

	for i in range(0, fracnum):
		fracbit = fracbit * 10
		frac = frac + str(fracbit >> fracnum)
		fracbit = fracbit & mask
	return whole + "." + frac
