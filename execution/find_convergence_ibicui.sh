#!/bin/bash

execute_app_ntimes() {
    for ((ITER = 0; ITER < 5; ITER++)); do
        echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo
        cd $BASE_PATH
        set_baseline_temp
        echo "APP:" $APP
        echo "ITER:" $ITER
        echo "CONFIG:" $CONFIG
        echo "OMP_NUM_THREADS:" $OMP_NUM_THREADS
        echo "OMP_PROC_BIND:" $OMP_PROC_BIND
        echo "OMP_PLACES:" $OMP_PLACES
        export ITER=$ITER
        execute_app
    done
}

set_baseline_temp() {
    TEMPERATURE=$(sensors | grep Package | awk '{print $4}' | sed 's/[^0-9\.]*//g' | tr "." " " | awk '{print $1}')
    while [ $TEMPERATURE -gt 35 ]; do
        echo "Baseline temperature of:" $TEMPERATURE
        sleep 5
        TEMPERATURE=$(sensors | grep Package | awk '{print $4}' | sed 's/[^0-9\.]*//g' | tr "." " " | awk '{print $1}')
    done
}

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
        COMMAND="$APP 15 30 512 65536 65536 1000 none ouput.txt $OMP_NUM_THREADS"
    elif [ $APP = "hpcg" ]; then
        cd $BASE_PATH/Benchs/HPCG
        COMMAND="$APP 256 256 256"
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
    ./$COMMAND >>$BASE_PATH/Results/Convergence/Region/$CONFIG.txt
}

export BASE_PATH="/home/smmarques/TBFT"
export OMP_NUM_THREADS=24
export OMP_PLACES=cores
export OMP_PROC_BIND=close
export OMP_POSEIDON_BOOST_PATH=$BASE_PATH/Compiler/gcc-9.4.0/libgomp/
export LD_LIBRARY_PATH=$BASE_PATH/Compiler/gcc-build/lib64:$LD_LIBRARY_PATH

for i in {0..23}; do
    echo "ondemand" > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor
    if [ $? != 0 ]; then
        echo "Erro when configuring the governor policy."
        exit -1
    fi
done

urano_metrics=("temperature" "performance")
applications=("histo" "hpcg" "ja" "kripke.exe" "lud_omp" "nn" "qs" "sc_omp" "sp.C.x" "spmv" "tr" "tpacf")
configs=("tbft")
sleep 5

for config in "${configs[@]}"; do
    for metric in "${urano_metrics[@]}"; do
        if [ $metric = "temperature" ]; then
            export IPC_TARGET=0.9
            export TIME_TARGET=2
        else
            export IPC_TARGET=0.5
            export TIME_TARGET=3
        fi
        export OMP_POSEIDON=$metric
        for app in "${applications[@]}"; do
            export APP=$app
            export CONFIG=$app.$config.$metric
            execute_app_ntimes
        done
    done
done