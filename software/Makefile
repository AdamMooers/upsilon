kernel: src/*.c ../firmware/overlay.dts ../firmware/io_pins.h
	mkdir -p build
	cd build && cmake $$(cat ../../firmware/overlay.config) -DDTC_OVERLAY_FILE=../firmware/overlay.dts -DBOARD=litex_vexriscv .. && make -j7
clean:
	rm -rf build
