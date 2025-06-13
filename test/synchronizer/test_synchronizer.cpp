#include <iostream>
#include <bitset>

#include <verilated_vcd_c.h> // Generating waveform files (VCD) for simulation
#include <verilated.h>
#include "Vtest_synchronizer.h"

struct test_case {
    uint32_t input_data;
    uint32_t expected_output;
};
typedef struct test_case test_case_t;

test_case_t test_cases[] = {
    {0x00000000u, ~0x00000000u},
    {0x00000001u, ~0x00000001u},
    {0xFFFFFFFFu, ~0xFFFFFFFFu},
    {0x12345678u, ~0x12345678u},
    {0x87654321u, ~0x87654321u},
};

struct cdc_case {
    uint32_t clk_a_period;
    uint32_t clk_b_period;
};
typedef struct cdc_case cdc_case_t;
cdc_case_t cdc_cases[] = {
    {1, 1},
    {1, 2},
    {2, 1},
    {5, 7},
    {7, 5},
    {5, 17},
    {17, 5},
    {1, 17},
    {17, 1}
};


static void doSimStep(Vtest_synchronizer* tb, VerilatedVcdC* tfp, VerilatedContext* ctx, int& main_time, int a_clk_period, int b_clk_period) {
    // Toggle clocks
    if (main_time % a_clk_period == 0) {
        tb->clk_a = !tb->clk_a;
    }
    if (main_time % b_clk_period == 0) {
        tb->clk_b = !tb->clk_b;
    }

    // Evaluate the model
    tb->eval();

    // Dump trace
    if (tfp) {
        tfp->dump(main_time);
    }

    // Increment time
    ++main_time;
}

int main(int argc, char** argv) {
    std::cout << "Starting Tests..." << std::endl;

    int failed_test_cases = 0;

    for (size_t i = 0; i < sizeof(cdc_cases) / sizeof(cdc_case_t); i++)
    {
        VerilatedContext* contextp = new VerilatedContext;
        contextp->commandArgs(argc, argv);

        cdc_case_t cdc = cdc_cases[i];

        // Create instance of the DUT
        Vtest_synchronizer* tb = new Vtest_synchronizer{contextp};

        // Enable VCD tracing
        Verilated::traceEverOn(true);
        VerilatedVcdC* tfp = new VerilatedVcdC;
        tb->trace(tfp, 99);  // Trace 99 levels of hierarchy
        tfp->open((std::string("test_synchronizer_dump_") + std::to_string(cdc.clk_a_period) + "_" + std::to_string(cdc.clk_b_period) + ".vcd").c_str());

        const int MAX_SIM_TIME = 10000; // Maximum simulation time
        int main_time = 0;

        // Initialize signals
        tb->clk_a = 0;
        tb->clk_b = 0;
        tb->rst_n = 0;
        tb->master_start = 0;
        tb->master_send = 0x00000000;

        for (int i = 0; i < 2; ++i)
            doSimStep(tb, tfp, contextp, main_time, 1, 1); // Initial reset

        tb->rst_n = 1; // Release reset

        int clk_a_period = cdc.clk_a_period;
        int clk_b_period = cdc.clk_b_period;

        int test_case = 0;
        int test_case_progress = 0; // 0 is setup for test case, 1 is waiting for master_recv_valid, 2 is waiting for master_can_send

        while (test_case < sizeof(test_cases) / sizeof(test_case_t)) {
            if (main_time > MAX_SIM_TIME) {
                std::cerr << "Simulation timed out!" << std::endl;
                break;
            }

            doSimStep(tb, tfp, contextp, main_time, clk_a_period, clk_b_period);
            if (test_case_progress == 0) {
                tb->master_start = 1;
                tb->master_send = test_cases[test_case].input_data; // Send test case input data
                test_case_progress = 1; // Move to waiting for master_recv_valid
            } else if (test_case_progress == 1) {
                if (tb->master_recv_valid) {
                    // std::cout << "Received: " << std::bitset<32>(tb->master_recv) << std::endl;
                    if (tb->master_recv == test_cases[test_case].expected_output) {
                        // std::cout << "Test case " << test_case << " passed!" << std::endl;
                    } else {
                        std::cout << "Test case " << test_case << " failed!" << std::endl;
                        failed_test_cases += 1;
                    }
                    test_case_progress = 2; // Move to waiting for master_can_send
                }
            } else if (test_case_progress == 2) {
                if (tb->master_can_send) {
                    tb->master_send = test_cases[test_case].input_data;
                    tb->master_start = 0; // Start the master again
                    test_case_progress = 0; // Move back to waiting for master_recv_valid
                    test_case++; // Move to the next test case
                }
            }
        }

        // Close the trace file
        tb->final();
        tfp->close();

        delete tfp;
    }

    if (failed_test_cases > 0) {
        std::cerr << failed_test_cases << " test cases failed" << std::endl;
        return 1;
    }

    std::cout << "Done." << std::endl;

    return 0;
}