`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/09/2026 11:15:43 PM
// Design Name: 
// Module Name: FieldAligner
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


module FieldAligner #(
    parameter beat_width = 64,
    parameter max_message_size = 10,   // Max number of fields in a template
    parameter num_templates = 4,
    parameter ring_size = 16
    )(
    input logic clk,
    input logic [beat_width-1:0] din,
    input logic [$clog2(max_message_size)-1:0] message_field_count,
    input logic rstn,
    output logic new_message,
    output logic [beat_width+1:0] douts [0:3],  // Superscalar so we are able to process more than 1 field at a time
    output logic [0:3] field_valid  // Indicates whether superscalar path has valid feild
    );
    
    // Stop & start ptr calc
    reg [ring_size-1:0] stop_ptrs;
    reg [ring_size-1:0] stop_bits;
    reg [7:0] ring_buffer [0:ring_size-1];
    reg [$clog2(max_message_size)-1:0] current_field_count;
    logic [2:0] stop_ptr [0:3];   // four pointers, each 3-bit index
    logic [2:0] start_ptr;
    integer k, j;
    int count = 0;
    
    // Extract stop bits
    always_comb begin
        for(k = 0; k < ring_size/2; k = k + 1) begin
            stop_bits[k] = din[(k*8)-1];
        end
    end 
    
    //Store din
    logic top_full;
    always_ff @(posedge clk) begin
        if(~rstn) begin
            for(k = 0; k < ring_size; k = k + 1) begin
                    ring_buffer[k] <= 0;
                    stop_ptrs[k] <= 0;
            end
        end
        else
            if(~top_full) begin
                for(k = 0; k < ring_size/2; k = k + 1) begin
                    ring_buffer[k] <= din[((k+1)*8)-1 -: 8];
                end
                top_full <= 1;
            end
            else begin
                for(k = ring_size/2; k < ring_size; k = k + 1) begin
                    ring_buffer[k] <= din[((k+1)*8)-1 -: 8];
                end
                top_full <= 0;
            end
    end
    
    // Field ptr generatrion
    always_comb begin
        for (int i = 7; i >= 0; i--) begin
            if (stop_bits[i] && count < 4) begin
                stop_ptr[count] = i;
                field_valid[count] = 1;
                count++;
                current_field_count <= current_field_count + 1;
                if(current_field_count == message_field_count - 1) begin
                    douts[count][beat_width+1] <= 1; // Indicate this field is PMAP
                end
                else if (current_field_count == message_field_count) begin
                    douts[count][beat_width] <= 1;   // Indicat this field is TID
                    new_message <= 1;
                end
            end
        end
        for (j = count; j < 4; j++) begin
            stop_ptr[j] = '0;
            field_valid[j] = 0;
        end
        start_ptr <= stop_ptr[3]; // Take stop of previous cycle
    end

    
    // Assignment of fields to superscalar streams
    always_comb begin
        for(j = 0; j < 4; j = j + 1) begin
            if(j == 0) begin
                for(k = start_ptr; k < stop_ptr[0] + start_ptr; k = k + 1) begin
                    douts[j][(k+1)*7 -: 8] <= ring_buffer[k];
                end
            end
            else begin
                for(k = start_ptr + stop_ptr[j - 1]; k < stop_ptr[j] + start_ptr; k = k + 1) begin
                    douts[j][(k+1)*7 -: 8] <= ring_buffer[k];
                end
            end
        end
    end

endmodule
