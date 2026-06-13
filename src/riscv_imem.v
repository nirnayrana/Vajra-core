module riscv_imem (
    input  wire        clk,
    input  wire [31:0] a,
    output wire [31:0] rd
);

    reg [31:0] mem [0:1023];

    wire [7:0] addr = a[11:2];

    assign rd = mem[addr];

    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            mem[i] = 32'h00000013; // NOP

        $readmemh("program.hex", mem, 0, 1023);
    end
    initial begin
        #1;
        $display("==== IMEM DUMP ====");
        for (i = 0; i < 16; i = i + 1)
        $display("mem[%0d] = %h", i, mem[i]);
    end

endmodule
