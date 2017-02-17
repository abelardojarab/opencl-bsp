#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)/../scripts/"

#arc submit node/"[memory>=15000]" -- ../../../scripts/aoc_for_bsp.sh --board skx_fpga_1602 hello_world.cl 
#arc submit node/"[memory>=15000]" -- ../../../scripts/aoc_for_bsp.sh --board skx_fpga_1602 device/mem_bandwidth.cl
#arc submit node/"[memory>=15000]" -- ../../../scripts/aoc_for_bsp.sh --board skx_fpga_1602 device/vector_add.cl 

AOC_CMD="sh $SCRIPT_DIR_PATH/aoc_for_bsp.sh --board skx_fpga_1602"

mkdir kernel_comp
cd kernel_comp
arc submit node/"[memory>=15000]" -- $AOC_CMD ../blank/blank.cl
arc submit node/"[memory>=15000]" -- $AOC_CMD ../hello_world/device/hello_world.cl
arc submit node/"[memory>=15000]" -- $AOC_CMD ../mem_bandwidth/device/mem_bandwidth.cl
arc submit node/"[memory>=15000]" -- $AOC_CMD ../vector_add/device/vector_add.cl
