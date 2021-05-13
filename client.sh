#!/bin/bash
SHELL_FOLDER=$(cd "$(dirname "$0")";pwd)
CONFIG_FILE="config.sh"
cd "$SHELL_FOLDER"

echo "塞尔达传说信息收集客户端" >&2
echo "当前工作目录是 $(pwd)" >&2

if [ ! -f "$CONFIG_FILE" ] || [ ! -x "$CONFIG_FILE" ]; then
    log "错误：在工作目录找不到配置文件 $CONFIG_FILE 或该文件不可执行。"
    exit 2
fi

. ./$CONFIG_FILE
. ./functions.sh

log "正在与服务器建立连接"

function connectAndSendCSV {
    checkParamNum 2 $*
    local studentId="$1"
    local file="$2"
    local server="${SERVER_ADDRESS-"localhost"}"
    local port="${SERVER_PORT-"45123"}"
    connectServer "$server" "$port"
    log "连接成功"

    sendHeader
    sendType "add"
    sendLine "$studentId"
    sendFile "$file"
    sendFooter

    disconnectServer
}