HOW TO RUN SIM:
cd git_repo_root

#you can aslo run ./scripts/run_full_opencl_sim_test.sh
export OPENCL_ASE_SIM=1
./scripts/sim_bsp_env_shell.sh
./scripts/setup_packages.sh
cd example_designs/mem_bandwidth
aoc device/mem_bandwidth.cl -o bin/mem_bandwidth.aocx
rm -fr bin/mem_bandwidth
aocl program acl0 bin/mem_bandwidth.aocx
make
./bin/mem_bandwidth 1


HOW TO RUN HW:
export OPENCL_ASE_SIM=0
./scripts/bsp_env_shell.sh
./scripts/setup_packages.sh
aoc device/mem_bandwidth.cl -o bin/mem_bandwidth.aocx
rm -fr bin/mem_bandwidth
make
./bin/mem_bandwidth

