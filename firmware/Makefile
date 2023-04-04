.PHONY: cpu clean

DEVICETREE_GEN_DIR=.

all: rtl_codegen build/digilent_arty/digilent_arty.bit overlay.dts overlay.cmake pin_io.h

rtl_codegen:
	cd rtl && make
build/digilent_arty/digilent_arty.bit: rtl_codegen soc.py
	python3 soc.py
clean:
	rm -rf build csr.json overlay.config overlay.dts pin_io.h
overlay.dts overlay.cmake: csr.json litex_json2dts_zephyr.py
	# NOTE: Broken in LiteX 2022.4.
	$(DEVICETREE_GEN_DIR)/litex_json2dts_zephyr.py --dts overlay.dts --config overlay.cmake csr.json

pin_io.h: csr.json generate_csr_locations.py
	python3 generate_csr_locations.py > pin_io.h
