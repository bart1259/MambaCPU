# Converts assembly code to machine code

import re

INSTRUCTION_SET = [
    {
        "name": "NOP",
        "opcode": "000000",
        "instruction_type": "R0",
        "regex": r"^\s*NOP\s*$",
        "group_mapping": []
    },
    {
        "name": "MV",
        "opcode": "000001",
        "instruction_type": "R2",
        "regex": r"^R(\d+)\s*=\s*R(\d+)\s*$",
        "group_mapping": ["R1", "R2"]
    },
    {
        "name": "IMM",
        "opcode": "000010",
        "instruction_type": "R1I",
        "regex": r"^R(\d+)\s*=\s*(\d+)\s*$",
        "group_mapping": ["R1", "IMM"]
    },
    {
        "name": "ADD",
        "opcode": "000011",
        "instruction_type": "R3",
        "regex": r"^R(\d+)\s*=\s*R(\d+)\s*\+\s*R(\d+)\s*$",
        "group_mapping": ["R1", "R2", "R3"]
    },
    {
        "name": "ADDI",
        "opcode": "000100",
        "instruction_type": "R2I",
        "regex": r"^R(\d+)\s*=\s*R(\d+)\s*\+\s*(\d+)\s*$",
        "group_mapping": ["R1", "R2", "IMM"]
    },
    {
        "name": "SUB",
        "opcode": "000101",
        "instruction_type": "R3",
        "regex": r"^R(\d+)\s*=\s*R(\d+)\s*-\s*R(\d+)\s*$",
        "group_mapping": ["R1", "R2", "R3"]
    },
    {
        "name": "SUBI",
        "opcode": "000110",
        "instruction_type": "R2I",
        "regex": r"^R(\d+)\s*=\s*R(\d+)\s*-\s*(\d+)\s*$",
        "group_mapping": ["R1", "R2", "IMM"]
    },
    {
        "name": "AND",
        "opcode": "000111",
        "instruction_type": "R3",
        "regex": r"^R(\d+)\s*=\s*R(\d+)\s*&\s*R(\d+)\s*$",
        "group_mapping": ["R1", "R2", "R3"]
    },
    {
        "name": "OR",
        "opcode": "001000",
        "instruction_type": "R3",
        "regex": r"^R(\d+)\s*=\s*R(\d+)\s*\|\s*R(\d+)\s*$",
        "group_mapping": ["R1", "R2", "R3"]
    },
    {
        "name": "XOR",
        "opcode": "001001",
        "instruction_type": "R3",
        "regex": r"^R(\d+)\s*=\s*R(\d+)\s*\^\s*R(\d+)\s*$",
        "group_mapping": ["R1", "R2", "R3"]
    },
    {
        "name": "NOT",
        "opcode": "001010",
        "instruction_type": "R2",
        "regex": r"^R(\d+)\s*=\s*~R(\d+)\s*$",
        "group_mapping": ["R1", "R2"]
    },
    {
        "name": "SHL",
        "opcode": "001011",
        "instruction_type": "R3",
        "regex": r"^R(\d+)\s*=\s*R(\d+)\s*<<\s*R(\d+)\s*$",
        "group_mapping": ["R1", "R2", "R3"]
    },
    {
        "name": "SHR",
        "opcode": "001100",
        "instruction_type": "R3",
        "regex": r"^R(\d+)\s*=\s*R(\d+)\s*>>\s*R(\d+)\s*$",
        "group_mapping": ["R1", "R2", "R3"]
    },
    {
        "name": "MUL",
        "opcode": "001101",
        "instruction_type": "R3",
        "regex": r"^R(\d+)\s*=\s*R(\d+)\s*\*\s*R(\d+)\s*$",
        "group_mapping": ["R1", "R2", "R3"]
    },
    { # r1 = [r2 + imm]
        "name": "LDO",
        "opcode": "001110",
        "instruction_type": "R2I",
        "regex": r"^R(\d+)\s*=\s*\[R(\d+)\s*\+\s*(\d+)\]\s*$",
        "group_mapping": ["R1", "R2", "IMM"]
    },
    { # [r2 + imm] = r1
        "name": "STO",
        "opcode": "001111",
        "instruction_type": "R2I",
        "regex": r"^\[R(\d+)\s*\+\s*(\d+)\]\s*=\s*R(\d+)\s*$",
        "group_mapping": ["R2", "IMM", "R1"]
    },
    {
        "name": "JMP",
        "opcode": "010000",
        "instruction_type": "R0I",
        "regex": r"^JMP\s*(\d+)\s*$",
        "group_mapping": ["IMM"]
    },
    {
        "name": "JR",
        "opcode": "010001",
        "instruction_type": "R1I",
        "regex": r"^JR\s*R(\d+)\s*\+\s*(\d+)\s*$",
        "group_mapping": ["R1", "IMM"]
    },
    { # r1 == r2 ? JMP imm
        "name": "BEQ",
        "opcode": "010010",
        "instruction_type": "R2I",
        "regex": r"^\s*R(\d+)\s*==\s*R(\d+)\s*?\?\s*JMP\s*(\d+)\s*$",
        "group_mapping": ["R1", "R2", "IMM"]
    },
    {
        "name": "BNE",
        "opcode": "010011",
        "instruction_type": "R2I",
        "regex": r"^\s*R(\d+)\s*!=\s*R(\d+)\s*?\?\s*JMP\s*(\d+)\s*$",
        "group_mapping": ["R1", "R2", "IMM"]
    },
    { # r1 == 0 ? JMP imm
        "name": "BZ",
        "opcode": "010100",
        "instruction_type": "R2I",
        "regex": r"^\s*R(\d+)\s*==\s*0\s*?\?\s*JMP\s*(\d+)\s*$",
        "group_mapping": ["R1", "IMM"]
    },
    { # r1 != 0 ? JMP imm
        "name": "BNZ",
        "opcode": "010101",
        "instruction_type": "R2I",
        "regex": r"^\s*R(\d+)\s*!=\s*0\s*?\?\s*JMP\s*(\d+)\s*$",
        "group_mapping": ["R1", "IMM"]
    },
    {
        "name": "HLT",
        "opcode": "010110",
        "instruction_type": "R0",
        "regex": r"^\s*HLT\s*$",
        "group_mapping": []
    },
    {
        "name": "FLSH",
        "opcode": "010111",
        "instruction_type": "R0",
        "regex": r"^\s*FLSH\s*$",
        "group_mapping": []
    }
]

import os

def get_binary(value, bit_count):
    assert isinstance(value, int), "Value must be an integer."
    assert bit_count > 0, "Bit count must be a positive integer."

    if value < 0:
        raise ValueError("Negative values are not supported in this context.")
    
    binary = bin(value)[2:]  # Convert to binary and strip the '0b' prefix
    if len(binary) > bit_count:
        raise ValueError(f"Value {value} exceeds the bit count of {bit_count}.")
    return binary.zfill(bit_count)  # Pad with leading zeros to fit the bit count

def assemble(file):
    if not os.path.exists(file):
        raise FileNotFoundError(f"File {file} does not exist.")
    
    with open(file, 'r') as f:
        lines = f.readlines()

    # Strip whitespace and comments from each line
    cleaned_lines = []
    for line in lines:
        line = line.split('#')[0].strip()
        if line != '':
            cleaned_lines.append(line)

    # Find labels and replace them with their addresses
    labels = {}
    for i, line in enumerate(cleaned_lines):
        if line.startswith('.'):
            label_name = line[1:].strip()
            labels[label_name] = i
            cleaned_lines[i] = "NOP"

    # Replace labels in the code with their addresses
    for i, line in enumerate(cleaned_lines):
        for label, address in labels.items():
            if "." + label in line:
                cleaned_lines[i] = line.replace("." + label, str(address))


    # Assemble the cleaned lines into machine code
    instruction_info = []
    for line in cleaned_lines:
        values = {
            "R1": 0,
            "R2": 0,
            "R3": 0,
            "IMM": 0
        }
        valid_instruction = False
        for instr in INSTRUCTION_SET:
            if re.match(instr["regex"], line):
                valid_instruction = True
                # Extract the values for each group
                groups = re.match(instr["regex"], line).groups()
                for i, group in enumerate(groups):
                    if instr["group_mapping"][i] == "IMM":
                        values["IMM"] = int(group)
                    else:
                        values[instr["group_mapping"][i]] = int(group)

                if instr["instruction_type"].endswith("I"):
                    machine_code = instr["opcode"] + get_binary(values["R1"], 5) + get_binary(values["R2"], 5) + get_binary(values["IMM"], 16)
                else:
                    machine_code = instr["opcode"] + get_binary(values["R1"], 5) + get_binary(values["R2"], 5) + get_binary(values["R3"], 5) + ("0" * 11)

                instruction_info.append({
                    "name": instr["name"],
                    "opcode": instr["opcode"],
                    "instruction_type": instr["instruction_type"],
                    "values": values,
                    "machine_code": machine_code
                })

                break

        if not valid_instruction:
            raise ValueError(f"Invalid instruction: {line}")

    # Validate all instructions are 32 bits
    for info in instruction_info:
        if len(info["machine_code"]) != 32:
            raise ValueError(f"Machine code for instruction {info['name']} is not 32 bits: {info['machine_code']}")

    return instruction_info

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python assembler.py <assembly_file> <optional output_file>")
        sys.exit(1)
    
    assembly_file = sys.argv[1]
    if len(sys.argv) == 2:
        output_file = assembly_file.replace(".asm", ".bin")
    else:
        output_file = sys.argv[2]
    parsed_file = assemble(assembly_file)

    if "-pp" in sys.argv:
        # Print parsed instructions
        for i, instruction in enumerate(parsed_file):
            print(f"{i}: {instruction}")

    with open(output_file, 'wb') as f:
        for instruction in parsed_file:
            # Convert string of 0 and 1 into bytes and write to file
            byte_array = int(instruction["machine_code"], 2).to_bytes(4, byteorder='big')
            f.write(byte_array)

    print(f"Assembly code from {assembly_file} has been assembled and written to {output_file}.")