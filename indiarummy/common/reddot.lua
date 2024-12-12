local cluster = require "cluster"
local skynet = require "skynet"

local reddot = {}

local prefix = "reddot:" --红点key前缀

local allKeys = PDEFINE.REDDOT

-- 直接设置
function reddot.set(uid, cat, val)
    if not table.contain(allKeys, cat) then
        return
    end
    if not val then
        val = 1
    end
    do_redis({"hset", prefix .. uid, cat, val})
end

-- 增加红点值
function reddot.incr(uid, cat, val)
    if not table.contain(allKeys, cat) then
        return
    end
    if not val then
        val = 1
    end
    do_redis({"hincrby", prefix .. uid, cat, val})
end

-- 直接添加key的
function reddot.addSpecialKey(uid, key, val)
    if not val then
        val = 1
    end
    do_redis({"hset", prefix .. uid, key, val})
end

--删除单个红点
function reddot.del(uid, cat)
    if not table.contain(allKeys, cat) then
        return
    end
    do_redis({"hset", prefix .. uid, cat, 0})
end

-- 重置红点
function reddot.reset(uid)
    local tbl = {}
    for _, k in pairs(allKeys) do
        tbl[k] = 0
    end
    do_redis({"hmset", prefix .. uid, tbl})
end

--获取所有红点
function reddot.getall(uid)
    local data = do_redis({"hgetall", prefix .. uid})
    data = make_pairs_table_int(data)
    for _, k in pairs(allKeys) do --所有key都给存上
        if not data[k] then
            data[k] = 0
        end
    end
    return data
end

return reddot