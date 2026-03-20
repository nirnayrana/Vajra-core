ENTRY(_start)
MEMORY
{
    FLASH (rx) : ORIGIN = 0x00000000, LENGTH = 4K
    RAM   (rw) : ORIGIN = 0x00000000, LENGTH = 1K
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

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
