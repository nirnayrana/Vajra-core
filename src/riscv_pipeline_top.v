`timescale 1ns/1ns

// riscv_pipeline_top.v — with preemptive timer interrupt support
//
// NEW vs previous version:
//   1. riscv_mtime peripheral at 0x2000_0000.
//   2. CSR_File: timer_irq, mret_en, irq_pending ports.
//   3. Interrupt injection at IF stage: irq_pending flushes pipeline, redirects PC to mtvec.
//   4. MRET detection in WB: redirects PC to mepc, restores MIE via CSR_File.
//   5. trap_active one-cycle lock prevents double-trap.

module riscv_pipeline_top (
    input  wire        clk,
    input  wire        rst,
    input  wire [1:0]  debug_sel,
    output wire [9:0]  led
);

wire [31:0] Result_W;
reg  [4:0]  Rd_W;
reg         RegWrite_W, MemtoReg_W;

reg  [31:0] ALUResult_M, WriteData_M;
reg  [4:0]  Rd_M;
reg         RegWrite_M, MemtoReg_M, MemWrite_M;
reg  [31:0] PCPlus4_M;
reg         Jump_M;

reg  [31:0] RD1_E, RD2_E, PC_E, Imm_E;
reg  [4:0]  Rs1_E, Rs2_E, Rd_E;
reg  [3:0]  ALUControl_E;
reg  [2:0]  Funct3_E;
reg         RegWrite_E, MemtoReg_E, MemWrite_E;
reg         Branch_E, Jump_E, ALUSrc_E, PCToSrcA_E;
reg         IsCSR_E;
reg  [11:0] CSRAddr_E;

reg  [31:0] ReadData_W, ALUResult_W;
reg  [31:0] PCPlus4_W;
reg         Jump_W;
reg         IsCSR_W;
reg  [11:0] CSRAddr_W;
reg  [31:0] CSRWData_W;
reg         IsMRET_W;

reg  [1:0]  ForwardA, ForwardB;

wire [31:0] ReadData_M;
wire        io_valid;
wire [7:0]  io_data;
wire        MemWait;

// CSR/interrupt wires
wire [31:0] csr_rdata_D;
wire [31:0] mepc_out;
wire [31:0] mtvec_out;
wire        irq_pending;
wire        timer_irq;

reg         trap_en;
reg  [31:0] trap_pc;
reg  [31:0] trap_cause;
reg         trap_active;

wire mtime_sel_M  = (ALUResult_M[31:4] == 28'h2000000);
wire mtime_we_M   = MemWrite_M  && mtime_sel_M;
wire mtime_re_M   = MemtoReg_M  && mtime_sel_M;
wire [31:0] mtime_rdata;

wire mret_en_W = IsMRET_W;
wire Flush_trap = trap_en | mret_en_W;

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
    else if (mret_en_W)
        PC_F <= mepc_out;
    else if (trap_en)
        PC_F <= mtvec_out;
    else if (PCSrc_E)
        PC_F <= PC_Target_E;
    else
        PC_F <= PC_F + 4;
end

riscv_imem IMEM (.clk(clk), .a(PC_F), .rd(Instr_F));

////////////////////////////////////////////////////////////
// INTERRUPT DETECTION
////////////////////////////////////////////////////////////

always @(posedge clk or posedge rst) begin
    if (rst) begin
        trap_en <= 0; trap_pc <= 0; trap_cause <= 0; trap_active <= 0;
    end else begin
        trap_active <= trap_en;
        trap_en     <= 0;
        if (irq_pending && !trap_active && !MemWait && !PCSrc_E) begin
            trap_en    <= 1;
            trap_pc    <= PC_F;
            trap_cause <= 32'h8000_0007; // interrupt, cause=7 (machine timer)
        end
    end
end

////////////////////////////////////////////////////////////
// IF/ID register
////////////////////////////////////////////////////////////

reg [31:0] Instr_D, PC_D;

always @(posedge clk or posedge rst) begin
    if (rst || Flush_D || Flush_trap) begin
        Instr_D <= 32'h00000013; PC_D <= 0;
    end else if (!Stall_D) begin
        Instr_D <= Instr_F; PC_D <= PC_F;
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
wire Branch_D, Jump_D, ALUSrc_D, PCToSrcA_D;
wire [1:0] ALUOp_D;
wire [3:0] ALUControl_D;

riscv_regfile REG_FILE (
    .clk(clk), .rst(rst), .we3(RegWrite_W),
    .a1(Rs1_D), .a2(Rs2_D), .a3(Rd_W),
    .wd3(Result_W), .rd1(RD1_D), .rd2(RD2_D)
);

riscv_control CONTROL (
    .opcode(Instr_D[6:0]), .funct3(Instr_D[14:12]), .funct7(Instr_D[31:25]),
    .RegWrite(RegWrite_D), .MemtoReg(MemtoReg_D), .MemWrite(MemWrite_D),
    .Branch(Branch_D), .ALUOp(ALUOp_D), .ALUSrc(ALUSrc_D),
    .Jump(Jump_D), .PCToSrcA(PCToSrcA_D)
);

riscv_alu_decoder ALU_DEC (
    .alu_op(ALUOp_D), .funct3(Instr_D[14:12]),
    .funct7(Instr_D[30]), .op(Instr_D[6:0]),
    .alu_ctrl(ALUControl_D)
);

wire IsCSR_D  = (Instr_D[6:0] == 7'b1110011) && (Instr_D[14:12] != 3'b000);
wire IsMRET_D = (Instr_D[6:0] == 7'b1110011) && (Instr_D[31:20] == 12'b0011_0000_0010);

CSR_File CSR (
    .clk(clk), .rst_n(~rst),
    .csr_addr(Instr_D[31:20]),
    .csr_rdata(csr_rdata_D),
    .wb_csr_addr(CSRAddr_W),
    .wb_csr_wdata(CSRWData_W),
    .wb_csr_write_en(IsCSR_W),
    .mret_en(mret_en_W),
    .timer_irq(timer_irq),
    .trap_en(trap_en),
    .pc_in(trap_pc),
    .cause_in(trap_cause),
    .mepc_out(mepc_out),
    .mtvec_out(mtvec_out),
    .irq_pending(irq_pending)
);

wire [31:0] Imm_D =
    (Instr_D[6:0]==7'b0010011||Instr_D[6:0]==7'b0000011||Instr_D[6:0]==7'b1100111) ?
        {{20{Instr_D[31]}}, Instr_D[31:20]} :
    (Instr_D[6:0]==7'b0100011) ?
        {{20{Instr_D[31]}}, Instr_D[31:25], Instr_D[11:7]} :
    (Instr_D[6:0]==7'b1100011) ?
        {{20{Instr_D[31]}}, Instr_D[7], Instr_D[30:25], Instr_D[11:8], 1'b0} :
    (Instr_D[6:0]==7'b0110111||Instr_D[6:0]==7'b0010111) ?
        {Instr_D[31:12], 12'b0} :
    (Instr_D[6:0]==7'b1101111) ?
        {{12{Instr_D[31]}}, Instr_D[19:12], Instr_D[20], Instr_D[30:21], 1'b0} :
    32'b0;

////////////////////////////////////////////////////////////
// ID/EX register
////////////////////////////////////////////////////////////

always @(posedge clk or posedge rst) begin
    if (rst || Flush_E || Flush_trap) begin
        RD1_E<=0; RD2_E<=0; PC_E<=0; Imm_E<=0;
        Rs1_E<=0; Rs2_E<=0; Rd_E<=0;
        ALUControl_E<=0; Funct3_E<=0;
        RegWrite_E<=0; MemtoReg_E<=0; MemWrite_E<=0;
        Branch_E<=0; Jump_E<=0; ALUSrc_E<=0; PCToSrcA_E<=0;
        IsCSR_E<=0; CSRAddr_E<=0;
    end else begin
        RD1_E<=RD1_D; RD2_E<=RD2_D; PC_E<=PC_D; Imm_E<=Imm_D;
        Rs1_E<=Rs1_D; Rs2_E<=Rs2_D; Rd_E<=Rd_D;
        ALUControl_E<=ALUControl_D; Funct3_E<=Instr_D[14:12];
        RegWrite_E<=RegWrite_D; MemtoReg_E<=MemtoReg_D;
        MemWrite_E<=MemWrite_D; Branch_E<=Branch_D; Jump_E<=Jump_D;
        ALUSrc_E<=ALUSrc_D; PCToSrcA_E<=PCToSrcA_D;
        IsCSR_E<=IsCSR_D; CSRAddr_E<=Instr_D[31:20];
    end
end

////////////////////////////////////////////////////////////
// FORWARDING
////////////////////////////////////////////////////////////

always @(*) begin
    ForwardA = 2'b00; ForwardB = 2'b00;
    if      (RegWrite_M&&(Rd_M!=0)&&(Rd_M==Rs1_E)) ForwardA = 2'b10;
    else if (RegWrite_W&&(Rd_W!=0)&&(Rd_W==Rs1_E)) ForwardA = 2'b01;
    if      (RegWrite_M&&(Rd_M!=0)&&(Rd_M==Rs2_E)) ForwardB = 2'b10;
    else if (RegWrite_W&&(Rd_W!=0)&&(Rd_W==Rs2_E)) ForwardB = 2'b01;
end

////////////////////////////////////////////////////////////
// EXECUTE
////////////////////////////////////////////////////////////

wire [31:0] SrcA_E =
    PCToSrcA_E          ? PC_E        :
    (ForwardA==2'b10)   ? ALUResult_M :
    (ForwardA==2'b01)   ? Result_W    : RD1_E;

wire [31:0] SrcB_raw =
    (ForwardB==2'b10) ? ALUResult_M :
    (ForwardB==2'b01) ? Result_W    : RD2_E;

wire [31:0] SrcB_E = ALUSrc_E ? Imm_E : SrcB_raw;
wire [31:0] ALUResult_E;
wire        Zero_E;

riscv_alu4b ALU (
    .SrcA(SrcA_E), .SrcB(SrcB_E),
    .ALUControl(ALUControl_E),
    .ALUResult(ALUResult_E), .Zero(Zero_E)
);

assign PC_Target_E = Jump_E ? (ALUResult_E & ~32'h1) : (PC_E + Imm_E);

wire BranchTaken = Branch_E && (
    (Funct3_E==3'b000 &&  Zero_E) ||
    (Funct3_E==3'b001 && !Zero_E) ||
    (Funct3_E==3'b100 && !Zero_E) ||
    (Funct3_E==3'b101 &&  Zero_E) ||
    (Funct3_E==3'b110 && !Zero_E) ||
    (Funct3_E==3'b111 &&  Zero_E)
);

assign PCSrc_E = BranchTaken | Jump_E;

////////////////////////////////////////////////////////////
// HAZARD
////////////////////////////////////////////////////////////

wire LoadUseHazard = MemtoReg_E && ((Rd_E==Rs1_D)||(Rd_E==Rs2_D));
assign Stall_F = LoadUseHazard | MemWait;
assign Stall_D = LoadUseHazard | MemWait;
assign Flush_D = PCSrc_E;
assign Flush_E = PCSrc_E | LoadUseHazard;

////////////////////////////////////////////////////////////
// EX/MEM register
////////////////////////////////////////////////////////////

wire [31:0] WriteData_E =
    (ForwardB==2'b10) ? ALUResult_M :
    (ForwardB==2'b01) ? Result_W    : RD2_E;

wire [31:0] PCPlus4_E = PC_E + 4;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ALUResult_M<=0; WriteData_M<=0; Rd_M<=0;
        RegWrite_M<=0; MemtoReg_M<=0; MemWrite_M<=0;
        PCPlus4_M<=0; Jump_M<=0;
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

riscv_mtime #(.TICK_CYCLES(1000)) MTIME (
    .clk(clk), .rst_n(~rst),
    .addr(ALUResult_M),
    .wdata(WriteData_M),
    .we(mtime_we_M), .re(mtime_re_M),
    .rdata(mtime_rdata),
    .timer_irq(timer_irq)
);

wire dmem_en = (MemWrite_M | MemtoReg_M) && !mtime_sel_M;

riscv_dmem DMEM (
    .clk(clk),
    .mem_en(dmem_en),
    .mem_write(MemWrite_M && !mtime_sel_M),
    .addr(ALUResult_M),
    .wdata(WriteData_M),
    .rdata(ReadData_M),
    .io_valid(io_valid),
    .io_data(io_data)
);

assign MemWait = 1'b0;

wire [31:0] ReadData_Mux = mtime_sel_M ? mtime_rdata : ReadData_M;

////////////////////////////////////////////////////////////
// MEM/WB register
////////////////////////////////////////////////////////////

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ReadData_W<=0; ALUResult_W<=0; Rd_W<=0;
        RegWrite_W<=0; MemtoReg_W<=0;
        PCPlus4_W<=0; Jump_W<=0;
        IsCSR_W<=0; CSRAddr_W<=0; CSRWData_W<=0; IsMRET_W<=0;
    end else if (!MemWait) begin
        ReadData_W  <= ReadData_Mux;
        ALUResult_W <= ALUResult_M;
        Rd_W        <= Rd_M;
        RegWrite_W  <= RegWrite_M;
        MemtoReg_W  <= MemtoReg_M;
        PCPlus4_W   <= PCPlus4_M;
        Jump_W      <= Jump_M;
        IsCSR_W     <= IsCSR_E;
        CSRAddr_W   <= CSRAddr_E;
        CSRWData_W  <= RD1_E;
        IsMRET_W    <= IsMRET_D && !Flush_trap;
    end
end

////////////////////////////////////////////////////////////
// WRITEBACK
////////////////////////////////////////////////////////////

assign Result_W =
    MemtoReg_W ? ReadData_W  :
    Jump_W     ? PCPlus4_W   :
    IsCSR_W    ? csr_rdata_D :
                 ALUResult_W;

////////////////////////////////////////////////////////////
// DEBUG
////////////////////////////////////////////////////////////

assign led =
    (debug_sel==2'b00) ? PC_F[9:0]           :
    (debug_sel==2'b01) ? ALUResult_E[9:0]    :
    (debug_sel==2'b10) ? Result_W[9:0]       :
                         {6'b0,Stall_F,Flush_D,Flush_E,PCSrc_E};

endmodule
