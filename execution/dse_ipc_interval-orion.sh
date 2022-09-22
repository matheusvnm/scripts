#!/bin/bash
execute_app_ntimes() {
    for ((ITER=0;ITER<5;ITER++))
    do  
        cd $BASE_PATH
        set_baseline_temp
        echo "DSE - IPC - Interval!"
        echo "APP:" $APP
        echo "ITER:" $ITER
        echo "CONFIG:" $CONFIG
        echo "OMP_NUM_THREADS:" $OMP_NUM_THREADS
        echo "OMP_PROC_BIND:" $OMP_PROC_BIND
        echo "OMP_PLACES:" $OMP_PLACES
        execute_app
    done
}

set_baseline_temp() {
    TEMPERATURE=$(sensors | grep Package | awk '{print $4}' | sed 's/[^0-9\.]*//g' | tr "." " " | awk '{print $1}')
    while [ $TEMPERATURE -gt 35 ];
    do
        echo "Baseline temperature of:" $TEMPERATURE
        sleep 5
        TEMPERATURE=$(sensors | grep Package | awk '{print $4}' | sed 's/[^0-9\.]*//g' | tr "." " " | awk '{print $1}')
    done
}

execute_app() {
    if [ $APP = "hpcg" ]
    then
        cd $BASE_PATH/Benchs/HPCG
        COMMAND="$APP 256 256 256"
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
    else 
        cd $BASE_PATH/Benchs/Executaveis
        COMMAND="$APP"
    fi
    ./$COMMAND >> $BASE_PATH/Results/DSE/$CONFIG.txt
    echo "Última configuração executada é: $CONFIG" > $BASE_PATH/last_config.txt
}

export BASE_PATH="/home/smmarques/TBFT"
export OMP_NUM_THREADS=24
export OMP_PLACES=cores
export OMP_PROC_BIND=close

for i in {0..23}
do
    echo "ondemand" > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_governor
    if [ $? != 0 ]
    then 
        echo "Erro when configuring the governor policy."
        exit -1
    fi
done

export OMP_POSEIDON_BOOST_PATH=$BASE_PATH/Compiler/gcc-9.4.0/libgomp/
export LD_LIBRARY_PATH=$BASE_PATH/Compiler/gcc-build/lib64:$LD_LIBRARY_PATH

metrics=("performance" "temperature")
applications=("tpacf" "kripke.exe" "lud_omp" "hpcg" "sp.C.x")
ipc_values_performance=("0.4" "0.5" "0.6" "0.7" "0.8" "0.9" "1.0")
ipc_values_temperature=("0.5" "0.6" "0.7" "0.8" "0.9" "1.0" "1.1" "1.2")
intervals=("1" "2" "3" "4" "5")
sleep 5

for metric in "${metrics}"
do
    export OMP_POSEIDON=$metric
    for interval in "${intervals[@]}"
    do
        systemctl stop kubelet 2> /dev/null 
        systemctl stop docker 2> /dev/null 
        systemctl stop containerd 2> /dev/null

        if [ $metric = "performance" ]
        then 
            for ipc in "${ipc_values_performance[@]}"
            do
                export IPC_TARGET=$ipc
                export TIME_TARGET=$interval
                for app in "${applications[@]}"
                do
                    export APP=$app
                    export CONFIG=$app.$metric.dse.$ipc.$interval
                    execute_app_ntimes
                done
            done
        else
            for ipc in "${ipc_values_temperature[@]}"
            do
                export IPC_TARGET=$ipc
                export TIME_TARGET=$interval
                for app in "${applications[@]}"
                do
                    export APP=$app
                    export CONFIG=$app.$metric.dse.$ipc.$interval
                    execute_app_ntimes
                done
            done
        fi 
    done
done