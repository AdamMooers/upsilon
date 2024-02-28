# Copyright 2023 (C) Peter McGoron
#
# This file is a part of Upsilon, a free and open source software project.
# For license terms, refer to the files in `doc/copying` in the Upsilon
# source distribution.
#
.PHONY: cpu clean rtl_codegen

DEVICETREE_GEN_DIR=.

all: build/digilent_arty/digilent_arty.bit arty.dtb mmio.py

mmio.py csr.json build/digilent_arty/digilent_arty.bit: soc.py
	@# Litex Version Check (current version 2023.12)
	@if ! pip show litex | awk '/Version:/ { split($$2, a, "\\."); if (a[1] < 2023 || a[2] < 12) exit(1)}'; then \
		pip show litex; \
		echo "You are using an old version of LiteX!"; \
		echo "Update LiteX or remake your image."; \
		exit 1; \
	fi
	
	@if [ ! -f config.py ]; then \
		echo "No config file found! If you are just starting, do"; \
		echo "$$ cp config.py.def config.py"; \
	fi
	
	cd rtl && make
	python3 soc.py

clean:
	rm -rf build csr.json arty.dts arty.dtb mmio.py

arty.dts: csr.json
	litex_json2dts_linux csr.json > arty.dts

arty.dtb: arty.dts
	dtc -O dtb -o arty.dtb arty.dts
