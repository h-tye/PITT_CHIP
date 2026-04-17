`timescale 1ns / 1ps

module L2_tb #(
    parameter L1_capacity = 8,
    parameter L2_capacity = 16,
    parameter timestamp_bits = 32,
    parameter orderID_bits = 16,
    parameter price_bits = 16,
    parameter qty_bits = 16,
    parameter order_locations = 3,
    parameter FoB = 1,
    parameter order_width = order_locations + FoB + timestamp_bits + orderID_bits + price_bits + qty_bits,
    parameter num_incoming_orders = 5,
    parameter num_dut_orders = 100,
    parameter test_price = 100,
    parameter test_qty = 50
    )();

    logic clk, rstn, done_matching, CPU_orders_ready;
    logic [$clog2(num_incoming_orders)-1:0] num_L2_requested;
    logic [$clog2(num_incoming_orders)-1:0] num_L1_evicted;
    logic [$clog2(num_incoming_orders*2)-1:0] num_orders_added;
    logic [9:0] top_level_tail_ptr;
    logic [$clog2(num_incoming_orders)-1:0] num_cancelled;
    logic [$clog2(L1_capacity+L2_capacity)-1:0] cancelled_orders [num_incoming_orders];
    logic [order_width-1:0] L1_orders [num_incoming_orders];
    logic [order_width-1:0] new_orders [num_incoming_orders*2];
    logic [order_width-1:0] CPU_orders [num_incoming_orders];
    logic [order_width-1:0] orders_to_L1 [num_incoming_orders];
    logic L2_orders_ready;
    logic [order_width-1:0] evicted_orders [num_incoming_orders];
    logic [$clog2(num_incoming_orders)-1:0] num_CPU_requested;
    logic [$clog2(num_incoming_orders)-1:0] num_L2_evicted;

    // Simulated CPU buffer to store evicted orders for reuse
    logic [order_width-1:0] CPU_sim [16];
    logic [3:0] CPU_sim_ptr;

    L2 #(
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
        .done_matching(done_matching),
        .CPU_orders_ready(CPU_orders_ready),
        .num_L2_requested(num_L2_requested),
        .num_L1_evicted(num_L1_evicted),
        .top_level_tail_ptr(top_level_tail_ptr),
        .num_orders_added(num_orders_added),
        .num_cancelled(num_cancelled),
        .cancelled_orders(cancelled_orders),
        .L1_orders(L1_orders),
        .new_orders(new_orders),
        .CPU_orders(CPU_orders),
        .orders_to_L1(orders_to_L1),
        .evicted_orders(evicted_orders),
        .num_CPU_requested(num_CPU_requested),
        .num_L2_evicted(num_L2_evicted),
        .L2_orders_ready(L2_orders_ready)
    );

    // Clock generation: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Order generation helpers
    // order format (MSB to LSB):
    //   [order_width-1 -: 3] = location (3'b010 = L2)
    //   [order_width-4]      = FoB (1 = front, 0 = back)
    //   [timestamp_bits]     = timestamp
    //   [orderID_bits]       = order ID
    //   [price_bits]         = price
    //   [qty_bits]           = qty
    // -------------------------------------------------------------------------
    function automatic logic [order_width-1:0] make_order(
        input logic [2:0]                loc,
        input logic                      fob,
        input logic [timestamp_bits-1:0] ts,
        input logic [orderID_bits-1:0]   oid,
        input logic [price_bits-1:0]     price,
        input logic [qty_bits-1:0]       qty
    );
        make_order = {loc, fob, ts, oid, price, qty};
    endfunction

    function automatic logic [order_width-5:0] make_L1_order(
        input logic [timestamp_bits-1:0] ts,
        input logic [orderID_bits-1:0]   oid,
        input logic [price_bits-1:0]     price,
        input logic [qty_bits-1:0]       qty
    );
        make_L1_order = {ts, oid, price, qty};
    endfunction

    function automatic logic [price_bits-1:0] rand_price();
        rand_price = test_price + ($urandom_range(0,20) - 10);
    endfunction

    function automatic logic [qty_bits-1:0] rand_qty();
        rand_qty = test_qty + ($urandom_range(0,20) - 10);
    endfunction

    // New order pool: L2 location, all back insertions
    logic [order_width-1:0] dut_new_orders [num_dut_orders];
    initial begin
        for(int i = 0; i < num_dut_orders; i++) begin
            dut_new_orders[i] = make_order(
                3'b010,
                1'b0,
                timestamp_bits'(i / 2),
                orderID_bits'(i),
                rand_price(),
                rand_qty()
            );
        end
    end
    
    logic [order_width-1:0] dut_L1_orders [10];  // Intial L1 to throw at sim
    initial begin
        for(int i = 0; i < num_dut_orders; i++) begin
            dut_L1_orders[i] = make_order(
                3'b001,
                1'b0,
                timestamp_bits'(i / 2),
                orderID_bits'(i),
                rand_price(),
                rand_qty()
            );
        end
    end

    // Simulated L1 evicted orders (stripped of header, order_width-5 wide)
    logic [order_width-5:0] evicted_L1_orders [num_dut_orders];
    initial begin
        for(int i = 0; i < num_dut_orders; i++) begin
            evicted_L1_orders[i] = make_L1_order(
                timestamp_bits'(i / 2),
                orderID_bits'(i),
                rand_price(),
                rand_qty()
            );
        end
    end

    // CPU order pool for cancellation replacements
    logic [order_width-1:0] CPU_order_pool [num_dut_orders];
    initial begin
        logic [timestamp_bits-1:0] ts;
        logic [orderID_bits-1:0]   oid;
        for(int i = 0; i < num_dut_orders; i++) begin
            ts  = timestamp_bits'(i / 2);
            oid = orderID_bits'(i + num_dut_orders);
            CPU_order_pool[i] = {ts, oid, rand_price(), rand_qty()};
        end
    end

    // Capture evicted orders into CPU_sim buffer for reuse
    int n;
    always_ff @(posedge clk) begin
        for(n = 0; n < num_incoming_orders; n++) begin
            if(evicted_orders[n] != '0) begin
                CPU_sim[CPU_sim_ptr] = evicted_orders[n];
                CPU_sim_ptr = CPU_sim_ptr + 1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Task: reset DUT
    // -------------------------------------------------------------------------
    task do_reset();
        rstn               = 0;
        done_matching      = 0;
        CPU_orders_ready   = 0;
        top_level_tail_ptr = 8;
        num_orders_added   = 0;
        num_L2_requested   = 0;
        num_L1_evicted     = 0;
        num_cancelled      = 0;
        CPU_sim_ptr        = 0;
        for(int i = 0; i < num_incoming_orders; i++) begin
            cancelled_orders[i] = 0;
            new_orders[i*2]     = 0;
            new_orders[i*2+1]   = 0;
            CPU_orders[i]       = 0;
            L1_orders[i]        = 0;
        end
        for(int j = 0; j < 16; j++) begin
            CPU_sim[j] = 0;
        end
        @(posedge clk); #1;
        rstn          = 1;
        done_matching = 1;
        @(posedge clk); #1;
    endtask

    // -------------------------------------------------------------------------
    // Send tasks - n_requested = num_L2_requested, n_added = num_orders_added
    // -------------------------------------------------------------------------
    task send_orders(
        input logic [order_width-1:0] ord0, ord1, ord2, ord3, ord4,
        input logic [9:0] tail_ptr,
        input logic [$clog2(num_incoming_orders*2)-1:0] n_added,
        input logic [$clog2(num_incoming_orders)-1:0] n_requested
    );
        new_orders[0]      = ord0; 
        new_orders[1] = ord1;
        new_orders[2]      = ord2; 
        new_orders[3] = ord3;
        new_orders[4]      = ord4;
        top_level_tail_ptr = tail_ptr;
        num_orders_added   = n_added;
        num_L2_requested   = n_requested;
        done_matching      = 1;
        CPU_orders_ready   = 1;
        @(posedge clk); #1;
        done_matching    = 0;
        CPU_orders_ready = 0;
    endtask

    task send_orders_ofl1(
        input logic [order_width-1:0] ord0, ord1, ord2, ord3, ord4, ord5,
        input logic [9:0] tail_ptr,
        input logic [$clog2(num_incoming_orders*2)-1:0] n_added,
        input logic [$clog2(num_incoming_orders)-1:0] n_requested
    );
        new_orders[0]      = ord0; new_orders[1] = ord1;
        new_orders[2]      = ord2; new_orders[3] = ord3;
        new_orders[4]      = ord4;
        L1_orders[0] = ord5;
        top_level_tail_ptr = tail_ptr;
        num_orders_added   = n_added;
        num_L2_requested   = n_requested;
        num_L1_evicted = 1;
        done_matching      = 1;
        CPU_orders_ready   = 1;
        @(posedge clk); #1;
        done_matching    = 0;
        CPU_orders_ready = 0;
    endtask

    task send_orders_ofl2(
        input logic [order_width-1:0] ord0, ord1, ord2, ord3, ord4, ord5, ord6, ord7,
        input logic [9:0] tail_ptr,
        input logic [$clog2(num_incoming_orders*2)-1:0] n_added,
        input logic [$clog2(num_incoming_orders)-1:0] n_requested
    );
        new_orders[0]      = ord0; new_orders[1] = ord1;
        new_orders[2]      = ord2; new_orders[3] = ord3;
        new_orders[4]      = ord4;
        L1_orders[0] = ord5;
        L1_orders[1] = ord6;
        L1_orders[2] = ord7;
        top_level_tail_ptr = tail_ptr;
        num_orders_added   = n_added;
        num_L2_requested   = n_requested;
        num_L1_evicted = 3;
        done_matching      = 1;
        CPU_orders_ready   = 1;
        @(posedge clk); #1;
        done_matching    = 0;
        CPU_orders_ready = 0;
    endtask

    task send_orders_removal1(
        input logic [order_width-1:0] ord0, ord1, ord2, ord3,
        input logic [9:0] tail_ptr,
        input logic [$clog2(num_incoming_orders*2)-1:0] n_added,
        input logic [$clog2(num_incoming_orders)-1:0] n_requested
    );
        new_orders[0]      = ord0; new_orders[1] = ord1;
        new_orders[2]      = ord2; new_orders[3] = ord3;
        top_level_tail_ptr = tail_ptr;
        num_orders_added   = n_added;
        num_L2_requested   = n_requested;
        done_matching      = 1;
        CPU_orders_ready   = 1;
        @(posedge clk); #1;
        done_matching    = 0;
        CPU_orders_ready = 0;
    endtask

    task send_orders_removal2(
        input logic [order_width-1:0] ord0, ord1,
        input logic [9:0] tail_ptr,
        input logic [$clog2(num_incoming_orders*2)-1:0] n_added,
        input logic [$clog2(num_incoming_orders)-1:0] n_requested
    );
        new_orders[0]      = ord0; new_orders[1] = ord1;
        top_level_tail_ptr = tail_ptr;
        num_orders_added   = n_added;
        num_L2_requested   = n_requested;
        done_matching      = 1;
        CPU_orders_ready   = 1;
        @(posedge clk); #1;
        done_matching    = 0;
        CPU_orders_ready = 0;
    endtask

    // -------------------------------------------------------------------------
    // Test 1: No cancellations, simple back population
    // -------------------------------------------------------------------------
    task test1();
        $display("=== Test 1: Simple back population ===");
        do_reset();
        num_cancelled  = 0;
        num_L1_evicted = 0;
        for(int i = 0; i < 8; i++) begin
            send_orders(dut_new_orders[i*5], dut_new_orders[i*5+1],
                        dut_new_orders[i*5+2], dut_new_orders[i*5+3],
                        dut_new_orders[i*5+4], 5*i + 8, 5, 0);
        end
        @(posedge clk); #1;
        @(posedge clk); #1;
        $display("Test 1 PASSED");
    endtask

    // -------------------------------------------------------------------------
    // Test 2: Low overflow with L1 evictions feeding L2
    // -------------------------------------------------------------------------
    task test2();
        $display("=== Test 2: Low overflow via L1 evictions ===");
        do_reset();
        num_cancelled = 0;
        for(int i = 0; i < L1_capacity; i++) begin
            num_L1_evicted = !(!i);
            send_orders_ofl1(dut_new_orders[i*6], dut_new_orders[i*6+1],
                             dut_new_orders[i*6+2], dut_new_orders[i*6+3],
                             dut_new_orders[i*6+4], evicted_L1_orders[i],
                             6*i+8, 5, 0);
        end
        @(posedge clk); #1;
        @(posedge clk); #1;
        $display("Test 2 PASSED: evicted_orders[0] = %0h", evicted_orders[0]);
    endtask
    
    // -------------------------------------------------------------------------
    // Test 3: High overflow
    // -------------------------------------------------------------------------
    task test3();
        $display("=== Test 3: High overflow via L1 evictions ===");
        do_reset();
        num_cancelled = 0;
        for(int i = 0; i < L1_capacity; i++) begin
            send_orders_ofl2(dut_new_orders[i*6], dut_new_orders[i*6+1],
                             dut_new_orders[i*6+2], dut_new_orders[i*6+3],
                             dut_new_orders[i*6+4], evicted_L1_orders[3*i],
                             evicted_L1_orders[3*i+1], evicted_L1_orders[3*i+2],
                             8*i+8, 6, 0);
        end
        @(posedge clk); #1;
        @(posedge clk); #1;
        $display("Test 3 PASSED: evicted_orders[0] = %0h", evicted_orders[0]);
    endtask

    // -------------------------------------------------------------------------
    // Test 4: Low Overflow to full L2
    // -------------------------------------------------------------------------
    task test4();
        $display("=== Test 4: Low overflow via L1 evictions ===");
        do_reset();
        num_cancelled = 0;
        for(int i = 0; i < 8; i++) begin
            send_orders_ofl1(dut_new_orders[i*6], dut_new_orders[i*6+1],
                             dut_new_orders[i*6+2], dut_new_orders[i*6+3],
                             dut_new_orders[i*6+4], dut_L1_orders[i],
                             6*i+8, 5, 0);
        end
        @(posedge clk); #1;
        @(posedge clk); #1;
        $display("Test 4 PASSED: evicted_orders[0] = %0h", evicted_orders[0]);
    endtask
    
    // -------------------------------------------------------------------------
    // Test 5: High Overflow to full L2
    // -------------------------------------------------------------------------
    task test5();
        $display("=== Test 5: High overflow via L1 evictions ===");
        do_reset();
        num_cancelled = 0;
        for(int i = 0; i < 8; i++) begin
            send_orders_ofl2(dut_new_orders[i*6], dut_new_orders[i*6+1],
                             dut_new_orders[i*6+2], dut_new_orders[i*6+3],
                             dut_new_orders[i*6+4], evicted_L1_orders[3*i],
                             evicted_L1_orders[3*i+1], evicted_L1_orders[3*i+2],
                             8*i+8, 6, 0);
        end
        @(posedge clk); #1;
        @(posedge clk); #1;
        $display("Test 5 PASSED: evicted_orders[0] = %0h", evicted_orders[0]);
    endtask

    // -------------------------------------------------------------------------
    // Test 6: Simple cancellation, no overflow, only 1
    // -------------------------------------------------------------------------
    task test6();
        $display("=== Test 6: 1 cancellation ===");
        do_reset();
        num_L1_evicted = 0;
        for(int i = 0; i < L1_capacity/2; i++) begin
            send_orders(dut_new_orders[i*5], dut_new_orders[i*5+1],
                        dut_new_orders[i*5+2], dut_new_orders[i*5+3],
                        dut_new_orders[i*5+4], 5*i+8, 5, 0);
        end
        num_cancelled       = 1;
        cancelled_orders[0] = 1;
        CPU_orders[0]       = CPU_order_pool[0];
        CPU_orders_ready    = 1;
        done_matching       = 0;
        @(posedge clk); #1;
        CPU_orders_ready = 0;
        num_cancelled    = 0;
        @(posedge clk); #1;
        for(int i = L1_capacity/2; i < L1_capacity; i++) begin
            send_orders(dut_new_orders[i*5], dut_new_orders[i*5+1],
                        dut_new_orders[i*5+2], dut_new_orders[i*5+3],
                        dut_new_orders[i*5+4], 5, 0, 0);
        end
        $display("Test 5 PASSED");
    endtask

    // -------------------------------------------------------------------------
    // Test 7: Multiple cancellations, no overflow
    // -------------------------------------------------------------------------
    task test7();
        $display("=== Test 7: Multiple cancellations ===");
        do_reset();
        num_L1_evicted = 0;
        for(int i = 0; i < 4; i++) begin
            send_orders(dut_new_orders[i*5], dut_new_orders[i*5+1],
                        dut_new_orders[i*5+2], dut_new_orders[i*5+3],
                        dut_new_orders[i*5+4], 5*i+8, 5, 0);
        end
        num_cancelled       = 3;
        cancelled_orders[0] = 0;
        cancelled_orders[1] = 2;
        cancelled_orders[2] = 4;
        CPU_orders[0]       = CPU_order_pool[0];
        CPU_orders[1]       = CPU_order_pool[1];
        CPU_orders[2]       = CPU_order_pool[2];
        CPU_orders_ready    = 1;
        done_matching       = 0;
        @(posedge clk); #1;
        CPU_orders_ready = 0;
        num_cancelled    = 0;
        @(posedge clk); #1;
//        for(int i = L1_capacity/2; i < L1_capacity; i++) begin
//            send_orders(dut_new_orders[i*5], dut_new_orders[i*5+1],
//                        dut_new_orders[i*5+2], dut_new_orders[i*5+3],
//                        dut_new_orders[i*5+4], 5*i+8, 0, 0);
//        end
        $display("Test 7 PASSED");
    endtask

    // -------------------------------------------------------------------------
    // Test 8: Multiple repeated cancellations
    // -------------------------------------------------------------------------
    task test8();
        $display("=== Test 8: Multiple cancellations ===");
        do_reset();
        num_L1_evicted = 0;
        for(int i = 0; i < 4; i++) begin
            send_orders(dut_new_orders[i*5], dut_new_orders[i*5+1],
                        dut_new_orders[i*5+2], dut_new_orders[i*5+3],
                        dut_new_orders[i*5+4], 5*i+8, 5, 0);
        end
        num_cancelled       = 3;
        cancelled_orders[0] = 0;
        cancelled_orders[1] = 2;
        cancelled_orders[2] = 4;
        CPU_orders[0]       = CPU_order_pool[0];
        CPU_orders[1]       = CPU_order_pool[1];
        CPU_orders[2]       = CPU_order_pool[2];
        CPU_orders_ready    = 1;
        done_matching       = 0;
        @(posedge clk); #1;
        num_cancelled       = 2;
        cancelled_orders[0] = 0;
        cancelled_orders[1] = 1;
        cancelled_orders[2] = 0;
        CPU_orders[0]       = CPU_order_pool[3];
        CPU_orders[1]       = CPU_order_pool[4];
        CPU_orders_ready    = 1;
        done_matching       = 0;
        @(posedge clk); #1;
        @(posedge clk); #1;
        CPU_orders_ready = 0;
        num_cancelled    = 0;
        @(posedge clk); #1;
//        for(int i = L1_capacity/2; i < L1_capacity; i++) begin
//            send_orders(dut_new_orders[i*5], dut_new_orders[i*5+1],
//                        dut_new_orders[i*5+2], dut_new_orders[i*5+3],
//                        dut_new_orders[i*5+4], 5*i+8, 0, 0);
//        end
        $display("Test 8 PASSED");
    endtask

    // -------------------------------------------------------------------------
    // Test 9: Overflow with single cancellation
    // -------------------------------------------------------------------------
    task test9();
        $display("=== Test 9: Cancellation with overflow ===");
        do_reset();
        for(int i = 0; i < 8; i++) begin
            send_orders_ofl1(dut_new_orders[i*6], dut_new_orders[i*6+1],
                             dut_new_orders[i*6+2], dut_new_orders[i*6+3],
                             dut_new_orders[i*6+4], dut_L1_orders[i],
                             6*i+8, 5, 0);
        end
        num_cancelled       = 1;
        cancelled_orders[0] = 0;
        CPU_orders[0]       = CPU_sim[0];
        CPU_orders_ready    = 1;
        done_matching       = 0;
        @(posedge clk); #1;
        num_cancelled       = 1;
        cancelled_orders[0] = 3;
        CPU_orders[0]       = CPU_sim[1];
        CPU_orders_ready    = 1;
        done_matching       = 0;
        @(posedge clk); #1;
        CPU_orders_ready = 0;
        num_cancelled    = 0;
        @(posedge clk); #1;
//        for(int i = L1_capacity/2; i < L1_capacity; i++) begin
//            num_L1_evicted = 1;
//            send_orders_ofl1(dut_new_orders[i*6], dut_new_orders[i*6+1],
//                             dut_new_orders[i*6+2], dut_new_orders[i*6+3],
//                             dut_new_orders[i*6+4], dut_new_orders[i*6+5],
//                             i+5, 1, 0);
//        end
        $display("Test 9 PASSED");
    endtask

    // -------------------------------------------------------------------------
    // Test 10: Overflow with multiple cancellations
    // -------------------------------------------------------------------------
    task test10();
        $display("=== Test 10: Cancellation with overflow ===");
        do_reset();
        for(int i = 0; i < 8; i++) begin                                        
        send_orders_ofl2(dut_new_orders[i*6], dut_new_orders[i*6+1],        
                         dut_new_orders[i*6+2], dut_new_orders[i*6+3],      
                         dut_new_orders[i*6+4], evicted_L1_orders[3*i],     
                         evicted_L1_orders[3*i+1], evicted_L1_orders[3*i+2],
                         8*i+8, 6, 0);          
        end                            
        num_cancelled       = 3;
        cancelled_orders[0] = 0;
        cancelled_orders[1] = 2;
        cancelled_orders[2] = 4;
        CPU_orders[0]       = CPU_sim[0];
        CPU_orders[1]       = CPU_sim[1];
        CPU_orders[2]       = CPU_sim[2];
        CPU_orders_ready    = 1;
        done_matching       = 0;
        @(posedge clk); #1;
        cancelled_orders[0] = 0;
        cancelled_orders[1] = 1;
        cancelled_orders[2] = 0;
        CPU_orders[0]       = CPU_sim[3];
        CPU_orders[1]       = CPU_sim[4];
        CPU_orders_ready    = 1;
        done_matching       = 0;
        @(posedge clk); #1;
        CPU_orders_ready = 0;
        num_cancelled    = 0;
        @(posedge clk); #1;
//        for(int i = L1_capacity/2; i < L1_capacity; i++) begin
//            num_L1_evicted = 1;
//            send_orders_ofl1(dut_new_orders[i*6], dut_new_orders[i*6+1],
//                             dut_new_orders[i*6+2], dut_new_orders[i*6+3],
//                             dut_new_orders[i*6+4], dut_new_orders[i*6+5],
//                             i+5, 1, 0);
//        end
        $display("Test 10 PASSED");
    endtask

    // -------------------------------------------------------------------------
    // Test 11: L1 requests 1 order from L2 (SEND_L1 state)
    // -------------------------------------------------------------------------
    task test11();
        $display("=== Test 11: 1 L1 request ===");
        do_reset();
        num_cancelled  = 0;
        num_L1_evicted = 0;
        for(int i = 0; i < 8; i++) begin
            send_orders_ofl1(dut_new_orders[i*6], dut_new_orders[i*6+1],
                             dut_new_orders[i*6+2], dut_new_orders[i*6+3],
                             dut_new_orders[i*6+4], dut_L1_orders[i],
                             6*i+8, 5, 0);
        end
        num_L2_requested = 1;
        CPU_orders[0] = CPU_order_pool[0];
        @(posedge clk); #1;
        @(posedge clk); #1;
    endtask

    // -------------------------------------------------------------------------
    // Test 12: L1 requests multiple orders from L2
    // -------------------------------------------------------------------------
    task test12();
        $display("=== Test 10: Multiple L1 requests ===");
        do_reset();
        num_cancelled  = 0;
        num_L1_evicted = 0;
        for(int i = 0; i < 8; i++) begin
            send_orders_ofl1(dut_new_orders[i*6], dut_new_orders[i*6+1],
                             dut_new_orders[i*6+2], dut_new_orders[i*6+3],
                             dut_new_orders[i*6+4], dut_L1_orders[i],
                             6*i+8, 5, 0);
        end
        // Simulate L1 requesting 3 orders
        CPU_orders[0]    = CPU_order_pool[0];
        CPU_orders[1]    = CPU_order_pool[1];
        CPU_orders[2]    = CPU_order_pool[2];
        num_L2_requested = 3;
        @(posedge clk); #1;
        @(posedge clk); #1;
    endtask

    // -------------------------------------------------------------------------
    // Test 13: L1 requests multiple orders from L2 repeadetly
    // -------------------------------------------------------------------------
    task test13();
        $display("=== Test 13: Multiple L1 requests ===");
        do_reset();
        num_cancelled  = 0;
        num_L1_evicted = 0;
        for(int i = 0; i < 8; i++) begin
            send_orders_ofl1(dut_new_orders[i*6], dut_new_orders[i*6+1],
                             dut_new_orders[i*6+2], dut_new_orders[i*6+3],
                             dut_new_orders[i*6+4], dut_L1_orders[i],
                             6*i+8, 5, 0);
        end
        // Simulate L1 requesting 3 orders
        CPU_orders[0]    = CPU_order_pool[0];
        CPU_orders[1]    = CPU_order_pool[1];
        CPU_orders[2]    = CPU_order_pool[2];
        num_L2_requested = 3;
        @(posedge clk); #1;
        CPU_orders[0]    = CPU_order_pool[0];
        CPU_orders[1]    = CPU_order_pool[1];
        CPU_orders[2]    = 0;
        num_L2_requested = 2;
        @(posedge clk); #1;
        @(posedge clk); #1;
    endtask
    
    // -------------------------------------------------------------------------
    // Test 11: Low stress - mix of L1 evictions, cancels, and L1 requests
    // -------------------------------------------------------------------------
    task test14();
        $display("=== Test 13: Low stress mix of L1 evictions, cancels, L1 requests ===");
        do_reset();
        num_cancelled = 0;

        // Phase 1: Partially fill L2 with back insertions
        num_L1_evicted = 0;
        for(int i = 0; i < L1_capacity/2; i++) begin
            send_orders(dut_new_orders[i*5], dut_new_orders[i*5+1],
                        dut_new_orders[i*5+2], dut_new_orders[i*5+3],
                        dut_new_orders[i*5+4], i+4, 0, 0);
        end

        // Phase 2: Cancel 1 order, replace with CPU order
        num_cancelled       = 1;
        cancelled_orders[0] = 2;
        CPU_orders[0]       = CPU_order_pool[0];
        CPU_orders_ready    = 1;
        done_matching       = 0;
        @(posedge clk); #1;
        CPU_orders_ready = 0;
        num_cancelled    = 0;
        @(posedge clk); #1;

        // Phase 3: Fill remainder with L1 evictions causing mild overflow
        for(int i = L1_capacity/2; i < L1_capacity; i++) begin
            num_L1_evicted = 1;
            send_orders_ofl1(dut_new_orders[i*6], dut_new_orders[i*6+1],
                             dut_new_orders[i*6+2], dut_new_orders[i*6+3],
                             dut_new_orders[i*6+4], dut_new_orders[i*6+5],
                             4 + (i - L1_capacity/2), 1, 0);
        end

        // Phase 4: Cancel 2 orders simultaneously
        num_cancelled       = 2;
        cancelled_orders[0] = 1;
        cancelled_orders[1] = 3;
        CPU_orders[0]       = CPU_order_pool[1];
        CPU_orders[1]       = CPU_order_pool[2];
        CPU_orders_ready    = 1;
        done_matching       = 0;
        @(posedge clk); #1;
        CPU_orders_ready = 0;
        num_cancelled    = 0;
        @(posedge clk); #1;

        // Phase 5: L1 requests 1 order from L2, CPU replenishes L2
        CPU_orders[0]    = CPU_order_pool[3];
        CPU_orders_ready = 1;
        send_orders_removal1(dut_new_orders[L1_capacity*5],   dut_new_orders[L1_capacity*5+1],
                             dut_new_orders[L1_capacity*5+2], dut_new_orders[L1_capacity*5+3],
                             L1_capacity+4, 0, 1);
        @(posedge clk); #1;
        CPU_orders_ready = 0;

        // Phase 6: Cancel 1 more and add new L1 eviction simultaneously
        num_cancelled       = 1;
        cancelled_orders[0] = 0;
        CPU_orders[0]       = CPU_order_pool[4];
        num_L1_evicted      = 1;
        CPU_orders_ready    = 1;
        done_matching       = 1;
        new_orders[0]       = dut_new_orders[L1_capacity*5+4];
        new_orders[1]       = dut_new_orders[L1_capacity*5+5];
        top_level_tail_ptr  = L1_capacity+4;
        num_orders_added    = 1;
        @(posedge clk); #1;
        done_matching    = 0;
        CPU_orders_ready = 0;
        num_cancelled    = 0;
        num_L1_evicted   = 0;
        @(posedge clk); #1;

        // Phase 7: L1 requests 2 orders, CPU replenishes
        CPU_orders[0]    = CPU_order_pool[5];
        CPU_orders[1]    = CPU_order_pool[6];
        CPU_orders_ready = 1;
        send_orders_removal2(dut_new_orders[L1_capacity*5+6], dut_new_orders[L1_capacity*5+7],
                             L1_capacity+4, 0, 2);
        @(posedge clk); #1;
        CPU_orders_ready = 0;
        @(posedge clk); #1;

    endtask

    // -------------------------------------------------------------------------
    // Run all tests
    // -------------------------------------------------------------------------
    initial begin
//        test1();
//        test2();
//        test3();
//        test4();
//        test5();
//        test6();
//        test7();
//        test8();
//        test9();
//        test10();
//        test11();
//        test12();
        test13();
        $display("=== All tests complete ===");
        $finish;
    end

endmodule
