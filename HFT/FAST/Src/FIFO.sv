module FIFO #(
    parameter FIFO_size = 16,
    parameter width = 72
)(
    input  logic clk,
    input  logic clear,
    input  logic read,
    input  logic write,
    input  logic [width-1:0] d_in,
    output logic [width-1:0] d_out,
    output logic full,
    output logic empty
);

    reg [width-1:0] memory [0:FIFO_size-1];
    reg [$clog2(FIFO_size)-1:0] read_ptr, write_ptr;
    reg [$clog2(FIFO_size):0] valid;  

    always_ff @(negedge clk or posedge clear) begin
        if (clear) begin
            read_ptr  <= 0;
            write_ptr <= 0;
            valid     <= 0;
        end else begin
            if (write && valid < FIFO_size) begin
                memory[write_ptr] <= d_in;
                write_ptr <= (write_ptr == FIFO_size-1) ? 0 : write_ptr + 1;
            end
            if (read && valid > 0) begin
                d_out <= memory[read_ptr];
                read_ptr <= (read_ptr == FIFO_size-1) ? 0 : read_ptr + 1;
            end
            case ({write && valid<FIFO_size, read && valid>0})
                2'b10: valid <= valid + 1;  // write only
                2'b01: valid <= valid - 1;  // read only
                2'b11: valid <= valid;      // read & write cancel out
            endcase
        end
    end

    assign full  = (valid == FIFO_size);
    assign empty = (valid == 0);

endmodule
