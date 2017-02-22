echo ase sim compile flow
mkdir sim_files

qsys-generate --synthesis=VERILOG --family="Arria 10" --part=10AX115U3F45E2SGE3  kernel_system.qsys
qsys-generate --synthesis=VERILOG --family="Arria 10" --part=10AX115U3F45E2SGE3  board.qsys


find ./kernel_system/synth/*.v | xargs cp -t ./sim_files
find ./kernel_system/*/synth/*.vo | xargs cp -t ./sim_files
find ./kernel_system/*/synth/*.v | xargs cp -t ./sim_files
find ./kernel_system/*/synth/*.sv| xargs cp -t  ./sim_files
find ./kernel_system/*/synth/*.vh  | xargs cp -t ./sim_files
find ./kernel_system/*/synth/*.vhd  | xargs cp -t ./sim_files
find ./board/synth/*.v | xargs cp -t ./sim_files
find ./board/*/synth/*.vo | xargs cp -t ./sim_files
find ./board/*/synth/*.v | xargs cp -t ./sim_files
find ./board/*/synth/*.sv | xargs cp -t  ./sim_files
find ./board/*/synth/*.vh  | xargs cp -t ./sim_files

find ./ip/*.v | xargs cp -t ./sim_files
find ./ip/*.sv | xargs cp -t  ./sim_files

cp -rf ccip_std_afu.sv ./sim_files/ccip_std_afu.sv
find *.sv  | xargs cp -t ./sim_files


sed -i 's/RRP_FIFO_DEPTH(64)/RRP_FIFO_DEPTH(256)/g'  ./sim_files/*_system.v

cp -rf extra_sim_files/global_routing.v ./sim_files/global_routing.v
cp -rf system.v ./sim_files/system.v
cp -rf rr_arb.v ./sim_files/rr_arb.v
cp -rf bsp_logic.sv ./sim_files/bsp_logic.sv
cp -fr hw sim_files/mpf
rm simulation.tar.gz
tar -zcvf simulation.tar.gz sim_files sys_description.hex ccip_std_afu.v *.hex 
cp -rf simulation.tar.gz fpga.bin
