# Copyright 2023 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.
#
.PHONY: cpu clean rtl_codegen

DEVICETREE_GEN_DIR=.

all: build/digilent_arty/digilent_arty.bit arty.dtb# mmio.py

csr.json build/digilent_arty/digilent_arty.bit: soc.py
	python3 soc.py

clean:
	rm -rf build csr.json arty.dts arty.dtb mmio.py

arty.dts: csr.json
	litex_json2dts_linux csr.json > arty.dts

arty.dtb: arty.dts
	dtc -O dtb -o arty.dtb arty.dts

#mmio.py: csr2mp.py csr.json
#	python3 csr2mp.py csr.json > mmio.py
