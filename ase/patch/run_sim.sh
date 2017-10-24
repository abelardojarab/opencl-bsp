echo $KDIR
mkdir qsys_files
rm  -fr qsys_files/*

cp -R $KDIR/sim_files/* ./qsys_files
mkdir ./qsys_files_vhd
mv qsys_files/*.vhd ./qsys_files_vhd
#cp /swip_build/releases/acds/17.0/248/linux64/quartus/eda/sim_lib/*.vhd ./qsys_files_vhd


(cat vlog_files_base.list ; find ./qsys_files | grep -v ./qsys_files/BBB_ ) > ./vlog_files.list

echo > ./vhdl_files.list
find $ALTERAOCLSDKROOT/ip/dspba_library_package.vhd >> ./vhdl_files.list
find $ALTERAOCLSDKROOT/ip/dspba_library.vhd >> ./vhdl_files.list
(find ./qsys_files_vhd | grep -v mpf ) >> ./vhdl_files.list


#this command generates this flow but leaves out "-full64"
#quartus_sh --simlib_comp -tool vcsmx -language vhdl -family "arria10"
echo "
altera : ./vhdl_libs/altera
lpm : ./vhdl_libs/lpm
sgate : ./vhdl_libs/sgate
altera_mf : ./vhdl_libs/altera_mf
altera_lnsim : ./vhdl_libs/altera_lnsim
twentynm : ./vhdl_libs/twentynm
twentynm_hssi : ./vhdl_libs/twentynm_hssi
twentynm_hip : ./vhdl_libs/twentynm_hip
" >> synopsys_sim.setup

mkdir -p ./vhdl_libs/altera
vhdlan  -nc -full64 -work altera $QUARTUS_HOME/eda/sim_lib/altera_syn_attributes.vhd 
vhdlan  -nc -full64 -work altera $QUARTUS_HOME/eda/sim_lib/altera_standard_functions.vhd 
vhdlan  -nc -full64 -work altera $QUARTUS_HOME/eda/sim_lib/alt_dspbuilder_package.vhd 
vhdlan  -nc -full64 -work altera $QUARTUS_HOME/eda/sim_lib/altera_europa_support_lib.vhd 
vhdlan  -nc -full64 -work altera $QUARTUS_HOME/eda/sim_lib/altera_primitives_components.vhd 
vhdlan  -nc -full64 -work altera $QUARTUS_HOME/eda/sim_lib/altera_primitives.vhd 
mkdir -p ./vhdl_libs/lpm
vhdlan  -nc -full64 -work lpm $QUARTUS_HOME/eda/sim_lib/220pack.vhd 
vhdlan  -nc -full64 -work lpm $QUARTUS_HOME/eda/sim_lib/220model.vhd 
mkdir -p ./vhdl_libs/sgate
vhdlan  -nc -full64 -work sgate $QUARTUS_HOME/eda/sim_lib/sgate_pack.vhd 
vhdlan  -nc -full64 -work sgate $QUARTUS_HOME/eda/sim_lib/sgate.vhd 
mkdir -p ./vhdl_libs/altera_mf
vhdlan  -nc -full64 -work altera_mf $QUARTUS_HOME/eda/sim_lib/altera_mf_components.vhd 
vhdlan  -nc -full64 -work altera_mf $QUARTUS_HOME/eda/sim_lib/altera_mf.vhd 
mkdir -p ./vhdl_libs/altera_lnsim
vlogan -sverilog -nc -full64 -work altera_lnsim $QUARTUS_HOME/eda/sim_lib/altera_lnsim.sv 
vhdlan  -nc -full64 -work altera_lnsim $QUARTUS_HOME/eda/sim_lib/altera_lnsim_components.vhd 
mkdir -p ./vhdl_libs/twentynm
vlogan +v2k5 -nc -full64 -work twentynm $QUARTUS_HOME/eda/sim_lib/synopsys/twentynm_atoms_ncrypt.v 
vhdlan  -nc -full64 -work twentynm $QUARTUS_HOME/eda/sim_lib/twentynm_atoms.vhd 
vhdlan  -nc -full64 -work twentynm $QUARTUS_HOME/eda/sim_lib/twentynm_components.vhd 
mkdir -p ./vhdl_libs/twentynm_hssi
vlogan +v2k5 -nc -full64 -work twentynm_hssi $QUARTUS_HOME/eda/sim_lib/synopsys/twentynm_hssi_atoms_ncrypt.v 
vhdlan  -nc -full64 -work twentynm_hssi $QUARTUS_HOME/eda/sim_lib/twentynm_hssi_components.vhd 
vhdlan  -nc -full64 -work twentynm_hssi $QUARTUS_HOME/eda/sim_lib/twentynm_hssi_atoms.vhd 
mkdir -p ./vhdl_libs/twentynm_hip
vlogan +v2k5 -nc -full64 -work twentynm_hip $QUARTUS_HOME/eda/sim_lib/synopsys/twentynm_hip_atoms_ncrypt.v 
vhdlan  -nc -full64 -work twentynm_hip $QUARTUS_HOME/eda/sim_lib/twentynm_hip_components.vhd 
vhdlan  -nc -full64 -work twentynm_hip $QUARTUS_HOME/eda/sim_lib/twentynm_hip_atoms.vhd 

set -e

#different hacks to extend mmio timeout
#export SNPS_VLOGAN_OPT=" +define+MMIO_RESPONSE_TIMEOUT=32768 "
#echo -e "+define+MMIO_RESPONSE_TIMEOUT=32768\n$(cat rtl/sources.txt)" > rtl/sources.txt

#hack to fix vhdl compilation.  replace '-F' with '-f'
#https://jira01.devtools.intel.com/browse/OPAE-641
sed -i -E 's;(vhdlan.*)-F;\1-f;g' Makefile

#hack ASE for interrupts on non-DCP platform(because DCP mem model is slow)
sed -i -e 's/undef\s\+ASE_ENABLE_INTR_FEATURE/define  ASE_ENABLE_INTR_FEATURE/' ./sw/ase_common.h
sed -i -e 's/undef\s\+ASE_ENABLE_INTR_FEATURE/define  ASE_ENABLE_INTR_FEATURE/' ./rtl/platform.vh
sed -i -e 's/define\s\+FORWARDING_CHANNEL\s\+outoforder_wrf_channel/define FORWARDING_CHANNEL  inorder_wrf_channel/' ./rtl/platform.vh

make OPAE_BASEDIR=$OPAE_INSTALL_PATH/../opae_src
cp $KDIR/*.hex ./work/
make sim&

ASE_READY_FILE=./work/.ase_ready.pid

while [ ! -f $ASE_READY_FILE ]
do
	echo "Waiting for simulation to start..."
	sleep 1
done

echo "simulation is ready!"
