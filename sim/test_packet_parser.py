import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge


@cocotb.test()
async def test_reset(dut):

    # Start clock: 10 ns period = 100 MHz
    cocotb.start_soon(
        Clock(dut.clk, 10, unit="ns").start()
    )

    # Initial input values
    dut.rst_n.value = 0

    dut.s_axis_tdata.value = 0
    dut.s_axis_tkeep.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0

    # Hold reset for two clocks
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    # Release reset
    dut.rst_n.value = 1

    # Let DUT run
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)