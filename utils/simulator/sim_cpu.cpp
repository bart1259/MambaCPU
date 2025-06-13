#include <iostream>
#include <bitset>

#include <verilated_vcd_c.h> // Generating waveform files (VCD) for simulation
#include <verilated.h>
#include "Vcpu_core.h"

uint32_t memory[65536];

void tick(Vcpu_core* top, VerilatedVcdC* tfp, int& tickcount) {
    top->clk = !top->clk; // Toggle the clock
    top->eval(); // Evaluate the model
    tfp->dump(tickcount); // Dump the current time to the VCD file
    tickcount += 1;

    if (top->ram_master_req)
    {
        uint64_t request = top->ram_master_data;
        uint32_t data = request & 0xFFFFFFFF; // Extract data from the request
        uint32_t address = (request >> 32) & 0xFFFF; // Extract address from the request
        bool is_write = (request >> 48) & 0x1; // Extract write flag from the request

        if (is_write)
        {
            memory[address] = data;
            // std::cout << "Wrote to address " << std::hex << address << ": " << std::dec << memory[address] << std::endl;
        }
        else {
            top->ram_slave_data = memory[address];
            // std::cout << "Read from address " << std::hex << address << ": " << std::dec << memory[address] << std::endl;
        }

        // Acknowledge the request
        top->ram_slave_ack = 1;
    } else {
        top->ram_slave_ack = 0; // No request, so no acknowledgment
    }
}

int main(int argc, char** argv) {
    std::cout << "Starting Simulation..." << std::endl;

    // Parse arguments
    // --print-final-ram <address> <size>

    bool print_final_ram = false;
    size_t print_final_ram_address = 0;
    size_t print_final_ram_size = 0;

    for (size_t i = 0; i < argc - 1; i++)
    {
        if (std::string(argv[i]) == "--print-final-ram") {
            if (i + 2 < argc) {
                print_final_ram = true;
                print_final_ram_address = std::stoul(argv[i + 1], nullptr, 0);
                print_final_ram_size = std::stoul(argv[i + 2], nullptr, 0);
            } else {
                std::cerr << "Error: --print-final-ram requires two additional arguments." << std::endl;
            }
        }
    }

    // --display-ram <address> <x_size> <y_size>
    bool display_ram = false;
    size_t display_ram_address = 0;
    size_t display_ram_x_size = 0;
    size_t display_ram_y_size = 0;

    for (size_t i = 0; i < argc - 1; i++)
    {
        if (std::string(argv[i]) == "--display-ram") {
            if (i + 3 < argc) {
                display_ram = true;
                display_ram_address = std::stoul(argv[i + 1], nullptr, 0);
                display_ram_x_size = std::stoul(argv[i + 2], nullptr, 0);
                display_ram_y_size = std::stoul(argv[i + 3], nullptr, 0);
            } else {
                std::cerr << "Error: --display-ram requires three additional arguments." << std::endl;
            }
        }
    }

    // Get instruction file from command line arguments
    if (argc > 1) {
        std::cout << "Loading instructions from file: " << argv[1] << std::endl;
        FILE* file = fopen(argv[argc - 1], "rb");
        if (!file) {
            std::cerr << "Error opening file: " << argv[argc - 1] << std::endl;
            return 1;
        }
        // Read in big endian format
        for (size_t i = 0; i < 65536; i++) {
            uint32_t word;
            fread(&word, sizeof(uint32_t), 1, file);
            memory[i] = __builtin_bswap32(word);
        }
        fclose(file);
    } else {
        std::cerr << "No instruction file provided. Exiting." << std::endl;
        return 1;
    }


    Verilated::commandArgs(argc, argv); // Initialize Verilator command line arguments
    Verilated::traceEverOn(true); // Enable tracing
    VerilatedVcdC* tfp = new VerilatedVcdC; // Create a VCD trace file
    Vcpu_core* top = new Vcpu_core; // Create an instance of the memory controller
    top->trace(tfp, 99); // Set the trace depth
    tfp->open("waveform.vcd"); // Open the VCD file for writing
    top->clk = 0;
    top->rst_n = 0;
    top->cs = 1;

    const int MAX_TICKS = 100000;
    int tickcount = 0; // Initialize tick count

    tick(top, tfp, tickcount);
    tick(top, tfp, tickcount);
    tick(top, tfp, tickcount);
    tick(top, tfp, tickcount);

    top->rst_n = 1; // Deassert reset

    tick(top, tfp, tickcount);
    tick(top, tfp, tickcount);

    while (true)
    {
        if (tickcount >= MAX_TICKS) {
            std::cout << "Max ticks reached, stopping simulation." << std::endl;
            break;
        }

        tick(top, tfp, tickcount); // Clock tick

        if (top->cpu_halted) {
            std::cout << "CPU halted." << std::endl;
            break;
        }
    }

    if (print_final_ram) {
        for (size_t i = print_final_ram_address; i < print_final_ram_address + print_final_ram_size; i++)
        {
            std::cout << "0x" << std::hex << i << ": " << std::dec << memory[i] << std::endl;
        }
    }

    // Display RAM contents
    if (display_ram) {
        for (size_t i = 0; i < display_ram_y_size; i++)
        {
            for (size_t j = 0; j < display_ram_x_size; j++)
            {
                int add = 256 + (i * display_ram_x_size) + j;
                if(memory[add] != 0) {
                    std::cout << "#";
                } else {
                    std::cout << ".";
                }
                
            }
            std::cout << std::endl;
        }
    }
}