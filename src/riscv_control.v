module riscv_control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,

    output reg        RegWrite,
    output reg        MemtoReg,
    output reg        MemWrite,
    output reg        Branch,
    output reg [1:0]  ALUOp,
    output reg        ALUSrc,
    output reg        Jump,
    output reg        PCToSrcA
);

    always @(*) begin
        // Default values (VERY IMPORTANT)
        RegWrite  = 0;
        MemtoReg  = 0;
        MemWrite  = 0;
        Branch    = 0;
        ALUOp     = 2'b00;
        ALUSrc    = 0;
        Jump      = 0;
        PCToSrcA  = 0;

        case (opcode)

            // =========================
            // R-Type (ADD, SUB, AND...)
            // =========================
            7'b0110011: begin
                RegWrite = 1;
                ALUOp    = 2'b10;
            end

            // =========================
            // I-Type ALU (ADDI, ORI...)
            // =========================
            7'b0010011: begin
                RegWrite = 1;
                ALUSrc   = 1;
                ALUOp    = 2'b11;
            end

            // =========================
            // LOAD (LB, LH, LW...)
            // =========================
            7'b0000011: begin
                RegWrite = 1;
                MemtoReg = 1;
                ALUSrc   = 1;
                ALUOp    = 2'b00; // ADD for address
            end

            // =========================
            // STORE (SB, SH, SW)
            // =========================
            7'b0100011: begin
                MemWrite = 1;
                ALUSrc   = 1;
                ALUOp    = 2'b00; // ADD for address
            end

            // =========================
            // BRANCH (BEQ, BNE, BLT...)
            // =========================
            7'b1100011: begin
                Branch = 1;
                ALUOp  = 2'b01;
            end

            // =========================
            // JAL
            // =========================
            7'b1101111: begin
                RegWrite = 1;     // Write PC+4
                Jump     = 1;
                ALUSrc   = 1;     // Use immediate
                PCToSrcA = 1;     // Use PC as SrcA
                ALUOp    = 2'b00;
            end

            // =========================
            // JALR
            // =========================
            7'b1100111: begin
                RegWrite = 1;
                Jump     = 1;
                ALUSrc   = 1;
                ALUOp    = 2'b00;
            end

            // =========================
            // LUI
            // =========================
            7'b0110111: begin
                RegWrite = 1;
                ALUSrc   = 1;
                ALUOp    = 2'b11; // Your top uses 2'b11 for LUI
            end

            // =========================
            // AUIPC
            // =========================
            7'b0010111: begin
                RegWrite = 1;
                ALUSrc   = 1;
                PCToSrcA = 1;     // PC + Imm
                ALUOp    = 2'b00;
            end

            default: begin
                // Keep defaults
            end

        endcase
    end

endmodule