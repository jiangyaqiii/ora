#!/bin/bash

if [[ $(docker ps -qf name=ora-tora) ]]; then
    echo "ora-tora正在运行"
else
    echo "停止"
fi
