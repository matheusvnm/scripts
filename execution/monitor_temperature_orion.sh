#!/bin/bash

while :
do
    temp=$(sensors | grep Package)
    echo $temp >> $BASE_PATH/Results/Temp/$CONFIG.$ITER.txt    
    sleep 1s
done