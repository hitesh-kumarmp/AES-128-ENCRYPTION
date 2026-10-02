## ============================================================
## Arty A7-100T : AES-128 + UART
## ============================================================

## ------------------------------------------------------------
## 100 MHz System Clock
## ------------------------------------------------------------

set_property -dict {
    PACKAGE_PIN E3
    IOSTANDARD LVCMOS33
} [get_ports clk]

create_clock -add \
    -name sys_clk \
    -period 10.000 \
    -waveform {0 5} \
    [get_ports clk]


## ------------------------------------------------------------
## Reset - BTN0
## Active HIGH
## ------------------------------------------------------------

set_property -dict {
    PACKAGE_PIN D9
    IOSTANDARD LVCMOS33
} [get_ports rst]


## ------------------------------------------------------------
## USB-UART
##
## FPGA perspective:
##
## uart_rx = PC/FTDI TX → FPGA RX
## uart_tx = FPGA TX → PC/FTDI RX
## ------------------------------------------------------------

set_property -dict {
    PACKAGE_PIN A9
    IOSTANDARD LVCMOS33
} [get_ports uart_rx]

set_property -dict {
    PACKAGE_PIN D10
    IOSTANDARD LVCMOS33
} [get_ports uart_tx]