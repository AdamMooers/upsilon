# Copyright 2023 (C) Peter McGoron
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

# Generate verilog from m4 file
#m4 -P --synclines $< | awk -v filename=$< '/^#line/ {printf("`line %d %s 0\n", $$2, filename); next} {print}' > $@
# NOTE: f4pga yosys does not support `line directives. Use above for debug.
%.v: %.v.m4
	m4 -P $< > $@
%_preprocessed.v: %.v
	verilator -P -E $< > $@
