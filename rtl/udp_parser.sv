module udp_parser(
    input logic clk,
    input logic rst_n,

    input logic        beat_valid,
    input logic [7:0]  beat_index, 
    input logic [63:0] data, 

    input logic [3:0] ip_ihl,
    input logic [7:0] ip_protocol,
    input logic       ipv4_valid,

    output logic [15:0] udp_src_port,
    output logic [15:0] udp_dst_port,
    output logic [15:0] udp_length,
    output logic [15:0] udp_checksum,

    output logic udp_valid
);

    logic [7:0]   udp_start_byte;
    logic [7:0]   udp_start_beat;
    logic [2:0]   udp_offset;

    logic [63:0]  first_beat;
    logic [127:0] window;
    logic [63:0]  aligned_udp_header;

    logic udp_enable;


    always_comb begin
        udp_start_byte = 8'd14 + ({4'b0000, ip_ihl} << 2);
        udp_start_beat = udp_start_byte >> 3;
        udp_offset     = udp_start_byte[2:0];

        window = {data, first_beat};

        udp_enable = (ip_protocol == 8'h11) && ipv4_valid;

        case (udp_offset)
            3'd2:    aligned_udp_header = window[79:16];
            3'd6:    aligned_udp_header = window[111:48];
            default: aligned_udp_header = 64'd0;
        endcase
    end

    // UDP header byte offsets RELATIVE to UDP start:
    //
    //   Bytes 0-1 : Source Port
    //   Bytes 2-3 : Destination Port
    //   Bytes 4-5 : UDP Length
    //   Bytes 6-7 : UDP Checksum
    //   Byte  8   : Start of UDP payload
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            udp_valid <= 0;
            first_beat <= 0;
        end 
        else begin
            udp_valid <= 0;
            if (beat_valid && beat_index == udp_start_beat) begin
                first_beat <= data;
            end
            if (beat_valid && udp_enable && beat_index == udp_start_beat + 1'b1) begin
                udp_src_port <= {
                    aligned_udp_header[7:0],
                    aligned_udp_header[15:8]
                };

                udp_dst_port <= {
                    aligned_udp_header[23:16],
                    aligned_udp_header[31:24]
                };

                udp_length <= {
                    aligned_udp_header[39:32],
                    aligned_udp_header[47:40]
                };

                udp_checksum <= {
                    aligned_udp_header[55:48],
                    aligned_udp_header[63:56]
                };

                udp_valid <= 1;
            end
        end
    end
endmodule
