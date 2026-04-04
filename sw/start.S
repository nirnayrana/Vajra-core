.section .text
.global _start

_start:
    # Stack pointer: top of 4 KB RAM = ORIGIN(RAM) + LENGTH(RAM)
    #                                 = 0x1000     + 0x1000
    #                                 = 0x2000
    # FIX: was 0x2800 (old comment wrongly calculated 0x1000 + 2048 decimal
    #      as 0x2800 instead of 0x1000 + 0x800 = 0x1800 for 2 KB, or
    #      0x1000 + 0x1000 = 0x2000 for 4 KB).
    li sp, 0x00002000

    # -------------------------
    # COPY .data (FLASH → RAM)
    # -------------------------
    la t0, _sdata    # destination start in RAM
    la t1, _edata    # destination end
    la t2, _sidata   # source in FLASH (load address of .data)

copy_data:
    beq  t0, t1, done_copy
    lw   t3, 0(t2)
    sw   t3, 0(t0)
    addi t0, t0, 4
    addi t2, t2, 4
    j    copy_data

done_copy:

    # -------------------------
    # ZERO .bss
    # -------------------------
    la t0, _sbss
    la t1, _ebss

zero_bss:
    beq  t0, t1, done_bss
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    zero_bss

done_bss:

    # -------------------------
    # CALL MAIN
    # -------------------------
    jal main

hang:
    j hang
