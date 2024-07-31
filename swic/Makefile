.PHONY: clean

CC = riscv64-unknown-elf-gcc
FLAGS = -march=rv32im -mabi=ilp32 -ffreestanding -nostdlib -Os \
	-Wl,--no-warn-rwx-segments,-build-id=none,-Bstatic,-T,riscv.ld,--strip-debug,$\
	--defsym=RAM_ORIGIN=0x10000,--defsym=RAM_SIZE=0x1000,--defsym=IRQ_REL_ORIGIN=0x10 \
	-nostartfiles -lgcc
SOURCE_FILES = start.s main.c

test.bin: test.elf
	riscv64-unknown-elf-objcopy -O binary -j .text test.elf test.bin
test.elf: $(SOURCE_FILES)
	$(CC) $(FLAGS) $(SOURCE_FILES) -o test.elf
clean:
	rm -rf *.elf *.bin