#!/bin/bash
#get exact script path
SCRIPT_PATH=`readlink -f ${BASH_SOURCE[0]}`
#get director of script path
SCRIPT_DIR_PATH="$(dirname $SCRIPT_PATH)"

. $SCRIPT_DIR_PATH/bsp_common.sh

export OPENCL_ASE_SIM=1
setup_arc_for_script $@

$SCRIPT_DIR_PATH/setup_packages.sh
python $SCRIPT_DIR_PATH/setup_bsp.py -v

cd $ROOT_PROJECT_PATH/example_designs/hello_world
rm -fr bin/hello_world
if [ ! -f bin/hello_world.aocx ]; then
	echo "Running AOC..."
	aoc device/hello_world.cl --board dcp_a10 -o bin/hello_world.aocx
	#aoc device/hello_world.cl --board skx_fpga_dcp_svm -o bin/hello_world.aocx
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
