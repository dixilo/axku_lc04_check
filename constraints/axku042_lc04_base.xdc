## USER LEDs
set_property PACKAGE_PIN E12 [get_ports {user_led[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[0]}]
set_property PACKAGE_PIN F12 [get_ports {user_led[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[1]}]
set_property PACKAGE_PIN L9 [get_ports {user_led[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[2]}]
set_property PACKAGE_PIN H23 [get_ports {user_led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {user_led[3]}]

## Differential system clock (200 MHz)
set_property PACKAGE_PIN AK17 [get_ports PL_CLK0_P]
set_property PACKAGE_PIN AK16 [get_ports PL_CLK0_N]
set_property IOSTANDARD LVDS [get_ports PL_CLK0_P]
set_property IOSTANDARD LVDS [get_ports PL_CLK0_N]
create_clock -period 5.000 -name PL_CLK0 [get_ports PL_CLK0_P]

## External Reset (Active-Low)
set_property PACKAGE_PIN N27 [get_ports ext_resetn]
set_property IOSTANDARD LVCMOS33 [get_ports ext_resetn]

## I2C for 24LC04 (1.8V)
set_property PACKAGE_PIN K13 [get_ports iic_sda]
set_property IOSTANDARD LVCMOS18 [get_ports iic_sda]
set_property PULLTYPE PULLUP [get_ports iic_sda]
set_property PACKAGE_PIN L13 [get_ports iic_scl]
set_property IOSTANDARD LVCMOS18 [get_ports iic_scl]
set_property PULLTYPE PULLUP [get_ports iic_scl]
