`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/09/2026 11:15:43 PM
// Design Name: 
// Module Name: FieldAligner
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


module FieldAligner #(
    parameter beat_width = 64,
    parameter ring_size = 16
    )(
    input logic clk,
    input logic [beat_width-1:0] din,
    input logic rstn,
    output logic [ring_size-1:0] next_FIFO_en,
    output logic [ring_size-1:0] dout [ring_size-1:0]
    );
    
    // Stop & start ptr calc
    reg [ring_size-1:0] stop_ptr;
    logic [ring_size-1:0] stop_bits;
    reg [7:0] ring_buffer [0:ring_size-1];
    integer k;
    always_comb begin   // Extract stop bits
        for(k = 0; k < ring_size/2; k = k + 1) begin
            stop_bits[k] = din[(k*8)-1];
        end
    end 
    
    //Store din
    logic top_full;
    always_ff @(posedge clk) begin
        if(~rstn) begin
            for(k = 0; k < ring_size; k = k + 1) begin
                    ring_buffer[k] <= 0;
                    stop_ptr[k] <= 0;
            end
        end
        else
            if(~top_full) begin
                for(k = 0; k < ring_size/2; k = k + 1) begin
                    ring_buffer[k] <= din[((k+1)*8)-1 -: 8];
                end
                top_full <= 1;
            end
            else begin
                for(k = ring_size/2; k < ring_size; k = k + 1) begin
                    ring_buffer[k] <= din[((k+1)*8)-1 -: 8];
                end
                top_full <= 0;
            end
    end
    assign dout = ring_buffer; // Assign full buffer to dout, invalid fields will be ignored by stop_ptrs
    
    genvar g;
    generate
        for (g = 0; g < ring_size; g++) begin : GEN_STOP
            always_ff @(posedge clk) begin
                if (g == ring_size-1)
                    stop_ptr[g] <= stop_bits[g]; 
                else
                    stop_ptr[g] <= ~(|stop_bits[ring_size-1:g+1]);  // Stop ptr is 1 only if rest of stop bits are 0s -> field is incomplete
            end
        end
    endgenerate
    assign next_FIFO_en = stop_ptr;

endmodule
