`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/25/2026 11:02:27 PM
// Design Name: 
// Module Name: WriteBack
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


module WriteBack #(
    parameter beat_width = 64,
    parameter max_message_size = 10,   // Max number of fields in a template
    parameter num_templates = 4,
    parameter ring_size = 16,
    parameter sup_paths = 4,  // Superscalar paths
    parameter num_messages = 1,
    parameter num_decoders = sup_paths*2,
    parameter template_field_size = 10,
    parameter field_op_size = 32,
    parameter messageID_size = 21
    )(
    input logic [messageID_size+$clog2(max_message_size)+beat_width:0] decoded_field_stream [0:num_decoders/2-1],
    output logic [0:num_decoders/2-1] replace_field,
    output logic  [beat_width-1:0] replacement_field [0:num_decoders/2-1],
    output logic [$clog2(max_message_size)-1:0] replace_field_idx [0:num_decoders/2-1]
    );
    
    int k;
    always_comb begin
        for(k = 0; k < num_decoders/2; k = k + 1) begin
            if(decoded_fields_stream[k][messageID_size+$clog2(max_message_size)+beat_width]) begin
                replace_field[k] = 1;
                replace_field_idx[k] <= decoded_fields_stream[k][$clog2(max_message_size)+beat_width-1 -: $clog2(max_message_size)];
                replacement_field[k] <= decoded_fields_stream[k][beat_width-1:0];
            end
        end
    end
    
    
endmodule
