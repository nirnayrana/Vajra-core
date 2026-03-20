#!/bin/bash
riscv64-unknown-elf-gcc \
  -O0 \
  -ffreestanding \
  -fno-pic -fno-pie \
  -nostdlib \
  -nostartfiles \
  -march=rv32i \
  -mabi=ilp32 \
  -T linker.ld \
  -Wl,-e,_start \
  start.S program.c \
  -o program.elf
riscv64-unknown-elf-objcopy -O binary program.elf program.bin

hexdump -v -e '1/4 "%08x\n"' program.bin > program.hex

iverilog -g2012 -o sim.out *.v *.sv
vvp sim.out
