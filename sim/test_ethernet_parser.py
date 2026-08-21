import cocotb

from cocotb.clock import Clock
from cocotb.triggers import ReadOnly, RisingEdge, with_timeout
from cocotbext.axi import AxiStreamBus, AxiStreamSource


CLOCK_PERIOD_NS = 6.4  # 156.25 MHz


async def reset_dut(dut) -> None:
    dut.rst.value = 1

    for _ in range(5):
        await RisingEdge(dut.clk)

    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def wait_for_header_valid(dut) -> None:
    while True:
        await RisingEdge(dut.clk)
        await ReadOnly()

        if int(dut.header_valid.value):
            return


def build_ethernet_frame() -> bytes:
    destination_mac = bytes.fromhex("001122334455")
    source_mac = bytes.fromhex("66778899aabb")
    ether_type = bytes.fromhex("0800")

    # The payload is long enough that the packet will still be active
    # when the Ethernet header finishes parsing.
    payload = bytes(range(46))

    return (
        destination_mac
        + source_mac
        + ether_type
        + payload
    )


@cocotb.test()
async def test_valid_ethernet_header(dut) -> None:
    cocotb.start_soon(
        Clock(dut.clk, CLOCK_PERIOD_NS, unit="ns").start()
    )

    source = AxiStreamSource(
        AxiStreamBus.from_prefix(dut, "s_axis"),
        dut.clk,
        dut.rst,
        reset_active_level=True,
    )

    await reset_dut(dut)

    frame = build_ethernet_frame()

    header_task = cocotb.start_soon(
        wait_for_header_valid(dut)
    )

    await source.send(frame)

    # A broken parser should fail instead of hanging forever.
    await with_timeout(header_task, 1, "us")

    assert int(dut.dst_mac.value) == 0x001122334455
    assert int(dut.src_mac.value) == 0x66778899AABB
    assert int(dut.ether_type.value) == 0x0800
    assert int(dut.header_error.value) == 0

    # Ethernet metadata should appear before the complete frame ends.
    assert int(dut.s_axis_tlast.value) == 0