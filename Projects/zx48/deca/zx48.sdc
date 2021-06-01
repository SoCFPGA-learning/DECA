create_clock -name "clock50" -period 20.000 [get_ports {clock50}]
#create_clock -name "spiCk" -period 35.714 [get_ports {spiCk}]

derive_pll_clocks -create_base_clocks
derive_clock_uncertainty

#set_clock_groups -asynchronous -group [get_clocks {spiCk}] -group [get_clocks {Clock|altpll_component|auto_generated|pll1|clk[1]}]
#set_multicycle_path -from [get_clocks {Clock|altpll_component|auto_generated|pll1|clk[0]}] -to [get_clocks {pll|altpll_component|auto_generated|pll1|clk[0]}] -setup 2


set_input_delay -clock [get_clocks {Clock|altpll_component|auto_generated|pll1|clk[0]}] -reference_pin [get_ports sdramCk] -max 6.4 [get_ports sdramDQ[*]]
set_input_delay -clock [get_clocks {Clock|altpll_component|auto_generated|pll1|clk[0]}] -reference_pin [get_ports sdramCk] -min 3.2 [get_ports sdramDQ[*]]

set_output_delay -clock [get_clocks {Clock|altpll_component|auto_generated|pll1|clk[0]}] -reference_pin [get_ports sdramCk] -max 1.5 [get_ports {sdramCe sdramCs sdramWe sdramRas sdramCas sdramDQM[*] sdramDQ[*] sdramBA[*] sdramA[*]}]
set_output_delay -clock [get_clocks {Clock|altpll_component|auto_generated|pll1|clk[0]}] -reference_pin [get_ports sdramCk] -min -0.8 [get_ports {sdramCe sdramCs sdramWe sdramRas sdramCas sdramDQM[*] sdramDQ[*] sdramBA[*] sdramA[*]}]


set_output_delay -clock [get_clocks {Clock|altpll_component|auto_generated|pll1|clk[0]}] -max 0 [get_ports {sync[*]}]
set_output_delay -clock [get_clocks {Clock|altpll_component|auto_generated|pll1|clk[0]}] -min -5 [get_ports {sync[*]}]
set_multicycle_path -to [get_ports {sync[*]}] -setup 5
set_multicycle_path -to [get_ports {sync[*]}] -hold 4

set_output_delay -clock [get_clocks {Clock|altpll_component|auto_generated|pll1|clk[0]}] -max 0 [get_ports {rgb[*]}]
set_output_delay -clock [get_clocks {Clock|altpll_component|auto_generated|pll1|clk[0]}] -min -5 [get_ports {rgb[*]}]
set_multicycle_path -to [get_ports {rgb[*]}] -setup 5
set_multicycle_path -to [get_ports {rgb[*]}] -hold 4


set_false_path -to [get_ports {led[*] ear}]
