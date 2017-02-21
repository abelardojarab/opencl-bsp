

#project_open fgpa_top -revision pr_afu_synth

post_message "Generating board.qsys:"
post_message "    qsys-generate -syn --family=\"Arria 10\" --part=10AX115U3F45E2SG board.qsys"
qexec "qsys-generate -syn --family=\"Arria 10\" --part=10AX115U3F45E2SG board.qsys"

# adding board.qsys and corresponding .ip parameterization files to opencl_bsp_ip.qsf
qexec "qsys-archive --quartus-project=top --rev=opencl_bsp_ip board.qsys"



# generate kernel_system.qsys 
# and add Qsys Pro generated files to "opencl_bsp_ip.qsf"
post_message "Generating kernel_system.qsys:"
post_message "    qsys-generate -syn --family=\"Arria 10\" --part=10AX115U3F45E2SG kernel_system.qsys"
qexec "qsys-generate -syn --family=\"Arria 10\" --part=10AX115U3F45E2SG kernel_system.qsys"
qexec "qsys-archive --quartus-project=top --rev=opencl_bsp_ip kernel_system.qsys"




# generate kernel_system.qsys 
# and add Qsys Pro generated files to "opencl_bsp_ip.qsf"
post_message "Generating kernel_system.qsys:"
post_message "    qsys-generate -syn --family=\"Arria 10\" --part=10AX115U3F45E2SG cci_interface.qsys"
qexec "qsys-generate -syn --family=\"Arria 10\" --part=10AX115U3F45E2SG cci_interface.qsys"
qexec "qsys-archive --quartus-project=top --rev=opencl_bsp_ip cci_interface.qsys"



