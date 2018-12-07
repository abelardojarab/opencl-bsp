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
echo "run_full_mmd_copy_sim_test.sh: TARGET_BSP is $TARGET_BSP"

. $SCRIPT_DIR_PATH/bsp_common.sh

export OPENCL_ASE_SIM=1
setup_arc_for_script $@

$SCRIPT_DIR_PATH/setup_packages.sh
python $SCRIPT_DIR_PATH/setup_bsp.py -v

#for now, use the 'example_designs' folder since the 
#application needs to match the rest of this script
#if [ "$DCP_BSP_TARGET" == "dcp_s10" ]
#then
#	cd $ROOT_PROJECT_PATH/example_designs_s10/mmd_copy_test
#	
#	rm -fr bin/mmd_copy_test
#	if [ ! -f bin/mmd_copy_test.aocx ]; then
#	    echo "Running AOC..."
#	    aoc device/mmd_copy_test.cl -board=$TARGET_BSP -o bin/mmd_copy_test.aocx
#	    rm -fr mmd_copy_test_comp
#	    mv bin/mmd_copy_test mmd_copy_test_comp
#	fi
#	#aocl program acl0 bin/hello_world.aocx
#	#aocl diagnose/program doesn't work on ARC - fb:532942
#	$SCRIPT_DIR_PATH/../linux64/libexec/program acl0 bin/mmd_copy_test.aocx
#	make
#	cp ./bin/mmd_copy_test .
#	cp bin/mmd_copy_test.aocx .
#	#16384 == buffer test size for dma
#	./mmd_copy_test 16384
#else
	cd $ROOT_PROJECT_PATH/example_designs/mmd_copy_test
	
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
	#16384 == buffer test size for dma
    # 1  = buffer size
    BUF_SZ=16384
    # 2  = num test loops
    NUM_TEST_LOOPS=1
    # 3  = do_test_1 (data is all 0x0)
    DO_TEST_1=1
    # 4  = do_test_2 (data is incrementing pattern)
    DO_TEST_2=1
    # 5  = do_test_3 (data is random)
    DO_TEST_3=1
    # 6  = do writes (clEnqueueWriteBuffer)
    DO_WRITES=1
    # 7  = do copies (clEnqueueCopyBuffer)
    DO_COPIES=1
    # 8  = do reads (clEnqueueReadBuffer)
    DO_READS=1
    # 9  = do read-back data compare
    DO_READ_COMPARE=1
    # 10 = do small reads
    DO_SMALL_READS=0
    # 11 = if small reads, use this size
    SMALL_RD_SZ=1024
    # 12 = how many reads to attempt (during wr-only test with read-compare)
    RD_TST_CNT=5

    ./hello_world $BUF_SZ $NUM_TEST_LOOPS $DO_TEST_1 $DO_TEST_2 $DO_TEST_3 $DO_WRITES $DO_COPIES $DO_READS $DO_READ_COMPARE $DO_SMALL_READS $SMALL_RD_SZ $RD_TST_CNT
#fi

