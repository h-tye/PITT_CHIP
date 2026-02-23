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
    parameter messageID_size = 21,
    parameter FIFO_width = 2
    )(
        input logic clk,
        input logic rstn,
        input logic [messageID_size+$clog2(max_message_size)+beat_width:0] decoded_fields [0:num_decoders-1],
        output logic [messageID_size+$clog2(max_message_size)+beat_width-1:0] out_fields [0:num_decoders*FIFO_width-1]
    );
    
    logic [$clog2(2*num_decoders)+messageID_size+$clog2(max_message_size)+beat_width-1:0] registers [0:2*num_decoders-1];
    logic start_ptr;
    integer k;
    
    always_ff @(posedge clk) begin
        if(!rstn) begin
            for(k = 0; k < FIFO_width*num_decoders; k = k + 1) begin
                registers[k] <= 0;
            end
            start_ptr <= 0;
        end
        else begin
            
            for(k = 0; k < num_decoders*FIFO_width; k = k + 1) begin
                out_fields[1+messageID_size+$clog2(max_message_size)+beat_width:0] <= registers[1+messageID_size+$clog2(max_message_size)+beat_width:0];
            end
            
            for(k = 0; k < num_decoders; k = k + 1) begin
                if(decoded_fields[k][messageID_size+$clog2(max_message_size)+beat_width]) begin // If decoded feild is valid
                    registers[start_ptr + k][messageID_size+$clog2(max_message_size)+beat_width-1:0] <= decoded_fields[k][messageID_size+$clog2(max_message_size)+beat_width-1:0];
                    start_ptr <= start_ptr + 1;
                    if(start_ptr == num_decoders*FIFO_width) begin
                        start_ptr <= 0;
                    end
                end
            end   
        end
    end
endmodule
