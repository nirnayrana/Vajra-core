// program.c — Vajra Core preemptive scheduler demo
//
// Creates 3 tasks that each count independently.
// The timer interrupt fires every TICK_INTERVAL clocks,
// switches tasks, and you can see interleaved output on UART.

#include "kernel.h"

#define UART ((volatile unsigned int*)0x80000000)

static void uart_puts(const char *s) {
    while (*s) *UART = (unsigned int)*s++;
}
static void uart_put_dec(unsigned int n) {
    if (n >= 10) uart_put_dec(n / 10);
    *UART = '0' + (n % 10);
}

// Task A — counts upward, prints every 500 iterations
static void task_a(void) {
    unsigned int count = 0;
    while (1) {
        count++;
        if (count % 500 == 0) {
            uart_puts("A:"); uart_put_dec(count); uart_puts("\n");
        }
    }
}

// Task B — counts downward from 10000
static void task_b(void) {
    unsigned int count = 10000;
    while (1) {
        if (count > 0) count--;
        if (count % 500 == 0) {
            uart_puts("B:"); uart_put_dec(count); uart_puts("\n");
        }
    }
}

// Task C — heartbeat every 1000 iterations
static void task_c(void) {
    unsigned int count = 0;
    while (1) {
        count++;
        if (count % 1000 == 0) {
            uart_puts("C:heartbeat\n");
        }
    }
}

// main — create tasks, start OS (never returns)
int main(void) {
    uart_puts("[boot] Vajra Core RTOS\n");
    task_create(task_a);
    task_create(task_b);
    task_create(task_c);
    os_start();
    return 0;
}
