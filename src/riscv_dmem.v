// riscv_dmem.v — Data Memory + UART MMIO
// Fixed:
//   1. Address range now correctly 0x1000–0x2FFF (was 0x400–0x2FFF, mismatched local_addr base)
//   2. Read address guard uses same range as write (0x1000–0x2FFF)
//   3. word_addr derived from local_addr = addr - 0x1000, only used inside valid range
//   4. Added out-of-range read guard returns 0 (no garbage from underflowed word_addr)

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

    reg [31:0] RAM [0:511]; // 2 KB: 0x1000 – 0x2FFF

    // FIX 1: base is 0x1000, not 0x0 or 0x400
    wire [31:0] local_addr = addr - 32'h00001000;
    wire [8:0]  word_addr  = local_addr[10:2];

    // FIX 2: valid RAM window matches local_addr base
    wire addr_in_ram  = (addr >= 32'h00001000 && addr < 32'h00003000);
    wire addr_is_uart = (addr[31:28] == 4'h8);

    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1)
            RAM[i] = 0;
    end

    // READ — combinational
    // FIX 3: only index RAM when address is actually in range;
    //        previously addr >= 0x400 passed the guard but
    //        local_addr = addr - 0x1000 underflowed for 0x400–0xFFF,
    //        producing a garbage word_addr and reading stale RAM content.
    always @(*) begin
        if (mem_en && !mem_write && addr_in_ram)
            rdata = RAM[word_addr];
        else
            rdata = 32'b0;
    end

    // WRITE — synchronous
    always @(posedge clk) begin
        io_valid <= 0;

        if (mem_en && mem_write) begin
            $display("DMEM WRITE: addr=%h data=%h", addr, wdata);

            if (addr_is_uart) begin
                // UART MMIO: 0x8000_0000 and up
                io_valid <= 1;
                io_data  <= wdata[7:0];

            end else if (addr_in_ram) begin
                RAM[word_addr] <= wdata;

            end else begin
                $display("❌ INVALID WRITE ADDRESS: %h", addr);
                $finish;
            end
        end
    end

endmodule