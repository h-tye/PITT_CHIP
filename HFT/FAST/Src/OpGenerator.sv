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
    output logic [field_op_size-1:0] t_field_ops_stream [max_message_size-1:0],
    output logic [field_op_size-1:0] t_field_ops_prev [max_message_size-1:0]
    );
    
    integer k, prev_count, stream_count;
    reg [20:0] message_count; 
    
    always_comb begin
        if(~rstn) begin
            for(k = 0; k < max_message_size; k = k + 1) begin
                t_field_ops_stream[k] = 0;
                t_field_ops_prev[k] = 0;
            end
        end
        else if(new_message) begin
            for(k = 0; k < max_message_size; k = k + 1) begin
                
                t_field_ops_stream[prev_count][field_op_size-2:template_field_size] = message_count;
                t_field_ops_prev[stream_count][field_op_size-2:template_field_size] = message_count;
                
                // Set mem write to replace based on pmap and operator, see documentation
                
                // No Operator
                if (template[k][field_op_size-1 -: $clog2(num_templates)] == 0) begin
                    t_field_ops_stream[stream_count][template_field_size-1:0] = template[k];
                    t_field_ops_stream[stream_count][field_op_size-1] = 0;
                    stream_count = stream_count + 1;
                end
                
                // Constant Operator
                if (template[k][field_op_size-1 -: $clog2(num_templates)] == 1) begin
                    t_field_ops_stream[stream_count][template_field_size-1:0] = template[k];
                    t_field_ops_stream[stream_count][field_op_size-1] = 0; 
                    stream_count = stream_count + 1;
                end
                
                // Copy operator
                if (template[k][field_op_size-1 -: $clog2(num_templates)] == 2 && pmap[k] == 1) begin
                    t_field_ops_stream[stream_count][template_field_size-1:0] = template[k];
                    t_field_ops_stream[stream_count][field_op_size-1] = 1;  
                    stream_count = stream_count + 1;
                end
                else if(template[k][field_op_size-1 -: $clog2(num_templates)] == 2) begin
                    t_field_ops_prev[k][template_field_size-1:0] = template[k];
                    t_field_ops_prev[k][field_op_size-1] = 0; 
                end
                    
                // Default operator
                if (template[k][field_op_size-1 -: $clog2(num_templates)] == 3) begin
                    t_field_ops_stream[stream_count][template_field_size-1:0] = template[k];
                    t_field_ops_stream[stream_count][field_op_size-1] = 0;
                    stream_count = stream_count + 1;
                end
                
                // Delta operator, always write back, always present
                if (template[k][field_op_size-1 -: $clog2(num_templates)] == 4) begin
                    t_field_ops_stream[stream_count][template_field_size-1:0] = template[k];
                    t_field_ops_stream[stream_count][field_op_size-1] = 1;
                    stream_count = stream_count + 1;
                end
                
                // Increment operator
                if (template[k][field_op_size-1 -: $clog2(num_templates)] == 5 && pmap[k] == 1) begin
                    t_field_ops_stream[stream_count][template_field_size-1:0] = template[k];
                    t_field_ops_stream[stream_count][field_op_size-1] = 1;
                    stream_count = stream_count + 1;
                end
                else if(template[k][field_op_size-1 -: $clog2(num_templates)] == 5) begin
                    t_field_ops_prev[k][template_field_size-1:0] = template[k];
                    t_field_ops_prev[k][field_op_size-1] = 0; 
                    prev_count = prev_count + 1;
                end
                
                // Tail operator
                if (template[k][field_op_size-1 -: $clog2(num_templates)] == 6 && pmap[k] == 1) begin
                    t_field_ops_stream[stream_count][template_field_size-1:0] = template[k];
                    t_field_ops_stream[stream_count][field_op_size-1] = 1;
                    stream_count = stream_count + 1;
                end
                else if(template[k][field_op_size-1 -: $clog2(num_templates)] == 6) begin
                    t_field_ops_prev[prev_count][template_field_size-1:0] = template[k];
                    t_field_ops_prev[prev_count][field_op_size-1] = 0; 
                    prev_count = prev_count + 1;
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
