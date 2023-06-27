"""
Copyright 2023 (C) Peter McGoron

This file is a part of Upsilon, a free and open source software project.
For license terms, refer to the files in `doc/copying` in the Upsilon
source distribution.
"""

import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import sys
import signal
from util import *

Pval = string_to_fixed_point('0.0006', 43)
Ival = string_to_fixed_point('0.01', 43)

out = connect_execute("control_loop_test.py", Pval, Ival, 10000, 100)

################
# Script Handler
################

for line in out.stdout:
    print(line)
