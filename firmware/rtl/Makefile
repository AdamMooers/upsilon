all: make_base make_spi make_control_loop make_waveform

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
