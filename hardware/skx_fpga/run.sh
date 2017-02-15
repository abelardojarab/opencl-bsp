#!/bin/bash

# Copy Blue bitstream library 
# ===========================
echo "Restoring Blue BS lib files"
echo "==========================="
cp -r ../lib/blue/output_files/ .
cp -r ../lib/blue/output_files/ .
cp -r ../lib/blue/qdb_file/* .

PROJ_REV1_NAME="fpga_top"
PROJ_REV2_NAME="skx_pr_afu_synth"
PROJ_REV3_NAME="skx_pr_afu"
# DO NOT MODIFY THESE VALUES"
# ==========================
ID_LOW_1="1a3a7f02"
ID_HIGH_1="870c3bcb"
ID_LOW_2="7d564b53"
ID_HIGH_2="e993f64a"
# ==========================

echo "Revision 1 : $PROJ_REV1_NAME"
echo "Revision 2 : $PROJ_REV2_NAME"
echo "Revision 3 : $PROJ_REV3_NAME"
echo "============================"

SYNTH_SUCCESS=1
FIT_SUCCESS=1
ASM_SUCCESS=1

# generate board.qsys
qsys-generate --synthesis=VERILOG --family="Arria 10" --part=10AX115U3F45E2SGE3  kernel_system.qsys
qsys-generate --synthesis=VERILOG --family="Arria 10" --part=10AX115U3F45E2SGE3  board.qsys



# Synthesize PR Persona
# =====================
quartus_syn --read_settings_files=on $PROJ_REV1_NAME -c $PROJ_REV2_NAME
SYNTH_SUCCESS=$?

# Fit PR Persona
# ==============
if [ $SYNTH_SUCCESS -eq 0 ]
then
    quartus_cdb --read_settings_files=on $PROJ_REV1_NAME -c $PROJ_REV2_NAME --export_block "root_partition" --snapshot synthesized --file "$PROJ_REV2_NAME.qdb"
    quartus_cdb --read_settings_files=on $PROJ_REV1_NAME -c $PROJ_REV3_NAME --import_block "root_partition" --file "$PROJ_REV1_NAME.qdb"
    quartus_cdb --read_settings_files=on $PROJ_REV1_NAME -c $PROJ_REV3_NAME --import_block persona1 --file "$PROJ_REV2_NAME.qdb"
    quartus_fit --read_settings_files=on $PROJ_REV1_NAME -c $PROJ_REV3_NAME    
    FIT_SUCCESS=$?
else
    echo "Persona synthesis failed"
    exit
fi

# Run Assembler 
# =============
if [ $FIT_SUCCESS -eq 0 ]
then
    quartus_asm $PROJ_REV1_NAME -c $PROJ_REV3_NAME
    ASM_SUCCESS=$?
else
    echo "Assmebler failed"
    exit 1
fi



# Report Timing
# =============
if [ $ASM_SUCCESS -eq 0 ]
then
    quartus_sta --do_report_timing $PROJ_REV1_NAME -c $PROJ_REV3_NAME
	quartus_sh -t scripts/adjust_plls_mcp.tcl
else
    echo "Persona compilation failed"
    exit 1
fi








# Generate output files for PR persona
# ====================================
if [ $ASM_SUCCESS -eq 0 ]
then
    echo "Generating PR rbf file"
    bash generate_pr_bitstream.sh $ID_LOW_1 $ID_HIGH_1 $ID_LOW_2 $ID_HIGH_2
else
    echo "Persona compilation failed"
    exit 1
fi
rm -rf *.json
echo ""
echo "==========================================================================="
echo "SKX-P PR AFU compilation complete"
echo "*** DEFAULT (uClk_usr, uClk_usrDiv2) is (312.5 MHz, 156.25 MHz) ****"
echo "AFU gbs file located at output_files/skx_pr_afu.gbs"
echo "Use this gbs file with aliconfafu utility to load PR bitstream"
echo "==========================================================================="
echo ""
