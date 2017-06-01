echo ase sim compile flow
rm -fr sim_files
mkdir sim_files

qsys-generate --synthesis=VERILOG -qpf=dcp -c=afu_synth kernel_system.qsys
qsys-generate --synthesis=VERILOG -qpf=dcp -c=afu_synth board.qsys

find ccip_iface/ip -name synth | xargs -n1 -IAAA find AAA -name "*.v" -o -name "*.sv" | xargs cp -t ./sim_files
find ccip_iface/ccip_avmm_bridge -name synth | xargs -n1 -IAAA find AAA -name "*.v" -o -name "*.sv" | xargs cp -t ./sim_files

find board -name synth | xargs -n1 -IAAA find AAA -name "*.v" -o -name "*.sv" | xargs cp -t ./sim_files
find ip/board -name synth | xargs -n1 -IAAA find AAA -name "*.v" -o -name "*.sv" | xargs cp -t ./sim_files

find kernel_system -name synth | xargs -n1 -IAAA find AAA -name "*.v" -o -name "*.sv" | xargs cp -t ./sim_files
find ip/kernel_system -name synth | xargs -n1 -IAAA find AAA -name "*.v" -o -name "*.sv" | xargs cp -t ./sim_files

find ddr_board -name synth | xargs -n1 -IAAA find AAA -name "*.v" -o -name "*.sv" | xargs cp -t ./sim_files
find ip/ddr_board -name synth | xargs -n1 -IAAA find AAA -name "*.v" -o -name "*.sv" | xargs cp -t ./sim_files

find msgdma_bbb -name synth | xargs -n1 -IAAA find AAA -name "*.v" -o -name "*.sv" | xargs cp -t ./sim_files
find ip/msgdma_bbb -name synth | xargs -n1 -IAAA find AAA -name "*.v" -o -name "*.sv" | xargs cp -t ./sim_files

find kernel_hdl -type f | xargs cp -t ./sim_files

find ./ip/*.v | xargs cp -t ./sim_files
find ./ip/*.sv | xargs cp -t  ./sim_files

cp -rf ccip_std_afu.sv ./sim_files/ccip_std_afu.sv
find *.sv  | xargs cp -t ./sim_files

cp -f ccip_iface/avmm_ccip_host.sv ./sim_files
cp -f ccip_iface/ccip_avmm_mmio.sv ./sim_files

cp -rf extra_sim_files/global_routing.v ./sim_files/global_routing.v
cp -rf system.v ./sim_files/system.v
cp -rf bsp_logic.sv ./sim_files/bsp_logic.sv
cp -fr hw sim_files/mpf
rm simulation.tar.gz
tar -zcvf simulation.tar.gz sim_files sys_description.hex *.hex 
cp -rf simulation.tar.gz fpga.bin
