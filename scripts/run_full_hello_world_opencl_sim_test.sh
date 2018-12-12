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

echo "run_full_hello_world_opencl_sim_test.sh: TARGET_BSP is $TARGET_BSP"

$SCRIPT_DIR_PATH/setup_packages.sh
python $SCRIPT_DIR_PATH/setup_bsp.py -v

#for now, use the 'example_designs' folder since the 
#application needs to match the rest of this script
#if [ "$DCP_BSP_TARGET" == "dcp_s10" ]
#then
#	cd $ROOT_PROJECT_PATH/example_designs_s10/hello_world
#else
	cd $ROOT_PROJECT_PATH/example_designs/hello_world
#fi

rm -fr bin/hello_world
if [ ! -f bin/hello_world.aocx ]; then
	echo "Running AOC..."
	aoc device/hello_world.cl -board=$TARGET_BSP -o bin/hello_world.aocx
	rm -fr hello_world_comp
	mv bin/hello_world hello_world_comp
fi
#aocl program acl0 bin/hello_world.aocx
#aocl diagnose/program doesn't work on ARC - fb:532942
$SCRIPT_DIR_PATH/../linux64/libexec/program acl0 bin/hello_world.aocx
make
cp ./bin/hello_world .
cp bin/hello_world.aocx .
./hello_world
#ENABLE_DCP_OPENCL_SVM=1 ./bin/hello_world
