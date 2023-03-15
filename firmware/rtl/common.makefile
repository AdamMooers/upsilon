# Generate verilog from m4 file
%.v: %.v.m4
	m4 -P --synclines $< | awk -v filename=$< '/^#line/ {printf("`line %d %s 0\n", $$2, filename); next} {print}' > $@
