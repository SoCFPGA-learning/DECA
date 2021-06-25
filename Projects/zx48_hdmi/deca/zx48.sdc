create_clock -name "clock50" -period 20.000 [get_ports {clock50}]

derive_pll_clocks 
derive_clock_uncertainty


