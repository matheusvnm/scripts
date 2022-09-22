#!/bin/bash

execute_app() {
    if [ $APP = "nn" ]
    then
        cd $BASE_PATH/Benchs/rodinia_3.1/openmp/nn/
        COMMAND="$APP filelist_4 100000 1000 2000"
    elif [ $APP = "histo" ]
    then
        cd $BASE_PATH/Benchs/parboil/
        COMMAND="parboil run $APP omp_base default"
    elif [ $APP = "spmv" ]
    then	
        cd $BASE_PATH/Benchs/parboil/
        COMMAND="parboil run $APP omp_base large"
    elif [ $APP = "sc_omp" ]
    then
        cd $BASE_PATH/Benchs/rodinia_3.1/openmp/streamcluster/
        COMMAND="$APP 15 30 512 65536 65536 1000 none ouput.txt $OMP_NUM_THREADS"
    elif [ $APP = "hpcg" ]
    then
        cd $BASE_PATH/Benchs/HPCG
        COMMAND="$APP 256 256 128"
    elif [ $APP = "lud_omp" ]
    then
        cd $BASE_PATH/Benchs/rodinia_3.1/openmp/lud/omp
        COMMAND="$APP -s 16000"
    elif [ $APP = "tpacf" ]
    then	
        cd $BASE_PATH/Benchs/parboil/
        COMMAND="parboil run $APP omp_base medium"
    elif [ $APP = "kripke.exe" ]
    then
        cd $BASE_PATH/Benchs/LLNL/Kripke/build/bin
        COMMAND="$APP --zones 32,32,32 --niter 20"
    elif [ $APP = "qs" ]
    then
        cd $BASE_PATH/Benchs/LLNL/Quicksilver/src
        COMMAND="$APP -N 70"
    else 
        cd $BASE_PATH/Benchs/Executaveis
        COMMAND="$APP"
    fi
    ./$COMMAND >> $BASE_PATH/Results/Exaustive/$CONFIG.txt
}


export BASE_PATH="/home/smmarques/TBFT"
export PROCESSOR="AMDProcessors"
export OMP_NUM_THREADS=64
export OMP_PLACES=cores
export OMP_PROC_BIND=close
export AMDuProfPcm=/opt/AMDuProf_3.5-671/bin/AMDuProfPcm

for i in {0..63}
do
    echo "ondemand" > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor
    if [ $? != 0 ]
    then 
        echo "Erro when configuring the governor policy."
        exit -1
    fi
done


echo "Tracing..."
echo 0 > /sys/devices/system/cpu/cpufreq/boost
threads=("2" "4" "6" "8" "10" "12" "14" "16" "18" "20" "22" "24" "26" "28" "30" "32" "36" "40" "44" "48" "56" "64")
applications=("ja" "hpcg" "nn" "sp.C.x" "histo" "spmv" "tr" "sc_omp" "lud_omp" "kripke.exe" "qs" "tpacf")
modes=("turbo" "noturbo")

systemctl stop kubelet 2> /dev/null 
systemctl stop docker 2> /dev/null 
systemctl stop containerd 2> /dev/null 

for app in "${applications[@]}"
do
    export APP=$app
    for mode in "${modes[@]}"
    do
        if [ mode = "turbo" ]
        then 
            echo "Activating Turbo Mode"
            echo 1 > /sys/devices/system/cpu/cpufreq/boost
        else 
            echo "Deactivating Turbo Mode"
            echo 0 > /sys/devices/system/cpu/cpufreq/boost
        fi 
        for thread in "{threads[@]}"
        do
            export CONFIG=$app.$config.$mode
            execute_app
            echo "Cooling down..."
            sleep 10
        done
    done
done
