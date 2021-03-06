#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#echo "script_path is $SCRIPT_PATH"
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"
#echo "SCRIPT_DIR_PATH is $SCRIPT_DIR_PATH"
MAIN_SCRIPTS_DIR_PATH="$(dirname $SCRIPT_PATH)/../scripts/"
#echo "MAIN_SCRIPTS_DIR_PATH is $MAIN_SCRIPTS_DIR_PATH"

AOC_CMD="sh $MAIN_SCRIPTS_DIR_PATH/aoc_for_bsp.sh -v -board=dcp_s10"
#echo "aoc_cmd is $AOC_CMD"

#KERNEL_LIST=`find $SCRIPT_DIR_PATH -name "*.cl"`
KERNEL_LIST=`find $SCRIPT_DIR_PATH/vector_add -name "vector_add.cl"`

#check if kernel_comp_s10/vector_add exists; rename if it does
if [ -d kernel_comp_s10 ]; then
    if [ -d kernel_comp_s10/vector_add ]; then
        mv kernel_comp_s10/vector_add kernel_comp_s10/vector_add_$(date +%Y%m%d%H%M%S)
    fi
else
    mkdir kernel_comp_s10
fi
cd kernel_comp_s10

#printenv

echo "KERNEL_LIST is: "
echo $KERNEL_LIST
echo "Submitting each kernel to compile separately on arc..."

for i in $KERNEL_LIST; do
	echo $i
	arc submit node/"[memory>=32000]" priority=61 --  "export ALTERAOCLSDKROOT=/data/dgroen/aocl_181_patch/hld; export INTELFPGAOCLSDKROOT=/data/dgroen/aocl_181_patch/hld; PATH=$PATH:/data/dgroen/aocl_181_patch/hld/bin;export DCP_BSP_TARGET=dcp_s10; $AOC_CMD $i"
done
exit 0

