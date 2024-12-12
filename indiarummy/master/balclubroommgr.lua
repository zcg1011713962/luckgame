-- 俱乐部房 页面操作
local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local queue     = require "skynet.queue"
local player_tool = require "base.player_tool"
local club_db = require "base.club_db"
local cjson = require "cjson"
local cs = queue()
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local GAME_ID = 256

--接口
local CMD = {}

local club_desk_list = {} -- 俱乐部桌子列表
local club_desk_wait = {} -- 在俱乐部房间界面的用户

local function getAgent(uid)
    return skynet.call(".userCenter", "lua", "getAgent", uid)
end

-- 设置桌子缓存
local function setDeskCache(desk, cid, gameid, deskid)
    if nil == club_desk_list[cid] then
        club_desk_list[cid] = {}
    end
    if nil == club_desk_list[cid][gameid] then
        club_desk_list[cid][gameid] = {}
    end
    club_desk_list[cid][gameid][deskid] = desk
end

-- 获取桌子缓存
local function getDeskCache(deskid, gameid, cid)
    if club_desk_list[cid] and club_desk_list[cid][gameid] then
        return club_desk_list[cid][gameid][deskid]
    end
end

-- 设置玩家缓存
local function setWaitCache(cid, uid)
    if not club_desk_wait[cid] then
        club_desk_wait[cid] = {}
    end
    table.insert(club_desk_wait[cid], uid)
end

-- 加入桌子
local function joinDesk(desk, uid, seatid, gameid)
    local agent = getAgent(uid)
    local params = {}
    params.gameid = gameid or GAME_ID
    params.deskid = desk.deskid
    params.uid = uid
    params.c = 43
    if seatid and seatid > 0 then
        params.seatid = 3
    end
    local resp = {c=PDEFINE.NOTIFY.CLUB_JOIN_ROOM, code=PDEFINE.RET.SUCCESS}
    LOG_DEBUG("joinDesk: msg:", params)
    local retok,retcode,retobj,deskAddr = pcall(cluster.call, desk.server, ".dsmgr", "joinDeskInfo", agent, params, "127.0.0.1", params.gameid)
    LOG_DEBUG("joinDesk return retcode:".. retcode .. "retobj:", retobj, ' deskAddr:', deskAddr)
    if not retok or retcode ~= PDEFINE.RET.SUCCESS then
        LOG_WARNING("加入房间失败", retok, retcode)
        -- resp = {c=PDEFINE.NOTIFY.BALOOT_JOIN_VIPROOM, code=PDEFINE.RET.SUCCESS, spcode=retcode}
        return retok,retcode,retobj,deskAddr
    end
    -- 加入桌子
    skynet.call(".agentdesk","lua","joinDesk", deskAddr, uid)
    desk.curseat = desk.curseat + 1 -- 人数加1
    resp.deskid = retobj.deskinfo.deskid
    resp.users  = retobj.deskinfo.users
    resp.conf   = retobj.deskinfo.conf
    local users = {}
    for _, muser in pairs(retobj.deskinfo.users) do
        local agent = getAgent(muser.uid)
        if agent then
            pcall(cluster.send, agent.server, agent.address, "sendToClient", cjson.encode(resp)) --通知客户端
        end
        table.insert(users, {
            ['uid'] = muser.uid,
            ['playername'] = muser.playername,
            ['usericon'] = muser.usericon,
            ['seatid'] = muser.seatid,
        })
    end
    desk.users = users
    pcall(cluster.send, agent.server, agent.address, "setClusterDesk", deskAddr) -- 设置玩家桌子
    return true, 200, retobj, deskAddr
end

function CMD.getDeskInfoFromCache(deskid, gameid, cid)
    if club_desk_list[cid] and club_desk_list[cid][gameid] then
        return club_desk_list[cid][gameid][deskid]
    end
end

-- 创建桌子
local function createDesk(uid, params)
    params = params or {}
    params.uid = uid
    params.seat = params.conf.seat or 4
    local gameid = params.gameid
    local cid = params.cid  -- 俱乐部id
    local gameName = skynet.call(".mgrdesk", "lua", "getMatchGameName", gameid)
    local agent = getAgent(uid)
    local retok, retcode, retobj, deskAddr = pcall(cluster.call, gameName, ".dsmgr", "createDeskInfo", agent, params, "127.0.0.1", params.gameid)
    if not retok or retcode ~= PDEFINE.RET.SUCCESS then
        LOG_WARNING("创建匹配房间失败", retok, retcode)
        return retok, retcode
    end
    skynet.call(".agentdesk","lua","joinDesk", deskAddr, uid)

    local desk = {
        server = deskAddr.server,
        address = deskAddr.address,
        gameid = deskAddr.gameid,
        deskid = deskAddr.desk_id,
        desk_uuid = deskAddr.desk_uuid,
        create_time = os.time(),
        curseat = 1,
        seat = params.seat,
        conf = retobj.deskinfo.conf, --conf.roomtype 房间类型1：匹配房 2:vip房 3排位赛
        users = {},
        score = params.conf.score,
        entry = params.conf.entry,
        owner = uid,
        cid = params.cid,
    }
    if gameid == PDEFINE.GAME_TYPE.BALOOT then
        desk.score = retobj.deskinfo.panel.score
    end
    for _, user in pairs(retobj.deskinfo.users) do
        local item = {
            ['uid']  = user.uid,
            ['playername'] = user.playername,
            ['usericon'] = user.usericon,
            ['seatid'] = user.seatid
        }
        table.insert(desk.users, item)
    end
    local deskid = deskAddr.desk_id
    deskid = tonumber(deskid)
    setDeskCache(desk, cid, gameid, deskid)
    pcall(cluster.call, agent.server, agent.address, "setClusterDesk", deskAddr)
    return true, desk, retobj
end

local function getRoomList(cid)
    local roomList = {}
    if club_desk_list[cid] then
        for gameid, gameList in pairs(club_desk_list[cid]) do
            for deskid, row in pairs(gameList) do
                local item = {
                    deskid = deskid,
                    entry = row.entry or row.conf.bet,
                    -- score = row.conf.bet,
                    prize = row.conf.bet*2*0.95,
                    turntime = row.conf.turntime,
                    shuffle = row.conf.shuffle,
                    voice = row.conf.voice,
                    curseat = row.curseat,
                    score = row.score or 0,
                    users = row.users,
                    private = row.conf.private,
                    timeout = 0,
                    seat = row.conf.seat, --最大座位数
                    gameid = row.gameid, --游戏id
                }
                table.insert(roomList, item)
            end
        end
    end
    return roomList
end

-- 房间列表有变化，推送房间列表信息
local function pushRoomList(cid)
    if not club_desk_wait[cid] then
        return 
    end
    local roomList = getRoomList(cid)
    local resp = {c= PDEFINE.NOTIFY.BALOOT_REFLASH_VIPROOM, code=PDEFINE.RET.SUCCESS, data = roomList}
    for uid, _ in pairs(club_desk_wait[cid]) do
        local agent = getAgent(uid)
        if agent then
            pcall(cluster.send, agent.server, agent.address, "sendToClient", cjson.encode(resp))
        end
    end
end

-- 创建俱乐部房间
function CMD.createRoom(rcvobj)
    local uid = tonumber(rcvobj.uid)
    local entry = tonumber(rcvobj.entry or 500) --最小携带
    local score = tonumber(rcvobj.score or 1) --底分 hand 和 hand sudi使用
    local turntime = tonumber(rcvobj.turntime or 10)
    local shuffle = tonumber(rcvobj.shuffle or 0) -- 0所有 1洗牌  2不洗牌
    local voice = tonumber(rcvobj.voice or 0) -- 0所有  1开启音效 2不开启
    local private = tonumber(rcvobj.private or 0) --0所有 1私有 2公有
    local gameid = tonumber(rcvobj.gameid or GAME_ID)
    local seat  = tonumber(rcvobj.seat or 4) --人数
    local cid   = tonumber(rcvobj.cid)  -- 俱乐部id

    local resp = {c=rcvobj.c, code=PDEFINE.RET.SUCCESS, cid=cid,spcode=0}
    if not cid then
        resp.spcode = 2
        return resp
    end
    local clubInfo = club_db.getClubByUid(uid)
    if not clubInfo or table.empty(clubInfo) or clubInfo.cid ~= cid then
        resp.spcode = 3  -- 无权限操作该俱乐部
        return resp
    end
    local params = {}
    params.conf = {}
    params.conf.roomtype = PDEFINE.BAL_ROOM_TYPE.CLUB
    params.conf.bet = score
    params.conf.score = score
    params.conf.entry = entry
    params.conf.turntime = turntime
    params.conf.shuffle = shuffle
    params.conf.voice = voice
    params.conf.private = private
    params.conf.seat = seat
    params.gameid = gameid
    params.cid = cid
    local ok, desk, retobj = createDesk(uid, params)
    LOG_DEBUG("createClubRoom ok:", ok, ' desk:', desk, ' retobj:', retobj)
    if not ok or type(desk)=="number" or desk ==nil then
        LOG_DEBUG("createClubRoom createDeskfailed uid:", uid, ' retobj:', desk)
        resp.spcode = desk
        return resp
    end
    
    resp.deskinfo = {
        ['deskid'] = desk.deskid,
        ['conf'] = params.conf,
        ['users'] = desk.users
    }
    -- 推送房间列表信息
    pushRoomList(cid)
    return resp, retobj
end

-- 加入俱乐部房间
function CMD.joinRoom(rcvobj)
    local uid = tonumber(rcvobj.uid)
    local deskid = tonumber(rcvobj.deskid or 0)
    local gameid = tonumber(rcvobj.gameid or GAME_ID)
    local cid = tonumber(rcvobj.cid)
    local deskInfo = getDeskCache(deskid, gameid, cid)
    local resp = {c=rcvobj.c, code=PDEFINE.RET.SUCCESS,spcode=0, uid=uid, cid=cid, gameid=gameid}
    if not deskInfo then
        resp.spcode = PDEFINE.RET.ERROR.GAME_IS_RUNNING
        return resp
    end
    
    local clubInfo = club_db.getClubByUid(uid)
    if not clubInfo or table.empty(clubInfo) or clubInfo.cid ~= cid then
        resp.spcode = 2  -- 非俱乐部成员
        return resp
    end

    local ok, retcode, retobj, _ = joinDesk(deskInfo, uid, nil, gameid)
    -- 推送房间列表信息
    pushRoomList(cid)
    return resp, retobj
end

-- 退出俱乐部房间
function CMD.exitRoom(cid, gameid, deskid, uid)
    local deskid = tonumber(deskid)
    local gameid = tonumber(gameid)
    local cid = tonumber(cid)
    local uid = tonumber(uid)
    local deskInfo = getDeskCache(deskid, gameid, cid)
    if deskInfo then
        local exists = false
        for i= #deskInfo.users, 1, -1 do
            if deskInfo.users[i].uid == uid then
                table.remove(deskInfo.users, i)
                deskInfo.curseat = deskInfo.curseat - 1
                exists = true
            end
        end
    end
    -- 推送房间列表信息
    pushRoomList(cid)
    return PDEFINE.RET.SUCCESS
end

-- 获取俱乐部房间列表
function CMD.getRoomList(uid, cid)
    local roomList = {}
    if club_desk_list[cid] then
        for _, desks in pairs(club_desk_list[cid]) do
            for deskid, row in pairs(desks) do
                local item = {
                    deskid = deskid,
                    entry = row.entry or row.conf.bet,
                    -- score = row.conf.bet,
                    prize = row.conf.bet*2*0.95,
                    turntime = row.conf.turntime,
                    shuffle = row.conf.shuffle,
                    voice = row.conf.voice,
                    curseat = row.curseat,
                    score = row.score or 0,
                    users = row.users,
                    private = row.conf.private,
                    timeout = 0,
                    seat = row.conf.seat, --最大座位数
                    gameid = row.gameid, --游戏id
                }
                table.insert(roomList, item)
            end
        end
    end
    -- 标记用户，用于推送列表更改信息
    -- setWaitCache(cid, uid)
    return roomList
end

-- 邀请好友
function CMD.inviteFriend(rcvobj)
    local uid = tonumber(rcvobj.uid)
    local frienduid = tonumber(rcvobj.frienduid)
    local deskid = tonumber(rcvobj.deskid)
    local gameid = tonumber(rcvobj.gameid)
    local cid = tonumber(rcvobj.cid)
    local deskInfo = getDeskCache(deskid, gameid, cid)
    local resp = {c=rcvobj.c, code=PDEFINE.RET.SUCCESS,spcode=0, uid=uid, frienduid=frienduid, cid=cid, gameid=gameid}
    if not deskInfo then
        resp.spcode = PDEFINE.RET.ERROR.DESKID_NOT_FOUND
        return resp
    end
    local friendClub = club_db.getClubByUid(frienduid)
    if not friendClub or table.empty(friendClub) or friendClub.cid ~= cid then
        resp.spcode = PDEFINE.RET.ERROR.NOT_SAME_CLUB
        return resp
    end

    local friendAgent = getAgent(frienduid)
    if friendAgent then
        local playerInfo = skynet.call(".userCenter", "lua", "getPlayerInfo", uid)
        local friendInfo = skynet.call(".userCenter", "lua", "getPlayerInfo", frienduid)
        local resp = {
            c = PDEFINE.NOTIFY.CLUB_INVITE_GAME,
            code = PDEFINE.RET.SUCCESS,
            deskid = deskid,
            gameid = deskInfo.gameid,
            cid = cid,
            from = uid,
            playername  = playerInfo.playername,
            usericon = playerInfo.usericon,
        }
        pcall(cluster.call, friendAgent.server, friendAgent.address, "sendToClient", cjson.encode(resp))
        return resp
    else
        resp.spcode = PDEFINE.RET.ERROR.FRIEND_OFFLINE
        return resp
    end
end

-- 退出房间列表
function CMD.exitRoomList(rcvobj)
    local uid = rcvobj.uid
    local cid = math.floor(rcvobj.cid)
    if club_desk_wait[cid] == nil then
        club_desk_wait[cid] = {}
    end
    club_desk_wait[cid][uid] = nil
    return PDEFINE.RET.SUCCESS
end

-- 开始游戏后，从列表中删除
function CMD.removeRoom(gameid, deskid, cid)
    deskid = tonumber(deskid)
    cid = tonumber(cid)
    gameid = tonumber(gameid)
    if not club_desk_list[cid] then
        return
    end
    if not club_desk_list[cid][gameid] then
        return
    end
    club_desk_list[cid][gameid][deskid] = nil
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = assert(CMD[cmd])
        skynet.retpack(f(...))
	end)
    skynet.register(".balclubroommgr")
    collectgarbage("collect")
end)