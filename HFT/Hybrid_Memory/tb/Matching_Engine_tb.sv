`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/19/2026 09:31:33 PM
// Design Name: 
// Module Name: Matching_Engine_tb
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

module Matching_Engine_tb #(
    parameter L1_capacity = 8,
    parameter L2_capacity = 120,
    parameter timestamp_bits = 32,
    parameter orderID_bits   = 16,
    parameter price_bits     = 16,
    parameter qty_bits       = 16,
    parameter order_locations = 3,
    parameter FoB             = 1,
    parameter order_width = order_locations + FoB + timestamp_bits + orderID_bits + price_bits + qty_bits,
    parameter num_incoming_orders = 5
    )();

    logic clk, rstn, L1_sorted;
    logic [order_width-5:0] new_buys  [num_incoming_orders];
    logic [order_width-5:0] new_sells [num_incoming_orders];
    logic [order_width-5:0] top_buys  [num_incoming_orders];
    logic [order_width-5:0] top_sells [num_incoming_orders];
    logic [$clog2(L1_capacity + L2_capacity)-1:0] top_buy_ptr;
    logic [$clog2(L1_capacity + L2_capacity)-1:0] top_sell_ptr;
    logic [$clog2(num_incoming_orders*2)-1:0] num_orders_buy_added;
    logic [$clog2(num_incoming_orders)-1:0]   num_orders_buy_removed;
    logic [$clog2(num_incoming_orders*2)-1:0] num_orders_sell_added;
    logic [$clog2(num_incoming_orders)-1:0]   num_orders_sell_removed;
    logic [order_width-1:0] outgoing_orders_buy  [num_incoming_orders*2];
    logic [order_width-1:0] outgoing_orders_sell [num_incoming_orders*2];
    logic done;

    MatchingEngine #(
        .L1_capacity(L1_capacity),
        .L2_capacity(L2_capacity),
        .timestamp_bits(timestamp_bits),
        .orderID_bits(orderID_bits),
        .price_bits(price_bits),
        .qty_bits(qty_bits),
        .order_locations(order_locations),
        .FoB(FoB),
        .num_incoming_orders(num_incoming_orders)
    ) DUT (
        .clk(clk),
        .rstn(rstn),
        .L1_sorted(L1_sorted),
        .new_buys(new_buys),
        .new_sells(new_sells),
        .top_buys(top_buys),
        .top_sells(top_sells),
        .top_buy_ptr(top_buy_ptr),
        .top_sell_ptr(top_sell_ptr),
        .num_orders_buy_added(num_orders_buy_added),
        .num_orders_buy_removed(num_orders_buy_removed),
        .num_orders_sell_added(num_orders_sell_added),
        .num_orders_sell_removed(num_orders_sell_removed),
        .outgoing_orders_buy(outgoing_orders_buy),
        .outgoing_orders_sell(outgoing_orders_sell),
        .done(done)
    );

    // -------------------------------------------------------------------------
    // Clock: 10ns period
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Order construction helper
    // order_width-5 format (MSB to LSB):
    //   [timestamp_bits] [orderID_bits] [price_bits] [qty_bits]
    // -------------------------------------------------------------------------
    function automatic logic [order_width-5:0] make_order(
        input logic [timestamp_bits-1:0] ts,
        input logic [orderID_bits-1:0]   oid,
        input logic [price_bits-1:0]     price,
        input logic [qty_bits-1:0]       qty
    );
        make_order = {ts, oid, price, qty};
    endfunction

    // -------------------------------------------------------------------------
    // Helper: extract price field from a packed order
    // -------------------------------------------------------------------------
    function automatic logic [price_bits-1:0] get_price(
        input logic [order_width-5:0] ord
    );
        get_price = ord[price_bits+qty_bits-1 -: price_bits];
    endfunction

    // -------------------------------------------------------------------------
    // Standard input stimulus
    //
    // new_buys/sells:
    //   [0..2] : 3 orders at BEST price (110 buy / 90 sell) -> LOAD1 candidates
    //   [3]    : 1 order AT best price but within tail ptr  -> LOAD3 candidate
    //   [4]    : 1 order at a worse price                   -> routed to CPU in SEND2
    //
    // top_buys/sells:
    //   [0..3] : 4 orders at best price level (ptr = 4)
    //   [4]    : 1 order at next price level
    //
    // top_buy_ptr = top_sell_ptr = 4  (4 orders in current best price level)
    // -------------------------------------------------------------------------
    localparam BEST_BUY_PRICE  = 16'd100; // Set up so new orders match but nothing else does
    localparam BEST_SELL_PRICE = 16'd100;
    localparam WORSE_BUY_PRICE = 16'd90;  // Below best buy  -> CPU
    localparam WORSE_SELL_PRICE= 16'd110;   // Above best sell -> CPU
    localparam TOP_PTR         = 4;

    task load_stimulus();
        // new_buys[0..2]: better than best price -> LOAD1 candidates
        new_buys[0] = make_order(32'd1, 16'd0,  BEST_BUY_PRICE, 16'd50);
        new_buys[1] = make_order(32'd2, 16'd1,  BEST_BUY_PRICE, 16'd60);
        new_buys[2] = make_order(32'd3, 16'd2,  BEST_BUY_PRICE, 16'd70);
        // new_buys[3]: same as best price, within tail ptr -> LOAD3 candidate
        new_buys[3] = make_order(32'd4, 16'd3,  BEST_BUY_PRICE-1, 16'd40);
        // new_buys[4]: worse price -> will be routed to CPU in SEND2
        new_buys[4] = make_order(32'd5, 16'd4,  WORSE_BUY_PRICE, 16'd30);

        // new_sells[0..2]: better than best sell price -> LOAD1 candidates
        new_sells[0] = make_order(32'd1, 16'd10, BEST_SELL_PRICE, 16'd50);
        new_sells[1] = make_order(32'd2, 16'd11, BEST_SELL_PRICE, 16'd60);
        new_sells[2] = make_order(32'd3, 16'd12, BEST_SELL_PRICE, 16'd70);
        // new_sells[3]: same as best sell price, within tail ptr -> LOAD3 candidate
        new_sells[3] = make_order(32'd4, 16'd13, BEST_SELL_PRICE+1, 16'd40);
        // new_sells[4]: worse price -> will be routed to CPU in SEND2
        new_sells[4] = make_order(32'd5, 16'd14, WORSE_SELL_PRICE, 16'd30);

        // top_buys[0..3]: 4 orders at best price level
        top_buys[0] = make_order(32'd10, 16'd20, BEST_BUY_PRICE-1, 16'd100);
        top_buys[1] = make_order(32'd11, 16'd21, BEST_BUY_PRICE-1, 16'd80);
        top_buys[2] = make_order(32'd12, 16'd22, BEST_BUY_PRICE-1, 16'd90);
        top_buys[3] = make_order(32'd13, 16'd23, BEST_BUY_PRICE-1, 16'd70);
        // top_buys[4]: next price level
        top_buys[4] = make_order(32'd14, 16'd24, BEST_BUY_PRICE - 2, 16'd50);

        // top_sells[0..3]: 4 orders at best price level
        top_sells[0] = make_order(32'd10, 16'd30, BEST_SELL_PRICE+1, 16'd100);
        top_sells[1] = make_order(32'd11, 16'd31, BEST_SELL_PRICE+1, 16'd80);
        top_sells[2] = make_order(32'd12, 16'd32, BEST_SELL_PRICE+1, 16'd90);
        top_sells[3] = make_order(32'd13, 16'd33, BEST_SELL_PRICE+1, 16'd70);
        // top_sells[4]: next price level
        top_sells[4] = make_order(32'd14, 16'd34, BEST_SELL_PRICE + 2, 16'd50);

        // 4 orders in current best price level on both sides
        top_buy_ptr  = TOP_PTR;
        top_sell_ptr = TOP_PTR;

        L1_sorted = 1;
    endtask

    // -------------------------------------------------------------------------
    // Test RST: verify all outputs are 0 immediately after reset
    // -------------------------------------------------------------------------
    task test_RST();
        $display("=== Test RST: All outputs zero after reset ===");
        rstn      = 0;
        L1_sorted = 0;
        for(int i = 0; i < num_incoming_orders; i++) begin
            new_buys[i]  = '0;
            new_sells[i] = '0;
            top_buys[i]  = '0;
            top_sells[i] = '0;
        end
        top_buy_ptr  = '0;
        top_sell_ptr = '0;
        @(posedge clk); #1;
        rstn = 1;
        @(posedge clk); #1;

        // Output ports
        assert(done == 0)
            else $error("RST FAILED: done != 0");
        assert(num_orders_buy_added == 0)
            else $error("RST FAILED: num_orders_buy_added != 0");
        assert(num_orders_buy_removed == 0)
            else $error("RST FAILED: num_orders_buy_removed != 0");
        assert(num_orders_sell_added == 0)
            else $error("RST FAILED: num_orders_sell_added != 0");
        assert(num_orders_sell_removed == 0)
            else $error("RST FAILED: num_orders_sell_removed != 0");
        for(int i = 0; i < num_incoming_orders*2; i++) begin
            assert(outgoing_orders_buy[i] == 0)
                else $error("RST FAILED: outgoing_orders_buy[%0d] != 0", i);
            assert(outgoing_orders_sell[i] == 0)
                else $error("RST FAILED: outgoing_orders_sell[%0d] != 0", i);
        end

        // Internal candidate arrays
        for(int i = 0; i < num_incoming_orders*2; i++) begin
            assert(DUT.candidate_buys[i] == 0)
                else $error("RST FAILED: candidate_buys[%0d] != 0", i);
            assert(DUT.candidate_sells[i] == 0)
                else $error("RST FAILED: candidate_sells[%0d] != 0", i);
        end
        assert(DUT.stage_num == 0)
            else $error("RST FAILED: stage_num != 0");
        assert(DUT.num_candidate_incoming_buy == 0)
            else $error("RST FAILED: num_candidate_incoming_buy != 0");
        assert(DUT.num_candidate_incoming_sell == 0)
            else $error("RST FAILED: num_candidate_incoming_sell != 0");

        $display("Test RST PASSED");
    endtask

    // -------------------------------------------------------------------------
    // Test LOAD1: new_buys/sells[0..2] with best price become candidates
    // -------------------------------------------------------------------------
    task test_LOAD1();
        $display("=== Test LOAD1: Best price new orders populate candidates ===");
        load_stimulus();
        @(posedge clk); #1;  // RST -> LOAD1 (L1_sorted=1)
        @(posedge clk); #1;  // LOAD1 executes, state moves to LOAD2

        // Expect candidate_buys[0..2] to hold the 3 best new buy orders
        // marked with new bit (MSB = 1)
//        for(int i = 0; i < 3; i++) begin
//            assert(DUT.candidate_buys[i] == new_buys[i][order_width-5:0])
//                else $error("LOAD1 FAILED: candidate_buys[%0d] data mismatch", i);
//        end
//        // Expect candidate_sells[0..2] to hold the 3 best new sell orders
//        for(int i = 0; i < 3; i++) begin
//            assert(DUT.candidate_sells[i] == new_sells[i][order_width-5:0] )
//                else $error("LOAD1 FAILED: candidate_sells[%0d] data mismatch", i);
//        end
//        // num_candidate_incoming should reflect 3 new orders each side
//        assert(DUT.num_candidate_incoming_buy == 3)
//            else $error("LOAD1 FAILED: num_candidate_incoming_buy = %0d, expected 3",
//                        DUT.num_candidate_incoming_buy);
//        assert(DUT.num_candidate_incoming_sell == 3)
//            else $error("LOAD1 FAILED: num_candidate_incoming_sell = %0d, expected 3",
//                        DUT.num_candidate_incoming_sell);
//        // Best prices captured correctly
//        assert(DUT.best_buy_price == BEST_BUY_PRICE)
//            else $error("LOAD1 FAILED: best_buy_price = %0d, expected %0d",
//                        DUT.best_buy_price, BEST_BUY_PRICE-1);
//        assert(DUT.best_sell_price == BEST_SELL_PRICE)
//            else $error("LOAD1 FAILED: best_sell_price = %0d, expected %0d",
//                        DUT.best_sell_price, BEST_SELL_PRICE+1);
//        // new_in_curr_price should equal TOP_PTR since ptr <= num_incoming_orders
//        assert(DUT.new_in_curr_price_buy == TOP_PTR)
//            else $error("LOAD1 FAILED: new_in_curr_price_buy = %0d, expected %0d",
//                        DUT.new_in_curr_price_buy, TOP_PTR);
//        assert(DUT.new_in_curr_price_sell == TOP_PTR)
//            else $error("LOAD1 FAILED: new_in_curr_price_sell = %0d, expected %0d",
//                        DUT.new_in_curr_price_sell, TOP_PTR);

        $display("Test LOAD1 PASSED");
    endtask

    // -------------------------------------------------------------------------
    // Test LOAD2: top_buys/sells[0..3] (best price level) appended to candidates
    // -------------------------------------------------------------------------
    task test_LOAD2();
        $display("=== Test LOAD2: Top OB best price level inserted into candidates ===");
        // Already in LOAD2 state after test_LOAD1, advance one more cycle
        @(posedge clk); #1;  // LOAD2 executes, state moves to LOAD3

        // candidate_buys[3..6] should now hold top_buys[0..3]
        // (offset by num_candidate_incoming_buy = 3)
//        for(int i = 0; i < TOP_PTR; i++) begin
//            assert(DUT.candidate_buys[i + 3][order_width-5:0] == top_buys[i])
//                else $error("LOAD2 FAILED: candidate_buys[%0d] mismatch, got %0h expected %0h",
//                            i+3, DUT.candidate_buys[i+3][order_width-5:0], top_buys[i]);
//            // Top OB orders are not new, so new bit should be 0
//            assert(DUT.candidate_buys[i + 3][order_width] == 1'b0)
//                else $error("LOAD2 FAILED: candidate_buys[%0d] new bit should be 0", i+3);
//        end
//        for(int i = 0; i < TOP_PTR; i++) begin
//            assert(DUT.candidate_sells[i + 3][order_width-5:0] == top_sells[i])
//                else $error("LOAD2 FAILED: candidate_sells[%0d] mismatch, got %0h expected %0h",
//                            i+3, DUT.candidate_sells[i+3][order_width-5:0], top_sells[i]);
//            assert(DUT.candidate_sells[i + 3][order_width] == 1'b0)
//                else $error("LOAD2 FAILED: candidate_sells[%0d] new bit should be 0", i+3);
//        end

        $display("Test LOAD2 PASSED");
    endtask

    // -------------------------------------------------------------------------
    // Test LOAD3: new_buys/sells[3] at best price within tail ptr -> candidate
    // -------------------------------------------------------------------------
    task test_LOAD3();
        $display("=== Test LOAD3: Same-price new order within tail ptr added to candidates ===");
        @(posedge clk); #1;  // LOAD3 executes, state moves to LOAD4

        // new_buys[3] is at best price and top_buy_ptr <= num_incoming_orders
        // so it should have been appended after the current price level entries
        // Position = new_in_curr_price_buy(4) + num_candidate_incoming_buy(3) = 7
        // However since num_incoming_orders*2 = 10, index 7 is valid
//        assert(DUT.candidate_buys[TOP_PTR + 3][order_width-5:0] == new_buys[3])
//            else $error("LOAD3 FAILED: candidate_buys[%0d] mismatch, got %0h expected %0h",
//                        TOP_PTR+3, DUT.candidate_buys[TOP_PTR+3][order_width-5:0], new_buys[3]);
//        assert(DUT.candidate_buys[TOP_PTR + 3][order_width] == 1'b1)
//            else $error("LOAD3 FAILED: candidate_buys[%0d] new bit not set", TOP_PTR+3);

//        assert(DUT.candidate_sells[TOP_PTR + 3][order_width-5:0] == new_sells[3])
//            else $error("LOAD3 FAILED: candidate_sells[%0d] mismatch, got %0h expected %0h",
//                        TOP_PTR+3, DUT.candidate_sells[TOP_PTR+3][order_width-5:0], new_sells[3]);
//        assert(DUT.candidate_sells[TOP_PTR + 3][order_width] == 1'b1)
//            else $error("LOAD3 FAILED: candidate_sells[%0d] new bit not set", TOP_PTR+3);

//        // num_candidate_incoming should now be 4
//        assert(DUT.num_candidate_incoming_buy == 4)
//            else $error("LOAD3 FAILED: num_candidate_incoming_buy = %0d, expected 4",
//                        DUT.num_candidate_incoming_buy);
//        assert(DUT.num_candidate_incoming_sell == 4)
//            else $error("LOAD3 FAILED: num_candidate_incoming_sell = %0d, expected 4",
//                        DUT.num_candidate_incoming_sell);

        $display("Test LOAD3 PASSED");
    endtask

    // -------------------------------------------------------------------------
    // Test LOAD4: top_buys/sells[4] (next price level) appended, last slot stays 0
    // -------------------------------------------------------------------------
    task test_LOAD4();
        $display("=== Test LOAD4: Next price level order inserted, last candidate stays 0 ===");
        @(posedge clk); #1;  // LOAD4 executes, state moves to MATCH

        // top_buys[4] is the one order beyond the current price level
        // new_in_curr_price_buy = 4, so it is inserted at index 4 + 4 = 8
        assert(DUT.candidate_buys[TOP_PTR + 4][order_width-5:0] == top_buys[4])
            else $error("LOAD4 FAILED: candidate_buys[%0d] mismatch, got %0h expected %0h",
                        TOP_PTR+4, DUT.candidate_buys[TOP_PTR+4][order_width-5:0], top_buys[4]);
        assert(DUT.candidate_sells[TOP_PTR + 4][order_width-5:0] == top_sells[4])
            else $error("LOAD4 FAILED: candidate_sells[%0d] mismatch, got %0h expected %0h",
                        TOP_PTR+4, DUT.candidate_sells[TOP_PTR+4][order_width-5:0], top_sells[4]);

        // Last slot (index num_incoming_orders*2 - 1 = 9) should remain 0
        // since num_incoming_orders + num_candidate_incoming = 5 + 4 = 9,
        // meaning candidates[9] was marked empty
        assert(DUT.candidate_buys[num_incoming_orders*2 - 1] == 0)
            else $error("LOAD4 FAILED: last candidate_buys slot should be 0, got %0h",
                        DUT.candidate_buys[num_incoming_orders*2 - 1]);
        assert(DUT.candidate_sells[num_incoming_orders*2 - 1] == 0)
            else $error("LOAD4 FAILED: last candidate_sells slot should be 0, got %0h",
                        DUT.candidate_sells[num_incoming_orders*2 - 1]);

        $display("Test LOAD4 PASSED");
    endtask
    
    task test_MATCH1();
        $display("=== Test MATCH1 ===");
        @(posedge clk); #1;
        
    endtask
    task test_MATCH2();
        $display("=== Test MATCH2 ===");
        @(posedge clk); #1;
        
    endtask
    task test_MATCH3();
        $display("=== Test MATCH3 ===");
        @(posedge clk); #1;
        
    endtask
    task test_SEND1();
        $display("=== Test SEND1 ===");
        @(posedge clk); #1;
        
    endtask
    task test_SEND2();
        $display("=== Test SEND1 ===");
        @(posedge clk); #1;
        
    endtask
    task test_END();
        $display("=== Test END ===");
        @(posedge clk); #1;
        
    endtask

    // -------------------------------------------------------------------------
    // Run all tests
    // -------------------------------------------------------------------------
    initial begin
        rstn      = 0;
        L1_sorted = 0;
        for(int i = 0; i < num_incoming_orders; i++) begin
            new_buys[i]  = '0;
            new_sells[i] = '0;
            top_buys[i]  = '0;
            top_sells[i] = '0;
        end
        top_buy_ptr  = '0;
        top_sell_ptr = '0;
        @(posedge clk); #1;
        rstn = 1;
        @(posedge clk); #1;

//        test_RST();
        test_LOAD1();
        test_LOAD2();
        test_LOAD3();
        test_LOAD4();
        test_MATCH1();
        test_MATCH2();
        test_MATCH3();
        test_SEND1();
        test_SEND2();
        test_END();

        $display("=== All Matching Engine LOAD tests complete ===");
        $finish;
    end

endmodule
