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
    output logic [order_width-1:0] to_CPU_buy,
    output logic [order_width-1:0] to_CPU_sell,
    output logic [order_width-1:0] to_L1_buy,
    output logic [order_width-1:0] to_L1_sell,
    output logic [order_width-1:0] to_L2_buy,
    output logic [order_width-1:0] to_L2_sell,
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
    logic [$clog2(num_incoming_orders)-1:0] num_candidate_incoming_buy;
    logic [$clog2(num_incoming_orders)-1:0] num_candidate_incoming_sell;
    int i;
    always_comb begin
        num_candidate_incoming_buy = 0;
        num_candidate_incoming_sell = 0;
        for(i = 0; i < num_incoming_orders; i = i + 1) begin
            // If new order has better price insert at top of candidate buys
            if(new_buys[i][price_bits+qty_bits-1 -: price_bits] > best_buy_price) begin
                candidate_buys[num_candidate_incoming_buy] = new_buys[i];
                num_candidate_incoming_buy = num_candidate_incoming_buy + 1;
            end
            if(new_sells[i][price_bits+qty_bits-1 -: price_bits] < best_sell_price) begin
                candidate_sells[num_candidate_incoming_sell] = new_sells[i];
                num_candidate_incoming_sell = num_candidate_incoming_sell + 1;
            end
        end
        // Insert top of OB after
        for(i = 0; i < num_incoming_orders; i = i + 1) begin
            candidate_buys[i + num_candidate_incoming_buy] = top_buys[i];
            candidate_sells[i + num_candidate_incoming_sell] = top_sells[i];
        end
        
        // If same price as current top & top is about to be depelted, could potentially match
        for(i = 0; i < num_incoming_orders; i = i + 1) begin
            if(((new_buys[i][price_bits+qty_bits-1 -: price_bits] == best_buy_price) && (top_buy_tail <= L1_capacity))) begin
                candidate_buys[num_incoming_orders + num_candidate_incoming_buy] = new_buys[i];
                num_candidate_incoming_buy = num_candidate_incoming_buy + 1;
            end
            if(((new_buys[i][price_bits+qty_bits-1 -: price_bits] == best_buy_price) && (top_buy_tail <= L1_capacity))) begin
                candidate_sells[num_incoming_orders + num_candidate_incoming_sell] = new_sells[i];
                num_candidate_incoming_sell = num_candidate_incoming_sell + 1;
            end
        end
    end
    

    // Generate grid of matching cores, populate with candidate buys/sells
    logic [qty_bits-1:0] h_qty [num_incoming_orders*2][num_incoming_orders*2+1]; // horizontal carry
    logic h_BoS [num_incoming_orders*2][num_incoming_orders*2+1];
    logic [qty_bits-1:0] v_qty [num_incoming_orders*2+1][num_incoming_orders*2]; // vertical carry
    logic v_BoS [num_incoming_orders*2+1][num_incoming_orders*2];
    logic filled [num_incoming_orders*2][num_incoming_orders*2];
    logic p_filled [num_incoming_orders*2][num_incoming_orders*2];
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
    // If not filled -> will be sent to L1 or L2
    //     Keep tally of filled orders, depedending on the amount filled will either go to L1 or L2
    //     If num_incoming_orders - orders_filled > L1_capacity, some will be demoted to L2
    //     Else they go to L1
    // If filled -> kill here and don't send
    logic [num_incoming_orders*2-1:0] orders_filled;
    logic [$clog2(num_incoming_orders)-1:0] num_orders_filled_buy;
    logic [$clog2(num_incoming_orders)-1:0] num_orders_filled_sell;
    
    // For new orders that were not deemed candidates:
    // Either will go to L2 or CPU
    // Go to L2 if price level tail is in L2
    // Else go to CPU
    
    // num_orders and AoR calculation:
    // if num_orders_filled > num_incoming_matchable_orders -> we are filling from L1 cache -> remove AoR = 1
    //    in this case, num_orders = num_orders_filled - num_incoming__matchable_orders
    // if num_orders_filled <= num_incoming_matchable_orders : We are either adding or staying the same -> AoR = 0
    //    in this case, num_orders = num_incoming_matchable_orders - num_orders_filled
    
    
    int count_L1_buy, count_L1_sell, count_L2_buy, count_L2_sell, count_CPU_buy, count_CPU_sell;
    always_comb begin
        if(num_orders_filled_buy > num_candidate_incoming_buy) begin
            AoR_buy = 1;
            num_orders_buy = num_orders_filled_buy - num_candidate_incoming_buy;
        end
        else begin
            AoR_buy = 0;
            num_orders_buy = num_candidate_incoming_buy - num_orders_filled_buy;
        end
        if(num_orders_filled_sell > num_candidate_incoming_sell) begin
            AoR_sell = 1;
            num_orders_sell = num_orders_filled_sell - num_candidate_incoming_sell;
        end
        else begin
            AoR_sell = 0;
            num_orders_sell = num_candidate_incoming_sell - num_orders_filled_sell;
        end
    end
    always_comb begin
        // Process orders for outgoing
        count_L1_buy = 0;
        count_L1_sell = 0;
        count_L2_buy = 0;
        count_L2_sell = 0;
        count_CPU_buy = 0;
        count_CPU_sell = 0;
        for(i = 0; i < num_incoming_orders; i = i + 1) begin
            if(i <= num_candidate_incoming_buy && filled[i] == 0) begin  // Insert into L1 cache
                to_L1_buy[count_L1_buy] = new_buys[i];
                count_L1_buy = count_L1_buy + 1;
            end
            else if(new_buys[i][price_bits+qty_bits-1 -: price_bits] == best_buy_price && top_buy_tail < aggr_cache_capacity) begin
                to_L2_buy[count_L2_buy] = new_buys[i];
                count_L2_buy = count_L2_buy + 1;
            end
            else begin
                to_CPU_buy[count_CPU_buy] = new_buys[i];
                count_CPU_buy = count_CPU_buy + 1;
            end
            if(i <= num_candidate_incoming_sell && !orders_filled[i]) begin  // Insert into L1 cache
                to_L1_sell[count_L1_sell] = new_sells[i];
                count_L1_sell = count_L1_sell + 1;
            end
            else if(new_sells[i][price_bits+qty_bits-1 -: price_bits] == best_sell_price && top_sell_tail < aggr_cache_capacity) begin
                to_L2_sell[count_L2_buy] = new_sells[i];
                count_L2_sell = count_L2_sell + 1;
            end
            else begin
                to_CPU_sell[count_CPU_sell] = new_sells[i];
                count_CPU_sell = count_CPU_sell + 1;
            end
        end     
    end            
endmodule
