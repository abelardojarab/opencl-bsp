#!/bin/bash
ID_LOW_1=$1
ID_HIGH_1=$2
ID_LOW_2=$3
ID_HIGH_2=$4
PROJ_REV_NAME="skx_pr_afu"
cd output_files/

MSF_FILE=`ls $PROJ_REV_NAME.persona1.msf`
MSF_EXISTS=$?
echo "MSF file : $MSF_FILE"

SOF_FILE=`ls $PROJ_REV_NAME.sof`
SOF_EXISTS=$?
echo "SOF file : $SOF_FILE"

PMSF_FILE=$PROJ_REV_NAME.pmsf
echo "PMSF file: $PMSF_FILE"

RBF_FILE=$PROJ_REV_NAME.rbf
echo "RBF file : $RBF_FILE"

if [ $MSF_EXISTS -eq 0 ]
then
        if [ $SOF_EXISTS -eq 0 ]
        then
                quartus_cpf -p $MSF_FILE $SOF_FILE $PMSF_FILE
                PMSF_CREATED=$?
        else
                PMSF_CREATED=1
                echo "Failed to generate PMSF file. SOF file not found"
        fi
else
        PMSF_CREATED=1
        echo "Failed to generate PMSF file. MSF file not found"
fi

if [ $PMSF_CREATED -eq 0 ]
then
        echo "Generated PMSF file"
        quartus_cpf -c $PMSF_FILE $RBF_FILE
        RBF_CREATED=$?
        if [ $RBF_CREATED -eq 0 ]
        then
                echo "Generated GBS file"
                cp ../lnkpr2sr .
				chmod 777 lnkpr2sr 
                ./lnkpr2sr 0x$ID_LOW_1 0x$ID_HIGH_1 0x$ID_LOW_2 0x$ID_HIGH_2

        else
                echo "Failed to create GBS file"        
        fi
else
        echo "Failed to create RBF file. No PMSF file"
fi

cd ../

