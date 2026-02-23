`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/12/2026 08:18:54 PM
// Design Name: 
// Module Name: Decoder
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


module Decoder #(
    parameter beat_width = 64,
    parameter num_templates = 4,
    parameter sup_paths = 4,
    parameter template_field_size = 10, // Assume 10 bits of template info per field(datatype, operator, optional, pmap, field num)
    parameter max_message_size = 10,  // Max number of fields per template
    parameter field_op_size = 32,   // Assume 32 bits for ops per field
    parameter messageID_size = 21,
    parameter tail_size = 4
    )(
    input logic clk,
    input logic rstn,
    input logic [field_op_size-1:0] field_ops,
    input logic [beat_width+1:0] dins [sup_paths],
    input logic [sup_paths-1:0] field_valids,
    input logic [sup_paths-1:0] field_complete,
    input logic [$clog2(sup_paths)-1:0] decoderID,
    output logic [1+messageID_size+$clog2(max_message_size)+beat_width:0] decoded_field, // Valid, MessageID, Field Num, Field Value
    output logic [messageID_size+$clog2(max_message_size):0] decoder_error // Produce error with messageID and field num
    );
    
    logic [beat_width-1:0] Tail_Overflow [tail_size-1:0];
    logic [beat_width-1:0] din, ofl_out, datatype_out, op_in;
    logic [beat_width-1:0] int_out, uint_out, deci_out, ascii_out;
    logic [beat_width-1:0] noop_out, const_out, copy_out, default_out, delta_out, inc_out, tail_out; 
    logic datatype_done, ofl_read, ofl_full, ofl_empty, dt_full, dt_empty, error, rearrange_field;
    logic [$clog2(sup_paths)-1:0] read_field;
    
    // Dynamic scheduling of data
    int k,j,count;
    always_comb begin
        for(k = 0; k < sup_paths; k = k + 1) begin
            if(k == read_field) begin
                din = dins[k];
            end
        end
    end
    always_ff @(posedge clk) begin
        if(!rstn) begin
            for(k = 0; k < sup_paths; k = k + 1) begin
                read_field[k] <= k;
            end
        end
        else begin
            for(k = sup_paths-1; k >= 0; k = k + 1) begin
                if(!field_complete[k] && field_valids[k]) begin
                    read_field[k] <= 0;
                    rearrange_field <= 1;
                    count = 1;
                end
                if(rearrange_field) begin
                    read_field[k] <= count;
                    count <= count + 1;
                end
            end
        end
    end
    
    // FIFO for incomplete fields
    FIFO #(
        .FIFO_size(4),  // Overflow of 4 beats = 32 bytes
        .width(beat_width)
    ) OverFlow (
        .clk(!clk),
        .clear(rstn),
        .read(ofl_read),
        .write(1),
        .d_in(din),
        .d_out(ofl_out),
        .full(ofl_full),
        .empty(ofl_empty)
    );
          
    // Data type decoding
    Int_Decoder D1 (
        .din(din),
        .dout(int_out),
        .done(datatype_done)
    );
    UInt_Decoder D2 (
        .din(din),
        .dout(uint_out),
        .done(datatype_done)
    );
    Deci_Decoder D3 (
        .din(din),
        .dout(deci_out),
        .done(datatype_done)
    );
    ASCII_Decoder D4 (
        .din(din),
        .dout(ascii_out),
        .done(datatype_done)
    );
    
    // Mux the data type
    always_comb begin
        if(field_ops[1:0] == 0) begin
            datatype_out = int_out;
        end
        else if(field_ops[1:0] == 1) begin
            datatype_out = uint_out;
        end
        else if(field_ops[1:0] == 2) begin
            datatype_out = deci_out;
        end
        else begin
            datatype_out = ascii_out;
        end
        
        if(field_valids[read_field]) begin
            ofl_read = 1; 
        end
        else begin
            ofl_read = 0; // Store if full field not ready yet
        end
    end
    
    // Subpipeline buffer
    FIFO #(
        .FIFO_size(4),  
        .width(beat_width)
    ) DataType_Buffer (
        .clk(!clk),
        .clear(rstn),
        .read(1),
        .write(1),
        .d_in(datatype_out),
        .d_out(op_in),
        .full(dt_full),
        .empty(dt_empty)
    );
    
    // Operator decoding
    NoOp_Decoder O0 (
        .din(op_in),
        .dout(noop_out),
        .error(error)
    );
    Const_Decoder O1 (
        .din(op_in),
        .dout(const_out),
        .error(error)
    );
    Copy_Decoder O2 (
        .din(op_in),
        .dout(copy_out),
        .error(error)
    );
    Default_Decoder O3 (
        .din(op_in),
        .dout(default_out),
        .error(error)
    );
    Delta_Decoder O4 (
        .din(datatype_out),
        .dout(delta_out),
        .error(error)
    );
    Inc_Decoder O5 (
        .din(op_in),
        .dout(inc_out),
        .error(error)
    );
    Tail_Decoder O6 (
        .din(op_in),
        .dout(tail_out),
        .error(error)
    );
    
    // Decoder error, report 
    always_comb begin
        if(ofl_full || ofl_empty) begin
            decoder_error[messageID_size+$clog2(max_message_size)] = 1;
            decoder_error[messageID_size+$clog2(max_message_size)-1 -: messageID_size] = field_ops[field_op_size-1 : field_op_size-20];
            decoder_error[$clog2(max_message_size)-1 : 0] = field_ops[$clog2(max_message_size)+5:6];
        end
        else begin
            decoder_error = 0;
        end
    end
    
    // Mux the operator 
    always_comb begin   // assign payload
        if(field_ops[4:2] == 0) begin
            decoded_field[beat_width-1:0] = noop_out;
        end
        else if(field_ops[4:2] == 1) begin
            decoded_field[beat_width-1:0] = const_out;
        end
        else if(field_ops[4:2] == 2) begin
            decoded_field[beat_width-1:0] = copy_out;
        end
        else if(field_ops[4:2] == 3) begin
            decoded_field[beat_width-1:0] = default_out;
        end
        else if(field_ops[4:2] == 4) begin
            decoded_field[beat_width-1:0] = delta_out;
        end
        else if(field_ops[4:2] == 5) begin
            decoded_field[beat_width-1:0] = inc_out;
        end
        else if(field_ops[4:2] == 6) begin
            decoded_field[beat_width-1:0] = tail_out;
        end
        
        decoded_field[beat_width+$clog2(max_message_size)-1:beat_width] = field_ops[$clog2(max_message_size)+5:6];   // append field num & message num
        decoded_field[beat_width+$clog2(max_message_size)+20 : beat_width+$clog2(max_message_size)-1] = field_ops[field_op_size-1 : field_op_size-20];
    end
       
    
    
endmodule
