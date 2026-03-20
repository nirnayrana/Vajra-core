# Vajra Core ⚡

A 32-bit pipelined RISC-V processor built from scratch in Verilog, capable of executing compiled C programs in a bare-metal environment.

## Features

* 5-stage pipeline (IF, ID, EX, MEM, WB)
* Hazard detection (load-use)
* Data forwarding (bypassing)
* Branch handling and pipeline flush
* Memory-mapped IO support

## System Overview

* Custom RISC-V CPU (RV32I subset)
* Instruction + Data memory
* Minimal runtime (start.S + linker)
* GCC-based compilation flow

## How It Works

C Program → RISC-V GCC → ELF → HEX → Loaded into IMEM → Executed by CPU

## Running the Simulation

```bash
./scripts/run.sh
```

## Project Status

🚧 Under active development — currently stabilizing memory system and runtime.

## Vision

To evolve into a full-stack open hardware compute system with custom accelerators and SoC integration.
