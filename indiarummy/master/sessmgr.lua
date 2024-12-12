local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local snax = require "snax"
local CMD = {}
--[[
匹配场游戏的场次信息
]]

local sess_list = {}    --场次列表

local function loadFromDb()
    local tmp_list = {}
    local sql = "SELECT * FROM s_sess WHERE `status`=1 ORDER BY ord"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            table.insert(tmp_list, {
                ssid = tonumber(row.id),          --场次ID
                gameid = tonumber(row.gameid),  --游戏ID
                title = row.title,              --游戏名称
                basecoin = tonumber(row.basecoin),  --底分
                mincoin = tonumber(row.mincoin),    --最小入场金币
                maxcoin = tonumber(row.maxcoin),    --最大入场金币
                param1 = tonumber(row.param1),      --texas小盲/teenpatti最小下注/21点最小下注
                param2 = tonumber(row.param2),      --texas大盲/teenpatti最大下注/21点最大下注
                param3 = tonumber(row.param3),
                param4 = tonumber(row.param4),
            })
        end
    end
    sess_list = tmp_list
end

--获取场次信息
function CMD.getSess(ssid)
    for _, sess in ipairs(sess_list) do
        if sess.ssid == ssid then
            return sess
        end
    end
end

--获取游戏场次列表
function CMD.getSessByGameId(gameid)
    local list = {}
    for _, sess in ipairs(sess_list) do
        if sess.gameid == gameid then
            table.insert(list, sess)
        end
    end
    return list
end

--获取所有游戏场次
function CMD.getAllSess()
    return sess_list
end

-------- 重新从库里加载配置到游戏 --------
function CMD.reload()
    loadFromDb()
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    loadFromDb()
    skynet.register(".sessmgr")
end)
