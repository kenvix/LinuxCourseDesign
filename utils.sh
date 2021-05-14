#!/bin/bash
SHELL_FOLDER=$(
    cd "$(dirname "$0")"
    pwd
)
CONFIG_FILE="config.sh"
cd "$SHELL_FOLDER"

if [ ! -f "$CONFIG_FILE" ] || [ ! -x "$CONFIG_FILE" ]; then
    logE "错误：在工作目录找不到配置文件 $CONFIG_FILE 或该文件不可执行。"
    exit 2
fi

. ./$CONFIG_FILE
. ./functions.sh

$*