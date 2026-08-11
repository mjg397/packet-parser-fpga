
module packet_parser #(
    parameter int unsigned MAX_FRAME_BYTES; 
)(
    input logic clk,
    input logic rst_n,

    // Post-MAC Ethernet streaming data
    input  logic [63:0] s_axis_tdata,
    input  logic [7:0]  s_axis_tkeep,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,
    input  logic        s_axis_tvalid,

    //
 // max size is 1518 bytes, whichi s ~24 transfers or 5 bits
packet_offset[4:0]

    output logic m_axis_tdata,
    output logic m_axis_tkeep,

    // Ethernet parser output
    output logic [47:0] eth_dst_mac,
    output logic [47:0] eth_src_mac,
    output logic [15:0] eth_type,
    output logic        eth_valid,

    // Ipv4 parser output
    output logic version;
    output logic ihl;
    output logic dscp;
    output logic ecn;

    uint16_t total_length;
    uint16_t identification;

    uint8_t flags;
    uint16_t fragment_offset;

    uint8_t ttl;
    uint8_t protocol;
    uint16_t header_checksum;

    std::array<uint8_t, 4> source_ip;
    std::array<uint8_t, 4> destination_ip;

    std::vector<uint8_t> options;

    // UDP parser output
    output logic [15:0] udp_src_port,
    output logic [15:0] udp_dst_port,
    output logic [15:0] udp_length,
    output logic        udp_valid,
);
    
    // beatfire records whenever a new AXIS beat arrives with data
    logic beatfire;
    assign beatfire = s_axis_tready && s_axis_tvalid;

    // count the packet offset in terms of bits
    localparam int unsigned OFFSET_WIDTH = $clog(MAX_FRAME_BYTES+1);

    logic [OFFSET_WIDTH-1:0] packet_offset;
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            packet_offset <= 0;
        end else begin
            if (s_axis_tlast)
                packet_offset <= 0;
            if (beatfire)
                packet_offset <= packet_offset + 8;
        end
    end



    // Define FSM states
    typedef enum logic [1:0] {
        IDLE,
        PARSE_FRAME,
        DROP_FRAME
    } state_t;

    state_t state; next_state;

    // Current state register
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always_comb begin
        next_state = state;
        //set some others here


        case(state)
            IDLE : begin


            end




            DROP : begin

            end
        endcase
    end


    ethernet_parser (
        data
        packet_offset
    );


    ipv4_parser (
        data
        packet_offset
    );


    udp_parser (
        data
        packet_offset
    );

    message_parser (


    );

    freshness_first_handler (


    );

endmodule