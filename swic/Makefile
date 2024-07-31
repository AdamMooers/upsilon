.PHONY: clean

SOURCE_FILES = start.s test.c

test.bin: test.elf
	riscv64-unknown-elf-objcopy -O binary -j .text test.elf test.bin
test.elf: $(SOURCE_FILES)
	riscv64-unknown-elf-gcc -DRAM_SIZE=0x1000 -march=rv32im -mabi=ilp32 \
	-ffreestanding -nostdlib -Os -Wl,-build-id=none,-Bstatic,-T,riscv.ld,\
	--strip-debug -nostartfiles -lgcc $(SOURCE_FILES) -o test.elf
clean:
	rm -rf *.elf *.bin