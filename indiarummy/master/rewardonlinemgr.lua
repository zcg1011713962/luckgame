local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local snax = require "snax"
local CMD = {}
---
--- 在线奖励时间配置
---

local list = {}

-------- 开始启动 把配置全部加载到内存 --------
local function start()
    local sql = "select * from s_reward_online"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            if list[row.id] == nil then
                list[row.id] = {}
            end
            list[row.id] = row
        end
    end
end

-------- 根据id获取配置项 --------
function CMD.getRow(id)
    if nil ~= list[id] then
        return list[id]
    end
    return nil
end

-------- 获取所有的配置列表 --------
function CMD.getAll()
    if table.empty(list) then
        start()
    end
    return list
end

-------- 后台修改了配置, 重新全部加载到内存 --------
function CMD.reload()
    start()
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    start()
    skynet.register(".rewardonlinemgr")
end)