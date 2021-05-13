#!/bin/bash


export SQL_FILE=${SQL_FILE-"main.sqlite3"}
export VERSION=3

function checkParamNum {
    if (($# < 1)); then 
        logE "Illegal checkParamNum call, at least one param required."
        return 2
    fi
    
    local minParamNum=$1
    shift
    if (($# < $minParamNum)); then
        logE "Illegal function call, at least $minParamNum param required, $# given."
        return 2
    fi
}

function getDate {
    echo -n "$(date '+%Y-%m-%d')"
}

function getDateTime {
    echo -n "$(date '+%Y-%m-%d %H:%M:%S')"
}

function log {
    local level=${2-"INFO"}
    echo -n "[$(getDateTime)] [$level] "
    echo "$1" >&2
}

function logD {
    if [ "${IS_DEBUG-0}" -ne 0 ]; then
        log "$1" "DEBUG"
    fi
}

function logW {
    log "$1" "WARN"
}

function logE {
    log "$1" "ERROR"
}

function logInline {
    echo -n "$1" >&2
}

function connectServer {
    logD "[CONNECT] $1:$2"
    exec 4<>/dev/tcp/$1/$2
}

function disconnectServer {
    logD "[CLOSE] $1:$2"
    exec 4>&-
}

function sendPacket {
    logD "[SEND]: $1"
    echo -n -e $1 >&4
}

function sendHeader {
    sendPacket "#%?\n"
}

function sendFooter {
    sendPacket "\0"
}

function sendString {
    logD "[SEND]: $1"
    echo -n "$1" >&4
}

function sendLine {
    sendString "$1"
    echo >&4
}

function sendFile {
    logD "[SEND-FILE]: $1"
    cat "$1" >&4
}

function sendType {
    sendLine "$1"
}

function execSQL {
    sqlite3 "$SQL_FILE" "$@"
}

function execSQLRO {
    sqlite3 "file:$SQL_FILE?mode=ro" "$@"
}

function sqlAdds {
    echo -n "${sql//[\']//\\\'}"
}

function getUserIdByStudentId {
    checkParamNum 1 $*
    echo $1
    local studentId=`sqlAdds "$1"`
    echo $studentId
    execSQLRO "SELECT userid FROM users WHERE studentid = '$studentId';"
}

function addElementOrIncKillNumByTypeName {
    checkParamNum 6 $*
    local type=$(sqlAdds "$1")
    local subtype=$(sqlAdds "$2")
    local sku=$(sqlAdds "$3")
    local userid=$(sqlAdds "$1")
    local x=$(sqlAdds "$2")
    local y=$(sqlAdds "$3")
    local today=$(getDate)
    
    local existOne=$(execSQL "SELECT date,killnum FROM elements WHERE x = '$x' AND y = '$y'" | tr '|' ' ')
    if ((${#existOne[@]} > 0)); then
        if [[ ${existOne[0]} == "$today" ]]; then
            log "检测到同日重复，将忽略: $*"
        else
            execSQL "UPDATE elements SET date = '$today', killnum = ${existOne[1]} + 1;"
        fi
    else
        execSQL "INSERT INTO elements
            (userid, typeid, x, y, date)
            VALUES 
            (
                '$userid'
                (SELECT typeid FROM types WHERE types.type LIKE '$type' AND types.subtype LIKE '$subtype' AND types.sku LIKE '$sku'),
                '$x',
                '$y',
                DATE()
            )"  
    fi
}

function getTypeId {
    checkParamNum 3 $*
    local b=$(sqlAdds "$1")
    local c=$(sqlAdds "$2")
    local d=$(sqlAdds "$3")
}

function addUser {
    checkParamNum 2 $*
    local b=$(sqlAdds "$1")
    local c=$(sqlAdds "$2")
    execSQL "INSERT users (name, studentid) VALUES ('$a', '$b');"
}

function getRankByTypeName {
    checkParamNum 1 $*
    local name=$(sqlAdd "$1")
    execSQL "SELECT * FROM daily_rank_by_type WHERE type LIKE '$name' OR subtype LIKE '$name';"
}

function exportDailyRank {
    local date="${1-"$(getDate)"}"
    local fileName="${2-"stat-$(getDate).html"}"
    log "导出 $date 的数据，并存储到：$fileName"
    
    exec 9<>"$fileName"
    echo '<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
	<meta http-equiv="charset" content="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />
    <style>table,table tr th, table tr td { border:1px solid #0094ff; }</style>'  >&9

    echo "<title>塞尔达传说 $(getDate) 的所有数据和排行榜</title>" >&9
    echo "</head><body>" >&9    
    echo "<h1>可视化地图</h1>" >&9 
    echo '<canvas id="cv" width="100%" height="98vh" style="border:1px solid #000000;"></canvas>' >&9 
    echo '<script>var c = document.getElementById("cv"); var ctx = c.getContext("2d");' >&9 
    
    local elements=$(execSQLRO "SELECT `type`, `subtype`, `x`, `y`, (
	CASE
		WHEN `subtype` IS NULL OR `subtype` = '' THEN type
		ELSE `subtype`
	END
) AS `rtype`, (
	CASE (
		CASE
			WHEN `subtype` IS NULL OR `subtype` = '' THEN type
			ELSE `subtype`
		END
		)
		WHEN '独眼巨人西诺克斯' THEN '👽'
		WHEN '岩石巨人' THEN '🗿'
		WHEN '神庙' THEN '🏯'
        WHEN '半人马莱尼尔' THEN '🐴'
        WHEN '莫尔德拉吉克' THEN '👻'
		WHEN '克洛格种子' THEN '🌱'
		ELSE '❓'
	END
) AS `emoji` FROM everything;")
    

    echo '</script>' >&9 

    echo "<h1>目前的全部数据</h1>" >&9 

    echo "<table>" >&9
    echo "<tr> <th>ID</th> <th>类型</th> <th>子类</th> <th>特点</th> <th>X</th>  <th>Y</th> <th>击杀次数</th> <th>提交人姓名</th> <th>学号</th> <th>时间</th> </tr>" >&9

    execSQLRO '.mode html' \
        '.output stdout' \
        'SELECT `id`, `type`, `subtype`, `sku`, `x`, `y`,`killnum` , `name`, `studentid`, `date` FROM everything ORDER BY datetime(`date`) DESC;' >&9
    
    echo "</table>" >&9


    echo "<h1>$(getDate) 的排行榜</h1>" >&9 

    echo "<h2>神庙高手排行榜</h2>" >&9
    echo "<table>" >&9
    echo "<tr>  <th>姓名</th>  <th>学号</th> <th>类目数</th> <th>击杀总数</th></tr>" >&9
    
    execSQLRO ".mode html" \
        ".output stdout" \
        "SELECT name, studentid, subtype_count, kill_count FROM daily_rank_by_type WHERE type LIKE '神庙' LIMIT 10;" >&9

    echo "</table>" >&9

    

    echo "<h2>岩石巨人杀手排行榜</h2>" >&9
    echo "<table>" >&9
    echo "<tr>  <th>姓名</th>  <th>学号</th>  <th>类目数</th> <th>击杀总数</th></tr>" >&9
    
    execSQLRO ".mode html" \
        ".output stdout" \
        "SELECT name, studentid, subtype_count, kill_count FROM daily_rank_by_type WHERE subtype LIKE '岩石巨人' LIMIT 10;" >&9

    echo "</table>" >&9


    echo "<h2>西诺克斯杀手排行榜</h2>" >&9
    echo "<table>" >&9
    echo "<tr>  <th>姓名</th>  <th>学号</th>  <th>类目数</th> <th>击杀总数</th></tr>" >&9
    
    execSQLRO ".mode html" \
        ".output stdout" \
        "SELECT name, studentid, subtype_count, kill_count FROM daily_rank_by_type WHERE subtype LIKE '独眼巨人西诺克斯' LIMIT 10;" >&9

    echo "</table>" >&9


    echo "<h2>莱尼尔杀手排行榜</h2>" >&9
    echo "<table>" >&9
    echo "<tr>  <th>姓名</th>  <th>学号</th>  <th>类目数</th> <th>击杀总数</th></tr>" >&9
    
    execSQLRO ".mode html" \
        ".output stdout" \
        "SELECT name, studentid, subtype_count, kill_count FROM daily_rank_by_type WHERE subtype LIKE '半人马莱尼尔' LIMIT 10;" >&9

    echo "</table>" >&9


    echo "<h2>莫尔德拉吉克杀手排行榜</h2>" >&9
    echo "<table>" >&9
    echo "<tr>  <th>姓名</th>  <th>学号</th>  <th>类目数</th> <th>击杀总数</th></tr>" >&9
    
    execSQLRO ".mode html" \
        ".output stdout" \
        "SELECT name, studentid, subtype_count, kill_count FROM daily_rank_by_type WHERE subtype LIKE '莫尔德拉吉克' LIMIT 10;" >&9

    echo "</table>" >&9


    echo "<h2>克洛格排行榜</h2>" >&9
    echo "<table>" >&9
    echo "<tr>  <th>姓名</th>  <th>学号</th>  <th>类目数</th> <th>击杀总数</th></tr>" >&9
    
    execSQLRO ".mode html" \
        ".output stdout" \
        "SELECT name, studentid, subtype_count, kill_count FROM daily_rank_by_type WHERE type LIKE '克洛格种子' LIMIT 10;" >&9

    echo "</table>" >&9


    echo "</body></html>" >&9
    exec 9>&-   
}

function connectAndSendCSV {
    checkParamNum 2 $*
    local studentId="$1"
    local file="$2"
    local server="${SERVER_ADDRESS-"localhost"}"
    local port="${SERVER_PORT-"45123"}"
    connectServer "$server" "$port"
    if (($? != 0)); then
        logE "连接服务器失败"
        return 2
    fi 

    log "连接成功"

    sendHeader  || return 1
    sendType "add" || return 1
    sendLine "$studentId" || return 1
    sendLine "$(wc -l <  "$file")" || return 1
    sendFile "$file" || return 1
    sendFooter || return 1

    disconnectServer || return 1
    return 0
}

logD "调试模式已启用"