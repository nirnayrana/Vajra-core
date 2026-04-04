`timescale 1ns/1ns

// riscv_dmem.v — Data Memory + UART MMIO
// FIXES:
//   1. RAM expanded from 512 words (2 KB) to 1024 words (4 KB) to match the
//      linker.ld LENGTH=4K and start.S stack pointer of 0x2000.
//      Previously the stack pointer (0x2800 in old start.S) was above the
//      2 KB window, causing out-of-bounds aliasing on every stack push/pop.
//
//   2. word_addr widened from 9 bits to 10 bits to correctly index 1024 words.
//      With 9 bits, addresses above 0x17FC wrapped around to RAM[0].
//
//   3. addr_in_ram upper bound corrected to 0x2000 (was 0x3000, which could
//      alias into unmapped space beyond the 4 KB window).
//
//   4. Invalid-address handler changed from $finish to $display warning.
//      $finish was too aggressive: a misaligned pointer from the C toolchain
//      would kill the simulation before any useful output appeared.

module riscv_dmem (
    input  wire        clk,
    input  wire        mem_en,
    input  wire        mem_write,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,

    output reg         io_valid,
    output reg [7:0]   io_data
);

    // 4 KB SRAM: 0x1000–0x1FFF
    reg [31:0] RAM [0:1023];

    wire [31:0] local_addr = addr - 32'h00001000;
    wire [9:0]  word_addr  = local_addr[11:2]; // 10 bits for 1024 words

    wire addr_in_ram  = (addr >= 32'h00001000 && addr < 32'h00002000);
    wire addr_is_uart = (addr[31:28] == 4'h8);

    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            RAM[i] = 32'b0;
    end

    // READ — combinational, only within valid window
    always @(*) begin
        if (mem_en && !mem_write && addr_in_ram)
            rdata = RAM[word_addr];
        else
            rdata = 32'b0;
    end

    // WRITE — synchronous
    always @(posedge clk) begin
        io_valid <= 1'b0;

        if (mem_en && mem_write) begin
            if (addr_is_uart) begin
                // UART MMIO — emit low byte
                io_valid <= 1'b1;
                io_data  <= wdata[7:0];
            end else if (addr_in_ram) begin
                RAM[word_addr] <= wdata;
            end else begin
                // Changed from $finish → $display so simulation continues
                $display("[DMEM] WARNING: write to unmapped address 0x%08h (data=0x%08h) — ignored",
                         addr, wdata);
            end
        end
    end

endmodule
