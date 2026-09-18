#include "udp_parser.hpp"

#include <vector>
#include <cstdint>
#include <iostream>
#include <cassert>

int main() {
    std::vector<uint8_t> frame = {
        // Source port 0x1234, Destination port 0x5678
        0x12, 0x34, 0x56, 0x78,
        // Length = 12 (8 header + 4 payload)
        0x00, 0x0C,
        // Checksum
        0xAB, 0xCD,
        // Payload
        0xDE, 0xAD, 0xBE, 0xEF,
    };

    UdpPacket packet = parseUdp(frame);

    assert(packet.source_port == 0x1234);
    assert(packet.destination_port == 0x5678);
    assert(packet.length == 12);
    assert(packet.checksum == 0xABCD);

    std::vector<uint8_t> expected_payload = {0xDE, 0xAD, 0xBE, 0xEF};
    assert(packet.payload == expected_payload);

    std::cout << "UDP payload passthrough test passed\n";
    return 0;
}
