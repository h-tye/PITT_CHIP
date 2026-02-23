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
    parameter num_decoders = 8,  
    parameter field_op_size = 32   // Assume 32 bits for ops per field
    )(
    input logic clk,
    input logic rstn,
    input logic new_message,
    input logic [num_decoders/2-1:0] prev_decoders_done,
    input logic [template_field_size-1:0] template [max_message_size],
    input logic [beat_width+1:0] dins [sup_paths],
    input logic [sup_paths-1:0] field_valids,
    input logic [sup_paths-1:0] field_complete,
    input logic [$clog2(num_templates)-1:0] TID,
    output logic [field_op_size-1:0] field_ops_stream[num_decoders/2],
    output logic [field_op_size-1:0] field_ops_prev[num_decoders/2],
    output logic [$clog2(max_message_size)-1:0] fields_finished
    );
    
    logic [beat_width-1:0] pmap, pmap_reg;
    logic [field_op_size-1:0] t_field_ops_stream [max_message_size-1:0];
    logic [field_op_size-1:0] t_field_ops_prev [max_message_size-1:0];
    logic [$clog2(max_message_size)-1:0] stream_finished;
    logic [$clog2(max_message_size)-1:0] prev_finished;
    integer k,j;
    
    OpGenerator U(
        .new_message(new_message),
        .rstn(rstn),
        .template(template),
        .pmap(pmap),
        .field_ops_stream(t_field_ops_stream),
        .field_ops_prev(t_field_ops_prev)
        );
        
     OpScheduler StreamScheduler(
        .clk(clk),
        .rstn(rstn),
        .new_message(new_message),
        .field_valids(field_complete),
        .total_field_ops(t_field_ops_stream),
        .field_ops(field_ops_stream),
        .fields_finished(stream_finished)
        );
        
     OpScheduler PrevScheduler(
        .clk(clk),
        .rstn(rstn),
        .new_message(new_message),
        .field_valids(prev_decoders_done),
        .total_field_ops(t_field_ops_prev),
        .field_ops(field_ops_prev),
        .fields_finished(prev_finished)
        );
     
     // Set pmap
     always_comb begin
        for(k = 0; k < sup_paths; k = k + 1) begin
            if(dins[k][beat_width+1] && field_complete[k]) begin
                pmap <= dins[k][beat_width-1:0];
            end
        end
     end
            
     always_ff @(posedge clk) begin
        if(!rstn) begin
            pmap <= 0;
        end
        else if(new_message) begin
            pmap_reg <= pmap;
        end
        
        fields_finished <= stream_finished + prev_finished;
     end
         
endmodule
