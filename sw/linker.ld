/* linker.ld — Vajra Core memory map
 *
 * FIX: LENGTH changed from 2K to 4K.
 *   Old: RAM = 0x1000–0x17FF (2 KB), stack top = 0x1800
 *   New: RAM = 0x1000–0x1FFF (4 KB), stack top = 0x2000
 *
 *   The old start.S set sp = 0x2800 (a comment said "0x1000 + 2048 - 4 = 0x27FC"
 *   which confuses decimal 2048 with hex 0x2000; actual 2 KB = 0x800 bytes).
 *   That placed the stack 4 KB above the 2 KB RAM window, so any function call
 *   or local variable push would write to unmapped space.
 *
 *   With LENGTH=4K: _stack_top = 0x1000 + 0x1000 = 0x2000.
 *   start.S sets sp = 0x2000, giving the full 4 KB for code, data, and stack.
 *   riscv_dmem.v is updated to match (1024 words, addr < 0x2000).
 */

ENTRY(_start)
MEMORY
{
    FLASH (rx) : ORIGIN = 0x00000000, LENGTH = 4K   /* instruction memory */
    RAM   (rw) : ORIGIN = 0x00001000, LENGTH = 4K   /* data memory + stack */
}

SECTIONS
{
    .text : {
        *(.text*)
    } > FLASH

    .data : {
        _sdata  = .;
        *(.data*)
        *(.sdata*)
        _edata  = .;
    } > RAM AT > FLASH

    _sidata = LOADADDR(.data);

    .bss : {
        _sbss = .;
        *(.bss*)
        *(COMMON)
        _ebss = .;
    } > RAM

    /* Stack grows down from top of RAM.
     * _stack_top = 0x1000 + 0x1000 = 0x2000
     * start.S must set:  li sp, 0x00002000
     */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
