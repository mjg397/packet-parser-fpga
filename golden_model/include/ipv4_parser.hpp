#pragma once

#include <cstdint>
#include <array>
#include <vector>
#include <cstddef>

struct IPv4Header {
    uint8_t version;
    uint8_t ihl;
    uint8_t dscp;
    uint8_t ecn;

    uint16_t total_length;
    uint16_t identification;

    uint8_t flags;
    uint16_t fragment_offset;

    uint8_t ttl;
    uint8_t protocol;
    uint16_t header_checksum;

    std::array<uint8_t, 4> source_ip;
    std::array<uint8_t, 4> destination_ip;

    std::vector<uint8_t> options;
};

IPv4Header parseIPv4(const std::vector<uint8_t>& frame, std::size_t offset);
