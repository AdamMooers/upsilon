.PHONY: lint
base.v: base.m4
	m4 -P --synclines base.m4 | awk -v filename=base.m4 '/^#line/ {printf("`line %s %d 0\n", filename, $$2); next} {print}' > base.v
lint: base.v
	verilator --lint-only base.v -I../spi -I../control_loop -I../waveform
