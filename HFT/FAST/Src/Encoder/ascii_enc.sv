`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/22/2026 07:57:00 PM
// Design Name: 
// Module Name: ascii_enc
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


module ascii_enc #(
    parameter input_width = 64,
    parameter output_width = input_width + input_width/8,
    parameter output_bytes = output_width / 8 + 1
    )(
    input nullable,
    input logic [$clog2(input_width)-1:0] encoded_size,
    input logic [input_width-1:0] op_encoded_value,
    output logic [output_width-1:0] dt_encoded_value
    );
    
    logic [output_width-1:0] temp;
    always_comb begin
        if(nullable && op_encoded_value > 0) begin
            temp = op_encoded_value;
        end
        else begin
            temp = 8'h80;
        end
    end
    
    always_comb begin
        int k;
        for (k = 0; k < output_bytes; k = k + 1) begin
            if(k * 8 < encoded_size) begin
                dt_encoded_value[(k+1)*8 -: 8] = {1'b0, op_encoded_value[(k+1)*8-1 -: 7]};
            end
            else begin
                dt_encoded_value[(k+1)*8 -: 8] = {1'b1, op_encoded_value[(k+1)*8-1 -: 7]};
            end
        end
    end
endmodule
