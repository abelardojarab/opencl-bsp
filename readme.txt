HOW TO RUN:
cd git_repo_root
arc shell vcs,vcs-vcsmx-lic/vrtn-dev,gcc/4.8.2,acl/16.0.2,vcs,acds/16.0.2,qedition/pro,python
./scripts/setup_packages.sh
./scripts/setup_env.sh

#./scripts/run_full_opencl_sim_test.sh
cd example_designs/mem_bandwidth
aoc --board bdw_fpga_skx device/mem_bandwidth.cl -o bin/mem_bandwidth.aocx
rm -fr bin/mem_bandwidth
aocl program acl0 bin/mem_bandwidth.aocx
make
./bin/mem_bandwidth 1

