set script_dir [file normalize [file dirname [info script]]]
set repo_root  [file normalize [file join $script_dir ".."]]
set build_dir  [file normalize [file join $script_dir "build"]]
set proj_name  "axku_lc04_check"
set part_name  "xcku040-ffva1156-2-i"
set bd_name    "mb_i2c_system"

file mkdir $build_dir
create_project $proj_name $build_dir -part $part_name -force

set rtl_files [list \
    [file join $repo_root rtl i2c_eeprom_master.v] \
    [file join $repo_root rtl axi_i2c_eeprom_ctrl.v] \
    [file join $repo_root rtl axku_lc04_top.v] \
]
add_files -norecurse $rtl_files
add_files -fileset constrs_1 -norecurse [file join $repo_root constraints axku042_lc04_base.xdc]
set_property top axku_lc04_top [current_fileset]
set_property source_mgmt_mode All [current_project]

create_bd_design $bd_name

create_bd_port -dir I -type clk clk_200
set_property CONFIG.FREQ_HZ 200000000 [get_bd_ports clk_200]
create_bd_port -dir I ext_resetn
create_bd_port -dir IO iic_scl
create_bd_port -dir IO iic_sda
create_bd_port -dir O -from 3 -to 0 user_led
create_bd_port -dir O -from 5 -to 0  dbg_fsm_state
create_bd_port -dir O -from 4 -to 0  dbg_bit_state
create_bd_port -dir O dbg_ack_poll_active
create_bd_port -dir O dbg_ack_poll_seen
create_bd_port -dir O dbg_last_ack
create_bd_port -dir O -from 15 -to 0 dbg_ack_poll_count
create_bd_port -dir O dbg_scl_sample
create_bd_port -dir O dbg_sda_sample

set clk_wiz_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz clk_wiz_0]
set_property -dict [list \
    CONFIG.PRIM_SOURCE {No_buffer} \
    CONFIG.PRIM_IN_FREQ {200.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.USE_RESET {false} \
] $clk_wiz_0

set rst_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset proc_sys_reset_0]
set rst_inv_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic rst_inv_0]
set_property -dict [list CONFIG.C_OPERATION {not} CONFIG.C_SIZE {1}] $rst_inv_0
connect_bd_net [get_bd_ports clk_200] [get_bd_pins clk_wiz_0/clk_in1]
connect_bd_net [get_bd_ports ext_resetn] [get_bd_pins rst_inv_0/Op1]
connect_bd_net [get_bd_pins rst_inv_0/Res] [get_bd_pins proc_sys_reset_0/ext_reset_in]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins proc_sys_reset_0/slowest_sync_clk]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins proc_sys_reset_0/dcm_locked]

set mb_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze microblaze_0]
set_property -dict [list \
    CONFIG.C_DEBUG_ENABLED {1} \
    CONFIG.C_USE_BARREL {1} \
    CONFIG.C_USE_DIV {1} \
    CONFIG.C_USE_HW_MUL {1} \
    CONFIG.C_D_AXI {1} \
    CONFIG.C_I_AXI {1} \
    CONFIG.C_USE_MSR_INSTR {1} \
] $mb_0

set mdm_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:mdm mdm_0]
set_property -dict [list CONFIG.C_USE_UART {1}] $mdm_0

set dlmb_cntlr [create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr dlmb_bram_if_cntlr]
set ilmb_cntlr [create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr ilmb_bram_if_cntlr]
set lmb_bram [create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen lmb_bram]
set_property -dict [list CONFIG.Memory_Type {True_Dual_Port_RAM}] $lmb_bram

set axi_interconnect_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect axi_interconnect_0]
set_property -dict [list CONFIG.NUM_MI {2}] $axi_interconnect_0

set axi_i2c_eeprom_ctrl_0 [create_bd_cell -type module -reference axi_i2c_eeprom_ctrl axi_i2c_eeprom_ctrl_0]

connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] \
    [get_bd_pins microblaze_0/Clk] \
    [get_bd_pins dlmb_bram_if_cntlr/LMB_Clk] \
    [get_bd_pins ilmb_bram_if_cntlr/LMB_Clk] \
    [get_bd_pins axi_interconnect_0/ACLK] \
    [get_bd_pins axi_interconnect_0/S00_ACLK] \
    [get_bd_pins axi_interconnect_0/M00_ACLK] \
    [get_bd_pins axi_interconnect_0/M01_ACLK] \
    [get_bd_pins mdm_0/S_AXI_ACLK] \
    [get_bd_pins axi_i2c_eeprom_ctrl_0/s_axi_aclk]

connect_bd_net [get_bd_pins proc_sys_reset_0/mb_reset] [get_bd_pins microblaze_0/Reset]
connect_bd_net [get_bd_pins proc_sys_reset_0/bus_struct_reset] \
    [get_bd_pins dlmb_bram_if_cntlr/LMB_Rst] \
    [get_bd_pins ilmb_bram_if_cntlr/LMB_Rst]
connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
    [get_bd_pins mdm_0/S_AXI_ARESETN] \
    [get_bd_pins axi_i2c_eeprom_ctrl_0/s_axi_aresetn] \
    [get_bd_pins axi_interconnect_0/ARESETN]

connect_bd_intf_net [get_bd_intf_pins microblaze_0/DLMB] [get_bd_intf_pins dlmb_bram_if_cntlr/SLMB]
connect_bd_intf_net [get_bd_intf_pins microblaze_0/ILMB] [get_bd_intf_pins ilmb_bram_if_cntlr/SLMB]
connect_bd_intf_net [get_bd_intf_pins dlmb_bram_if_cntlr/BRAM_PORT] [get_bd_intf_pins lmb_bram/BRAM_PORTA]
connect_bd_intf_net [get_bd_intf_pins ilmb_bram_if_cntlr/BRAM_PORT] [get_bd_intf_pins lmb_bram/BRAM_PORTB]

connect_bd_intf_net [get_bd_intf_pins microblaze_0/M_AXI_DP] [get_bd_intf_pins axi_interconnect_0/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M00_AXI] [get_bd_intf_pins mdm_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_interconnect_0/M01_AXI] [get_bd_intf_pins axi_i2c_eeprom_ctrl_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins mdm_0/MBDEBUG_0] [get_bd_intf_pins microblaze_0/DEBUG]

assign_bd_address

connect_bd_net [get_bd_ports iic_scl] [get_bd_pins axi_i2c_eeprom_ctrl_0/iic_scl]
connect_bd_net [get_bd_ports iic_sda] [get_bd_pins axi_i2c_eeprom_ctrl_0/iic_sda]
connect_bd_net [get_bd_ports user_led] [get_bd_pins axi_i2c_eeprom_ctrl_0/user_led]
connect_bd_net [get_bd_ports dbg_fsm_state] [get_bd_pins axi_i2c_eeprom_ctrl_0/dbg_fsm_state]
connect_bd_net [get_bd_ports dbg_bit_state] [get_bd_pins axi_i2c_eeprom_ctrl_0/dbg_bit_state]
connect_bd_net [get_bd_ports dbg_ack_poll_active] [get_bd_pins axi_i2c_eeprom_ctrl_0/dbg_ack_poll_active]
connect_bd_net [get_bd_ports dbg_ack_poll_seen] [get_bd_pins axi_i2c_eeprom_ctrl_0/dbg_ack_poll_seen]
connect_bd_net [get_bd_ports dbg_last_ack] [get_bd_pins axi_i2c_eeprom_ctrl_0/dbg_last_ack]
connect_bd_net [get_bd_ports dbg_ack_poll_count] [get_bd_pins axi_i2c_eeprom_ctrl_0/dbg_ack_poll_count]
connect_bd_net [get_bd_ports dbg_scl_sample] [get_bd_pins axi_i2c_eeprom_ctrl_0/dbg_scl_sample]
connect_bd_net [get_bd_ports dbg_sda_sample] [get_bd_pins axi_i2c_eeprom_ctrl_0/dbg_sda_sample]

validate_bd_design
save_bd_design

make_wrapper -files [get_files $build_dir/$proj_name.srcs/sources_1/bd/$bd_name/$bd_name.bd] -top
add_files -norecurse $build_dir/$proj_name.gen/sources_1/bd/$bd_name/hdl/${bd_name}_wrapper.v

set_property platform.default_output_type {xsa} [current_project]

puts ""
puts "Project created at: $build_dir"
puts "Next steps:"
puts "  1. open_project $build_dir/$proj_name.xpr"
puts "  2. source [file join $repo_root vivado insert_ack_poll_ila.tcl]   ;# optional"
puts "  3. Generate bitstream and export XSA"
