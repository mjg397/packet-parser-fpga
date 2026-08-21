# Low-Latency FPGA Market Data Normalizer

## One-Sentence Summary

Build a **SystemVerilog FPGA pipeline** that receives raw Ethernet/IPv4/UDP market-data packets over AXI-Stream, parses an ITCH-inspired binary feed format, validates and filters packets, detects sequence gaps, and emits normalized low-latency trading events, verified against a **C++ golden model**.

This project is meant to be an HFT-facing FPGA portfolio project. It is not just a UDP parser. It is a small but realistic market-data ingestion pipeline.

---

## Why This Project Is Strong for HFT FPGA Roles

This project demonstrates the exact cluster of skills that low-latency trading FPGA roles tend to value:

- Low-latency streaming RTL design
- AXI-Stream protocol handling
- Ethernet / IPv4 / UDP packet parsing
- Market-data protocol normalization
- Sequence-number tracking and gap detection
- Backpressure-safe valid/ready design
- C++ modeling and packet generation
- Self-checking verification with a scoreboard
- Vivado synthesis, timing, resource, and latency reporting

The final story should be:

> I built a low-latency FPGA market-data normalizer. It receives raw Ethernet/IPv4/UDP packets over AXI-Stream, filters and validates a custom ITCH-inspired feed protocol, detects sequence gaps, and emits normalized trading events. I verified the RTL against a C++ golden model with randomized packet generation, malformed packet tests, scoreboard checking, backpressure tests, and Vivado timing/resource analysis.

---

## What Problem It Solves

Raw network packets are messy. A trading system does not want to consume raw bytes like this:

```text
[Ethernet header][IPv4 header][UDP header][market-data payload]
```

A trading system wants clean events like this:

```text
Symbol 3: bid updated to 101.25, quantity 100
Symbol 7: trade occurred at 225.10, quantity 20
Symbol 4: order 12345 deleted
```

This project converts raw network frames into normalized market-data events with deterministic low latency.

---

## High-Level Architecture

```text
AXI-Stream Ethernet Frame In
        |
        v
+------------------+
| Ethernet Parser  |
+------------------+
        |
        v
+------------------+
| IPv4 Parser      |
+------------------+
        |
        v
+------------------+
| UDP Parser       |
+------------------+
        |
        v
+--------------------------+
| Feed Filter / Validator  |
+--------------------------+
        |
        v
+--------------------------+
| NanoFeed Msg Parser      |
+--------------------------+
        |
        v
+--------------------------+
| Sequence Tracker         |
+--------------------------+
        |
        v
+--------------------------+
| Normalized Event Output  |
+--------------------------+
        |
        v
Optional Stretch:
+--------------------------+
| Tiny Top-of-Book Engine  |
+--------------------------+
```

---

## Target Time Budget

The recommended target is **20-40 focused hours**.

### Minimum Resume-Worthy Version

Estimated time: **20-25 hours**

Includes:

- C++ packet generator and golden parser
- 64-bit AXI-Stream input
- Ethernet / IPv4 / UDP parsing
- NanoFeed packet header parsing
- One or more messages per UDP payload
- Normalized event output
- Basic packet drops
- Sequence gap detection
- SystemVerilog self-checking testbench
- Vivado synthesis and timing report
- README with architecture, verification, and latency numbers

### Strong HFT Version

Estimated time: **30-40 hours**

Adds:

- More malformed packet tests
- Randomized C++ packet generation
- Backpressure tests
- More detailed scoreboard
- Latency counter
- Drop-reason checking
- Resource / latency table
- Cleaner documentation and resume bullets

### Stretch Version Beyond 40 Hours

Optional, only after the core version works:

- Multicast MAC/IP filtering
- IPv4 checksum validation
- UDP checksum validation
- Multiple feed IDs
- Per-feed sequence tracking
- Tiny top-of-book engine
- cocotb integration
- 32-bit and 128-bit AXI-Stream configurations

---

## Input Interface

The RTL receives full Ethernet frames over AXI-Stream.

Recommended default:

```systemverilog
parameter int DATA_W = 64;
```

AXI-Stream signals:

```systemverilog
input  logic                  clk;
input  logic                  rst;

input  logic                  s_axis_tvalid;
output logic                  s_axis_tready;
input  logic [DATA_W-1:0]     s_axis_tdata;
input  logic [DATA_W/8-1:0]   s_axis_tkeep;
input  logic                  s_axis_tlast;
input  logic                  s_axis_tuser;
```

Use `DATA_W = 64` for the first full implementation. Parameterization for 32/128-bit can be a stretch goal.

---

## Output Interface

The output should be a clean normalized event interface, not raw bytes.

```systemverilog
output logic                  m_event_valid;
input  logic                  m_event_ready;

output logic [7:0]            m_event_type;
output logic [1:0]            m_side;
output logic [15:0]           m_symbol_id;
output logic [31:0]           m_order_id;
output logic [31:0]           m_price;
output logic [31:0]           m_quantity;
output logic [31:0]           m_event_seq;
output logic [31:0]           m_packet_seq;
output logic [63:0]           m_timestamp_ns;
output logic [7:0]            m_feed_id;
output logic                  m_gap_detected;
```

Example normalized event:

```text
event_type   = Q
side         = buy
symbol_id    = 3
price        = 1012500
quantity     = 100
packet_seq   = 42
timestamp_ns = 1234567890
gap_detected = 0
```

---

## Packet Format

The input packet is a complete Ethernet frame.

```text
[Ethernet Header][IPv4 Header][UDP Header][NanoFeed Payload]
```

Example:

```text
Ethernet:
  dst_mac   = 01:00:5e:00:00:01
  src_mac   = aa:bb:cc:dd:ee:ff
  ethertype = 0x0800

IPv4:
  version  = 4
  ihl      = 5
  protocol = UDP / 17
  src_ip   = 10.0.0.1
  dst_ip   = 239.1.1.1

UDP:
  src_port = 50000
  dst_port = 9000

NanoFeed:
  packet_seq = 42
  timestamp  = 1234567890
  messages   = one or more market-data messages
```

---

## Custom Market Data Protocol: NanoFeed v1

Do not start with full NASDAQ ITCH. That would add unnecessary complexity. Instead, define an ITCH-inspired binary protocol called **NanoFeed v1**.

Each UDP payload contains:

```text
[NanoFeed Packet Header][Message 0][Message 1]...[Message N-1]
```

---

## NanoFeed Packet Header

Fixed size: **16 bytes**

| Field | Size | Description |
|---|---:|---|
| magic | 16 bits | Must equal `0x4E46`, ASCII `NF` |
| version | 8 bits | Must equal `1` |
| feed_id | 8 bits | Feed/channel ID |
| packet_seq | 32 bits | Packet sequence number |
| send_timestamp_ns | 64 bits | Exchange/send timestamp |

Required behavior:

- Drop packet if magic is wrong
- Drop packet if version is unsupported
- Extract `feed_id`
- Extract `packet_seq`
- Extract `send_timestamp_ns`
- Pass metadata to every output event from this packet

---

## NanoFeed Message Format

Fixed size: **24 bytes**

| Field | Size | Description |
|---|---:|---|
| msg_type | 8 bits | Add / Modify / Delete / Trade / Quote |
| side | 8 bits | Buy / Sell / None |
| symbol_id | 16 bits | Numeric symbol ID |
| order_id | 32 bits | Order ID |
| price | 32 bits | Fixed-point integer price |
| quantity | 32 bits | Shares/contracts |
| event_seq | 32 bits | Message sequence number |
| flags | 16 bits | Reserved/status flags |
| reserved | 16 bits | Padding |

Message types:

```text
0x41 = 'A' = Add order
0x4D = 'M' = Modify order
0x44 = 'D' = Delete order
0x54 = 'T' = Trade
0x51 = 'Q' = Quote / top-of-book update
```

Side values:

```text
0 = none
1 = buy
2 = sell
```

Required behavior:

- Parse all fields
- Drop invalid message types
- Drop invalid side values
- Emit one normalized event per message
- Support multiple messages per UDP packet

---

## Drop/Error Reporting

Add a small drop/error output interface.

```systemverilog
output logic                  drop_valid;
output logic [7:0]            drop_reason;
output logic [31:0]           drop_packet_seq;
```

Recommended drop reasons:

```systemverilog
typedef enum logic [7:0] {
  DROP_NONE                   = 8'd0,
  DROP_NON_IPV4               = 8'd1,
  DROP_BAD_IP_VERSION         = 8'd2,
  DROP_IP_OPTIONS_UNSUPPORTED = 8'd3,
  DROP_NON_UDP                = 8'd4,
  DROP_WRONG_UDP_PORT         = 8'd5,
  DROP_BAD_UDP_LENGTH         = 8'd6,
  DROP_BAD_MAGIC              = 8'd7,
  DROP_BAD_VERSION            = 8'd8,
  DROP_BAD_MSG_TYPE           = 8'd9,
  DROP_BAD_SIDE               = 8'd10,
  DROP_SEQUENCE_GAP           = 8'd11,
  DROP_TRUNCATED_PACKET       = 8'd12,
  DROP_FRAGMENTED_IP          = 8'd13
} drop_reason_t;
```

For sequence gaps, the better behavior is usually to **flag the event** rather than fully drop the packet:

```systemverilog
m_gap_detected = 1'b1;
```

---

## Required RTL Modules

### 1. `eth_parser.sv`

Responsibilities:

- Read Ethernet destination MAC
- Read Ethernet source MAC
- Read Ethertype
- Accept only IPv4 packets: `ethertype == 16'h0800`
- Drop non-IPv4 packets

Outputs metadata:

```text
dst_mac
src_mac
ethertype
```

---

### 2. `ipv4_parser.sv`

Responsibilities:

- Read IPv4 header
- Check `version == 4`
- Check `IHL == 5` for MVP
- Check `protocol == 17` for UDP
- Check packet is not fragmented
- Extract total length
- Extract source IP
- Extract destination IP

Drop if:

- Bad IP version
- IP options unsupported
- Not UDP
- Invalid length
- Fragmented packet

---

### 3. `udp_parser.sv`

Responsibilities:

- Read UDP source port
- Read UDP destination port
- Read UDP length
- Filter on configured destination market-data port
- Pass UDP payload to NanoFeed parser

Recommended parameter:

```systemverilog
parameter bit [15:0] MARKET_DATA_PORT = 16'd9000;
```

Drop if:

- Wrong destination port
- Bad UDP length

---

### 4. `nanofeed_parser.sv`

Responsibilities:

- Parse NanoFeed packet header
- Validate magic and version
- Parse one or more fixed-size messages
- Output one normalized event per message
- Propagate packet metadata to each event

Drop if:

- Bad magic
- Bad version
- Bad message type
- Bad side
- Truncated message

---

### 5. `sequence_tracker.sv`

Responsibilities:

- Track expected packet sequence number
- Initialize on first packet
- Detect in-order packets
- Detect gaps
- Detect duplicate or old packets

Example:

```text
Packet 100 arrives -> initialize expected next = 101
Packet 101 arrives -> sequence OK, expected next = 102
Packet 103 arrives -> gap detected, expected was 102
Packet 102 arrives -> old/out-of-order packet
```

Recommended outputs:

```systemverilog
output logic        sequence_ok;
output logic        sequence_gap;
output logic        sequence_old;
output logic [31:0] expected_seq;
output logic [31:0] observed_seq;
```

---

### 6. `market_data_normalizer_top.sv`

Responsibilities:

- Connect all pipeline stages
- Expose AXI-Stream input
- Expose normalized event output
- Expose drop/error interface
- Optionally expose debug counters

---

## Optional Stretch Module: `top_of_book.sv`

Only add this after the parser, sequence tracker, verification, and Vivado report are working.

Purpose:

Maintain a tiny top-of-book for a small number of symbols.

Recommended parameter:

```systemverilog
parameter int NUM_SYMBOLS = 16;
```

For each symbol, store:

```text
best_bid_price
best_bid_quantity
best_ask_price
best_ask_quantity
```

For quote messages:

```text
Q buy  -> update best bid
Q sell -> update best ask
```

Output:

```systemverilog
output logic        tob_valid;
output logic [15:0] tob_symbol_id;
output logic [31:0] best_bid_price;
output logic [31:0] best_bid_qty;
output logic [31:0] best_ask_price;
output logic [31:0] best_ask_qty;
```

This makes the project more trading-like, but it is not required for the first 20-40 hour version.

---

## C++ Golden Model

Build the C++ golden model first.

The C++ model defines the correct behavior of the RTL. It is the test oracle.

### C++ Responsibilities

The C++ program should:

1. Generate raw Ethernet/IPv4/UDP/NanoFeed packets
2. Parse packets using the intended behavior
3. Produce expected normalized events
4. Produce expected drop reasons
5. Write test vectors for the SystemVerilog testbench

---

## C++ Model Files

Recommended structure:

```text
cpp/
  include/
    packet.hpp
    nanofeed.hpp
    parser.hpp
    event.hpp
    test_case.hpp

  src/
    packet_builder.cpp
    golden_parser.cpp
    test_vector_gen.cpp
    main.cpp

  tests/
    test_golden_parser.cpp
```

### `packet.hpp`

Defines basic byte buffers and helper functions.

### `nanofeed.hpp`

Defines NanoFeed packet header and message structs.

### `parser.hpp`

Defines the golden software parser.

### `event.hpp`

Defines normalized event structs and drop reason enums.

### `packet_builder.cpp`

Builds raw byte packets.

### `golden_parser.cpp`

Parses raw packets and produces expected events/drop reasons.

### `test_vector_gen.cpp`

Generates deterministic and randomized test vectors.

---

## C++ Output Files

For each test, generate files like:

```text
vectors/
  packets/
    valid_one_msg.hex
    valid_multi_msg.hex
    wrong_udp_port.hex
    bad_magic.hex
    sequence_gap_0.hex
    sequence_gap_1.hex

  expected_events/
    valid_one_msg.events
    valid_multi_msg.events
    sequence_gap.events

  expected_drops/
    wrong_udp_port.drops
    bad_magic.drops
```

The SystemVerilog testbench reads these files and compares the RTL output against the C++ expected result.

---

## Verification Plan

The verification environment should include:

- AXI-Stream packet driver
- Event monitor
- Drop monitor
- Scoreboard
- Latency counter
- Backpressure generator
- Reset tests

### Required Test Cases

#### Valid Packet Tests

- One packet, one message
- One packet, multiple messages
- Multiple packets back-to-back
- Different symbols
- Different sides
- Different message types

#### Drop Tests

- Non-IPv4 Ethernet packet
- Bad IPv4 version
- IPv4 packet with options, if unsupported
- IPv4 packet that is not UDP
- Fragmented IPv4 packet
- Wrong UDP destination port
- Bad UDP length
- Bad NanoFeed magic
- Bad NanoFeed version
- Invalid message type
- Invalid side
- Truncated packet

#### Sequence Tests

- First packet initializes sequence tracker
- In-order packets
- Missing packet creates sequence gap
- Duplicate packet detected
- Old packet detected

#### Backpressure Tests

- `m_event_ready` always high
- Random output backpressure
- Long output stall
- Back-to-back packets while output stalls

---

## Latency Measurement

Measure latency from:

```text
first valid input beat of Ethernet frame
```

to:

```text
first valid normalized output event
```

Add a simulation counter.

Report:

```text
latency_cycles
latency_ns
clock_frequency
```

Example target:

```text
DATA_W = 64
Target clock = 200 MHz
Target first-event latency = under 40 cycles
Target latency = under 200 ns
```

The exact number matters less than measuring it, documenting it, and explaining the tradeoffs.

---

## Vivado Synthesis Requirements

At the end, synthesize the design in Vivado.

Required artifacts:

- Timing summary
- Utilization report
- Clock target
- Worst negative slack / timing status
- LUT count
- FF count
- BRAM count
- DSP count
- Latency measurement

Recommended report table:

| Config | DATA_W | Clock Target | LUTs | FFs | BRAM | DSP | Timing | First Event Latency |
|---|---:|---:|---:|---:|---:|---:|---|---:|
| MVP Parser | 64 | 200 MHz | TBD | TBD | TBD | TBD | TBD | TBD |
| Parser + Seq | 64 | 200 MHz | TBD | TBD | TBD | TBD | TBD | TBD |
| Parser + TOB | 64 | 200 MHz | TBD | TBD | TBD | TBD | TBD | TBD |

---

## Recommended Repo Layout

```text
fpga-low-latency-market-data-normalizer/
  README.md

  rtl/
    axis_defs.sv
    eth_parser.sv
    ipv4_parser.sv
    udp_parser.sv
    nanofeed_parser.sv
    sequence_tracker.sv
    market_data_normalizer_top.sv
    top_of_book.sv

  tb/
    sv/
      market_data_normalizer_tb.sv
      axis_driver.sv
      event_monitor.sv
      drop_monitor.sv
      event_scoreboard.sv

  cpp/
    include/
      packet.hpp
      nanofeed.hpp
      parser.hpp
      event.hpp
      test_case.hpp
    src/
      packet_builder.cpp
      golden_parser.cpp
      test_vector_gen.cpp
      main.cpp
    tests/
      test_golden_parser.cpp
    CMakeLists.txt

  vectors/
    packets/
    expected_events/
    expected_drops/

  vivado/
    synth.tcl
    constraints.xdc
    reports/

  docs/
    architecture.md
    protocol.md
    verification.md
    latency_resource_report.md
```

---

# 20-40 Hour Build Plan

## Phase 1: Define Protocol and C++ Data Structures

Estimated time: **3-5 hours**

### Goals

- Lock down NanoFeed packet format
- Create C++ structs/enums
- Implement byte packing helpers
- Decide endian format
- Create initial packet builder skeleton

### Deliverables

- `nanofeed.hpp`
- `event.hpp`
- `packet.hpp`
- Basic `PacketBuilder`

### Completion Criteria

You can generate a raw byte vector containing:

```text
Ethernet header + IPv4 header + UDP header + NanoFeed header + one message
```

---

## Phase 2: C++ Golden Parser and Test Vector Generator

Estimated time: **4-6 hours**

### Goals

- Parse generated packets in C++
- Produce normalized events
- Produce drop reasons
- Generate deterministic test vector files

### Deliverables

- `golden_parser.cpp`
- `test_vector_gen.cpp`
- `valid_one_msg.hex`
- `valid_multi_msg.hex`
- `bad_magic.hex`
- `wrong_udp_port.hex`
- Expected event/drop files

### Completion Criteria

Running the C++ program generates packets and expected outputs that look correct by inspection.

---

## Phase 3: RTL Skeleton and AXI-Stream Driver

Estimated time: **3-5 hours**

### Goals

- Create top module
- Create basic AXI-Stream input handling
- Create SV testbench driver that reads hex vectors
- Confirm packets can be driven into RTL

### Deliverables

- `market_data_normalizer_top.sv`
- `axis_driver.sv`
- `market_data_normalizer_tb.sv`

### Completion Criteria

Simulation can read a `.hex` packet file and drive it beat-by-beat over AXI-Stream.

---

## Phase 4: Ethernet / IPv4 / UDP Parser RTL

Estimated time: **5-8 hours**

### Goals

- Implement Ethernet header parsing
- Implement IPv4 header parsing
- Implement UDP header parsing
- Drop obvious invalid packets
- Pass UDP payload position to NanoFeed parser

### Deliverables

- `eth_parser.sv`
- `ipv4_parser.sv`
- `udp_parser.sv`

### Completion Criteria

RTL accepts a valid Ethernet/IPv4/UDP packet and rejects:

- Non-IPv4 packet
- Non-UDP packet
- Wrong UDP port

---

## Phase 5: NanoFeed Parser and Normalized Event Output

Estimated time: **5-8 hours**

### Goals

- Parse NanoFeed header
- Parse one message
- Extend to multiple messages per packet
- Emit normalized events
- Validate message type and side

### Deliverables

- `nanofeed_parser.sv`
- Event output interface
- Basic event monitor

### Completion Criteria

A valid packet with one or more messages produces the correct normalized event outputs.

---

## Phase 6: Sequence Tracker and Drop/Error Reporting

Estimated time: **3-5 hours**

### Goals

- Track expected packet sequence
- Detect gaps
- Detect old/duplicate packets
- Add drop/error interface
- Propagate `gap_detected` to output events

### Deliverables

- `sequence_tracker.sv`
- Drop reason enum
- Drop monitor

### Completion Criteria

Sequence test cases match the C++ golden model.

---

## Phase 7: Scoreboard, Backpressure, and Regression Tests

Estimated time: **4-7 hours**

### Goals

- Compare RTL output events against C++ expected event files
- Compare drop outputs against C++ expected drop files
- Add random `m_event_ready` backpressure
- Add back-to-back packet tests
- Add latency counter

### Deliverables

- `event_scoreboard.sv`
- `drop_monitor.sv`
- Regression script
- Latency counter/report

### Completion Criteria

A small regression suite passes:

```text
valid_one_msg
valid_multi_msg
wrong_udp_port
bad_magic
bad_version
invalid_side
sequence_gap
duplicate_packet
backpressure_valid_multi_msg
```

---

## Phase 8: Vivado Synthesis and Documentation

Estimated time: **3-6 hours**

### Goals

- Synthesize the design
- Generate timing/utilization reports
- Document latency and resources
- Write README
- Write final resume bullets

### Deliverables

- `synth.tcl`
- `constraints.xdc`
- `timing_summary.rpt`
- `utilization.rpt`
- `README.md`
- `docs/latency_resource_report.md`

### Completion Criteria

The repo clearly shows:

- What the project does
- How the protocol works
- How verification works
- What tests passed
- Latency in cycles/ns
- Vivado timing/resource results

---

## Recommended Time Allocation Summary

| Phase | Task | Estimated Time |
|---|---|---:|
| 1 | Protocol + C++ structs | 3-5 hrs |
| 2 | C++ golden parser + vectors | 4-6 hrs |
| 3 | RTL skeleton + AXI driver | 3-5 hrs |
| 4 | Ethernet/IPv4/UDP parser | 5-8 hrs |
| 5 | NanoFeed parser + events | 5-8 hrs |
| 6 | Sequence tracker + drops | 3-5 hrs |
| 7 | Scoreboard + backpressure | 4-7 hrs |
| 8 | Vivado + docs | 3-6 hrs |
| **Total** | **Core project** | **30-50 hrs** |

To keep this inside **20-40 hours**, prioritize Phases 1-6 and do a lighter version of Phases 7-8.

---

## 20-Hour Minimum Path

If time is tight, do this:

| Step | Task | Time |
|---|---|---:|
| 1 | Define NanoFeed protocol + C++ structs | 2 hrs |
| 2 | C++ packet generator for 5 deterministic tests | 3 hrs |
| 3 | C++ golden parser output events/drops | 3 hrs |
| 4 | RTL Ethernet/IPv4/UDP/NanoFeed parser combined FSM | 6 hrs |
| 5 | SV testbench with hardcoded/loaded vectors | 3 hrs |
| 6 | Sequence gap detection | 1.5 hrs |
| 7 | Basic Vivado synthesis + README | 1.5 hrs |
| **Total** | **Minimum version** | **20 hrs** |

Minimum test set:

```text
valid_one_msg
valid_multi_msg
wrong_udp_port
bad_magic
sequence_gap
```

---

## 40-Hour Strong Path

If you can spend closer to 40 hours, do this:

| Step | Task | Time |
|---|---|---:|
| 1 | Protocol + C++ structs | 4 hrs |
| 2 | C++ packet builder + golden parser | 6 hrs |
| 3 | Deterministic + randomized vector generator | 4 hrs |
| 4 | AXI-Stream RTL top/testbench infrastructure | 4 hrs |
| 5 | Ethernet/IPv4/UDP parser RTL | 7 hrs |
| 6 | NanoFeed parser RTL | 6 hrs |
| 7 | Sequence tracker + drop reporting | 3 hrs |
| 8 | Scoreboard + backpressure tests | 4 hrs |
| 9 | Vivado synthesis + README/report | 2 hrs |
| **Total** | **Strong version** | **40 hrs** |

---

## Stretch Features After 40 Hours

Only add these if the main project already works and is documented.

### Stretch 1: Multicast Filtering

Add configurable multicast destination MAC/IP filtering.

### Stretch 2: Per-Feed Sequence Tracking

Track sequence numbers independently for each `feed_id`.

### Stretch 3: IPv4 Header Checksum

Validate IPv4 header checksum.

### Stretch 4: UDP Checksum

Validate UDP checksum, or explicitly document why checksum zero is allowed in IPv4 UDP.

### Stretch 5: Tiny Top-of-Book Engine

Maintain best bid/ask for 16 symbols.

### Stretch 6: Parameterized DATA_W

Run at:

```text
DATA_W = 32
DATA_W = 64
DATA_W = 128
```

---

## Final README Outline

Your final README should include:

1. Project summary
2. Why it is HFT-relevant
3. Architecture diagram
4. NanoFeed protocol specification
5. Input/output interfaces
6. C++ golden model explanation
7. Verification plan
8. Test results
9. Latency measurement
10. Vivado timing/resource results
11. Future work
12. Resume bullets

---

## Final Resume Bullets

Use these once the project is complete:

- Designed a low-latency SystemVerilog market-data normalizer parsing Ethernet/IPv4/UDP packets over AXI-Stream and emitting fixed-format normalized trading events.
- Implemented feed filtering, malformed-packet drops, multi-message UDP payload parsing, and packet sequence-gap detection for an ITCH-inspired binary market-data protocol.
- Built a C++ golden model and randomized packet generator to verify valid packets, malformed frames, sequence gaps, duplicate packets, and backpressure behavior.
- Developed a self-checking RTL verification environment with scoreboard comparisons, latency counters, drop-reason checks, and regression tests across parser pipeline stages.
- Synthesized the design in Vivado and documented timing closure, FPGA resource utilization, deterministic pipeline latency, and latency/resource tradeoffs across configurations.

---

## Recommended First Commit

Your first commit should not be RTL.

Start with:

```text
README.md
cpp/include/nanofeed.hpp
cpp/include/event.hpp
cpp/include/packet.hpp
cpp/src/packet_builder.cpp
cpp/src/golden_parser.cpp
```

First milestone:

> C++ program generates a valid raw Ethernet/IPv4/UDP/NanoFeed packet and parses it into the expected normalized event.

Once that works, the RTL has a precise target.
