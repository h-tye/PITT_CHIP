`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/03/2026 05:21:59 PM
// Design Name: 
// Module Name: L1
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


module L1 #(
    parameter L1_capacity = 8,
    parameter L2_capacity = 120,
    parameter timestamp_bits = 32,
    parameter orderID_bits = 16,
    parameter price_bits = 16,
    parameter qty_bits = 16,
    parameter order_locations = 3,  // L1, L2, or CPU
    parameter FoB = 1,              // Insert/remove from front or back
    parameter order_width = order_locations + FoB + timestamp_bits + orderID_bits + price_bits + qty_bits,
    parameter num_incoming_orders = 1 // Only 1 for now
    )(
    input logic clk,
    input logic rstn,
    input logic done_matching,
    input logic L2_orders_ready,
    input logic [$clog2(L1_capacity + L2_capacity)-1:0] top_level_tail_ptr,  // Last position within top price level
    input logic [$clog2(num_incoming_orders*2)-1:0] num_orders_added,   // Num orders to add
    input logic [$clog2(num_incoming_orders*2)-1:0] num_orders_removed, // Num orders to remove due to matching
    input logic [$clog2(num_incoming_orders)-1:0] num_cancelled,
    input logic [$clog2(L1_capacity + L2_capacity)-1:0] cancelled_orders [num_incoming_orders], // Cancelled order numbers
    input logic [order_width-1:0] new_orders [num_incoming_orders*2],  // Read incoming new orders
    input logic [order_width-5:0] L2_orders [num_incoming_orders],     // Top of L2 orders
    output logic [order_width-5:0] top_orders [num_incoming_orders],   // To matching engine
    output logic [order_width-1:0] evicted_orders [num_incoming_orders],   // Evict orders to L2
    output logic L1_sorted // Send to matching engine
    );
    
    // Construct cache
    logic [order_width-5:0] orders [L1_capacity]; 
    logic [$clog2(L1_capacity)-1:0] pos [L1_capacity];  // pos[i] = entry location of order i
    logic [$clog2(L1_capacity)-1:0] pos_queue [L1_capacity];
    
    // State transition
    typedef enum logic [1:0] {
        RST,
        CANCEL,
        IDLE,     
        ADD_REMOVE
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
    
    // Compute next stage
    always_comb begin
        if(state == RST) begin
            if(!rstn) begin
                next_state = RST;
            end
            else begin
                next_state = CANCEL;
            end
            L1_sorted = 0;
        end
        else if(state == CANCEL) begin
            if(done_matching) begin
                next_state = ADD_REMOVE;
            end
            else if(L2_orders_ready) begin
                next_state = CANCEL;   // Can continue to cancel, not dependent on matching
            end
            else begin
                next_state = IDLE;
            end
            L1_sorted = 0;
        end
        else if(state == ADD_REMOVE) begin
            if(L2_orders_ready) begin
                next_state = CANCEL; 
            end
            else begin
                next_state = IDLE; // Can't rematch unless cancels are done first
            end
            L1_sorted = 1;
        end
    end
    
    integer i,j,k;
    logic [$clog2(num_incoming_orders)-1:0] can_count;
    logic [$clog2(L1_capacity)-1:0] top_ptr, insert_ptr;
    logic [$clog2(L1_capacity+L2_capacity)-1:0] local_tail_ptr;
    logic test;
    
    // Send top of OB to matching engine
    always_comb begin
        for(k = 0; k < num_incoming_orders; k++) begin
            top_orders[j] = orders[k];
        end
    end
    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            for(i = 0; i < L1_capacity; i = i + 1) begin
                orders[i] <= 0;
                pos[i] <= i;
                pos_queue[i] <= 0;
            end
            can_count <= 0;
            top_ptr <= 0;
            local_tail_ptr <= num_incoming_orders;
            i <= 0;
            j <= 0;
            test <= 0;
            insert_ptr <= num_incoming_orders;
        end
        else if(next_state == CANCEL) begin
            // Must perform cancellations first, independent of filling of orders
            for(j = 0; j < num_cancelled; j++) begin
                orders[pos[cancelled_orders[j]]] <= L2_orders[j];
            end
            can_count = 0;
            // Update positions
            for(j = L1_capacity - 1; j >= 0; j--) begin
                if(j >= L1_capacity - num_cancelled) begin
                    pos_queue[can_count] = pos[j-can_count];
                    pos[j] = pos[cancelled_orders[num_cancelled-(can_count+1)]]; // Push cancelled to back of queue
                    can_count = can_count + 1;
                end
                else if(can_count > 0) begin
                    pos[j] = pos_queue[num_cancelled-can_count];
                    can_count = can_count -1;
                end
            end
        end
        else if(next_state == ADD_REMOVE) begin
            if(local_tail_ptr < L1_capacity) begin
                insert_ptr = local_tail_ptr;
            end
            else begin
                insert_ptr = pos[L1_capacity-1];
            end
            local_tail_ptr = top_level_tail_ptr + num_orders_added;
            top_ptr = 0;
            // First handle incoming order
            for(i = 0; i < num_incoming_orders*2; i++) begin
                if(new_orders[i][order_width-1 -: 3] == 3'b001) begin
                    if(new_orders[i][order_width-4]) begin  // Insert into top
                        if(top_ptr >= num_incoming_orders) begin // Can't insert into top_ptr, have to insert into evicted location
                            evicted_orders[top_ptr - num_incoming_orders] <= orders[pos[insert_ptr]];
                            orders[pos[insert_ptr]] <= new_orders[i][order_width-5:0];
                            // Have to update positions, same approach as cancel: ring
//                            for(j = 0; j < L1_capacity - num_incoming_orders; j++) begin
//                                pos[insert_ptr - i] = pos[insert_ptr - i - 1];
//                            end
//                            pos[num_incoming_orders] = insert_ptr;
//                            insert_ptr = pos[insert_ptr - 1];
                        end
                        else begin // Else can just replace previous
                            orders[pos[top_ptr]] <= new_orders[i][order_width-5:0]; // Disregard header info
                        end
                        top_ptr = top_ptr + 1;
                    end
                    else begin // Push to tail
                        orders[local_tail_ptr] <= new_orders[i][order_width-5:0]; // Account for new orders
                        evicted_orders[(local_tail_ptr - top_level_tail_ptr)] <= orders[pos[L1_capacity-1-(local_tail_ptr - top_level_tail_ptr)]];
                        local_tail_ptr = local_tail_ptr + 1;
                    end
                end
            end
            // Handle removal, at most can remove orders we sent to engine
            for(i= L1_capacity - num_orders_removed; i < L1_capacity;i++) begin
                orders[pos[i]] <= L2_orders[i+num_cancelled]; // Account for L2 used to fill in cancelled
                pos[i] = pos[i + num_orders_removed];
            end
        end
     end
endmodule
