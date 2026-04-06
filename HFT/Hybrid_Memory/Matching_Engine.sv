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
    logic [order_width:0] candidate_buys [num_incoming_orders*2];     // Use extra bit to mark if new or not
    logic [order_width:0] candidate_sells [num_incoming_orders*2];
    logic [$clog2(num_incoming_orders)-1:0] num_candidate_incoming_buy;
    logic [$clog2(num_incoming_orders)-1:0] num_candidate_incoming_sell;
    logic [num_incoming_orders-1:0] new_candidate_buy;
    logic [num_incoming_orders-1:0] new_candidate_sell;
    int i,n;
    always_comb begin
        num_candidate_incoming_buy = 0;
        num_candidate_incoming_sell = 0;
        new_candidate_buy = 0;
        new_candidate_sell = 0;
        for(i = 0; i < num_incoming_orders; i = i + 1) begin
            // If new order has better price insert at top of candidate buys
            if(new_buys[i][price_bits+qty_bits-1 -: price_bits] > best_buy_price) begin
                candidate_buys[num_candidate_incoming_buy] = {1'b1, new_buys[i]};
                new_candidate_buy[i] = 1;
                num_candidate_incoming_buy = num_candidate_incoming_buy + 1;
            end
            if(new_sells[i][price_bits+qty_bits-1 -: price_bits] < best_sell_price) begin
                candidate_sells[num_candidate_incoming_sell] = {1'b1,new_sells[i]};
                new_candidate_sell[i] = 1;
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
                candidate_buys[num_incoming_orders + num_candidate_incoming_buy] = {1'b1,new_buys[i]};
                new_candidate_buy[i] = 1;
                num_candidate_incoming_buy = num_candidate_incoming_buy + 1;
            end
            if(((new_buys[i][price_bits+qty_bits-1 -: price_bits] == best_buy_price) && (top_buy_tail <= L1_capacity))) begin
                candidate_sells[num_incoming_orders + num_candidate_incoming_sell] = {1'b1, new_sells[i]};
                new_candidate_sell[i] = 1;
                num_candidate_incoming_sell = num_candidate_incoming_sell + 1;
            end
        end
    end
    
    // Generate grid of matching cores, populate with candidate buys/sells
    logic buy_filled [num_incoming_orders*2];
    logic sell_filled [num_incoming_orders*2];
    logic buy_pfilled [num_incoming_orders*2];
    logic sell_pfilled [num_incoming_orders*2];
    logic [qty_bits-1:0] residual_buy_qty [num_incoming_orders*2][num_incoming_orders*2+1];
    logic [qty_bits-1:0] residual_sell_qty [num_incoming_orders*2+1][num_incoming_orders*2+1];
    logic core_en;
    logic [$clog2(num_incoming_orders*2)-1:0] stage_num;
    genvar r, c;
    generate
        // Grid Iron
        for(r = 0; r < num_incoming_orders*2;r++) begin
            for (c = 0; c < num_incoming_orders*2; c++) begin : col_loop
            
                always_comb begin
                    if(r == stage_num || c == stage_num) begin
                        core_en = 1;
                    end
                    else begin
                        core_en = 0;
                    end
                end
                Matching_Core core_inst (
                    .buy_price  (candidate_buys[r][price_bits+qty_bits-1 -: price_bits]),
                    .buy_qty    (candidate_buys[r][qty_bits-1:0]),
                    .sell_price (candidate_sells[c][price_bits+qty_bits-1 -: price_bits]),
                    .sell_qty   (candidate_sells[c][qty_bits-1:0]),
                    .en(core_en),
                    .next_buy_qty (residual_buy_qty[r][c]),
                    .next_sell_qty (residual_sell_qty[r][c]),
                    .buy_filled(buy_filled[r]),
                    .sell_filled(sell_filled[c]),
                    .buy_pfilled(buy_pfilled[r]),
                    .sell_pfilled(sell_pfilled[c])
                );
            end
        end
    endgenerate
    
    // Pipeline values
    logic done_eval;
    logic [$clog2(num_incoming_orders)-1:0] num_orders_filled_buy;
    logic [$clog2(num_incoming_orders)-1:0] num_orders_filled_sell;
    logic [$clog2(num_incoming_orders)-1:0] new_orders_filled_buy;
    logic [$clog2(num_incoming_orders)-1:0] new_orders_filled_sell;
    always_ff @(posedge clk or negedge rstn) begin
        int r,c;
        if(!rstn) begin
            stage_num <= 0;
        end
        else begin
            stage_num <= stage_num + 1;
            for (r = 0; r < num_incoming_orders*2; r++) begin
                for(c = 0; c < num_incoming_orders*2;c++) begin
                    // Horizontal propagation (right)
                    if(r == stage_num) begin
                        candidate_buys[r][c+1][qty_bits-1:0] <= residual_buy_qty[r][c];
                    end
                    // Vertical progagation (below)
                    if(c == stage_num) begin
                        candidate_sells[r+1][c][qty_bits-1:0] <= residual_sell_qty[r][c];
                    end
                end
            end
            if(residual_sell_qty[stage_num][num_incoming_orders*2-1] == 0) begin
                num_orders_filled_sell = num_orders_filled_sell + 1;
                new_orders_filled_sell = new_orders_filled_sell + candidate_sells[stage_num][order_width];  // Marked new
            end
            if(residual_buy_qty[stage_num][num_incoming_orders*2-1] == 0) begin
                num_orders_filled_buy = num_orders_filled_buy + 1;
                new_orders_filled_buy = new_orders_filled_buy + candidate_buys[stage_num][order_width];
            end
            if(residual_sell_qty[stage_num][num_incoming_orders*2-1] == candidate_sells[stage_num][qty_bits-1:0] && 
                residual_buy_qty[stage_num][num_incoming_orders*2-1] == candidate_buys[stage_num][qty_bits-1:0]) begin
                done_eval <= 1;
            end
        end
    end
    

    
    
    
    
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
    int j;
    always_comb begin
        if(done_eval) begin
        
            // L1 memory
            for(i = 0; i < num_incoming_orders*2; i = i + 1) begin
                // Buy
                if(residual_buy_qty[i][num_incoming_orders*2-1] == 0) begin     // If not filled, has to go back to L1
                    outgoing_orders_buy[i][order_width-1 -: 3] = 3'b001;  // To L1
                    outgoing_orders_buy[i][order_width-5] = 1'b1;         // Insert into start of queue
                    outgoing_orders_buy[i][order_width-5:0] = candidate_buys[i];
                end
                // Sell
                if(candidate_sells[i][price_bits+qty_bits-1 -: price_bits] > best_sell_price && residual_sell_qty[i][num_incoming_orders*2-1] == 0) begin
                    outgoing_orders_sell[i][order_width-1 -: 3] = 3'b001;  // To L1
                    outgoing_orders_sell[i][order_width-5] = 1'b1;         // Insert into start of queue
                    outgoing_orders_sell[i][order_width-5:0] = new_sells[i];
                end
            end
            
            // New order handling
            for(j = 0; j < num_incoming_orders; j++) begin
                if(new_buys[i][price_bits+qty_bits-1 -: price_bits] == best_buy_price && 
                top_buy_tail < L2_capacity + num_orders_buy_added && top_buy_tail > L1_capacity + num_orders_buy_added
                && !new_candidate_buy[i]) begin
                    outgoing_orders_buy[i][order_width-1 -: 3] = 3'b010;  // To L2
                    outgoing_orders_buy[i][order_width-5] = 1'b0;         // Insert into end of FIFO
                    outgoing_orders_buy[i][order_width-5:0] = candidate_buys[i];
                end
                else begin
                    outgoing_orders_buy[i][order_width-1 -: 3] = 3'b100;  // To CPU
                    outgoing_orders_buy[i][order_width-5] = 1'b0;         // don't care
                    outgoing_orders_buy[i][order_width-5:0] = new_buys[i];
                end
                
                // Sell
                if(new_sells[i][price_bits+qty_bits-1 -: price_bits] == best_sell_price && 
                top_sell_tail < L2_capacity + num_orders_sell_added && top_sell_tail > L1_capacity + num_orders_sell_added
                && !new_candidate_sell) begin
                    outgoing_orders_sell[i][order_width-1 -: 3] = 3'b001;  // To L2
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
