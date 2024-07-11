# Copyright 2024 (C) Peter McGoron, Adam Mooers
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

# Makefile for tests and hardware verification.

.PHONY: test clean codegen all

CPP_FILE=pd_pipeline.cpp
VERILOG=pd_pipeline.v

test: obj_dir/pd_pipeline
	obj_dir/pd_pipeline

clean:
	rm -rf obj_dir

obj_dir/Vpd_pipeline.mk:  ${VERILOG} ${CPP_FILE}
	verilator --cc --exe -Wall --trace --trace-fst \
		${VERILOG} ${CPP_FILE}

obj_dir/Vpd_pipeline: obj_dir/Vpd_pipeline.mk
	cd obj_dir && make -f Vpd_pipeline.mk
