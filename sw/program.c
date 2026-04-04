// program.c — Vajra Core test
// Uses only local variables so no .data section copy is needed in simulation.
// (Global volatile vars require start.S to copy .data from FLASH → RAM via DMEM,
//  but in simulation DMEM can't read FLASH. Locals live on the stack which is
//  always writable.)

int main() {
    volatile int *uart = (volatile int*)0x80000000;

    volatile int x = 5;    // local — stored on stack (in RAM), no .data needed
    volatile int y = 10;   // 10 = ASCII '\n' — triggers simulation finish

    *uart = x;
    *uart = y;

    while (1);
}
