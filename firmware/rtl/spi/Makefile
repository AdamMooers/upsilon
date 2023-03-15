# Makefile for tests and hardware verification.

.PHONY: test clean codegen

all: test codegen
test: obj_dir/Vspi_switch

codegen: spi_master_ss_preprocessed.v spi_master_preprocessed.v \
         spi_master_ss_no_write_preprocessed.v spi_switch_preprocessed.v

%_preprocessed.v: %.v
	verilator -E $< > $@

SRC= spi_switch.v spi_switch_sim.cpp
obj_dir/Vspi_switch.mk: $(SRC)
	verilator --cc --exe -Wall \
		$(SRC)
obj_dir/Vspi_switch: obj_dir/Vspi_switch.mk $(SRC)
	cd obj_dir && make -f Vspi_switch.mk
	./obj_dir/Vspi_switch

clean:
	rm -rf obj_dir/
