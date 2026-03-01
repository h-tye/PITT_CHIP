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
    parameter num_operators = 7
    )(
    input logic clk,
    input logic rstn,
    input logic [order_width-1:0] gen_orders [orders_generated],
    input logic [order_width-1:0] prev_orders [orders_generated],
    input logic [$clog2(num_operators)-1:0] operators [orders_generated][1],
    output logic [1:0] PMAPs [orders_generated], // Presence only for price and qty
    output logic [price_bits+qty_bits-1:0] encoded_values [orders_generated]
    );
    
    
    logic [1:0] PMAPs_temp [num_operators][orders_generated];
    logic [price_bits+qty_bits-1:0] encoded_values_temp [num_operators][orders_generated];
    
    // Modules for price
    genvar i;
    generate
        for(i = 0; i < orders_generated; i = i + 1) begin
            CopyCalc C_Price(
                .order(gen_orders[i][price_bits-1 -: price_bits]),
                .prev_order(prev_orders[i][price_bits-1 -: price_bits]),
                .present(PMAPs_temp[i][0][0]),
                .encoded_value(encoded_values_temp[i][0][price_bits-1 -: price_bits])
                );
                
            DefCalc Def_Price(
                .order(gen_orders[i][price_bits-1 -: price_bits]),
                .prev_order(prev_orders[i][price_bits-1 -: price_bits]),
                .present(PMAPs_temp[i][1][0]),
                .encoded_value(encoded_values_temp[i][1][price_bits-1 -: price_bits])
                );
                
            DeltaCalc Delta_Price(
                .order(gen_orders[i][price_bits-1 -: price_bits]),
                .prev_order(prev_orders[i][price_bits-1 -: price_bits]),
                .present(PMAPs_temp[i][2][0]),
                .encoded_value(encoded_values_temp[i][2][price_bits-1 -: price_bits])
                );
                
            IncCalc Inc_Price(
                .order(gen_orders[i][price_bits-1 -: price_bits]),
                .prev_order(prev_orders[i][price_bits-1 -: price_bits]),
                .present(PMAPs_temp[i][3][0]),
                .encoded_value(encoded_values_temp[i][3][price_bits-1 -: price_bits])
                );
                
            NoopCalc NO_Price(
                .order(gen_orders[i][price_bits-1 -: price_bits]),
                .prev_order(prev_orders[i][price_bits-1 -: price_bits]),
                .present(PMAPs_temp[i][4][0]),
                .encoded_value(encoded_values_temp[i][4][price_bits-1 -: price_bits])
                );
        end
    endgenerate
    
    // Mux output
    integer k,j;
    always_comb begin
        for(k = 0; k < orders_generated; k = k + 1) begin
           for(j = 0; j < num_operators; j = j + 1) begin
               if(operators[k][j][0] == j) begin
                   PMAPs[k][0] = PMAPs_temp[j][k][0];
                   encoded_values[k][price_bits - 1 -: price_bits] = encoded_values_temp[k][j][price_bits-1 -: price_bits];
               end
           end
        end
    end
    
    // Qty modules
    generate
        for(i = 0; i < orders_generated; i = i + 1) begin
            CopyCalc C_Price(
                .order(gen_orders[i][qty_bits-1 -: qty_bits]),
                .prev_order(prev_orders[i][qty_bits-1 -: qty_bits]),
                .present(PMAPs_temp[i][0][1]),
                .encoded_value(encoded_values_temp[i][0][qty_bits-1 -: qty_bits])
                );
                
            DefCalc Def_Price(
                .order(gen_orders[i][qty_bits-1 -: qty_bits]),
                .prev_order(prev_orders[i][qty_bits-1 -: qty_bits]),
                .present(PMAPs_temp[i][1][1]),
                .encoded_value(encoded_values_temp[i][1][qty_bits-1 -: qty_bits])
                );
                
            DeltaCalc Delta_Price(
                .order(gen_orders[i][qty_bits-1 -: qty_bits]),
                .prev_order(prev_orders[i][qty_bits-1 -: qty_bits]),
                .present(PMAPs_temp[i][2][1]),
                .encoded_value(encoded_values_temp[i][2][qty_bits-1 -: qty_bits])
                );
                
            IncCalc Inc(
                .order(gen_orders[i][qty_bits-1 -: qty_bits]),
                .prev_order(prev_orders[i][qty_bits-1 -: qty_bits]),
                .present(PMAPs_temp[i][3][1]),
                .encoded_value(encoded_values_temp[i][3][qty_bits-1 -: qty_bits])
                );
                
            NoopCalc NO(
                .order(gen_orders[i][qty_bits-1 -: qty_bits]),
                .prev_order(prev_orders[i][qty_bits-1 -: qty_bits]),
                .present(PMAPs_temp[i][4][1]),
                .encoded_value(encoded_values_temp[i][4][qty_bits-1 -: qty_bits])
                );
        end
    endgenerate
    
    // Mux output
    integer k,j;
    always_comb begin
        for(k = 0; k < orders_generated; k = k + 1) begin
           for(j = 0; j < num_operators; j = j + 1) begin
               if(operators[k][j][1] == j) begin
                   PMAPs[k][1] = PMAPs_temp[j][k][1];
                   encoded_values[k][qty_bits - 1 -: qty_bits] = encoded_values_temp[k][j][qty_bits-1 -: qty_bits];
               end
           end
        end
    end
    
    
endmodule
