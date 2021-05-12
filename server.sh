#!/bin/bash
set -e

SHELL_FOLDER=$(cd "$(dirname "$0")";pwd)
CONFIG_FILE="config.sh"
cd "$SHELL_FOLDER"

echo "塞尔达传说信息收集服务器" >&2
echo "当前工作目录是 $(pwd)" >&2

if [ ! -f "$CONFIG_FILE" ] || [ ! -x "$CONFIG_FILE" ]; then
    log "错误：在工作目录找不到配置文件 $CONFIG_FILE 或该文件不可执行。"
    exit 2
fi

. ./$CONFIG_FILE
. ./functions.sh

if [ ! -f "$SERVER_DATABASE" ] ; then
    logInline "正在初始化数据库..."
    log "完成"
fi

log "版本 $VERSION  正在监听端口 $SERVER_PORT"
stdbuf -oL nc -vv -lkp $SERVER_PORT | {
    # 分隔符：NUL
    while IFS= read -d '' -r recv
    do
        # log "RECV: $recv"
        echo "$recv" | {
            IFS= read -r line
            if [[ $line != "#%?" ]]; then
                log "收到无效数据包，必须以 #%?\n 开头: $line"
            else
                logD "--- Begin Packet ---"
                IFS= read -r dType
                logD "[RECV TYPE]: $dType"

                case "$dType" in
                    # Add
                    a)
                        IFS= read -r studentId
                        currentLine=0
                        log "接收到来自 $studentId 的请求"
                        userId=${$(getUserIdByStudentId "$studentId")-"-1"}
                        if [[ $userId == "-1" ]]; then
                            logW "无此用户 $studentId"
                        else
                            while IFS= read -r line; do
                                let currentLine++
                                if [[ $line =~ "种类" ]]; then
                                    logD "Skipping header"
                                else
                                    # colNum=$(echo -n -e "$line" | grep -o $'\t' | wc -l | wc -l)
                                    read mainType subType sku x y < <(echo "$line")
                                    if [ ! -n "$y" ]; then
                                        logW "第 $currentLine 行有错误，每行数据必须有 5 列"
                                    else
                                          
                                    fi
                                fi
                            done
                        fi
                    ;;

                    *)
                        logD "<!> Unknown type, Logging: $dType"
                        while IFS= read -r line; do
                            logD "[RECV]: $line"
                        done
                    ;;
                esac
                logD "--- End Packet ---"
            fi
        }

        # echo "RECV PACKET: $recv"
    done
}