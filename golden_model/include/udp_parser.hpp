#pragma once

#include <cstdint>
#include vector


struct UdpPacket {
    uint16_t source_port;
    uint16_t destination_port;
    uint16_t length;
    uint16_t checksum;
}

UdpPacket parseUdp(const std::vector<uint8_t>& frame);
