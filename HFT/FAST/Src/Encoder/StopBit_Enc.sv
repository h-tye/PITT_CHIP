`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/01/2026 11:54:21 AM
// Design Name: 
// Module Name: StopBit_Enc
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


module StopBit_Enc #(
    parameter orders_generated = 4,
    parameter max_delta = 16,
    parameter max_bytes = (max_delta) / 7
    )(
    input logic [max_delta-1:0] encoded_values [orders_generated],
    input logic [$clog2(max_delta)-1:0] encoded_size [0:1],
    output logic [max_bytes*8-1:0] sb_encoded_values [orders_generated] // 7 actual bits per byte
    );
    
    genvar j;
    generate
        for (j = 0; j < orders_generated; j = j + 1) begin : gen_sb
        
            always_comb begin
                logic overflow;
                int k;
                overflow = 1'b0;
                for (k = 0; k < max_bytes; k = k + 1) begin
                    if (k * 8 < encoded_size[0]) begin
                        sb_encoded_values[j][(k+1)*8 -: 8] =
                            {1'b0, encoded_values[j][(k+1)*8-1 -: 7], overflow};
                    end
                    else begin
                        sb_encoded_values[j][(k+1)*8 -: 8] =
                            {1'b1, encoded_values[j][(k+1)*8-1 -: 7], overflow};
                    end
    
                    overflow = encoded_values[j][(k+1)*8];
                end
            end
        end
    endgenerate
     
endmodule
