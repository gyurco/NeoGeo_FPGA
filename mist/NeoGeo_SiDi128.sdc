# Clock constraints

# Automatically constrain PLL and other generated clocks

# Automatically calculate clock uncertainty to jitter and other effects.

# tsu/th constraints

# tco constraints

# tpd constraints

#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {QSCK}  -period 41.666 -waveform { 20.8 41.666 } [get_ports {QSCK}]

set sdram2_clk "pll2|altpll_component|auto_generated|pll1|clk[0]"

#**************************************************************
# Create Generated Clock
#**************************************************************


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

#**************************************************************
# Set Input Delay
#**************************************************************

set_input_delay -clock [get_clocks $sdram2_clk] -reference_pin [get_ports {SDRAM2_CLK}] -max 6.4 [get_ports SDRAM2_DQ[*]]
set_input_delay -clock [get_clocks $sdram2_clk] -reference_pin [get_ports {SDRAM2_CLK}] -min 3.2 [get_ports SDRAM2_DQ[*]]

#**************************************************************
# Set Output Delay
#**************************************************************

set_output_delay -clock [get_clocks $sdram2_clk] -reference_pin [get_ports {SDRAM2_CLK}] -max 1.5 [get_ports {SDRAM2_D* SDRAM2_A* SDRAM2_BA* SDRAM2_n* SDRAM2_CKE}]
set_output_delay -clock [get_clocks $sdram2_clk] -reference_pin [get_ports {SDRAM2_CLK}] -min -0.8 [get_ports {SDRAM2_D* SDRAM2_A* SDRAM2_BA* SDRAM2_n* SDRAM2_CKE}]

#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group [get_clocks {QSCK}] -group [get_clocks {pll|altpll_component|auto_generated|pll1|clk[*]}]
set_clock_groups -asynchronous -group [get_clocks {QSCK}] -group [get_clocks {pll2|altpll_component|auto_generated|pll1|clk[*]}]
set_clock_groups -asynchronous -group [get_clocks {SPI_SCK}] -group [get_clocks {pll2|altpll_component|auto_generated|pll1|clk[*]}]

#**************************************************************
# Set False Path
#**************************************************************



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

