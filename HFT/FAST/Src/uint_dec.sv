module fast_uint_decoder #(
    parameter MAX_BYTES = 10,  // max bytes in a FAST field (up to 10 for uint64)
    parameter OUT_WIDTH = 64
)(
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic [MAX_BYTES-1:0][7:0]  msg_bytes,    // input bytes (MSB first)
    input  logic [$clog2(MAX_BYTES):0] byte_count,   // number of valid bytes
    input  logic                       nullable,      // is this field nullable?

    output logic                       valid_out,
    output logic [OUT_WIDTH-1:0]       value,
    output logic                       is_null
);

    // -------------------------------------------------------------------------
    // Step 1: Find length by stop bit
    //   The stop bit is bit[7] of each byte. The LAST byte has stop bit = 1.
    // -------------------------------------------------------------------------
    logic [$clog2(MAX_BYTES):0] field_len;
    always_comb begin
        field_len = '0;
        for (int i = 0; i < MAX_BYTES; i++) begin
            if (i < byte_count && field_len == '0) begin
                if (msg_bytes[i][7]) begin
                    field_len = i[$clog2(MAX_BYTES):0] + 1;
                end
            end
        end
    end

    // -------------------------------------------------------------------------
    // Step 2: Remove stop bit from each byte → extract 7-bit data words
    // -------------------------------------------------------------------------
    logic [MAX_BYTES-1:0][6:0] data_words;
    always_comb begin
        for (int i = 0; i < MAX_BYTES; i++) begin
            data_words[i] = msg_bytes[i][6:0];  // strip bit[7] (stop bit)
        end
    end

    // -------------------------------------------------------------------------
    // Step 3: Null detection & value adjustment
    //   - Nullable unsigned int: value 0x00 (single byte 0x80) → NULL
    //     All non-null values are decremented by 1.
    //   - Non-nullable: no adjustment, no null possible.
    //   - Combine 7-bit words big-endian to form the actual integer.
    // -------------------------------------------------------------------------
    logic [OUT_WIDTH-1:0] raw_value;
    logic                 raw_is_null;

    always_comb begin
        // Combine 7-bit words (big-endian, first byte is most significant)
        raw_value = '0;
        for (int i = 0; i < MAX_BYTES; i++) begin
            if (i < field_len) begin
                raw_value = (raw_value << 7) | {{(OUT_WIDTH-7){1'b0}}, data_words[i]};
            end
        end

        // Null detection
        if (nullable && field_len == 1 && data_words[0] == 7'h00) begin
            raw_is_null = 1'b1;
        end else begin
            raw_is_null = 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // Output register
    // -------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 1'b0;
            value     <= '0;
            is_null   <= 1'b0;
        end else if (valid_in) begin
            valid_out <= 1'b1;
            is_null   <= raw_is_null;
            // Nullable non-null values are decremented by 1
            if (nullable && !raw_is_null)
                value <= raw_value - 1'b1;
            else
                value <= raw_value;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
