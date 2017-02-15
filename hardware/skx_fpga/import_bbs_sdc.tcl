project_open -force "fpga_top.qpf" -revision fpga_top
create_timing_netlist -model slow
read_sdc
write_sdc -expand "skx_bbs.sdc"
