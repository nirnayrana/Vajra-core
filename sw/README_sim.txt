Simulation note
===============
The Harvard architecture (separate IMEM and DMEM) means start.S cannot copy
.data initial values from FLASH into RAM via the DMEM load path — DMEM only
covers 0x1000–0x1FFF, not the FLASH range (0x0000–0x0FFF where .data is
stored in the binary).

Use LOCAL variables in main() instead of global/static ones. Local variables
live on the stack (inside the 4 KB RAM window) and work correctly.

Alternatively, add a DMEM initialisation path: preload DMEM at startup using
$readmemh with a separate data.hex generated from the .data section of the ELF.
