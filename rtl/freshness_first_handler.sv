module freshness_first_handler(
    input clk,
    input rst_n,

    input  logic        msg_valid,
    input  logic [31:0] sequence_num,
    input  logic [63:0] msg_data,

    output logic        out_valid,
    output logic [63:0] out_data,
    output logic        stale_drop
);
    
    logic [31:0] newest_sequence;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            newest_sequence <= 0;
            out_valid       <= 0;
            stale_drop      <= 0;
        end
        else begin
            out_valid <= 0;
            out_data  <= msg_data;

            if (msg_valid) begin
                if (sequence_num > newest_sequence) begin
                    newest_sequence <= sequence_num;
                    out_valid       <= 1;
                    stale_drop      <= 0;
                end
                else begin
                    stale_drop <= 1;
                end
            end
        end
    end
endmodule
