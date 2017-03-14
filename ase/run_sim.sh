echo $KDIR
mkdir qsys_files
rm  -fr qsys_files/*

cp -R $KDIR/sim_files/* ./qsys_files
mkdir ./qsys_files_vhd
mv qsys_files/*.vhd ./qsys_files_vhd
#cp /swip_build/releases/acds/17.0/248/linux64/quartus/eda/sim_lib/*.vhd ./qsys_files_vhd

###setup MPF with ASE
#ln -s $MPF_INSTALL_PATH mpf_src

pkill -9 ase_simv

(cat vlog_files_base.list ; find ./qsys_files | grep -v mpf ) > ./vlog_files.list

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

make
cp $KDIR/*.hex ./work/
make sim&

#sleep for 5 seconds to make sure everything gets setup
sleep 5
