echo $KDIR
mkdir qsys_files
rm  -fr qsys_files/*

cp -R $KDIR/sim_files/* ./qsys_files
mkdir ./qsys_files_vhd
mv qsys_files/*.vhd ./qsys_files_vhd


(cat vlog_files_base.list ; find ./qsys_files | grep -v ./qsys_files/BBB_ ) > ./vlog_files.list

echo > ./vhdl_files.list
if [ "$DCP_BSP_TARGET" == "dcp_s10" ]
then
    #hack to work around compilation errors
    cp -rf $AOCL_BOARD_PACKAGE_ROOT/ase/bsp/extra_sim_files/hld_fifo.sv qsys_files/hld_fifo.sv
    cp -rf $AOCL_BOARD_PACKAGE_ROOT/ase/bsp/extra_sim_files/platform_afu_top_config.vh rtl/platform_afu_top_config.vh
    #dspba_library must be first!
    (find ./qsys_files_vhd | grep -v mpf | grep dspba_library) >> ./vhdl_files.list
    (find ./qsys_files_vhd | grep -v mpf | grep -v dspba_library) >> ./vhdl_files.list
else
    find $ALTERAOCLSDKROOT/ip/dspba_library_package.vhd >> ./vhdl_files.list
    find $ALTERAOCLSDKROOT/ip/dspba_library.vhd >> ./vhdl_files.list
    (find ./qsys_files_vhd | grep -v mpf ) >> ./vhdl_files.list
fi

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
fourteennm : ./vhdl_libs/fourteennm
#fourteennm_hssi : ./vhdl_libs/fourteennm_hssi
#fourteennm_hip : ./vhdl_libs/fourteennm_hip
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

mkdir -p ./vhdl_libs/fourteennm
vlogan +v2k5 -nc -full64 -work fourteennm $QUARTUS_HOME/eda/sim_lib/synopsys/fourteennm_atoms_ncrypt.sv 
vhdlan  -nc -full64 -work fourteennm $QUARTUS_HOME/eda/sim_lib/fourteennm_atoms.vhd 
vhdlan  -nc -full64 -work fourteennm $QUARTUS_HOME/eda/sim_lib/fourteennm_components.vhd 
#mkdir -p ./vhdl_libs/fourteennm_hssi
#vlogan +v2k5 -nc -full64 -work fourteennm_hssi $QUARTUS_HOME/eda/sim_lib/synopsys/fourteennm_hssi_atoms_ncrypt.v 
#vhdlan  -nc -full64 -work fourteennm_hssi $QUARTUS_HOME/eda/sim_lib/fourteennm_hssi_components.vhd 
#vhdlan  -nc -full64 -work fourteennm_hssi $QUARTUS_HOME/eda/sim_lib/fourteennm_hssi_atoms.vhd 
#mkdir -p ./vhdl_libs/fourteennm_hip
#vlogan +v2k5 -nc -full64 -work fourteennm_hip $QUARTUS_HOME/eda/sim_lib/synopsys/fourteennm_hip_atoms_ncrypt.v 
#vhdlan  -nc -full64 -work fourteennm_hip $QUARTUS_HOME/eda/sim_lib/fourteennm_hip_components.vhd 
#vhdlan  -nc -full64 -work fourteennm_hip $QUARTUS_HOME/eda/sim_lib/fourteennm_hip_atoms.vhd 
set -e

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
