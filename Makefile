# Vajra Core RTOS — Makefile

CROSS   = riscv64-unknown-elf
CC      = $(CROSS)-gcc
OBJCOPY = $(CROSS)-objcopy

ARCH    = -march=rv32ima_zicsr -mabi=ilp32
CFLAGS  = -O0 -ffreestanding -fno-pic -fno-pie -nostdlib -nostartfiles $(ARCH) -Wall
LDFLAGS = -T sw/linker.ld -Wl,-e,_start

SRCS    = sw/start.S sw/trap.S sw/program.c sw/kernel.c sw/runtime.c
TARGET  = build/program

all: $(TARGET).hex

$(TARGET).elf: $(SRCS) | build
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@ -lgcc

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).bin
	hexdump -v -e '1/4 "%08x\n"' $< > $@
	cp $@ program.hex

sim: $(TARGET).hex
	iverilog -g2012 -o build/sim.out src/*.v tb/tb_riscv_pipeline.sv
	vvp build/sim.out

build:
	mkdir -p build

clean:
	rm -rf build program.hex

.PHONY: all sim clean