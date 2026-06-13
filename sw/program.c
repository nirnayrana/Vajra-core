// program.c — Vajra Core RTOS: task registration + boot
//
// Creates 4 tasks:
//   task_a     — counter upward,  prints every 500 iters
//   task_b     — counter downward, prints every 500 iters
//   task_c     — heartbeat every 1000 iters
//   tinyml_task — 4×4 anomaly-detection inference, then exits cleanly

#include "kernel.h"

#define UART ((volatile unsigned int*)UART_BASE)

static void uart_puts(const char *s) {
    while (*s) *UART = (unsigned int)*s++;
}
static void uart_put_dec(unsigned int n) {
    if (n >= 10) uart_put_dec(n / 10);
    *UART = '0' + (n % 10);
}

// Task A — counts upward
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

// Task C — heartbeat
static void task_c(void) {
    unsigned int count = 0;
    while (1) {
        count++;
        if (count % 1000 == 0) {
            uart_puts("C:heartbeat\n");
        }
    }
}

// main — register tasks, start RTOS (never returns)
int main(void) {
    uart_puts("[boot] Vajra Core RTOS — TinyML Edition\n");
    task_create(task_a);
    task_create(task_b);
    task_create(task_c);
    task_create(tinyml_task);  // inference task runs once then yields
    os_start();
    return 0;
}