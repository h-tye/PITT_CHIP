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
    parameter timestamp_bits = 32,
    parameter orderID_bits = 16,
    parameter price_bits = 16,
    parameter qty_bits = 16,
    parameter order_width = timestamp_bits + orderID_bits + price_bits + qty_bits,
    parameter num_incoming_orders = 1 // Only 1 for now
    )(
    input logic clk,
    input logic rstn,
    input logic AoR, // Net negative orders -> remove orders from L1. Net positive orders -> add to L1, mutually exclusive
    input logic [$clog2(num_incoming_orders)-1:0] num_orders, // Num orders to remove or to add(only based on fill, not cancelled)
    input logic [$clog2(num_incoming_orders)-1:0] num_cancelled,
    input logic [$clog2(L1_capacity)-1:0] cancelled_positions [num_incoming_orders], // positions of cancelled orders
    input logic [order_width-1:0] incoming_orders [num_incoming_orders],  // Read incoming or L2
    output logic [order_width-1:0] evicted_orders [num_incoming_orders]   // Evict orders to L2
    );
    
    // Construct cache
    logic [order_width-1:0] orders [L1_capacity]; 
    logic [$clog2(L1_capacity)-1:0] pos [L1_capacity];
    logic [L1_capacity-1:0] filled;
    
    integer i;
    integer count;
    always_ff @(posedge clk or negedge rstn) begin
        if(!rstn) begin
            for(i = 0; i < L1_capacity; i = i + 1) begin
                orders[i] <= 0;
                pos[i] <= i;
                filled[i] <= 0;
            end
        end
        else begin
            // Must perform cancellations first
            for(i = 0; i < num_incoming_orders; i = i + 1) begin
                if(cancelled_positions[i] == pos[i]) begin
                    orders[cancelled_positions[i]] <= incoming_orders[count];
                    pos[i] <= L1_capacity - (num_cancelled - count); // Send to back of queue  
                    filled[i] <= 0;
                    count = count + 1;
                 end
                 else begin
                    pos[i] <= pos[i] - count;
                 end
            end
            if(AoR) begin  // Remove orders
                for(i = 0; i < L1_capacity; i = i + 1) begin
                    // If filled, adjust pos and insert L2 data
                    if(pos[i] <= num_orders) begin
                        orders[i] <= incoming_orders[num_cancelled + pos[i]];
                        pos[i] <= (L1_capacity - num_orders) + pos[i]; 
                        filled[i] <= 0;
                    end
                    else begin
                        pos[i] <= pos[i] - num_orders;
                    end
                 end
             end
             else begin
                for(i = 0; i < L1_capacity; i = i + 1) begin
                    // Evict bottom orders
                    if(pos[i] > L1_capacity - num_orders) begin
                        orders[i] <= incoming_orders[pos[i] - (L1_capacity - num_orders) + num_cancelled];
                        pos[i] <= pos[i] - (L1_capacity - num_orders);
                        filled[i] <= 0;
                        evicted_orders[pos[i] - (L1_capacity - num_orders)] <= orders[i];
                    end 
                    else begin
                        pos[i] <= pos[i] + num_orders;
                    end
                 end
             end
         end
     end
endmodule
