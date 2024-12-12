--统一缓存玩家游戏内数据
--1，防止游戏内各种功能需要存数据是各自操作redis导致的远程调用过多导致的性能问题
--2，数据只保存于redis，如果有长久的持久化需求的数据，请使用mysql
--3，数据以玩家ID为key，因此数据在各个“子游戏”之间是互通的（区别于游戏deskdata，以uid:gameid为key，子游戏之间是独立的）
--4，适用于各类游戏内活动（跟特定子游戏不关联）以及统计数据

local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local cjson = require "cjson"

cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local EXPIRED_TIME = 24*60*60*2  --超时清理内存时间
local MAX_ITEM_COUNT = 50000    --最大保存数据条数
--接口
local CMD = {}

--数据
local datas = {}
local count = 0

local function loaddata(uid)
    if not datas[uid] then
        local res = do_redis({"hgetall", PDEFINE.REDISKEY.GAME.gamedata..":"..uid}, uid)
        if res then
            local data = {}
            for i = 1, #res, 2 do
                data[res[i]] = res[i + 1]
            end
            datas[uid] = data
        else
            datas[uid] = {}
        end
        count = count + 1
    end
    datas[uid].__t = os.time()
    return datas[uid]
end

--读取所有值，返回值为table
function CMD.getAll(uid)
    local data = loaddata(uid)
    return data
end

--修改所有值，values为table
--最好不要立即保存immediate，调用方在合适时机手动保存
function CMD.setAll(uid, values, immediate)
    if not datas[uid] then
        count = count + 1
    end
    datas[uid] = values
    if immediate then
        CMD.save(uid)
    end
end

--读取单个值
function CMD.get(uid, key)
    local data = loaddata(uid)
    return data[key]
end

--修改单个值
function CMD.set(uid, key, value, immediate)
    local data = loaddata(uid)
    data[key] = value
    if immediate then
        CMD.save(uid)
    end
end

--对单个值做加法操作（数值类型）
function CMD.add(uid, key, value, immediate)
    if type(value)~="number" then return false end 
    local data = loaddata(uid)
    if not data[key] then
        data[key] = value
    else
        data[key] = tonumber(data[key]) + value
    end
    if immediate then
        CMD.save(uid)
    end
    return true
end

--删除某个值
function CMD.del(uid, key)
    if datas[uid] then
        datas[uid][key] = nil
    end
    do_redis({"hdel", PDEFINE.REDISKEY.GAME.gamedata..":"..uid, key}, uid)
end

--手动保存到redis
function CMD.save(uid)
    if datas[uid] then
        do_redis({"hmset", PDEFINE.REDISKEY.GAME.gamedata..":"..uid, datas[uid]}, uid)
    end
end

--清理超时数据
local function clean_expired(dt)
    if count > MAX_ITEM_COUNT then
        local now = os.time()
        local ids = {}
        local cnt = 0
        for uid, data in pairs(datas) do
            if now - data.__t > EXPIRED_TIME then  --大于2天的数据
                table.insert(ids, uid)
                cnt = cnt + 1
                if cnt > 50 then
                    break
                end
            end
        end

        for _, uid in ipairs(ids) do
            datas[uid] = nil
        end
        count = count - cnt
    end
end

local function threadfunc(interval)
    local dt = interval/100.0
    while true do
        xpcall(clean_expired,
            function(errmsg)
                print(debug.traceback(tostring(errmsg)))
            end,
            dt)
        skynet.sleep(interval)
    end
end

function CMD.start()
    skynet.fork(threadfunc, 2000) --每20秒执行
    LOG_INFO("gamedatamgr started")
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = assert(CMD[cmd])
        skynet.retpack(f(...))
	end)
    skynet.register(".gamedatamgr")
    collectgarbage("collect")
end)
