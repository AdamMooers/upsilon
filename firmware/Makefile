.PHONY: cpu clean rtl_codegen

DEVICETREE_GEN_DIR=.

all: rtl_codegen build/digilent_arty/digilent_arty.bit arty.dtb pin_io.c

rtl_codegen:
	cd rtl && make
csr.json build/digilent_arty/digilent_arty.bit: soc.py
	TFTP_SERVER_PORT=6969 python3 soc.py
clean:
	rm -rf build csr.json overlay.config overlay.dts pin_io.h arty.dts arty.dtb
	cd rtl && make clean

arty.dts: csr.json
	litex_json2dts_linux csr.json > arty.dts
arty.dtb: arty.dts
	dtc -O dtb -o arty.dtb arty.dts

pin_io.c: csr.json generate_csr_locations.py
	python3 generate_csr_locations.py > pin_io.c
