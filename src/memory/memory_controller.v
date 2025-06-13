// Standard LRU algorithm for eviction
function [1:0] eviction_algorithm (
    input [3:0] loaded,
    input [31:0] last_access_time_0,
    input [31:0] last_access_time_1,
    input [31:0] last_access_time_2,
    input [31:0] last_access_time_3
);
    if (loaded[0] == 0)
        eviction_algorithm = 0;
    else if (loaded[1] == 0)
        eviction_algorithm = 1;
    else if (loaded[2] == 0)
        eviction_algorithm = 2;
    else if (loaded[3] == 0)
        eviction_algorithm = 3;
    else begin
        // Find the least recently used page
        if (last_access_time_0 < last_access_time_1 && last_access_time_0 < last_access_time_2 && last_access_time_0 < last_access_time_3)
            eviction_algorithm = 0;
        else if (last_access_time_1 < last_access_time_0 && last_access_time_1 < last_access_time_2 && last_access_time_1 < last_access_time_3)
            eviction_algorithm = 1;
        else if (last_access_time_2 < last_access_time_0 && last_access_time_2 < last_access_time_1 && last_access_time_2 < last_access_time_3)
            eviction_algorithm = 2;
        else
            eviction_algorithm = 3;
    end
endfunction

module memory_controller (
`ifdef USE_POWER_PINS
    input wire vccd1, // 1.8V power supply
    input wire vssd1, // Ground
`endif
    input wire clk,
    input wire rst_n,
    input wire cs,

    // RAM communication protocol
    input wire ram_slave_ack,
    input wire [31:0] ram_slave_data,
    output reg ram_master_req,
    output reg [48:0] ram_master_data, // we, Address, data

    // Memory interface
    input wire mem_we,               // Write enable (1 for write, 0 for read)
    input wire [15:0] mem_addr,      // Address for memory access
    input wire [31:0] mem_data_in,   // Data to be written
    input wire mem_flush,            // Flush signal (1 for flush, 0 for no flush)
    output wire [31:0] mem_data_out, // Data read from memory
    output reg mem_is_valid          // Indicates if memory is valid and can be read
);
    parameter L1_READ_WRITE_DELAY = 1; // Burn x + 1 cycle for read/write to l1
    reg [2:0] l1_read_write_delay_counter;

    localparam [3:0] MEM_CONTROLLER_IDLE  = 4'b0000, // Idle state
                     MEM_CONTROLLER_IDLE_WAIT = 4'b0001, // Waiting for idle
                     MEM_CONTROLLER_EVICT = 4'b0010, // Evicting a page
                     MEM_CONTROLLER_EVICT_SEND = 4'b0011, // Sending eviction request
                     MEM_CONTROLLER_EVICT_WAIT = 4'b0100, // Waiting for eviction
                     MEM_CONTROLLER_LOAD = 4'b0101, // Loading a new page
                     MEM_CONTROLLER_LOAD_WAIT = 4'b0110, // Waiting for load
                     MEM_CONTROLLER_FLUSH = 4'b0111, // Flushing the cache
                     MEM_CONTROLLER_FLUSH_WAIT = 4'b1000, // Waiting for flush
                     MEM_CONTROLLER_FLUSH_SEND = 4'b1001, // Sending flush request
                     MEM_CONTROLLER_FLUSH_DONE = 4'b1010; // Flush done

    reg [3:0] state; // State of the memory controller

    reg [3:0] l1_loaded_mask; // Which l1 cache pages are used
    reg [7:0] l1_pages [0:3]; // Pages currently loaded in L1 cache

    // For LRU algorithm
    reg [31:0] access_time; // Current access time
    reg [31:0] last_access_times [0:3]; // Last access time for each page

    reg[3:0] use_chip; // Register determines which l1 mem chip to use

    reg [1:0] cur_page_index;
    reg [1:0] l1_evict_load_index; // Page to evict/load 0, 1, 2, 3
    reg [7:0] page_to_load_addr;

    reg [7:0] word_counter; // Which word to read / write when evicting / loading
    reg [1:0] page_flush_index; // Which page we are flushing
    reg [7:0] mem_addr_temp;
    reg mem_we_temp;
    reg [31:0] mem_data_in_temp;

    // Communication protocol with external RAM
    reg [48:0] ram_req_data; // we + Address + data
    reg  [31:0] ram_res_data;
    reg  ram_res_valid;
    reg  ram_can_send;

    reg  ram_request; // Request signal to RAM

    wire [31:0] mem_data_out_0, mem_data_out_1, mem_data_out_2, mem_data_out_3;
    /* verilator lint_off UNUSEDSIGNAL */
    wire [31:0] mem_data_out_x0, mem_data_out_x1, mem_data_out_x2, mem_data_out_x3;

    sky130_sram_1kbyte_1rw1r_32x256_8 l1_0 (
`ifdef USE_POWER_PINS
        .vccd1(vccd1), // 1.8V power supply
        .vssd1(vssd1), // Ground
`endif
        .clk0(clk),
        .csb0(~(use_chip[0])), // Chip select (active low)
        .web0(~mem_we_temp), // Write enable (active low)
        .wmask0(4'b1111), // Write mask (all bits)
        .addr0(mem_addr_temp), // Address for write
        .din0(mem_data_in_temp), // Data input for write
        .dout0(mem_data_out_0), // Data output for read
        .clk1(1'b0), // Clock for read
        .csb1(1'b0), // Chip select for read (active low)
        .addr1(8'b0), // Address for read
        .dout1(mem_data_out_x0) // Data output for read
    );

    sky130_sram_1kbyte_1rw1r_32x256_8 l1_1 (
`ifdef USE_POWER_PINS
        .vccd1(vccd1), // 1.8V power supply
        .vssd1(vssd1), // Ground
`endif
        .clk0(clk),
        .csb0(~(use_chip[1])), // Chip select (active low)
        .web0(~mem_we_temp), // Write enable (active low)
        .wmask0(4'b1111), // Write mask (all bits)
        .addr0(mem_addr_temp), // Address for write
        .din0(mem_data_in_temp), // Data input for write
        .dout0(mem_data_out_1), // Data output for read
        .clk1(1'b0), // Clock for read
        .csb1(1'b0), // Chip select for read (active low)
        .addr1(8'b0), // Address for read
        .dout1(mem_data_out_x1) // Data output for read
    );

    sky130_sram_1kbyte_1rw1r_32x256_8 l1_2 (
`ifdef USE_POWER_PINS
        .vccd1(vccd1), // 1.8V power supply
        .vssd1(vssd1), // Ground
`endif
        .clk0(clk),
        .csb0(~(use_chip[2])), // Chip select (active low)
        .web0(~mem_we_temp), // Write enable (active low)
        .wmask0(4'b1111), // Write mask (all bits)
        .addr0(mem_addr_temp), // Address for write
        .din0(mem_data_in_temp), // Data input for write
        .dout0(mem_data_out_2), // Data output for read
        .clk1(1'b0), // Clock for read
        .csb1(1'b0), // Chip select for read (active low)
        .addr1(8'b0), // Address for read
        .dout1(mem_data_out_x2) // Data output for read
    );

    sky130_sram_1kbyte_1rw1r_32x256_8 l1_3 (
`ifdef USE_POWER_PINS
        .vccd1(vccd1), // 1.8V power supply
        .vssd1(vssd1), // Ground
`endif
        .clk0(clk),
        .csb0(~(use_chip[3])), // Chip select (active low)
        .web0(~mem_we_temp), // Write enable (active low)
        .wmask0(4'b1111), // Write mask (all bits)
        .addr0(mem_addr_temp), // Address for write
        .din0(mem_data_in_temp), // Data input for write
        .dout0(mem_data_out_3), // Data output for read
        .clk1(1'b0), // Clock for read
        .csb1(1'b0), // Chip select for read (active low)
        .addr1(8'b0), // Address for read
        .dout1(mem_data_out_x3) // Data output for read
    );

    assign mem_data_out = (use_chip[0]) ? mem_data_out_0 :
                          (use_chip[1]) ? mem_data_out_1 :
                          (use_chip[2]) ? mem_data_out_2 :
                          (use_chip[3]) ? mem_data_out_3 : 32'b0;

    master_requester 
    # (
        .REQ_DATA_WIDTH(49), // we + Address + data
        .RES_DATA_WIDTH(32) // Data
    ) ram_protocol (
        .clk(clk),
        .rst_n(rst_n),
        .slave_raw_ack(ram_slave_ack), // When high, data is valid
        .slave_data(ram_slave_data), // Data from slave
        .master_req(ram_master_req), // Request signal to slave
        .master_data(ram_master_data), // Data to be sent to slave
        .pulse(ram_request), // Pulse signal to trigger the request
        .send_data(ram_req_data), // transmitted data
        .recv_data(ram_res_data), // received output
        .recv_valid(ram_res_valid), // Indicates if the received data is valid
        .can_send(ram_can_send) // Indicates if the master can send data
    );

    always @(posedge clk ) begin
        if (!rst_n) begin
            l1_loaded_mask <= 4'b0000; // Reset L1 mask
            l1_pages[0] <= 8'h00; // Reset L1 pages
            l1_pages[1] <= 8'h00;
            l1_pages[2] <= 8'h00;
            l1_pages[3] <= 8'h00;
            state <= MEM_CONTROLLER_IDLE; // Reset state
            mem_is_valid <= 0; // Reset memory validity
            word_counter <= 0; // Reset word counter
            l1_read_write_delay_counter <= 0;
        end else begin
            if (cs) begin
                case (state)
                    MEM_CONTROLLER_IDLE: begin
                        if (!mem_flush) begin
                            mem_we_temp <= mem_we;
                            mem_addr_temp <= mem_addr[7:0];
                            mem_data_in_temp <= mem_data_in;
                            use_chip[0] <= (mem_addr[15:8] == l1_pages[0]) && l1_loaded_mask[0];
                            use_chip[1] <= (mem_addr[15:8] == l1_pages[1]) && l1_loaded_mask[1];
                            use_chip[2] <= (mem_addr[15:8] == l1_pages[2]) && l1_loaded_mask[2];
                            use_chip[3] <= (mem_addr[15:8] == l1_pages[3]) && l1_loaded_mask[3];

                            if ((mem_addr[15:8] == l1_pages[0]) && l1_loaded_mask[0] ||
                                (mem_addr[15:8] == l1_pages[1]) && l1_loaded_mask[1] ||
                                (mem_addr[15:8] == l1_pages[2]) && l1_loaded_mask[2] ||
                                (mem_addr[15:8] == l1_pages[3]) && l1_loaded_mask[3]
                            ) begin
                                // Page hit
                                if (mem_addr[15:8] == l1_pages[0]) begin
                                    cur_page_index <= 0; // Page 0
                                end else if (mem_addr[15:8] == l1_pages[1]) begin
                                    cur_page_index <= 1; // Page 1
                                end else if (mem_addr[15:8] == l1_pages[2]) begin
                                    cur_page_index <= 2; // Page 2
                                end else if (mem_addr[15:8] == l1_pages[3]) begin
                                    cur_page_index <= 3; // Page 3
                                end

                                l1_read_write_delay_counter <= L1_READ_WRITE_DELAY; // Set delay counter
                                state <= MEM_CONTROLLER_IDLE_WAIT; // Wait L1 cache delay
                            end else begin
                                $display(" MEMORY CONTROLLER: Page miss: %h", mem_addr[15:8]);
                                // We need to load a new page
                                l1_evict_load_index = eviction_algorithm(l1_loaded_mask, last_access_times[0], last_access_times[1], last_access_times[2], last_access_times[3]); // Get the page to evict/load
                                
                                mem_is_valid <= 0; // Memory is not valid
                                page_to_load_addr <= mem_addr[15:8]; // Address to load
                                if (l1_loaded_mask[l1_evict_load_index] == 1) begin
                                    // Page is already loaded, we need to evict it
                                    $display(" MEMORY CONTROLLER: Evicting page from L1_%d addr: %h", l1_evict_load_index, l1_pages[l1_evict_load_index]);
                                    state <= MEM_CONTROLLER_EVICT;
                                end else begin
                                    $display(" MEMORY CONTROLLER: Loading page into L1_%d addr: %h", l1_evict_load_index, mem_addr[15:8]);
                                    // No page loaded, just load the new page
                                    state <= MEM_CONTROLLER_LOAD;
                                end
                            end
                        end else begin
                            // Flush the cache
                            $display(" MEMORY CONTROLLER: Flushing page from L1_%d addr: %h", 1'b0, l1_pages[0]);
                            page_flush_index <= 0;
                            word_counter <= 0;
                            mem_is_valid <= 0;
                            state <= MEM_CONTROLLER_FLUSH;
                        end
                    end

                    MEM_CONTROLLER_IDLE_WAIT: begin
                        if (l1_read_write_delay_counter > 0) begin
                            l1_read_write_delay_counter <= l1_read_write_delay_counter - 1; // Decrement delay counter
                        end else begin
                            access_time <= access_time + 1;
                            last_access_times[cur_page_index] <= access_time; // Update last access time
                            mem_is_valid <= 1; // Memory is valid
                            state <= MEM_CONTROLLER_IDLE; // Go back to idle state
                        end
                    end

                    MEM_CONTROLLER_FLUSH: begin
                        if (ram_can_send) begin
                            use_chip <= 4'b0001 << page_flush_index; // Enable the chip to flush
                            mem_we_temp <= 0; // Read from l1 cache
                            mem_addr_temp <= word_counter; // Address to read from

                            ram_request <= 0; // Request to main memory
                            // ram_req_data <= {1'b1, {l1_pages[page_flush_index], word_counter}, mem_data_out}; // Write enable + address + data
                            state <= MEM_CONTROLLER_FLUSH_SEND; // Wait for flush
                            l1_read_write_delay_counter <= L1_READ_WRITE_DELAY;
                        end
                    end

                    MEM_CONTROLLER_FLUSH_SEND: begin // Wait for latch of ram_req_data
                        if (l1_read_write_delay_counter > 0) begin
                            l1_read_write_delay_counter <= l1_read_write_delay_counter - 1; // Decrement delay counter
                        end else begin
                            ram_request <= 1; // Request to main memory
                            ram_req_data <= {1'b1, {l1_pages[page_flush_index], word_counter}, mem_data_out}; // Write enable + address + data
                            state <= MEM_CONTROLLER_FLUSH_WAIT; // Wait for flush
                        end
                    end

                    MEM_CONTROLLER_FLUSH_WAIT: begin
                        if (ram_res_valid) begin
                            ram_request <= 0; // Clear request signal
                            if (word_counter == 8'b11111111) begin
                                // We've flushed the page, now we can go to the next page
                                if (page_flush_index == 3) begin
                                    mem_is_valid <= 1; // Indicate request is complete
                                    state <= MEM_CONTROLLER_FLUSH_DONE; // Go back to idle state
                                end else begin
                                    page_flush_index <= page_flush_index + 1; // Increment page flush index
                                    if (l1_loaded_mask[page_flush_index + 1] == 1) begin
                                        $display(" MEMORY CONTROLLER: Flushing page from L1_%d addr: %h", page_flush_index + 1, l1_pages[page_flush_index + 1]);
                                        word_counter <= 0; // Reset word counter
                                    end else begin
                                        $display(" MEMORY CONTROLLER: Not flushing page L1_%d (empty)", page_flush_index + 1);
                                    end
                                    state <= MEM_CONTROLLER_FLUSH; // Continue flushing
                                end
                            end else begin
                                word_counter <= word_counter + 1; // Increment word counter
                                state <= MEM_CONTROLLER_FLUSH; // Continue flushing
                            end
                        end
                    end

                    MEM_CONTROLLER_FLUSH_DONE: begin
                        $display(" MEMORY CONTROLLER: Flushing complete.");
                        mem_is_valid <= 1; // Indicate request is complete
                        state <= MEM_CONTROLLER_IDLE; // Go back to idle state
                    end

                    MEM_CONTROLLER_EVICT: begin
                        // Write back to main memory from the l1 cache
                        if (ram_can_send) begin
                            use_chip <= 4'b0001 << l1_evict_load_index; // Enable the chip to evict
                            mem_we_temp <= 0; // Read from l1 cache
                            mem_addr_temp <= word_counter; // Address to read from

                            ram_request <= 0; // Request to main memory
                            // ram_req_data <= {1'b1, {l1_pages[l1_evict_load_index], word_counter}, mem_data_out}; // Write enable + address + data
                            state <= MEM_CONTROLLER_EVICT_SEND; // Wait for eviction
                            l1_read_write_delay_counter <= L1_READ_WRITE_DELAY;
                        end
                    end

                    MEM_CONTROLLER_EVICT_SEND: begin // Wait for latch of ram_req_data
                        if (l1_read_write_delay_counter > 0) begin
                            l1_read_write_delay_counter <= l1_read_write_delay_counter - 1; // Decrement delay counter
                        end else begin
                            ram_request <= 1; // Request to main memory
                            ram_req_data <= {1'b1, {l1_pages[l1_evict_load_index], word_counter}, mem_data_out}; // Write enable + address + data
                            state <= MEM_CONTROLLER_EVICT_WAIT; // Wait for flush
                        end
                    end

                    MEM_CONTROLLER_EVICT_WAIT: begin
                        if (ram_res_valid) begin
                            ram_request <= 0; // Clear request signal
                            if (word_counter == 8'b11111111) begin
                                // We've evicted the page, now we can load a new page
                                $display(" MEMORY CONTROLLER: Loading page into L1_%d addr: %h", l1_evict_load_index, mem_addr[15:8]);
                                state <= MEM_CONTROLLER_LOAD; // Load a new page
                            end else begin
                                state <= MEM_CONTROLLER_EVICT; // Continue evicting
                            end
                            word_counter <= word_counter + 1; // Increment word counter
                        end
                    end

                    MEM_CONTROLLER_LOAD: begin
                        if (ram_can_send) begin
                            ram_request <= 1; // Request to main memory
                            ram_req_data <= {1'b0, {page_to_load_addr, word_counter}, mem_data_out}; // Write enable + address + data
                            state <= MEM_CONTROLLER_LOAD_WAIT; // Wait for load
                        end
                    end

                    MEM_CONTROLLER_LOAD_WAIT: begin
                        if (ram_res_valid) begin
                            ram_request <= 0; // Clear request signal
                            use_chip <= 4'b0001 << l1_evict_load_index; // Enable the chip to evict
                            mem_we_temp <= 1; // Write to l1 cache
                            mem_addr_temp <= word_counter; // Address to write from

                            mem_data_in_temp <= ram_res_data; // Data to write

                            if (word_counter == 8'b11111111) begin
                                // We've loaded the page, now we can go back to idle
                                l1_loaded_mask[l1_evict_load_index] <= 1; // Mark the page as loaded
                                l1_pages[l1_evict_load_index] <= page_to_load_addr; // Update the page in L1 cache
                                state <= MEM_CONTROLLER_IDLE; // Go back to idle state
                            end else begin
                                state <= MEM_CONTROLLER_LOAD; // Continue loading
                            end
                            word_counter <= word_counter + 1; // Increment word counter
                        end
                    end
                    default: begin
                        state <= MEM_CONTROLLER_IDLE; // Default to idle state on error
                    end
                endcase
            end else begin // Chip is not selected
                state <= MEM_CONTROLLER_IDLE; // Go back to idle state
                mem_is_valid <= 0; // Memory is not valid
                ram_request <= 0; // Clear request signal
                // ram_master_req <= 0; // Clear request signal
                // ram_can_send <= 1; // Indicate that the master can send data
            end
        end
    end
endmodule
