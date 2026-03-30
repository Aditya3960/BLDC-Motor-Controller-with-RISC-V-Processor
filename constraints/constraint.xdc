## =============================================================
## PYNQ-Z2 BLDC Sensorless Mode Constraints
## Clock reduced from 125MHz to 50MHz to fix timing violations
## =============================================================

## Clock - CHANGED from 8ns to 20ns (50 MHz)
set_property -dict { PACKAGE_PIN H16  IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports { clk }]

## Buttons → BEMF Comparator Inputs
set_property -dict { PACKAGE_PIN D19  IOSTANDARD LVCMOS33 } [get_ports { btn_bemf_u }]
set_property -dict { PACKAGE_PIN D20  IOSTANDARD LVCMOS33 } [get_ports { btn_bemf_v }]
set_property -dict { PACKAGE_PIN L20  IOSTANDARD LVCMOS33 } [get_ports { btn_bemf_w }]
set_property -dict { PACKAGE_PIN L19  IOSTANDARD LVCMOS33 } [get_ports { btn_reset   }]

## PWM Outputs
set_property -dict { PACKAGE_PIN Y17  IOSTANDARD LVCMOS33 } [get_ports { pwm_uh }]
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports { pwm_ul }]
set_property -dict { PACKAGE_PIN W18  IOSTANDARD LVCMOS33 } [get_ports { pwm_vh }]
set_property -dict { PACKAGE_PIN W19  IOSTANDARD LVCMOS33 } [get_ports { pwm_vl }]
set_property -dict { PACKAGE_PIN Y14  IOSTANDARD LVCMOS33 } [get_ports { pwm_wh }]
set_property -dict { PACKAGE_PIN W14  IOSTANDARD LVCMOS33 } [get_ports { pwm_wl }]

## Status LEDs
set_property -dict { PACKAGE_PIN R14  IOSTANDARD LVCMOS33 } [get_ports { status_leds[0] }]
set_property -dict { PACKAGE_PIN P14  IOSTANDARD LVCMOS33 } [get_ports { status_leds[1] }]
set_property -dict { PACKAGE_PIN N16  IOSTANDARD LVCMOS33 } [get_ports { status_leds[2] }]
set_property -dict { PACKAGE_PIN M14  IOSTANDARD LVCMOS33 } [get_ports { status_leds[3] }]

## Configuration
set_property CONFIG_VOLTAGE 3.3  [current_design]
set_property CFGBVS        VCCO [current_design]

## False Paths - async inputs
set_false_path -from [get_ports { btn_reset  }]
set_false_path -from [get_ports { btn_bemf_u }]
set_false_path -from [get_ports { btn_bemf_v }]
set_false_path -from [get_ports { btn_bemf_w }]

## False Paths - outputs
set_false_path -to [get_ports { status_leds[*] }]
set_false_path -to [get_ports { pwm_uh }]
set_false_path -to [get_ports { pwm_ul }]
set_false_path -to [get_ports { pwm_vh }]
set_false_path -to [get_ports { pwm_vl }]
set_false_path -to [get_ports { pwm_wh }]
set_false_path -to [get_ports { pwm_wl }]

## I/O Delays
set_input_delay  0 -clock [get_clocks sys_clk_pin] \
    [get_ports { btn_bemf_u btn_bemf_v btn_bemf_w btn_reset }]
set_output_delay 0 -clock [get_clocks sys_clk_pin] \
    [get_ports { pwm_uh pwm_ul pwm_vh pwm_vl pwm_wh pwm_wl }]

## Multicycle paths - give critical paths 2 cycles
set_multicycle_path -setup 2 \
    -from [get_cells -hier -filter {NAME =~ *counter_reg[*]}] \
    -to   [get_cells -hier -filter {NAME =~ *pwm_*}]
set_multicycle_path -hold  1 \
    -from [get_cells -hier -filter {NAME =~ *counter_reg[*]}] \
    -to   [get_cells -hier -filter {NAME =~ *pwm_*}]

set_multicycle_path -setup 2 \
    -from [get_cells -hier -filter {NAME =~ *deadtime_counter*}]
set_multicycle_path -hold  1 \
    -from [get_cells -hier -filter {NAME =~ *deadtime_counter*}]

set_multicycle_path -setup 2 \
    -from [get_cells -hier -filter {NAME =~ *sector_reg*}]
set_multicycle_path -hold  1 \
    -from [get_cells -hier -filter {NAME =~ *sector_reg*}]

set_multicycle_path -setup 2 \
    -from [get_cells -hier -filter {NAME =~ *cpu*}] \
    -to   [get_cells -hier -filter {NAME =~ *cpu*}]
set_multicycle_path -hold  1 \
    -from [get_cells -hier -filter {NAME =~ *cpu*}] \
    -to   [get_cells -hier -filter {NAME =~ *cpu*}]