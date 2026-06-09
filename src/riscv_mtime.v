// riscv_mtime.v — Machine Timer (MTIME / MTIMECMP)
//
// RISC-V privileged spec §3.2.1
//   MTIME     : 64-bit real-time counter, increments every tick
//   MTIMECMP  : 64-bit compare register
//   Interrupt : timer_irq = (MTIME >= MTIMECMP) && mie_mtie
//
// Memory map (base = 0x2000_0000):
//   +0x00  mtime    [31:0]
//   +0x04  mtime    [63:32]
//   +0x08  mtimecmp [31:0]
//   +0x0C  mtimecmp [63:32]
//
// Usage:
//   - OS boot sets MTIMECMP = MTIME + TICK_CYCLES
//   - On interrupt, trap handler increments MTIMECMP by TICK_CYCLES
//   - timer_irq drives trap_en in CSR_File and pipeline top

`timescale 1ns/1ns

module riscv_mtime #(
    parameter TICK_CYCLES = 1000   // clocks per OS tick (tune per MHz + desired Hz)
)(
    input  wire        clk,
    input  wire        rst_n,

    // Simple memory-mapped I/O port (from pipeline DMEM bridge)
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire        we,
    input  wire        re,
    output reg  [31:0] rdata,

    // Timer interrupt output — goes to CSR File + pipeline
    output wire        timer_irq
);

    // 64-bit counter and compare
    reg [63:0] mtime;
    reg [63:0] mtimecmp;

    // Interrupt: raised when counter reaches compare value
    // Stays high until software writes a new (higher) mtimecmp
    assign timer_irq = (mtime >= mtimecmp);

    // -------------------------------------------------------
    // Counter — free-running, increments every clock
    // -------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mtime <= 64'b0;
        else
            mtime <= mtime + 1;
    end

    // -------------------------------------------------------
    // Write
    // -------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Set mtimecmp to max so no spurious interrupt at boot
            mtimecmp <= 64'hFFFF_FFFF_FFFF_FFFF;
        end else if (we) begin
            case (addr[3:2])   // word-aligned offset
                2'd0: mtimecmp[31:0]  <= wdata;   // 0x00 — mtimecmp lo
                2'd1: mtimecmp[63:32] <= wdata;   // 0x04 — mtimecmp hi
                // mtime is read-only in standard spec; writes silently ignored
                default: ;
            endcase
        end
    end

    // -------------------------------------------------------
    // Read (combinational)
    // -------------------------------------------------------
    always @(*) begin
        rdata = 32'b0;
        if (re) begin
            case (addr[3:2])
                2'd0: rdata = mtime[31:0];
                2'd1: rdata = mtime[63:32];
                2'd2: rdata = mtimecmp[31:0];
                2'd3: rdata = mtimecmp[63:32];
                default: rdata = 32'b0;
            endcase
        end
    end

endmodule
