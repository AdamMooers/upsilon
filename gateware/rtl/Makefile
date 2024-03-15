# Copyright 2023 (C) Peter McGoron
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.

all: make_spi

make_spi:
	cd spi && make codegen

test_waveform:
	cd waveform && make test

test: test_waveform

clean:
	cd waveform && make clean

#make_bram:
#	cd bram && make codegen
#clean:
#	cd bram && make clean
