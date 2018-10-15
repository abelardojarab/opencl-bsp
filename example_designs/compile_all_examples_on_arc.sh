#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
MAIN_SCRIPTS_DIR_PATH="$(dirname $SCRIPT_PATH)/../scripts/"

AOC_CMD="sh $MAIN_SCRIPTS_DIR_PATH/aoc_for_bsp.sh -board=dcp_a10"

KERNEL_LIST=`find $SCRIPT_DIR_PATH -name "*.cl"`

#check if kernel_comp exists; rename if it does
if [ ! -d kernel_comp_a10 ]; then
    mkdir kernel_comp_a10
fi
cd kernel_comp_a10

echo $KERNEL_LIST

for i in $KERNEL_LIST; do
    echo $i
    if [ -d "$i" ]; then
        echo "kernel $i build results already exists; deleting previous build and starting a new one..."
        rm -rf $i
    fi
    arc submit node/"[memory>=15000]" priority=61 --  "export DCP_BSP_TARGET=dcp_a10; $AOC_CMD $i"
done
exit 0

