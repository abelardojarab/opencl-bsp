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

cd $ROOT_PROJECT_PATH/example_designs/vector_add_int
rm -fr bin/vector_add_int
if [ ! -f bin/vector_add_int.aocx ]; then
	echo "Running AOC..."
	aoc vector_add_int.cl --board dcp_a10 -o bin/vector_add_int.aocx
	#aoc vector_add_int.cl --board skx_fpga_dcp_svm -o bin/vector_add_int.aocx
	rm -fr vector_add_int_comp
	mv bin/vector_add_int vector_add_int_comp
fi
#aocl program acl0 bin/vector_add_int.aocx
#aocl diagnose/program doesn't work on ARC - fb:532942
$SCRIPT_DIR_PATH/../linux64/libexec/program acl0 bin/vector_add_int.aocx
make
cp ./bin/vector_add_int .
cp bin/vector_add_int.aocx .
./vector_add_int 16
#ENABLE_DCP_OPENCL_SVM=1 ./bin/vector_add_int 16
