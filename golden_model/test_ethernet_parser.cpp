#include "ethernet_parser.hpp"

#include <array>
#include <vector>
#include <cstdint>
#include <iostream>
#include <cassert>

// Define test frame
std::vector<uint_8> frame = {
    // Destination MAC
    0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
    // Source MAC
    0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28,
    // EtherType
    0x08, 0x00
};

int main() {
    EthernetHeader header;
    header = parseEthernet(frame);

    std::array<uint_8, 6> expected_destination = {
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18
    }
    std::array<uint_8, 6> expected_source = {
        0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28
    }

    assert (header.destination_mac == expected_destination);
    assert (header.source_mac == expected_source);
    assert (header.ether_type == 0x800);

    std::cout << "Valid ethernet frame test passed\n";

    return 0;
}
