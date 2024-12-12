local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local cjson = require "cjson"
local game_tool = require "game_tool"
local player_tool = require "base.player_tool"

local APP = tonumber(skynet.getenv("app")) or 1

local gamename = "game"

--游戏服有哪些房间
local CMD = {}

--[[
    重写匹配流程，使得更加清晰明了

    1. Desks = {} 按照deskid来存放游戏，方便通过deskid快速找到游戏, desks[deskid] = desk
    2. GameDesks = {} 按照gameid来存放游戏，方便游戏间匹配 desks[gameid] = {}

    匹配原则
    1. 由于进程属于单进程，所以直接锁定桌子，预先占座
    2. 加入房间失败后释放，或者通过超时来主动同步桌子信息
    3. 此游戏没有局数之分，所以不需要考虑局数的问题
    4. 匹配的时候，优先寻找等待开局的游戏，其次找已经开局但是少人的房间
]]

local GameDesks = {}
local Desks = {}
local GameInCreate = {}  -- 正在创建中
local UserInJoin = {}  -- 正在加入中
local DeskJoin = {}  -- 桌子正在加入的玩家

local privateRooms = {}  -- 好友房列表
local matchRooms = {}  -- 匹配房列表

local uid_in_private_game = {}  -- 在游戏中的人
local uid_in_match_game = {}  -- 在游戏中的人
local closeServer = nil

local unlikeTime = 1*60  -- 目前设置1分钟内退出的房间，不会再次加入
local unlikeDeskid = {}  -- 以uid为key的 列表

local logic = {}

logic.isSessionGame = function(gameid)
    if gameid == PDEFINE.GAME_TYPE.TEENPATTI
        or gameid == PDEFINE.GAME_TYPE.TEXAS_HOLDEM
        or gameid == PDEFINE.GAME_TYPE.BLACK_JACK
        or gameid == PDEFINE.GAME_TYPE.INDIA_RUMMY
    then
        return true
    end
    return false
end

logic.getDefaultSeat = function(gameid)
    return PDEFINE.GAME_TYPE_INFO[APP][1][gameid].SEAT
end

-- 插入桌子信息
logic.insertDesk = function(deskInfo, sid)
    local desk = {}
    desk.deskid = deskInfo.deskid
    desk.gameid = deskInfo.gameid
    desk.state = deskInfo.state
    desk.playtime = 0 --每小局游戏的开始时间
    desk.seat = deskInfo.seat or deskInfo.conf.seat
    if desk.gameid == PDEFINE.GAME_TYPE.LUDO or desk.gameid == PDEFINE.GAME_TYPE.LUDO_QUICK then
        desk.seat = 2  --ludo的匹配场限制为2人
    end
    desk.ssid = deskInfo.ssid
    desk.sid = sid
    desk.users = {}
    for _, user in ipairs(deskInfo.users) do
        table.insert(desk.users, {
            playername = user.playername,
            avatarframe = user.avatarframe,
            usericon = user.usericon,
        })
    end
    desk.curseat = #desk.users
    desk.realnum = 1
    local gameid = desk.gameid
    if not GameDesks[gameid] then
        GameDesks[gameid] = {}
    end
    if not Desks[desk.deskid] then
        table.insert(GameDesks[gameid], desk)
        Desks[desk.deskid] = desk
    end
end

-- 更新桌子信息
logic.updateDesk = function(deskInfo)
    if not deskInfo then return end
    local desk = Desks[deskInfo.deskid]
    desk.deskid = deskInfo.deskid
    desk.gameid = deskInfo.gameid
    desk.state = deskInfo.state
    if desk.state == PDEFINE.DESK_STATE.MATCH then
        desk.playtime = 0
    end
    desk.users = {}
    for _, user in ipairs(deskInfo.users) do
        table.insert(desk.users, {
            playername = user.playername,
            avatarframe = user.avatarframe,
            usericon = user.usericon,
        })
    end
    desk.curseat = #desk.users
    desk.realnum = 1
end

-- 移除桌子信息
logic.removeDesk = function(deskid)
    if type(deskid) ~= "number" then
        LOG_ERROR("removeDesk deskid type error: ", deskid)
    end
    for gameid, desks in pairs(GameDesks) do
        for idx, desk in ipairs(desks) do
            if desk.deskid == deskid then
                LOG_DEBUG("removeDesk: ", deskid)
                table.remove(desks, idx)
                break 
            end
        end
    end
    Desks[deskid] = nil
end

-- 获取桌子信息
logic.findDeskByDeskid = function(deskid)
    return Desks[deskid]
end

-- 获取gametype
logic.getGameType = function(gameid)
    return PDEFINE.GAME_TYPE_INFO[APP][1][gameid].MATCH
end

-- 获取agent名
logic.getGameAgent = function (gameid)
    return PDEFINE.GAME_TYPE_INFO[APP][1][gameid].AGENT
end

-- 加入桌子
logic.joinDeskInfo = function(cluster_info, msg, ip)
    local recvobj = cjson.decode(msg)
    if type(recvobj.deskid) ~= 'number' then
        LOG_ERROR("joinDeskInfo error type --> deskid", recvobj.deskid)
    end
    local deskid = tonumber(recvobj.deskid)
    local desk = logic.findDeskByDeskid(deskid)
    local ok, retcode, retobj, cluster_desk = pcall(cluster.call, gamename, ".dsmgr", "joinDeskInfo", cluster_info,msg, ip, desk.gameid)
    if retcode == PDEFINE.RET.SUCCESS then
        return PDEFINE.RET.SUCCESS, retobj, cluster_desk
    else
        LOG_DEBUG("ok,retcode,retobj,cluster_desk ", ok,retcode,retobj,cluster_desk)
        return retcode
    end
end

-- 修改桌子信息
logic.changeDesk = function(deskid, key, value)
    LOG_DEBUG("changeDesk deskid:", deskid, " key:", key, " value:", value)
    local desk = logic.findDeskByDeskid(deskid)
    if desk then
        desk[key] = value
    end
end


-- 匹配锁定用户，防止加入其它房间
logic.lockPlayer = function(deskid, uids, gameid, gametype)
    if gametype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        for _, uid in ipairs(uids) do
            uid_in_match_game[uid..gameid] = {deskid=tonumber(deskid), gameid=tonumber(gameid)}
        end
    end
end

-- 解禁玩家
logic.unlockPlayer = function(deskid, uids, gameid, gametype)
    if gametype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        for _, uid in ipairs(uids) do
            uid_in_match_game[uid..gameid] = nil
        end
    end
end

-- 获取玩家当前所在桌子
logic.getPlayerDesk = function(uid, gametype, gameid)
    -- 这里坐下区分，好友房和匹配方是分开的
    if gametype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        return uid_in_match_game[uid..gameid]
    end
end

logic.setPlayerExit = function(uid, deskid)
    local uid = tonumber(uid)
    local deskid = deskid and tonumber(deskid) or 0
    LOG_DEBUG("wait setPlayerExit: ", deskid, uid)
    for uidgameid, desk in pairs(uid_in_match_game) do
        local struid = tostring(uid)
        if string.sub(uidgameid,1,string.len(struid))==struid then
            local gameid = string.sub(uidgameid,string.len(struid)+1,string.len(uidgameid))
            gameid = tonumber(gameid)
            local gameName = CMD.getGameName(gameid)
            if desk and desk.deskid ~= deskid and desk.gameid == gameid then
                LOG_DEBUG("setPlayerExit: ", desk.deskid, uid)
                pcall(cluster.send, gameName, ".dsmgr", "setPlayerExit", desk.deskid, uid)
            end
        end
    end
    local viewGame = skynet.call(".balprivateroommgr", "lua", "getViewRoom", uid)
    if viewGame and viewGame.deskid ~= deskid then
        LOG_DEBUG("setPlayerExit view: ", viewGame.deskid, uid)
        local gameName = CMD.getMatchGameName(viewGame.gameid)
        pcall(cluster.send, gameName, ".dsmgr", "setPlayerExit", viewGame.deskid, uid)
    end
end

-- 通过gameType获取匹配方法
logic.getFuncByGameType = function(gameType)
    if gameType == PDEFINE.GAME_KIND.FIGHT then  -- 对战类
        return logic.matchFight
    elseif gameType == PDEFINE.GAME_KIND.BET then  -- 百人场
        return logic.enterBet
    elseif gameType == PDEFINE.GAME_KIND.ALONE then  -- slot游戏
        return logic.enterAlone
    end
end

-- 加入匹配房
logic.matchFight = function(gameid, ssid, uid, sid, alone)
    if not GameDesks[gameid] then
        GameDesks[gameid] = {}
    end
    -- 循环列表，找出符合要求的桌子信息
    local desks = {}
    for _, desk in ipairs(GameDesks[gameid]) do
        if desk.ssid == ssid and desk.sid == sid and (logic.isSessionGame(gameid) or desk.state == PDEFINE.DESK_STATE.MATCH) then
            -- 检查是否是不喜欢的房间
            local isUnlike = false
            if unlikeDeskid[uid] then
                if os.time() > unlikeDeskid[uid].timeout then
                    unlikeDeskid[uid] = nil
                else
                    if table.contain(unlikeDeskid[uid].deskids, desk.deskid) then
                        isUnlike = true
                    end
                end
            end
            -- 只有非不喜欢的，才能返回
            if not isUnlike then
                local joinCnt = 0
                if DeskJoin[desk.deskid] then
                    joinCnt = #DeskJoin[desk.deskid]
                end
                if (desk.curseat + joinCnt) < desk.seat and (not alone or desk.realnum <= 0) then
                    table.insert(desks, desk)
                end
            end
        end
    end
    table.sort(desks, function(a, b)
        return a.playtime < b.playtime
    end)
    if #desks>0 then
        return desks[1].deskid
    end
    return nil
end

-- 加入下注房
logic.enterBet = function(gameid, ssid, uid, sid, alone)
    if not GameDesks[gameid] then
        GameDesks[gameid] = {}
    end
    if #GameDesks[gameid] > 0 then
        return GameDesks[gameid][1].deskid
    end
    return nil
end

-- 加入slot房
logic.enterAlone = function(gameid, ssid, uid, sid, alone)
    if not GameDesks[gameid] then
        GameDesks[gameid] = {}
    end
    return nil
end

-- 标记不喜欢的桌子
logic.markUnlikeDesk = function(uid, deskid)
    if not unlikeDeskid[uid] then
        unlikeDeskid[uid] = {timeout=nil, deskids={}}
    end
    table.insert(unlikeDeskid[uid].deskids, deskid)
    if #(unlikeDeskid[uid].deskids) > 3 then  --限制长度，不然玩家无限换桌
        table.remove(unlikeDeskid[uid].deskids, 1)
    end
    unlikeDeskid[uid].timeout = os.time()+unlikeTime
    LOG_DEBUG("markUnlikeDesk: ", uid, unlikeDeskid[uid])
end

--进入策略房间
logic.enterStrategyDesk = function(cluster_info, msg, ip)
    local uid = msg.uid
    -- 防止重复点击加入
    if UserInJoin[uid] then
        return PDEFINE.RET.ERROR.JOINING_DESK
    end
    UserInJoin[uid] = 1
    local retcode, retobj, cluster_desk = skynet.call(".strategymgr", "lua", "joinDesk", cluster_info, msg, ip)
    UserInJoin[uid] = nil
    if retcode ~= PDEFINE.RET.SUCCESS then
        return retcode
    end

    skynet.send(".agentdesk","lua","joinDesk",cluster_desk,uid)
    return retcode, retobj, cluster_desk
end


-------------------------- 游戏调用接口 ------------------------------

-- 开始匹配，协议是43协议
-- 去掉乱匹配，无需乱匹配
function CMD.matchSess(cluster_info, msg, ip, newplayercount)
    local gameid = msg.gameid           --游戏id
    local deskid = msg.deskid or nil    --房间id
    local ssid = msg.ssid or 0          --场次id
    local uid = msg.uid                 --用户id
    local sid = nil                       --策略id
    if not gameid then
        return PDEFINE.RET.ERROR.PARAM_NIL
    end
    local gameType = logic.getGameType(gameid)

    -- 匹配房再次匹配，则进入原来的房间
    if gameType ~= PDEFINE.GAME_KIND.ALONE then
        local desk = CMD.getPlayerDesk(uid, PDEFINE.BAL_ROOM_TYPE.MATCH, gameid)
        if desk then
            -- 如果原来的房间还在，则强制回原来的房间
            msg.deskid = desk.deskid
            local ok,retcode,retobj,cluster_desk = pcall(cluster.call, "game", ".dsmgr", "joinDeskInfo", cluster_info,msg,ip, desk.gameid)
            if retcode == PDEFINE.RET.SUCCESS then
                skynet.call(".agentdesk","lua","joinDesk",cluster_desk,uid)
                return PDEFINE.RET.SUCCESS,retobj,cluster_desk
            else
                if retcode == PDEFINE.RET.ERROR.DESKID_NOT_FOUND then
                    LOG_ERROR("desk not found", uid, desk.deskid, desk.gameid)
                    logic.unlockPlayer(desk.deskid, {uid}, desk.gameid, PDEFINE.BAL_ROOM_TYPE.MATCH)
                else
                    LOG_ERROR("joinDeskInfo fail", retcode)
                    return retcode
                end
            end
        end
    end

    local gameInfo = skynet.call(".gamemgr", "lua", "getRow", gameid)
    if not gameInfo then
        return PDEFINE.RET.ERROR.GAME_NOT_OPEN
    end
    msg.taxrate = tonumber(gameInfo.taxrate) or 0
    msg.aijoin = tonumber(gameInfo.aijoin) or 1

    local playerInfo = skynet.call(".userCenter", "lua", "getPlayerInfo", uid)
    if not playerInfo then
        return PDEFINE.RET.ERROR.PARAM_NIL
    end
    if gameInfo.svip then
        local svips = string.split_to_number(gameInfo.svip, ",")
        local minsvip = table.minn(svips)
        if playerInfo.svip < minsvip then
            return PDEFINE.RET.ERROR.GAME_SVIP_LOW, minsvip
        elseif not table.contain(svips, playerInfo.svip) then
            return PDEFINE.RET.ERROR.GAME_SVIP_LIMIT
        end
    end
    if playerInfo.ispayer ~= 1 then
        local bindconfig = skynet.call(".configmgr", "lua", "getPlayBindConfig")
        if bindconfig.bind_kyc == 1 then
            if playerInfo.isbindphone ~= 1 then
                return PDEFINE.RET.ERROR.GAME_NOT_BIND_PHONE
            end
            if playerInfo.kyc ~= 1 then
                return PDEFINE.RET.ERROR.GAME_NOT_BIND_KYC
            end
        end
        if bindconfig.bind_phone == 1 then
            if playerInfo.isbindphone ~= 1 then
                return PDEFINE.RET.ERROR.GAME_NOT_BIND_PHONE
            end
        end
    end

    if gameType == PDEFINE.GAME_KIND.BET then  -- 百人场走策略房间
        return logic.enterStrategyDesk(cluster_info, msg, ip)
    end

    local gameAgent = logic.getGameAgent(gameid)
    local sessInfo = {}
    if gameType == PDEFINE.GAME_KIND.FIGHT and gameAgent ~= "fishagent" then --用户金币超过了点击的场次金币范围，需要系统自动分配场次
        if ssid == 0 then
            return PDEFINE.RET.ERROR.PARAM_NIL
        end

        -- 获取场次信息
        sessInfo = skynet.call(".sessmgr", "lua", "getSess", ssid)
        if not sessInfo or sessInfo.gameid ~= gameid then
            return PDEFINE.RET.ERROR.CAN_NOT_FOUND_SESS
        end

        if sessInfo.mincoin > playerInfo.coin or (sessInfo.maxcoin > 0 and sessInfo.maxcoin < playerInfo.coin) then
            LOG_INFO("SESS_COIN_LIMIT", ssid, playerInfo.coin, sessInfo.mincoin, sessInfo.maxcoin)
            return PDEFINE.RET.ERROR.SESS_COIN_LIMIT
        end
    end

    local GT = PDEFINE.GAME_TYPE
    local alone = false
    local strategyGameIds = {GT.BLACK_JACK, GT.INDIA_RUMMY, GT.LUDO, GT.TEXAS_HOLDEM, GT.DOMINO, GT.TEENPATTI}
    if table.contain(strategyGameIds, gameid) and (playerInfo.svip or playerInfo.tagid) then
        local stgy = skynet.call(".strategymgr", "lua", "getStrategy", gameid, playerInfo.svip, playerInfo.tagid)
        if stgy then
            sid = stgy.id
            if stgy.alone == 1 or (gameid == GT.INDIA_RUMMY and stgy.rtp <= 60) then   --rtp<=60的rummy玩家进入单独的房间
                alone = true
            end
        end
    end

    local func = logic.getFuncByGameType(gameType)
    deskid = func(gameid, ssid, uid, sid, alone)
    

    --LOG_DEBUG("matchSess playerInfo", "uid:"..playerInfo.uid, "sid:"..(sid or 0), "svip:"..playerInfo.svip, "tagid:"..playerInfo.tagid, "deskid:"..(deskid or 0))

    -- 如果没有conf信息，则初始化一个
    if not msg.conf then
        msg.conf = {}
    end

    -- 填入匹配房类型
    msg.conf.roomtype = PDEFINE.BAL_ROOM_TYPE.MATCH
    -- 同步ssid
    msg.ssid = ssid
    msg.sid = sid

    -- 如果是对战放，则加入房间配置信息，以及场次信息
    if gameType == PDEFINE.GAME_KIND.FIGHT then
        if nil ~= UserInJoin[uid] then
            return PDEFINE.RET.ERROR.PLAYER_EXISTS_DESK
        end
        msg.conf.entry = sessInfo.basecoin
        msg.conf.score = sessInfo.basecoin
        msg.conf.mincoin = sessInfo.mincoin
        msg.conf.maxcoin = sessInfo.maxcoin
        msg.conf.param1 = sessInfo.param1
        msg.conf.param2 = sessInfo.param2
        msg.conf.private = 0
        -- 这里取默认配置的座位数量
        msg.conf.seat = logic.getDefaultSeat(gameid)
    end

    -- 通知其他房间，已加入新的房间，防止玩家在房间中观战未退出
    -- CMD.setPlayerExit(uid, deskid)

    local gameName = CMD.getMatchGameName(gameid)

    if not deskid then
        -- 百人场只能创建一个房间
        if gameType == PDEFINE.GAME_KIND.BET then
            if GameInCreate[gameid] == 1 then
                return PDEFINE.RET.ERROR.CREATE_AT_THE_SAME_TIME
            end
            GameInCreate[gameid] = 1
        end
        UserInJoin[uid] = 1
        local retok, retcode, retobj, cluster_desk = pcall(cluster.call, gameName, ".dsmgr", "createDeskInfo", cluster_info, msg, ip, gameid, newplayercount)
        if retcode ~= 200 then
            GameInCreate[gameid] = nil
            UserInJoin[uid] = nil
			return retcode
		end
        skynet.send(".agentdesk","lua","joinDesk", cluster_desk, uid)
        if gameType ~= PDEFINE.GAME_KIND.ALONE then
            logic.insertDesk(retobj.deskInfo or retobj.deskinfo, msg.sid)
        end
        UserInJoin[uid] = nil
        return PDEFINE.RET.SUCCESS,retobj,cluster_desk
    else
        msg.deskid = deskid
        LOG_INFO("uid: "..uid.." 加入房间：", deskid)
        -- 防止重复点击加入
        if UserInJoin[uid] then
            return PDEFINE.RET.ERROR.JOINING_DESK
        end
        UserInJoin[uid] = 1
        -- 记录正在加入房间的用户
        if not DeskJoin[deskid] then
            DeskJoin[deskid] = {}
        end
        if not table.contain(DeskJoin[deskid], uid) then
            table.insert(DeskJoin[deskid], uid)
        end
        local ok,retcode,retobj,cluster_desk = pcall(cluster.call, gamename, ".dsmgr", "joinDeskInfo", cluster_info,msg,ip, gameid)
        UserInJoin[uid] = nil
        -- 不管是否加入成功，都需要剔除列表中的uid
        for idx, uid in ipairs(DeskJoin[deskid]) do
            if uid == uid then
                table.remove(DeskJoin[deskid], idx)
                break
            end
        end
        if retcode == PDEFINE.RET.SUCCESS then
            if not retobj.deskInfo and not retobj.deskinfo then
                LOG_ERROR("join error, deskinfo is nil")
            end
            if gameType ~= PDEFINE.GAME_KIND.ALONE then
                logic.updateDesk(retobj.deskInfo or retobj.deskinfo)
            end
            skynet.send(".agentdesk","lua","joinDesk",cluster_desk,uid)
            return PDEFINE.RET.SUCCESS,retobj,cluster_desk
        elseif retcode == PDEFINE.RET.ERROR.DESK_NO_SEAT then
            LOG_DEBUG("(已满)加入房间失败: ", deskid, " gameid:",gameid)
            -- 座位满了，则继续匹配
            if gameType ~= PDEFINE.GAME_KIND.ALONE then
                local desk = logic.findDeskByDeskid(deskid)
                desk.curseat = desk.seat
                msg.deskid = nil
                LOG_DEBUG("清除房间: desk:", desk)
            end
            -- LOG_DEBUG("所有房间: GameDesks:", GameDesks)
            return CMD.matchSess(cluster_info, msg, ip, newplayercount)
        elseif retcode == PDEFINE.RET.ERROR.DESKID_FAIL then
            LOG_DEBUG("加入房间失败: ", deskid, " gameid:",gameid)
            msg.deskid = nil
            CMD.deleteMatchDsmgr(nil, gameid, deskid, nil, nil)
            return CMD.matchSess(cluster_info, msg, ip, newplayercount)
        elseif retcode == PDEFINE.RET.ERROR.DESKID_NOT_FOUND then
            LOG_DEBUG("(房间已经解散)加入房间失败: ", deskid, " gameid:",gameid)
            msg.deskid = nil
            CMD.deleteMatchDsmgr(nil, gameid, deskid, nil, nil)
            return CMD.matchSess(cluster_info, msg, ip, newplayercount)
        elseif retcode == PDEFINE.RET.ERROR.DESK_IS_PLAYING then
            LOG_DEBUG("(房间已经开始)加入房间失败: ", deskid, " gameid:",gameid)
            msg.deskid = nil
            logic.markUnlikeDesk(uid, deskid)
            -- CMD.changeMatchDeskStatus(nil, gameid, deskid, PDEFINE.DESK_STATE.PLAY)
            return CMD.matchSess(cluster_info, msg, ip, newplayercount)
        else
            return retcode
        end
    end
end

function CMD.apendDsmgr(gamename, gameid, baseinfo)
    if not privateRooms[gameid] then
        privateRooms[gameid] = {}
    end
    privateRooms[gameid][baseinfo.deskid] = baseinfo
end

function CMD.joinMatchDsmgr(gname)
    
end

function CMD.apendMatchDsmgr(gname,gameid, baseinfo)
    if not matchRooms[gameid] then
        matchRooms[gameid] = {}
    end
    matchRooms[gameid][baseinfo.deskid] = baseinfo
end

function CMD.deleteMatchDsmgr(gname, gameid, deskid, ssid, maxRound)
    LOG_DEBUG("deleteMatchDsmgr: ", deskid)
    logic.removeDesk(deskid)
    if privateRooms[gameid] then
        privateRooms[gameid][deskid] = nil
    end
    if matchRooms[gameid] then
        matchRooms[gameid] = nil
    end
end

--更改房间内当前用户数
--num：房间人数
--realnum: 真实玩家人数
function CMD.changDeskSeat(gname, gameid, deskid, num, realnum)
    logic.changeDesk(deskid, 'curseat', num)
    logic.changeDesk(deskid, 'realnum', realnum)
    local baseInfo
    if privateRooms[gameid] then
        baseInfo = privateRooms[gameid][deskid]
    end
    if matchRooms[gameid] and not baseInfo then
        baseInfo = matchRooms[gameid][deskid]
    end
    if baseInfo then
        baseInfo.curseat = num
        baseInfo.realnum = realnum
    end
end

--房间状态修改
function CMD.changeMatchDeskStatus(gname, gameid, deskid, status)
    local desk = logic.findDeskByDeskid(deskid)
    if desk then
        desk.state = status
        if status == PDEFINE.DESK_STATE.MATCH then
            desk.playtime = 0
        elseif status == PDEFINE.DESK_STATE.PLAY then
            desk.playtime = os.time()
        end
    end
end

function CMD.joinDeskInfo(cluster_info, msg, ip)
    return logic.joinDeskInfo(cluster_info, msg, ip)
end

-- 获取游戏名称
function CMD.getGameName(gameid)
    return gamename
end

-- 获取游戏服名
function CMD.getMatchGameName(gameid)
    return gamename
end

-- 锁定玩家
function CMD.lockPlayer(deskid, uids, gameid, gametype)
    return logic.lockPlayer(deskid, uids, gameid, gametype)
end

-- 解禁玩家，可以加入其它房间
function CMD.unlockPlayer(deskid, uids, gameid, gametype)
    return logic.unlockPlayer(deskid, uids, gameid, gametype)
end

-- 告知玩家桌子，玩家已换游戏
function CMD.setPlayerExit(uid, deskid)
    logic.setPlayerExit(uid, deskid)
end

-- 获取玩家当前所在桌子
function CMD.getPlayerDesk(uid, gametype, gameid)
    return logic.getPlayerDesk(uid, gametype, gameid)
end

-- 标记桌子，短时间内不再加入该桌子
function CMD.markDesk(uid, deskid)
    logic.markUnlikeDesk(uid, deskid)
end


--广播消息到游戏服  
--@param gameid
--@param cmd
function CMD.brodcastMsgByGameID(gameid, cmd, ...)
    if GameDesks[gameid] then
        local gameName = CMD.getGameName(gameid)
        for _, desk in ipairs(GameDesks[gameid]) do
            pcall(cluster.call, gameName, ".dsmgr", cmd, gameid, desk.deskid, ...)
        end
    end
end

-------------------------- api 相关接口 --------------------------

--后台接口: 获取游戏列表
function CMD.apiDeskList(gameid, type)
    local roomlist = {}
    if "room" == type then
        for gameid, rooms in pairs(privateRooms) do
            for deskid, room in pairs(rooms) do
                table.insert(roomlist, room)
            end
        end
    else
        for gameid, rooms in pairs(matchRooms) do
            for deskid, room in pairs(rooms) do
                table.insert(roomlist, room)
            end
        end
    end

    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.gameid = gameid
    retobj.roomlist = roomList

    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--后台接口：房间里面的信息
function CMD.apiDeskInfo(gameid, type, deskid)
    local desk = logic.findDeskByDeskid(deskid)
    local resp = { code = PDEFINE.RET.SUCCESS }
    local gamename = CMD.getGameName(gameid)
    if desk then
        local ok,retcode,retobj = pcall(cluster.call, gamename, ".dsmgr", "apiDeskInfo", deskid)
        resp.code = retcode
        resp.deskinfo = cjson.decode(retobj)
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(resp)
end

--后台接口：删除房间
function CMD.apiKickDesk(gameid, type, deskid)
    local desk = logic.findDeskByDeskid(deskid)
    local resp = { code = PDEFINE.RET.SUCCESS }
    if desk then
        local ok,retcode,retobj = pcall(cluster.call, 'game', ".dsmgr", "apiKickDesk", deskid)
        resp.code = retcode
        if retobj then
            resp.deskinfo = cjson.decode(retobj)
        end
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(resp)
end

--后台接口，推送某个游戏的跑马灯
function CMD.apiSendDeskNotice(msgid, gameid)
    local retobj = { c = PDEFINE.NOTIFY.NOTIFY_NOTICE_GAME, code = PDEFINE.RET.SUCCESS, notices = {}}
    local msg   = do_redis({"hget", "push_notice:" .. msgid, "msg"}, nil) --消息内容
    if nil ~= msg then
        local speed = do_redis({"hget", "push_notice:" .. msgid, "speed"}, nil) --速度
        table.insert(retobj.notices, { speed = speed, msg = msg })
        for deskid, desk in ipairs(Desks) do
            local ok,retcode,retobj = pcall(cluster.call, gamename, ".dsmgr", "apiSendDeskNotice", deskid, cjson.encode(retobj))
        end
    end

    return PDEFINE.RET.SUCCESS
end

--清除掉缓存的桌子
local function cleardesk( servername )
    Desks = {}
    GameDesks = {}
end

--维护游戏服
local function weihugame( gname )
    --通知匹配场
    LOG_DEBUG("weihugame call apiCloseServer")
    pcall(cluster.call, gname, ".dsmgr", "apiKickAllDesk", true)
    cleardesk( gname )
end

local function ongamechange( server )
    --[[
        server的结构
        server={
            name=xx,
            status=xx,
            tag=xx,
            freshtime=xx,
            serverinfo = {}
        }
    ]]
    if server.status == PDEFINE.SERVER_STATUS.stop then
        --清除掉缓存的桌子
        cleardesk(server.name)
    elseif server.status == PDEFINE.SERVER_STATUS.weihu then
        weihugame(server.name)
    end

    LOG_DEBUG("ongamechange server:", server)
end

function CMD.onserverchange( server )
    LOG_DEBUG("onserverchange server:",server)
    --[[
        server的结构
        server={
            name=xx,
            status=xx,
            tag=xx,
            freshtime=xx，
            serverinfo = {}
        }
    ]]
    if server.tag == "game" then
        ongamechange(server)
    end
end

--系统启动完成后的通知
function CMD.start_init( ... )
    local callback = {}
    callback.method = "onserverchange"
    callback.address = skynet.self()

    skynet.call(".servernode", "lua", "regEventFun", PDEFINE.SERVER_EVENTS.changestatus, callback)
end


skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".mgrdesk")
end)