ON_FPGA :=y
CROSS_COMPILE ?= mipsel-linux-gnu-

CC      := $(CROSS_COMPILE)gcc
LD      := $(CROSS_COMPILE)ld
OBJCOPY := $(CROSS_COMPILE)objcopy

CFLAGS  := -msoft-float -ffreestanding -fno-builtin -nostdlib -nostdinc -g -mno-abicalls -fno-pic -EL -G0 -Wall -O0
LDFLAGS := -EL -nostdlib -n -G 0 -static


rom.coe: gen_coe rom.bin
	./gen_coe

gen_coe: gen_coe.cpp
	gcc gen_coe.cpp -o gen_coe

rom.bin: rom.S
	$(CC) $(CFLAGS) -g -c -o rom.o $^
	$(LD) $(LDFLAGS) -Ttext 0xbfc00000 -o rom.elf rom.o
	$(OBJCOPY) -O binary -j .text -S rom.elf $@

.PHONY: clean
clean:
	-rm	rom.o
	-rm	rom.elf
	-rm	rom.bin
	-rm gen_coe
