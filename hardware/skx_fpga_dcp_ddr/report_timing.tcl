project_open fpga_top

create_timing_netlist
read_sdc 
update_timing_netlist
report_timing -detail path_and_clock -nworst 200 -npaths 200 -pairs_only -file fpga_top_detailed.sta.rpt
delete_timing_netlist
project_close
