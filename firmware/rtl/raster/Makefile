# Makefile for tests and hardware verification.

.PHONY: test clean


test: obj_dir/Vram_fifo obj_dir/Vram_shim

RAM_FIFO_SRC= ram_fifo.v ram_fifo_dual_port.v ram_fifo_sim.cpp
obj_dir/Vram_fifo.mk: ${RAM_FIFO_SRC}
	verilator --cc --exe -Wall --trace --trace-fst \
		${RAM_FIFO_SRC}
obj_dir/Vram_fifo: obj_dir/Vram_fifo.mk
	cd obj_dir && make -f Vram_fifo.mk
	@./obj_dir/Vram_fifo && echo 'Vram_fifo successful'

RAM_SHIM_SRC= ram_shim.v ram_fifo.v ram_fifo_dual_port.v  ram_shim_sim.cpp
obj_dir/Vram_shim.mk: ${RAM_SHIM_SRC} ram_shim_cmds.vh ram_shim_cmds.h
	verilator --cc --exe -Wall --trace --trace-fst \
		-DRAM_SHIM_DEBUG \
		${RAM_SHIM_SRC}
obj_dir/Vram_shim: obj_dir/Vram_shim.mk ram_shim_sim.cpp
	cd obj_dir && make -f Vram_shim.mk
	@./obj_dir/Vram_shim && echo 'Vram_shim successful'

####### Codegen ########

ram_shim_cmds.h: ram_shim_cmds.vh
	echo '#pragma once' > ram_shim_cmds.h
	sed 's/`define/#define/g; s/`//g' ram_shim_cmds.vh >> ram_shim_cmds.h
