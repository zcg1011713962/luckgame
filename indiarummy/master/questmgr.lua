local skynet = require "skynet"
require "skynet.manager"

local CMD = {}

local questlist = {}

--重新从库里加载配置到游戏
local function loadFromDb()
    local tmplist = {}
    local sql = string.format("select * from s_quest where status=1")
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            table.insert(tmplist, row)
        end
    end
    questlist = tmplist
end

function CMD.getRow(id)
    for _, quest in ipairs(questlist) do
        if quest.id == id then
            return quest
        end
    end
    return nil
end

function CMD.getAll()
    return questlist
end

function CMD.start()
    loadFromDb()
    return PDEFINE.RET.SUCCESS
end

function CMD.reload()
    loadFromDb()
    return PDEFINE.RET.SUCCESS
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)

    skynet.register(".questmgr")
end)
