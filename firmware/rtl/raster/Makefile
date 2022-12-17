# Makefile for tests and hardware verification.

.PHONY: test clean

RAM_FIFO_SRC= ram_fifo.v ram_fifo_sim.cpp FIFO36E1.v

obj_dir/Vram_fifo.mk:
	verilator --cc --exe -Wall --trace --trace-fst \
		${RAM_FIFO_SRC}
obj_dir/Vram_fifo: obj_dir/Vram_fifo.mk
	cd obj_dir && make -f Vram_fifo.mk
test: obj_dir/Vram_fifo
	./obj_dir/Vram_fifo
