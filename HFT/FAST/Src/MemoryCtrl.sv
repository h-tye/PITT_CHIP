`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/11/2026 07:37:13 PM
// Design Name: 
// Module Name: MemoryCtrl
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


module MemoryCtrl #(
    parameter beat_width = 64,
    parameter num_templates = 4,
    parameter template_field_size = 16, // Assume 16 bits of template info per field(datatype, operator)
    parameter max_message_size = 10  // Max number of fields per template
    )(
    input logic clk,
    input logic rstn,
    input logic new_message,
    input logic [beat_width+1:0] dins [0:3],
    input logic [3:0] field_valids,
    input logic [beat_width-1:0] replacement_field,         // To replace previous value
    input logic [$clog2(max_message_size)-1:0] replace_field_idx,
    input logic replace_field,
    output logic [$clog2(num_templates)-1:0] TID,
    output logic [template_field_size-1:0] out_template [max_message_size-1:0],
    output logic [beat_width-1:0] out_previous [max_message_size-1:0]
    );
    
    
    // Templates storage and previous value storage
    reg [template_field_size-1:0] template [num_templates-1:0][max_message_size-1:0];
    reg [beat_width-1:0] previous_values [num_templates-1:0][max_message_size-1:0];
    reg [$clog2(num_templates)-1:0] current_template;

    integer k;
    always_ff @(posedge clk) begin
        // Update temaplate and previous values for new message
        if(new_message) begin
            for(k = 0; k < num_templates; k = k + 1) begin
                if(dins[beat_width]) begin
                    TID <= dins[k];
                    out_template <= template[k];
                    out_previous <= previous_values[k];
                    current_template <= k;
                end
            end
        end
        // Replace previous value based on decoding logic
        if(replace_field) begin
            previous_values[current_template][replace_field_idx] <= replacement_field[replace_field_idx];
         end
    end 
    
    
endmodule
