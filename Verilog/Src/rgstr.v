`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/31/2025 05:44:19 PM
// Design Name: 
// Module Name: rgstr
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


module rgstr #(
    parameter  width = 32
)(  
    input wire [width-1:0] N,
    input wire Clk,
    input wire Rst,
    input wire En,
    output wire [width-1:0] Q
    );
    
    genvar i;
    generate
        for(i = 0; i < width; i = i + 1) begin : FF_STAGE
            FF U (
                   .N(N[i]),
                   .Clk(Clk),
                   .Rst(Rst),
                   .En(En),
                   .Q(Q[i])
                  );
             end 
     endgenerate
endmodule
