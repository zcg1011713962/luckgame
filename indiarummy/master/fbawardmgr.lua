local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local snax = require "snax"
--奖励开关
local CMD = {}

local datalist = {}

-------- 开始加载数据 --------
local function start()
    local sql = "select * from s_fb_award"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            if datalist[row.id] == nil then
                datalist[row.id] = {}
            end
            row.desc = nil
            datalist[row.id] = row
        end
    end
end

-------- 根据id获取 --------
function CMD.getRow(id, type)
    for _, row in pairs(datalist) do
        if row.type == type and row.id == id then
            return row
        end
    end
    return nil
end

-------- 根据type获取 --------
function CMD.getConfByType(type)
    local ret = {}
    for _, row in pairs(datalist) do
        if row.type == type and row.num > 0 then
            table.insert(ret, row.num)
        end
    end
    return ret
end

-------- 获取所有 --------
function CMD.getAll()
    if table.empty(datalist) then
        start()
    end
    return datalist
end

-------- 重新从库里加载配置到游戏 --------
function CMD.reload()
    start()
    return PDEFINE.RET.SUCCESS
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    start()
    skynet.register(".fbawardmgr")
end)
