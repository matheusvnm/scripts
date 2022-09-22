#!/bin/bash

execute_app() {
    if [ $APP = "nn" ]; then
        cd $BASE_PATH/Benchs/rodinia_3.1/openmp/nn/
        COMMAND="$APP filelist_4 100000 1000 2000"
    elif [ $APP = "histo" ]; then
        cd $BASE_PATH/Benchs/parboil/
        COMMAND="parboil run $APP omp_base default"
    elif [ $APP = "spmv" ]; then
        cd $BASE_PATH/Benchs/parboil/
        COMMAND="parboil run $APP omp_base large"
    elif [ $APP = "sc_omp" ]; then
        cd $BASE_PATH/Benchs/rodinia_3.1/openmp/streamcluster/
        COMMAND="$APP 15 30 512 65536 65536 1000 none output.txt $OMP_NUM_THREADS"
    elif [ $APP = "hpcg" ]; then
        cd $BASE_PATH/Benchs/HPCG
        COMMAND="$APP 256 256 128"
    elif [ $APP = "lud_omp" ]; then
        cd $BASE_PATH/Benchs/rodinia_3.1/openmp/lud/omp
        COMMAND="$APP -s 16000"
    elif [ $APP = "tpacf" ]; then
        cd $BASE_PATH/Benchs/parboil/
        COMMAND="parboil run $APP omp_base medium"
    elif [ $APP = "kripke.exe" ]; then
        cd $BASE_PATH/Benchs/LLNL/Kripke/build/bin
        COMMAND="$APP --zones 32,32,32 --niter 20"
    elif [ $APP = "qs" ]; then
        cd $BASE_PATH/Benchs/LLNL/Quicksilver/src
        COMMAND="$APP -N 70"
    else
        cd $BASE_PATH/Benchs/Executaveis
        COMMAND="$APP"
    fi
    echo "Starting to execute the app $APP with the command $COMMAND"
    echo "Basepath of $BASE_PATH"
    perf stat -a -e msr/tsc/,instructions,ls_not_halted_cyc,ls_dispatch.store_dispatch,ls_dispatch.ld_dispatch -o $BASE_PATH/Results/Profile/$APP.txt ./$COMMAND
}

echo "Configuration for Bagual"
export BASE_PATH="/home/smmarques/TBFT"
export OMP_NUM_THREADS=64
export OMP_PLACES=CORES
export OMP_PROC_BIND=CLOSE
kernels=("histo" "hpcg" "ja" "kripke.exe" "lud_omp" "nn" "qs" "sc_omp" "sp.C.x" "spmv" "tr" "tpacf")
for i in {0..63}; do
    echo "ondemand" >/sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor
    cat /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor
done

echo "Deactivating Turbo"
echo 0 >/sys/devices/system/cpu/cpufreq/boost
sleep 5

for APP in "${kernels[@]}"; do
    systemctl stop kubelet 2> /dev/null 
    systemctl stop docker 2> /dev/null 
    systemctl stop containerd 2> /dev/null 

    cd $BASE_PATH
    execute_app
done
