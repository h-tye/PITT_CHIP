`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/22/2026 09:22:40 PM
// Design Name: 
// Module Name: Header_Dt_Enc
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


module Header_Dt_Enc #(
    parameter max_delta = 16,      
    parameter possible_message_types = 4,
    parameter FIX_msg_type_bits = 16,  // 2 bytes for FIX
    parameter sq_num_bits = $clog2(max_delta), 
    parameter time_bits = $clog2(max_delta),
    parameter CIOrdID_bits = 32,
    parameter header_bits = sq_num_bits + time_bits + CIOrdID_bits,
    parameter dt_sq_num_bits = sq_num_bits + (sq_num_bits / 7 + 1),
    parameter dt_time_bits = time_bits + (time_bits / 7 + 1),
    parameter dt_CIOrdID_bits = CIOrdID_bits + (CIOrdID_bits / 7 + 1),
    parameter dt_header_bits = dt_sq_num_bits + dt_time_bits + dt_CIOrdID_bits,
    parameter clk_period = 10, // Assume 10 ns(100 MHz)
    parameter orders_generated = 4
    )(
    input logic clk,
    input logic rstn,
    input logic [header_bits-1:0] header,
    input logic [15:0] message_size,
    output logic [dt_header_bits-1:0] dt_header,
    output logic [15:0] dt_message_size
    );
    
    assign dt_message_size = dt_header_bits;
    // MsgSeqNum
    int_enc #(.input_width(sq_num_bits)) M(
        .nullable(0),
        .encoded_size(sq_num_bits),
        .op_encoded_value(header[header_bits-1 -: sq_num_bits]),
        .dt_encoded_value(dt_header[dt_header_bits-1 -: dt_sq_num_bits])
    );
    
    // SendingTime
    ascii_enc #(.input_width(time_bits)) S(
        .nullable(0),
        .encoded_size(time_bits),
        .op_encoded_value(header[header_bits-sq_num_bits-1 -: time_bits]),
        .dt_encoded_value(dt_header[dt_header_bits-dt_sq_num_bits-1 -: dt_time_bits])
    );
    
    // CIOrdID
    int_enc #(.input_width(CIOrdID_bits)) C(
        .nullable(0),
        .encoded_size(CIOrdID_bits),
        .op_encoded_value(header[header_bits-1 -: sq_num_bits]),
        .dt_encoded_value(dt_header[dt_header_bits-1 -: dt_sq_num_bits])
    );
endmodule
