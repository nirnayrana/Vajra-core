# =============================================================================
# Vajra Core RTOS — Makefile
# OS: VajraOS v1.0  (Bare-metal preemptive RTOS on RV32IMA)
# Author: Nirnay Rana
# =============================================================================

OS_NAME    = Ivaan
OS_VERSION = 1.0

CROSS   = riscv64-unknown-elf
CC      = $(CROSS)-gcc
OBJCOPY = $(CROSS)-objcopy
SIZE    = $(CROSS)-size

# RV32IMA + Zicsr: integer, multiply/divide, atomic, CSR instructions
ARCH    = -march=rv32ima_zicsr -mabi=ilp32

CFLAGS  = -O0 \
           -ffreestanding \
           -fno-pic \
           -fno-pie \
           -nostdlib \
           -nostartfiles \
           $(ARCH) \
           -Wall \
           -Wextra \
           -DOS_NAME=\"$(OS_NAME)\" \
           -DOS_VERSION=\"$(OS_VERSION)\"


CFLAGS_HW   = $(CFLAGS) -DUART_BASE=0x80000000UL -DSTACK_TOP=0x00002000
CFLAGS_QEMU = $(CFLAGS) -DUART_BASE=0x10000000UL -DSTACK_TOP=0x80012000 -DQEMU
LDFLAGS = -T sw/linker.ld -Wl,-e,_start

# QEMU flags — riscv32 virt machine, serial to stdout, no GUI
QEMU        = qemu-system-riscv32
QEMU_MACHINE = virt
QEMU_FLAGS  = -machine $(QEMU_MACHINE) \
              -nographic \
              -bios none

# Linker script variants
LD_HW   = sw/linker.ld        # Vajra Core hardware map  (0x00000000)
LD_QEMU = sw/linker_qemu.ld   # QEMU virt map            (0x80000000)

# Source files
SRCS    = sw/start.S     \
          sw/trap.S      \
          sw/program.c   \
          sw/kernel.c    \
          sw/runtime.c   \
          sw/tinyml_layer.c

TARGET      = build/program
TARGET_QEMU = build/program_qemu

# =============================================================================
# Default target — builds for Vajra Core hardware (used by VLSI team)
# =============================================================================
.PHONY: all
all: $(TARGET).hex
	@echo ""
	@echo "  ╔══════════════════════════════════════╗"
	@echo "  ║  $(OS_NAME) v$(OS_VERSION) — Build complete          ║"
	@echo "  ║  RV32IMA | Preemptive RTOS + TinyML  ║"
	@echo "  ╚══════════════════════════════════════╝"
	@echo ""

# =============================================================================
# Build rules — hardware target
# =============================================================================
$(TARGET).elf: $(SRCS) sw/linker.ld | build
	$(CC) $(CFLAGS_HW) $(LDFLAGS) $(SRCS) -o $@ -lgcc
	$(SIZE) $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).bin
	hexdump -v -e '1/4 "%08x\n"' $< > $@
	cp $@ program.hex

# =============================================================================
# Build rules — QEMU target (separate ELF, different linker script)
# =============================================================================
$(TARGET_QEMU).elf: $(SRCS) $(LD_QEMU) | build
	$(CC) $(CFLAGS_QEMU) -T $(LD_QEMU) -Wl,-e,_start $(SRCS) -o $@ -lgcc
	$(SIZE) $@

# Generate linker_qemu.ld from linker.ld if it doesn't exist yet
$(LD_QEMU):
	@echo "Generating $(LD_QEMU) for QEMU virt machine..."
	sed \
	  -e 's/ORIGIN = 0x00000000, LENGTH = 16K/ORIGIN = 0x80000000, LENGTH = 16K/' \
	  -e 's/ORIGIN = 0x00004000, LENGTH =  8K/ORIGIN = 0x80010000, LENGTH =  8K/' \
	  $(LD_HW) > $(LD_QEMU)
	@echo "  Created $(LD_QEMU)"
	@echo "  NOTE: If addresses don't look right, edit $(LD_QEMU) manually."

# =============================================================================
# run — OS development on QEMU (your target)
# =============================================================================
.PHONY: run
run: $(TARGET_QEMU).elf
	@echo ""
	@echo "  Booting $(OS_NAME) v$(OS_VERSION) on QEMU riscv32 virt..."
	@echo "  (Press Ctrl-A then X to exit QEMU)"
	@echo ""
	$(QEMU) $(QEMU_FLAGS) -kernel $(TARGET_QEMU).elf

# =============================================================================
# sim — Icarus Verilog simulation (VLSI team's target)
# =============================================================================
.PHONY: sim
sim: $(TARGET).hex
	iverilog -g2012 -o build/sim.out src/*.v tb/tb_riscv_pipeline.sv
	vvp build/sim.out

.PHONY: simrun
simrun:
	vvp build/sim.out

# =============================================================================
# Utilities
# =============================================================================
build:
	mkdir -p build

.PHONY: clean
clean:
	rm -rf build program.hex

.PHONY: info
info:
	@echo "OS:      $(OS_NAME) v$(OS_VERSION)"
	@echo "ISA:     RV32IMA + Zicsr"
	@echo "Sources: $(SRCS)"
	@echo "Targets:"
	@echo "  make all    — build for Vajra Core hardware (VLSI team)"
	@echo "  make sim    — Icarus Verilog simulation     (VLSI team)"
	@echo "  make run    — boot on QEMU riscv32 virt     (OS dev)"