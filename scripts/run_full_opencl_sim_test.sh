#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"

. $SCRIPT_DIR_PATH/bsp_common.sh

export OPENCL_ASE_SIM=1
setup_arc_for_script $@

$SCRIPT_DIR_PATH/setup_packages.sh
cd $ROOT_PROJECT_PATH/example_designs/mem_bandwidth
rm -fr bin/mem_bandwidth
aoc device/mem_bandwidth.cl --board skx_fpga_dcp_ddr -o bin/mem_bandwidth.aocx
#aoc device/mem_bandwidth.cl --board skx_fpga_dcp_svm -o bin/mem_bandwidth.aocx
rm -fr mem_bandwidth_comp
mv bin/mem_bandwidth mem_bandwidth_comp
aocl program acl0 bin/mem_bandwidth.aocx
make
./bin/mem_bandwidth 1
#ENABLE_DCP_OPENCL_SVM=1 ./bin/mem_bandwidth 1
