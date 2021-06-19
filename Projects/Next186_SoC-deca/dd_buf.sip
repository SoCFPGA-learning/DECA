set_global_assignment -entity "dd_buf" -library "lib_dd_buf" -name IP_TOOL_NAME "altera_gpio_lite"
set_global_assignment -entity "dd_buf" -library "lib_dd_buf" -name IP_TOOL_VERSION "17.1"
set_global_assignment -entity "dd_buf" -library "lib_dd_buf" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_dd_buf" -name SPD_FILE [file join $::quartus(sip_path) "dd_buf.spd"]

set_global_assignment -library "lib_dd_buf" -name MISC_FILE [file join $::quartus(sip_path) "dd_buf_sim/dd_buf.v"]
set_global_assignment -library "lib_dd_buf" -name MISC_FILE [file join $::quartus(sip_path) "dd_buf_sim/altera_gpio_lite/altera_gpio_lite.sv"]
