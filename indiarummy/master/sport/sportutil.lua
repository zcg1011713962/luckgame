local skynet = require "skynet"

local util = {}

--格式 yyyymmddhhmm
function util.timestamp(tm)
    return tm.year*100000000 + tm.month*1000000 + tm.day*10000 + tm.hour*100 + tm.min
end

function util.timestruct(timestamp)
    return {
        year = math.floor(timestamp/100000000),
        month = math.floor((timestamp%100000000)/1000000),
        day = math.floor((timestamp%1000000)/10000),
        hour = math.floor((timestamp%10000)/100),
        min = timestamp%100
    }
end

function util.currenttimestamp()
    local tm = os.date("*t", os.time())
    return util.timestamp(tm)
end

function util.currenttimestruct()
    return os.date("*t", os.time())
end

--系统格式的timestamp
function util.ostimestamp(tm)
    tm.sec = 0
    return os.time(tm)
end

function util.mysql_exec(sql)
    return skynet.call(".mysqlpool", "lua", "execute", sql)
end

function util.mysql_exec_async(sql)
    return skynet.send(".dbsync", "lua", "sync", sql)
end

function util.redis_exec(args, uid)
    local cmd = assert(args[1])
    args[1] = uid
    return skynet.call(".redispool", "lua", cmd, table.unpack(args))
end

return util
