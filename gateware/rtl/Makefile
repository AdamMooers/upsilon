# Copyright 2023 (C) Peter McGoron
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

all: make_base make_spi make_control_loop

test:
	cd control_loop && make test
make_base:
	cd base && make codegen
make_spi:
	cd spi && make codegen
make_control_loop:
	cd control_loop && make codegen
make_waveform:
	cd waveform && make codegen
clean:
	cd base && make clean
	cd spi && make clean
	cd control_loop && make clean
	cd waveform && make clean
