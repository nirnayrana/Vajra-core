`timescale 1ns/1ns

// riscv_axi_ram.v — AXI4-Lite RAM + UART MMIO slave
// Fixed:
//   1. UART check: was (S_AXI_AWADDR == 32'h80000000) full compare.
//      RAM index S_AXI_AWADDR[11:2] is only 10 bits (0–1023).
//      A write to 0x80000000 gives index 0x20000000 >> 2 = out of bounds.
//      Now uses addr[31:28] == 4'h8 (same as riscv_dmem.v), consistent
//      across both memory paths.
//   2. RAM write strobe: applies S_AXI_WSTRB byte-enable lanes correctly
//      so sub-word stores (SB, SH) don't corrupt neighbouring bytes.
//   3. Read: only respond from RAM if address is not UART region.

module riscv_axi_ram (
    input wire clk,
    input wire rst,

    // AXI4-Lite Slave
    input  wire [31:0] S_AXI_AWADDR,
    input  wire        S_AXI_AWVALID,
    output reg         S_AXI_AWREADY,

    input  wire [31:0] S_AXI_WDATA,
    input  wire        S_AXI_WVALID,
    input  wire [3:0]  S_AXI_WSTRB,
    output reg         S_AXI_WREADY,

    output reg  [1:0]  S_AXI_BRESP,
    output reg         S_AXI_BVALID,
    input  wire        S_AXI_BREADY,

    input  wire [31:0] S_AXI_ARADDR,
    input  wire        S_AXI_ARVALID,
    output reg         S_AXI_ARREADY,

    output reg  [31:0] S_AXI_RDATA,
    output reg  [1:0]  S_AXI_RRESP,
    output reg         S_AXI_RVALID,
    input  wire        S_AXI_RREADY
);

    reg [31:0] RAM [0:1023]; // 4 KB

    // FIX 1: decode UART by top nibble, consistent with riscv_dmem.v
    wire wr_is_uart = (S_AXI_AWADDR[31:28] == 4'h8);
    wire rd_is_uart = (S_AXI_ARADDR[31:28] == 4'h8);

    wire [9:0] wr_idx = S_AXI_AWADDR[11:2];
    wire [9:0] rd_idx = S_AXI_ARADDR[11:2];

    localparam IDLE = 0, WRITE_RESP = 1, READ_RESP = 2;
    reg [1:0] state;

    always @(posedge clk) begin
        if (rst) begin
            S_AXI_AWREADY <= 0; S_AXI_WREADY <= 0; S_AXI_BVALID <= 0;
            S_AXI_ARREADY <= 0; S_AXI_RVALID <= 0;
            S_AXI_RRESP <= 0;   S_AXI_BRESP <= 0;
            state <= IDLE;
        end else begin
            case (state)

                IDLE: begin
                    S_AXI_AWREADY <= 1;
                    S_AXI_WREADY  <= 1;
                    S_AXI_ARREADY <= 1;

                    if (S_AXI_AWVALID && S_AXI_WVALID) begin
                        S_AXI_AWREADY <= 0;
                        S_AXI_WREADY  <= 0;

                        if (wr_is_uart) begin
                            // UART MMIO — print char to sim console
                            $write("%c", S_AXI_WDATA[7:0]);
                        end else begin
                            // FIX 2: byte-enable write (respects SB/SH/SW)
                            if (S_AXI_WSTRB[0]) RAM[wr_idx][ 7: 0] <= S_AXI_WDATA[ 7: 0];
                            if (S_AXI_WSTRB[1]) RAM[wr_idx][15: 8] <= S_AXI_WDATA[15: 8];
                            if (S_AXI_WSTRB[2]) RAM[wr_idx][23:16] <= S_AXI_WDATA[23:16];
                            if (S_AXI_WSTRB[3]) RAM[wr_idx][31:24] <= S_AXI_WDATA[31:24];
                        end

                        S_AXI_BRESP  <= 2'b00; // OKAY
                        S_AXI_BVALID <= 1;
                        state <= WRITE_RESP;
                    end

                    if (S_AXI_ARVALID) begin
                        S_AXI_ARREADY <= 0;
                        // FIX 3: don't serve RAM data for UART reads
                        S_AXI_RDATA  <= rd_is_uart ? 32'b0 : RAM[rd_idx];
                        S_AXI_RRESP  <= 2'b00;
                        S_AXI_RVALID <= 1;
                        state <= READ_RESP;
                    end
                end

                WRITE_RESP: begin
                    if (S_AXI_BREADY) begin
                        S_AXI_BVALID <= 0;
                        state <= IDLE;
                    end
                end

                READ_RESP: begin
                    if (S_AXI_RREADY) begin
                        S_AXI_RVALID <= 0;
                        state <= IDLE;
                    end
                end

            endcase
        end
    end

endmodule