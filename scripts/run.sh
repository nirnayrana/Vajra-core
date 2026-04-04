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
  -march=rv32i \
  -mabi=ilp32 \
  -T sw/linker.ld \
  -Wl,-e,_start \
  sw/start.S sw/program.c sw/runtime.c \
  -o build/program.elf

echo "==> Generating hex..."
riscv64-unknown-elf-objcopy -O binary build/program.elf build/program.bin
hexdump -v -e '1/4 "%08x\n"' build/program.bin > build/program.hex

# $readmemh("program.hex") in riscv_imem.v looks in the working directory
cp build/program.hex program.hex

echo "==> Simulating..."
iverilog -g2012 -o build/sim.out \
  src/*.v tb/tb_riscv_pipeline.sv

vvp build/sim.out