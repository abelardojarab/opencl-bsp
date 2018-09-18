#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"

if [ "$DCP_BSP_TARGET" == "dcp_s10" ]
then
	TARGET_BSP="dcp_s10"
else
	TARGET_BSP="dcp_a10"
	export DCP_BSP_TARGET="dcp_a10"
fi

. $SCRIPT_DIR_PATH/bsp_common.sh

export OPENCL_ASE_SIM=1
setup_arc_for_script $@

$SCRIPT_DIR_PATH/setup_packages.sh
python $SCRIPT_DIR_PATH/setup_bsp.py -v

if [ "$DCP_BSP_TARGET" == "dcp_s10" ]
then
	cd $ROOT_PROJECT_PATH/example_designs_s10/mem_bandwidth
else
	cd $ROOT_PROJECT_PATH/example_designs/mem_bandwidth
fi

rm -fr bin/mem_bandwidth
if [ ! -f bin/mem_bandwidth.aocx ]; then
	echo "Running AOC..."
	aoc device/mem_bandwidth.cl -board=$TARGET_BSP -o bin/mem_bandwidth.aocx
	#aoc device/mem_bandwidth.cl --board skx_fpga_dcp_svm -o bin/mem_bandwidth.aocx
	rm -fr mem_bandwidth_comp
	mv bin/mem_bandwidth mem_bandwidth_comp
fi
#aocl program acl0 bin/mem_bandwidth.aocx
#aocl diagnose/program doesn't work on ARC - fb:532942
$SCRIPT_DIR_PATH/../linux64/libexec/program acl0 bin/mem_bandwidth.aocx
make
./bin/mem_bandwidth 1
#ENABLE_DCP_OPENCL_SVM=1 ./bin/mem_bandwidth 1
