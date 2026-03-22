`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/21/2026 07:58:21 PM
// Design Name: 
// Module Name: RandomGen
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


module RandomGen #(
    parameter width = 32,
    parameter iterations = 4
    )(
    input clk,
    input rstn,
    output logic [width-1:0] randnum
    );
    
    // LCG Implementation
    logic [width-1:0] prev_num;
    logic [width-1:0] curr_num;
    logic [width-1:0] seed;
    logic [width/2-1:0] multiplier;
    logic [width-1:0] increment;
    logic [width-1:0] mod;
    
    always_ff @(posedge clk) begin
        if(!rstn) begin
            prev_num <= 0;
            seed <= 1;
            multiplier <= 1664525;
            increment <= 1013904223;
            mod <= 2000000000;
        end
        else begin
            prev_num <= curr_num;
        end
    end
    
    int i;
    always_comb begin
        for (i = 0; i < iterations; i = i + 1) begin
            curr_num = (multiplier * curr_num + increment);
            curr_num[(i+1)*(width/iterations) -: (width/iterations)] = curr_num;
        end
        randnum = curr_num;
    end
            
endmodule
