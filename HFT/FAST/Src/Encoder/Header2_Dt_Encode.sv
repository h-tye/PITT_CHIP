`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/29/2026 11:40:22 AM
// Design Name: 
// Module Name: Header2_Dt_Encode
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


module Header2_Dt_Encode #(
    parameter orders_generated = 4,
    parameter max_delta = 16,
    parameter body_length_bits = max_delta,
    parameter checksum_bits = 8,
    parameter ord_type_bits = 8,
    parameter side_bits = 8,
    parameter dt_body_length_bits = body_length_bits + (body_length_bits / 7 + 1),
    parameter dt_ord_type_bits = ord_type_bits + (ord_type_bits / 7 + 1),
    parameter dt_side_bits = side_bits + (side_bits / 7 + 1),
    parameter dt_checksum_bits = checksum_bits + (checksum_bits / 7 + 1),
    parameter header2_bits = body_length_bits + ord_type_bits + side_bits + checksum_bits,
    parameter header2_size_bytes = header2_bits / 7 + 1
    )(
    input logic [header2_bits-1:0] header2 [orders_generated],
    output logic [header2_size_bytes*8-1:0] dt_header2 [orders_generated]
    );
    
    
    // Body length
    int_enc #(.input_width(body_length_bits)) B(
        .nullable(0),
        .op_encoded_value(header2[header2_bits-1 -: body_length_bits]),
        .dt_encoded_value(dt_header2[header2_size_bytes*8-1 -: dt_body_length_bits])
    );
        
    // Ord Type 
    ascii_enc #(.input_width(ord_type_bits)) O(
        .nullable(0),
        .op_encoded_value(header2[header2_bits-body_length_bits-1 -: ord_type_bits]),
        .dt_encoded_value(dt_header2[header2_size_bytes*8-dt_body_length_bits-1 -: dt_ord_type_bits])
    );
    
    // Side
    ascii_enc #(.input_width(side_bits)) S(
        .nullable(0),
        .op_encoded_value(header2[header2_bits-body_length_bits-ord_type_bits-1 -: side_bits]),
        .dt_encoded_value(dt_header2[header2_size_bytes*8-dt_body_length_bits-dt_ord_type_bits-1 -: dt_side_bits])
    );
    
    // Checksum
    int_enc #(.input_width(checksum_bits)) C(
        .nullable(0),
        .op_encoded_value(header2[checksum_bits-1:0]),
        .dt_encoded_value(dt_header2[dt_checksum_bits-1:0])
    );
    
    
endmodule
