`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/12/2026 09:36:25 AM
// Design Name: 
// Module Name: DecoderCtrl
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


module DecoderCtrl #(
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
    input logic new_message,
    input logic [num_decoders-1:0] decoders_done,
    input logic [template_field_size-1:0] template [max_message_size],
    input logic [beat_width+1:0] dins [sup_paths],
    input logic [sup_paths-1:0] field_valid,
    input logic [$clog2(num_templates)-1:0] TID,
    output logic [field_op_size-1:0] field_ops[num_decoders]
    );
    
    logic [beat_width-1:0] pmap;
    logic [$clog2(num_decoders)-1:0] current_batch_completed;
    logic [field_op_size-1:0] field_ops_total [max_message_size-1:0]; // extra 2 bits for issued and completion
    logic [max_message_size-1:0] fields_issued;
    logic [max_message_size-1:0] fields_completed;
    logic [$clog2(max_message_size)-1:0] ops_order [0:num_decoders-1];
    integer k,j;
    
    OpGenerator U(
        .new_message(new_message),
        .rstn(rstn),
        .template(template),
        .pmap(pmap),
        .field_ops(field_ops_total)
        );
     
     // Set pmap
     always_ff @(posedge clk) begin
        if(!rstn) begin
            pmap <= 0;
        end
        else if(new_message) begin
            for(k = 0; k < sup_paths; k = k + 1) begin
                if(dins[k][beat_width+1] && field_valid[k]) begin
                    pmap <= dins[k][beat_width-1:0];
                end
            end
        end
     end
     
    // Issue new ops based on completion
    integer field_count = 0;
    always_ff @(posedge clk) begin
        for(j = 0; j < num_decoders; j = j + 1) begin
            if(decoders_done[k]) begin
                fields_completed[ops_order[k]] <= 1;
            end
            else begin
                fields_completed[ops_order[k]] <= 0;
            end
        end
        
        for(k = 0; k < max_message_size ; k = k + 1) begin 
            if(!fields_completed[k] && field_count < num_decoders) begin // If not completed, reissue
                field_ops[ops_order[k]] <= field_ops_total[k];
                field_count = field_count + 1;
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
                if(decoders_done[k]) begin
                    ops_order[k] <= start_ptr;
                    start_ptr <= start_ptr + 1;
                end
             end
        end
    end
         
endmodule
