.PHONY: lint
include ../common.makefile

codegen: base.v
base.v: base.v.m4
lint: base.v
	verilator --lint-only base.v -I../spi -I../control_loop -I../waveform
clean:
	rm base.v
