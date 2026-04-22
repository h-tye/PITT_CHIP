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
    input buy_filled,
    input sell_filled, 
    input logic [price_bits-1:0] buy_price,
    input logic [price_bits-1:0] sell_price,
    input logic [qty_bits-1:0] buy_qty,
    input logic [qty_bits-1:0] sell_qty,
    output logic [qty_bits-1:0] next_buy_qty,
    output logic [qty_bits-1:0] next_sell_qty
    );


    always_comb begin
        if(en & (sell_price != 0) & (buy_price != 0)) begin
            if(buy_filled || sell_filled) begin
                next_buy_qty = buy_qty;
                next_sell_qty = sell_qty;
            end
            else begin
                if(buy_price >= sell_price) begin
                    if(buy_qty > sell_qty) begin
                        next_buy_qty = buy_qty - sell_qty;
                        next_sell_qty = 0;
                    end
                    else if(sell_qty > buy_qty) begin
                        next_buy_qty = 0;
                        next_sell_qty = sell_qty - buy_qty;
                    end
                    else begin
                        next_buy_qty = 0;
                        next_sell_qty = 0;
                    end
                end
                else begin
                    next_buy_qty = buy_qty;
                    next_sell_qty = sell_qty;
                end
            end
        end
        else begin
            next_buy_qty = buy_qty;
            next_sell_qty = sell_qty;
        end
    end
endmodule
