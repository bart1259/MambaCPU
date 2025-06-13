## Area of triangle generator

### Initialize variables
# Length of the base
R0 = 20
# Length of the height
R1 = 30
R4 = 256
R5 = 1

R2 = R0 * R1 # Calculate area
R3 = R2 >> R5 # Divide by 2

[R4 + 0] = R3 # Store the area in memory

# Done
FLSH
HLT