`timescale 1ns/1ps

// tb_riscv_pipeline.sv
// FIX: UART output was printed THREE times per character:
//   Block 1 (unconditional, after MAIN CYCLE TRACKER): dut.DMEM.io_valid
//   Block 2 (ENABLE_UART generate):                    dut.DMEM.io_valid
//   Block 3 (bottom of file):                          dut.io_valid
//   dut.io_valid and dut.DMEM.io_valid are the SAME signal.
//
// Resolution: keep only the ENABLE_UART generate block (Block 2), which is
// already guarded with !rst. The newline-detection finish from Block 3 is
// merged into that single block. Blocks 1 and 3 are removed.

module tb_riscv_pipeline;

////////////////////////////////////////////////////////////
// PARAMETERS (CONFIGURABLE)
////////////////////////////////////////////////////////////

parameter CLK_PERIOD      = 10;
parameter TIMEOUT_CYCLES  = 5000;
parameter ENABLE_TRACE    = 1;
parameter ENABLE_REG_DUMP = 1;
parameter ENABLE_UART     = 1;

parameter CHECK_RESULT_W  = 0;
parameter CHECK_REG       = 1;

parameter EXPECTED_RESULT = 32'd15;
parameter CHECK_REG_ADDR  = 15;  // x15 (a5)

////////////////////////////////////////////////////////////
// SIGNALS
////////////////////////////////////////////////////////////

reg        clk;
reg        rst;
reg [1:0]  debug_sel;
wire [9:0] led;
integer    cycle_count;

////////////////////////////////////////////////////////////
// DUT
////////////////////////////////////////////////////////////

riscv_pipeline_top dut (
    .clk(clk),
    .rst(rst),
    .debug_sel(debug_sel),
    .led(led)
);

////////////////////////////////////////////////////////////
// CLOCK
////////////////////////////////////////////////////////////

initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

////////////////////////////////////////////////////////////
// RESET
////////////////////////////////////////////////////////////

initial begin
    rst        = 1;
    debug_sel  = 2'b10;
    cycle_count = 0;
    repeat (5) @(posedge clk);
    rst = 0;
end

////////////////////////////////////////////////////////////
// CYCLE COUNTER
////////////////////////////////////////////////////////////

always @(posedge clk) begin
    if (!rst) cycle_count <= cycle_count + 1;
end

////////////////////////////////////////////////////////////
// CORE TRACE
////////////////////////////////////////////////////////////

generate
if (ENABLE_TRACE) begin
    always @(posedge clk) begin
        if (!rst) begin
            $display("--------------------------------------------------");
            $display("Cycle: %0d | Time: %0t", cycle_count, $time);
            $display("PC        = 0x%08h", dut.PC_F);
            $display("Instr     = 0x%08h", dut.Instr_F);
            $display("Result_W  = %0d",    dut.Result_W);
            $display("MemWait   = %b",     dut.MemWait);
            $display("LED       = %b",     led);
            $display("--------------------------------------------------");
        end
    end
end
endgenerate

////////////////////////////////////////////////////////////
// UART OUTPUT  — single block, with newline-based finish
// FIX: was printed by 3 separate always blocks simultaneously.
////////////////////////////////////////////////////////////

generate
if (ENABLE_UART) begin
    always @(posedge clk) begin
        if (!rst && dut.DMEM.io_valid) begin
            $write("%c", dut.DMEM.io_data);
            // Finish on newline (program signals completion by writing '\n')
            if (dut.DMEM.io_data == 8'h0A) begin
                $display("\n[TB] Program output complete — stopping simulation.");
                $finish;
            end
        end
    end
end
endgenerate

////////////////////////////////////////////////////////////
// REGISTER MONITOR
////////////////////////////////////////////////////////////

generate
if (ENABLE_REG_DUMP) begin
    always @(posedge clk) begin
        if (!rst) begin
            $display("REGS: x1=%0d x2=%0d x3=%0d x10=%0d x15=%0d",
                dut.REG_FILE.rf[1],
                dut.REG_FILE.rf[2],
                dut.REG_FILE.rf[3],
                dut.REG_FILE.rf[10],
                dut.REG_FILE.rf[15]
            );
        end
    end
end
endgenerate

////////////////////////////////////////////////////////////
// PASS CONDITIONS
////////////////////////////////////////////////////////////

generate
if (CHECK_RESULT_W) begin
    always @(posedge clk) begin
        if (!rst && dut.Result_W == EXPECTED_RESULT) begin
            $display("\n[PASS] Result_W = %0d @ cycle %0d", dut.Result_W, cycle_count);
            $finish;
        end
    end
end
endgenerate

generate
if (CHECK_REG) begin
    always @(posedge clk) begin
        if (!rst && dut.REG_FILE.rf[CHECK_REG_ADDR] == EXPECTED_RESULT) begin
            $display("\n[PASS] x%0d = %0d @ cycle %0d",
                     CHECK_REG_ADDR,
                     dut.REG_FILE.rf[CHECK_REG_ADDR],
                     cycle_count);
            $finish;
        end
    end
end
endgenerate

////////////////////////////////////////////////////////////
// X DETECTION
////////////////////////////////////////////////////////////

always @(posedge clk) begin
    if (!rst && ^dut.Result_W === 1'bx) begin
        $display("[ERROR] X detected in Result_W at cycle %0d", cycle_count);
        $finish;
    end
end

////////////////////////////////////////////////////////////
// TIMEOUT
////////////////////////////////////////////////////////////

always @(posedge clk) begin
    if (cycle_count > TIMEOUT_CYCLES) begin
        $display("\n[TIMEOUT] cycle=%0d  PC=0x%08h  Instr=0x%08h  Result_W=%0d  x15=%0d",
                 cycle_count, dut.PC_F, dut.Instr_F, dut.Result_W,
                 dut.REG_FILE.rf[15]);
        $finish;
    end
end

////////////////////////////////////////////////////////////
// WAVEFORM
////////////////////////////////////////////////////////////

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_riscv_pipeline);
end

endmodule
