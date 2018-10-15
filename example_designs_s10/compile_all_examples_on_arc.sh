#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
MAIN_SCRIPTS_DIR_PATH="$(dirname $SCRIPT_PATH)/../scripts/"

AOC_CMD="sh $MAIN_SCRIPTS_DIR_PATH/aoc_for_bsp.sh -v -board=dcp_s10"

KERNEL_LIST=`find $SCRIPT_DIR_PATH -name "*.cl"`

#check if kernel_comp_s10 exists; create it if not
if [ ! -d kernel_comp_s10 ]; then
    mkdir kernel_comp_s10
fi
cd kernel_comp_s10

echo "KERNEL_LIST is: "
echo $KERNEL_LIST
echo "Submitting each kernel to compile separately on arc..."

for i in $KERNEL_LIST; do
    echo "This kernel is $i"
    if [ -d "$i" ]; then
        echo "kernel $i build results already exists; deleting previous build and starting a new one..."
        rm -rf $i
    fi
    arc submit node/"[memory>=32000]" priority=61 --  "export ACL_ACDS_VERSION_OVERRIDE=18.1.0; export DCP_BSP_TARGET=dcp_s10; $AOC_CMD $i"
done
exit 0

