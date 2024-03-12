.PHONY: all

.SUFFIXES: .mpy .py

MPY=picorv32.mpy registers.mpy spi.mpy  waveform.mpy mmio.mpy

all: $(MPY)
.py.mpy:
	. ../build/venv/bin/activate && mpy-cross $<
