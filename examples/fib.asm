## Fibonacci number generator
# R0 is the term counter
# R1 is the current term
# R2 is the previous term
# R3 is the term limit 
# R4 is temp
# R5 is base address for output
# R6 is the current address for output

### Initialize variables
# We start at iteration 0
R0 = 0
# Start with the first two terms
R1 = 0
R2 = 1
R3 = 30  # Count first 30 terms
R5 = 256 # Start on second page of memory

.loop
    R4 = R1 + R2 # Calculate next term
    R6 = R5 + R0 # Calculate address for output
    [R6 + 0] = R4 # Store the term in memory

    R0 = R0 + 1 # Increment term counter
    R1 = R2
    R2 = R4 # Update previous term to current term

    R0 != R3 ? JMP .loop

# Done
FLSH
HLT