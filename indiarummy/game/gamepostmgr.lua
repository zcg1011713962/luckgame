local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local cjson   = require "cjson"
local player_tool = require "base.player_tool"

cjson.encode_sparse_array(true)

local CMD = {}
local observers = {} --观察者


local function statisUserData(ret)
    LOG_DEBUG("statisUserData ret:", ret)
    local sql = string.format( "select count(*) as t from d_user_statis where uid = %d and gameid=%d", ret.uid, ret.gameid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local time = os.time()
    local leagueInfo = player_tool.getLeagueInfo(ret.roomtype, ret.uid)
    LOG_DEBUG("statisUserData uid:", ret.uid, ' rs:', rs[1].t, ' gameid:', ret.gameid)
    if ret.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then 
        if ret.win==1 then --开过一次沙龙房且进行了游戏
            pcall(cluster.send, "master", ".userCenter", "updateQuest", ret.uid, PDEFINE.QUESTID.DAILY.PRIVATEROOM, 1)
        end
    end

    if ret.win == 1 and (ret.winCoin and ret.winCoin > 0) then
        LOG_DEBUG('gamepostmgr uid:', ret.uid, ' wincoin:', ret.winCoin)
        pcall(cluster.send, "master", ".userCenter", "updateWinCoin", ret.uid, ret.winCoin)
    end

    --DAILY Task
    if ret.gameid == 265 then
        pcall(cluster.send, "master", ".userCenter", "updateQuest", ret.uid, PDEFINE.QUESTID.DAILY.DOMINOGAME, 1)
    else
        pcall(cluster.send, "master", ".userCenter", "updateQuest", ret.uid, PDEFINE.QUESTID.DAILY.POKERGAME, 1)
    end

    if rs and rs[1].t > 0 then
        sql = string.format( "update d_user_statis set online_times=online_times+1, online_played=online_played+%d,online_wintimes=online_wintimes+%d,online_exists=online_exists+%d,update_time=%d where uid =%d and gameid=%d",
        ret.cost_time, ret.win, ret.exited, time, ret.uid, ret.gameid)
        -- 判断是否参与了排位赛
        if leagueInfo.isOpen and leagueInfo.isSign then
            sql = string.format( "update d_user_statis set online_times=online_times+1, online_played=online_played+%d,online_wintimes=online_wintimes+%d,online_exists=online_exists+%d,update_time=%d,league_times=league_times+1, league_played=league_played+%d,league_wintimes=league_wintimes+%d,league_exists=league_exists+%d where uid =%d and gameid=%d",
        ret.cost_time, ret.win, ret.exited, time, ret.cost_time, ret.win, ret.exited, ret.uid, ret.gameid)
        end
        LOG_DEBUG("statisUserData sql1:", sql)
        skynet.call(".mysqlpool", "lua", "execute", sql)
    else
        sql = string.format("insert into d_user_statis(uid,online_times,online_played,online_wintimes,online_exists,update_time,gameid) values(%d,%d,%d,%d,%d,%d,%d)",
        ret.uid, 1, ret.cost_time, ret.win, ret.exited, time, ret.gameid)

        if leagueInfo.isOpen and leagueInfo.isSign then
            sql = string.format("insert into d_user_statis(uid,online_times,online_played,online_wintimes,online_exists,league_times,league_played,league_wintimes,league_exists,update_time, gameid) values(%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)",
            ret.uid, 1, ret.cost_time, ret.win, ret.exited,1, ret.cost_time, ret.win, ret.exited, time, ret.gameid)
        end

        LOG_DEBUG("statisUserData sql2:", sql)
        skynet.call(".mysqlpool", "lua", "execute", sql)
    end
end

-- game result
--[[
    local log = {
        ["uid"] = uid,
        ['deskid] = deskid,
        ["roomtype"] = act,
        ["create_time"] = create_time,
        ["settle"] = settle,
        ["win"] = win,
        ["exited"] = exited,
        ['cost_time] = cost_time,
        ['gameid'] = 257
    }
]]
function CMD.addGameResult(data)
    LOG_DEBUG("addGameResult:", data)
    if nil == data.create_time then
        data.create_time = os.time()
    end

    -- local questIds = {} --游戏次数
    -- if data.isSign and data.isSign == 1 then
    --     table.insert(questIds, PDEFINE.QUESTID.NEW.RANKEDGAME)
    -- end
    if data.win ~= nil and type(data.win) == "boolean" then
        if data.win  then
            data.win = 1
        else
            data.win = 0
        end
    end
    
    --不论输赢，都加金猪
    local addCoin = 0
    if data.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        for _, row in pairs(PDEFINE.MONEYBAG['MATCH']) do
            if row.entry == data.entry then
                addCoin = row.addCoin
                break
            end
        end
        -- table.insert(questIds, PDEFINE.QUESTID.NEW.MATCHGAME)
    elseif data.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        for _, row in pairs(PDEFINE.MONEYBAG['VIP']) do
            if row.entry == data.entry then
                addCoin = row.addCoin
                break
            end
        end
        -- table.insert(questIds, PDEFINE.QUESTID.NEW.FRIENDGAME)
    end
    if addCoin == 0 and data.moneybag ~= nil then --直接传金猪
        addCoin = tonumber(data.moneybag)
    end
    if addCoin > 0 then
        local up_data = {
            addbag = addCoin,
        }
        pcall(cluster.send, "master", ".userCenter", "updateUserLevelInfo", data.uid, up_data)
    end
    -- pcall(cluster.send, "master", ".userCenter", "updateBatchQuest", data.uid, questIds, 1)

    for _, func in pairs(observers) do
        pcall(func, data)
    end
    return PDEFINE.RET.SUCCESS
end


--记录代理排行榜中间表
function CMD.addLbAgent(uid, bet, wincoin)
    if nil == uid then
        return
    end

    local agentuid = do_redis({"hget", 'd_user:'..uid, 'invit_uid'})
    agentuid = tonumber(agentuid or 0)
    if agentuid == 0 then
        return
    end

    local cur_timestamp = os.time()
    local temp_date = os.date("*t", cur_timestamp)
    local beginTime = os.time({year=temp_date.year, month=temp_date.month, day=temp_date.day, hour=0})
    local effbet = bet - wincoin
    local sql = string.format([[
        insert into d_lb_agent(invit_uid,uid,create_time,bet,wincoin,effbet) values(%d, %d, %d, %f, %f, %f)
        on duplicate key update bet=bet+%f, wincoin=wincoin+%f,effbet=effbet+%f
    ]], agentuid, uid, beginTime, bet, wincoin, effbet, bet, wincoin, effbet)
    return do_mysql_queue(sql)
end

function CMD.addObserver(func)
    table.insert(observers, func)
end

function CMD.start()
    CMD.addObserver(statisUserData)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd .. "not found")
        skynet.retpack(f(...))
    end)
    skynet.register(".gamepostmgr")
end)
