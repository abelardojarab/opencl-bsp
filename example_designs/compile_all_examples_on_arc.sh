#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
MAIN_SCRIPTS_DIR_PATH="$(dirname $SCRIPT_PATH)/../scripts/"

AOC_CMD="sh $MAIN_SCRIPTS_DIR_PATH/aoc_for_bsp.sh --board dcp_a10"

KERNEL_LIST=`find $SCRIPT_DIR_PATH -name "*.cl"`

mkdir kernel_comp
cd kernel_comp

echo $KERNEL_LIST

for i in $KERNEL_LIST; do
	echo $i
	arc submit node/"[memory>=15000]" priority=61 -- $AOC_CMD $i
done
exit 0

