`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 03:24:00 AM
// Design Name: 
// Module Name: Matching_Core
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


module Matching_Core #(
    parameter timestamp_bits = 32,
    parameter orderID_bits = 16,
    parameter price_bits = 16,
    parameter qty_bits = 16,
    parameter order_width = timestamp_bits + orderID_bits + price_bits + qty_bits,
    parameter num_incoming_orders = 1
    )(
    input en, 
    input logic [price_bits-1:0] buy_price,
    input logic [price_bits-1:0] sell_price,
    input logic [qty_bits-1:0] buy_qty,
    input logic [qty_bits-1:0] sell_qty,
    output logic [qty_bits-1:0] next_buy_qty,
    output logic [qty_bits-1:0] next_sell_qty,
    output logic buy_filled,
    output logic sell_filled,
    output logic buy_pfilled,
    output logic sell_pfilled
    );


    always_comb begin
        if(en) begin
            if(buy_price >= sell_price) begin
                if(buy_qty > sell_qty) begin
                    next_buy_qty = buy_qty - sell_qty;
                    next_sell_qty = 0;
                    buy_pfilled = 1;
                    buy_filled = 0;
                    sell_pfilled = 1;
                    sell_filled = 0;
                end
                else if(sell_qty > buy_qty) begin
                    next_buy_qty = 0;
                    next_sell_qty = sell_qty - buy_qty;
                    buy_pfilled = 0;
                    buy_filled = 1;
                    sell_pfilled = 0;
                    sell_filled = 1;
                end
                else begin
                    next_buy_qty = 0;
                    next_sell_qty = 0;
                    buy_pfilled = 0;
                    buy_filled = 1;
                    sell_pfilled = 0;
                    sell_filled = 1;
                end
            end
            else begin
                next_buy_qty = buy_qty;
                next_sell_qty = sell_qty;
                buy_pfilled = 0;
                buy_filled = 0;
                sell_pfilled = 0;
                sell_filled = 0;
            end
        end
        else begin
            next_buy_qty = buy_qty;
            next_sell_qty = sell_qty;
            buy_pfilled = 0;
            buy_filled = 0;
            sell_pfilled = 0;
            sell_filled = 0;
        end
    end
endmodule
