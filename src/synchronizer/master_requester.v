/* verilator lint_off MULTITOP */
module master_requester
# (
    parameter REQ_DATA_WIDTH = 32,
    parameter RES_DATA_WIDTH = 32
) (
    input wire clk,
    input wire rst_n,

    input wire slave_raw_ack, // When high, data is valid
    input wire[RES_DATA_WIDTH-1:0] slave_data, // Data from slave

    output reg master_req, // Request signal to slave
    output reg[REQ_DATA_WIDTH-1:0] master_data, // Data to be sent to slave

    // Trigger signals
    input wire pulse,    // Pulse signal to trigger the request
    input wire [REQ_DATA_WIDTH-1:0] send_data, // transmitted data
    output reg [RES_DATA_WIDTH-1:0] recv_data,  // received output
    output reg recv_valid, // Indicates if the received data is valid
    output reg can_send // Indicates if the master can send data
);
    localparam [1:0] MASTER_IDLE = 2'b00, // Idle state
                     MASTER_WAIT = 2'b01, // Waiting for ack
                     MASTER_DONE = 2'b10; // Done

    reg [1:0] state; // State of the transmitter
    reg synched_ack; // Synchronized ack signal

    // Synchronize the raw_valid signal
    two_flop_sync #(.WIDTH(1)) sync_ack (
        .clk(clk),
        .rst_n(rst_n),
        .in_data(slave_raw_ack),
        .out_data(synched_ack)
    );
    
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= MASTER_IDLE; // Reset state
            master_req <= 0; // Clear request signal
            recv_data <= 0; // Clear received data register
            recv_valid <= 0; // Clear valid signal
            can_send <= 1; // Indicate that the master can send data
        end else begin
            case (state)
                MASTER_IDLE: begin
                    if (pulse) begin
                        master_req <= 1; // Request to send data
                        master_data <= send_data; // Load data to be sent
                        state <= MASTER_WAIT; // Move to wait state
                        recv_valid <= 0; // Clear valid signal
                        can_send <= 0; // Indicate that the master is busy
                    end
                end

                MASTER_WAIT: begin
                    if (synched_ack) begin
                        master_req <= 0; // Clear request signal
                        recv_data <= slave_data; // Capture received data
                        recv_valid <= 1; // Indicate that data is valid
                        state <= MASTER_DONE; // Move to done state
                    end
                end

                MASTER_DONE: begin
                    if (!synched_ack) begin
                        master_req <= 0; // Clear request signal
                        state <= MASTER_IDLE; // Go back to idle state
                        recv_valid <= 0; // Clear the valid signal
                        can_send <= 1; // Indicate that the master can request more data
                    end
                end

                default: begin
                    state <= MASTER_IDLE; // Default to idle state on error
                end
            endcase
        end
    end

endmodule
