#include "udp_parser.hpp"

#include <stdexcept>

UdpPacket parseUdp(const std::vector<uint8_t>& frame) {
    if (frame.size() < 8) {
        throw std::invalid_argument("UDP frame is shorter than 8 bytes");
    }

    UdpPacket packet{};
    packet.source_port = (static_cast<uint16_t>(frame[0]) << 8) | frame[1];
    packet.destination_port = (static_cast<uint16_t>(frame[2]) << 8) | frame[3];
    packet.length = (static_cast<uint16_t>(frame[4]) << 8) | frame[5];
    packet.checksum = (static_cast<uint16_t>(frame[6]) << 8) | frame[7];

    if (packet.length < 8 || frame.size() < packet.length) {
        throw std::invalid_argument("UDP length field inconsistent with frame size");
    }

    // Payload passthrough: everything after the 8-byte UDP header, up to
    // the length the header itself declares. Without this, a downstream
    // consumer (e.g. a market-data feed decoder) has no way to get at the
    // datagram's contents -- parsing the header alone is a dead end.
    packet.payload.assign(frame.begin() + 8, frame.begin() + packet.length);

    return packet;
}
