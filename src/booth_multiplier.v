module booth_multiplier (
    input signed [31:0] a,
    input signed [31:0] b,
    output signed [31:0] prod
);
    reg signed [63:0] p;
    integer i;

    always @(*) begin
        p = 64'd0;
        p[31:0] = b; // Load multiplier into lower bits
        
        // Basic Booth's Algorithm Implementation
        for (i = 0; i < 32; i = i + 1) begin
            if (p[0] == 1'b1) begin
                p[63:32] = p[63:32] + a;
            end
            p = p >> 1; // Arithmetic Shift Right
        end
    end
    
    assign prod = p[31:0]; // Return lower 32 bits
endmodule