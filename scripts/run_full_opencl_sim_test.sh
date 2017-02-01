cd $ROOT_PROJECT_PATH/example_designs/mem_bandwidth
aoc --board bdw_fpga_skx device/mem_bandwidth.cl -o bin/mem_bandwidth.aocx
rm -fr bin/mem_bandwidth
aocl program acl0 bin/mem_bandwidth.aocx
make
./bin/mem_bandwidth 1
