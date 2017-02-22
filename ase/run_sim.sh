echo $KDIR
mkdir qsys_files
rm  -fr qsys_files/*

cp -R $KDIR/sim_files/* ./qsys_files
rm qsys_files/*.vhd

###setup MPF with ASE
#ln -s $MPF_INSTALL_PATH mpf_src

pkill -9 ase_simv

(cat vlog_files_base.list ; find ./qsys_files | grep -v mpf ) > ./vlog_files.list
make
cp $KDIR/*.hex ./work/
make sim&
