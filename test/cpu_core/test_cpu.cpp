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
            if (address < 32)
                std::cout << "Wrote to address " << std::hex << address << ": " << std::dec << memory[address] << std::endl;
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

#define OP_NOP   0x00
#define OP_MV    0x01
#define OP_IMM   0x02
#define OP_ADD   0x03
#define OP_ADDI  0x04
#define OP_SUB   0x05
#define OP_SUBI  0x06
#define OP_AND   0x07
#define OP_OR    0x08
#define OP_XOR   0x09
#define OP_NOT   0x0A
#define OP_SHL   0x0B
#define OP_SHR   0x0C
#define OP_MUL   0x0D
#define OP_LDO   0x0E
#define OP_STO   0x0F
#define OP_JMP   0x10
#define OP_JR    0x11
#define OP_BEQ   0x12
#define OP_BNE   0x13
#define OP_BZ    0x14
#define OP_BNZ   0x15
#define OP_HLT   0x16
#define OP_FLSH  0x17

#define PACK_OP(op)      ((uint32_t)(op) << 26)
#define PACK_R1(r1)      ((uint32_t)(r1) << 21)
#define PACK_R2(r2)      ((uint32_t)(r2) << 16)
#define PACK_IMM(imm)    ((uint32_t)(imm) & 0xFFFF)
#define PACK_R3(r3)      ((uint32_t)(r3) << 11)

inline uint32_t make_R0(uint8_t opcode) {
    return PACK_OP(opcode);
}

inline uint32_t make_R1(uint8_t opcode, uint8_t r1) {
    return PACK_OP(opcode) | PACK_R1(r1);
}

inline uint32_t make_R2(uint8_t opcode, uint8_t r1, uint8_t r2) {
    return PACK_OP(opcode) | PACK_R1(r1) | PACK_R2(r2);
}

inline uint32_t make_R3(uint8_t opcode, uint8_t r1, uint8_t r2, uint16_t r3) {
    return PACK_OP(opcode) | PACK_R1(r1) | PACK_R2(r2) | PACK_R3(r3);
}

inline uint32_t make_R1I(uint8_t opcode, uint8_t r1, uint16_t imm) {
    return PACK_OP(opcode) | PACK_R1(r1) | PACK_IMM(imm);
}

inline uint32_t make_R2I(uint8_t opcode, uint8_t r1, uint8_t r2, uint16_t imm) {
    return PACK_OP(opcode) | PACK_R1(r1) | PACK_R2(r2) | PACK_IMM(imm);
}

int main(int argc, char** argv) {
    std::cout << "Starting Tests..." << std::endl;

    Verilated::commandArgs(argc, argv); // Initialize Verilator command line arguments
    Verilated::traceEverOn(true); // Enable tracing
    VerilatedVcdC* tfp = new VerilatedVcdC; // Create a VCD trace file
    Vcpu_core* top = new Vcpu_core; // Create an instance of the memory controller
    top->trace(tfp, 99); // Set the trace depth
    tfp->open("waveform.vcd"); // Open the VCD file for writing
    top->clk = 0;
    top->rst_n = 0;
    top->cs = 1;

    const int MAX_TICKS = 1000000;
    int tickcount = 0; // Initialize tick count

    tick(top, tfp, tickcount);
    tick(top, tfp, tickcount);
    tick(top, tfp, tickcount);
    tick(top, tfp, tickcount);

    top->rst_n = 1; // Deassert reset

    // For the first 4096 words of memory, we'll compute the Fibonacci sequence    
    memory[0] = make_R0(OP_NOP);
    memory[1] = make_R1I(OP_IMM, 0, 10); // R0 = 10
    memory[2] = make_R1I(OP_IMM, 1, 20); // R1 = 20
    memory[3] = make_R3(OP_ADD, 2, 0, 1); // R2 = R0 + R1
    memory[4] = make_R2I(OP_STO, 2, 3, 0x000F); // Store R2 at address 0x000F
    memory[5] = make_R0(OP_FLSH); // Flush the memory controller
    memory[6] = make_R0(OP_HLT);

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

    std::cout << "Memory (F): " << std::dec << memory[0xF] << std::dec << std::endl;

    if (memory[0xF] != 30) {
        std::cerr << "Test failed: Expected 30, got " << memory[0xF] << std::endl;
        return 1;
    } else {
        std::cout << "Test passed: Memory at 0xF is 30." << std::endl;
        return 0;
    }
}