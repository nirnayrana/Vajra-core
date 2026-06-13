// kernel.c — Vajra Core RTOS kernel implementation

#include "kernel.h"
#include <stdint.h>
//#include <string.h>
void *memset(void *s, int c, unsigned long n) {
    unsigned char *p = s;
    while (n--) *p++ = (unsigned char)c;
    return s;
}

// -----------------------------------------------------------------------
// UART (for scheduler trace output)
// -----------------------------------------------------------------------
#define UART_ADDR UART_BASE
static void uart_putchar(char c) {
    *(volatile uint32_t*)UART_ADDR = (uint32_t)c;
}
static void uart_puts(const char *s) {
    while (*s) uart_putchar(*s++);
}
static void uart_put_dec(uint32_t n) {
    if (n >= 10) uart_put_dec(n / 10);
    uart_putchar('0' + (n % 10));
}

// -----------------------------------------------------------------------
// Kernel state
// -----------------------------------------------------------------------
TCB   tasks[MAX_TASKS];
TCB  *current_task;
int   task_count = 0;

// -----------------------------------------------------------------------
// task_create
// Builds an initial stack frame that looks exactly like what trap.S
// saves when it preempts a running task.  When the task is first
// scheduled, trap.S restores the frame and MRET jumps into entry().
//
// Initial frame layout (124 bytes, x1..x31):
//   [  0] x1  (ra)  = task_exit  (so the task can "return" cleanly)
//   [  4] x2  (sp)  = top of this task's stack (after frame removed)
//   [  8..120] x3..x31 = 0
//
// mepc for first dispatch is set in os_start / first context switch.
// We store entry() in TCB and set mepc from it when we first pick the task.
// -----------------------------------------------------------------------
int task_create(void (*entry)(void)) {
    if (task_count >= MAX_TASKS) return -1;

    TCB *t = &tasks[task_count];
    t->entry = entry;
    t->id    = (uint8_t)task_count;
    t->state = 1;  // runnable

    // Zero the private stack
    memset(t->stack, 0, TASK_STACK_SIZE);

    // Stack top (highest address, aligned to 4 bytes)
    uint32_t stack_top = (uint32_t)(t->stack + TASK_STACK_SIZE);

    // Allocate the 124-byte initial context frame
    uint32_t *frame = (uint32_t*)(stack_top - 124);
    // Clear all 31 slots
    for (int i = 0; i < 31; i++) frame[i] = 0;

    // x1 (ra) = simple infinite loop sentinel (task should loop itself)
    frame[0] = (uint32_t)entry;      // ra = entry (won't return but safe)
    // x2 (sp) = address after frame is popped
    frame[1] = (uint32_t)frame + 124;

    // Save the frame pointer as the task's initial sp
    t->sp = (uint32_t)frame;

    task_count++;
    return 0;
}

// -----------------------------------------------------------------------
// scheduler — called from trap.S, returns pointer to next TCB
//
// Simple round-robin: advance current index, skip non-runnable tasks.
// Also reprograms MTIMECMP for the next tick.
// -----------------------------------------------------------------------
TCB *scheduler(void) {
    // Re-arm timer: add TICK_INTERVAL to current MTIME
    // Use 64-bit read-modify-write (lower word first to avoid carry race)
    uint32_t lo = MTIME_LO;
    uint32_t hi = MTIME_HI;
    uint64_t next = ((uint64_t)hi << 32 | lo) + TICK_INTERVAL;

    // Write high word first (sets compare far in future), then low word
    MTIMECMP_HI = (uint32_t)(next >> 32);
    MTIMECMP_LO = (uint32_t)(next & 0xFFFFFFFF);

    // Round-robin: find next runnable task
    int start = current_task ? (int)(current_task->id + 1) : 0;
    for (int i = 0; i < task_count; i++) {
        int idx = (start + i) % task_count;
        if (tasks[idx].state == 1) {
            current_task = &tasks[idx];

            uart_puts("[OS] task ");
            uart_put_dec(current_task->id);
            uart_puts("\n");

            return current_task;
        }
    }

    // No runnable task — idle (return current as fallback)
    return current_task;
}

// -----------------------------------------------------------------------
// os_start — sets up the hardware, then "starts" the first task
//
// Strategy: set mtvec, arm the timer, enable interrupts, then spin
// in an idle loop.  The first timer tick will invoke trap.S, which
// calls scheduler(), which picks task 0 and MRET's into it.
// -----------------------------------------------------------------------
void os_start(void) {
    if (task_count == 0) {
        uart_puts("[OS] no tasks!\n");
        while (1);
    }

    // Point mtvec at our trap handler (direct mode, bit1:0 = 00)
    extern void trap_entry(void);
    csr_write(mtvec, (uint32_t)trap_entry);

    // Set current_task = NULL so scheduler() starts at task 0
    current_task = 0;

    // Arm first timer interrupt: fire after TICK_INTERVAL clocks
    uint32_t lo = MTIME_LO;
    uint32_t hi = MTIME_HI;
    uint64_t fire = ((uint64_t)hi << 32 | lo) + TICK_INTERVAL;
    MTIMECMP_HI = (uint32_t)(fire >> 32);
    MTIMECMP_LO = (uint32_t)(fire & 0xFFFFFFFF);

    // Enable machine timer interrupt in mie (bit 7 = MTIE)
    csr_write(mie, 0x80);

    // Enable global interrupts in mstatus (bit 3 = MIE)
    uint32_t ms;
    csr_read(mstatus, ms);
    csr_write(mstatus, ms | 0x8);

    uart_puts("[OS] starting, waiting for first tick...\n");

    // Idle loop — first interrupt will switch to task 0
    while (1) {
        // wfi would go here on real hardware: asm volatile("wfi");
    }
}
