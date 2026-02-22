`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/12/2026 10:20:04 AM
// Design Name: 
// Module Name: OpGenerator
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


module OpGenerator #(
    parameter beat_width = 64,
    parameter num_templates = 4,
    parameter template_field_size = 10, // Assume 10 bits of template info per field(datatype, operator)
    parameter max_message_size = 10,  // Max number of fields per template
    parameter field_op_size = 32   // Assume 32 bits for ops per field(10 bits template, 21 bits message ID, 1 bit memory write)
    )(
    input logic new_message,
    input logic rstn,
    input logic clk,
    input logic [template_field_size-1:0] template [max_message_size-1:0],
    input logic [beat_width-1:0] pmap,
    output logic [field_op_size-1:0] field_ops [max_message_size-1:0]
    );
    
    integer k;
    reg [20:0] message_count; 
    always_comb begin
        if(~rstn) begin
            for(k = 0; k < max_message_size; k = k + 1) begin
                field_ops[k] = 0;
            end
        end
        else if(new_message) begin
            for(k = 0; k < max_message_size; k = k + 1) begin
                field_ops[k][template_field_size-1:0] = template[k];
                field_ops[k][field_op_size-2:template_field_size] = message_count;
                
                // Set mem write to replace based on pmap and operator, see documentation
                if (template[k][field_op_size-1 -: $clog2(num_templates)] == 0) begin
                    field_ops[k][field_op_size-1] = 0;  // No Operator
                end
                if (template[k][field_op_size-1 -: $clog2(num_templates)] == 1) begin
                    field_ops[k][field_op_size-1] = 0;  // Constant Operator
                end
                if (template[k][field_op_size-1 -: $clog2(num_templates)] == 2 && pmap[k] == 1) begin
                    field_ops[k][field_op_size-1] = 1;  // Copy operator
                end
                if (template[k][field_op_size-1 -: $clog2(num_templates)] == 3) begin
                    field_ops[k][field_op_size-1] = 0;  // Default operator
                end
                if (template[k][field_op_size-1 -: $clog2(num_templates)] == 4) begin
                    field_ops[k][field_op_size-1] = 1;  // Delta operator, always write back
                end
                if (template[k][field_op_size-1 -: $clog2(num_templates)] == 5 && pmap[k] == 1) begin
                    field_ops[k][field_op_size-1] = 1;  // Increment operator
                end
                if (template[k][field_op_size-1 -: $clog2(num_templates)] == 7 && pmap[k] == 1) begin
                    field_ops[k][field_op_size-1] = 1;  // Default operator
                end
                
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if(!rstn) begin
            message_count <= 0;
        end
        else if(new_message) begin
            message_count <= message_count + 1;
        end
    end
    
endmodule
