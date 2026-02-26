`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/23/2026 02:36:58 PM
// Design Name: 
// Module Name: FAST_Decoder
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


module FAST_Decoder #(
    parameter beat_width = 64,
    parameter max_message_size = 10,   // Max number of fields in a template
    parameter num_templates = 4,
    parameter ring_size = 16,
    parameter sup_paths = 4,  // Superscalar paths
    parameter num_messages = 1,
    parameter num_decoders = sup_paths*2,
    parameter template_field_size = 10,
    parameter field_op_size = 32,
    parameter messageID_size = 21
    )(
    input logic clk,
    input logic flush_FA,
    input logic flush_MEM,
    input logic flush_DEC,
    input logic flush_MES,
    input logic [beat_width-1:0] din,
    input logic rstn,
    output logic [messageID_size+$clog2(max_message_size):0] decoder_error,
    output logic [beat_width-1:0] ordered_messages [0:num_messages-1][0:max_message_size-1]
    );
    
    int k, j;
    
    // Field Aligner Out
    logic [beat_width+1:0] FA_douts [0:sup_paths-1];
    logic [sup_paths-1:0] FA_field_complete;
    logic [sup_paths-1:0] FA_field_valid;
    logic FA_new_message;
    
    // Memory Ctrl Out
    logic [$clog2(num_templates)-1:0] MEM_TID;
    logic [template_field_size-1:0] MEM_out_template [max_message_size];
    logic [beat_width-1:0] MEM_out_previous [max_message_size];
    
    // Decoder Out
    logic [$clog2(max_message_size)-1:0] DEC_message_field_count;
    logic [beat_width-1:0] DEC_replacement_field [0:sup_paths-1];
    logic [num_decoders/2-1:0] DEC_replace_field [0:sup_paths-1];
    logic [$clog2(max_message_size)-1:0] DEC_replace_field_idx [0:sup_paths-1];
    logic [field_op_size-1:0] DEC_field_ops_stream[num_decoders/2];
    logic [field_op_size-1:0] DEC_field_ops_prev[num_decoders/2];
    logic [messageID_size+$clog2(max_message_size)+beat_width:0] DEC_decoded_field_stream [0:num_decoders/2-1];
    logic [messageID_size+$clog2(max_message_size)+beat_width:0] DEC_decoded_field_prev [0:num_decoders/2-1];
    logic [messageID_size+$clog2(max_message_size):0] DEC_decoder_error [0:num_decoders-1];
    
    FieldAligner U1(
        .clk(clk),
        .rstn(rstn),
        .din(din),
        .message_field_count(DEC_message_field_count),
        .douts(FA_douts),
        .field_complete(FA_field_complete),
        .field_valid(FA_field_valid)
        );
        
     // Buffer 1
     reg [beat_width+1:0] douts_B1 [0:sup_paths-1];
     reg [sup_paths-1:0] field_complete_B1;
     reg [sup_paths-1:0] field_valid_B1;
     reg new_message_B1;
     always_ff @(negedge clk) begin
        if(flush_FA || ~rstn) begin
            for(k = 0; k < sup_paths; k = k + 1) begin
                douts_B1[k] <= 0;
                field_complete_B1[k] <= 0;
                field_valid_B1[k] <= 0;
            end
            new_message_B1 <= 0;
        end
        else begin
            for(k = 0; k < sup_paths; k = k + 1) begin
                douts_B1[k] <= FA_douts[k];
                field_complete_B1[k] <= FA_field_complete[k];
                field_valid_B1[k] <= FA_field_valid[k];
            end
            new_message_B1 <= FA_new_message;
        end
     end
     
     MemoryCtrl U2(
        .clk(clk),
        .rstn(rstn),
        .new_message(new_message_B1),
        .dins(douts_B1),
        .field_valids(field_valid_B1),
        .field_complete(field_complete_B1),
        .replacement_field(DEC_replacement_field),
        .replace_field(DEC_replace_field),
        .replace_field_idx(DEC_replace_field_idx),
        .TID(MEM_TID),
        .out_template(MEM_out_template),
        .out_previous(MEM_out_previous)
        );
        
    // Buffer 2
     reg [beat_width+1:0] douts_B2 [0:sup_paths-1];
     reg [sup_paths-1:0] field_complete_B2;
     reg [sup_paths-1:0] field_valid_B2;
     reg new_message_B2;
     reg [template_field_size-1:0] out_template_B2 [max_message_size];
     reg [$clog2(num_templates)-1:0] TID_B2;
     reg [beat_width-1:0] out_previous_B2 [max_message_size];
     always_ff @(negedge clk) begin
        if(flush_MEM || ~rstn) begin
            for(k = 0; k < sup_paths; k = k + 1) begin
                douts_B2[k] <= 0;
                field_complete_B2[k] <= 0;
                field_valid_B2[k] <= 0;
            end
            for(j = 0; j < max_message_size; k = k + 1) begin
                out_template_B2[j] <= 0;
                out_previous_B2[j] <= 0;
            end
            TID_B2 <= 0;
            new_message_B2 <= 0;
        end
        else begin
            for(k = 0; k < sup_paths; k = k + 1) begin
                douts_B2[k] <= douts_B1[k];
                field_complete_B2[k] <= douts_B1[k];
                field_valid_B2[k] <= field_valid_B1[k];
            end
            for(j = 0; j < max_message_size; k = k + 1) begin
                out_template_B2[j] <= MEM_out_template[j];
                out_previous_B2[j] <= MEM_out_previous[j];
            end
            TID_B2 <= MEM_TID;
            new_message_B2 <= new_message_B1;
        end
     end
        
        
    // Decoder controller module     
    DecoderCtrl U3a(
        .clk(clk),
        .rstn(rstn),
        .new_message(new_message_B2),
        .prev_decoders_done(),
        .template(out_template_B2),
        .dins(douts_B2),
        .field_valids(field_valid_B2),
        .field_complete(field_complete_B2),
        .TID(TID_B2),
        .field_ops_stream(DEC_field_ops_stream),
        .field_ops_prev(DEC_field_ops_prev),
        .fields_finished(DEC_message_field_count)  // Send to FA
        );
        
    // Decoder modules, superscalar
    genvar i;
    generate
        for(i = 0; i < num_decoders/2; i = i + 1) begin
            Decoder D(
               .clk(clk),
               .rstn(rstn),
               .field_ops(DEC_field_ops_stream[i]),
               .dins(douts_B2[i]),
               .field_valids(field_valid_B2),
               .field_complete(field_complete_B2),
               .decoderID(i),
               .decoded_field(DEC_decoded_field_stream[i]),
               .decoder_error(DEC_decoder_error[i])
            );
            
            PrevDecoder PD(
               .clk(clk),
               .rstn(rstn),
               .field_ops(DEC_field_ops_stream[i]),
               .dins(douts_B2[i]),
               .field_complete(field_complete_B2),
               .decoded_field(DEC_decoded_field_prev[i]),
               .decoder_error(DEC_decoder_error[i])
            );
        end
    endgenerate
    
    // Format for writing back to previous values
    WriteBack U3b(
        .decoded_field_stream(DEC_decoded_field_stream),
        .replace_field(DEC_replace_field),
        .replacement_field(DEC_replacement_field),
        .replace_field_idx(DEC_replace_field_idx)
        );
        
    
    // Report error
    always_comb begin
        for(k = 0; k < num_decoders; k = k + 1) begin
            if(DEC_decoder_error[k][messageID_size+$clog2(max_message_size)]) begin
                decoder_error = DEC_decoder_error[k];
            end
        end
    end
    
    // Buffer 3 + FIFO
    MessageFIFO_Ctrl U4(
        .clk(clk),
        .rstn(rstn),
        .decoded_fields({DEC_decoded_field_stream, DEC_decoded_field_prev}),
        .ordered_messages(ordered_messages)
        );
    
        
        
endmodule
