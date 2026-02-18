`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/13/2026 05:02:13 PM
// Design Name: 
// Module Name: MessageCtrl
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


module MessageFIFO_Ctrl #(
    parameter beat_width = 64,
    parameter max_message_size = 10,  // Max number of fields per template
    parameter num_decoders = 4,
    parameter field_op_size = 32,   // Assume 32 bits for ops per field
    parameter FIFO_size = 32,        // FIFO's store up to 32 fields at a time
    parameter messageID_size = 21,
    parameter num_messages = 1,
    parameter FIFO_width = 2
    )(
    input clk,
    input rstn,
    input FIFO_filled,
    input logic [1+messageID_size+$clog2(max_message_size)+beat_width:0] decoded_fields [0:num_decoders-1],
    output logic [beat_width-1:0] ordered_messages [0:num_messages-1][0:max_message_size-1]
    );
    
    logic [1+messageID_size+$clog2(max_message_size)+beat_width:0] fifo_out [0:num_decoders*FIFO_width-1];
    logic [messageID_size-1:0] curr_messageID, next_messageID;
    logic [$clog2(max_message_size)-1:0] curr_count, next_count;
    logic [$clog2(2*num_decoders)-1:0] curr_idx, next_idx;
    logic curr_hit, next_hit;
    logic flush_curr, flush_next;
    reg [beat_width-1:0] message_rf [0:0][max_message_size-1:0];
    
    Field_FIFO U1(
        .clk(clk),
        .rstn(rstn),
        .decoded_fields(decoded_fields),
        .out_fields(fifo_out)
    );
    
    integer k;
    always_comb begin
        curr_hit = 0;
        next_hit = 0;
        curr_idx = 0;
        next_idx = 0;
        for(k = 0; k < FIFO_width*num_decoders; k = k + 1) begin
            if(  // Check field tag, valid, and message ID
            (fifo_out[k][$clog2(max_message_size)+beat_width -: $clog2(max_message_size)] == curr_count) &&
            (fifo_out[k][1+messageID_size+$clog2(max_message_size)+beat_width]) &&
            (fifo_out[k][messageID_size+$clog2(max_message_size)+beat_width -: messageID_size] == curr_messageID)) begin
                curr_hit = 1;
                curr_idx = k;
            end
            if(
            (fifo_out[k][$clog2(max_message_size)+beat_width -: $clog2(max_message_size)] == next_count) &&
            (fifo_out[k][1+messageID_size+$clog2(max_message_size)+beat_width]) &&
            (fifo_out[k][messageID_size+$clog2(max_message_size)+beat_width -: messageID_size] == curr_messageID)) begin
                next_hit = 1;
                next_idx = k;
            end
        end
    end 
    
    // Fill output messages until done, then flush them
    always_ff @(posedge clk) begin
        if(!rstn) begin
            message_rf[0][curr_count] <= 0;
            message_rf[1][next_count] <= 0;
            curr_count <= 0;
            next_count <= 0;
            flush_curr <= 0;
            flush_next <= 0;
        end
        else begin
            if(curr_hit) begin
                message_rf[0][curr_count] <= fifo_out[curr_idx][beat_width-1:0];
                curr_count <= curr_count + 1;
                if(curr_count == max_message_size) begin // fix this to be dynamic size based on template
                    flush_curr <= 1;
                    curr_count <= 0;
                    ordered_messages[0] <= message_rf[0];
                end
                else begin
                    flush_curr <= 0;
                end
            end
            if(next_hit) begin
                message_rf[1][next_count] <= fifo_out[next_idx][beat_width-1:0];
                next_count <= next_count + 1;
                if(next_count == max_message_size) begin // fix this
                    flush_next <= 1;
                    next_count <= 0;
                    ordered_messages[1] <= message_rf[1];
                end
                else begin
                    flush_next <= 0;
                end
            end
        end
    end
    
    
endmodule
