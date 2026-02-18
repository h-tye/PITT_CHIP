`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/18/2026 02:05:34 PM
// Design Name: 
// Module Name: Field_FIFO
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


module Field_FIFO #(
    parameter num_decoders = 4,
    parameter beat_width = 64,
    parameter max_message_size = 10, 
    parameter messageID_size = 21
    )(
        input logic clk,
        input logic rstn,
        input logic [1+messageID_size+$clog2(max_message_size)+beat_width:0] decoded_fields [0:num_decoders-1],
        output logic [1+messageID_size+$clog2(max_message_size)+beat_width:0] out_fields [0:num_decoders-1]
    );
    
    reg [$clog2(2*num_decoders)+1+messageID_size+$clog2(max_message_size)+beat_width:0] registers [0:2*num_decoders-1];
    reg start_ptr;
    integer k;
    
    always_ff @(posedge clk) begin
        if(!rstn) begin
            for(k = 0; k < 2*num_decoders; k = k + 1) begin
                registers[k] <= 0;
            end
            start_ptr <= 0;
        end
        else begin
            for(k = start_ptr; k < start_ptr + num_decoders; k = k + 1) begin
                out_fields[1+messageID_size+$clog2(max_message_size)+beat_width:0] <= registers[1+messageID_size+$clog2(max_message_size)+beat_width:0];
            end
            if(start_ptr <= 0) begin
                start_ptr <= 8;
            end 
            else begin
                start_ptr <= 0;
            end
            
        end
    end
endmodule
