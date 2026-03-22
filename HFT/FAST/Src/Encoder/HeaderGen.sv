`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/02/2026 08:39:32 PM
// Design Name: 
// Module Name: HeaderGen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module HeaderGen #(
    parameter max_message_size = 16,
    parameter possible_message_types = 4,
    parameter FIX_type_size = 2, // 2 bytes to represent FIX message type
    parameter S_COMPID = 0,
    parameter T_COMPID = 1,
    parameter sq_num_size = 16, // Unknown 
    parameter time_bits = 28,
    parameter checksum_bits = 32,
    parameter header_bits = 64 + $clog2(max_message_size) + FIX_type_size + 64 + 64 + sq_num_size + time_bits + 32 + checksum_bits,
    parameter clk_period = 10, // Assume 10 ns(100 MHz)
    parameter orders_generated = 4
    )(
    input logic rstn,
    input logic clk,
    output logic [header_bits-1:0] header,
    output logic [time_bits-1:0] real_time
    );
    
    logic [63:0] begin_string;
    logic [$clog2(max_message_size)-1:0] body_length;
    logic [FIX_type_size-1:0] message_type;
    logic [63:0] SenderCOMPID;
    logic [63:0] TargetCOMPID;
    logic [sq_num_size-1:0] MsgSeqNum;
    logic [time_bits-1:0] SendingTime;
    logic [31:0] CIOrdID;
    logic [checksum_bits-1:0] CheckSum; 
    
    always_comb begin
        begin_string = {8'h46, 8'h49, 8'h58, 8'h54, 8'h2e, 8'h31, 8'h2e, 8'h31}; // FIXT.1.1
        SenderCOMPID = S_COMPID;
        TargetCOMPID = T_COMPID;
        CheckSum = 8 + 1 + 8 + 8 + 2 + 4 + 4 + 4; // Total bytes used for header + CIOrdID
    end
    
    // Generator for time
    logic [3:0] ms1, ms2, ms3, sec1, sec2, min1, min2, hour1, hour2;
    assign SendingTime = {hour2, hour1, min2, min1, sec2, sec1, ms3, ms2, ms1};
    assign real_time = SendingTime;
    digitalClock #(.FREQ(100000000)) C1 (
        .clk(clk),
        .rstn(rstn),
        .ms1(ms1),
        .ms2(ms2),
        .ms3(ms3),
        .sec1(sec1),
        .sec2(sec2),
        .min1(min1),
        .min2(min2),
        .hour1(hour1),
        .hour2(hour2)
    );
    
    
    // Need a generator for order ID(only for buy orders)
    RandomGen G1 (
        .clk(clk),
        .rstn(rstn),
        .randnum(CIOrdID)
    );
    
    // Sequence number
    always_ff @(posedge clk) begin
        if(rstn) begin
            MsgSeqNum <= 0;
        end
        else begin
            MsgSeqNum <= MsgSeqNum + orders_generated;
        end
        
        // Generator 1 header stream, then fill in message_type and checksum downstream
        header <= {begin_string, body_length, message_type, SenderCOMPID, TargetCOMPID, MsgSeqNum, SendingTime, CIOrdID, CheckSum};
    end
    
    
endmodule
