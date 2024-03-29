# Copyright 2023 (C) Peter McGoron
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

# Makefile for tests and hardware verification.

include ../common.makefile

.PHONY: test clean codegen

all: test codegen
test: obj_dir/Vbram_interface_sim obj_dir/Vwaveform_sim
CODEGEN_FILES=bram_interface_preprocessed.v waveform_preprocessed.v

codegen: ${CODEGEN_FILES}

bram_SRC= bram_interface_sim.v dma_sim.v bram_interface.v bram_interface_sim.cpp

obj_dir/Vbram_interface_sim.mk: $(bram_SRC)
	verilator --cc --exe -Wall --trace --trace-fst \
		-CFLAGS -DWORD_AMNT=2048 \
		-CFLAGS -DRAM_WID=32 \
		$(bram_SRC)
obj_dir/Vbram_interface_sim: obj_dir/Vbram_interface_sim.mk
	cd obj_dir && make -f Vbram_interface_sim.mk
	./obj_dir/Vbram_interface_sim

waveform_src = waveform_sim.v waveform.v bram_interface.v dma_sim.v waveform_sim.cpp ../spi/spi_slave_no_write.v
obj_dir/Vwaveform_sim.mk: $(waveform_src)
	verilator --cc --exe -Wall --trace --trace-fst -I../spi \
		-CFLAGS -DWORD_AMNT=2048 \
		-CFLAGS -DRAM_WID=32 \
		-DVERILATOR_SIMULATION \
		$(waveform_src)
obj_dir/Vwaveform_sim: obj_dir/Vwaveform_sim.mk $(waveform_src)
	cd obj_dir && make -f Vwaveform_sim.mk
	./obj_dir/Vwaveform_sim

clean:
	rm -rf obj_dir/ ${CODEGEN_FILES}
