module ipv4_parser(
    input logic clk,
    input logic rst_n,

    input logic        beat_valid,
    input logic [4:0]  beat_index,
    input logic [63:0] data,

    input logic [15:0] eth_type,

    output logic [3:0] ip_version,
    output logic [3:0] ip_ihl,

    output logic [15:0] ip_total_length,
    output logic [7:0]  ip_protocol,

    output logic [31:0] ip_src_addr,
    output logic [31:0] ip_dst_addr,

    output logic [15:0] ip_checksum,

    output logic        ipv4_valid
);

    logic ipv4_enable;

    always_comb begin
        if (beat_valid && eth_type == 16'h0800)
            ipv4_enable <= 1'b1;
        else
            ipv4_enable <= 1'b0;
    end

    // IPv4 header byte offsets:
    //   Byte  14    : Version [7:4], IHL [3:0]
    //   Byte  15    : DSCP [7:2], ECN [1:0]
    //   Bytes 16-17 : Total Length
    //   Bytes 18-19 : Identification
    //   Bytes 20-21 : Flags [15:13], Fragment Offset [12:0]
    //   Byte  22    : Time To Live (TTL)
    //   Byte  23    : Protocol
    //   Bytes 24-25 : Header Checksum
    //   Bytes 26-29 : Source IPv4 Address
    //   Bytes 30-33 : Destination IPv4 Address
    //
    //   Byte  34    : Start of next header if IHL == 5
    //
    //   Bytes 34+   : IPv4 Options if IHL > 5
    //                 Next header starts at:
    //                 14 + (IHL * 4)
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ipv4_valid <= 1'b0;
        end else begin
            ipv4_valid <= 1'b0;
            if (ipv4_enable) begin
                case(beat_index)
                    1 : begin
                        ip_ihl     <= data[51:48];
                        ip_version <= data[55:52];
                    end
                    2 : begin
                        ip_total_length <= data[15:0];
                        ip_protocol     <= data[63:56];
                    end
                    3 : begin
                        ip_checksum <= data[15:0];
                        ip_src_addr <= data[47:16];
                        ip_dst_addr <= data[63:48];
                    end
                    4 : begin
                        ip_dst_addr <= data[15:0];
                        ipv4_valid   <= 1'b1;
                    end
                endcase
            end
        end
    end
endmodule