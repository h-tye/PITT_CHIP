`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/22/2026 09:22:40 PM
// Design Name: 
// Module Name: Order_Dt_Enc
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


module Order_Dt_Enc #(
    parameter orders_generated = 4,
    parameter dynamic_fields = 4, // Side, Type, Price, Qty
    parameter price_bits = 32,
    parameter qty_bits = 16,
    parameter type_bits = 2, // Side bit, Order Type bit(Limit vs Market)
    parameter order_width = price_bits + qty_bits + type_bits,
    parameter max_message_size = 10, // Number of fields per message
    parameter max_delta = 16,  // Max difference between previous and current value = 2^16 = 64k
    parameter output_bits = (type_bits) * 8 + (max_delta / 7 + 1) * 8 * 2
    )(
    input clk,
    input rstn,
    input logic [type_bits+2*max_delta-1:0] encoded_values [orders_generated],
    input logic [$clog2(max_delta)-1:0] encoded_size [0:1][orders_generated],  // Size only needed for price/qty, 1 bit for others
    output logic [output_bits-1:0] dt_encoded_values [orders_generated]
    );
    
    
    genvar i;
    generate
        for(i = 0; i < orders_generated; i = i + 1) begin
            // SIDE
            int_enc #(.input_width(1)) S(
                .nullable(0),
                .encoded_size(1),
                .op_encoded_value(encoded_values[type_bits+2*max_delta-1][i]),
                .dt_encoded_value(dt_encoded_values[i][output_bits-1 -: 8])
            );
            
            // ORDER TYPE
            ascii_enc #(.input_width(1)) O(
                .nullable(0),
                .encoded_size(1),
                .op_encoded_value(encoded_values[type_bits+2*max_delta-2][i]),
                .dt_encoded_value(dt_encoded_values[i][output_bits-9 -: 8])
            );
            
            // PRICE
            deci_enc #(.input_width((max_delta / 7 + 1) * 8)) P(
                .nullable(0),
                .encoded_size(encoded_size[0][i]),
                .op_encoded_value(encoded_values[i][type_bits+2*max_delta-3 -: max_delta]),
                .dt_encoded_value(dt_encoded_values[i][output_bits-17 -: (max_delta / 7 + 1) * 8])
            );
            
            // QTY
            int_enc #(.input_width((max_delta / 7 + 1) * 8)) Q(
                .nullable(0),
                .encoded_size(encoded_size[1][i]),
                .op_encoded_value(encoded_values[i][type_bits+max_delta-3 -: 0]),
                .dt_encoded_value(dt_encoded_values[i][output_bits-1 -: 8])
            );
        end
    endgenerate
endmodule
