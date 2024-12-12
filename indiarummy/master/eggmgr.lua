local skynet = require "skynet"
require "skynet.manager"

local CMD = {}

local eggCfgs = {}

--重新从库里加载配置到游戏
local function loadFromDb()
    local cfgs = {}
    local sql = string.format("select * from s_egg")
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            if row.rewards and row.rewards ~= "" then
                row.rewards = decodeRewards(row.rewards)
            end
            table.insert(cfgs, row)
        end
    end
    eggCfgs = cfgs
end

function CMD.getEggReward(eggType)
    for _, cfg in ipairs(eggCfgs) do
        if cfg.type == eggType then
            return cfg
        end
    end
    return nil
end

function CMD.getAll()
    return eggCfgs
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

    skynet.register(".eggmgr")
end)
