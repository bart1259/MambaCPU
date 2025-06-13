## Compute the factorial of 8
# R0 - counter
R0 = 8
# R1 - result
R1 = 1
# R2 - temp
R2 = 0

R4 = 1 # Termination case
R3 = 256 # Start on second page of memory

.loop
    NOP
    R2 = R1 * R0
    NOP
    R1 = R2
    NOP
    R2 = R0 - 1
    NOP
    R0 = R2

    R0 != R4 ? JMP .loop


# Store the result in memory
[R3 + 0] = R1

FLSH
HLT