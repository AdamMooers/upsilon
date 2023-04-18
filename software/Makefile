unexport CXXFLAGS
unexport CFLAGS
unexport CPPFLAGS
unexport LDFLAGS

# TODO: Number of processors
build/zephyr/zephyr.bin: build/Makefile
	cd build && make -j7
build/Makefile: ../creole/creole.c src/*.c ../firmware/overlay.dts ../firmware/pin_io.c prj.conf CMakeLists.txt
	mkdir -p build
	cd build && cmake ..
clean:
	rm -rf build
