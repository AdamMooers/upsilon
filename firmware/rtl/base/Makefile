.PHONY: lint
include ../common.makefile
base.v: base.v.m4
lint: base.v
	verilator --lint-only base.v -I../spi -I../control_loop -I../waveform
