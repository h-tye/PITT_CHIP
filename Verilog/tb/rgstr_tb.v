`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/04/2025 10:11:23 AM
// Design Name: 
// Module Name: rgstr_tb
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


module rgstr_tb(
    );
    
    reg clk, rst, en;
    reg [31:0] d;
    wire [31:0] q;
    
    // INSTANTIATE REGISTER
    rgstr #(32) U (
        .N(d),
        .Clk(clk),
        .Rst(rst),
        .En(en),
        .Q(q));
        
    // CLOCK GENERATION
    initial clk = 0;
    always #5 clk = ~clk; // CLK = not(CLK) after 5 ns
    
    initial begin
        
        // CASE 1: RST
        rst = 1;
        en = 1;
        d = 32'h00000000;
        #10; // WAIT 10 ns
        
        // CASE 2: ENABLE
        rst = 0;
        en = 0;
        #10;
        
        // CASE 3: LOAD
        d = 32'hFFFFFFFF;
        en = 1;
        #10;
        
        $finish; // WAIT, sim is done
    end
        
endmodule
