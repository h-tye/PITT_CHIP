`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/22/2026 10:16:59 PM
// Design Name: 
// Module Name: OpScheduler
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


module OpScheduler #(
    parameter beat_width = 64,
    parameter num_templates = 4,
    parameter sup_paths = 4,
    parameter template_field_size = 10, // Assume 10 bits of template info per field(datatype, operator, optional, pmap, field num)
    parameter max_message_size = 10,  // Max number of fields per template
    parameter num_decoders = 4,  
    parameter field_op_size = 32   // Assume 32 bits for ops per field
    )(
    input logic clk,
    input logic rstn,
    input logic [sup_paths-1:0] field_complete,
    input logic [field_op_size-1:0] total_field_ops [max_message_size-1:0],
    output logic [field_op_size-1:0] field_ops [num_decoders:0]
    );
    
    logic [max_message_size-1:0] fields_issued;
    logic [max_message_size-1:0] fields_completed;
    logic [$clog2(max_message_size)-1:0] ops_order [0:num_decoders-1];
    int k,j;
    
    // Issue new ops based on completion
    integer field_count = 0;
    always_ff @(posedge clk) begin
        if(!rstn) begin
            for(j = 0; j < num_decoders; j = j + 1) begin
                fields_completed[j] <= 0;
            end
            for(k = 0; k < max_message_size ; k = k + 1) begin 
                field_ops[ops_order[k]] <= 0;
                field_count = 0;
            end
        end
        else begin
            for(j = 0; j < num_decoders; j = j + 1) begin
                if(field_complete[k]) begin
                    fields_completed[ops_order[k]] <= 1;
                end
                else begin
                    fields_completed[ops_order[k]] <= 0;
                end
            end
            
            for(k = 0; k < max_message_size ; k = k + 1) begin 
                if(!fields_completed[k] && field_count < num_decoders) begin // If not completed, reissue to same decoder
                    field_ops[ops_order[k]] <= total_field_ops[k];
                    field_count = field_count + 1;
                end
            end
        end
    end
    
    integer start_ptr;
    always_ff @(posedge clk) begin
        if(!rstn) begin
            for(k = 0; k < num_decoders; k = k + 1) begin
                ops_order[k] <= k; // Intialize to 0,1,2,3, etc. 
            end
            start_ptr <= num_decoders; // Point to next starting field
        end
        else begin
            for(k = 0; k < num_decoders; k = k + 1) begin
                if(field_complete[k]) begin
                    ops_order[k] <= start_ptr;
                    start_ptr <= start_ptr + 1;
                end
             end
        end
    end
    
endmodule
