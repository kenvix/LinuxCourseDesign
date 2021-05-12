#!/bin/bash
SHELL_FOLDER=$(cd "$(dirname "$0")";pwd)
CONFIG_FILE="config.sh"
cd "$SHELL_FOLDER"

echo "塞尔达传说信息收集编辑器" >&2
echo "当前工作目录是 $(pwd)" >&2

if [ ! -f "$CONFIG_FILE" ] || [ ! -x "$CONFIG_FILE" ]; then
    log "错误：在工作目录找不到配置文件 $CONFIG_FILE 或该文件不可执行。"
    exit 2
fi

. ./$CONFIG_FILE
. ./functions.sh

filePath=${1-"$(date +%Y-%m-%d).csv"}
if [ ! -f "$filePath" ]; then
    log "将创建当日的汇报文件：$filePath"
    cp "template.csv" "$filePath"
else 
    log "正在编辑文件: $filePath"
fi

sensible-editor "$filePath"

lineNum=$(grep -c "" "$filePath")
if (( $lineNum <= 1 )); then
    logE "请至少编写一行数据，格式为：种类\t子类\t特点\t经度\t纬度 （\t表示制表符）"
    exit 2
fi

currentLine=0
while IFS= read -r line; do
    let currentLine++
    if [[ $line =~ "种类" ]]; then
        logD "Skipping header"
    else
        # colNum=$(echo -n -e "$line" | grep -o $'\t' | wc -l | wc -l)
        read mainType subType sku x y < <(echo "$line")
        if [ ! -n "$y" ]; then
            log "第 $currentLine 行有错误，每行数据必须有 5 列"
            log "文本编辑器请按 Tab 键表示下一列，建议使用 VSCode 或 LibreOffice 编辑，如果数据不存在请写横线 - "
            log "请重新编写文件。"
            rm -f "$filePath"
            exit 3
        fi
    fi
done < "$filePath"

while true; do
    read -p "是否立刻发送此文件？" yn
    case $yn in
        [Yy]* ) sendFileNow;;
        [Nn]* ) exit;;
        * ) echo "Yes or no.";;
    esac
done