
-- 时间倒计时管理
local skynet = require "skynet"

local desk_timeout_pool = {}
local user_timeout_pool = {}

local function timeout(outtime, f, ...)
    local param = {...}
    local function t()
        if f then
            f(table.unpack(param))
        end
    end
    skynet.timeout(outtime, t)
    return function() f = nil end
end

local function stop_desk(deskinfo, action)
    local deskid = deskinfo.deskid
    if action then
        local stop_fun = desk_timeout_pool[deskid] and desk_timeout_pool[deskid][action] or nil
        if stop_fun then
            stop_fun()
        end
    else
        local pool = desk_timeout_pool[deskid]
        for _, stop_fun in pairs(pool) do
            stop_fun()
        end
    end
end

-- 注意一种类型只能存在一个
local function auto_desk(deskinfo, action, outtime_sec, f , ...)
    action = action or "normal"
    stop_desk(deskinfo, action)
    local stop_fun = timeout(outtime_sec * 100, f, ...)
    local deskid = deskinfo.deskid
    desk_timeout_pool[deskid] = desk_timeout_pool[deskid] or {}
    local pool = desk_timeout_pool[deskid]
    pool[action] = pool[action]
    if pool[action] then
        pool[action]()
    end
    pool[action] = stop_fun
end

local function stop_user(user, action)
    local uid = user.uid
    if action then
        local stop_fun = user_timeout_pool[uid] and user_timeout_pool[uid][action] or nil
        if stop_fun then
            -- print("zhourj stop_user !!!! ", user.uid, debug.traceback())
            stop_fun()
        end
    else
        local pool = user_timeout_pool[uid] or {}
        for key, stop_fun in pairs(pool) do
            -- print("zhourj stop_user !!!! ", user.uid, key)
            stop_fun()
        end
    end
end

local function auto_user(user, action, outtime_sec, f, ...)
    stop_user(user, action)
    action = action or "normal"
    local auto_fun = timeout(outtime_sec * 100, f, ...)
    local uid = user.uid
    user_timeout_pool[uid] = user_timeout_pool[uid] or {}
    local pool = user_timeout_pool[uid]
    if pool[action] then
        pool[action]()
    end
    pool[action] = auto_fun
end

return {
    auto_user = auto_user,
    stop_user = stop_user,

    auto_desk = auto_desk,
    stop_desk = stop_desk,
}