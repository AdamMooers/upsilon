# Copyright 2024 (C) Peter McGoron
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

# Makefile for tests and hardware verification.

.PHONY: test clean codegen all

CPP_FILE=waveform.cpp
VERILOG=waveform_sim.v waveform.v

test: obj_dir/Vwaveform_sim
	obj_dir/Vwaveform_sim
clean:
	rm -rf obj_dir
obj_dir/Vwaveform_sim.mk:  ${VERILOG} ${CPP_FILE}
	verilator --cc --exe -Wall --trace --trace-fst \
		${VERILOG} ${CPP_FILE}

obj_dir/Vwaveform_sim: obj_dir/Vwaveform_sim.mk
	cd obj_dir && make -f Vwaveform_sim.mk
