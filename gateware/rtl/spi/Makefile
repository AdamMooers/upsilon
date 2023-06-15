# Copyright 2023 (C) Peter McGoron
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.
# Makefile for tests and hardware verification.

.PHONY: test clean codegen
include ../common.makefile

all: test codegen
test: obj_dir/Vspi_switch

CODEGEN_FILES= spi_master_ss_preprocessed.v spi_master_preprocessed.v \
	       spi_master_no_write_preprocessed.v \
	       spi_master_no_read_preprocessed.v \
               spi_master_ss_no_read_preprocessed.v \
               spi_master_ss_no_write_preprocessed.v spi_switch_preprocessed.v

codegen: ${CODEGEN_FILES}

SRC= spi_switch.v spi_switch_sim.cpp
obj_dir/Vspi_switch.mk: $(SRC)
	verilator --cc --exe -Wall \
		$(SRC)
obj_dir/Vspi_switch: obj_dir/Vspi_switch.mk $(SRC)
	cd obj_dir && make -f Vspi_switch.mk
	./obj_dir/Vspi_switch

clean:
	rm -rf obj_dir/ ${CODEGEN_FILES}
