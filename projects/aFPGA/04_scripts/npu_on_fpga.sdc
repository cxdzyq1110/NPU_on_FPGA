#**************************************************************
# This .sbc file is created by Terasic Tool.
# Users are recommended to modify this file to match users logic.
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************
create_clock -period 20 [get_ports CLOCK_50]
create_clock -period 20 [get_ports CLOCK2_50]
create_clock -period 20 [get_ports CLOCK3_50]

# for enhancing USB BlasterII to be reliable, 25MHz
create_clock -name {altera_reserved_tck} -period 40 [get_ports {altera_reserved_tck}]

#**************************************************************
# Create Generated Clock
#**************************************************************
derive_pll_clocks



#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty



#**************************************************************
# Set Input Delay
#**************************************************************

#set_input_delay -clock [get_clocks altera_reserved_tck] -max 2.000 [get_ports {altera_reserved_tdi altera_reserved_tms}]
#set_input_delay -clock [get_clocks altera_reserved_tck] -min 1.000 [get_ports {altera_reserved_tdi altera_reserved_tms}]

set_input_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[2]] -max 4.000 [get_ports {SRAM_D*}]
set_input_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[2]] -min 0.500 [get_ports {SRAM_D*}]


set_input_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -max 3.000 [get_ports {OTG*}]
set_input_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -min 1.000 [get_ports {OTG*}]

set_input_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -max 3.000 [get_ports {UART_RXD}]
set_input_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -min 1.000 [get_ports {UART_RXD}]

set_input_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -max 3.000 [get_ports {AUD_ADC*}]
set_input_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -min 1.000 [get_ports {AUD_ADC*}]
set_input_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -max 3.000 [get_ports {AUD_BCLK*}]
set_input_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -min 1.000 [get_ports {AUD_BCLK*}]
set_input_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -max 3.000 [get_ports {AUD_DACLRCK*}]
set_input_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -min 1.000 [get_ports {AUD_DACLRCK*}]

set_input_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[3]] -max 3.000 [get_ports {I2C_S*}]
set_input_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[3]] -min 1.000 [get_ports {I2C_S*}]

#**************************************************************
# Set Output Delay
#**************************************************************

#set_output_delay -clock [get_clocks altera_reserved_tck] -max 2.000 [get_ports {altera_reserved_tdo}]
#set_output_delay -clock [get_clocks altera_reserved_tck] -min 1.000 [get_ports {altera_reserved_tdo}]

set_output_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[2]] -max 4.000 [get_ports {SRAM_*}]
set_output_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[2]] -min 0.500 [get_ports {SRAM_*}]

set_output_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -max 3.000 [get_ports {OTG*}]
set_output_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -min 1.000 [get_ports {OTG*}]

set_output_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -max 3.000 [get_ports {UART_TXD}]
set_output_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -min 1.000 [get_ports {UART_TXD}]

set_output_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -max 3.000 [get_ports {AUD_DACDAT}]
set_output_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]] -min 1.000 [get_ports {AUD_DACDAT}]

set_output_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[3]] -max 3.000 [get_ports {I2C_S*}]
set_output_delay -clock [get_clocks alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[3]] -min 1.000 [get_ports {I2C_S*}]


#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************

set_false_path -from {KEY*} -to {*}
set_false_path -from {SW*} -to {*}
set_false_path -from {altera_reserved_tdi*} -to {*}
set_false_path -from {altera_reserved_tms*} -to {*}
set_false_path  -from {*} -to {LED*}
set_false_path  -from {*} -to {HEX*}
set_false_path  -from {*} -to {AUD_XCK*}
set_false_path  -from {*} -to {altera_reserved_tdo*}
set_false_path -from {*} -through {afi_phy_rst_n} -to {*}
set_false_path -from {*} -through {audio_sample_en} -to {*}

set_false_path -from [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[2]}] -to [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]}]
set_false_path -from [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[0]}] -to [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[2]}]

set_false_path -from [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[2]}] -to [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[1]}]
set_false_path -from [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[1]}] -to [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[2]}]

set_false_path -from [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[2]}] -to [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[3]}]
set_false_path -from [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[3]}] -to [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[2]}]

set_false_path -from [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[2]}] -to [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[4]}]
set_false_path -from [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[4]}] -to [get_clocks {alt_pll_ip_core_inst|altpll_component|auto_generated|pll1|clk[2]}]


#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Load
#**************************************************************



