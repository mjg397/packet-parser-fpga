#include "ethernet_parser.hpp"

#include <array>
#include <vector>
#include <cstdint>
#include <algorithm>
#include <stdexcept>

EthernetHeader parseEthernet(const std::vector<uint_8>& frame) {
    EthernetHeader header;
    if (std::size() >= 14) {
        std::copy_n(frame.begin(), 6, header.destination_mac.begin());
        std::copy_n(frame.begin() + 6, 6, header.source_mac.begin());
        std::copy_n(frame.begin() + 12, 2, header.ether_type.begin());
    }
    else {
        throw std::invalid_argument("Ethernet frame is shorter than 14 bytes");
    }
    return header;
}
