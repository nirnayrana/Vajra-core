/* linker.ld — Vajra Core memory map
 *
 * Fixed:
 *   RAM origin moved from 0x00000000 to 0x00001000
 *   Previously FLASH and RAM both started at 0x0:
 *     - .data VMA landed at 0x0 (same as .text start)
 *     - start.S copy loop wrote .data over the beginning of .text
 *     - volatile int x=5, y=10 clobbered the first instructions
 *   Now .data VMA is 0x1000, which is exactly where riscv_dmem.v
 *   accepts writes (addr >= 0x1000 && addr < 0x3000).
 *
 *   Stack pointer in start.S (li sp, 0x300) should also be updated
 *   to 0x2FFC (top of DMEM range) — see note below.
 */

ENTRY(_start)
MEMORY
{
    FLASH (rx) : ORIGIN = 0x00000000, LENGTH = 4K
    RAM   (rw) : ORIGIN = 0x00001000, LENGTH = 2K
}

SECTIONS
{
    .text : {
        *(.text*)
    } > FLASH

    .data : {
        _sdata = .;
        *(.data*)
        *(.sdata*)
        _edata = .;
    } > RAM AT > FLASH

    _sidata = LOADADDR(.data);

    .bss : {
        _sbss = .;
        *(.bss*)
        *(COMMON)
        _ebss = .;
    } > RAM

    /* Stack grows down from top of RAM: 0x1000 + 2048 - 4 = 0x27FC */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
