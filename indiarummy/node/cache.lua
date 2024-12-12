local skynet = require "skynet"
require "skynet.manager"
local cjson = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local snax = require "snax"
local cluster = require "cluster"

local s_special_quest = require "conf.s_special_quest"
local fbshareCfg = require "conf.fbshareCfg"

-- 初始化 加缓存模块

local CMD = {}

-- 初始化配置到redis，方便后台管理
local function initCacheCfg()

    --初始化fb分享转盘奖励
    local redis_key = PDEFINE_REDISKEY.QUEUE.fbshare_wheel_list 
    local cacheVal = do_redis({"get", redis_key})
    local ok, cacheTasks = pcall(jsondecode, cacheVal)
    LOG_DEBUG('initCacheCfg data', cacheTasks)
    if not ok or type(cacheTasks) ~= 'table' or table.size(cacheTasks) <= 0 then
        local json = cjson.encode(fbshareCfg)
        LOG_DEBUG('initCacheCfg2 data', json)
        do_redis({"set", redis_key, json})
    end

    -- 初始化bonus中salon任务奖励配置到redis中
    redis_key = PDEFINE_REDISKEY.QUEUE.salon_tasks_list 
    cacheVal = do_redis({"get", redis_key})
    ok, cacheTasks = pcall(jsondecode, cacheVal)
    if not ok or type(cacheTasks) ~= 'table' or table.size(cacheTasks) <= 0 then
        local json = cjson.encode(s_special_quest.tasks)
        do_redis({"set", redis_key, json})
    end
end


function CMD.run()
    initCacheCfg()
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".cache")
end)