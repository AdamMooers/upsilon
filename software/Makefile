unexport CXXFLAGS
unexport CFLAGS
unexport CPPFLAGS
unexport LDFLAGS

build/zephyr/zephyr.bin: build/Makefile
	cd build && make -j7
build/Makefile: ../creole/creole.c src/*.c ../firmware/overlay.dts ../firmware/pin_io.h
	mkdir -p build
	cd build && cmake ..
clean:
	rm -rf build
