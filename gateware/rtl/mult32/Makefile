# Copyright 2024 (C) Peter McGoron, Adam Mooers
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

# Makefile for tests and hardware verification.

.PHONY: test clean codegen all

CPP_FILE=mult32.cpp
VERILOG=mult32.v

test: obj_dir/Vmult32
	obj_dir/Vmult32

clean:
	rm -rf obj_dir

obj_dir/Vmult32.mk:  ${VERILOG} ${CPP_FILE}
	verilator --cc --exe -Wall --trace --trace-fst \
		${VERILOG} ${CPP_FILE}

obj_dir/Vmult32: obj_dir/Vmult32.mk
	cd obj_dir && make -f Vmult32.mk
