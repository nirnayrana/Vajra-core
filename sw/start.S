// start.S — Vajra Core bare-metal startup
// Updated for preemptive scheduler: trap.S provides trap_entry.

.section .text.start
.global _start

_start:
    // Stack pointer: top of 4KB RAM
    li sp, STACK_TOP

    // Copy .data (FLASH -> RAM)
    la t0, _sdata
    la t1, _edata
    la t2, _sidata
copy_data:
    beq  t0, t1, done_copy
    lw   t3, 0(t2)
    sw   t3, 0(t0)
    addi t0, t0, 4
    addi t2, t2, 4
    j    copy_data
done_copy:

    // Zero .bss
    la t0, _sbss
    la t1, _ebss
zero_bss:
    beq  t0, t1, done_bss
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    zero_bss
done_bss:

    // Call main (which calls os_start — never returns)
    jal main

hang:
    j hang
