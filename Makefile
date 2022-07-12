.PHONY: cpu clean
cpu: soc.py
	python3 soc.py
clean:
	rm -rf build csr.json overlay.config overlay.dts
overlay.dts overlay.config: csr.json
	# NOTE: Broken in LiteX 2022.4.
