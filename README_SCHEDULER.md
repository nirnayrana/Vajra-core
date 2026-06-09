# Vajra Core — Preemptive Scheduler Implementation

## What Was Added

### Hardware (src/)

| File | What changed |
|------|-------------|
| `src/riscv_mtime.v` | **NEW** — 64-bit MTIME/MTIMECMP timer peripheral, memory-mapped at `0x2000_0000`. Generates `timer_irq` when `MTIME >= MTIMECMP`. |
| `src/CSR_file.v` | **UPDATED** — Added `mie` (0x304), `mip` (0x344), `mret_en` input, `irq_pending` output. `mstatus` now correctly saves/restores `MIE↔MPIE` on trap entry/MRET. |
| `src/riscv_pipeline_top.v` | **UPDATED** — Instantiates MTIME, wires `irq_pending` into fetch stage. On interrupt: flushes IF/ID/EX, saves PC, redirects to `mtvec`. On MRET: redirects to `mepc`. `trap_active` lock prevents double-trap. |

### Software (sw/)

| File | What it does |
|------|-------------|
| `sw/trap.S` | **NEW** — Assembly trap entry point. Saves all 31 registers onto current task's stack, calls `scheduler()`, restores next task's registers, executes `mret`. |
| `sw/kernel.h` | **NEW** — TCB struct, API declarations, CSR macros, MTIME register macros. |
| `sw/kernel.c` | **NEW** — `task_create()`, `scheduler()` (round-robin + re-arms timer), `os_start()` (sets mtvec, enables interrupts). |
| `sw/program.c` | **UPDATED** — Demo: 3 tasks (A counts up, B counts down, C heartbeat). |
| `sw/start.S` | **UPDATED** — `.text.start` section for correct link ordering. |
| `sw/linker.ld` | **UPDATED** — Places `.text.start` first so `_start` is at address 0x0. |
| `sw/trap.S` | Linked into FLASH alongside `start.S`. `trap_entry` symbol is at the address written into `mtvec`. |

### Testbench (tb/)

`tb/tb_riscv_pipeline.sv` — Updated: timeout 100k cycles, trap/MRET monitors, PASS on ≥3 context switches.

---

## Memory Map

```
0x0000_0000 – 0x0000_0FFF   FLASH / IMEM   (instructions: _start, trap_entry, main, tasks)
0x0000_1000 – 0x0000_1FFF   RAM  / DMEM    (stack, BSS, TCBs, task stacks)
0x2000_0000 – 0x2000_000F   MTIME          (mtime_lo, mtime_hi, mtimecmp_lo, mtimecmp_hi)
0x8000_0000+                UART MMIO
```

---

## How a Context Switch Works (Step by Step)

```
1. MTIME counts up every clock cycle.
2. When MTIME >= MTIMECMP:  timer_irq = 1
3. CSR_File sees: mstatus.MIE=1 AND mie.MTIE=1 AND mip.MTIP=1  →  irq_pending = 1
4. Pipeline (riscv_pipeline_top.v):
      trap_en  ← 1
      trap_pc  ← PC_F  (where we were)
      trap_cause ← 0x8000_0007  (machine timer interrupt)
      IF/ID/EX pipeline registers flushed to NOP
      PC_F ← mtvec  (address of trap_entry in trap.S)
5. CSR_File (on trap_en):
      mepc    ← trap_pc
      mstatus.MPIE ← mstatus.MIE
      mstatus.MIE  ← 0    (interrupts OFF while in handler)
6. trap.S runs:
      addi sp, sp, -124   (make room)
      sw x1..x31          (save all registers)
      current_task->sp = sp   (freeze current task)
      call scheduler()
7. scheduler() (kernel.c):
      MTIMECMP += TICK_INTERVAL   (re-arm for next tick)
      picks next runnable task (round-robin)
      current_task = next_task
      returns pointer to next TCB
8. trap.S resumes:
      sp = next_task->sp   (switch stacks)
      lw x1..x31           (restore next task's registers)
      mret
9. MRET (hardware):
      PC       ← mepc        (next task's saved PC)
      mstatus.MIE ← mstatus.MPIE   (re-enable interrupts)
10. Next task resumes exactly where it left off.
```

---

## Build & Simulate

```bash
# Compile SW (requires riscv32-unknown-elf-gcc)
riscv32-unknown-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -T sw/linker.ld \
    sw/start.S sw/trap.S sw/kernel.c sw/program.c sw/runtime.c \
    -o build/vajra.elf

riscv32-unknown-elf-objcopy -O ihex build/vajra.elf build/vajra.hex

# Simulate (requires iverilog)
iverilog -g2012 -o sim.vvp \
    src/riscv_pipeline_top.v src/riscv_mtime.v src/CSR_file.v \
    src/riscv_imem.v src/riscv_dmem.v src/riscv_regfile.v \
    src/riscv_alu4b.v src/riscv_alu_decoder.v src/riscv_control.v \
    src/riscv_forwarding.v src/riscv_hazard_unit.v src/riscv_pipe_reg.v \
    tb/tb_riscv_pipeline.sv

vvp sim.vvp
```

Expected output:
```
[boot] Vajra Core RTOS
[OS] starting, waiting for first tick...
[TB] cycle=1005  TRAP TAKEN  PC=0x000000xx  cause=0x80000007
[OS] task 0
[TB] cycle=1010  MRET (context switch #1)  mepc=0x000000xx
A:500
[TB] cycle=2005  TRAP TAKEN ...
[OS] task 1
[TB] cycle=2010  MRET (context switch #2)
...
[PASS] Preemptive scheduler verified: 3 context switches
```

---

## Tuning

- **Tick rate**: change `TICK_CYCLES` in `riscv_mtime.v` or `TICK_INTERVAL` in `kernel.h` (must match).
- **Max tasks**: change `MAX_TASKS` in `kernel.h`.
- **Stack size**: change `TASK_STACK_SIZE` in `kernel.h` (must fit in 4 KB RAM alongside BSS/data).
- **Add tasks**: call `task_create(my_func)` before `os_start()`.
