`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/05/2026 01:30:37 AM
// Design Name: 
// Module Name: MatchingEngine
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


module MatchingEngine #(
    parameter aggr_cache_capacity = 128,
    parameter L1_capacity = 8,
    parameter timestamp_bits = 32,
    parameter orderID_bits = 16,
    parameter price_bits = 16,
    parameter qty_bits = 16,
    parameter order_width = timestamp_bits + orderID_bits + price_bits + qty_bits,
    parameter num_incoming_orders = 1
    )(
    input logic clk,
    input logic rstn,
    input logic [order_width-1:0] new_buys [num_incoming_orders],     // Coming from FIFO
    input logic [order_width-1:0] new_sells [num_incoming_orders],
    input logic [order_width-3:0] top_buys [num_incoming_orders],
    input logic [$clog2(aggr_cache_capacity)-1:0] top_buy_tail,
    input logic [$clog2(aggr_cache_capacity)-1:0] top_sell_tail,
    input logic [order_width-3:0] top_sells [num_incoming_orders],
    output logic [$clog2(num_incoming_orders)-1:0] num_orders_buy,       // Number to add or remove(not including cancels)
    output logic [$clog2(num_incoming_orders)-1:0] num_orders_sell,
    output logic AoR_buy,  // Signal net positive(add) or negative(remove)
    output logic AoR_sell,
    output logic done  // Signals completion to cache and hash table  
    );
    
    
    // Stage 1 : Determine which new orders have the potential to be matched
    logic [price_bits-1:0] best_buy_price;
    logic [price_bits-1:0] best_sell_price;
    assign best_buy_price = top_buys[0][price_bits+qty_bits-1 -: price_bits];
    assign best_sell_price = top_sells[0][price_bits+qty_bits-1 -: price_bits];
    
    logic [order_width-1:0] candidate_buys [num_incoming_orders*2];
    logic [order_width-1:0] candidate_sells [num_incoming_orders*2];
    int i, count_b, count_s;
    always_comb begin
        count_b = 0;
        count_s = 0;
        for(i = 0; i < num_incoming_orders; i = i + 1) begin
            // If new order has better price insert at top of candidate buys
            if(new_buys[i][price_bits+qty_bits-1 -: price_bits] > best_buy_price) begin
                candidate_buys[i] = new_buys[i];
                count_b = count_b + 1;
            end
            if(new_sells[i][price_bits+qty_bits-1 -: price_bits] < best_sell_price) begin
                candidate_sells[count_s] = new_sells[i];
                count_s = count_s + 1;
            end
        end
        // Insert top of OB after
        for(i = 0; i < num_incoming_orders; i = i + 1) begin
            candidate_buys[i + count_b] = top_buys[i];
            candidate_sells[i + count_s] = top_sells[i];
        end
        for(i = 0; i < num_incoming_orders; i = i + 1) begin
            if(((new_buys[i][price_bits+qty_bits-1 -: price_bits] == best_buy_price) && (top_buy_tail <= L1_capacity))) begin
                candidate_buys[num_incoming_orders + count_b + i] = new_buys[i];
            end
            if(((new_buys[i][price_bits+qty_bits-1 -: price_bits] == best_buy_price) && (top_buy_tail <= L1_capacity))) begin
                candidate_sells[num_incoming_orders + count_s + i] = new_sells[i];
            end
        end
    end
    

    // Inter-core signal
    logic [qty_bits-1:0] h_qty [num_incoming_orders*2][num_incoming_orders*2+1]; // horizontal carry
    logic h_BoS [num_incoming_orders*2][num_incoming_orders*2+1];
    logic [qty_bits-1:0] v_qty [num_incoming_orders*2+1][num_incoming_orders*2]; // vertical carry
    logic v_BoS [num_incoming_orders*2+1][num_incoming_orders*2];
    logic filled [num_incoming_orders*2][num_incoming_orders*2];
    logic p_filled [num_incoming_orders*2][num_incoming_orders*2];
    
    // Seed the edges with zero
    genvar g, k;
    generate
        for(g = 0; g < num_incoming_orders; g++) begin
            assign h_qty[g][0] = 0;  // no incoming buy overflow on left edge
            assign h_BoS[g][0] = 0;
            assign v_qty[0][g] = 0;  // no incoming sell overflow on top edge
            assign v_BoS[0][g] = 0;
        end
        
        // Populate with candidate orders 
        for(g = 0; g < num_incoming_orders*2; g++) begin       // buy index
            for(k = 0; k < num_incoming_orders*2; k++) begin  // sell index
                Matching_Core core_inst (
                    .buy_price  (candidate_buys[g][price_bits+qty_bits-1 -: price_bits]),
                    .buy_qty    (candidate_buys[g][qty_bits-1:0]),
                    .sell_price (candidate_sells[k][price_bits+qty_bits-1 -: price_bits]),
                    .sell_qty   (candidate_sells[k][qty_bits-1:0]),
                    .prev_qty   (h_qty[g][k]),
                    .prev_BoS   (h_BoS[g][k]),
                    .next_qty   (h_qty[g][k+1]),
                    .next_BoS   (h_BoS[g][k+1]),
                    .filled     (filled[g][k]),
                    .partially_filled(p_filled[g][k])
                );
            end
        end
    endgenerate
    
    // Evaluation of chain
    // Go through each new order and check:
    // If not filled & price < best price -> send to CPU
    // If not filled & price = best price -> sent to back of FIFO(could be CPU or cache)
    // If not filled || partially filled & price > best_price -> insert into top of order book(L1 cache)
    // If filled 
    
    
    
    
    
                
            
endmodule
