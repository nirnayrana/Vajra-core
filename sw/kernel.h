// kernel.h — Vajra Core RTOS kernel
//
// Minimal preemptive round-robin scheduler.
// Driven by the machine timer interrupt wired through riscv_mtime.v.

#ifndef KERNEL_H
#define KERNEL_H

#include <stdint.h>

// -----------------------------------------------------------------------
// Config
// -----------------------------------------------------------------------
#define MAX_TASKS        4
#define TASK_STACK_SIZE  256   // bytes per task stack

//QEMU
#ifdef QEMU
  #define MTIME_BASE    0x0200bff8UL   // QEMU virt CLINT
  #define MTIME_LO      (*(volatile uint32_t*)(MTIME_BASE + 0x00))
  #define MTIME_HI      (*(volatile uint32_t*)(MTIME_BASE + 0x04))
  #define MTIMECMP_LO   (*(volatile uint32_t*)(0x02004000UL))
  #define MTIMECMP_HI   (*(volatile uint32_t*)(0x02004004UL))
#else
// MTIME peripheral base address (set in riscv_mtime.v / linker)
  #define MTIME_BASE    0x20000000UL
  #define MTIME_LO      (*(volatile uint32_t*)(MTIME_BASE + 0x00))
  #define MTIME_HI      (*(volatile uint32_t*)(MTIME_BASE + 0x04))
  #define MTIMECMP_LO   (*(volatile uint32_t*)(MTIME_BASE + 0x08))
  #define MTIMECMP_HI   (*(volatile uint32_t*)(MTIME_BASE + 0x0C))
#endif


// Timer tick = 1000 hardware cycles (matches TICK_CYCLES in riscv_mtime.v)
#define TICK_INTERVAL    1000UL

// CSR helpers (inline asm macros)
#define csr_write(csr, val) \
    asm volatile ("csrw " #csr ", %0" :: "r"(val))

#define csr_read(csr, val) \
    asm volatile ("csrr %0, " #csr : "=r"(val))

// -----------------------------------------------------------------------
// Task Control Block (TCB)
// IMPORTANT: sp MUST be the first field — trap.S reads offset 0.
// -----------------------------------------------------------------------
typedef struct {
    uint32_t  sp;            // saved stack pointer (FIRST — trap.S depends on this)
    uint8_t   stack[TASK_STACK_SIZE];  // private stack
    void    (*entry)(void);  // task function pointer
    uint8_t   id;            // task index
    uint8_t   state;         // 0=idle, 1=runnable
} TCB;

// -----------------------------------------------------------------------
// Kernel globals (defined in kernel.c)
// -----------------------------------------------------------------------
extern TCB    tasks[MAX_TASKS];
extern TCB   *current_task;     // trap.S references this by name
extern int    task_count;

// -----------------------------------------------------------------------
// API
// -----------------------------------------------------------------------

// Create a task. Returns 0 on success, -1 if MAX_TASKS reached.
int  task_create(void (*entry)(void));

// Start the OS: set mtvec, arm the first timer tick, enable interrupts.
// Never returns.
void os_start(void);

// Called from trap.S — selects next task, updates current_task.
// Returns pointer to the new current_task (for trap.S to load sp from).
TCB *scheduler(void);

#endif // KERNEL_H

// TinyML inference task (defined in tinyml_layer.c)
void tinyml_task(void);