#!/bin/bash

set_turbo() {
    if [ $1 = "turbo" ]
    then
        echo "Enabling Turbo for" $2
        echo 1 > /sys/devices/system/cpu/cpufreq/boost
    else
        echo "Disabling Turbo for" $2
        echo 0 > /sys/devices/system/cpu/cpufreq/boost
    fi

}

start_execution() {
    for APP in "${applications[@]}"
    do
        export CONFIG=$APP
        for PARAMETER in "$@"
        do
            export CONFIG+=.$PARAMETER
        done
        for ((ITER=0;ITER<15;ITER++))
        do  
            cd $BASE_PATH
            set_baseline_temp
            echo "APP:" $APP
            echo "ITER:" $ITER
            echo "CONFIG:" $CONFIG
            echo "OMP_NUM_THREADS:" $OMP_NUM_THREADS
            echo "OMP_PROC_BIND:" $OMP_PROC_BIND
            echo "OMP_PLACES:" $OMP_PLACES
            export ITER=$ITER
            ./monitor_temperature.sh &
            APP_TEMP=$!
            execute_app
            kill -9 $APP_TEMP
        done
    done
}

compile_technique() {
    cd $BASE_PATH/Compiler/gcc-9.4.0/
    cp ../$config/$PROCESSOR/* libgomp/
    make -j4 && make install 
    if [ $? != 0 ]
    then 
        echo "Erro de compilação."
        exit -1
    fi
}

set_baseline_temp() {
    TEMPERATURE=$(sensors | grep Tctl | sed 's/[^0-9\.]*//g' | tr "." " " | awk '{print $1}')
    while [ $TEMPERATURE -gt 45 ];
    do
        echo "Baseline temperature of:" $TEMPERATURE
        sleep 5
        TEMPERATURE=$(sensors | grep Tctl | sed 's/[^0-9\.]*//g' | tr "." " " |awk '{print $1}')
    done
}

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
    elif [ $APP = "qs" ]
    then
        cd $BASE_PATH/Benchs/LLNL/Quicksilver/src
        COMMAND="$APP -N 70"
    else 
        cd $BASE_PATH/Benchs/Executaveis
        COMMAND="$APP"
    fi
    ./$COMMAND >> $BASE_PATH/Results/Time/$CONFIG.txt
}


export BASE_PATH="/home/smmarques/TBFT"
export PROCESSOR="AMDProcessors"
export IPC_TARGET=0.6
export TIME_TARGET=2
export OMP_NUM_THREADS=64
export OMP_PLACES=cores
export OMP_PROC_BIND=close

for i in {0..63}
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
echo 0 > /sys/devices/system/cpu/cpufreq/boost

urano_metrics=("performance")
budget_power_values=("70" "140" "210" "280")
budget_power_modes=("turbo" "noturbo")
omp_dynamic_modes=("turbo" "noturbo")
baseline_modes=("turbo" "noturbo")

applications=("histo" "hpcg" "ja" "kripke.exe" "lud_omp" "nn" "qs" "sc_omp" "sp.C.x" "spmv" "tr" "tpacf")
configs=("omp_budget")
sleep 5


for config in "${configs[@]}"
do
    systemctl stop kubelet 2> /dev/null 
    systemctl stop docker 2> /dev/null 
    systemctl stop containerd 2> /dev/null 

    if [ $config = "tbft" ]
    then
        compile_technique
        for metric in "${urano_metrics[@]}"
        do  
            export OMP_POSEIDON=$metric
            start_execution $config $metric
            unset OMP_POSEIDON
        done

    elif [ $config = "omp_budget" ]
    then
        compile_technique
        for mode in "${budget_power_modes[@]}"
        do  
            set_turbo $mode $config
            for power_budget in "${budget_power_values[@]}"
            do 
                export OMP_BUDGET=TRUE
                export OMP_BUDGET_VALUE=$power_budget
                start_execution $config $mode $power_budget
                unset OMP_BUDGET
                unset OMP_BUDGET_VALUE
            done
        done

    elif [ $config = "omp_dynamic" ]
    then
        for mode in "${omp_dynamic_modes[@]}"
        do  
            export OMP_DYNAMIC=true
            set_turbo $mode $config
            start_execution $config.$mode
            unset OMP_DYNAMIC 
        done

    else
        for mode in "${baseline_modes[@]}"
        do
            set_turbo $mode $config
            start_execution $config $mode
        done
    fi 
done
