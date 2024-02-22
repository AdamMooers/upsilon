# Copyright 2023-2024 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

def minbits(n):
    from math import log2, floor
    """ Return the amount of bits necessary to store n. """
    return floor(log2(n) + 1)

