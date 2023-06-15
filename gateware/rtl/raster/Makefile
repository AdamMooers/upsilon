# Copyright 2023 (C) Peter McGoron
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.
#
# Makefile for tests and hardware verification.

.PHONY: test clean


test: obj_dir/Vram_fifo obj_dir/Vram_shim obj_dir/Vraster_sim

RAM_FIFO_SRC= ram_fifo.v ram_fifo_dual_port.v ram_fifo_sim.cpp
obj_dir/Vram_fifo.mk: ${RAM_FIFO_SRC}
	verilator --cc --exe -Wall --trace --trace-fst \
		${RAM_FIFO_SRC}
obj_dir/Vram_fifo: obj_dir/Vram_fifo.mk
	cd obj_dir && make -f Vram_fifo.mk
	@./obj_dir/Vram_fifo && echo 'ram_fifo successful'

RAM_SHIM_SRC= ram_shim.v ram_fifo.v ram_fifo_dual_port.v  ram_shim_sim.cpp
obj_dir/Vram_shim.mk: ${RAM_SHIM_SRC} ram_shim_cmds.vh ram_shim_cmds.h
	verilator --cc --exe -Wall --trace --trace-fst \
		-DRAM_SHIM_DEBUG \
		${RAM_SHIM_SRC}
obj_dir/Vram_shim: obj_dir/Vram_shim.mk ram_shim_sim.cpp
	cd obj_dir && make -f Vram_shim.mk
	@./obj_dir/Vram_shim && echo 'ram_shim successful'

RASTER_SIM_SRC = raster_sim.v raster.v ram_shim.v ram_fifo.v ram_fifo_dual_port.v raster_sim.cpp

obj_dir/Vraster_sim.mk: ${RASTER_SIM_SRC} raster_cmds.vh raster_cmds.h ram_shim_cmds.vh ram_shim_cmds.h
	verilator --cc --exe -Wall --trace --trace-fst -CFLAGS -Wall \
		${RASTER_SIM_SRC}
obj_dir/Vraster_sim: obj_dir/Vraster_sim.mk raster_sim.cpp
	cd obj_dir && make -f Vraster_sim.mk
	@./obj_dir/Vraster_sim && echo 'raster successful'

####### Codegen ########

ram_shim_cmds.h: ram_shim_cmds.vh
	echo '#pragma once' > ram_shim_cmds.h
	sed 's/`define/#define/g; s/`//g' ram_shim_cmds.vh >> ram_shim_cmds.h
raster_cmds.h: raster_cmds.vh
	echo '#pragma once' > raster_cmds.h
	sed 's/`define/#define/g; s/`//g' raster_cmds.vh >> raster_cmds.h

clean:
	rm -rf obj_dir
	rm -f *.vcd ram_shim_cmds.h
