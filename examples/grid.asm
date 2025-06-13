R0 = 0 # X coordinate
R1 = 0 # Y coordinate
R2 = 16 # X/Y Size

R4 = 256 # Base address for output

R5 = 0 # black pixel
R6 = 1 # white pixel
R7 = 4 # Mask
R13 = 2

# Iterate over x and y
.x_loop
    R0 = 0


    .y_loop
        # Compute address
        R8 = 16
        R3 = R1 * R8
        R9 = R3 + R0
        R3 = R9 + R4

        R11 = R0 + R1
        R11 = R11 & R6

        R11 != R6 ? JMP .draw_white

        .draw_black
            # Draw black pixel
            [R3 + 0] = R5 # Set pixel to black
            JMP .done_drawing

        .draw_white
            # Draw white pixel
            [R3 + 0] = R6 # Set pixel to white
            JMP .done_drawing

        .done_drawing

        R3 = R0 + 1
        R0 = R3 # R0 += 1

        R0 != R2 ? JMP .y_loop

    R3 = R1 + 1
    R1 = R3 # R1 += 1
    R1 != R2 ? JMP .x_loop

# Done
FLSH
HLT