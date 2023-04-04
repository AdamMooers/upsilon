build/zephyr/zephyr.bin: src/*.c ../firmware/overlay.dts ../firmware/pin_io.h
	mkdir -p build
	cd build && CMAKE_BINARY_DIR=$$(pwd) cmake $$(cat ../../firmware/overlay.config) -DDTC_OVERLAY_FILE=../firmware/overlay.dts -DBOARD=litex_vexriscv -DEXTRA_CFLAGS=-Wfatal-errors .. && make
clean:
	rm -rf build
