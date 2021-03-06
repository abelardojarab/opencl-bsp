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

export OPENCL_ASE_SIM=1

. $SCRIPT_DIR_PATH/bsp_common.sh

setup_arc_for_script $@

echo "For simulations, we are still going to use acl17.1.1 until ASE issues are resolved."
export ALTERAOCLSDKROOT=/tools/acl/17.1.1/273/linux64
export INTELFPGAOCLSDKROOT=$ALTERAOCLSDKROOT
PATH=$PATH:/tools/acl/17.1.1/273/linux64/bin

echo "run_full_opencl_sim_test.sh: TARGET_BSP is $TARGET_BSP"

$SCRIPT_DIR_PATH/setup_packages.sh
python $SCRIPT_DIR_PATH/setup_bsp.py -v

#for now, use the 'example_designs' folder since the 
#application needs to match the rest of this script
#if [ "$DCP_BSP_TARGET" == "dcp_s10" ]
#then
#	cd $ROOT_PROJECT_PATH/example_designs_s10/mem_bandwidth
#else
	cd $ROOT_PROJECT_PATH/example_designs/mem_bandwidth
#fi

rm -fr bin/mem_bandwidth
if [ ! -f bin/mem_bandwidth.aocx ]; then
	echo "Running AOC..."
	aoc device/mem_bandwidth.cl -board=$TARGET_BSP -o bin/mem_bandwidth.aocx
	rm -fr mem_bandwidth_comp
	mv bin/mem_bandwidth mem_bandwidth_comp
fi
#aocl program acl0 bin/mem_bandwidth.aocx
#aocl diagnose/program doesn't work on ARC - fb:532942
$SCRIPT_DIR_PATH/../linux64/libexec/program acl0 bin/mem_bandwidth.aocx
make
./bin/mem_bandwidth 1 1
#ENABLE_DCP_OPENCL_SVM=1 ./bin/mem_bandwidth 1
