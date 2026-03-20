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

    reg [31:0] RAM [0:511]; // 2KB (for 0x1000–0x2FFF)

    wire [31:0] local_addr = addr - 32'h00001000;
    wire [8:0] word_addr = local_addr[10:2];

    integer i;
    initial begin
        for (i = 0; i < 512; i = i + 1)
            RAM[i] = 0;
    end

    // READ
    always @(*) begin
        if (mem_en && !mem_write &&
            addr >= 32'h00000400 && addr < 32'h00003000)
            rdata = RAM[word_addr];
        else
            rdata = 32'b0;
    end

    // WRITE
    always @(posedge clk) begin
        io_valid <= 0;

        if (mem_en && mem_write) begin
            $display("DMEM WRITE: addr=%h data=%h", addr, wdata);

            if (addr[31:28] == 4'h8) begin
                io_valid <= 1;
                io_data  <= wdata[7:0];

            end else if (addr >= 32'h00000400 && addr < 32'h00003000) begin
                RAM[word_addr] <= wdata;

            end else begin
                $display("❌ INVALID WRITE ADDRESS: %h", addr);
                $finish;
            end
        end
    end

endmodule