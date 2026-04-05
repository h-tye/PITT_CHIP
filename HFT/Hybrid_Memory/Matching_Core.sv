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
    parameter aggr_cache_capacity = 128,
    parameter timestamp_bits = 32,
    parameter orderID_bits = 16,
    parameter price_bits = 16,
    parameter qty_bits = 16,
    parameter order_width = timestamp_bits + orderID_bits + price_bits + qty_bits,
    parameter num_incoming_orders = 1
    )(
    input logic [qty_bits-1:0] prev_qty,
    input logic prev_BoS,                     // Signal wether previous is sell or buy overflow
    input logic [price_bits-1:0] buy_price,
    input logic [price_bits-1:0] sell_price,
    input logic [qty_bits-1:0] buy_qty,
    input logic [qty_bits-1:0] sell_qty,
    output logic [qty_bits-1:0] next_qty,
    output logic next_BoS,
    output logic filled,                 // Indicate filled or not
    output logic partially_filled
    );

    // Handle overflow first
    logic [qty_bits-1:0] active_sell_qty, active_buy_qty;
    always_comb begin
        active_sell_qty = sell_qty;
        active_buy_qty = buy_qty;
        if(!prev_BoS) begin // Buy side overflow

            // If overflow >= sell qty, mark as filled and move overflow to next core
            if(prev_qty >= sell_qty) begin
                filled = 1;
                partially_filled = 1;
                next_BoS = 0;
                next_qty = prev_qty - sell_qty;
            end
            else begin
                active_sell_qty = sell_qty - prev_qty;
                // Once overflow dealt with, can handle current orders
                if(buy_price >= sell_price) begin
                    if(active_buy_qty > active_sell_qty) begin  // Buy overflow
                        next_qty = active_buy_qty - active_sell_qty;
                        next_BoS = 0;
                        filled = 1;
                        partially_filled = 1;
                    end
                    else if(active_buy_qty < active_sell_qty)  begin // Sell overflow
                        next_qty = active_sell_qty - active_buy_qty;
                        next_BoS = 1;
                        filled = 1;
                        partially_filled = 1;
                    end
                    else begin  // Perfect match
                        next_qty = 0;
                        next_BoS = 0; // default, will be ignored since filled = 0
                        filled = 1;
                        partially_filled = 0;
                    end
                end
                else begin
                    next_qty = 0;
                    next_BoS = 0;
                    filled = 0;
                    partially_filled = 0;
                end
            end
        end
        else begin // Sell side overflow
            if(prev_qty >= buy_qty) begin
                filled = 1;
                next_BoS = 1;
                next_qty = prev_qty - buy_qty;
                partially_filled = 1;
            end
            else begin
                active_buy_qty = buy_qty - prev_qty;
                // Once overflow dealt with, can handle current orders
                if(buy_price >= sell_price) begin
                    if(active_buy_qty > active_sell_qty) begin  // Buy overflow
                        next_qty = active_buy_qty - active_sell_qty;
                        next_BoS = 0;
                        filled = 1;
                        partially_filled = 1;
                    end
                    else if(active_buy_qty < active_sell_qty)  begin // Sell overflow
                        next_qty = active_sell_qty - active_buy_qty;
                        next_BoS = 1;
                        filled = 1;
                        partially_filled = 1;
                    end
                    else begin  // Perfect match
                        next_qty = 0;
                        next_BoS = 0; // default, will be ignored since filled = 0
                        filled = 1;
                        partially_filled = 0;
                    end
                end
                else begin
                    next_qty = 0;
                    next_BoS = 0;
                    filled = 0;
                    partially_filled = 0;
                end
            end
        end
    end
endmodule
