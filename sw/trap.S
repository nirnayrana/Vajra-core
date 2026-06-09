// trap.S — Machine-mode trap entry/exit for Vajra Core preemptive scheduler
//
// HOW IT WORKS
// ============
// When the hardware takes a trap (timer interrupt or exception):
//   1. Hardware atomically:
//        mepc    <- interrupted PC
//        mcause  <- 0x80000007 (machine timer interrupt)
//        mstatus.MPIE <- mstatus.MIE
//        mstatus.MIE  <- 0   (interrupts disabled while in handler)
//        PC      <- mtvec
//
//   2. This handler runs:
//        a. Saves all 31 non-zero registers onto the CURRENT task's stack
//        b. Saves the updated stack pointer into current_task->sp
//        c. Calls scheduler() — picks the next task, updates current_task
//        d. Loads next task's saved sp
//        e. Restores all 31 registers from the new stack
//        f. MRET — restores PC from mepc, MIE from MPIE, returns to user code
//
// STACK FRAME (grows down, 31 words = 124 bytes)
// -----------------------------------------------
//   SP+120: x31 (t6)
//   SP+116: x30 (t5)
//   ...
//   SP+4  : x2  (sp — value before trap, saved by us before decrementing)
//   SP+0  : x1  (ra)
//
// NOTE: x0 is never saved (always 0). mepc/mstatus saved in CSR hardware.

.section .text
.global trap_entry
.align 4               // mtvec requires 4-byte alignment (vectored: 64-byte)

trap_entry:

    // ------------------------------------------------------------------
    // 1. Make room for 31 registers (x1..x31) = 31*4 = 124 bytes
    // ------------------------------------------------------------------
    addi sp, sp, -124

    // Save all general-purpose registers
    sw   x1,   0(sp)    // ra
    // x2 (sp) — save the PRE-TRAP sp value = current sp + 124
    addi t0, sp, 124
    sw   t0,   4(sp)    // save original sp
    sw   x3,   8(sp)    // gp
    sw   x4,  12(sp)    // tp
    sw   x5,  16(sp)    // t0  (already clobbered above — but we saved it)
    sw   x6,  20(sp)    // t1
    sw   x7,  24(sp)    // t2
    sw   x8,  28(sp)    // s0/fp
    sw   x9,  32(sp)    // s1
    sw  x10,  36(sp)    // a0
    sw  x11,  40(sp)    // a1
    sw  x12,  44(sp)    // a2
    sw  x13,  48(sp)    // a3
    sw  x14,  52(sp)    // a4
    sw  x15,  56(sp)    // a5
    sw  x16,  60(sp)    // a6
    sw  x17,  64(sp)    // a7
    sw  x18,  68(sp)    // s2
    sw  x19,  72(sp)    // s3
    sw  x20,  76(sp)    // s4
    sw  x21,  80(sp)    // s5
    sw  x22,  84(sp)    // s6
    sw  x23,  88(sp)    // s7
    sw  x24,  92(sp)    // s8
    sw  x25,  96(sp)    // s9
    sw  x26, 100(sp)    // s10
    sw  x27, 104(sp)    // s11
    sw  x28, 108(sp)    // t3
    sw  x29, 112(sp)    // t4
    sw  x30, 116(sp)    // t5
    sw  x31, 120(sp)    // t6

    // ------------------------------------------------------------------
    // 2. Save stack pointer into current_task->sp
    //    current_task is a global pointer to the TCB struct
    //    TCB layout: { uint32_t sp; ... }  (sp is first field)
    // ------------------------------------------------------------------
    la   t0, current_task    // t0 = &current_task  (pointer to pointer)
    lw   t1, 0(t0)           // t1 = current_task   (the TCB pointer itself)
    sw   sp, 0(t1)           // current_task->sp = sp

    // ------------------------------------------------------------------
    // 3. Call the C scheduler to pick the next task
    //    scheduler() updates current_task and returns next task's TCB in a0
    // ------------------------------------------------------------------
    call scheduler

    // ------------------------------------------------------------------
    // 4. Load the new task's saved stack pointer
    //    a0 = pointer to next TCB; first field is sp
    // ------------------------------------------------------------------
    lw   sp, 0(a0)           // sp = next_task->sp

    // ------------------------------------------------------------------
    // 5. Restore all registers from new task's stack
    // ------------------------------------------------------------------
    lw   x1,   0(sp)    // ra
    // skip x2 (sp) — will restore after all others
    lw   x3,   8(sp)    // gp
    lw   x4,  12(sp)    // tp
    lw   x5,  16(sp)    // t0
    lw   x6,  20(sp)    // t1
    lw   x7,  24(sp)    // t2
    lw   x8,  28(sp)    // s0/fp
    lw   x9,  32(sp)    // s1
    lw  x10,  36(sp)    // a0
    lw  x11,  40(sp)    // a1
    lw  x12,  44(sp)    // a2
    lw  x13,  48(sp)    // a3
    lw  x14,  52(sp)    // a4
    lw  x15,  56(sp)    // a5
    lw  x16,  60(sp)    // a6
    lw  x17,  64(sp)    // a7
    lw  x18,  68(sp)    // s2
    lw  x19,  72(sp)    // s3
    lw  x20,  76(sp)    // s4
    lw  x21,  80(sp)    // s5
    lw  x22,  84(sp)    // s6
    lw  x23,  88(sp)    // s7
    lw  x24,  92(sp)    // s8
    lw  x25,  96(sp)    // s9
    lw  x26, 100(sp)    // s10
    lw  x27, 104(sp)    // s11
    lw  x28, 108(sp)    // t3
    lw  x29, 112(sp)    // t4
    lw  x30, 116(sp)    // t5
    lw  x31, 120(sp)    // t6

    // Restore sp last (it still points to the frame we just read)
    lw   x2,   4(sp)

    // ------------------------------------------------------------------
    // 6. MRET — atomically:
    //      PC      <- mepc  (next task's saved PC)
    //      MIE     <- MPIE  (re-enable interrupts)
    //      privilege <- M
    // ------------------------------------------------------------------
    mret
