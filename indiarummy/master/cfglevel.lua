local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local snax = require "snax"
-- 升级配置表

local level_list = {} --个人等级
local CMD = {}

local function loadCfg()
    local tmpList = {}
    local sql = "select * from s_config_level"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            local tmp = {}
            tmp["level"] = row.lv --vip级别
            tmp["exp"]  = row.exp --达到vip级别需要的经验值
            tmp['rewards'] = row.rewards
            tmpList[row.lv] = tmp
        end
    end
    level_list = tmpList
end

function CMD.reload()
    loadCfg()
end

function CMD.getAll()
    if table.empty(level_list) then
        loadCfg()
    end
    return level_list
end

function CMD.getInfo(lv)
    if table.empty(level_list) then
        loadCfg()
    end
    if nil == level_list[lv] then
        return {}
    end
    return level_list[lv]
end

--一次获取当前等级和下一级的信息
function CMD.getCurAndNextLvInfo(lv)
    if nil == lv or 0 ==lv then
        lv = 1
    end
    local levelinfo = {}
    levelinfo[1] = CMD.getInfo(lv)
    levelinfo[2] = CMD.getInfo(lv +1)
    return levelinfo
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".cfglevel")
end)