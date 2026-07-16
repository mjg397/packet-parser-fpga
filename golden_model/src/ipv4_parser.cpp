#include "ipv4_parser.hpp"


#include <algorithm>
#include <stdexcept>

// ------------------------------------------------------------------------------
// | IPv4 offset | Packet offset | Contents                                     |
// | ----------: | ------------: | -------------------------------------------- |
// |           0 |            14 | Version in upper 4 bits, IHL in lower 4 bits |
// |           1 |            15 | DSCP and ECN                                 |
// |         2–3 |         16–17 | Total IPv4 packet length                     |
// |         4–5 |         18–19 | Identification                               |
// |         6–7 |         20–21 | Flags and fragment offset                    |
// |           8 |            22 | Time to Live                                 |
// |           9 |            23 | Protocol                                     |
// |       10–11 |         24–25 | Header checksum                              |
// |       12–15 |         26–29 | Source IPv4 address                          |
// |       16–19 |         30–33 | Destination IPv4 address                     |
// |   20 onward |     34 onward | Options, only when IHL is greater than 5     |
// ------------------------------------------------------------------------------

IPv4Header parseIPv4(const std::vector<uint8_t>& frame, std::size_t offset) {
    IPv4Header header{};
    if (frame.size() < offset+20) {
        throw std::invalid_argument("IPv4 frame is shorter than 20 bytes");
    }

    // Version and IHL
    uint8_t first_byte = frame[offset];
    header.version = first_byte >> 4;
    header.ihl = first_byte & 0x0F;

    if (header.version != 4) {
        throw std::invalid_argument("Invalid IPv4 Version");
    }
    if (header.ihl < 5) {
        throw std::invalid_argument("Invalid IPv4 IHL");
    }

    std::size_t header_length = static_cast<std::size_t>(header.ihl) * 4;

    if (frame.size() < offset + header_length) {
        throw std::invalid_argument(
            "Frame is shorter than the IPv4 header indicated by IHL"
        );
    }

    // DSCP and ECN
    uint8_t second_byte = frame[offset+1];
    header.dscp = second_byte >> 2;
    header.ecn = second_byte & 0x03;

    // Total length and identificaiton
    header.total_length = (static_cast<uint16_t>frame[offset+2]) << 8 |
        frame[offset+3];
    header.identification = (static_cast<uint16_t>frame[offset+4]) << 8 |
        frame[offset+5];

    if (header.total_length < header_length) {
        throw std::invalid_argument("IPv4 total length is smaller than its header length");
    }
    // Flags and fragmentation offset
    uint16_t fragmentation_field = (static_cast<uint16_t>frame[offset+6]) << 8 |
        frame[offset+7];
    header.flags = fragmentation_field  >> 13;
    header.fragment_offset = fragmentation_field & 0x1FFF;

    // TTL, protocol, and checksum
    header.ttl = frame[offset + 8];
    header.protocol = frame[offset + 9];

    header.header_checksum = (static_cast<uint16_t>frame[offset+10]) << 8 |
        frame[offset+11];

    // Source and destination IP
    std::copy_n(frame.begin() + offset + 12, 4, header.source_ip.begin());
    std::copy_n(frame.begin() + offset + 16, 4, header.destination_ip.begin());

    // Options
    header.options.assign(frame.begin() + offset + 20, 
        frame.begin() + offset + header_length);

    return header;
}


