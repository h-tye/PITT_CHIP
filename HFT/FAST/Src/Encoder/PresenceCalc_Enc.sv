`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/26/2026 11:53:23 PM
// Design Name: 
// Module Name: PresenceCalc_Enc
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


module PresenceCalc_Enc #(
    parameter orders_generated = 4,
    parameter price_bits = 32,
    parameter qty_bits = 16,
    parameter header_bits = 16,
    parameter order_width = price_bits + qty_bits + header_bits,
    parameter max_message_size = 10, // Number of fields per message
    parameter max_delta = 16  // Max difference between previous and current value = 2^16 = 64k
    )(
    input logic clk,
    input logic rstn,
    input logic [order_width-1:0] gen_orders [orders_generated],
    input logic [order_width-1:0] prev_orders [orders_generated],
    output logic [1:0] PMAPs [orders_generated], // Presence only for price and qty
    output logic [max_delta-1:0] encoded_values [orders_generated],
    output logic [$clog2(max_delta)-1:0] encoded_size [0:1]
    );
    
    /**
      * ASSUME DELTA OPERATOR USED FOR PRICE AND QUANTITY
    */
    
    // Modules for price
    genvar i;
    generate
        for(i = 0; i < orders_generated; i = i + 1) begin
                
            DeltaCalc #(.input_bits(price_bits)) Delta_Price(
                .order(gen_orders[i][price_bits-1 -: price_bits]),
                .prev_order(prev_orders[i][price_bits-1 -: price_bits]),
                .present(PMAPs[i][0]),
                .encoded_value(encoded_values[i][price_bits-1 -: price_bits]),
                .encoded_size(encoded_size[0])
                );
        end
    endgenerate
    
    // Qty modules
    generate
        for(i = 0; i < orders_generated; i = i + 1) begin
                
            DeltaCalc #(.input_bits(qty_bits)) Delta_Price(
                .order(gen_orders[i][qty_bits-1 -: qty_bits]),
                .prev_order(prev_orders[i][qty_bits-1 -: qty_bits]),
                .present(PMAPs[i][1]),
                .encoded_value(encoded_values[i][qty_bits-1 -: qty_bits]),
                .encoded_size(encoded_size[1])
                );
        end
    endgenerate
    
     
endmodule
