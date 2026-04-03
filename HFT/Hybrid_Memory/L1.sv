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
    parameter num_orders = 1 // Only 1 for now
    )(
    input logic clk,
    input logic rstn,
    input logic PoI,   // Pull or Insert. 0 to pull from L2(fill). 1 to insert new orders(kill)
    input logic [$clog2(num_orders)-1:0] orders_filled,
    input logic [$clog2(num_orders)-1:0] inserted_orders,
    input logic [order_width-1:0] incoming_orders [num_orders],  // Mux between external and L2
    output logic [order_width-1:0] evicted_orders [num_orders]
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
            if(!PoI) begin
                for(i = 0; i < L1_capacity; i = i + 1) begin
                    // If filled, adjust pos and insert L2 data
                    if(pos[i] <= orders_filled) begin
                        orders[i] <= incoming_orders[orders_filled - pos[i]];
                        pos[i] <= (L1_capacity - orders_filled) + pos[i]; 
                        filled[i] <= 0;
                    end
                    else begin
                        pos[i] <= pos[i] - orders_filled;
                    end
                 end
             end
             else begin
                for(i = 0; i < L1_capacity; i = i + 1) begin
                    // Evict bottom orders
                    if(pos[i] > L1_capacity - inserted_orders) begin
                        orders[i] <= incoming_orders[pos[i] - (L1_capacity - inserted_orders)];
                        pos[i] <= pos[i] - (L1_capacity - inserted_orders);
                        filled[i] <= 0;
                        evicted_orders[pos[i] - (L1_capacity - inserted_orders)] <= orders[i];
                    end
                    else begin
                        pos[i] <= pos[i] + inserted_orders;
                    end
                 end
             end
         end
     end
endmodule
