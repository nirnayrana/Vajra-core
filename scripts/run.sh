#!/bin/bash
set -e
# Run from repo root: ./scripts/run.sh
cd "$(dirname "$0")/.."
mkdir -p build
echo "==> Compiling..."
riscv64-unknown-elf-gcc \
  -O0 \
  -ffreestanding \
  -fno-pic -fno-pie \
  -nostdlib \
  -nostartfiles \
  -march=rv32ima_zicsr \
  -mabi=ilp32 \
  -T sw/linker.ld \
  -Wl,-e,_start \
  sw/start.S sw/trap.S sw/program.c sw/kernel.c \
  -o build/program.elf \
  -lgcc
echo "==> Generating hex..."
riscv64-unknown-elf-objcopy -O binary build/program.elf build/program.bin
hexdump -v -e '1/4 "%08x\n"' build/program.bin > build/program.hex
cp build/program.hex program.hex
echo "==> Simulating..."
iverilog -g2012 -o build/sim.out \
  src/*.v tb/tb_riscv_pipeline.sv