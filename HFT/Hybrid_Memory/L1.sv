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
    input logic [$clog2(L1_capacity + L2_capacity)-1:0] top_level_tail_ptr,  // Last position within top price level
    input logic [$clog2(num_incoming_orders*2)-1:0] num_orders_added,   // Num orders to add
    input logic [$clog2(num_incoming_orders*2)-1:0] num_orders_removed, // Num orders to remove due to matching
    input logic [$clog2(num_incoming_orders)-1:0] num_cancelled,
    input logic [$clog2(L1_capacity)-1:0] cancelled_orders [num_incoming_orders], // Cancelled order numbers
    input logic [order_width-1:0] new_orders [num_incoming_orders*2],  // Read incoming new orders
    input logic [order_width-5:0] L2_orders [num_incoming_orders],     // Top of L2 orders
    output logic [order_width-1:0] evicted_orders [num_incoming_orders]   // Evict orders to L2
    );
    
    // Construct cache
    logic [order_width-5:0] orders [L1_capacity]; 
    logic [$clog2(L1_capacity)-1:0] pos [L1_capacity];  // pos[i] = entry location of order i
    logic [$clog2(L1_capacity)-1:0] temp_pos;
    
    integer i,j;
    integer count, count1;
    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            for(i = 0; i < L1_capacity; i = i + 1) begin
                orders[i] <= 0;
                pos[i] <= i;
            end
        end
        else begin
            // Must perform cancellations first, independent of filling of orders
            for(j = 0; j < num_cancelled; j++) begin
                orders[pos[cancelled_orders[j]]] <= L2_orders[j];
            end
            count = 0;
            count1 = 0;
            // Update positions
            for(j = L1_capacity - 1; j >= 0; j--) begin
                if(count < num_cancelled) begin  // Perform swap -> See notes
                    temp_pos = pos[j];
                    pos[j] = pos[cancelled_orders[num_cancelled-count+1]];
                    count = count + 1;
                    pos[pos[j]] = temp_pos;
                end
            end
            
            
            L1_top_ptr = 0; // Initialize to 0
            local_tail_ptr = top_level_tail_ptr;
            if(done_matching) begin  // Add or remove orders to/from order book based on matching
                for(i = 0; i < num_incoming_orders*2; i++) begin
                    if(new_orders[i][order_width-1 -: 3] == 3'b001) begin
                        if(new_orders[order_width-4]) begin  // Insert into top
                            orders[L1_top_ptr] <= new_orders[i][order_width-5:0]; // Disregard header info
                            L1_top_ptr = L1_top_ptr + 1;
                        end
                        else begin
                            orders[local_tail_ptr] <= new_orders[i][order_width-5:0];
                            local_tail_ptr = local_tail_ptr + 1;
                        end
                    end
                    //Handle eviction
                    if(L1_top_ptr >= num_incoming_orders || 
                end
            end
        end
     end
endmodule
