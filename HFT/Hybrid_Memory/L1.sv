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
    output logic [order_width-5:0] evicted_orders [num_incoming_orders],   // Evict orders to L2
    output logic L1_sorted // Send to matching engine
    );
    
    // Construct cache
    logic [order_width-5:0] orders [L1_capacity]; 
    logic [$clog2(L1_capacity)-1:0] pos [L1_capacity];  // pos[i] = entry location of order i
    logic [$clog2(num_incoming_orders)-1:0] canc_tally [L1_capacity];
    logic [$clog2(L1_capacity)-1:0] pos_queue [L1_capacity];
    logic [order_width-5:0] holding_buffer [num_incoming_orders]; // Additional bit to show if used
    logic [$clog2(num_incoming_orders)-1:0] num_holding;
    
    // State transition
    typedef enum logic [1:0] {
        IDLE,
        CANCEL,
        REMOVE,   
        ADD
    } state_t;
    state_t state, next_state;
    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    
    // Compute next stage
    always_comb begin
        if(state == IDLE) begin
            if(L2_orders_ready && (num_cancelled > 0)) begin
                next_state = CANCEL;
            end
            else if(done_matching && num_orders_removed > 0) begin
                next_state = REMOVE;
            end
            else if(done_matching) begin
                next_state = ADD;
            end
            else begin
                next_state = IDLE;
            end
            L1_sorted = 0;
        end
        else if(state == CANCEL) begin
            if(done_matching && num_orders_removed > 0) begin
                next_state = REMOVE;
            end
            else if(done_matching) begin
                next_state = ADD;
            end
            else if(L2_orders_ready && (num_cancelled > 0)) begin
                next_state = CANCEL;   // Can continue to cancel, not dependent on matching
            end
            else begin
                next_state = IDLE;
            end
            L1_sorted = 0;
        end
        else if(state == REMOVE) begin
            next_state = ADD;
        end
        else if(state == ADD) begin
            if(L2_orders_ready && (num_cancelled > 0)) begin
                next_state = CANCEL; 
            end
            else if(done_matching && num_orders_removed > 0) begin
                next_state = REMOVE;
            end
            else if(done_matching) begin
                next_state = ADD;
            end
            else begin
                next_state = IDLE; // Can't rematch unless cancels are done first
            end
            L1_sorted = 1;
        end
    end
    
    integer i,j,k,m,n;
    logic [$clog2(L1_capacity)-1:0] top_ptr, insert_ptr, temp_ptr, stop_idx, canc_count;
    logic [$clog2(L1_capacity+L2_capacity)-1:0] local_tail_ptr;
    logic L1_full, test;
    
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
                canc_tally[i] <= 0;
                evicted_orders[i] <= 0;
            end
            top_ptr <= 0;
            local_tail_ptr <= num_incoming_orders;
            i <= 0;
            j <= 0;
            m <= 0;
            test <= 0;
            insert_ptr <= num_incoming_orders;
            L1_full <= 0;
            canc_count <= 0;
        end
        else if(next_state == CANCEL) begin
            // Must perform cancellations first, independent of filling of orders
            // Produce neccessary meta info
            canc_count = 0;
            for(i = 0; i < L1_capacity; i = i + 1) begin
                if((i == cancelled_orders[canc_count]) || ((i+canc_count) == cancelled_orders[canc_count])) begin
                    canc_count = canc_count + 1;
                end
                canc_tally[i] = canc_count;
            end
            // Insert new orders
            for(j = 0; j < num_cancelled; j++) begin
                if(j < num_holding) begin
                    orders[pos[cancelled_orders[j]]] <= holding_buffer[j];
                    holding_buffer[j] <= 0;
                    num_holding <= num_holding - 1;
                end
                else begin
                    orders[pos[cancelled_orders[j]]] <= L2_orders[j - num_holding];
                end
                pos_queue[j] = pos[cancelled_orders[j]];
            end
            // Update positions
            if(L1_full) begin
                stop_idx = L1_capacity - 1;
            end
            else begin
                stop_idx = local_tail_ptr;
            end
            for(i = 0; i <= stop_idx - num_cancelled; i++) begin
                pos[i] <= pos[i + canc_tally[i]];
            end
            for(j = stop_idx - num_cancelled + 1; j <= stop_idx; j++) begin
                pos[j] <= pos_queue[j - (stop_idx - num_cancelled + 1)];
            end
        end
        else if(next_state == REMOVE) begin
            // Handle removal first, at most can remove orders we sent to engine
            for(m = 0; m <= num_orders_removed; m++) begin
                if(m < num_holding) begin
                    orders[m] = holding_buffer[m];
                    holding_buffer[m] = 0;
                    num_holding <= num_holding - 1;
                end
                else begin
                    orders[m] = L2_orders[m - num_holding];
                end
            end
            for(i = 0; i <= L1_capacity - num_orders_removed - 1; i++) begin
                pos[i] = pos[i + num_orders_removed];
            end
            for(j = L1_capacity - num_orders_removed; j < L1_capacity; j++) begin
                pos[j] = j - (L1_capacity - num_orders_removed);
            end
        end
        else if(next_state == ADD) begin
            // First handle incoming order
            local_tail_ptr = top_level_tail_ptr + num_orders_added; // Allow seperation for overflow orders
            top_ptr = 0;
            for(i = 0; i < num_incoming_orders*2; i++) begin
                if(new_orders[i][order_width-1 -: 3] == 3'b001) begin
                    if(new_orders[i][order_width-4]) begin  // Insert into top
                        if(top_ptr >= num_incoming_orders) begin // Can't insert into top_ptr, have to insert into evicted location
                            holding_buffer[top_ptr - num_incoming_orders] <= orders[pos[insert_ptr]];
                            orders[pos[insert_ptr]] <= new_orders[i][order_width-5:0];
                            // Should only do this when full, extremely inefficient
                            if(L1_full) begin
                                temp_ptr = pos[L1_capacity-1];
                                for(j = L1_capacity; j >= num_incoming_orders; j--) begin
                                    pos[j] = pos[j-1];
                                end
                                pos[num_incoming_orders] = temp_ptr;
                            end
                        end
                        else begin // Else can just replace previous
                            orders[pos[top_ptr]] <= new_orders[i][order_width-5:0]; // Disregard header info
                        end
                        top_ptr = top_ptr + 1;
                    end
                    else begin // Push to tail
                        orders[local_tail_ptr] <= new_orders[i][order_width-5:0]; // Account for new orders
                        holding_buffer[(local_tail_ptr - top_level_tail_ptr)] <= orders[pos[L1_capacity-1-(local_tail_ptr - top_level_tail_ptr)]];
                        local_tail_ptr = local_tail_ptr + 1;
                    end
                end
            end
            if(local_tail_ptr < L1_capacity-1) begin
                insert_ptr <= local_tail_ptr;
                L1_full <= 0;
            end
            else begin
                insert_ptr <= pos[L1_capacity-1];
                L1_full <= 1;
            end
            num_holding <= num_orders_added;
        end
     end
     
     // Send orders in holding buffer to L2 is not used
     always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            for(n = 0; n < num_incoming_orders; n++) begin
                holding_buffer[n] <= 0;
            end
        end
        for(n = 0; n < num_incoming_orders; n++) begin
            if(holding_buffer[n] == 0) begin
                evicted_orders[n] <= holding_buffer[n];
            end
        end
     end
endmodule
