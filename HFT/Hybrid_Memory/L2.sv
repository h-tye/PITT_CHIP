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
    input logic CPU_orders_ready,
    input logic [$clog2(num_incoming_orders)-1:0] num_L2_requested, // Will be for next cycle
    input logic [$clog2(num_incoming_orders)-1:0] num_L1_evicted,   // Num orders to add from L1
    input logic [$clog2(num_incoming_orders*2)-1:0] num_orders_added,   // Num orders to add from new
    input logic [9:0] top_level_tail_ptr,  // Last position within top price level
    input logic [$clog2(num_incoming_orders)-1:0] num_cancelled,
    input logic [$clog2(L1_capacity+L2_capacity)-1:0] cancelled_orders [num_incoming_orders], // Cancelled order numbers
    input logic [order_width-1:0] L1_orders [num_incoming_orders],
    input logic [order_width-1:0] new_orders [num_incoming_orders*2],  // Read incoming new orders(from matching & L1 overflow)
    input logic [order_width-1:0] CPU_orders [num_incoming_orders],
    output logic [order_width-1:0] orders_to_L1 [num_incoming_orders],
    output logic L2_orders_ready,
    output logic [order_width-1:0] evicted_orders [num_incoming_orders],   // Evict orders to CPU
    output logic [$clog2(num_incoming_orders)-1:0] num_CPU_requested, // Will be for next cycle
    output logic [$clog2(num_incoming_orders)-1:0] num_L2_evicted
    );
    
    // Construct cache
    logic [order_width-5:0] orders [L2_capacity]; 
    logic [$clog2(L2_capacity)-1:0] pos [L2_capacity];  // pos[i] = entry location of order i
    logic [$clog2(L2_capacity)-1:0] pos_queue [L2_capacity];
    logic [$clog2(num_incoming_orders)-1:0] canc_tally [L2_capacity];
    
    // State transition
    typedef enum logic [2:0] {
        IDLE,
        SERVICE_L1, 
        CANCEL,   
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
            if(num_L2_requested > 0) begin
                next_state = SERVICE_L1;  // Occurs if L1 orders filled or cancelled, highest priority
            end
            else if(num_cancelled > 0) begin
                next_state = CANCEL;
            end
            else if(done_matching || (num_L1_evicted > 0)) begin
                next_state = ADD;
            end
            else begin
                next_state = IDLE;
            end
        end
        else if(state == SERVICE_L1) begin
            if(num_L2_requested > 0) begin
                next_state = SERVICE_L1;
            end
            else if(num_cancelled > 0) begin
                next_state = CANCEL;
            end
            else if(done_matching || (num_L1_evicted > 0)) begin
                next_state = ADD;
            end
            else begin
                next_state = IDLE;
            end
        end
        else if(state == CANCEL) begin
            if(done_matching || (num_L1_evicted > 0)) begin
                next_state = ADD;
            end
            else if(num_L2_requested > 0) begin
                next_state = SERVICE_L1;
            end
            else if(num_cancelled > 0) begin
                next_state = CANCEL;
            end
            else begin
                next_state = IDLE;
            end
        end
        else if(state == ADD) begin
            if(num_L2_requested > 0) begin
                next_state = SERVICE_L1;
            end
            else if(CPU_orders_ready && (num_cancelled > 0)) begin
                next_state = CANCEL; 
            end
            else if(done_matching) begin
                next_state = ADD;
            end
            else begin
                next_state = IDLE; // Can't rematch unless cancels are done first
            end
        end
    end
    
    integer i,j,k,m,n;
    logic [$clog2(L2_capacity)-1:0] top_ptr, temp_ptr, stop_idx, canc_count, insert_ptr;
    logic [9:0] local_tail_ptr;
    logic L2_full, test;
    
    // Send top of OB to matching engine
    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            for(i = 0; i < L2_capacity; i = i + 1) begin
                orders[i] <= 0;
                pos[i] <= i;
                pos_queue[i] <= 0;
                canc_tally[i] <= 0;
                evicted_orders[i] <= 0;
            end
            top_ptr <= 0;
            local_tail_ptr <= 0;
            i <= 0;
            j <= 0;
            m <= 0;
            test <= 0;
            insert_ptr <= 0;
            L2_full <= 0;
            canc_count <= 0;
            num_L2_evicted <= 0;
            num_CPU_requested <= 0;
        end
        else if(next_state == SERVICE_L1) begin
            num_CPU_requested <= num_L2_requested;
            num_L2_evicted <= num_L1_evicted;
            for(m = 0; m < num_L2_requested; m++) begin
                orders_to_L1[m] <= orders[pos[m]];
                orders[pos[m]] <= CPU_orders[m];
            end
            for(i = 0; i <= L2_capacity - num_L2_requested - 1; i++) begin
                pos[i] = pos[i + num_L2_requested];
            end
            for(j = L2_capacity - num_L2_requested; j < L2_capacity; j++) begin
                pos[j] = j - (L2_capacity - num_L2_requested);
            end

        end
        else if(next_state == CANCEL) begin
            // Must perform cancellations first, independent of filling of orders
            // Produce neccessary meta info
            num_L2_evicted <= 0;
            num_CPU_requested <= num_cancelled;
            canc_count = 0;
            for(i = 0; i < L2_capacity; i = i + 1) begin
                if((i == cancelled_orders[canc_count]) || ((i+canc_count) == cancelled_orders[canc_count])) begin
                    canc_count = canc_count + 1;
                    if(((i+canc_count) == cancelled_orders[canc_count])) begin
                        canc_count = canc_count + 1;
                    end
                end
                canc_tally[i] = canc_count;
            end
            // Insert new orders
            for(j = 0; j < num_cancelled; j++) begin
                orders[pos[cancelled_orders[j]]] <= CPU_orders[j];
                pos_queue[j] = pos[cancelled_orders[j]];
            end
            // Update positions
            if(L2_full) begin
                stop_idx = L2_capacity - 1;
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
        else if(next_state == ADD) begin
            // First handle incoming order
            if(L2_full) begin
                num_L2_evicted <= num_orders_added + num_L1_evicted;
            end
            else begin
                num_L2_evicted <= 0;
            end
            if(top_level_tail_ptr < L1_capacity) begin
                local_tail_ptr = num_L1_evicted;
            end 
            else begin
                local_tail_ptr = top_level_tail_ptr - L1_capacity + num_L1_evicted;
            end
            
            // Insert L1 orders first
            num_CPU_requested <= 0; 
            // If L2 full, can no longer push to tail, only to front
            if(L2_full) begin
                for(j = 0; j < num_L1_evicted;j++) begin 
                    evicted_orders[j] <= orders[insert_ptr - num_L1_evicted + j + 1];
                    orders[insert_ptr - num_L1_evicted + j + 1] <= L1_orders[j];
                end  
                for(m = L2_capacity - num_L1_evicted; m < L2_capacity; m++) begin
                    pos[m - (L2_capacity - num_L1_evicted)] <= pos[m];
                end
                for(m = num_L1_evicted; m < L2_capacity; m++) begin
                    pos[m] <= pos[m - num_L1_evicted];
                end
            end
            else begin
                for(j = 0; j < num_L1_evicted;j++) begin
                    orders[insert_ptr + j] <= L1_orders[j];
                end  
                // Can check incoming for L2
                for(i = 0; i < num_incoming_orders*2; i++) begin
                    if(new_orders[i][order_width-1 -: 3] == 3'b010) begin
                        orders[local_tail_ptr] <= new_orders[i][order_width-5:0];
                        evicted_orders[(local_tail_ptr - top_level_tail_ptr)] <= orders[pos[L2_capacity-1-(local_tail_ptr - top_level_tail_ptr)]];
                        local_tail_ptr = local_tail_ptr + 1;
                    end
                end
                for(m = num_L1_evicted; m < insert_ptr + num_L1_evicted; m++) begin
                    pos[m] <= pos[m-num_L1_evicted];
                end
                for(m = 0; m < num_L1_evicted; m++) begin
                    pos[m] <= insert_ptr + m;
                end
            end
            
            if(local_tail_ptr < L2_capacity-1) begin
                insert_ptr <= pos[local_tail_ptr];
                L2_full <= 0;
            end
            else begin
                insert_ptr <= pos[L2_capacity-1];
                L2_full <= 1;
            end
        end
     end
endmodule
