`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/27/2026 10:49:17 AM
// Design Name: 
// Module Name: HeaderGen2
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


module HeaderGen2 #(
    parameter dynamic_fields = 4,
    parameter orders_generated = 4,
    parameter max_delta = 16,
    parameter body_length_bits = max_delta,
    parameter checksum_bits = 8,
    parameter FIX_msg_type_bits = 16,  // 2 bytes for FIX
    parameter header2_bits = body_length_bits + checksum_bits + FIX_msg_type_bits,
    parameter header1_size_bytes = 2 + 1 + 4,
    parameter header2_size_bytes = header2_bits / 7 + 1,
    parameter qty_bytes =  (max_delta / 7 + 1),
    parameter price_bytes = (max_delta / 7 + 1)
    )(
    input clk,
    input rstn,
    input [dynamic_fields-1:0] order_PMAPs [orders_generated],
    input [body_length_bits-1:0] prev_body_length,
    input [checksum_bits-1:0] prev_checksum,
    output [header2_bits-1:0] header1 [orders_generated]
    );
    
    logic [body_length_bits-1:0] body_length [orders_generated];
    logic [checksum_bits-1:0] checksum [orders_generated];
    
    genvar i;
    generate
        for(i = 0; i < orders_generated; i = i + 1) begin
            always_comb begin
                body_length[i] = header1_size_bytes + header2_size_bytes;
                if(order_PMAPs[i][0]) begin
                    body_length[i] = body_length[i] + 1;
                end
                if(order_PMAPs[i][1]) begin
                    body_length[i] = body_length[i] + 1'b1;
                end
                if(order_PMAPs[i][2]) begin
                    body_length[i] = body_length[i] + price_bytes;
                end
                if(order_PMAPs[i][3]) begin
                    body_length[i] = body_length[i] + qty_bytes;
                end
                checksum[i] = body_length[i][7:0]; // Checksum = totaly bytes % 256
             end
         end
     endgenerate
                
        
endmodule
