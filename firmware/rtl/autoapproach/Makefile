# Makefile for tests and hardware verification.

.PHONY: test clean

test: obj_dir/Vbram_interface_sim

bram_SRC= bram_interface_sim.v dma_sim.v bram_interface.v bram_interface_sim.cpp

obj_dir/Vbram_interface_sim.mk: $(bram_SRC)
	verilator --cc --exe -Wall --trace --trace-fst \
		-CFLAGS -DWORD_AMNT=2048 \
		-CFLAGS -DRAM_WID=32 \
		$(bram_SRC)
obj_dir/Vbram_interface_sim: obj_dir/Vbram_interface_sim.mk
	cd obj_dir && make -f Vbram_interface_sim.mk
	./obj_dir/Vbram_interface_sim

clean:
	rm -rf obj_dir/
