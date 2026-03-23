`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/22/2026 07:57:00 PM
// Design Name: 
// Module Name: deci_enc
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


module deci_enc #(
    parameter input_width = 64,
    parameter output_width = input_width + input_width/8,
    parameter output_bytes = output_width / 8 + 1
    )(
    input nullable,
    input logic [$clog2(input_width)-1:0] encoded_size,  // Encoded size = size(exponent + mantissa). Relevant size = size - 1
    input logic [input_width-1:0] op_encoded_value,      // Assume exponent can only take up 1 byte, no value will have exponent > 127
    output logic [output_width-1:0] dt_encoded_value
    );
    
    logic [output_width-1:0] temp;
    assign temp = op_encoded_value;
    assign dt_encoded_value[output_width-1 -: 8] =  {1'b1, op_encoded_value[input_width-2 -: 7]}; // Assign exponent
    always_comb begin
        logic overflow;
        int k;
        overflow = 1'b0;
        for (k = 0; k < output_bytes - 1; k = k + 1) begin
            overflow = temp[(k+1)*8];
            if(k * 8 < encoded_size - 1) begin  
                dt_encoded_value[(k+1)*8 -: 8] = {1'b0, op_encoded_value[(k+1)*8-1 -: 7]};
            end
            else begin
                dt_encoded_value[(k+1)*8 -: 8] = {1'b1, op_encoded_value[(k+1)*8-1 -: 7]};
            end
            
            temp = temp << 1;  // Shift over for stop bit
            temp[(k+1)*8+1] = overflow; // Insert overflow bit
        end
    end
endmodule
