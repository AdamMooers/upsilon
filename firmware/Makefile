.PHONY: cpu clean

DEVICETREE_GEN_DIR=.
cpu: soc.py
	python3 soc.py
clean:
	rm -rf build csr.json overlay.config overlay.dts
overlay.dts overlay.config: csr.json litex_json2dts_zephyr.py
	# NOTE: Broken in LiteX 2022.4.
	$(DEVICETREE_GEN_DIR)/litex_json2dts_zephyr.py --dts overlay.dts --config overlay.config csr.json
