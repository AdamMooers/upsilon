# Makefile for tests and hardware verification.

.PHONY: test clean codegen all

all: test codegen

####### Tests ########

COMMON_CPP = control_loop_math_implementation.cpp
COMMON= ${COMMON_CPP} control_loop_math_implementation.h
control_loop_math_verilog = control_loop_math.v boothmul.v intsat.v sign_extend.v

CONSTS_FRAC=43
E_WID=21

test: obj_dir/Vcontrol_loop_sim_top obj_dir/Vcontrol_loop_math
	# obj_dir/Vcontrol_loop_math

obj_dir/Vcontrol_loop_math.mk: control_loop_math_sim.cpp ${COMMON} \
                               ${control_loop_math_verilog}
	verilator --cc --exe -Wall --trace --trace-fst \
		--top-module control_loop_math \
		-GCONSTS_FRAC=${CONSTS_FRAC} -DDEBUG_CONTROL_LOOP_MATH \
		-CFLAGS -DCONSTS_FRAC=${CONSTS_FRAC} \
		-CFLAGS -DE_WID=${E_WID} \
		control_loop_math.v control_loop_math_sim.cpp ${COMMON_CPP}

obj_dir/Vcontrol_loop_math: obj_dir/Vcontrol_loop_math.mk
	cd obj_dir && make -f Vcontrol_loop_math.mk

obj_dir/Vcontrol_loop_sim_top.mk: control_loop_sim.cpp ${COMMON} \
                          adc_sim.v dac_sim.v \
                          ../spi/spi_master_ss.v \
                          ../spi/spi_slave_no_write.v \
                          control_loop_sim_top.v control_loop_sim_top.v \
                          control_loop_cmds.vh control_loop.v \
                          ${control_loop_math_verilog}
	verilator --cc --exe -Wall --trace --trace-fst \
		--top-module control_loop_sim_top \
		-GCONSTS_FRAC=${CONSTS_FRAC} \
		-CFLAGS -DCONSTS_FRAC=${CONSTS_FRAC} \
		-CFLAGS -DE_WID=${E_WID} -I../spi \
		control_loop_sim_top.v control_loop.v control_loop_sim.cpp \
		${COMMON_CPP} adc_sim.v dac_sim.v ../spi/spi_master_ss.v \
		../spi/spi_slave_no_read.v ../spi/spi_slave.v
obj_dir/Vcontrol_loop_sim_top: obj_dir/Vcontrol_loop_sim_top.mk control_loop_cmds.h
	cd obj_dir && make -f Vcontrol_loop_sim_top.mk

####### Codegen ########

include ../common.makefile
CODEGEN_FILES=control_loop_cmds.h boothmul.v control_loop_math.v control_loop.v control_loop_cmds.vh
codegen: ${CODEGEN_FILES}
control_loop_cmds.vh: control_loop_cmds.m4
	m4 -P control_loop_cmds.vh.m4  > control_loop_cmds.vh
control_loop_cmds.h: control_loop_cmds.m4
	echo '#pragma once' > control_loop_cmds.h
	m4 -P control_loop_cmds.h.m4 >> control_loop_cmds.h

clean:
	rm -rf obj_dir *.fst ${CODEGEN_FILES}
