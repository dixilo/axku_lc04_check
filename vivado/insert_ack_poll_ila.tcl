set top_scope [current_instance .]

create_debug_core u_ila_ack ila
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_ack]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_ack]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_ack]

set dbg_clk_net [get_nets -hier -filter {NAME =~ *clk_200*}]
if {[llength $dbg_clk_net] == 0} {
    error "Could not find a clock net for the ILA. Open synthesized design and adjust the net name if needed."
}

set_property port_width 1 [get_debug_ports u_ila_ack/clk]
connect_debug_port u_ila_ack/clk [lindex $dbg_clk_net 0]

create_debug_port u_ila_ack probe
set_property port_width 6 [get_debug_ports u_ila_ack/probe0]
connect_debug_port u_ila_ack/probe0 [get_nets -hier -filter {NAME =~ *dbg_fsm_state[*]}]

create_debug_port u_ila_ack probe
set_property port_width 5 [get_debug_ports u_ila_ack/probe1]
connect_debug_port u_ila_ack/probe1 [get_nets -hier -filter {NAME =~ *dbg_bit_state[*]}]

create_debug_port u_ila_ack probe
set_property port_width 1 [get_debug_ports u_ila_ack/probe2]
connect_debug_port u_ila_ack/probe2 [get_nets -hier -filter {NAME =~ *dbg_ack_poll_active}]

create_debug_port u_ila_ack probe
set_property port_width 1 [get_debug_ports u_ila_ack/probe3]
connect_debug_port u_ila_ack/probe3 [get_nets -hier -filter {NAME =~ *dbg_ack_poll_seen}]

create_debug_port u_ila_ack probe
set_property port_width 1 [get_debug_ports u_ila_ack/probe4]
connect_debug_port u_ila_ack/probe4 [get_nets -hier -filter {NAME =~ *dbg_last_ack}]

create_debug_port u_ila_ack probe
set_property port_width 16 [get_debug_ports u_ila_ack/probe5]
connect_debug_port u_ila_ack/probe5 [get_nets -hier -filter {NAME =~ *dbg_ack_poll_count[*]}]

create_debug_port u_ila_ack probe
set_property port_width 1 [get_debug_ports u_ila_ack/probe6]
connect_debug_port u_ila_ack/probe6 [get_nets -hier -filter {NAME =~ *dbg_scl_sample}]

create_debug_port u_ila_ack probe
set_property port_width 1 [get_debug_ports u_ila_ack/probe7]
connect_debug_port u_ila_ack/probe7 [get_nets -hier -filter {NAME =~ *dbg_sda_sample}]

current_instance $top_scope
puts "Inserted ILA for ACK polling debug signals."
