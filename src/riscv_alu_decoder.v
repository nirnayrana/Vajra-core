`timescale 1ns/1ns

// riscv_alu_decoder.v
// FIXES:
//   1. SLT  (funct3=010): was 4'b1000, must be 4'b0101 (matches riscv_alu4b case)
//   2. SLTU (funct3=011): was 4'b1001, must be 4'b0110
//   3. SLL  (funct3=001): was 4'b0101, must be 4'b0111
//   4. SRL  (funct3=101): was 4'b0110, must be 4'b1000
//   5. SRA  (funct3=101): was 4'b0111, must be 4'b1001
//   6. LUI  (alu_op=2'b11): was ADD(4'b0000), must be SrcB-pass(4'b1010)
//      LUI writes Imm directly to rd. SrcA could be any register value,
//      so ADD is wrong. 4'b1010 passes SrcB (the immediate) straight through.
//   7. Branches now decode funct3 so BNE/BLT/BGE/BLTU/BGEU work correctly.
//      BEQ/BNE → SUB  (check Zero)
//      BLT/BGE  → SLT (check Zero for signed comparison result)
//      BLTU/BGEU→ SLTU (check Zero for unsigned comparison result)

module riscv_alu_decoder (
    input  wire [1:0] alu_op,
    input  wire [2:0] funct3,
    input  wire       funct7,   // Instr[30]
    input  wire [6:0] op,
    output reg  [3:0] alu_ctrl
);

    always @(*) begin
        case (alu_op)

            // LW / SW — address = rs1 + imm (ADD)
            2'b00: alu_ctrl = 4'b0000;

            // Branch — select comparison from funct3
            2'b01: begin
                case (funct3)
                    3'b000, 3'b001: alu_ctrl = 4'b0001; // BEQ/BNE  → SUB
                    3'b100, 3'b101: alu_ctrl = 4'b0101; // BLT/BGE  → SLT (signed)
                    3'b110, 3'b111: alu_ctrl = 4'b0110; // BLTU/BGEU→ SLTU (unsigned)
                    default:        alu_ctrl = 4'b0001;
                endcase
            end

            // R-type / I-type ALU ops
            2'b10: begin
                case (funct3)
                    3'b000: begin
                        // SUB only when R-type (op[5]=1) AND funct7[5]=1
                        if (op[5] && funct7) alu_ctrl = 4'b0001; // SUB
                        else                 alu_ctrl = 4'b0000; // ADD / ADDI
                    end
                    3'b001: alu_ctrl = 4'b0111;                  // SLL
                    3'b010: alu_ctrl = 4'b0101;                  // SLT
                    3'b011: alu_ctrl = 4'b0110;                  // SLTU
                    3'b100: alu_ctrl = 4'b0100;                  // XOR
                    3'b101: alu_ctrl = funct7 ? 4'b1001 : 4'b1000; // SRA : SRL
                    3'b110: alu_ctrl = 4'b0011;                  // OR
                    3'b111: alu_ctrl = 4'b0010;                  // AND
                    default: alu_ctrl = 4'b0000;
                endcase
            end

            // LUI — pass immediate (SrcB) straight through to rd
            // SrcA for LUI is some register value; using ADD would corrupt the result.
            2'b11: alu_ctrl = 4'b1010;

            default: alu_ctrl = 4'b0000;
        endcase
    end

endmodule
