#!/bin/bash
SHELL_FOLDER=$(
    cd "$(dirname "$0")"
    pwd
)
CONFIG_FILE="config.sh"
cd "$SHELL_FOLDER"

echo "塞尔达传说信息收集客户端" >&2
echo "当前工作目录是 $(pwd)" >&2

if [ ! -f "$CONFIG_FILE" ] || [ ! -x "$CONFIG_FILE" ]; then
    logE "错误：在工作目录找不到配置文件 $CONFIG_FILE 或该文件不可执行。"
    exit 2
fi

. ./$CONFIG_FILE
. ./functions.sh

filePath=${1-"$(date +%Y-%m-%d).csv"}
if [ ! -f "$filePath" ]; then
    logE "错误：在工作目录找不到 $filePath ，请先运行 ./edit.sh 进行编写"
    exit 3
fi

function sendFileNow {
    log "正在与服务器建立连接并发送文件"
    connectAndSendCSV "$USER_STUDENT_ID" "${filePath}" "${2-"$SERVER_ADDRESS"}" "${3-"$SERVER_PORT"}"
}
sendFileNow
senderExitCode=$?

while ((senderExitCode != 0)); do
    read -p "发送文件失败失败，是否重试？[y/n] " yn
    case $yn in
    [Yy]*)
        sendFileNow
        senderExitCode=$?
        ;;
    [Nn]*)
        log "未发送报告文件，你稍后可自行运行 ./client \"$filePath\" 来发送文件"
        exit 1
        ;;
    *) echo "Yes or no." ;;
    esac
done

log "发送结束"