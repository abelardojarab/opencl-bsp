#!/bin/bash

FLOW_SUCCESS=1

# Copy Blue bitstream library 
# ===========================
echo "Restoring Blue BS lib files"
echo "==========================="
#TODO: copy files

# generate board.qsys
qsys-generate --synthesis=VERILOG --family="Arria 10" --part=10AX115N3F40E2SG  kernel_system.qsys
qsys-generate --synthesis=VERILOG --family="Arria 10" --part=10AX115N3F40E2SG  board.qsys

# compile project
# =====================
quartus_sh -t a10_partial_reconfig.tcl -setup_script pr_setup.tcl -impl afu_fit
FLOW_SUCCESS=$?

# Report Timing
# =============
if [ $FLOW_SUCCESS -eq 0 ]
then
    quartus_sta --do_report_timing $PROJ_REV1_NAME -c $PROJ_REV3_NAME
	quartus_sh -t scripts/adjust_plls_mcp.tcl
else
    echo "Persona compilation failed"
    exit 1
fi

echo ""
echo "==========================================================================="
echo "SKX-P PR AFU compilation complete"
echo "*** DEFAULT (uClk_usr, uClk_usrDiv2) is (312.5 MHz, 156.25 MHz) ****"
echo "AFU gbs file located at output_files/skx_pr_afu.gbs"
echo "Use this gbs file with aliconfafu utility to load PR bitstream"
echo "==========================================================================="
echo ""
