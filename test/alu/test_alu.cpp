#include <iostream>
#include <bitset>

#include <verilated_vcd_c.h> // Generating waveform files (VCD) for simulation
#include <verilated.h>
#include "Valu.h"
    
struct test_case {
    uint32_t op_code;
    uint32_t a;
    uint32_t b;
    uint32_t expected_result1;
    uint32_t expected_result2;
};

typedef struct test_case test_case_t;

// parameter ADD = 4'b0000,
//           SUB = 4'b0001,
//           AND = 4'b0010,
//           OR  = 4'b0011,
//           XOR = 4'b0100,
//           NOT = 4'b0101,
//           SHL = 4'b0110,
//           SHR = 4'b0111,
//           MUL = 4'b1000;

test_case_t test_cases[] = {
    {0b0000, 12, 13, 25, 0}, // Add
    {0b0001, 15,  7,  8, 0}, // Subtract
    {0b0010, 0b0111, 0b1011, 0b0011, 0}, // AND
    {0b0011, 0b0111, 0b1011, 0b1111, 0}, // OR
    {0b0100, 0b0111, 0b1011, 0b1100, 0}, // XOR
    {0b0101, 12, 0xFFFFFFFF, 0xFFFFFFF3, 0}, // NOT
    {0b0110, 12, 2, 48, 0}, // Shift left
    {0b0111, 12, 2, 3, 0}, // Shift right
    {0b1000, 20, 2, 40, 0}, // Multiply
    {0b1000, 1185001, 16455, 0b10001010001111100000110010011111u, 0b100u} // Multiply

};

static void doSimStep(Valu* alu, VerilatedVcdC* tfp, VerilatedContext* ctx, int& time_step) {
    alu->clk = !alu->clk;
    alu->eval();

    if (tfp) {
        tfp->dump(time_step);
    }

    time_step+=1;
}

int main(int argc, char** argv) {
    std::cout << "Starting Tests..." << std::endl;

    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    // Create instance of the DUT
    Valu* alu = new Valu{contextp};

    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    alu->trace(tfp, 99);  // Trace 99 levels of hierarchy
    tfp->open("alu_test.vcd");

    const int MAX_SIM_TIME = 10000; // Maximum simulation time
    int time_step = 0;

    // Reset the ALU
    alu->clk = 0;
    alu->rst_n = 0;
    doSimStep(alu, tfp, contextp, time_step);
    doSimStep(alu, tfp, contextp, time_step);
    doSimStep(alu, tfp, contextp, time_step);
    doSimStep(alu, tfp, contextp, time_step);

    alu->rst_n = 1; // Release reset

    int test_case_index = 0;
    int test_case_count = sizeof(test_cases) / sizeof(test_case_t);

    int cycles = 0;

    int failed_test_cases = 0;

    while (test_case_index < test_case_count) {
        if (time_step > MAX_SIM_TIME) {
            std::cout << "Simulation timed out!" << std::endl;
            break;
        }
        alu->cs = 1; // Enable ALU
        alu->op = test_cases[test_case_index].op_code;
        alu->a = test_cases[test_case_index].a;
        alu->b = test_cases[test_case_index].b;

        // Perform the operation
        doSimStep(alu, tfp, contextp, time_step);
        doSimStep(alu, tfp, contextp, time_step);

        cycles += 1;

        if (alu->ready) {
            // Check the results
            std::cout << "Done in " << cycles << " cycles." << std::endl;
            if (alu->result1 == test_cases[test_case_index].expected_result1 && alu->result2 == test_cases[test_case_index].expected_result2) {
                // std::cout << "Test case " << test_case_index << " passed!" << std::endl;
            } else {
                failed_test_cases += 1;
                std::cout << "Test case " << test_case_index << " failed!" << std::endl;
                std::cout << "Expected: " << std::bitset<32>(test_cases[test_case_index].expected_result1) << ", Got: " << std::bitset<32>(alu->result1) << std::endl;
                std::cout << "Expected: " << std::bitset<32>(test_cases[test_case_index].expected_result2) << ", Got: " << std::bitset<32>(alu->result2) << std::endl;
            }
    
            test_case_index++;
            cycles = 0;
        }

    }

    // Close the trace file
    alu->final();
    tfp->close();

    if (failed_test_cases > 0) {
        std::cerr << failed_test_cases << " test cases failed!" << std::endl;
        return 1;
    } else {
        std::cout << "All test cases passed!" << std::endl;
        return 0;
    }
}