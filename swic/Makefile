.PHONY: clean

CROSS = riscv64-unknown-elf-
COMPILE_FLAGS = -march=rv32im -mabi=ilp32 -ffreestanding -nostdlib -Os \
	-Wl,--no-warn-rwx-segments,-build-id=none,-Bstatic,-T,riscv.ld,--strip-debug,$\
	--defsym=RAM_ORIGIN=0x10000,--defsym=RAM_SIZE=0x1000,--defsym=IRQ_ORIGIN=0x10010 \
	-nostartfiles -lgcc
SOURCE_FILES = start.s main.c

test.bin: test.elf
	#$(CROSS)objcopy -O binary -j .start -j .IRQ_handler -j .text test.elf test.bin

test.elf: $(SOURCE_FILES)
	$(CROSS)gcc $(COMPILE_FLAGS) $(SOURCE_FILES) -o test.elf
decompile: test.elf
	$(CROSS)objdump -D test.elf
section-stats: test.elf
	$(CROSS)objdump -h test.elf
clean:
	rm -rf *.elf *.bin