module register_file (
`ifdef USE_POWER_PINS
    inout  vccd1,
    inout  vssd1,
`endif
    input  wire        clk,
    input  wire        rst_n,

    // Read port for r1
    input  wire [4:0]  read_addr_1,
    output wire [31:0] read_data_1,

    // Read port for r2
    input  wire [4:0]  read_addr_2,
    output wire [31:0] read_data_2,

    // Read port for r3
    input  wire [4:0]  read_addr_3,
    output wire [31:0] read_data_3,

    // Write port
    input  wire        write_en,
    input  wire [4:0]  write_addr,
    input  wire [31:0] write_data
);

    // Internal array of 32 registers, each 32 bits.
    reg [31:0] reg_array [0:31];
    integer i;
    
    // Asynchronous (combinational) read: just wire outputs to internal storage
    assign read_data_1 = reg_array[read_addr_1];
    assign read_data_2 = reg_array[read_addr_2];
    assign read_data_3 = reg_array[read_addr_3];

    // Synchronous write on rising edge of clk
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset all registers to 0
            for (i = 0; i < 32; i = i + 1) begin
                reg_array[i] <= 32'd0;
            end
        end else if (write_en) begin
            // Write data into the register file
            reg_array[write_addr] <= write_data;
        end
    end

endmodule
