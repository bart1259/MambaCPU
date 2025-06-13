parameter ALU_ADD = 4'b0000,
          ALU_SUB = 4'b0001,
          ALU_AND = 4'b0010,
          ALU_OR  = 4'b0011,
          ALU_XOR = 4'b0100,
          ALU_NOT = 4'b0101,
          ALU_SHL = 4'b0110,
          ALU_SHR = 4'b0111,
          ALU_MUL = 4'b1000;

module alu (
`ifdef USE_POWER_PINS
    inout vccd1,
    inout vssd1,
`endif
    input wire clk,
    input wire rst_n,
    input wire cs,

    input wire [31:0] a, // First operand
    input wire [31:0] b, // Second operand
    input wire [3:0] op, // Operation code

    output reg ready, // Indicates if the result is ready
    output reg [31:0] result1, // Final result
    output reg [31:0] result2 // Final result
);

    reg multiplying;
    reg [6:0] counter; // Counter for multiplication
    reg [63:0] product; // Product for multiplication
    reg [63:0] a_temp, b_temp; // Temporary registers for operands

    always @(posedge clk) begin

        if (!rst_n) begin
            ready <= 0;
            result1 <= 0;
            result2 <= 0;
            multiplying <= 0;
            counter <= 0;
            product <= 0;
            a_temp <= 0;
            b_temp <= 0;
        end else begin
            if (cs) begin
                case (op)
                    ALU_ADD: begin
                        result1 <= a + b; // Addition
                        result2 <= 32'b0; // Clear result2 for addition
                        ready <= 1;
                    end
                    ALU_SUB: begin
                        result1 <= a - b; // Subtraction
                        result2 <= 32'b0; // No underflow
                        ready <= 1;
                    end
                    ALU_AND: begin
                        result1 <= a & b; // Bitwise AND
                        result2 <= 32'b0; // Clear result2 for AND
                        ready <= 1;
                    end
                    ALU_OR: begin
                        result1 <= a | b; // Bitwise OR
                        result2 <= 32'b0; // Clear result2 for OR
                        ready <= 1;
                    end
                    ALU_XOR: begin
                        result1 <= a ^ b; // Bitwise XOR
                        result2 <= 32'b0; // Clear result2 for XOR
                        ready <= 1;
                    end
                    ALU_NOT: begin
                        result1 <= ~a; // Bitwise NOT
                        result2 <= 32'b0; // Clear result2 for NOT
                        ready <= 1;
                    end
                    ALU_SHL: begin
                        result1 <= a << b; // Shift left logical
                        result2 <= 32'b0; // Clear result2 for shift left
                        ready <= 1;
                    end
                    ALU_SHR: begin
                        result1 <= a >> b; // Shift right logical
                        result2 <= 32'b0; // Clear result2 for shift right
                        ready <= 1;
                    end
                    ALU_MUL: begin
                        $display("Counter: %d ; Multiplying: %d", counter, multiplying);
                        // Shift and Add Multiplication (https://users.utcluj.ro/~baruch/book_ssce/SSCE-Shift-Mult.pdf)
                        if (counter == 0 && multiplying == 0 && ready == 0) begin
                            // Initiate multiplication
                            multiplying <= 1; // Start multiplication
                            counter <= 32; // Set counter for 32 iterations
                            product <= 0; // Reset product
                            a_temp <= {32'b0, a};
                            b_temp <= {32'b0, b};
                            
                            ready <= 0; 
                        end else if (counter > 0) begin
                            if (b_temp[0] == 1) begin
                                product <= product + {a_temp}; // Add to product if LSB of b is 1
                            end
                            a_temp <= a_temp << 1; // Shift left first operand
                            b_temp <= b_temp >> 1; // Shift right second operand
                            result1 <= product[31:0]; // For testing
                            result2 <= product[63:32]; // For testing
                            counter <= counter - 1; // Decrement counter
                        end else begin
                            // Done
                            multiplying <= 0; // Stop multiplying
                            counter <= 0; // Reset counter
                            result1 <= product[31:0];
                            result2 <= product[63:32];
                            
                            ready <= 1;
                        end
                    end
                    default: begin
                        ready <= 0; // Invalid operation, not ready
                    end
                endcase
            end else begin
                ready <= 0; // Not ready if cs is low
            end
        end

    end

endmodule
