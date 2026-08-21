// AI-GENERATED CODE
//
// Fixed-format UDP payload message parser.
//
// Assumptions:
//   - 64-bit input datapath = 8 bytes/beat
//   - Ethernet header = 14 bytes
//   - IPv4 header = ip_ihl * 4 bytes
//   - UDP header = 8 bytes
//   - First packet byte in each beat is data[7:0]
//
// Message format: 32 bytes
//
//   Byte  0      : msg_type
//   Byte  1      : flags
//   Bytes 2-3    : source_id
//   Bytes 4-7    : sequence_num
//   Bytes 8-15   : timestamp
//   Bytes 16-19  : data_a
//   Bytes 20-23  : data_b
//   Bytes 24-27  : data_c
//   Bytes 28-31  : status
//
// message_meta_valid pulses as soon as source_id and sequence_num
// are available.
//
// message_valid pulses when the complete message has been parsed.

module message_parser (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        beat_valid,
    input  logic [7:0]  beat_index,
    input  logic [63:0] data,

    input  logic [3:0]  ip_ihl,
    input  logic        udp_valid,

    output logic [7:0]  msg_type,
    output logic [7:0]  flags,
    output logic [15:0] source_id,
    output logic [31:0] sequence_num,

    output logic [63:0] timestamp,

    output logic [31:0] data_a,
    output logic [31:0] data_b,
    output logic [31:0] data_c,
    output logic [31:0] status,

    output logic        message_meta_valid,
    output logic        message_valid
);

    // -------------------------------------------------------------------------
    // Message location
    //
    // Ethernet = 14 bytes
    // IPv4     = ip_ihl * 4 bytes
    // UDP      = 8 bytes
    //
    // message_start_byte = 14 + IPv4 + 8
    //                    = 22 + IPv4
    // -------------------------------------------------------------------------

    logic [7:0] message_start_byte;
    logic [7:0] message_start_beat;
    logic [2:0] message_offset;

    always_comb begin
        message_start_byte = 8'd22 + ({4'b0000, ip_ihl} << 2);
        message_start_beat = message_start_byte >> 3;
        message_offset     = message_start_byte[2:0];
    end


    // -------------------------------------------------------------------------
    // Sliding window
    //
    // prev_data = previous AXI beat
    // data      = current AXI beat
    //
    // Combining them lets us reconstruct 64-bit words that are not naturally
    // aligned to the AXI beat boundary.
    // -------------------------------------------------------------------------

    logic [63:0]  prev_data;
    logic [127:0] window;
    logic [63:0]  aligned_word;

    always_comb begin
        window = {data, prev_data};

        case (message_offset)
            3'd2:    aligned_word = window[79:16];
            3'd6:    aligned_word = window[111:48];
            default: aligned_word = 64'd0;
        endcase
    end


    // -------------------------------------------------------------------------
    // Parsing control
    // -------------------------------------------------------------------------

    logic [2:0] msg_word_index;
    logic       parsing;

    // udp_valid is generated after the beat containing the end of the UDP
    // header has been accepted. If there is a bubble before the next AXI beat,
    // remember that UDP parsing completed.
    logic udp_start_pending;


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            prev_data          <= 64'd0;
            msg_word_index     <= 3'd0;
            parsing            <= 1'b0;
            udp_start_pending  <= 1'b0;

            msg_type           <= 8'd0;
            flags              <= 8'd0;
            source_id          <= 16'd0;
            sequence_num       <= 32'd0;
            timestamp          <= 64'd0;
            data_a             <= 32'd0;
            data_b             <= 32'd0;
            data_c             <= 32'd0;
            status             <= 32'd0;

            message_meta_valid <= 1'b0;
            message_valid      <= 1'b0;
        end
        else begin

            // One-cycle pulse outputs
            message_meta_valid <= 1'b0;
            message_valid      <= 1'b0;


            // Remember that the UDP header has been successfully parsed.
            // This is useful if there is a gap before the next AXI beat.
            if (udp_valid) begin
                udp_start_pending <= 1'b1;
            end


            if (beat_valid) begin

                // -------------------------------------------------------------
                // First complete aligned message word
                //
                // The message starts partway through message_start_beat.
                // On the following beat, prev_data + data contain the complete
                // first 8 bytes of the message.
                // -------------------------------------------------------------

                if ((udp_valid || udp_start_pending) &&
                    (beat_index == message_start_beat + 8'd1)) begin

                    msg_type <= aligned_word[7:0];
                    flags    <= aligned_word[15:8];

                    source_id <= {
                        aligned_word[23:16],
                        aligned_word[31:24]
                    };

                    sequence_num <= {
                        aligned_word[39:32],
                        aligned_word[47:40],
                        aligned_word[55:48],
                        aligned_word[63:56]
                    };

                    message_meta_valid <= 1'b1;

                    msg_word_index    <= 3'd1;
                    parsing           <= 1'b1;
                    udp_start_pending <= 1'b0;
                end


                // -------------------------------------------------------------
                // Remaining message words
                // -------------------------------------------------------------

                else if (parsing) begin

                    case (msg_word_index)

                        // Message bytes 8-15
                        3'd1: begin
                            timestamp <= {
                                aligned_word[7:0],
                                aligned_word[15:8],
                                aligned_word[23:16],
                                aligned_word[31:24],
                                aligned_word[39:32],
                                aligned_word[47:40],
                                aligned_word[55:48],
                                aligned_word[63:56]
                            };

                            msg_word_index <= 3'd2;
                        end


                        // Message bytes 16-23
                        3'd2: begin
                            data_a <= {
                                aligned_word[7:0],
                                aligned_word[15:8],
                                aligned_word[23:16],
                                aligned_word[31:24]
                            };

                            data_b <= {
                                aligned_word[39:32],
                                aligned_word[47:40],
                                aligned_word[55:48],
                                aligned_word[63:56]
                            };

                            msg_word_index <= 3'd3;
                        end


                        // Message bytes 24-31
                        3'd3: begin
                            data_c <= {
                                aligned_word[7:0],
                                aligned_word[15:8],
                                aligned_word[23:16],
                                aligned_word[31:24]
                            };

                            status <= {
                                aligned_word[39:32],
                                aligned_word[47:40],
                                aligned_word[55:48],
                                aligned_word[63:56]
                            };

                            message_valid <= 1'b1;
                            parsing      <= 1'b0;
                        end


                        default: begin
                            parsing <= 1'b0;
                        end

                    endcase
                end


                // Every accepted beat becomes the previous beat
                // for the next sliding-window operation.
                prev_data <= data;
            end
        end
    end

endmodule
