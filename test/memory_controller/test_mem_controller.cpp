#include <iostream>
#include <bitset>

#include <verilated_vcd_c.h> // Generating waveform files (VCD) for simulation
#include <verilated.h>
#include "Vmemory_controller.h"

uint32_t memory[65536];

void tick(Vmemory_controller* top, VerilatedVcdC* tfp, int& tickcount) {
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
    std::cout << "Starting Tests..." << std::endl;

    Verilated::commandArgs(argc, argv); // Initialize Verilator command line arguments
    Verilated::traceEverOn(true); // Enable tracing
    VerilatedVcdC* tfp = new VerilatedVcdC; // Create a VCD trace file
    Vmemory_controller* top = new Vmemory_controller; // Create an instance of the memory controller
    top->trace(tfp, 99); // Set the trace depth
    tfp->open("waveform.vcd"); // Open the VCD file for writing
    top->clk = 0; // Initialize clock
    top->rst_n = 0; // Initialize reset

    // Init RAM
    for (size_t i = 0; i < 65536; i++)
    {
        memory[i] = i;
    }

    const int MAX_TICKS = 10000000;
    int tickcount = 0; // Initialize tick count

    int failed_test_cases = 0;

    // Reset the design
    top->rst_n = 0; // Assert reset
    tick(top, tfp, tickcount);
    tick(top, tfp, tickcount);
    tick(top, tfp, tickcount);
    tick(top, tfp, tickcount);
    top->rst_n = 1; // Deassert reset

    // Test memory read
    uint32_t read_address = 0;
    uint32_t memory_test_state = 0; // 0 - read, 1 - wait for mem_is_valid to be low
    while (read_address < 2048) {
        if (tickcount >= MAX_TICKS) {
            std::cout << "Max ticks reached, stopping simulation." << std::endl;
            break;
        }
        if (memory_test_state == 0) {
            top->mem_we = 0;
            top->cs = 1;
            top->mem_addr = read_address;
    
            tick(top, tfp, tickcount); // Clock tick
            
            if (top->mem_is_valid) {
                if (top->mem_data_out != memory[read_address]) {
                    std::cout << "Memory read error at address " << read_address << ": expected " << memory[read_address] << ", got " << top->mem_data_out << std::endl;
                    failed_test_cases += 1;
                } else {
                    // std::cout << "Memory read success at address " << read_address << ": " << top->mem_data_out << std::endl;
                }
                read_address++;
                memory_test_state = 1; // Move to wait state
            }
        } else if (memory_test_state == 1) {
            top->cs = 0;
            if (!top->mem_is_valid) {
                memory_test_state = 0; // Go back to read state
            }
            tick(top, tfp, tickcount); // Clock tick
        }
    }

    top->cs = 0;
    tick(top, tfp, tickcount); // Clock tick
    tick(top, tfp, tickcount); // Clock tick
    tick(top, tfp, tickcount); // Clock tick
    tick(top, tfp, tickcount); // Clock tick

    uint32_t base_address = 0x1000;
    uint32_t write_adress = 0;
    memory_test_state = 0; // 0 - write, 1 - wait for mem_is_valid to be low
    while (write_adress < 2048) {
        if (tickcount >= MAX_TICKS) {
            std::cout << "Max ticks reached, stopping simulation." << std::endl;
            failed_test_cases += 1;
            break;
        }

        if (memory_test_state == 0) {
            top->mem_we = 1;
            top->cs = 1;
            top->mem_addr = base_address + write_adress;
            top->mem_data_in = write_adress;

            tick(top, tfp, tickcount); // Clock tick

            if (top->mem_is_valid) {
                write_adress++;
                memory_test_state = 1; // Move to wait state
            }
        } else if (memory_test_state == 1) {
            top->cs = 0;
            if (!top->mem_is_valid) {
                memory_test_state = 0; // Go back to read state
            }
            tick(top, tfp, tickcount); // Clock tick
        }
    }

    // Flush
    top->mem_we = 0;
    top->cs = 1;
    top->mem_flush = 1;

    tick(top, tfp, tickcount); // Clock tick
    tick(top, tfp, tickcount); // Clock tick
    tick(top, tfp, tickcount); // Clock tick
    tick(top, tfp, tickcount); // Clock tick

    while (!top->mem_is_valid) {
        if (tickcount >= MAX_TICKS) {
            std::cout << "Max ticks reached, stopping simulation." << std::endl;
            failed_test_cases += 1;
            break;
        }
        tick(top, tfp, tickcount); // Clock tick
    }
    
    for (size_t i = base_address; i < base_address + 128; i++)
    {
        if (i - base_address != memory[i]) {
            std::cout << "Memory write error at address 0x" << std::hex << i << std::dec << ": expected " << i - base_address << ", got " << memory[i] << std::endl;
            failed_test_cases += 1;
        } else {
            // std::cout << "Memory write success at address 0x" << std::hex << i << std::dec << ": " << memory[i] << std::endl;
        }
    }

    // Close file
    tfp->close(); // Close the VCD file
    delete top; // Delete the model instance
    delete tfp; // Delete the VCD trace file

    if (failed_test_cases > 0) {
        std::cerr << "Test failed with " << failed_test_cases << " errors." << std::endl;
        return 1;
    } else {
        std::cout << "All tests passed successfully!" << std::endl;
        return 0;
    }
}