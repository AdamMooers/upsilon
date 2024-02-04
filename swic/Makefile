test.bin: test.elf
	riscv64-unknown-elf-objcopy -O binary -j .text test.elf test.bin
test.elf: test.c
	riscv64-unknown-elf-gcc -march=rv32imc -mabi=ilp32 -ffreestanding -nostdlib -Os -Wl,-build-id=none,-Bstatic,-T,riscv.ld,--strip-debug -nostartfiles -lgcc test.c -o test.elf
