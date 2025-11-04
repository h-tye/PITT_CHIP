`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/31/2025 03:56:41 PM
// Design Name: 
// Module Name: FF
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


module FF(
    input  wire N,
    input  wire Clk,
    input  wire En,
    input  wire Rst,
    output reg  Q
);

    always @(posedge Clk or posedge Rst) begin
        if (Rst == 1'b1)
            Q <= 1'b0;
        else if (En == 1'b1)
            Q <= N;
    end

endmodule

