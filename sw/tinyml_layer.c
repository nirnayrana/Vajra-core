// tinyml_layer.c — Vajra Core RTOS: TinyML Edge Anomaly Detection Task
//
// Runs as a cooperative task on Vajra Core RTOS.
// Performs a 4x4 weight-stationary matrix multiply (W * X^T) entirely
// in software — the Vajra Core SoC has no DSA hardware peripheral.
// Hardware accelerators (if added later) would live at a validated
// AXI-mapped address; for now the MAC loop IS the accelerator.
//
// BUG FIXES vs original tinyml_layer.c
// ======================================
// 1. REMOVED phantom DSA_CTRL / DSA_MAT_A / DSA_MAT_B / DSA_MAT_C
//    MMIO addresses (0x40000000–0x4000000C). No such peripheral exists
//    on this SoC; writing to unmapped AXI space causes undefined behavior.
//
// 2. REMOVED inverted DSA_CTRL poll:
//      while((*DSA_CTRL & 0x1) == 0);   // wrote 1, polled for 0 → infinite loop
//    There is no hardware to ever clear that bit.
//
// 3. REMOVED broken *DSA_MAT_C read loop. Reading the same MMIO address
//    16 times returns the same value every time — there is no FIFO or
//    auto-increment on a plain memory-mapped register.
//
// 4. FIXED print_num(0): original returned early without printing '0',
//    causing missing columns and misaligned output.
//
// 5. FIXED W[16] and X[16] as stack-local arrays. Global/static data
//    lives in .data (FLASH 0x0000–0x0FFF) which is NOT reachable via
//    the DMEM load path in this Harvard architecture. Per README_sim.txt:
//    "Use LOCAL variables in main() instead of global/static ones."
//
// 6. REMOVED bare while(1) at the end of main(). Under the RTOS that
//    spins with interrupts masked and starves other tasks. The function
//    now returns normally so the RTOS scheduler can continue.
//
// 7. UART is the only valid MMIO output peripheral (0x80000000),
//    consistent with riscv_dmem.v (addr[31:28] == 4'h8 → UART).

#include "kernel.h"   // TCB, UART, csr_read/write, RTOS API

// ---------------------------------------------------------------------------
// UART output helpers (consistent with kernel.c / program.c style)
// ---------------------------------------------------------------------------
#define UART_MMIO ((volatile unsigned int *)0x80000000U)

static void tml_putchar(char c) {
    *UART_MMIO = (unsigned int)c;
}

static void tml_puts(const char *s) {
    while (*s) tml_putchar(*s++);
}

// FIX 4: original returned early on 0, printing nothing for that column.
static void tml_put_dec(int num) {
    if (num < 0) {
        tml_putchar('-');
        num = -num;
    }
    // FIX: handle zero correctly
    if (num == 0) {
        tml_putchar('0');
        return;
    }
    // Reverse-digit buffer (max 10 decimal digits for 32-bit int)
    char buf[10];
    int  i = 0;
    while (num > 0) {
        buf[i++] = (char)('0' + (num % 10));
        num /= 10;
    }
    while (i > 0) {
        tml_putchar(buf[--i]);
    }
}

// ---------------------------------------------------------------------------
// Software ReLU — unchanged, but placed before use to avoid implicit-decl
// ---------------------------------------------------------------------------
static int relu(int x) {
    return (x > 0) ? x : 0;
}

// ---------------------------------------------------------------------------
// Pure-software 4x4 MAC: Y = W * X^T
//
// W[4][4] — pre-trained weights (stationary, loaded once)
// X[4][4] — sensor batch (one row = one 4-feature reading)
// Y[4][4] — pre-activation outputs
//
// Y[i][j] = sum_k( W[i][k] * X[j][k] )
//   i = neuron index (0..3)
//   j = time-step / sensor reading (0..3)
//   k = feature index (0..3)
//
// This mirrors what the DSA systolic array *would* compute if it existed.
// ---------------------------------------------------------------------------
static void sw_mac_4x4(const int W[4][4],
                        const int X[4][4],
                        int       Y[4][4])
{
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            int acc = 0;
            for (int k = 0; k < 4; k++) {
                acc += W[i][k] * X[j][k];
            }
            Y[i][j] = acc;
        }
    }
}

// ---------------------------------------------------------------------------
// tinyml_task — entry point for the RTOS task
// Can also be called directly from main() for a standalone demo.
// ---------------------------------------------------------------------------
void tinyml_task(void) {
    tml_puts("\n--- VAJRA CORE: TINYML ANOMALY DETECTION ---\n");

    // FIX 5: stack-local arrays — safe with Harvard arch DMEM path.
    // W[neuron][feature]: 8-bit quantised pre-trained weights
    int W[4][4] = {
        { 12,  -5,   8,  -2 },
        { -3,  15,  -4,   6 },
        {  9,  -1,  11,  -7 },
        { -6,   4,  -8,  14 }
    };

    // X[time][feature]: live sensor batch (4 readings × 4 features)
    int X[4][4] = {
        {  5,  2,  1,  0 },   // T0: Normal
        {  6,  3,  2,  1 },   // T1: Normal
        { 18, 25,  4,  2 },   // T2: ANOMALY SPIKE
        {  4,  1,  1,  0 }    // T3: Normal
    };

    // Output pre-activations Y[neuron][time]
    int Y[4][4];

    // ------------------------------------------------------------------
    // Stage 1 — "load weights" (here: just announce; on a real DSA we
    // would DMA W into the PE array via a validated MMIO region)
    // ------------------------------------------------------------------
    tml_puts("1. Weights loaded into PE array (software MAC engine).\n");

    // ------------------------------------------------------------------
    // Stage 2 — "stream sensor batch"
    // ------------------------------------------------------------------
    tml_puts("2. Sensor batch staged for inference.\n");

    // ------------------------------------------------------------------
    // Stage 3 — software MAC (replaces non-existent DSA hardware)
    // FIX 1-3: no phantom MMIO writes/reads; all computation is in-core.
    // ------------------------------------------------------------------
    tml_puts("3. Running MAC operations (software systolic array)...\n");
    sw_mac_4x4((const int (*)[4])W,
               (const int (*)[4])X,
               Y);

    // ------------------------------------------------------------------
    // Stage 4 — ReLU activation + result display
    // ------------------------------------------------------------------
    tml_puts("4. Applying ReLU activation and reading results...\n\n");

    // Column header
    tml_puts("         [N0]\t[N1]\t[N2]\t[N3]\n");
    tml_puts("         ----\t----\t----\t----\n");

    for (int j = 0; j < 4; j++) {          // j = sensor reading / time-step
        // Annotate anomaly reading
        if (j == 2)
            tml_puts("Sensor T2*: ");  // * = anomaly
        else {
            tml_puts("Sensor T");
            tml_put_dec(j);
            tml_puts(":  ");
        }

        for (int i = 0; i < 4; i++) {      // i = neuron
            int activated = relu(Y[i][j]);
            tml_put_dec(activated);
            tml_putchar('\t');
        }
        tml_putchar('\n');
    }

    tml_puts("\n* T2 anomaly spike — elevated activations indicate fault.\n");
    tml_puts("\n--- INFERENCE COMPLETE ---\n\n");

    // FIX 6: return normally so the RTOS scheduler can run other tasks.
    // Do NOT spin in while(1) here — that would starve tasks A/B/C.
}
