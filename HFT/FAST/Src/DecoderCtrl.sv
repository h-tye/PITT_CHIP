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
    parameter template_field_size = 10, // Assume 10 bits of template info per field(datatype, operator, optional, pmap, field num)
    parameter max_message_size = 10,  // Max number of fields per template
    parameter num_decoders = 4,
    parameter field_op_size = 32   // Assume 32 bits for ops per field
    )(
    input logic clk,
    input logic rstn,
    input logic new_message,
    input logic [num_decoders-1:0] decoders_done,
    input logic [template_field_size-1:0] template [max_message_size-1:0],
    input logic [beat_width+1:0] dins [0:3],
    input logic [3:0] field_valid,
    input logic [$clog2(num_templates)-1:0] TID,
    output logic [field_op_size-1:0] field_ops[$clog2(num_decoders)-1:0]
    );
    
    logic [beat_width-1:0] pmap;
    logic [field_op_size-1:0] field_ops_total [max_message_size-1:0];
    logic [$clog2(max_message_size)-1:0] field_count;
    integer k;
    
    OpGenerator U(
        .new_message(new_message),
        .rstn(rstn),
        .template(template),
        .pmap(pmap),
        .field_ops(field_ops_total)
        );
     
     // Set pmap
     always_ff @(posedge clk) begin
        if(new_message) begin
            for(k = 0; k < 4; k = k + 1) begin
                if(dins[k][beat_width+1] && field_valid[k]) begin
                    pmap <= dins[k][beat_width-1:0];
                end
            end
        end
     end
     
    // Get field count to issue batch of new ops
    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn)
            field_count <= 0;
        else begin
            for (int k=0; k<num_decoders; k++) begin
                if(decoders_done[k]) begin
                    field_count <= field_count + 1;
                end
            end
        end
    end

    // Issue new ops
    always_comb begin
        for(k = 0; k < max_message_size; k = k + 1) begin
            if(k > field_count && k < field_count + num_decoders) begin
                field_ops[k] = field_ops_total[k + field_count];
            end
            else begin
                field_ops[k] = 0;
            end 
        end
    end
         
endmodule
