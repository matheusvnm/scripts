#!/bin/bash

while :
do
    temp=$(sensors | grep Tctl)
    echo $temp >> $BASE_PATH/Results/Temp/$CONFIG.$ITER.txt    
    sleep 1s
done