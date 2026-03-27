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
    parameter max_delta = 16,      
    parameter possible_message_types = 4,
    parameter FIX_msg_type_bits = 16,  // 2 bytes for FIX
    parameter sq_num_bits = $clog2(max_delta), 
    parameter time_bits = $clog2(max_delta),
    parameter CIOrdID_bits = 32,
    parameter header_bits = sq_num_bits + time_bits + CIOrdID_bits,
    parameter clk_period = 10, // Assume 10 ns(100 MHz)
    parameter orders_generated = 4
    )(
    input logic rstn,
    input logic clk,
    input logic [$clog2(max_delta)-1:0] incoming_seq_num,  // Poll from incoming messages 
    output logic [header_bits-1:0] header,
    output logic [15:0] message_size // Needed to compute bodylength and checksum downstream
    );
    
    /**
     * FIELDS ENCODED : MsgSeqNum(Delta), SendingTime(Tail), CIOrdID(no op)
     * FILEDS TODO DOWNSTREAM : BodyLength(delta), MsgType(no op), CheckSum(delta)
     * CONSTANT FIELDS : BeginString, SenderCompID, TargetCompID
     */
    
    // No Op Feilds
    logic [CIOrdID_bits-1:0] CIOrdID;
    
    // Delta(internal previous)
    logic [sq_num_bits-1:0] MsgSeqNum;
    logic [sq_num_bits-1:0] PrevMsgSeqNum;
    logic [time_bits-1:0] SendingTime;
    logic [time_bits-1:0] CurrTime;
    logic [time_bits-1:0] PrevTime;
   
    
    // Generator for time : ASCII
    logic [5:0] colon, period;
    assign colon = 58;
    assign period = 46;
    logic [5:0] ms1, ms2, ms3, sec1, sec2, min1, min2, hour1, hour2;
    assign CurrTime = {hour2, hour1, colon, min2, min1, period, sec2, sec1, period, ms3, ms2, ms1};
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
    
    // Tail Encode Time
    assign SendingTime = CurrTime - PrevTime;
    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            PrevTime <= 0;
        end
        else begin
            PrevTime <= CurrTime; 
        end
    end 
    
    
    // Need a generator for order ID(only for buy orders)
    RandomGen G1 (
        .clk(clk),
        .rstn(rstn),
        .randnum(CIOrdID)
    );
    
    // Sequence number
    assign MsgSeqNum = (orders_generated + incoming_seq_num) - PrevMsgSeqNum; // Assume only "orders_generated" number added to sequence 
    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            PrevMsgSeqNum <= 0;
        end
        else begin
            PrevMsgSeqNum <= (orders_generated + incoming_seq_num); 
        end
    end 
    
    always_comb begin
        message_size = 2 + 1 + 4; 
    end
    
    // Generator 1 header stream, then fill in message_type and checksum downstream
    assign header = {MsgSeqNum, SendingTime, CIOrdID};
    
    
endmodule
