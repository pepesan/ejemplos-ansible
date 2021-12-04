#!/bin/bash

file="/home/pepesan/count.cnt"

if [ -e ${file} ]; then
    count=$(cat ${file})
else
    count=0
fi

((count++))

echo ${count} > ${file}

echo Loaded ${count} times
