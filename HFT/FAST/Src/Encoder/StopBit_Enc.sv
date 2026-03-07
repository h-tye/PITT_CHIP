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
    parameter header_bits = 2,
    parameter max_bytes = ((max_delta) / 7 + 1)*2 + header_bits // max bytes allocated for price and qty, 2 bytes for side field and type field
    )(
    input logic [header_bits+max_delta-1:0] encoded_values [orders_generated],
    input logic [$clog2(max_delta)-1:0] encoded_size [0:1],
    output logic [max_bytes*8-1:0] sb_encoded_values [orders_generated] // 7 actual bits per byte
    );
    
    genvar j;
    
    // Side and type
    generate
        for (j = 0; j < orders_generated; j = j + 1) begin : gen_sb_header
            always_comb begin
                sb_encoded_values[j][max_bytes*8-1 -: 7] = encoded_values[header_bits+max_delta-1];
                sb_encoded_values[j][max_bytes*(8-1)-1 -: 7] = encoded_values[header_bits+max_delta-2];
            end
        end
    endgenerate
    
    // Price
    generate
        for (j = 0; j < orders_generated; j = j + 1) begin : gen_sb_price
        
            always_comb begin
                logic overflow;
                int k;
                overflow = 1'b0;
                for (k = 0; k < (max_delta/7 + 1); k = k + 1) begin
                    if (k * 8 < encoded_size[0]) begin   // If field size is greater than bit idx, mark as incomplete
                        sb_encoded_values[j][(k+1)*8 -: 8] = {1'b0, encoded_values[j][(k+1)*8-1 -: 7], overflow};
                    end
                    else begin
                        sb_encoded_values[j][(k+1)*8 -: 8] = {1'b1, encoded_values[j][(k+1)*8-1 -: 7], overflow};
                    end
    
                    overflow = encoded_values[j][(k+1)*8];
                end
            end
        end
    endgenerate
    
    // Qty
    generate
        for (j = 0; j < orders_generated; j = j + 1) begin : gen_sb_qty
        
            always_comb begin
                logic overflow;
                int k;
                overflow = 1'b0;
                for (k = (max_delta/7 + 1); k < (max_delta/7 + 1)*2; k = k + 1) begin
                    if (k * 8 < encoded_size[1]) begin
                        sb_encoded_values[j][(k+1)*8 -: 8] = {1'b0, encoded_values[j][(k+1)*8-1 -: 7], overflow};
                    end
                    else begin
                        sb_encoded_values[j][(k+1)*8 -: 8] = {1'b1, encoded_values[j][(k+1)*8-1 -: 7], overflow};
                    end
    
                    overflow = encoded_values[j][(k+1)*8];
                end
            end
        end
    endgenerate
     
endmodule
