module cpu_core (
`ifdef USE_POWER_PINS
    inout vccd1,
    inout vssd1,
`endif
    input wire clk,
    input wire rst_n,
    input wire cs,

    // RAM communication protocol
    input wire ram_slave_ack,
    input wire [31:0] ram_slave_data,
    output reg ram_master_req,
    output reg [48:0] ram_master_data, // {we, Address[16 bits], data[32 bits]}
    output reg cpu_halted
);
    // Instruction opcodes
    parameter OP_NOP  = 5'b00000, // R0   
            OP_MV   = 5'b00001, // R1   r1 = r2
            OP_IMM  = 5'b00010, // R1I  r1 = imm
            OP_ADD  = 5'b00011, // R3   r1 = r2 + r3
            OP_ADDI = 5'b00100, // R2I  r1 = r2 + imm
            OP_SUB  = 5'b00101, // R3   r1 = r2 - r3
            OP_SUBI = 5'b00110, // R2I  r1 = r2 - imm
            OP_AND  = 5'b00111, // R3   r1 = r2 & r3
            OP_OR   = 5'b01000, // R3   r1 = r2 | r3
            OP_XOR  = 5'b01001, // R3   r1 = r2 ^ r3
            OP_NOT  = 5'b01010, // R2   r1 = ~r2
            OP_SHL  = 5'b01011, // R3   r1 = r2 << r3
            OP_SHR  = 5'b01100, // R3   r1 = r2 >> r3
            OP_MUL  = 5'b01101, // R3   r1 = r2 * r3
            OP_LDO  = 5'b01110, // R2I  r1 = [r2 + imm]
            OP_STO  = 5'b01111, // R2I  [r2 + imm] = r1
            OP_JMP  = 5'b10000, // R0I  pc = imm
            OP_JR   = 5'b10001, // R1I  pc = r1 + imm
            OP_BEQ  = 5'b10010, // R2I  if (r1 == r2) pc = imm
            OP_BNE  = 5'b10011, // R2I  if (r1 != r2) pc = imm
            OP_BZ   = 5'b10100, // R2I  if (r1 == 0) pc = imm
            OP_BNZ  = 5'b10101, // R2I  if (r1 != 0) pc = imm
            OP_HLT  = 5'b10110, // R0   Halt
            OP_FLSH = 5'b10111; // R0   Flush

    // ALU opcodes
    parameter ALU_ADD = 4'b0000,
            ALU_SUB = 4'b0001,
            ALU_AND = 4'b0010,
            ALU_OR  = 4'b0011,
            ALU_XOR = 4'b0100,
            ALU_NOT = 4'b0101,
            ALU_SHL = 4'b0110,
            ALU_SHR = 4'b0111,
            ALU_MUL = 4'b1000;

    // Core states
    parameter CORE_FETCH         = 3'b000,
            CORE_DECODE        = 3'b001,
            CORE_EXECUTE       = 3'b010,
            CORE_ALU_WAIT      = 3'b011,
            CORE_MEMORY_ACCESS = 3'b100,
            CORE_HALT          = 3'b101;

    // State and PC
    reg [2:0]  state;
    reg [15:0] pc;

    // Current fetched instruction
    reg [31:0] instruction;

    // Memory control signals
    reg        mem_cs;
    reg        mem_we;
    reg        mem_flush;
    reg [15:0] mem_addr;
    reg [31:0] mem_data_in;
    wire [31:0] mem_data_out;
    wire        mem_is_valid;

    // Instruction fields for convenience
    wire [4:0]  instruction_opcode;
    wire [4:0]  instruction_r1;
    wire [4:0]  instruction_r2;
    wire [4:0]  instruction_r3;
    wire [15:0] instruction_imm;

    assign instruction_opcode = instruction[30:26];
    assign instruction_r1     = instruction[25:21];
    assign instruction_r2     = instruction[20:16];
    assign instruction_r3     = instruction[15:11];
    assign instruction_imm    = instruction[15:0];

    // ALU control signals
    reg        alu_cs;
    reg [31:0] alu_input_a;
    reg [31:0] alu_input_b;
    reg [3:0]  alu_op;
    wire       alu_ready;
    wire [31:0] alu_result;
    reg  [31:0] alu_result2;

    // Register file wires
    wire [31:0] r1_data;
    wire [31:0] r2_data;
    wire [31:0] r3_data;
    reg         rf_write_en;
    reg  [4:0]  rf_write_addr;
    reg  [31:0] rf_write_data;

    // Instantiate the ALU
    alu alu_unit (
    `ifdef USE_POWER_PINS
        .vccd1(vccd1),
        .vssd1(vssd1),
    `endif
        .clk(clk),
        .rst_n(rst_n),
        .cs(alu_cs),
        .a(alu_input_a),
        .b(alu_input_b),
        .op(alu_op),
        .ready(alu_ready),
        .result1(alu_result),
        .result2(alu_result2)
    );

    // Instantiate the register file
    register_file reg_file (
    `ifdef USE_POWER_PINS
        .vccd1(vccd1),
        .vssd1(vssd1),
    `endif
        .clk(clk),
        .rst_n(rst_n),

        // Read ports
        .read_addr_1(instruction_r1),
        .read_data_1(r1_data),
        .read_addr_2(instruction_r2),
        .read_data_2(r2_data),
        .read_addr_3(instruction_r3),
        .read_data_3(r3_data),

        // Write port
        .write_en(rf_write_en),
        .write_addr(rf_write_addr),
        .write_data(rf_write_data)
    );

    // Memory controller
    memory_controller mem_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .cs(mem_cs),
        .ram_slave_ack(ram_slave_ack),
        .ram_slave_data(ram_slave_data),
        .ram_master_req(ram_master_req),
        .ram_master_data(ram_master_data),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_data_in(mem_data_in),
        .mem_data_out(mem_data_out),
        .mem_is_valid(mem_is_valid),
        .mem_flush(mem_flush)
    );

    // Main CPU logic
    always @(posedge clk) begin
        if (!rst_n) begin
            alu_input_a <= 0;
            alu_input_b <= 0;
            alu_op      <= 0;
            alu_cs      <= 0;
            pc          <= 0;
            mem_cs      <= 0;
            mem_we      <= 0;
            mem_flush   <= 0;
            mem_addr    <= 0;
            mem_data_in <= 0;
            rf_write_en <= 0;
            rf_write_addr <= 0;
            rf_write_data <= 0;
            instruction   <= 0;
            cpu_halted    <= 0;
            state         <= CORE_FETCH;
        end else begin
            // By default, don’t write to the register file each cycle
            rf_write_en <= 0;

            if (cs) begin
                case (state)
                    // Fetch state
                    CORE_FETCH: begin
                        $display("CPU: Fetching instruction @ PC: %h", pc);
                        // Request next instruction from memory
                        mem_we <= 0; // read
                        mem_addr <= pc;
                        mem_cs <= 1; // Enable memory
                        state <= CORE_DECODE;
                    end

                    // Decode state
                    CORE_DECODE: begin
                        if (mem_is_valid) begin
                            $display("CPU: Decoding instruction: %b", mem_data_out);
                            instruction <= mem_data_out; // Latch instruction
                            pc <= pc + 1;                // Increment PC
                            mem_cs <= 0;
                            state <= CORE_EXECUTE;
                        end
                    end

                    // Execute state
                    CORE_EXECUTE: begin
                        case (instruction_opcode)
                            OP_NOP: begin
                                // No operation
                                state <= CORE_FETCH;
                            end

                            OP_HLT: begin
                                // Halt
                                state <= CORE_HALT;
                            end

                            OP_MV: begin
                                // reg_file[r1] = reg_file[r2]
                                rf_write_addr <= instruction_r1;
                                rf_write_data <= r2_data;
                                rf_write_en   <= 1;
                                state <= CORE_FETCH;
                            end

                            OP_IMM: begin
                                // reg_file[r1] = {16'b0, imm}
                                rf_write_addr <= instruction_r1;
                                rf_write_data <= {16'b0, instruction_imm};
                                rf_write_en   <= 1;
                                state <= CORE_FETCH;
                            end

                            OP_ADD: begin
                                // r1 = r2 + r3
                                alu_input_a <= r2_data;
                                alu_input_b <= r3_data;
                                alu_op      <= ALU_ADD;
                                alu_cs      <= 1;
                                state <= CORE_ALU_WAIT;
                            end

                            OP_ADDI: begin
                                // r1 = r2 + imm
                                alu_input_a <= r2_data;
                                alu_input_b <= {16'b0, instruction_imm};
                                alu_op      <= ALU_ADD;
                                alu_cs      <= 1;
                                state <= CORE_ALU_WAIT;
                            end

                            OP_SUB: begin
                                // r1 = r2 - r3
                                alu_input_a <= r2_data;
                                alu_input_b <= r3_data;
                                alu_op      <= ALU_SUB;
                                alu_cs      <= 1;
                                state <= CORE_ALU_WAIT;
                            end

                            OP_SUBI: begin
                                // r1 = r2 - imm
                                alu_input_a <= r2_data;
                                alu_input_b <= {16'b0, instruction_imm};
                                alu_op      <= ALU_SUB;
                                alu_cs      <= 1;
                                state <= CORE_ALU_WAIT;
                            end

                            OP_AND: begin
                                // r1 = r2 & r3
                                alu_input_a <= r2_data;
                                alu_input_b <= r3_data;
                                alu_op      <= ALU_AND;
                                alu_cs      <= 1;
                                state <= CORE_ALU_WAIT;
                            end

                            OP_OR: begin
                                // r1 = r2 | r3
                                alu_input_a <= r2_data;
                                alu_input_b <= r3_data;
                                alu_op      <= ALU_OR;
                                alu_cs      <= 1;
                                state <= CORE_ALU_WAIT;
                            end

                            OP_XOR: begin
                                // r1 = r2 ^ r3
                                alu_input_a <= r2_data;
                                alu_input_b <= r3_data;
                                alu_op      <= ALU_XOR;
                                alu_cs      <= 1;
                                state <= CORE_ALU_WAIT;
                            end

                            OP_NOT: begin
                                // r1 = ~r2
                                alu_input_a <= r2_data;
                                alu_op      <= ALU_NOT;
                                alu_cs      <= 1;
                                state <= CORE_ALU_WAIT;
                            end

                            OP_SHL: begin
                                // r1 = r2 << r3
                                alu_input_a <= r2_data;
                                alu_input_b <= r3_data;
                                alu_op      <= ALU_SHL;
                                alu_cs      <= 1;
                                state <= CORE_ALU_WAIT;
                            end

                            OP_SHR: begin
                                // r1 = r2 >> r3
                                alu_input_a <= r2_data;
                                alu_input_b <= r3_data;
                                alu_op      <= ALU_SHR;
                                alu_cs      <= 1;
                                state <= CORE_ALU_WAIT;
                            end

                            OP_MUL: begin
                                // r1 = r2 * r3
                                $display("CPU: Multiplying R%d = (%d) * R%d = (%d)",
                                        instruction_r1, r2_data,
                                        instruction_r3, r3_data);
                                alu_input_a <= r2_data;
                                alu_input_b <= r3_data;
                                alu_op      <= ALU_MUL;
                                alu_cs      <= 1;
                                state <= CORE_ALU_WAIT;
                            end

                            OP_LDO: begin
                                // r1 = [r2 + imm]
                                mem_we <= 0; // read
                                mem_addr <= r2_data[15:0] + instruction_imm;
                                mem_cs <= 1;
                                state <= CORE_MEMORY_ACCESS;
                            end

                            OP_STO: begin
                                // [r2 + imm] = r1
                                $display("CPU: Storing value from R%d = (%d) to memory address R2 + immediate (%h)",
                                        instruction_r1, r1_data,
                                        r2_data[15:0] + instruction_imm);
                                mem_we <= 1; 
                                mem_addr    <= r2_data[15:0] + instruction_imm;
                                mem_data_in <= r1_data;
                                mem_cs <= 1;
                                state <= CORE_MEMORY_ACCESS;
                            end

                            OP_FLSH: begin
                                // Flush the cache back to RAM
                                mem_flush <= 1;
                                mem_cs <= 1;
                                state <= CORE_MEMORY_ACCESS;
                            end

                            OP_JMP: begin
                                // pc = imm
                                pc <= instruction_imm;
                                state <= CORE_FETCH;
                            end

                            OP_JR: begin
                                // pc = r1 + imm
                                pc <= r1_data[15:0] + instruction_imm;
                                state <= CORE_FETCH;
                            end

                            OP_BEQ: begin
                                // if (r1 == r2) pc = imm
                                if (r1_data == r2_data) begin
                                    pc <= instruction_imm;
                                end
                                state <= CORE_FETCH;
                            end

                            OP_BNE: begin
                                // if (r1 != r2) pc = imm
                                if (r1_data != r2_data) begin
                                    pc <= instruction_imm;
                                end
                                state <= CORE_FETCH;
                            end

                            OP_BZ: begin
                                // if (r1 == 0) pc = imm
                                if (r1_data == 32'd0) begin
                                    pc <= instruction_imm;
                                end
                                state <= CORE_FETCH;
                            end

                            OP_BNZ: begin
                                // if (r1 != 0) pc = imm
                                if (r1_data != 32'd0) begin
                                    pc <= instruction_imm;
                                end
                                state <= CORE_FETCH;
                            end

                            default: begin
                                // Unknown instruction
                                state <= CORE_FETCH;
                            end
                        endcase
                    end

                    // Wait until ALU is done
                    CORE_ALU_WAIT: begin
                        $display("CPU: Waiting for ALU operation to complete. A: %d, B: %d, Op: %b, R1: %d",
                                alu_input_a, alu_input_b, alu_op, alu_result);
                        if (alu_ready) begin
                            $display("CPU: ALU operation completed, storing result: %d in register %d",
                                    alu_result, instruction_r1);
                            // Write ALU result into r1
                            alu_cs <= 0;
                            rf_write_addr <= instruction_r1;
                            rf_write_data <= alu_result;
                            rf_write_en   <= 1;
                            state <= CORE_FETCH;
                        end
                    end

                    // Memory access (including flush)
                    CORE_MEMORY_ACCESS: begin
                        if (mem_is_valid) begin
                            if (mem_flush) begin
                                mem_flush <= 0;
                                mem_cs <= 0;
                            end else if (mem_we) begin
                                // Write complete
                                mem_cs <= 0;
                            end else begin
                                // Read complete, store in r1
                                rf_write_addr <= instruction_r1;
                                rf_write_data <= mem_data_out;
                                rf_write_en   <= 1;
                                mem_cs <= 0;
                            end
                            state <= CORE_FETCH;
                        end
                    end

                    // Halt state
                    CORE_HALT: begin
                        // CPU stays halted
                        state <= CORE_HALT;
                        cpu_halted <= 1;
                    end

                    default: begin
                        // Should never get here, fallback to fetch
                        state <= CORE_FETCH;
                    end
                endcase
            end // if (cs)
        end // else (reset)
    end // always @(posedge clk)

endmodule
