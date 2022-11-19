# Makefile for tests and hardware verification.

.PHONY: test clean
COMMON_CPP = control_loop_math_implementation.cpp
COMMON= ${COMMON_CPP} control_loop_math_implementation.h

CONSTS_FRAC=43
E_WID=21

test: obj_dir/Vcontrol_loop_math
	obj_dir/Vcontrol_loop_math
clean:
	rm -rf obj_dir *.fst

obj_dir/Vcontrol_loop_math.mk: control_loop_math_sim.cpp ${COMMON} \
                               control_loop_math.v
	verilator --cc --exe -Wall --trace --trace-fst \
		--top-module control_loop_math \
		-GCONSTS_FRAC=${CONSTS_FRAC} -DDEBUG_CONTROL_LOOP_MATH \
		-CFLAGS -DCONSTS_FRAC=${CONSTS_FRAC} \
		-CFLAGS -DE_WID=${E_WID} \
		control_loop_math.v control_loop_math_sim.cpp ${COMMON_CPP}

obj_dir/Vcontrol_loop_math: obj_dir/Vcontrol_loop_math.mk
	cd obj_dir && make -f Vcontrol_loop_math.mk

