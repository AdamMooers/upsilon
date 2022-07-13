.PHONY: cpu clean

DEVICETREE_GEN_DIR=.

all: build/digilent_arty/digilent_arty.bit overlay.dts overlay.config pin_io.h
build/digilent_arty/digilent_arty.bit: soc.py
	python3 soc.py
clean:
	rm -rf build csr.json overlay.config overlay.dts pin_io.h
overlay.dts overlay.config: csr.json litex_json2dts_zephyr.py
	# NOTE: Broken in LiteX 2022.4.
	$(DEVICETREE_GEN_DIR)/litex_json2dts_zephyr.py --dts overlay.dts --config overlay.config csr.json

pin_io.h: csr.json generate_csr_locations.py
	python3 generate_csr_locations.py > pin_io.h
