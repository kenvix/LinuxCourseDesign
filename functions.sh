#!/bin/bash

SQL_FILE=${SQL_FILE-"main.sqlite3"}

function checkParamNum {
    if (($# < 1)); then 
        logE "Illegal checkParamNum call, at least one param required."
        exit 2
    fi
    
    local minParamNum=$1
    shift
    if (($# < $minParamNum)); then
        logE "Illegal function call, at least $minParamNum param required, $# given."
        exit 2
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

function sendType {
    sendLine "$1"
}

function SQLOp {
    sqlite3 "$SQL_FILE"
}

function SQLOpRO {
    sqlite3 "file:$SQL_FILE?mode=ro"
}

function execSQL {
    SQLOp "$1"
}

function execSQLRO {
    SQLOpRO "$1"
}

function sqlAdds {
    echo -n "${sql//[\']//\\\'}"
}

function addElement {
    checkParamNum 3 $*
    local b=$(sqlAdds "$1")
    local c=$(sqlAdds "$2")
    local d=$(sqlAdds "$3")
    execSQL "INSERT INTO elements (userid, typeid, x, y) VALUES ('$b', '$c', '$d');"
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
    checkParamNum 1 $*

    local fileName="$1"
    exec 9<>"$fileName"
    echo <<-"HTML_HEAD" >&9
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
	<meta http-equiv="charset" content="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />
HTML_HEAD

    echo "<title>$(getDate) 的排行榜</title>" >&9
    echo "</head><body>" >&9    
    echo "<h1>$(getDate) 的排行榜</h1>" >&9 
    echo "<h2>神庙高手排行榜</h2>" >&9
    echo "<table>" >&9
    
    echo <<-"HEREDOC" | SQLOpRO >&9
.mode html
SELECT * FROM daily_rank_by_type WHERE type LIKE '神庙' LIMIT 10;
HEREDOC
    echo "</table>" >&9

    echo <<-"HEREDOC" >&9
</body>
</html>
HEREDOC

    exec 9>&-   
}

logD "调试模式已启用"