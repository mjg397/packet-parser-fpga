module ethernet_parser_axis_tb #(
    parameter int unsigned DATA_WIDTH   = 64,
    parameter int unsigned OFFSET_WIDTH = 16,
    localparam int unsigned KEEP_WIDTH  = DATA_WIDTH / 8
) (
    input  logic                    clk,
    input  logic                    rst,

    input  logic [DATA_WIDTH-1:0]   s_axis_tdata,
    input  logic [KEEP_WIDTH-1:0]   s_axis_tkeep,
    input  logic                    s_axis_tvalid,
    output logic                    s_axis_tready,
    input  logic                    s_axis_tlast,

    output logic [47:0]             dst_mac,
    output logic [47:0]             src_mac,
    output logic [15:0]             ether_type,
    output logic                    header_valid,
    output logic                    header_error
);

    logic axis_fire;
    logic in_packet;

    logic [OFFSET_WIDTH-1:0] packet_offset;
    logic                    packet_start;
    logic                    packet_end;

    /*
     * The parser is always able to consume input in this first version.
     */
    assign s_axis_tready = 1'b1;

    assign axis_fire = s_axis_tvalid && s_axis_tready;

    /*
     * These describe the beat being accepted on the current edge.
     */
    assign packet_start = axis_fire && !in_packet;
    assign packet_end   = axis_fire && s_axis_tlast;

    /*
     * packet_offset is the byte position of lane zero of the current beat.
     *
     * For DATA_WIDTH = 64:
     *   0, 8, 16, 24, ...
     */
    always_ff @(posedge clk) begin
        if (rst) begin
            packet_offset <= '0;
            in_packet      <= 1'b0;
        end else if (axis_fire) begin
            if (s_axis_tlast) begin
                packet_offset <= '0;
                in_packet      <= 1'b0;
            end else begin
                packet_offset <= packet_offset + KEEP_WIDTH;
                in_packet      <= 1'b1;
            end
        end
    end

    ethernet_parser #(
        .DATA_WIDTH   (DATA_WIDTH),
        .OFFSET_WIDTH (OFFSET_WIDTH)
    ) dut (
        .clk           (clk),
        .rst           (rst),

        .data          (s_axis_tdata),
        .keep          (s_axis_tkeep),
        .beat_valid    (axis_fire),
        .packet_offset (packet_offset),
        .packet_start  (packet_start),
        .packet_end    (packet_end),

        .dst_mac       (dst_mac),
        .src_mac       (src_mac),
        .ether_type    (ether_type),
        .header_valid  (header_valid),
        .header_error  (header_error)
    );

endmodule