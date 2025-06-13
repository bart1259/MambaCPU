/* verilator lint_off MULTITOP */
module slave_responder
# (
    parameter REQ_DATA_WIDTH = 32,
    parameter RES_DATA_WIDTH = 32
) (
    input wire clk,
    input wire rst_n,

    input wire master_raw_req, // Request signal from master
    input wire[REQ_DATA_WIDTH-1:0] master_data, // Data from master

    output reg slave_raw_ack, // Acknowledge signal to master
    output reg[RES_DATA_WIDTH-1:0] slave_data // Data to be sent to master
);
    localparam [1:0] SLAVE_IDLE = 2'b00, // Idle state
                     SLAVE_WAIT = 2'b01; // Waiting for data

    reg [1:0] state; // State of the receiver
    reg synched_req; // Synchronized request signal

    // Synchronize the raw_req signal
    two_flop_sync #(.WIDTH(1)) sync_req (
        .clk(clk),
        .rst_n(rst_n),
        .in_data(master_raw_req),
        .out_data(synched_req)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= SLAVE_IDLE; // Reset state
            slave_raw_ack <= 0; // Clear acknowledge signal
            slave_data <= 0; // Clear data register
        end else begin
            case (state)
                SLAVE_IDLE: begin
                    if (synched_req) begin
                        slave_raw_ack <= 1; // Acknowledge request
                        slave_data <= ~master_data; // Invert data from master
                        state <= SLAVE_WAIT; // Move to wait state
                    end
                end

                SLAVE_WAIT: begin
                    if (!synched_req) begin
                        slave_raw_ack <= 0; // Clear acknowledge signal
                        state <= SLAVE_IDLE; // Move to idle state
                    end
                end

                default: begin
                    state <= SLAVE_IDLE; // Default to idle state on error
                end
            endcase
        end
    end

endmodule
