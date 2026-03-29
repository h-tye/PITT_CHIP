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
    parameter ord_type_bits = 8,
    parameter side_bits = 8,
    parameter header2_bits = body_length_bits + ord_type_bits + side_bits + checksum_bits,
    parameter header1_size_bytes = 2 + 1 + 4,
    parameter header2_size_bytes = header2_bits / 7 + 1,
    parameter qty_bytes =  (max_delta / 7 + 1),
    parameter price_bytes = (max_delta / 7 + 1)
    )(
    input logic [dynamic_fields-1:0] order_PMAPs [orders_generated],
    input logic [body_length_bits-1:0] prev_body_length,
    input logic [checksum_bits-1:0] prev_checksum,
    input logic [1:0] type_bits [orders_generated],  // Buy vs Sell, Market vs Limit
    output logic [header2_bits-1:0] header2 [orders_generated]
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
                
                // Operator encode
                header2[i][header2_bits-1 -: body_length_bits] = body_length[i] - prev_body_length;
                if(type_bits[1]) begin
                    header2[i][header2_bits-body_length_bits-1 -: 8] = 50; // Default = 0(buy), only encode if != 0, ASCII encode
                end
                if(!type_bits[0]) begin
                    header2[i][header2_bits-body_length_bits-9 -: 8] = 49; // Default = 1(limit), only encode if != 1, AscII encode
                end
                header2[i][checksum_bits-1:0] = checksum[i] - prev_checksum;
             end
         end
     endgenerate
                
        
endmodule
