module ethernet_parser(
    input logic clk,
    input logic rst_n,

    input logic        beat_valid,
    input logic [4:0]  beat_index,
    input logic [63:0] data,


    output logic [47:0] eth_dst_mac,
    output logic [47:0] eth_src_mac,
    output logic [15:0] eth_type,
    output logic        eth_valid
);

    // Extract ethernet fields from first 2 beats of AXIS
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            eth_valid <= 1'b0;
        end
        else begin
            eth_valid <= 1'b0;
            else if (beat_valid) begin 
                // Ethernet header byte offsets:
                //   Bytes  0-5  : Destination MAC
                //   Bytes  6-11 : Source MAC
                //   Bytes 12-13 : EtherType
                //   Byte  14    : Start of next header
                case(beat_index)
                    0 : begin
                        eth_dst_mac       <= data[47:0];
                        eth_src_mac[15:0] <= data[63:48];
                    end
                    1 : begin
                        eth_src_mac[47:16] <= data[31:0];
                        eth_type           <= data[47:31];
                        eth_valid          <= 1'b1;
                    end

                    default : begin
                        // No ethernet frames in later beats
                    end
                endcase
            end
        end
    end

endmodule
