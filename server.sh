#!/bin/bash

SHELL_FOLDER=$(
    cd "$(dirname "$0")"
    pwd
)
CONFIG_FILE="config.sh"
EMBEDDING_MODE=0
HANDLE_REQUEST=0

set -- $(getopt -q -o h --long embedding,handle-request -- "$@")

while [ -n "$1" ]; do
    case "$1" in
    --embedding) EMBEDDING_MODE=1 ;;
    --handle-request) HANDLE_REQUEST=1 ;;
    --)
        shift
        break
        ;;
    *) echo "$1 is not option" ;;
    esac

    shift
done

cd "$SHELL_FOLDER"

if [ ! -f "$CONFIG_FILE" ] || [ ! -x "$CONFIG_FILE" ]; then
    log "错误：在工作目录找不到配置文件 $CONFIG_FILE 或该文件不可执行。"
    exit 2
fi

. ./$CONFIG_FILE
. ./functions.sh

function handleRequest {
    # 分隔符：NUL
    while IFS= read -t 10 -d '' -r recv; do
        # log "RECV: $recv"
        echo "$recv" | {
            IFS= read -t 0.1 -r line
            if [[ $line != "#%?" ]]; then
                log "收到无效数据包，必须以 #%?\n 开头: $line"
            else
                logD "--- Begin Packet ---"
                IFS= read -t 0.1 -r dType
                logD "[RECV TYPE]: $dType"

                case "$dType" in
                # Add
                add)
                    IFS= read -t 0.1 -r studentId
                    currentLine=0
                    log "接收到来自 $studentId 的请求"
                    _sqlUserId=$(getUserIdByStudentId "$studentId")
                    userId=${_sqlUserId-"-1"}
                    if [[ $userId == "" || $userId == "-1" ]]; then
                        logW "无此用户 $studentId"
                    else
                        IFS= read -t 0.1 -r dNum
                        logD "开始处理 $userId ($studentId)，共 $dNum 个"
                        for ((currentLine = 1; currentLine <= $dNum; currentLine++)); do
                            logD "开始处理 $currentLine/$dNum"

                            # colNum=$(echo -n -e "$line" | grep -o $'\t' | wc -l | wc -l)
                            read -t 0.1 mainType subType sku x y
                            if [[ $mainType =~ "种类" ]]; then
                                logD "Skipping header"
                            else
                                log "正在处理：$mainType $subType $sku $x $y"
                                if [ ! -n "$y" ]; then
                                    logW "第 $currentLine 行有错误，每行数据必须有 5 列"
                                else
                                    addElementOrIncKillNumByTypeName "$mainType" "$subType" "$sku" "$userId" "$x" "$y"
                                    exitCode=$?
                                    if (($exitCode == 0)); then
                                        logD "处理成功"
                                    else 
                                        logD "处理出错：$exitCode"
                                    fi
                                fi
                            fi
                        done
                        logD "处理结束"
                    fi
                    ;;

                *)
                    logD "<!> Unknown type, Logging: $dType"
                    while IFS= read -t 0.1 -r line; do
                        logD "[RECV]: $line"
                    done
                    ;;
                esac

                logD "--- End Packet ---"
            fi
        }

        # echo "RECV PACKET: $recv"
    done
    exit 0
}

if [ $EMBEDDING_MODE -ne 0 ]; then
    if [ $HANDLE_REQUEST -ne 0 ]; then
        handleRequest
        exit $?
    fi
else
    echo "塞尔达传说信息收集服务器" >&2
    echo "当前工作目录是 $(pwd)" >&2

    if [ ! -f "$SERVER_DATABASE" ]; then
        logInline "正在初始化数据库..."
        cp "template.sqlite3" "$SERVER_DATABASE"
        log "完成"
    fi

    if command -v nc.traditional &>/dev/null; then
        logD "Found Debian traditional netcat"
        netcat="nc.traditional"
    else
        netcat="nc"
    fi

    log "版本 $VERSION  正在监听端口 $SERVER_PORT"
    while true; do
        $netcat -vv -lkp $SERVER_PORT -c "./server.sh --embedding --handle-request"

        if [ $? -ne 0 ]; then
            logW "nc 似乎未能监听端口，请确保端口未占用。同时也请确保你使用的是 nc.traditional 而非 BSD netcat. 在 Debian 上，使用 update-alternatives --config nc 切换"
            break
        fi
    done
fi