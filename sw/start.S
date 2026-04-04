.section .text
.global _start

_start:
    # Stack pointer: top of RAM = 0x1000 + 2KB - 4 = 0x27FC
    # Fixed: was 0x300 which is inside IMEM address space, not DMEM
    li sp,  0x00002800

    # -------------------------
    # COPY .data (FLASH → RAM)
    # -------------------------
    la t0, _sdata
    la t1, _edata
    la t2, _sidata

copy_data:
    beq t0, t1, done_copy
    lw t3, 0(t2)
    sw t3, 0(t0)
    addi t0, t0, 4
    addi t2, t2, 4
    j copy_data

done_copy:

    # -------------------------
    # ZERO .bss
    # -------------------------
    la t0, _sbss
    la t1, _ebss

zero_bss:
    beq t0, t1, done_bss
    sw zero, 0(t0)
    addi t0, t0, 4
    j zero_bss

done_bss:

    # -------------------------
    # CALL MAIN
    # -------------------------
    jal main

hang:
    j hang