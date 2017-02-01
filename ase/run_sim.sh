echo $KDIR
mkdir qsys_files
rm  qsys_files/*

cp $KDIR/sim_files/* ./qsys_files
rm qsys_files/*.vhd

###setup MPF with ASE
ln -s $MPF_INSTALL_PATH mpf_src

pkill -9 ase_simv

(cat vlog_files_base.list ; find ./qsys_files ) > ./vlog_files.list
make
cp $KDIR/*.hex ./work/
make sim&


while [ ! -f ./work/inter.vpd]
do
  sleep 1
done

sleep 15