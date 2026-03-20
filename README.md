# Vajra Core ⚡

A 32-bit pipelined RISC-V processor built from scratch in Verilog, capable of executing compiled C programs in a bare-metal environment.

---

## 🚀 Highlights

* 5-stage pipeline (IF, ID, EX, MEM, WB)
* Hazard detection (load-use stall)
* Data forwarding (bypassing)
* Branch handling with pipeline flush
* Memory-mapped I/O support
* End-to-end C execution (GCC → ELF → HEX → CPU)

---

## 🧠 System Architecture

This project implements a complete compute pipeline:

C Program → RISC-V GCC → ELF → HEX → Instruction Memory → CPU → Data Memory → Output

---

## 📂 Project Structure

```
rtl/        → CPU design (Verilog)
tb/         → Testbench
sw/         → Bare-metal runtime (start.S, linker.ld, C programs)
scripts/    → Build & run scripts
build/      → Generated binaries (ignored in git)
docs/       → Architecture documentation
```

---

## ▶️ Running the Simulation

```bash
./scripts/run.sh
```

---

## 📌 Current Status

* Pipeline execution: ✅
* C program execution: ✅
* Memory system: ⚠️ under stabilization

---

## 🔭 Vision

Vajra Core is part of a broader initiative to build a full-stack open hardware compute platform, including:

* Custom SoC design
* AI accelerators
* Assistive communication hardware

---

## 👤 Author

Nirnay Rana
ECE | Computer Architecture | RISC-V | Systems
