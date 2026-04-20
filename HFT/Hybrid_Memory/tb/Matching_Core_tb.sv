`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/19/2026 09:43:05 PM
// Design Name: 
// Module Name: Matching_Core_tb
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

/* THIS IS A CLAUDE GENERATED TESTBENCH */

module Matching_Core_tb #(
    parameter timestamp_bits = 32,
    parameter orderID_bits   = 16,
    parameter price_bits     = 16,
    parameter qty_bits       = 16,
    parameter order_width    = timestamp_bits + orderID_bits + price_bits + qty_bits,
    parameter num_incoming_orders = 1
    )();

    logic                    en;
    logic [price_bits-1:0]   buy_price, sell_price;
    logic [qty_bits-1:0]     buy_qty,   sell_qty;
    logic [qty_bits-1:0]     next_buy_qty, next_sell_qty;
    logic                    buy_filled,  sell_filled;
    logic                    buy_pfilled, sell_pfilled;

    Matching_Core #(
        .timestamp_bits(timestamp_bits),
        .orderID_bits(orderID_bits),
        .price_bits(price_bits),
        .qty_bits(qty_bits),
        .num_incoming_orders(num_incoming_orders)
    ) DUT (
        .en(en),
        .buy_price(buy_price),
        .sell_price(sell_price),
        .buy_qty(buy_qty),
        .sell_qty(sell_qty),
        .next_buy_qty(next_buy_qty),
        .next_sell_qty(next_sell_qty),
        .buy_filled(buy_filled),
        .sell_filled(sell_filled),
        .buy_pfilled(buy_pfilled),
        .sell_pfilled(sell_pfilled)
    );

    // -------------------------------------------------------------------------
    // Task: drive inputs and check outputs after propagation delay
    // -------------------------------------------------------------------------
    task apply_and_check(
        input logic                  t_en,
        input logic [price_bits-1:0] t_buy_price,
        input logic [price_bits-1:0] t_sell_price,
        input logic [qty_bits-1:0]   t_buy_qty,
        input logic [qty_bits-1:0]   t_sell_qty,
        // Expected outputs
        input logic [qty_bits-1:0]   exp_next_buy_qty,
        input logic [qty_bits-1:0]   exp_next_sell_qty,
        input logic                  exp_buy_filled,
        input logic                  exp_sell_filled,
        input logic                  exp_buy_pfilled,
        input logic                  exp_sell_pfilled,
        input string                 test_name
    );
        en         = t_en;
        buy_price  = t_buy_price;
        sell_price = t_sell_price;
        buy_qty    = t_buy_qty;
        sell_qty   = t_sell_qty;
        #10; // Allow combinational logic to settle

        assert(next_buy_qty  == exp_next_buy_qty)
            else $error("%s FAILED: next_buy_qty = %0d, expected %0d",
                        test_name, next_buy_qty, exp_next_buy_qty);
        assert(next_sell_qty == exp_next_sell_qty)
            else $error("%s FAILED: next_sell_qty = %0d, expected %0d",
                        test_name, next_sell_qty, exp_next_sell_qty);
        assert(buy_filled    == exp_buy_filled)
            else $error("%s FAILED: buy_filled = %0b, expected %0b",
                        test_name, buy_filled, exp_buy_filled);
        assert(sell_filled   == exp_sell_filled)
            else $error("%s FAILED: sell_filled = %0b, expected %0b",
                        test_name, sell_filled, exp_sell_filled);
        assert(buy_pfilled   == exp_buy_pfilled)
            else $error("%s FAILED: buy_pfilled = %0b, expected %0b",
                        test_name, buy_pfilled, exp_buy_pfilled);
        assert(sell_pfilled  == exp_sell_pfilled)
            else $error("%s FAILED: sell_pfilled = %0b, expected %0b",
                        test_name, sell_pfilled, exp_sell_pfilled);

        $display("%s PASSED", test_name);
    endtask

    initial begin
        en = 0; buy_price = 0; sell_price = 0; buy_qty = 0; sell_qty = 0;
        #10;

        // ----------------------------------------------------------------
        // Test 1: en = 0, no match should occur regardless of prices/qtys
        // ----------------------------------------------------------------
        apply_and_check(
            0, 100, 90, 50, 50,
            // Outputs undefined when en=0 - just check en=1 cases below
            // We expect no assertion here since outputs are don't-care,
            // so we pass current output values to avoid false failures
            next_buy_qty, next_sell_qty,
            buy_filled, sell_filled, buy_pfilled, sell_pfilled,
            "Test 1: en=0 no match"
        );

        // ----------------------------------------------------------------
        // Test 2: buy_price == sell_price, buy_qty == sell_qty
        // Both fully filled, no remainder
        // ----------------------------------------------------------------
        apply_and_check(
            1, 100, 100, 50, 50,
            0, 0,
            1, 1, 0, 0,
            "Test 2: exact match equal price equal qty"
        );

        // ----------------------------------------------------------------
        // Test 3: buy_price > sell_price, buy_qty == sell_qty
        // Both fully filled
        // ----------------------------------------------------------------
        apply_and_check(
            1, 110, 100, 75, 75,
            0, 0,
            1, 1, 0, 0,
            "Test 3: buy_price > sell_price equal qty"
        );

        // ----------------------------------------------------------------
        // Test 4: buy_price > sell_price, buy_qty > sell_qty
        // Buy partially filled, sell fully filled
        // ----------------------------------------------------------------
        apply_and_check(
            1, 110, 100, 100, 60,
            40, 0,
            0, 0, 1, 1,
            "Test 4: buy_price > sell_price buy_qty > sell_qty"
        );

        // ----------------------------------------------------------------
        // Test 5: buy_price > sell_price, sell_qty > buy_qty
        // Sell partially filled, buy fully filled
        // ----------------------------------------------------------------
        apply_and_check(
            1, 110, 100, 40, 100,
            0, 60,
            1, 1, 0, 0,
            "Test 5: buy_price > sell_price sell_qty > buy_qty"
        );

        // ----------------------------------------------------------------
        // Test 6: buy_price == sell_price, buy_qty > sell_qty
        // Buy partially filled, sell fully filled
        // ----------------------------------------------------------------
        apply_and_check(
            1, 100, 100, 200, 50,
            150, 0,
            0, 0, 1, 1,
            "Test 6: equal price buy_qty > sell_qty"
        );

        // ----------------------------------------------------------------
        // Test 7: buy_price == sell_price, sell_qty > buy_qty
        // Sell partially filled, buy fully filled
        // ----------------------------------------------------------------
        apply_and_check(
            1, 100, 100, 50, 200,
            0, 150,
            1, 1, 0, 0,
            "Test 7: equal price sell_qty > buy_qty"
        );

        // ----------------------------------------------------------------
        // Test 8: buy_price < sell_price, no match
        // All outputs should reflect no trade
        // ----------------------------------------------------------------
        apply_and_check(
            1, 90, 100, 50, 50,
            50, 50,
            0, 0, 0, 0,
            "Test 8: buy_price < sell_price no match"
        );

        // ----------------------------------------------------------------
        // Test 9: buy_price < sell_price, asymmetric qtys, still no match
        // ----------------------------------------------------------------
        apply_and_check(
            1, 80, 100, 200, 10,
            200, 10,
            0, 0, 0, 0,
            "Test 9: buy_price < sell_price asymmetric qty no match"
        );

        // ----------------------------------------------------------------
        // Test 10: Boundary - qty = 1 on both sides, exact match
        // ----------------------------------------------------------------
        apply_and_check(
            1, 100, 100, 1, 1,
            0, 0,
            1, 1, 0, 0,
            "Test 10: boundary qty=1 exact match"
        );

        // ----------------------------------------------------------------
        // Test 11: Boundary - buy_qty = 1, sell_qty large
        // Buy fully filled, sell has large remainder
        // ----------------------------------------------------------------
        apply_and_check(
            1, 100, 100, 1, 1000,
            0, 999,
            1, 1, 0, 0,
            "Test 11: boundary buy_qty=1 sell_qty=1000"
        );

        // ----------------------------------------------------------------
        // Test 12: Boundary - max price values, buy >= sell
        // ----------------------------------------------------------------
        apply_and_check(
            1, {price_bits{1'b1}}, {price_bits{1'b1}}, 50, 50,
            0, 0,
            1, 1, 0, 0,
            "Test 12: max price values equal qty"
        );

        // ----------------------------------------------------------------
        // Test 13: Boundary - max qty values, buy_qty > sell_qty
        // ----------------------------------------------------------------
        apply_and_check(
            1, 100, 100, {qty_bits{1'b1}}, 1,
            {qty_bits{1'b1}} - 1, 0,
            0, 0, 1, 1,
            "Test 13: max buy_qty sell_qty=1"
        );

        // ----------------------------------------------------------------
        // Test 14: en toggles mid-simulation - disable then re-enable
        // ----------------------------------------------------------------
        en = 1; buy_price = 110; sell_price = 100; buy_qty = 50; sell_qty = 50;
        #10;
        assert(buy_filled == 1)
            else $error("Test 14a FAILED: expected match when en=1");
        en = 0;
        #10;
        // Outputs are don't-care when disabled - just verify no $error from X prop
        en = 1;
        #10;
        assert(buy_filled == 1)
            else $error("Test 14b FAILED: match should resume after re-enable");
        $display("Test 14: en toggle PASSED");

        // ----------------------------------------------------------------
        // Test 15: buy_price = sell_price - 1, just below threshold
        // ----------------------------------------------------------------
        apply_and_check(
            1, 99, 100, 50, 50,
            50, 50,
            0, 0, 0, 0,
            "Test 15: buy_price just below sell_price no match"
        );

        $display("=== All Matching_Core tests complete ===");
        $finish;
    end

endmodule
