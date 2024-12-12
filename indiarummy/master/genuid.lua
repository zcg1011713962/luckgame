local skynet = require "skynet"
require "skynet.manager"

local CMD = {}
local CACHE_KEY = "UID_LIST"
local CAN_USER_KEY = "UID_STATUS_ZERO"

local EXCLUDE_UIDS = {} --保留的的uid
local function loadExcludeUID()
    local tmp = {}
    local sql = "select uid from d_uidstar where status=0"
    local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            table.insert(tmp, row['uid'])
        end
        EXCLUDE_UIDS = tmp
    end
end

--[[
预先生成uid
]]
local running = false
local function genuid()
    if running then
        print(" genuid is running")
        return
    end
    running = true

    local max = 50000
    local num = do_redis({ "get", CAN_USER_KEY}) or 0 --待用的还有多少个
    num = tonumber(num)
    if num == 0 then
        local sql = "select count(1) as t from d_uidgen where status=0"
        local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs > 0 then
            num = rs[1].t
            do_redis({ "set", CAN_USER_KEY, num})
        end
    end
    if num < max then --可用的个数不够max
        local pagesize = 2000
        local page = math.ceil((max - num)/pagesize)
        loadExcludeUID()
        for i=1, page do
            local sql = "select * from d_uidgen order by id desc limit 1"
            local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
            local lastid = 0
            if #rs > 0 then
                lastid = rs[1].id --最后1位的id
            end

            local uids = {}
            local uidsHad = {}
            for k=lastid+1, (lastid + pagesize) do
                -- if string.find(tostring(i),'4') == nil then
                --     table.insert(uids, tonumber(k))
                -- end
                if not table.contain(EXCLUDE_UIDS, k) then
                    table.insert(uids, tonumber(k))
                end
            end

            local sql2 = string.format("select uid from d_user where uid in (%s)", table.concat(uids, ','))
            local rs2  = skynet.call(".mysqlpool", "lua", "execute", sql2)
            if #rs2 > 0 then
                for _,row in pairs(rs2) do
                    table.insert(uidsHad, tonumber(row.uid))
                end
            end

            if #uidsHad > 0 then
                for _, euid in pairs(uidsHad) do
                    for k, uid in pairs(uids) do
                        if euid == uid then
                            table.remove(uids, k)
                            break
                        end
                    end
                end
            end

            if #uids > 0 then
                local insertSql= "insert into d_uidgen values " --批量写入
                for _, uid in pairs(uids) do
                    insertSql = insertSql .. string.format("(%d,0),", uid)

                end
                insertSql = string.sub(insertSql,1,string.len(insertSql)-1)

                skynet.call(".mysqlpool", "lua", "execute", insertSql)
                local curNum = do_redis({ "get", CAN_USER_KEY}) or 0
                curNum = tonumber(curNum)
                do_redis({ "set", CAN_USER_KEY, (curNum + #uids)})
            end
        end
    end

    running = false
end

--[[
监控可用队列大小，不够了往里面塞入
]]
local monitorRun = false
local function monitorQueueSize()
    if monitorRun then
        print("monitorQueueSize is running....")
        return
    end
    monitorRun = true
    local max = 10000
    local cacheNum = do_redis({ "zcard", CACHE_KEY}) or 0
    cacheNum = tonumber(cacheNum)
    if cacheNum < max then
        local CACHE_LASTID = 'UID_LASTID'
        local pagesize = 2000
        local page = math.ceil((max - cacheNum)/pagesize)
        for i = 1, page do
            local lastid = do_redis({ "get", CACHE_LASTID}) or 0
            lastid = tonumber(lastid)
            if lastid == 0 then
                local sql = "select * from d_uidgen where status=0 limit 1"
                local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
                lastid = rs[1].id
                do_redis({ "set", CACHE_LASTID, lastid})
            end

            local uids = {}
            local sql = string.format("select * from d_uidgen where id> %d and status=0 limit %d", lastid, pagesize)
            local rs2 = skynet.call(".mysqlpool", "lua", "execute", sql)
            if #rs2 > 0 then
                math.randomseed(tonumber(tostring(os.time()):reverse():sub(1,6)))
                for _,row in pairs(rs2) do
                    do_redis({ "zadd", CACHE_KEY , math.random(1, 1000000), row.id})
                    table.insert(uids, row.id)
                    lastid = row.id
                end

                do_redis({ "set", CACHE_LASTID, lastid})


                local upSql = string.format("update d_uidgen set status=1 where id in (%s)", table.concat(uids, ","))
                skynet.call(".mysqlpool", "lua", "execute", upSql) --已经放入队列了，去db中去除

                if #uids > 0 then
                    local canUseNum = do_redis({ "get", CAN_USER_KEY}) or 0
                    canUseNum = tonumber(canUseNum)
                    local leftnum = 0
                    if canUseNum - #uids > 0 then
                        leftnum = canUseNum - #uids
                    end
                    do_redis({ "set", CAN_USER_KEY, leftnum})
                end
            end
        end
    end
    monitorRun = false
end

--每1分钟跑1次
function CMD.runGenUid()
    genuid()
end

--每10分钟跑一次
function CMD.runMonitorQueueSize()
    monitorQueueSize()
end

function CMD.start()
    genuid()
    monitorQueueSize()
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd .. "not found")
        skynet.retpack(f(...))
    end)
    skynet.register(".genuid")
end)