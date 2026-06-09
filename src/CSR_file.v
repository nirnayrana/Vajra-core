// CSR_file.v — Control & Status Registers
//
// ADDED for preemptive scheduler:
//   mie     (0x304) — Machine Interrupt Enable
//                     bit 7 = MTIE (machine timer interrupt enable)
//   mip     (0x344) — Machine Interrupt Pending  [read-only, driven by hardware]
//                     bit 7 = MTIP (timer interrupt pending)
//   mstatus improvements:
//                     bit 3 = MIE  (global interrupt enable)
//                     bit 7 = MPIE (saved MIE, restored by MRET)
//   mret_en input   — when WB stage executes MRET:
//                     PC <- mepc, MIE <- MPIE
//
// Interrupt taken when:  mstatus.MIE && mie.MTIE && mip.MTIP
// That combined signal (irq_pending) drives trap_en in the pipeline.

module CSR_File (
    input wire clk,
    input wire rst_n,

    // Read Port (ID Stage)
    input  wire [11:0] csr_addr,
    output reg  [31:0] csr_rdata,

    // Write Port (WB Stage)
    input  wire [11:0] wb_csr_addr,
    input  wire [31:0] wb_csr_wdata,
    input  wire        wb_csr_write_en,

    // MRET instruction decoded in WB
    input  wire        mret_en,

    // Hardware interrupt inputs
    input  wire        timer_irq,

    // Trap injection
    input  wire        trap_en,
    input  wire [31:0] pc_in,
    input  wire [31:0] cause_in,

    // Outputs to pipeline
    output wire [31:0] mepc_out,
    output wire [31:0] mtvec_out,
    output wire        irq_pending
);

    reg [31:0] mepc;
    reg [31:0] mcause;
    reg [31:0] mtvec;
    reg [31:0] mstatus;
    reg [31:0] mie;
    wire [31:0] mip;

    // MIP bit7 (MTIP) is wired directly from timer hardware
    assign mip = {24'b0, timer_irq, 7'b0};

    wire mie_global = mstatus[3];
    wire mtie       = mie[7];
    wire mtip       = mip[7];

    assign irq_pending = mie_global & mtie & mtip;

    // Read
    always @(*) begin
        case (csr_addr)
            12'h300: csr_rdata = mstatus;
            12'h304: csr_rdata = mie;
            12'h305: csr_rdata = mtvec;
            12'h341: csr_rdata = mepc;
            12'h342: csr_rdata = mcause;
            12'h344: csr_rdata = mip;
            default: csr_rdata = 32'h0;
        endcase
    end

    // Write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mepc    <= 32'h0;
            mcause  <= 32'h0;
            mtvec   <= 32'h0;
            mstatus <= 32'h0;
            mie     <= 32'h0;
        end
        else if (trap_en) begin
            mepc    <= pc_in;
            mcause  <= cause_in;
            // MPIE <- MIE,  MIE <- 0
            mstatus[7] <= mstatus[3];
            mstatus[3] <= 1'b0;
        end
        else if (mret_en) begin
            // MIE <- MPIE,  MPIE <- 1
            mstatus[3] <= mstatus[7];
            mstatus[7] <= 1'b1;
        end
        else if (wb_csr_write_en) begin
            case (wb_csr_addr)
                12'h300: mstatus <= wb_csr_wdata;
                12'h304: mie     <= wb_csr_wdata;
                12'h305: mtvec   <= wb_csr_wdata;
                12'h341: mepc    <= wb_csr_wdata;
                12'h342: mcause  <= wb_csr_wdata;
                default: ;
            endcase
        end
    end

    assign mepc_out  = mepc;
    assign mtvec_out = mtvec;

endmodule
