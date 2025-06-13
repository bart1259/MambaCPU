/* verilator lint_off MULTITOP */
module two_flop_sync 
# (
    parameter WIDTH = 1 // Width of the input data
) (
    input wire clk, // Clock signal
    input wire rst_n, // Reset signal (active low)
    input wire [WIDTH-1:0] in_data, // Input data
    output wire [WIDTH-1:0] out_data // Output data
);

    reg [WIDTH-1:0] sync_reg1; // First stage register
    reg [WIDTH-1:0] sync_reg2; // Second stage register

    assign out_data = sync_reg2; // Output data is from the second stage register

    always @(posedge clk) begin
        if (!rst_n) begin
            sync_reg1 <= 0; // Reset first stage register
            sync_reg2 <= 0; // Reset second stage register
        end else begin
            sync_reg1 <= in_data; // Capture input data
            sync_reg2 <= sync_reg1; // Pass data to second stage register
        end
    end
endmodule
