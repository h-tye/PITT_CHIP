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
    parameter L1_capacity = 8,
    parameter L2_capacity = 120,
    parameter timestamp_bits = 32,
    parameter orderID_bits = 16,
    parameter price_bits = 16,
    parameter qty_bits = 16,
    parameter order_locations = 3,  // L1, L2, or CPU
    parameter FoB = 1,              // Insert/remove from front or back
    parameter order_width = order_locations + FoB + timestamp_bits + orderID_bits + price_bits + qty_bits,
    parameter num_incoming_orders = 1
    )(
    input logic clk,
    input logic rstn,
    input logic [order_width-5:0] new_buys [num_incoming_orders],     // Coming from stream FIFO
    input logic [order_width-5:0] new_sells [num_incoming_orders],
    input logic [order_width-5:0] top_buys [num_incoming_orders],     // Top of the order book(potentially matchable trades)
    input logic [order_width-5:0] top_sells [num_incoming_orders],    // -5 for FoB + order_locations, don't need to store
    input logic [$clog2(L1_capacity + L2_capacity)-1:0] top_buy_tail,
    input logic [$clog2(L1_capacity + L2_capacity)-1:0] top_sell_tail,
    output logic [$clog2(num_incoming_orders)-1:0] num_orders_buy_added,
    output logic [$clog2(num_incoming_orders)-1:0] num_orders_buy_removed,
    output logic [$clog2(num_incoming_orders)-1:0] num_orders_sell_added,
    output logic [$clog2(num_incoming_orders)-1:0] num_orders_sell_removed,
    output logic [order_width-1:0] outgoing_orders_buy [num_incoming_orders],
    output logic [order_width-1:0] outgoing_orders_sell [num_incoming_orders],
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
    int i,n;
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
    logic buy_filled [num_incoming_orders*2];
    logic sell_filled [num_incoming_orders*2];
    logic buy_pfilled [num_incoming_orders*2];
    logic sell_pfilled [num_incoming_orders*2];
    logic [qty_bits-1:0] residual_buy_qty [num_incoming_orders*2]; // Gives residual for each level
    logic [qty_bits-1:0] residual_sell_qty [num_incoming_orders*2+1];
    logic [order_width-1:0] input_buy_qty;
    logic [order_width-1:0] input_sell_qty;
    genvar r, c;
    generate
        
        // Grid Iron
        for (r = 0; r < num_incoming_orders; r++) begin : row_loop
            for (c = 0; c < num_incoming_orders; c++) begin : col_loop
                Matching_Core core_inst (
                    .buy_price  (candidate_buys[r][price_bits+qty_bits-1 -: price_bits]),
                    .buy_qty    (candidate_buys[r][qty_bits-1:0]),
                    .sell_price (candidate_sells[c][price_bits+qty_bits-1 -: price_bits]),
                    .sell_qty   (residual_sell_qty[c]),
                    .next_buy_qty (residual_buy_qty[r]),
                    .next_sell_qty (residual_sell_qty[c+1]),
                    .buy_filled(buy_filled[r]),
                    .sell_filled(sell_filled[c]),
                    .buy_pfilled(buy_pfilled[r]),
                    .sell_pfilled(sell_pfilled[c])
                );
            end
        end
    endgenerate
    
    // Pipeline values
    logic [num_incoming_orders-1:0] stage_done;
    always_ff @(posedge clk) begin
        int r;
        for (r = 0; r < num_incoming_orders; r++) begin
            // Horizontal propagation (right), buffer between columns
            if (c < num_incoming_orders-1) begin
                candidate_buys[r+1][qty_bits-1:0] <= residual_buy_qty[r];
            end
        end
    end
    
    // Evaluation of chain
    // Go through each new order and check:
    // If not filled -> will be sent to L1 or L2
    //     Keep tally of filled orders, depedending on the amount filled will either go to L1 or L2
    //     If num_incoming_orders - orders_filled > L1_capacity, some will be demoted to L2
    //     Else they go to L1
    // If filled -> kill here and don't send
    logic done_eval;
    logic [$clog2(num_incoming_orders)-1:0] num_orders_filled_buy;
    logic [$clog2(num_incoming_orders)-1:0] num_orders_filled_sell;
    logic [$clog2(num_incoming_orders)-1:0] new_orders_filled_buy;
    
    
    
    // For new orders that were not deemed candidates:
    // Either will go to L2 or CPU
    // Go to L2 if price level tail is in L2
    // Else go to CPU
    
    // num_orders and AoR calculation:
    // if num_orders_filled > num_incoming_matchable_orders -> we are filling from L1 cache -> remove AoR = 1
    //    in this case, num_orders = num_orders_filled - num_incoming__matchable_orders
    // if num_orders_filled <= num_incoming_matchable_orders : We are either adding or staying the same -> AoR = 0
    //    in this case, num_orders = num_incoming_matchable_orders - num_orders_filled
    
    
    // Remove cache orders
    always_comb begin
        if(done_eval) begin
            if(num_orders_filled_buy > num_incoming_orders) begin
                num_orders_buy_removed =  num_orders_filled_buy - num_incoming_orders;
            end
            else begin
                num_orders_buy_added = num_incoming_orders - num_orders_filled_buy;
            end
            if(num_orders_filled_sell > num_candidate_incoming_sell) begin
                num_orders_sell_removed =  num_orders_filled_sell - num_incoming_orders;
            end
            else begin
                num_orders_sell_added = num_incoming_orders - num_orders_filled_sell;
            end
        end
    end
    // Add orders to cache
    always_comb begin
        if(done_eval) begin
            for(i = 0; i < num_incoming_orders; i = i + 1) begin
                // Buy
                if(new_buys[i][price_bits+qty_bits-1 -: price_bits] > best_buy_price && filled[i] == 0) begin
                    outgoing_orders_buy[i][order_width-1 -: 3] = 3'b001;  // To L1
                    outgoing_orders_buy[i][order_width-5] = 1'b1;         // Insert into start of queue
                    outgoing_orders_buy[i][order_width-5:0] = new_buys[i];
                end
                else if(new_buys[i][price_bits+qty_bits-1 -: price_bits] == best_buy_price && top_buy_tail < L1_capacity) begin
                    outgoing_orders_buy[i][order_width-1 -: 3] = 3'b001;  // To L1
                    outgoing_orders_buy[i][order_width-5] = 1'b0;         // Insert into end of FIFO
                    outgoing_orders_buy[i][order_width-5:0] = new_buys[i];
                end
                else if(new_buys[i][price_bits+qty_bits-1 -: price_bits] == best_buy_price && top_buy_tail < L2_capacity) begin
                    outgoing_orders_buy[i][order_width-1 -: 3] = 3'b010;  // To L2
                    outgoing_orders_buy[i][order_width-5] = 1'b0;         // Insert into end of FIFO
                    outgoing_orders_buy[i][order_width-5:0] = new_buys[i];
                end
                else begin
                    outgoing_orders_buy[i][order_width-1 -: 3] = 3'b100;  // To CPU
                    outgoing_orders_buy[i][order_width-5] = 1'b0;         // don't care
                    outgoing_orders_buy[i][order_width-5:0] = new_buys[i];
                end
                
                // Sell
                if(new_sells[i][price_bits+qty_bits-1 -: price_bits] > best_sell_price && filled[i] == 0) begin
                    outgoing_orders_sell[i][order_width-1 -: 3] = 3'b001;  // To L1
                    outgoing_orders_sell[i][order_width-5] = 1'b1;         // Insert into start of queue
                    outgoing_orders_sell[i][order_width-5:0] = new_sells[i];
                end
                else if(new_sells[i][price_bits+qty_bits-1 -: price_bits] == best_sell_price && top_sell_tail < L1_capacity) begin
                    outgoing_orders_sell[i][order_width-1 -: 3] = 3'b001;  // To L1
                    outgoing_orders_sell[i][order_width-5] = 1'b0;         // Insert into end of FIFO
                    outgoing_orders_sell[i][order_width-5:0] = new_buys[i];
                end
                else if(new_sells[i][price_bits+qty_bits-1 -: price_bits] == best_sell_price && top_sell_tail < L2_capacity) begin
                    outgoing_orders_sell[i][order_width-1 -: 3] = 3'b010;  // To L2
                    outgoing_orders_sell[i][order_width-5] = 1'b0;         // Insert into end of FIFO
                    outgoing_orders_sell[i][order_width-5:0] = new_buys[i];
                end
                else begin
                    outgoing_orders_sell[i][order_width-1 -: 3] = 3'b100;  // To CPU
                    outgoing_orders_sell[i][order_width-5] = 1'b0;         // don't care, has to go to back
                    outgoing_orders_sell[i][order_width-5:0] = new_buys[i];
                end
            end
        end
    end                     
endmodule
