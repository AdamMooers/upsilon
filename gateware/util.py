# Copyright 2023-2024 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

def minbits(n):
    """ Return the amount of bits necessary to store n. """
    from math import log2, floor
    return floor(log2(n) + 1)

def round_up_to_pow_2(n):
    """ Round up to nearest power of 2 if not already a power of 2. """
    assert n > 0
    # If n is a power of 2, then n - 1 has a smaller bit length than n.
    # If n is not a power of 2, then n - 1 has the same bit length.
    l = (n - 1).bit_length()
    return  1 << l

def round_up_to_word(n):
    """ Round up to 8, 16, or 32. """
    if n <= 8:
        return 8
    if n <= 16:
        return 16
    if n <= 32:
        return 32
    raise Exception(f"{n} must be less than or equal to 32")
