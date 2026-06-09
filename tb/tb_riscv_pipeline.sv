`timescale 1ns/1ps

// tb_riscv_pipeline.sv — updated for preemptive scheduler
//
// Changes from previous version:
//   - Timeout increased to 100000 cycles (scheduler needs time to tick)
//   - UART finish condition removed (OS runs forever; sim ends on timeout or PASS)
//   - Timer IRQ monitor: prints when trap fires and when MRET executes
//   - Trap counter: counts context switches, PASS if >= 3 (proves scheduler runs)

module tb_riscv_pipeline;

parameter CLK_PERIOD     = 10;
parameter TIMEOUT_CYCLES = 100_000;
parameter ENABLE_TRACE   = 0;      // set 1 for full pipeline trace (very verbose)
parameter ENABLE_UART    = 1;
parameter MIN_SWITCHES   = 3;      // PASS when scheduler has run at least this many times

reg        clk;
reg        rst;
reg [1:0]  debug_sel;
wire [9:0] led;
integer    cycle_count;
integer    switch_count;

riscv_pipeline_top dut (
    .clk(clk), .rst(rst),
    .debug_sel(debug_sel),
    .led(led)
);

// Clock
initial begin clk = 0; forever #(CLK_PERIOD/2) clk = ~clk; end

// Reset
initial begin
    rst = 1; debug_sel = 2'b10;
    cycle_count = 0; switch_count = 0;
    repeat(5) @(posedge clk);
    rst = 0;
end

// Cycle counter
always @(posedge clk) if (!rst) cycle_count <= cycle_count + 1;

// --------------------------------------------------------
// UART output
// --------------------------------------------------------
generate
if (ENABLE_UART) begin
    always @(posedge clk) begin
        if (!rst && dut.DMEM.io_valid)
            $write("%c", dut.DMEM.io_data);
    end
end
endgenerate

// --------------------------------------------------------
// Pipeline trace (optional, very verbose)
// --------------------------------------------------------
generate
if (ENABLE_TRACE) begin
    always @(posedge clk) begin
        if (!rst) begin
            $display("Cycle:%0d PC=0x%08h Instr=0x%08h Result=%0d",
                cycle_count, dut.PC_F, dut.Instr_F, dut.Result_W);
        end
    end
end
endgenerate

// --------------------------------------------------------
// Trap / context-switch monitor
// --------------------------------------------------------
always @(posedge clk) begin
    if (!rst) begin
        // Detect trap_en assertion (interrupt taken)
        if (dut.trap_en) begin
            $display("[TB] cycle=%0d  TRAP TAKEN  PC=0x%08h  cause=0x%08h",
                     cycle_count, dut.trap_pc, dut.trap_cause);
        end
        // Detect MRET in WB stage
        if (dut.IsMRET_W) begin
            switch_count = switch_count + 1;
            $display("[TB] cycle=%0d  MRET (context switch #%0d)  mepc=0x%08h",
                     cycle_count, switch_count, dut.mepc_out);
            if (switch_count >= MIN_SWITCHES) begin
                $display("\n[PASS] Preemptive scheduler verified: %0d context switches", switch_count);
                $finish;
            end
        end
    end
end

// --------------------------------------------------------
// Timeout
// --------------------------------------------------------
always @(posedge clk) begin
    if (cycle_count > TIMEOUT_CYCLES) begin
        $display("\n[TIMEOUT] cycles=%0d  switches=%0d  PC=0x%08h",
                 cycle_count, switch_count, dut.PC_F);
        $display("irq_pending=%b  timer_irq=%b  mtvec=0x%08h  mepc=0x%08h",
                 dut.irq_pending, dut.timer_irq, dut.mtvec_out, dut.mepc_out);
        $finish;
    end
end

// Waveform
initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_riscv_pipeline);
end

endmodule
