from pathlib import Path
from cocotb_tools.runner import get_runner


def run_test():
    root = Path(__file__).resolve().parent.parent
    rtl = root / "rtl"

    sources = [
        rtl / "packet_parser.sv",
        rtl / "ethernet_parser.sv",
        rtl / "ipv4_parser.sv",
        rtl / "udp_parser.sv",
        rtl / "message_parser.sv",
        rtl / "freshness_first_handler.sv",
    ]

    runner = get_runner("verilator")

    runner.build(
        sources=sources,
        hdl_toplevel="packet_parser",
        build_args=["-Wno-fatal"],
        always=True,
    )

    runner.test(
        hdl_toplevel="packet_parser",
        test_module="test_packet_parser",
    )


if __name__ == "__main__":
    run_test()