module test_synchronizer (
    input wire clk_a,
    input wire clk_b,
    input wire rst_n,

    // Trigger signals
    input wire master_start,    // Pulse signal to trigger the request
    input wire [31:0] master_send, // transmitted data
    output reg [31:0] master_recv,  // received output
    output reg master_recv_valid, // Indicates if the received data is valid
    output reg master_can_send // Indicates if the master can send data
);

    wire master_req; // Request signal to slave
    wire [31:0] master_data; // Data to be sent to slave
    wire slave_raw_ack; // When high, data is valid
    wire [31:0] slave_data; // Data from slave

    master_requester
    # (
        .REQ_DATA_WIDTH(32),
        .RES_DATA_WIDTH(32)
    ) master_requester_inst (
        .clk(clk_a),
        .rst_n(rst_n),

        .slave_raw_ack(slave_raw_ack), // When high, data is valid
        .slave_data(slave_data), // Data from slave

        .master_req(master_req), // Request signal to slave
        .master_data(master_data), // Data to be sent to slave

        // Trigger signals
        .pulse(master_start),    // Pulse signal to trigger the request
        .send_data(master_send), // transmitted data
        .recv_data(master_recv),  // received output
        .recv_valid(master_recv_valid), // Indicates if the received data is valid
        .can_send(master_can_send) // Indicates if the master can send data
    );

    slave_responder
    # (
        .REQ_DATA_WIDTH(32),
        .RES_DATA_WIDTH(32)
    ) slave_responder_inst (
        .clk(clk_b),
        .rst_n(rst_n),

        .master_raw_req(master_req), // Request signal from master
        .master_data(master_data), // Data from master

        .slave_raw_ack(slave_raw_ack), // Acknowledge signal to master
        .slave_data(slave_data) // Data to be sent to master
    );
    
endmodule
