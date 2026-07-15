#pragma once

#include <array>
#include <vector>
#include <cstdint>

// Define struct for ethernet header
struct EthernetHeader {
    std::array<uint_8, 6> destination_mac;
    std::array<uint_8, 6> source_mac;
    uint_16 ether_type;
};

EthernetHeader parseEthernet(const std::vector<uint_8>& frame);
