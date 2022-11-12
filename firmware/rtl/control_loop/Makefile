# Makefile for tests and hardware verification.

COMMON_CPP = control_loop_math_implementation.cpp

COMMON= ${COMMON_CPP} control_loop_math_implementation.h

obj_dir/Vmul_const.mk: mul_const_sim.cpp mul_const.v boothmul.v intsat.v
	verilator --cc --exe -Wall --trace --trace-fst \
		--top-module mul_const \
		mul_const.v mul_const_sim.cpp

obj_dir/Vmul_const: obj_dir/Vmul_const.mk
	cd obj_dir && make -f Vmul_const.mk

SEC_PER_CYCLE_WID=15
CYCLE_COUNT_WID=18
UNSAT_WID=(${SEC_PER_CYCLE_WID} + ${CYCLE_COUNT_WID})
MAX_WID=48
DT_WID=$(shell echo $$((${UNSAT_WID} > ${MAX_WID} ? ${MAX_WID} : ${UNSAT_WID})))

obj_dir/Vcalculate_dt.mk: calculate_dt_sim.cpp calculate_dt.v ${COMMON}
	verilator --cc --exe -Wall --trace --trace-fst \
		--top-module calculate_dt \
		-GSEC_PER_CYCLE_WID=${SEC_PER_CYCLE_WID} \
		-GCYCLE_COUNT_WID=${CYCLE_COUNT_WID} \
		-CFLAGS -DDT_WID=${DT_WID} \
		calculate_dt.v calculate_dt_sim.cpp ${COMMON_CPP}
obj_dir/Vcalculate_dt: obj_dir/Vcalculate_dt.mk
	cd obj_dir && make -f Vcalculate_dt.mk

test: obj_dir/Vcalculate_dt
	obj_dir/Vcalculate_dt
