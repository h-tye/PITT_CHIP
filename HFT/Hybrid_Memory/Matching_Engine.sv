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
    input logic L1_sorted,
    input logic [order_width-5:0] new_buys [num_incoming_orders],     // Coming from stream FIFO
    input logic [order_width-5:0] new_sells [num_incoming_orders],
    input logic [order_width-5:0] top_buys [num_incoming_orders],     // Top of the order book(potentially matchable trades)
    input logic [order_width-5:0] top_sells [num_incoming_orders],    // -5 for FoB + order_locations, don't need to store
    input logic [$clog2(L1_capacity + L2_capacity)-1:0] top_buy_ptr,
    input logic [$clog2(L1_capacity + L2_capacity)-1:0] top_sell_ptr,
    output logic [$clog2(num_incoming_orders*2)-1:0] num_orders_buy_added,  // Worst case -> we can add/remove x2 orders back to orderbook
    output logic [$clog2(num_incoming_orders)-1:0] num_orders_buy_removed,  // Worst case -> can only remove top of OB
    output logic [$clog2(num_incoming_orders*2)-1:0] num_orders_sell_added,  
    output logic [$clog2(num_incoming_orders)-1:0] num_orders_sell_removed,
    output logic [order_width-1:0] outgoing_orders_buy [num_incoming_orders*2],
    output logic [order_width-1:0] outgoing_orders_sell [num_incoming_orders*2],
    output logic done  // Signals completion to cache and hash table  
    );
    
    logic [price_bits-1:0] best_buy_price;
    logic [price_bits-1:0] best_sell_price;
    logic [order_width:0] candidate_buys [num_incoming_orders*2];     // Use extra bit to mark if new or not
    logic [order_width:0] candidate_sells [num_incoming_orders*2];
    logic [$clog2(num_incoming_orders)-1:0] num_candidate_incoming_buy;
    logic [$clog2(num_incoming_orders)-1:0] num_candidate_incoming_sell;
    logic [num_incoming_orders-1:0] new_candidate_buy;
    logic [num_incoming_orders-1:0] new_candidate_sell;
    logic [$clog2(num_incoming_orders)-1:0] new_in_curr_price_buy;
    logic [$clog2(num_incoming_orders)-1:0] new_in_curr_price_sell;
    logic [qty_bits-1:0] residual_buy_qty [num_incoming_orders*2][num_incoming_orders*2];
    logic [qty_bits-1:0] residual_sell_qty [num_incoming_orders*2][num_incoming_orders*2];
    logic core_en [num_incoming_orders*2][num_incoming_orders*2];
    logic [$clog2(num_incoming_orders*2)-1:0] stage_num;
    logic [num_incoming_orders*2-1:0] buys_filled;
    logic [num_incoming_orders*2-1:0] sells_filled;
    logic done_eval;
    logic [$clog2(num_incoming_orders)-1:0] num_orders_filled_buy;
    logic [$clog2(num_incoming_orders)-1:0] num_orders_filled_sell;
    logic [$clog2(num_incoming_orders*2)-1:0] out_top_ptr_buy;
    logic [$clog2(num_incoming_orders*2)-1:0] out_top_ptr_sell;
    wire [qty_bits-1:0] buy_qty_wire [num_incoming_orders*2][num_incoming_orders*2];
    wire [qty_bits-1:0] sell_qty_wire [num_incoming_orders*2][num_incoming_orders*2];
    wire [qty_bits-1:0] input_buy_qty [num_incoming_orders*2][num_incoming_orders*2];
    wire [qty_bits-1:0] input_sell_qty[num_incoming_orders*2][num_incoming_orders*2];
    
    
    typedef enum logic [3:0] {
        RST,
        LOAD1,
        LOAD2,
        LOAD3,
        LOAD4,
        MATCH,
        MATCH_DONE,
        SEND1,
        SEND2,
        IDLE
    } state_t;
    state_t state, next_state;
    
    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            state <= RST;
        end
        else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always_comb begin
        if(state == RST) begin
            if(!rstn) begin
                next_state = RST;
            end
            else if(L1_sorted) begin
                next_state = LOAD1;
            end
            else begin
                next_state = IDLE;
            end
            done = 0;
        end
        else if(state == LOAD1) begin
            next_state = LOAD2;
            done = 0;
        end
        else if(state == LOAD2) begin
            next_state = LOAD3;
            done = 0;
        end
        else if(state == LOAD3) begin
            next_state = LOAD4;
            done  = 0;
        end
        else if(state == LOAD4) begin
            next_state = MATCH;
            done = 0;
        end
        else if(state == MATCH) begin
            if(done_eval) begin
                next_state = MATCH_DONE;
            end
            else begin
                next_state = MATCH;
            end
            done = 0;
        end
        else if(state == MATCH_DONE) begin
            next_state = SEND1;
        end
        else if(state == SEND1) begin
            next_state = SEND2;
            done = 0;
        end
        else if(state == SEND2) begin
            next_state = IDLE;
            done = 1;
        end
        else if(state == IDLE) begin
            if(L1_sorted) begin
                next_state = LOAD1;
            end
            else begin
                next_state = IDLE;
            end
            done = 0;
        end
    end
    
    int i,n;
    int r,c;
    int j;
    // Determine which new orders have the potential to be matched
    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            stage_num <= 0;
            done_eval <= 0;
            num_candidate_incoming_buy <= 0;
            num_candidate_incoming_sell <= 0;
            new_candidate_buy <= 0;
            new_candidate_sell <= 0;
            buys_filled <= 0;
            sells_filled <= 0;
            num_orders_filled_buy <= 0;
            num_orders_filled_sell <= 0;
            num_orders_buy_added <= 0;
            num_orders_buy_removed <= 0;
            num_orders_sell_added <= 0;
            num_orders_sell_removed <= 0;
            new_in_curr_price_buy <= 0;
            new_in_curr_price_sell <= 0;
            out_top_ptr_buy <= 0;
            out_top_ptr_sell <= 0;
            for(i = 0; i < num_incoming_orders*2; i++) begin
                candidate_buys[i] <= 0;
                candidate_sells[i] <= 0;
                for(j = 0; j < num_incoming_orders*2; j++) begin
                    residual_buy_qty[i][j] <= 0;
                    residual_sell_qty[i][j] <= 0;
                    core_en[i][j] <= 0;
                end
                outgoing_orders_buy[i] <= 0;
                outgoing_orders_sell[i] <= 0;
            end
        end
        else if(next_state == LOAD1) begin
            best_buy_price = top_buys[0][price_bits+qty_bits-1 -: price_bits]; 
            best_sell_price = top_sells[0][price_bits+qty_bits-1 -: price_bits];
            num_candidate_incoming_buy = 0;
            num_candidate_incoming_sell = 0;
            new_candidate_buy = 0;
            new_candidate_sell = 0;
            for(i = 0; i < num_incoming_orders; i = i + 1) begin
                // If new order has better price insert at top of candidate buys
                if(new_buys[i][price_bits+qty_bits-1 -: price_bits] > best_buy_price) begin
                    candidate_buys[num_candidate_incoming_buy] <= {1'b1, new_buys[i]};
                    new_candidate_buy[i] <= 1;
                    num_candidate_incoming_buy = num_candidate_incoming_buy + 1;
                end
                if(new_sells[i][price_bits+qty_bits-1 -: price_bits] < best_sell_price) begin
                    candidate_sells[num_candidate_incoming_sell] <= {1'b1,new_sells[i]};
                    new_candidate_sell[i] <= 1;
                    num_candidate_incoming_sell = num_candidate_incoming_sell + 1;
                end
            end
            
            // Compute for next stage, should hurt critical path as above logic is more intensive
            if(top_buy_ptr < num_incoming_orders) begin
                new_in_curr_price_buy <= top_buy_ptr;
            end
            else begin
                new_in_curr_price_buy <= num_incoming_orders;
            end
            if(top_sell_ptr < num_incoming_orders) begin
                new_in_curr_price_sell <= top_sell_ptr;
            end
            else begin
                new_in_curr_price_sell <= num_incoming_orders;
            end
        end
        else if(next_state == LOAD2) begin
            // Insert top of OB after, account for multiple price levels being sent
            for(i = 0; i < new_in_curr_price_buy; i = i + 1) begin
                candidate_buys[i + num_candidate_incoming_buy] <= top_buys[i];
            end
            for(i = 0; i < new_in_curr_price_sell; i = i + 1) begin
                candidate_sells[i + num_candidate_incoming_sell] <= top_sells[i];
            end
        end
        else if(next_state == LOAD3) begin
            // If same price as current top & top is about to be depelted, could potentially match
            for(i = 0; i < num_incoming_orders; i = i + 1) begin
                if(((new_buys[i][price_bits+qty_bits-1 -: price_bits] == best_buy_price) && (top_buy_ptr <= num_incoming_orders))) begin
                    candidate_buys[new_in_curr_price_buy + num_candidate_incoming_buy] <= {1'b1,new_buys[i]};
                    new_candidate_buy[i] <= 1;
                    num_candidate_incoming_buy = num_candidate_incoming_buy + 1;
                end
                if(((new_buys[i][price_bits+qty_bits-1 -: price_bits] == best_buy_price) && (top_buy_ptr <= num_incoming_orders))) begin
                    candidate_sells[new_in_curr_price_sell + num_candidate_incoming_sell] = {1'b1, new_sells[i]};
                    new_candidate_sell[i] <= 1;
                    num_candidate_incoming_sell = num_candidate_incoming_sell + 1;
                end
            end
        end
        else if(next_state == LOAD4) begin
            // Load in rest of incoming orders if neccessary
            for(i = new_in_curr_price_buy; i < num_incoming_orders; i++) begin
                candidate_buys[i + num_candidate_incoming_buy] <= top_buys[i];
            end
            for(i = new_in_curr_price_sell; i < num_incoming_orders; i++) begin
                candidate_sells[i + num_candidate_incoming_sell] <= top_sells[i];
            end
            // Mark the rest of candidates as unfilled
            for(j = num_incoming_orders + num_candidate_incoming_buy; j < 2*num_incoming_orders; j++) begin
                candidate_buys[j] <= 0;
            end
            for(j = num_incoming_orders + num_candidate_incoming_sell; j < 2*num_incoming_orders; j++) begin
                candidate_sells[j] <= 0;
            end
            // Enable cores for next cycle
            done_eval <= 0;
            buys_filled <= 0;
            sells_filled <= 0;
            for (r = 0; r < num_incoming_orders*2; r++) begin
                core_en[r][0] <= 1;
            end
            for (c = 0; c < num_incoming_orders*2; c++) begin
                core_en[0][c] <= 1;
            end
        end
        else if(next_state == MATCH) begin
            stage_num <= stage_num + 1;
            for (r = 0; r < num_incoming_orders*2; r++) begin
                for(c = 0; c < num_incoming_orders*2;c++) begin
                    // Set enable or core
                    if((r == stage_num + 1 && c >= stage_num + 1) || (c == stage_num + 1 && r >= stage_num + 1)) begin
                        core_en[r][c] = 1;
                    end
                    else begin
                        core_en[r][c] = 0;
                    end
                    if (r == stage_num && c >= stage_num) begin
                        residual_buy_qty[r][c]  <= buy_qty_wire[r][c];
                    end
                    if (c == stage_num && r >= stage_num) begin
                        residual_sell_qty[r][c] <= sell_qty_wire[r][c];
                    end
                end
            end
            if(input_sell_qty[stage_num][num_incoming_orders*2-1] != 0 || 
                input_buy_qty[num_incoming_orders*2-1][stage_num] != 0
                || num_orders_filled_sell == num_incoming_orders*2-1 
                || num_orders_filled_buy == num_incoming_orders*2-1) begin
                done_eval <= 1;
            end
        end
        else if(next_state == MATCH_DONE) begin
            candidate_buys[stage_num-1][qty_bits-1:0] <= residual_buy_qty[stage_num-1][stage_num-1];
            candidate_sells[stage_num-1][qty_bits-1:0] <= residual_sell_qty[stage_num-1][stage_num-1];
            for(i = 0; i < num_incoming_orders*2-1; i++) begin
                if(residual_sell_qty[i][stage_num-1] == 0 && candidate_sells[i] != 0) begin
                    sells_filled[i] = 1;
                    num_orders_filled_sell = num_orders_filled_sell + 1;
                end
                if(residual_buy_qty[stage_num-1][i] == 0 && candidate_buys[i] != 0) begin
                    buys_filled[i] = 1;
                    num_orders_filled_buy = num_orders_filled_buy + 1;
                end
            end
        end
        else if(next_state == SEND1) begin
            // Remove cache orders
            if(num_orders_filled_buy > num_incoming_orders) begin
                num_orders_buy_removed <= num_orders_filled_buy - num_incoming_orders;
            end
            else begin
                num_orders_buy_added <= num_incoming_orders - num_orders_filled_buy;
            end
            if(num_orders_filled_sell > num_incoming_orders) begin
                num_orders_sell_removed <= num_orders_filled_sell - num_incoming_orders;
            end
            else begin
                num_orders_sell_added <= num_incoming_orders - num_orders_filled_sell;
            end
            // Push matchable orders back to top of OB
            for(i = 0; i < num_incoming_orders*2; i = i + 1) begin
                // Buy
                if(buys_filled[i] == 0 && out_top_ptr_buy < L1_capacity && i < num_candidate_incoming_buy + num_incoming_orders) begin  // If not filled, has to go back to L1
                    outgoing_orders_buy[out_top_ptr_buy][order_width-1 -: 3] <= 3'b001;  // To L1
                    outgoing_orders_buy[out_top_ptr_buy][order_width-5] <= 1'b1;         // Insert into start of queue
                    outgoing_orders_buy[out_top_ptr_buy][order_width-5:0] <= candidate_buys[i];
                    out_top_ptr_buy = out_top_ptr_buy + 1;
                end
                else if(buys_filled[i] == 0 && i < num_candidate_incoming_buy + num_incoming_orders) begin  // L1 out of room
                    outgoing_orders_buy[out_top_ptr_buy][order_width-1 -: 3] <= 3'b010;  // To L2
                    outgoing_orders_buy[out_top_ptr_buy][order_width-5] <= 1'b1;         // Insert into start of queue
                    outgoing_orders_buy[out_top_ptr_buy][order_width-5:0] <= candidate_buys[i];
                    out_top_ptr_buy = out_top_ptr_buy + 1;
                end
                
                // Sell
                if(sells_filled[i] == 0 && out_top_ptr_sell < L1_capacity && i < num_candidate_incoming_sell + num_incoming_orders) begin
                    outgoing_orders_sell[out_top_ptr_sell][order_width-1 -: 3] <= 3'b001;  // To L1
                    outgoing_orders_sell[out_top_ptr_sell][order_width-5] <= 1'b1;         // Insert into start of queue
                    outgoing_orders_sell[out_top_ptr_sell][order_width-5:0] <= candidate_sells[i];
                    out_top_ptr_sell = out_top_ptr_sell + 1;
                end
                else if(sells_filled[i] == 0 && i < num_candidate_incoming_sell + num_incoming_orders) begin  // L1 out of room
                    outgoing_orders_sell[out_top_ptr_sell][order_width-1 -: 3] <= 3'b010;  // To L2
                    outgoing_orders_sell[out_top_ptr_sell][order_width-5] <= 1'b1;         // Insert into start of queue
                    outgoing_orders_sell[out_top_ptr_sell][order_width-5:0] <= candidate_sells[i];
                    out_top_ptr_sell = out_top_ptr_sell + 1;
                end
            end
        end  
        else if(next_state == SEND2) begin
            for(i = 0; i < num_incoming_orders; i++) begin
                if(buys_filled[i] == 0 && new_buys[i][price_bits+qty_bits-1 -: price_bits] == best_buy_price
                && !new_candidate_buy[i] && out_top_ptr_buy > L1_capacity && top_buy_ptr < L2_capacity) begin
                    outgoing_orders_buy[out_top_ptr_buy][order_width-1 -: 3] <= 3'b010;  // To L2
                    outgoing_orders_buy[out_top_ptr_buy][order_width-4] <= 1'b0;         // Insert into end of price level FIFO
                    outgoing_orders_buy[out_top_ptr_buy][order_width-5:0] <= candidate_buys[i];
                    out_top_ptr_buy = out_top_ptr_buy + 1;
                end
                else if(buys_filled[i] == 0) begin
                    outgoing_orders_buy[out_top_ptr_buy][order_width-1 -: 3] <= 3'b100;  // To CPU
                    outgoing_orders_buy[out_top_ptr_buy][order_width-4] <= 1'b0;         // don't care
                    outgoing_orders_buy[out_top_ptr_buy][order_width-5:0] <= new_buys[i];
                    out_top_ptr_buy = out_top_ptr_buy + 1;
                end
                if(sells_filled[i] == 0 && new_sells[i][price_bits+qty_bits-1 -: price_bits] == best_sell_price
                && !new_candidate_sell[i] && out_top_ptr_sell > L1_capacity && top_sell_ptr < L2_capacity) begin
                    outgoing_orders_sell[out_top_ptr_sell][order_width-1 -: 3] <= 3'b001;  // To L2
                    outgoing_orders_sell[out_top_ptr_sell][order_width-4] <= 1'b0;         // Insert into end of FIFO
                    outgoing_orders_sell[out_top_ptr_sell][order_width-5:0] <= new_sells[i];
                    out_top_ptr_sell = out_top_ptr_sell + 1;
                end
                else if(sells_filled[i] == 0) begin
                    outgoing_orders_sell[out_top_ptr_sell][order_width-1 -: 3] <= 3'b100;  // To CPU
                    outgoing_orders_sell[out_top_ptr_sell][order_width-4] <= 1'b0;         // don't care, has to go to back
                    outgoing_orders_sell[out_top_ptr_sell][order_width-5:0] <= new_sells[i];
                    out_top_ptr_sell = out_top_ptr_sell + 1;
                end
            end
        end 
    end
    
    // Generate grid of matching cores, populate with candidate buys/sells
    genvar row, col;
    generate
        for (row = 0; row < num_incoming_orders*2; row++) begin : row_loop
            for (col = 0; col < num_incoming_orders*2; col++) begin : col_loop
    
                // Buy qty input
                assign input_buy_qty[row][col] = (row == 0)
                    ? candidate_buys[col][qty_bits-1:0]
                    : (core_en[row][col] && row != col        // exclude corner - corner reads register
                        ? buy_qty_wire[row-1][col]
                        : residual_buy_qty[row-1][col]);
                
                // Sell qty input
                assign input_sell_qty[row][col] = (col == 0)
                    ? candidate_sells[row][qty_bits-1:0]
                    : (core_en[row][col] && row != col        // exclude corner - corner reads register
                        ? sell_qty_wire[row][col-1]
                        : residual_sell_qty[row][col-1]);
    
                Matching_Core core_inst (
                    .en          (core_en[row][col]),
                    .buy_filled  (buys_filled[col]),
                    .sell_filled (sells_filled[row]),
                    .buy_price   (candidate_buys[col][price_bits+qty_bits-1 -: price_bits]),
                    .buy_qty     (input_buy_qty[row][col]),
                    .sell_price  (candidate_sells[row][price_bits+qty_bits-1 -: price_bits]),
                    .sell_qty    (input_sell_qty[row][col]),
                    .next_buy_qty  (buy_qty_wire[row][col]),
                    .next_sell_qty (sell_qty_wire[row][col])
                );
            end
        end
    endgenerate              
endmodule
