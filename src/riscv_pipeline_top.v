`timescale 1ns/1ns

module riscv_pipeline_top (
    input wire clk,
    input wire rst,
    input wire [1:0] debug_sel,
    output wire [9:0] led
);
////////////////////////////////////////////////////////////
// GLOBAL PIPELINE WIRES (DECLARE FIRST)
////////////////////////////////////////////////////////////

// WRITEBACK
wire [31:0] Result_W;
reg  [4:0]  Rd_W;
reg         RegWrite_W;
reg         MemtoReg_W;

// MEMORY
reg  [31:0] ALUResult_M, WriteData_M;
reg  [4:0]  Rd_M;
reg         RegWrite_M, MemtoReg_M, MemWrite_M;

// EXECUTE
reg  [31:0] RD1_E, RD2_E, PC_E, Imm_E;
reg  [4:0]  Rs1_E, Rs2_E, Rd_E;
reg  [3:0]  ALUControl_E;
reg         RegWrite_E, MemtoReg_E, MemWrite_E;
reg         Branch_E, Jump_E, ALUSrc_E;

// FORWARDING
reg [1:0] ForwardA, ForwardB;

// MEMORY BUS
wire mem_busy;
wire [31:0] ReadData_M;

// STALL
wire MemWait;

////////////////////////////////////////////////////////////
// FETCH
////////////////////////////////////////////////////////////

reg [31:0] PC_F;
wire [31:0] PC_Next_F;
wire [31:0] Instr_F;

wire PCSrc_E;
wire [31:0] PC_Target_E;

wire Stall_F, Stall_D, Flush_D, Flush_E;
reg PCSrc_E_r;

always @(posedge clk) begin
    PCSrc_E_r <= PCSrc_E;
end

always @(posedge clk or posedge rst) begin
    if (rst)
        PC_F <= 0;
    else if (Stall_F)
        PC_F <= PC_F;
    else if (PCSrc_E)
        PC_F <= PC_Target_E;
    else
        PC_F <= PC_F + 4;
end

reg        PCSrc_r;
reg [31:0] PC_Target_r;





riscv_imem IMEM (
    .clk(clk),
    .a(PC_F),
    .rd(Instr_F)
);

////////////////////////////////////////////////////////////
// IF / ID
////////////////////////////////////////////////////////////

reg [31:0] Instr_D, PC_D;

always @(posedge clk or posedge rst) begin
    if (rst || Flush_D) begin
        Instr_D <= 32'h00000013; // NOP
        PC_D <= 0;
    end else if (!Stall_D) begin
        Instr_D <= Instr_F;
        PC_D <= PC_F;
    end
end

////////////////////////////////////////////////////////////
// DECODE
////////////////////////////////////////////////////////////

wire [4:0] Rs1_D = Instr_D[19:15];
wire [4:0] Rs2_D = Instr_D[24:20];
wire [4:0] Rd_D  = Instr_D[11:7];

wire [31:0] RD1_D, RD2_D;

wire RegWrite_D, MemtoReg_D, MemWrite_D;
wire Branch_D, Jump_D, ALUSrc_D;
wire [1:0] ALUOp_D;

wire [31:0] Imm_D;

// REGISTER FILE
riscv_regfile REG_FILE(
    .clk(clk),
    .rst(rst),
    .we3(RegWrite_W),
    .a1(Rs1_D),
    .a2(Rs2_D),
    .a3(Rd_W),
    .wd3(Result_W),
    .rd1(RD1_D),
    .rd2(RD2_D)
);

// CONTROL
riscv_control CONTROL(
    .opcode(Instr_D[6:0]),
    .funct3(Instr_D[14:12]),
    .funct7(Instr_D[31:25]),
    .RegWrite(RegWrite_D),
    .MemtoReg(MemtoReg_D),
    .MemWrite(MemWrite_D),
    .Branch(Branch_D),
    .ALUOp(ALUOp_D),
    .ALUSrc(ALUSrc_D),
    .Jump(Jump_D),
    .PCToSrcA(PCToSrcA_D)
);

// IMMEDIATE
assign Imm_D =
    // I-type
    (Instr_D[6:0] == 7'b0010011 || Instr_D[6:0] == 7'b0000011 || Instr_D[6:0] == 7'b1100111) ?
        {{20{Instr_D[31]}}, Instr_D[31:20]} :

    // S-type
    (Instr_D[6:0] == 7'b0100011) ?
        {{20{Instr_D[31]}}, Instr_D[31:25], Instr_D[11:7]} :

    // B-type
    (Instr_D[6:0] == 7'b1100011) ?
        {{20{Instr_D[31]}}, Instr_D[7], Instr_D[30:25], Instr_D[11:8], 1'b0} :

    // U-type (LUI and AUIPC)
    (Instr_D[6:0] == 7'b0110111 || Instr_D[6:0] == 7'b0010111) ?
        {Instr_D[31:12], 12'b0} :

    // J-type (JAL)
    (Instr_D[6:0] == 7'b1101111) ?
        {{12{Instr_D[31]}}, Instr_D[19:12], Instr_D[20], Instr_D[30:21], 1'b0} :

    32'b0;

// ALU DECODER
wire [3:0] ALUControl_D;

riscv_alu_decoder ALU_DEC(
    .alu_op(ALUOp_D),
    .funct3(Instr_D[14:12]),
    .funct7(Instr_D[30]),
    .op(Instr_D[6:0]),
    .alu_ctrl(ALUControl_D)
);

////////////////////////////////////////////////////////////
// ID / EX
////////////////////////////////////////////////////////////







always @(posedge clk or posedge rst) begin
    if (rst || Flush_E) begin
        RD1_E <= 0; RD2_E <= 0; PC_E <= 0; Imm_E <= 0;
        Rs1_E <= 0; Rs2_E <= 0; Rd_E <= 0;
        ALUControl_E <= 0;
        RegWrite_E <= 0; MemtoReg_E <= 0; MemWrite_E <= 0;
        Branch_E <= 0; Jump_E <= 0; ALUSrc_E <= 0;
        PCToSrcA_E <= 0;
    end else begin
        RD1_E <= RD1_D;
        RD2_E <= RD2_D;
        PC_E <= PC_D;
        Imm_E <= Imm_D;
        Rs1_E <= Rs1_D;
        Rs2_E <= Rs2_D;
        Rd_E  <= Rd_D;
        ALUControl_E <= ALUControl_D;

        RegWrite_E <= RegWrite_D;
        MemtoReg_E <= MemtoReg_D;
        MemWrite_E <= MemWrite_D;
        Branch_E <= Branch_D;
        Jump_E <= Jump_D;
        ALUSrc_E <= ALUSrc_D;
        PCToSrcA_E <= PCToSrcA_D;
    end
end

////////////////////////////////////////////////////////////
// FORWARDING
////////////////////////////////////////////////////////////



always @(*) begin
    ForwardA = 2'b00;
    ForwardB = 2'b00;

    if (RegWrite_M && (Rd_M != 0) && (Rd_M == Rs1_E))
        ForwardA = 2'b10;
    else if (RegWrite_W && (Rd_W != 0) && (Rd_W == Rs1_E))
        ForwardA = 2'b01;

    if (RegWrite_M && (Rd_M != 0) && (Rd_M == Rs2_E))
        ForwardB = 2'b10;
    else if (RegWrite_W && (Rd_W != 0) && (Rd_W == Rs2_E))
        ForwardB = 2'b01;
end

////////////////////////////////////////////////////////////
// EXECUTE
////////////////////////////////////////////////////////////
wire [31:0] PCPlus4_E = PC_E + 4;

// PCToSrcA_D: decoded from control unit for AUIPC/JAL
wire PCToSrcA_D;
// Latch through ID/EX register
reg PCToSrcA_E;

wire [31:0] SrcA_E =
    PCToSrcA_E          ? PC_E :
    (ForwardA == 2'b10) ? ALUResult_M :
    (ForwardA == 2'b01) ? Result_W :
    RD1_E;

wire [31:0] SrcB_raw =
    (ForwardB == 2'b10) ? ALUResult_M :
    (ForwardB == 2'b01) ? Result_W :
    RD2_E;

wire [31:0] SrcB_E = ALUSrc_E ? Imm_E : SrcB_raw;

wire [31:0] ALUResult_E;
wire Zero_E;

riscv_alu4b ALU(
    .SrcA(SrcA_E),
    .SrcB(SrcB_E),
    .ALUControl(ALUControl_E),
    .ALUResult(ALUResult_E),
    .Zero(Zero_E)
);

assign PC_Target_E = PC_E + Imm_E;
assign PCSrc_E = (Branch_E & Zero_E) | Jump_E;

////////////////////////////////////////////////////////////
// HAZARD
////////////////////////////////////////////////////////////

wire LoadUseHazard = MemtoReg_E && ((Rd_E == Rs1_D) || (Rd_E == Rs2_D));


assign Stall_F = LoadUseHazard | MemWait;
assign Stall_D = LoadUseHazard | MemWait;

assign Flush_D = PCSrc_E;
assign Flush_E = PCSrc_E | LoadUseHazard;

////////////////////////////////////////////////////////////
// EX / MEM
////////////////////////////////////////////////////////////



reg [31:0] PCPlus4_M;
reg        Jump_M;
wire [31:0] WriteData_E =
    (ForwardB == 2'b10) ? ALUResult_M :
    (ForwardB == 2'b01) ? Result_W :
    RD2_E;

always @(posedge clk or posedge rst) begin
    if (rst || LoadUseHazard) begin
        ALUResult_M <= 0;
        WriteData_M <= 0;
        Rd_M <= 0;
        RegWrite_M <= 0;
        MemtoReg_M <= 0;
        MemWrite_M <= 0;
        PCPlus4_M <= 0;
        Jump_M <= 0;
    end else if (!MemWait) begin
        ALUResult_M <= ALUResult_E;
        WriteData_M <= WriteData_E;
        Rd_M <= Rd_E;
        RegWrite_M <= RegWrite_E;
        MemtoReg_M <= MemtoReg_E;
        MemWrite_M <= MemWrite_E;
        PCPlus4_M <= PCPlus4_E;
        Jump_M <= Jump_E;
    end
end

////////////////////////////////////////////////////////////
// MEMORY
////////////////////////////////////////////////////////////
wire io_valid;
wire [7:0] io_data;

riscv_dmem DMEM (
    .clk(clk),
    .mem_en(MemWrite_M | MemtoReg_M),
    .mem_write(MemWrite_M),
    .addr(ALUResult_M),
    .wdata(WriteData_M),
    .rdata(ReadData_M),
    .io_valid(io_valid),
    .io_data(io_data)
);

assign MemWait = 1'b0;

////////////////////////////////////////////////////////////
// MEM / WB
////////////////////////////////////////////////////////////

reg [31:0] ReadData_W, ALUResult_W;

reg [31:0] PCPlus4_W;
reg        Jump_W;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ReadData_W <= 0;
        ALUResult_W <= 0;
        Rd_W <= 0;
        RegWrite_W <= 0;
        MemtoReg_W <= 0;
        PCPlus4_W <= 0;
        Jump_W <= 0;
    end else if (!MemWait) begin
        ReadData_W <= ReadData_M;
        ALUResult_W <= ALUResult_M;
        Rd_W <= Rd_M;
        RegWrite_W <= RegWrite_M;
        MemtoReg_W <= MemtoReg_M;
        PCPlus4_W <= PCPlus4_M;
        Jump_W <= Jump_M;
    end
end

////////////////////////////////////////////////////////////
// WRITEBACK
////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////
// WRITEBACK
////////////////////////////////////////////////////////////

assign Result_W =
    MemtoReg_W ? ReadData_W :
    Jump_W     ? PCPlus4_W :
                 ALUResult_W;


////////////////////////////////////////////////////////////
// DEBUG
////////////////////////////////////////////////////////////

wire [9:0] debug_pc     = PC_F[9:0];
wire [9:0] debug_alu    = ALUResult_E[9:0];
wire [9:0] debug_result = Result_W[9:0];

wire [9:0] debug_hazard = {
    6'b0,
    Stall_F,
    Flush_D,
    Flush_E,
    PCSrc_E
};
always @(posedge clk) begin
    $display("WB: RegWrite=%b Rd=%d Data=%d",
              RegWrite_W,
              Rd_W,
              Result_W);
end

assign led =
    (debug_sel == 2'b00) ? debug_pc :
    (debug_sel == 2'b01) ? debug_alu :
    (debug_sel == 2'b10) ? debug_result :
                          debug_hazard;

endmodule