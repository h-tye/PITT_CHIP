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


module L2 #(
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
    input logic [$clog2(L1_capacity + L2_capacity)-1:0] top_level_tail_ptr,  // Last position within top price level
    input logic [$clog2(num_incoming_orders*2)-1:0] num_orders_added,   // Num orders to add
    input logic [$clog2(num_incoming_orders*2)-1:0] num_orders_removed, // Num orders to remove due to matching
    input logic [$clog2(num_incoming_orders)-1:0] num_cancelled,
    input logic [$clog2(L1_capacity)-1:0] cancelled_orders [num_incoming_orders], // Cancelled order numbers
    input logic [order_width-1:0] new_orders [num_incoming_orders*2],  // Read incoming new orders(from matching & L1 overflow)
    input logic [order_width-1:0] CPU_orders [num_incoming_orders],
    output logic [order_width-1:0] evicted_orders_L1 [num_incoming_orders],
    output logic L2_orders_ready,
    output logic [order_width-1:0] evicted_orders_CPU [num_incoming_orders]   // Evict orders to CPU
    );
    
    // Construct cache
    logic [order_width-5:0] orders [L2_capacity]; 
    logic [$clog2(L1_capacity)-1:0] pos [L2_capacity];  // pos[i] = entry location of order i
    logic [$clog2(L1_capacity)-1:0] pos_queue [L2_capacity];
    
    // State transition
    typedef enum logic [2:0] {
        RST,
        L1_CANCEL,
        L2_CANCEL,     
        ADD_REMOVE,
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
    
    // Compute next stage
    always_comb begin
        if(state == RST) begin
            if(!rstn) begin
                next_state = RST;
            end
            else begin
                next_state = L1_CANCEL;
            end
        end
        else if(state == L1_CANCEL) begin
            next_state = L2_CANCEL;   
        end
        else if(state == L2_CANCEL) begin
            if(done_matching) begin
                next_state = ADD_REMOVE; 
            end
            else begin
                next_state = IDLE; // Can't rematch unless cancels are done first
            end
        end
        else if(state == ADD_REMOVE) begin
            next_state = L1_CANCEL;
        end
        else if(state == IDLE) begin
            if(done_matching) begin
                next_state = ADD_REMOVE;
            end
            else begin
                next_state = IDLE;
            end
        end
    end
    
    integer i,j,k;
    integer can_count, top_ptr, local_tail_ptr;
    integer L1_count;
    always_ff @(posedge clk or negedge rstn) begin
        if(state == RST) begin
            for(i = 0; i < L2_capacity; i = i + 1) begin
                orders[i] <= 0;
                pos[i] <= i;
            end
        end
        else if(state == L1_CANCEL) begin
            // Perform L1 cancels first, L1 requires highest priority
            L1_count = 0;
            for(j = 0; j < num_cancelled; j++) begin
                if(cancelled_orders[j] < L1_capacity) begin
                    // Send top up & move in data from CPU
                    evicted_orders_L1[L1_count] <= orders[pos[L1_count]];  
                    orders[pos[L1_count]] <= CPU_orders[L1_count];  
                    L1_count = L1_count + 1;                                           
                end
            end
            // Update positions
            for(i = 0; i < L2_capacity - L1_count; i++) begin
                pos[i] <= pos[i + L1_count]; // Shift up
            end
            for(i = L2_capacity - L1_count; i < L2_capacity; i++) begin
                pos[i] <= pos[i - (L2_capacity - L1_count)]; // Wrap around
            end
            L2_orders_ready <= 1; // Signal to L1
        end
        else if(state == L2_CANCEL) begin
            // Only begin once positions are updated for L1
            // Perform cancel of L2 orders
            for(j = 0; j < num_cancelled; j++) begin
                orders[pos[cancelled_orders[j]]] <= CPU_orders[j];
            end
            can_count = 0;
            // Update positions
            for(j = L2_capacity - 1; j >= 0; j--) begin
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
        else if(state == ADD_REMOVE) begin
            top_ptr = 0;
            local_tail_ptr = top_level_tail_ptr + num_orders_added;
            // First handle incoming order
            for(i = 0; i < num_incoming_orders*2; i++) begin
                if(new_orders[i][order_width-1 -: 3] == 3'b010) begin
                    if(new_orders[i][order_width-4]) begin  // Insert into top
                        if(top_ptr >= num_incoming_orders) begin // Can't insert into top_ptr, have to insert into evicted location
                            evicted_orders_CPU[top_ptr - num_incoming_orders] <= orders[pos[L2_capacity-1-(top_ptr-num_incoming_orders)]];
                            orders[pos[L2_capacity-1-(top_ptr-num_incoming_orders)]] <= new_orders[i][order_width-5:0];
                        end
                        else begin // Else can just replace previous
                            orders[pos[top_ptr]] <= new_orders[i][order_width-5:0]; // Disregard header info
                        end
                    end
                    else begin
                        orders[local_tail_ptr] <= new_orders[i][order_width-5:0]; // Account for new orders
                        evicted_orders_CPU[(local_tail_ptr - top_level_tail_ptr)] <= orders[pos[L2_capacity-1-(local_tail_ptr - top_level_tail_ptr)]];
                        local_tail_ptr = local_tail_ptr + 1;
                    end
                    top_ptr = top_ptr + 1;
                end
            end
            
            // Handle removal, at most can remove orders we sent to engine
            for(i = L2_capacity - num_orders_removed; i < L2_capacity;i++) begin
                orders[pos[i]] <= CPU_orders[i+num_cancelled]; // Account for L2 used to fill in cancelled
                pos[i] = pos[i + num_orders_removed];
            end
        end
     end
endmodule
