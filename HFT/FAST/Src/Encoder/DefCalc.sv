`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/02/2026 08:01:12 PM
// Design Name: 
// Module Name: DefCalc
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


module DefCalc #(
    parameter input_bits = 64,
    parameter default_value = 100000 // Always set
    )(
    input logic [input_bits-1:0] order,
    output logic present
    );
    
    always_comb begin
        if(order == default_value) begin
            present = 0;
        end
        else begin
            present = 1;
        end
    end


endmodule
