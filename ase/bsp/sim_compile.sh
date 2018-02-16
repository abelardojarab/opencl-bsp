#!/bin/bash

# (C) 2017 Intel Corporation. All rights reserved.
# Your use of Intel Corporation's design tools, logic functions and other
# software and tools, and its AMPP partner logic functions, and any output
# files any of the foregoing (including device programming or simulation
# files), and any associated documentation or information are expressly subject
# to the terms and conditions of the Intel Program License Subscription
# Agreement, Intel MegaCore Function License Agreement, or other applicable
# license agreement, including, without limitation, that your use is for the
# sole purpose of programming logic devices manufactured by Intel and sold by
# Intel or its authorized distributors.  Please refer to the applicable
# agreement for further details.

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

cp -rf mem_sim_model.sv ./sim_files/mem_sim_model.sv

cp -rf ccip_std_afu.sv ./sim_files/ccip_std_afu.sv
find *.sv  | xargs cp -t ./sim_files

cp -rf extra_sim_files/global_routing.v ./sim_files/global_routing.v
cp -rf bsp_logic.sv ./sim_files/bsp_logic.sv
cp -fr BBB_* sim_files/    
rm simulation.tar.gz
tar -hzcvf simulation.tar.gz sim_files sys_description.hex *.hex 
cp -rf simulation.tar.gz fpga.bin

#copy fpga.bin to parent directory so aoc flow can find it
cp fpga.bin ../
