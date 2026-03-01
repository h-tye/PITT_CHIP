`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/28/2026 09:04:02 PM
// Design Name: 
// Module Name: DeltaCalc
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


module DeltaCalc #(
    parameter input_bits = 64,
    parameter max_delta = 16
    )(
    input logic [input_bits-1:0] order,
    input logic [input_bits-1:0] prev_order,
    output logic present,
    output logic [max_delta-1:0] encoded_value,
    output logic [$clog2(max_delta)-1:0] encoded_size
    );
    
    
    logic [max_delta-1:0] delta;
    logic [$clog2(max_delta) - 1:0] size;
    
    integer k;
    always_comb begin
        delta = order - prev_order;
        for(k = 0; k < max_delta; k = k + 1) begin
            if(delta[k] == 1) begin
                size = k;  // If 1 detected, size is at least of size k
            end
        end
        
        encoded_value = delta;
        encoded_size = size;
    end
endmodule
