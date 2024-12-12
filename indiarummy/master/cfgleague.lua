local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local snax = require "snax"
-- 排位赛信息配置表

local league_list = {}
local CMD = {}

local function loadCfg()
    local sql = "select * from s_league_hand" --hand
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        local tmpList = {}
        for _, row in pairs(rs) do
            tmpList[row.id] = row
        end
        league_list = tmpList
    end
end

function CMD.reload()
    loadCfg()
end

function CMD.getAll()
    if table.empty(league_list) then
        loadCfg()
    end
    return league_list
end

function CMD.getCfgList()
    if table.empty(league_list) then
        loadCfg()
    end
    local datalist = {}
    for lv, row in pairs(league_list) do
        datalist[lv] = row.score
    end
    return datalist
end

--一次获取当前等级和下一级的信息
function CMD.getCurAndNextLvInfo(lv)
    if nil == lv or 0 ==lv then
        lv = 1
    end
    local leagueinfo = {}
    if nil ~= league_list then
        leagueinfo[1] = league_list[lv]
        leagueinfo[2] = league_list[lv+1]
    else
        leagueinfo = {{}, {}}
    end
    return leagueinfo
end

-- 根据分数获取当前排位段位
function CMD.getCurLevel(exp)
    local curLevel = 1
    for _, row in pairs(league_list) do
        if row.score < exp then
            curLevel = row.id
        else
            break
        end
    end
    return curLevel
end

-- 获取奖励的排位分
function CMD.getLeagueExp(score, lv)
    --local curLevel = lv or 1
    --if curLevel <= 0 then
        --curLevel = 1
    --end
    -- local info     = league_list[curLevel]
    local addExp   = score * 0.01
    addExp = math.floor(addExp)
    return addExp
end

-- 获取当前是否处于排位时间段
function CMD.isLeagueTime()
    -- 获取当前时间
    local now = os.date("*t", os.time())
    for i=#PDEFINE.LEAGUE.HOUR, 1, -1 do
        if PDEFINE.LEAGUE.HOUR[i].stop > now.hour and PDEFINE.LEAGUE.HOUR[i].start <= now.hour then
            return 1
        end
    end
    return 0
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".cfgleague")
end)