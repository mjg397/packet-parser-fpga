module packet_parser #(
    parameter int unsigned MAX_FRAME_BYTES = 1518
)(
    input  logic        clk,
    input  logic        rst_n,

    // AXI-Stream input
    input  logic [63:0] s_axis_tdata,
    input  logic [7:0]  s_axis_tkeep,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,
    input  logic        s_axis_tlast,

    // Ethernet parser outputs
    output logic [47:0] eth_dst_mac,
    output logic [47:0] eth_src_mac,
    output logic [15:0] eth_type,
    output logic        eth_valid,

    // IPv4 parser outputs
    output logic [3:0]  ip_version,
    output logic [3:0]  ip_ihl,
    output logic [15:0] ip_total_length,
    output logic [7:0]  ip_protocol,
    output logic [31:0] ip_src_addr,
    output logic [31:0] ip_dst_addr,
    output logic [15:0] ip_checksum,
    output logic        ipv4_valid,

    // UDP parser outputs
    output logic [15:0] udp_src_port,
    output logic [15:0] udp_dst_port,
    output logic [15:0] udp_length,
    output logic [15:0] udp_checksum,
    output logic        udp_valid,

    // Message parser outputs
    output logic [7:0]  msg_type,
    output logic [7:0]  msg_flags,
    output logic [15:0] source_id,
    output logic [31:0] sequence_num,
    output logic [63:0] timestamp,

    output logic [31:0] data_a,
    output logic [31:0] data_b,
    output logic [31:0] data_c,
    output logic [31:0] status,

    output logic        message_meta_valid,
    output logic        message_valid,

    // Freshness filter outputs
    output logic        fresh_valid,
    output logic [63:0] fresh_data,
    output logic        stale_drop
);

    // -------------------------------------------------------------------------
    // AXI handshake
    // -------------------------------------------------------------------------

    logic beatfire;

    assign s_axis_tready = 1'b1;
    assign beatfire = s_axis_tvalid && s_axis_tready;


    // -------------------------------------------------------------------------
    // Beat counter
    //
    // 64-bit AXI = 8 bytes per beat.
    // 1518 bytes / 8 bytes ~= 190 beats, so 8 bits is enough.
    // -------------------------------------------------------------------------

    logic [7:0] beat_index;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            beat_index <= 0;
        end
        else if (beatfire) begin
            if (s_axis_tlast)
                beat_index <= 0;
            else
                beat_index <= beat_index + 1'b1;
        end
    end


    // -------------------------------------------------------------------------
    // Frame FSM
    // -------------------------------------------------------------------------

    typedef enum logic [1:0] {
        IDLE,
        PARSE_FRAME,
        DROP_FRAME
    } state_t;

    state_t state, next_state;


    always_ff @(posedge clk) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end


    always_comb begin
        next_state = state;

        case (state)

            IDLE: begin
                if (beatfire && !s_axis_tlast)
                    next_state = PARSE_FRAME;
            end

            PARSE_FRAME: begin
                if (beatfire && s_axis_tlast)
                    next_state = IDLE;

                // Later:
                // if (invalid_packet)
                //     next_state = DROP_FRAME;
            end

            DROP_FRAME: begin
                if (beatfire && s_axis_tlast)
                    next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end

        endcase
    end


    // -------------------------------------------------------------------------
    // Ethernet parser
    // -------------------------------------------------------------------------

    ethernet_parser ethernet_parser_inst (
        .clk         (clk),
        .rst_n       (rst_n),

        .beat_valid  (beatfire),
        .beat_index  (beat_index),
        .data        (s_axis_tdata),

        .eth_dst_mac (eth_dst_mac),
        .eth_src_mac (eth_src_mac),
        .eth_type    (eth_type),
        .eth_valid   (eth_valid)
    );


    // -------------------------------------------------------------------------
    // IPv4 parser
    // -------------------------------------------------------------------------

    ipv4_parser ipv4_parser_inst (
        .clk             (clk),
        .rst_n           (rst_n),

        .beat_valid      (beatfire),
        .beat_index      (beat_index),
        .data            (s_axis_tdata),

        .eth_type        (eth_type),
        .eth_valid       (eth_valid),

        .ip_version      (ip_version),
        .ip_ihl          (ip_ihl),
        .ip_total_length (ip_total_length),
        .ip_protocol     (ip_protocol),
        .ip_src_addr     (ip_src_addr),
        .ip_dst_addr     (ip_dst_addr),
        .ip_checksum     (ip_checksum),
        .ipv4_valid      (ipv4_valid)
    );


    // -------------------------------------------------------------------------
    // UDP parser
    // -------------------------------------------------------------------------

    udp_parser udp_parser_inst (
        .clk          (clk),
        .rst_n        (rst_n),

        .beat_valid   (beatfire),
        .beat_index   (beat_index),
        .data         (s_axis_tdata),

        .ip_ihl       (ip_ihl),
        .ip_protocol  (ip_protocol),
        .ipv4_valid   (ipv4_valid),

        .udp_src_port (udp_src_port),
        .udp_dst_port (udp_dst_port),
        .udp_length   (udp_length),
        .udp_checksum (udp_checksum),

        .udp_valid    (udp_valid)
    );


    // -------------------------------------------------------------------------
    // Application message parser
    // -------------------------------------------------------------------------

    message_parser message_parser_inst (
        .clk                (clk),
        .rst_n              (rst_n),

        .beat_valid         (beatfire),
        .beat_index         (beat_index),
        .data               (s_axis_tdata),

        .ip_ihl             (ip_ihl),
        .udp_valid          (udp_valid),

        .msg_type           (msg_type),
        .flags              (msg_flags),
        .source_id          (source_id),
        .sequence_num       (sequence_num),

        .timestamp          (timestamp),

        .data_a             (data_a),
        .data_b             (data_b),
        .data_c             (data_c),
        .status             (status),

        .message_meta_valid (message_meta_valid),
        .message_valid      (message_valid)
    );


    // -------------------------------------------------------------------------
    // Freshness-first filter
    // -------------------------------------------------------------------------

    freshness_first_handler freshness_first_handler_inst (
        .clk          (clk),
        .rst_n        (rst_n),

        .msg_valid    (message_valid),
        .sequence_num (sequence_num),

        // Temporary choice for first version:
        .msg_data     ({data_a, data_b}),

        .out_valid    (fresh_valid),
        .out_data     (fresh_data),
        .stale_drop   (stale_drop)
    );

endmodule

// module packet_parser #(
//     parameter int unsigned MAX_FRAME_BYTES = 1518
// )(
//     input logic clk,
//     input logic rst_n,

//     // Post-MAC Ethernet streaming data
//     input  logic [63:0] s_axis_tdata,
//     input  logic [7:0]  s_axis_tkeep,
//     input  logic        s_axis_tvalid,
//     output logic        s_axis_tready,
//     input  logic        s_axis_tvalid,

//     output logic [47:0] eth_dst_mac,
//     output logic [47:0] eth_src_mac,
//     output logic [15:0] eth_type,
//     output logic        eth_valid,

//     output logic [3:0]  ip_version,
//     output logic [3:0]  ip_ihl,
//     output logic [15:0] ip_total_length,
//     output logic [7:0]  ip_protocol,
//     output logic [31:0] ip_src_addr,
//     output logic [31:0] ip_dst_addr,
//     output logic [15:0] ip_checksum,
//     output logic        ipv4_valid,

//     output logic [15:0] udp_src_port,
//     output logic [15:0] udp_dst_port,
//     output logic [15:0] udp_length,
//     output logic [15:0] udp_checksum,
//     output logic udp_valid

//     output logic m_axis_tdata,
//     output logic m_axis_tkeep,

//     // Ethernet parser output
//     output logic [47:0] eth_dst_mac,
//     output logic [47:0] eth_src_mac,
//     output logic [15:0] eth_type,
//     output logic        eth_valid,

//     // Ipv4 parser output
//     output logic version;
//     output logic ihl;
//     output logic dscp;
//     output logic ecn;

//     uint16_t total_length;
//     uint16_t identification;

//     uint8_t flags;
//     uint16_t fragment_offset;

//     uint8_t ttl;
//     uint8_t protocol;
//     uint16_t header_checksum;

//     std::array<uint8_t, 4> source_ip;
//     std::array<uint8_t, 4> destination_ip;

//     std::vector<uint8_t> options;

//     // UDP parser output
//     output logic [15:0] udp_src_port,
//     output logic [15:0] udp_dst_port,
//     output logic [15:0] udp_length,
//     output logic        udp_valid,
// );
    
//     // max size is 1518 bytes, whichi s ~24 transfers or 5 bits
//     packet_offset[4:0]

//     // beatfire records whenever a new AXIS beat arrives with data
//     logic beatfire;
//     assign beatfire = s_axis_tready && s_axis_tvalid;

//     // count the packet offset in terms of bits
//     localparam int unsigned OFFSET_WIDTH = $clog(MAX_FRAME_BYTES+1);

//     logic [OFFSET_WIDTH-1:0] packet_offset;
//     always_ff @(posedge clk) begin
//         if (!rst_n) begin
//             packet_offset <= 0;
//         end else begin
//             if (s_axis_tlast)
//                 packet_offset <= 0;
//             if (beatfire)
//                 packet_offset <= packet_offset + 8;
//         end
//     end



//     // Define FSM states
//     typedef enum logic [1:0] {
//         IDLE,
//         PARSE_FRAME,
//         DROP_FRAME
//     } state_t;

//     state_t state; next_state;

//     // Current state register
//     always_ff @(posedge clk) begin
//         if (!rst_n) begin
//             state <= IDLE;
//         end else begin
//             state <= next_state;
//         end
//     end

//     // Next state and output logic
//     always_comb begin
//         next_state = state;
//         //set some others here


//         case(state)
//             IDLE : begin
//                 next_state = (beatfire) ? PARSE_FRAME : IDLE;

//             end


//             PARSE_FRAME : begin

//             end

//             DROP : begin
//                 next_state <= 
//             end
//         endcase
//     end


//     ethernet_parser(
//         .clk(clk),
//         .rst_n(rst_n),

//         .beat_valid(),
//         .beat_index(),
//         .data(),

//         .eth_dst_mac(),
//         .eth_src_mac(),
//         .eth_type(),
//         .eth_valid()
//     );

//     module ipv4_parser(
//     input logic clk,
//     input logic rst_n,

//     input logic        beat_valid,
//     input logic [4:0]  beat_index,
//     input logic [63:0] data,

//     input logic [15:0] eth_type,
//     input logic        eth_valid,

//     output logic [3:0] ip_version,
//     output logic [3:0] ip_ihl,

//     output logic [15:0] ip_total_length,
//     output logic [7:0]  ip_protocol,

//     output logic [31:0] ip_src_addr,
//     output logic [31:0] ip_dst_addr,

//     output logic [15:0] ip_checksum,

//     output logic        ipv4_valid
// );


//     udp_parser(
//         .clk()
//         .rst_n()

//         .beat_valid()
//         .beat_index()
//         .data()

//         .ip_ihl()
//         .ip_protocol()
//         .ipv4_valid()

//         .udp_src_port()
//         .udp_dst_port()
//         .udp_lengtgh()
//         .udp_checksum()

//         .udp_valid()
//     );
    
//     module message_parser (
//     input  logic        clk,
//     input  logic        rst_n,

//     input  logic        beat_valid,
//     input  logic [4:0]  beat_index,
//     input  logic [63:0] data,

//     input  logic [3:0]  ip_ihl,
//     input  logic        udp_valid,

//     output logic [7:0]  msg_type,
//     output logic [7:0]  flags,
//     output logic [15:0] source_id,
//     output logic [31:0] sequence_num,

//     output logic [63:0] timestamp,

//     output logic [31:0] data_a,
//     output logic [31:0] data_b,
//     output logic [31:0] data_c,
//     output logic [31:0] status,

//     output logic        message_meta_valid,
//     output logic        message_valid
// );

//     freshness_first_handler(
//     input clk,
//     input rst_n,

//     input  logic        msg_valid;
//     input  logic [31:0] sequence_num;
//     input  logic [63:0] msg_data;

//     output logic        out_valid;
//     output logic [63:0] out_data;
//     output logic        stale_drop;
// );

// endmodule
