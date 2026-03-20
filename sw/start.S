.section .text
.global _start

_start:
    # setup stack
    li sp, 0x00000300
    addi sp, sp, 0

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
    # ZERO .bss (IMPORTANT)
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
