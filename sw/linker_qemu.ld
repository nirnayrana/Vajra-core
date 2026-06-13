/* linker.ld — Vajra Core RTOS memory map
 *
 * Flash: instruction memory 0x0000–0x0FFF  (4 KB)
 * RAM:   data + stack      0x1000–0x1FFF  (4 KB)
 *
 * Stack grows DOWN from 0x2000.
 * Kernel task stacks are carved out of the .bss section.
 */

ENTRY(_start)

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x80000000, LENGTH = 16K
    RAM   (rwx) : ORIGIN = 0x80010000, LENGTH = 8K
}

SECTIONS
{
    .text : {
        *(.text.start)   /* _start first */
        *(.text*)
    } > FLASH

    .rodata : {
        *(.rodata*)
        *(.srodata*)
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

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
