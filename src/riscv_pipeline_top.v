`timescale 1ns/1ns

// riscv_pipeline_top.v
// FIXES:
//   1. EX/MEM pipeline register: removed "|| LoadUseHazard" from reset condition.
//      Previously the load instruction was zeroed out as it moved from EX to MEM,
//      so the subsequent load-use dependent instruction always read 0 instead of
//      the loaded value. Now the load flows through to MEM normally; only the
//      instruction in the EX stage (the dependent one) is flushed via Flush_E.
//
//   2. JALR target: was always PC_E + Imm_E (correct for JAL, wrong for JALR).
//      For JALR the target is (rs1 + imm) & ~1 = ALUResult_E & ~1.
//      For JAL  the ALU also computes PC + Imm (PCToSrcA_E=1 → SrcA=PC_E),
//      so using ALUResult_E is correct for both. Branch targets still use
//      the dedicated PC_E + Imm_E path (Jump_E = 0 for branches).
//
//   3. Full branch support: added Funct3_E pipeline register. PCSrc_E now
//      evaluates all six branch conditions (BEQ/BNE/BLT/BGE/BLTU/BGEU)
//      using the ALU result (Zero flag) instead of hard-coding BEQ only.
//      The ALU decoder (riscv_alu_decoder.v) already generates the right
//      ALU op per funct3 (SUB for BEQ/BNE, SLT for BLT/BGE, SLTU for
//      BLTU/BGEU), so Zero_E carries the correct comparison result.
//
//   4. Removed dead registers PCSrc_E_r, PCSrc_r, PC_Target_r that were
//      declared but never read.

module riscv_pipeline_top (
    input  wire        clk,
    input  wire        rst,
    input  wire [1:0]  debug_sel,
    output wire [9:0]  led
);

////////////////////////////////////////////////////////////
// GLOBAL WIRES — writeback result visible to forwarding
////////////////////////////////////////////////////////////

wire [31:0] Result_W;
reg  [4:0]  Rd_W;
reg         RegWrite_W, MemtoReg_W;

// MEMORY stage regs
reg  [31:0] ALUResult_M, WriteData_M;
reg  [4:0]  Rd_M;
reg         RegWrite_M, MemtoReg_M, MemWrite_M;
reg  [31:0] PCPlus4_M;
reg         Jump_M;

// EXECUTE stage regs (ID/EX pipeline register)
reg  [31:0] RD1_E, RD2_E, PC_E, Imm_E;
reg  [4:0]  Rs1_E, Rs2_E, Rd_E;
reg  [3:0]  ALUControl_E;
reg  [2:0]  Funct3_E;        // FIX 3: needed for full branch decode
reg         RegWrite_E, MemtoReg_E, MemWrite_E;
reg         Branch_E, Jump_E, ALUSrc_E, PCToSrcA_E;

// FORWARDING mux selects
reg  [1:0]  ForwardA, ForwardB;

// MEMORY BUS
wire        mem_busy;
wire [31:0] ReadData_M;
wire        io_valid;
wire [7:0]  io_data;

// STALL / FLUSH control
wire MemWait;

////////////////////////////////////////////////////////////
// FETCH
////////////////////////////////////////////////////////////

reg  [31:0] PC_F;
wire [31:0] Instr_F;
wire        PCSrc_E;
wire [31:0] PC_Target_E;
wire        Stall_F, Stall_D, Flush_D, Flush_E;

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

riscv_imem IMEM (
    .clk(clk),
    .a(PC_F),
    .rd(Instr_F)
);

////////////////////////////////////////////////////////////
// IF / ID  pipeline register
////////////////////////////////////////////////////////////

reg [31:0] Instr_D, PC_D;

always @(posedge clk or posedge rst) begin
    if (rst || Flush_D) begin
        Instr_D <= 32'h00000013; // NOP (ADDI x0, x0, 0)
        PC_D    <= 0;
    end else if (!Stall_D) begin
        Instr_D <= Instr_F;
        PC_D    <= PC_F;
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
wire PCToSrcA_D;
wire [1:0] ALUOp_D;
wire [3:0] ALUControl_D;

riscv_regfile REG_FILE (
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

riscv_control CONTROL (
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

riscv_alu_decoder ALU_DEC (
    .alu_op(ALUOp_D),
    .funct3(Instr_D[14:12]),
    .funct7(Instr_D[30]),
    .op(Instr_D[6:0]),
    .alu_ctrl(ALUControl_D)
);

// Immediate generation
wire [31:0] Imm_D =
    // I-type (ALUI, LOAD, JALR)
    (Instr_D[6:0] == 7'b0010011 ||
     Instr_D[6:0] == 7'b0000011 ||
     Instr_D[6:0] == 7'b1100111) ?
        {{20{Instr_D[31]}}, Instr_D[31:20]} :
    // S-type (STORE)
    (Instr_D[6:0] == 7'b0100011) ?
        {{20{Instr_D[31]}}, Instr_D[31:25], Instr_D[11:7]} :
    // B-type (BRANCH)
    (Instr_D[6:0] == 7'b1100011) ?
        {{20{Instr_D[31]}}, Instr_D[7], Instr_D[30:25], Instr_D[11:8], 1'b0} :
    // U-type (LUI, AUIPC)
    (Instr_D[6:0] == 7'b0110111 ||
     Instr_D[6:0] == 7'b0010111) ?
        {Instr_D[31:12], 12'b0} :
    // J-type (JAL)
    (Instr_D[6:0] == 7'b1101111) ?
        {{12{Instr_D[31]}}, Instr_D[19:12], Instr_D[20], Instr_D[30:21], 1'b0} :
    32'b0;

////////////////////////////////////////////////////////////
// ID / EX  pipeline register
////////////////////////////////////////////////////////////

always @(posedge clk or posedge rst) begin
    if (rst || Flush_E) begin
        RD1_E       <= 0; RD2_E  <= 0;
        PC_E        <= 0; Imm_E  <= 0;
        Rs1_E       <= 0; Rs2_E  <= 0; Rd_E <= 0;
        ALUControl_E<= 0; Funct3_E <= 0;
        RegWrite_E  <= 0; MemtoReg_E <= 0; MemWrite_E <= 0;
        Branch_E    <= 0; Jump_E <= 0;
        ALUSrc_E    <= 0; PCToSrcA_E <= 0;
    end else begin
        RD1_E       <= RD1_D;   RD2_E  <= RD2_D;
        PC_E        <= PC_D;    Imm_E  <= Imm_D;
        Rs1_E       <= Rs1_D;   Rs2_E  <= Rs2_D; Rd_E <= Rd_D;
        ALUControl_E<= ALUControl_D;
        Funct3_E    <= Instr_D[14:12]; // FIX 3: latch funct3 for branch decode
        RegWrite_E  <= RegWrite_D;  MemtoReg_E <= MemtoReg_D;
        MemWrite_E  <= MemWrite_D;
        Branch_E    <= Branch_D;    Jump_E     <= Jump_D;
        ALUSrc_E    <= ALUSrc_D;    PCToSrcA_E <= PCToSrcA_D;
    end
end

////////////////////////////////////////////////////////////
// FORWARDING  (inline — riscv_forwarding.v module not instantiated)
////////////////////////////////////////////////////////////

always @(*) begin
    ForwardA = 2'b00;
    ForwardB = 2'b00;

    if      (RegWrite_M && (Rd_M != 0) && (Rd_M == Rs1_E)) ForwardA = 2'b10;
    else if (RegWrite_W && (Rd_W != 0) && (Rd_W == Rs1_E)) ForwardA = 2'b01;

    if      (RegWrite_M && (Rd_M != 0) && (Rd_M == Rs2_E)) ForwardB = 2'b10;
    else if (RegWrite_W && (Rd_W != 0) && (Rd_W == Rs2_E)) ForwardB = 2'b01;
end

////////////////////////////////////////////////////////////
// EXECUTE
////////////////////////////////////////////////////////////

wire [31:0] SrcA_E =
    PCToSrcA_E          ? PC_E        :   // JAL / AUIPC use PC as SrcA
    (ForwardA == 2'b10) ? ALUResult_M :   // forward from MEM
    (ForwardA == 2'b01) ? Result_W    :   // forward from WB
    RD1_E;

wire [31:0] SrcB_raw =
    (ForwardB == 2'b10) ? ALUResult_M :
    (ForwardB == 2'b01) ? Result_W    :
    RD2_E;

wire [31:0] SrcB_E = ALUSrc_E ? Imm_E : SrcB_raw;

wire [31:0] ALUResult_E;
wire        Zero_E;

riscv_alu4b ALU (
    .SrcA(SrcA_E),
    .SrcB(SrcB_E),
    .ALUControl(ALUControl_E),
    .ALUResult(ALUResult_E),
    .Zero(Zero_E)
);

// FIX 2: JALR target = ALUResult_E & ~1  (rs1 + imm, LSB cleared per spec)
//         JAL  target = ALUResult_E       (PC + J-imm, PCToSrcA_E=1 sets SrcA=PC)
//         Branch target = PC_E + Imm_E   (separate path when Jump_E=0)
assign PC_Target_E = Jump_E ? (ALUResult_E & ~32'h1) : (PC_E + Imm_E);

// FIX 3: Full branch decode — all six RISC-V branch conditions
//   BEQ/BNE  use SUB;  taken when Zero==1/0
//   BLT/BGE  use SLT;  taken when result≠0 / result==0
//   BLTU/BGEU use SLTU; same encoding as SLT group
wire BranchTaken =
    Branch_E && (
        (Funct3_E == 3'b000 &&  Zero_E) ||  // BEQ
        (Funct3_E == 3'b001 && !Zero_E) ||  // BNE
        (Funct3_E == 3'b100 && !Zero_E) ||  // BLT  (SLT result=1 → not zero)
        (Funct3_E == 3'b101 &&  Zero_E) ||  // BGE
        (Funct3_E == 3'b110 && !Zero_E) ||  // BLTU
        (Funct3_E == 3'b111 &&  Zero_E)     // BGEU
    );

assign PCSrc_E = BranchTaken | Jump_E;

////////////////////////////////////////////////////////////
// HAZARD UNIT (inline — riscv_hazard_unit.v module not instantiated)
////////////////////////////////////////////////////////////

wire LoadUseHazard = MemtoReg_E && ((Rd_E == Rs1_D) || (Rd_E == Rs2_D));

assign Stall_F = LoadUseHazard | MemWait;
assign Stall_D = LoadUseHazard | MemWait;
assign Flush_D = PCSrc_E;
assign Flush_E = PCSrc_E | LoadUseHazard;

////////////////////////////////////////////////////////////
// EX / MEM  pipeline register
////////////////////////////////////////////////////////////

wire [31:0] WriteData_E =
    (ForwardB == 2'b10) ? ALUResult_M :
    (ForwardB == 2'b01) ? Result_W    :
    RD2_E;

wire [31:0] PCPlus4_E = PC_E + 4;

// FIX 1: removed "|| LoadUseHazard" from the reset guard.
//   Previously, when a load-use hazard was detected the EX/MEM register was
//   zeroed. That discarded the load instruction (which was in EX, computing its
//   address) right before it moved to the MEM stage, so the load's result was
//   always 0. The only thing that should be flushed is the ID/EX register
//   (Flush_E covers that). The EX/MEM register must latch the load's address
//   so the MEM stage can actually read from data memory one cycle later.
always @(posedge clk or posedge rst) begin
    if (rst) begin                          // FIX: was (rst || LoadUseHazard)
        ALUResult_M <= 0; WriteData_M <= 0;
        Rd_M        <= 0;
        RegWrite_M  <= 0; MemtoReg_M <= 0; MemWrite_M <= 0;
        PCPlus4_M   <= 0; Jump_M <= 0;
    end else if (!MemWait) begin
        ALUResult_M <= ALUResult_E;
        WriteData_M <= WriteData_E;
        Rd_M        <= Rd_E;
        RegWrite_M  <= RegWrite_E;
        MemtoReg_M  <= MemtoReg_E;
        MemWrite_M  <= MemWrite_E;
        PCPlus4_M   <= PCPlus4_E;
        Jump_M      <= Jump_E;
    end
end

////////////////////////////////////////////////////////////
// MEMORY
////////////////////////////////////////////////////////////

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
// MEM / WB  pipeline register
////////////////////////////////////////////////////////////

reg [31:0] ReadData_W, ALUResult_W;
reg [31:0] PCPlus4_W;
reg        Jump_W;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ReadData_W  <= 0; ALUResult_W <= 0;
        Rd_W        <= 0;
        RegWrite_W  <= 0; MemtoReg_W <= 0;
        PCPlus4_W   <= 0; Jump_W <= 0;
    end else if (!MemWait) begin
        ReadData_W  <= ReadData_M;
        ALUResult_W <= ALUResult_M;
        Rd_W        <= Rd_M;
        RegWrite_W  <= RegWrite_M;
        MemtoReg_W  <= MemtoReg_M;
        PCPlus4_W   <= PCPlus4_M;
        Jump_W      <= Jump_M;
    end
end

////////////////////////////////////////////////////////////
// WRITEBACK
////////////////////////////////////////////////////////////

assign Result_W =
    MemtoReg_W ? ReadData_W  :
    Jump_W     ? PCPlus4_W   :
                 ALUResult_W;

////////////////////////////////////////////////////////////
// DEBUG OUTPUT
////////////////////////////////////////////////////////////

wire [9:0] debug_pc     = PC_F[9:0];
wire [9:0] debug_alu    = ALUResult_E[9:0];
wire [9:0] debug_result = Result_W[9:0];
wire [9:0] debug_hazard = {6'b0, Stall_F, Flush_D, Flush_E, PCSrc_E};

assign led =
    (debug_sel == 2'b00) ? debug_pc     :
    (debug_sel == 2'b01) ? debug_alu    :
    (debug_sel == 2'b10) ? debug_result :
                           debug_hazard;

endmodule
