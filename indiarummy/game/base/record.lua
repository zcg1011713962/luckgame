-- 此文件用于记录游戏记录，注单等
local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"

cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local record = {}

-- 游戏结束，更新个人结算信息
function record.betGameLog(deskInfo, user, betcoin, wincoin, settleInfo, tax)
    if not user.cluster_info then return end
    local isWin = wincoin > 0 and 1 or 0
    local betinfo = {}
    if user.round and user.round.betinfo then
        betinfo = user.round.betinfo
    end
    local roomtype = deskInfo.conf.roomtype or 1
    local issue = deskInfo.issue or ''
    local cost_time = 0
	if deskInfo.roundstime then
		cost_time = os.time() - deskInfo.roundstime
	end

    if deskInfo.openleadboard == nil then
        local code, gameids = pcall(cluster.call,"game",".dsmgr", "getGameIds")
        if code and table.contain(gameids, deskInfo.gameid) then
            deskInfo.openleadboard = 1
        end
    end

    local flag = deskInfo.openleadboard or 0 --是否算入排行榜标记
    local isexit = user.isexit or 0
    local istest = user.istest or 0
    local sql = string.format("insert into d_desk_user(gameid, deskid, uuid, uid, roomtype, create_time, settle, cost_time, win, wincoin, exited, bet, betinfo, prize, league, tax, issue,flag,istest)"
                                            .." values(%d, %d,'%s', %d, %d, %d, '%s', %d, %d, %.2f, %d, %.2f, '%s', %d, %d, %.2f, '%s',%d,%d)",
    deskInfo.gameid, deskInfo.deskid, deskInfo.uuid, user.uid, roomtype,
    os.time(), cjson.encode(settleInfo), cost_time, isWin, wincoin,
    isexit, betcoin, cjson.encode(betinfo), 0, 0, tax, issue, flag, istest)
    -- LOG_DEBUG("d_desk_user sql:", sql)

    skynet.send('.gamepostmgr', 'lua', 'addLbAgent', user.uid, betcoin, wincoin)

    local updateMainObjs = {
        {kind=PDEFINE.MAIN_TASK.KIND.GameTimes, count=1, gameid=deskInfo.gameid},
    }
    if betcoin > wincoin then
        local bet = betcoin - wincoin
        table.insert(updateMainObjs, {kind=PDEFINE.MAIN_TASK.KIND.BetCoin, count=bet})
    end

    if wincoin > betcoin then
        local earn = wincoin - betcoin
        table.insert(updateMainObjs, {kind=PDEFINE.MAIN_TASK.KIND.WinCoin, count=earn})
    end

    local data = {
        betcoin = betcoin,
        wincoin = wincoin,
        uid = user.uid,
        playername  = user.playername,
        gameid = deskInfo.gameid,
        tasks = updateMainObjs,
        issue = deskInfo.issue,
    }
    pcall(cluster.send, "master", ".userCenter", "gameResult", data)
    return do_mysql_queue(sql)
end

-- slots游戏结束，更新个人结算信息
function record.slotsGameLog(deskInfo, betcoin, wincoin, settle, tax)
    local user = deskInfo.user
    if not user.cluster_info then return end
    betcoin = math.abs(betcoin)  --转成整数
    if betcoin<=0 and wincoin<=0 then return end
    local isWin = wincoin > 0 and 1 or 0
    local issue = deskInfo.issue or ''
    local flag = deskInfo.openleadboard or 0 --是否算入排行榜标记
    local istest = user.istest or 0
    local sql = string.format("insert into d_desk_user(gameid, deskid, uuid, uid, roomtype, create_time, settle, cost_time, win, wincoin, exited, bet, betinfo, prize, league, tax, issue, flag, istest)"
                                            .." values(%d, %d,'%s', %d, %d, %d, '%s', %d, %d, %.2f, %d, %.2f, '%s', %d, %d, %.2f, '%s',%d, %d)",
    deskInfo.gameid, deskInfo.deskid, deskInfo.uuid, user.uid, 1,
    os.time(), cjson.encode(settle), 1, isWin, wincoin,
    0, betcoin, '', 0, 0, tax, issue, flag, istest)

    skynet.send('.gamepostmgr', 'lua', 'addLbAgent', user.uid, betcoin, wincoin)

    local data = {
        betcoin = betcoin,
        wincoin = wincoin,
        uid = user.uid,
        gameid = deskInfo.gameid,
        tasks = {},
        issue = deskInfo.issue,
    }
    pcall(cluster.send, "master", ".userCenter", "gameResult", data)
    return do_mysql_queue(sql)
end

-- 牌类游戏结束，更新个人结算信息
function record.updateMainTask(user, betcoin, wincoin, gameid)
    local updateMainObjs = {
        {kind=PDEFINE.MAIN_TASK.KIND.GameTimes, count=1, gameid=deskInfo.gameid},
    }

    if betcoin > wincoin then
        local bet = betcoin - wincoin
        table.insert(updateMainObjs, {kind=PDEFINE.MAIN_TASK.KIND.BetCoin, count=bet})
    end

    if wincoin > betcoin then
        local earn = wincoin - betcoin
        table.insert(updateMainObjs, {kind=PDEFINE.MAIN_TASK.KIND.WinCoin, count=earn})
    end
    pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "clusterModuleCall", "maintask", "updateTask", user.uid, updateMainObjs)
    pcall(cluster.send, "master", ".userCenter", "AddSuperiorRewards", user.uid, PDEFINE.TYPE.SOURCE.BET, betcoin)
end




return record