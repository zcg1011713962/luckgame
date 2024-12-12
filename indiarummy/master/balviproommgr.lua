-- vip房 页面操作
local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local queue     = require "skynet.queue"
local player_tool = require "base.player_tool"
local cjson = require "cjson"
local cs = queue()
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local GAME_ID = 256

--接口
local CMD = {}

local vip_desk_list = {} --vip桌子列表
local WAITING_USERS = {} --在vip匹配界面的用户 uid -> deskid

local function getAgent(uid)
    return skynet.call(".userCenter", "lua", "getAgent", uid)
end

local function leaveVipRoomListPage(uid, roomtype)
    skynet.send('.invitemgr', 'lua', 'leave', {uid}, roomtype)
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
    local resp = {c=PDEFINE.NOTIFY.BALOOT_JOIN_VIPROOM, code=PDEFINE.RET.SUCCESS}
    LOG_DEBUG("joinDesk: msg:", params)
    local retok,retcode,retobj,deskAddr = pcall(cluster.call, desk.server, ".dsmgr", "joinDeskInfo", agent, params, "127.0.0.1", params.gameid)
    LOG_DEBUG("joinDesk return retcode:".. retcode .. "retobj:", retobj, ' deskAddr:', deskAddr)
    if not retok or retcode ~= PDEFINE.RET.SUCCESS then
        LOG_WARNING("加入匹配房间失败", retok, retcode)
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
            pcall(cluster.call, agent.server, agent.address, "sendToClient", cjson.encode(resp)) --通知客户端
        end
        table.insert(users, {
            ['uid'] = muser.uid,
            ['playername'] = muser.playername,
            ['usericon'] = muser.usericon,
            ['seatid'] = muser.seatid,
        })
    end
    desk.users = users
    pcall(cluster.call, agent.server, agent.address, "setClusterDesk", deskAddr) -- 设置玩家桌子
    return true, 200, retobj, deskAddr
end

-- 创建桌子
local function createDesk(uid, params)
    params = params or {}
    params.uid = uid
    params.seat = params.conf.seat or 4
    local gameid = params.gameid
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
    if nil == vip_desk_list[gameid] then
        vip_desk_list[gameid] = {}
    end
    if nil == vip_desk_list[gameid][deskid] then
        vip_desk_list[gameid][deskid] = desk
    end
    LOG_DEBUG("create desk:", desk, ' #vip_desk_list:', #vip_desk_list[gameid])
    pcall(cluster.call, agent.server, agent.address, "setClusterDesk", deskAddr)
    return true, desk, retobj
end

-- 按条件过滤
local function filterDeskList(filterObj, gameid)
    local roomList = {}
    LOG_DEBUG("getVipRoomList vip_desk_list:", vip_desk_list[gameid])
    if vip_desk_list[gameid] then
        for deskid, row in pairs(vip_desk_list[gameid]) do
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
            local add1,add2,add3,add4,add5,add6 = true, true, true, true, true, true
            -- if nil ~= filterObj.private and item.private ~= filterObj.private then
            --     add1 = false
            -- end
            if nil ~= filterObj.state and filterObj.state == 2 then --隐藏满员的房间
                if row.seat == row.curseat then
                    add1 = false
                end
            end
            if nil ~= filterObj.entry and item.entry ~= filterObj.entry then
                add2 = false
            end
            if nil ~= filterObj.turntime and item.turntime ~= filterObj.turntime then
                add3 = false
            end
            if nil ~= filterObj.seat and item.seat ~= filterObj.seat then
                add4 = false
            end
            if nil ~= filterObj.shuffle and item.shuffle ~= filterObj.shuffle then
                add5 = false
            end
            if nil ~= filterObj.voice and item.voice ~= filterObj.voice then
                add6 = false
            end
            if item.private ~= 1 then
                if add1 and add2 and add3 and add4 and add5 and add6 then
                    table.insert(roomList, item)
                end
            end
        end
    end
    return roomList
end

local function refreshVipRoomList(gameid)
    LOG_DEBUG("refreshVipRoomList start gameid:", gameid)
    if nil == gameid then
        gameid = PDEFINE.GAME_TYPE.HAND
    end
    local roomList = filterDeskList({}, gameid)
    local resp = {c= PDEFINE.NOTIFY.BALOOT_REFLASH_VIPROOM, code=PDEFINE.RET.SUCCESS, data = roomList, gameid=gameid}
    local ok, uids, userVIPGames = pcall(skynet.call, ".invitemgr", "lua", "getVipListUIDAndGame")
    LOG_DEBUG("refreshVipRoomList ok:", ok, uids, userVIPGames)
    if ok and uids then
        for  _, uid in pairs(uids) do
            if nil ~= userVIPGames[uid] and userVIPGames[uid] == gameid then
                local agent = getAgent(uid)
                if agent then
                    pcall(cluster.call, agent.server, agent.address, "sendToClient", cjson.encode(resp))
                end
            end
        end
    end
end

-- 所有人都离开的vip房间，不应该在vip列表显示
-- 一旦有一个人离开的vip房间，也不应该在列表中显示
function CMD.changeDeskPrivate(gameid, deskid)
    if vip_desk_list[gameid] then
        for id, row in pairs(vip_desk_list[gameid]) do
            if tonumber(id) == tonumber(deskid) then
                if row.conf.private ~= 1 then
                    row.conf.private = 1 --标记成私人房，不会在vip列表中显示
                    refreshVipRoomList(gameid)
                end
            end
        end
    end
end

function CMD.getDeskInfoFromCache(deskid, gameid)
    if vip_desk_list[gameid] then
       return vip_desk_list[gameid][deskid]
    end
end


--! 创建vip房间
function CMD.createVipRoom(rcvobj)
    local uid = tonumber(rcvobj.uid)
    local entry = tonumber(rcvobj.entry or 0) --最小携带
    local score = tonumber(rcvobj.score or 1) --底分 hand 和 hand sudi使用
    local turntime = tonumber(rcvobj.turntime or 10)
    local shuffle = tonumber(rcvobj.shuffle or 0) -- 0所有 1洗牌  2不洗牌
    local voice = tonumber(rcvobj.voice or 0) -- 0所有  1开启音效 2不开启
    local private = tonumber(rcvobj.private or 0) --0所有 1私有 2公有
    local gameid = tonumber(rcvobj.gameid or GAME_ID)
    local seat  = tonumber(rcvobj.seat or 4) --人数

    local resp = {c=rcvobj.c, code=PDEFINE.RET.SUCCESS,spcode=0}
    local params = {}
    params.conf = {}
    params.conf.roomtype = PDEFINE.BAL_ROOM_TYPE.VIP
    params.conf.bet = score
    params.conf.score = score
    params.conf.entry = entry
    params.conf.turntime = turntime
    params.conf.shuffle = shuffle
    params.conf.voice = voice
    params.conf.private = private
    params.conf.seat = seat
    params.gameid = gameid
    local ok, desk, retobj = createDesk(uid, params)
    LOG_DEBUG("createVipRoom ok:", ok, ' desk:', desk, ' retobj:', retobj)
    if not ok or type(desk)=="number" or desk ==nil then
        LOG_DEBUG("createVipRoom createDeskfailed uid:", uid, ' retobj:', desk)
        resp.spcode = desk
        return PDEFINE.RET.SUCCESS, resp
    end
    
    resp.deskinfo = {
        ['deskid'] = desk.deskid,
        ['conf'] = params.conf,
        ['users'] = desk.users
    }
    leaveVipRoomListPage(uid, PDEFINE.BAL_ROOM_TYPE.VIP)
    WAITING_USERS[uid] = desk.deskid
    if private ~= 1 then --私人房不用通知其他人刷新
        refreshVipRoomList(gameid)
    end
    return PDEFINE.RET.SUCCESS, resp
end

--! 加入vip房间
function CMD.joinVipRoom(rcvobj)
    local uid = tonumber(rcvobj.uid)
    local deskid = tonumber(rcvobj.deskid or 0)
    local gameid = tonumber(rcvobj.gameid or GAME_ID)
    if nil == vip_desk_list[gameid] then
        vip_desk_list[gameid] = {}
    end
    local deskInfo = vip_desk_list[gameid][deskid]
    LOG_DEBUG("vip_desk_list: ", vip_desk_list, 'deskid:', deskid, ' type:', type(deskid))
    local resp = {c=rcvobj.c, code=PDEFINE.RET.SUCCESS,spcode=0}
    if not deskInfo then
        resp.spcode = PDEFINE.RET.ERROR.GAME_IS_RUNNING
        return PDEFINE.RET.SUCCESS, resp
    end
    
    local ok, retcode, deskAddr, _ = joinDesk(deskInfo, uid, nil, gameid)
    LOG_DEBUG("joinVIPRoom deskAddr:", deskAddr)
    leaveVipRoomListPage(uid, PDEFINE.BAL_ROOM_TYPE.VIP)
    WAITING_USERS[uid] = deskid
    refreshVipRoomList(gameid)
    return PDEFINE.RET.SUCCESS, deskAddr
end

--! vip房间列表中 直接点seat
function CMD.seatVipRoom(rcvobj)
    local uid = tonumber(rcvobj.uid)
    local deskids = {}
    local gameid = tonumber(rcvobj.gameid or GAME_ID)
    local resp = {c=rcvobj.c, code=PDEFINE.RET.SUCCESS, spcode = 0}
    if not gameid then
        LOG_DEBUG("seatVipRoom gameid err!", gameid)
        resp.spcode = PDEFINE.RET.ERROR.USER_NOT_VIP
        return PDEFINE.RET.SUCCESS, resp
    end

    if nil ~= vip_desk_list[gameid] then
        for deskid, row in pairs(vip_desk_list[gameid]) do
            if row.conf.private ~=1 and #row.users < row.seat then
                table.insert(deskids, deskid)
            end
        end
    end
    
    if table.empty(deskids) then --
        LOG_DEBUG("-----------seatVipRoom 没有房间，去创建房间-----uid：", uid)
        local params = {
            uid = uid,
            entry = 500,
            turntime = 8,
            shuffle = 1,
            private = 0,
            voice = 0,
            score = 500,
            gameid = gameid,
        }
        if gameid ~= PDEFINE.GAME_TYPE.BALOOT then
            params.score = 10
        end
        local ok, data = CMD.createVipRoom(params)
        resp.deskinfo = data.deskinfo
        return PDEFINE.RET.SUCCESS, resp
    end
    local agent = getAgent(uid)
    local ok , cluster_desk = pcall(cluster.call, agent.server, agent.address, "getClusterDesk")
    if ok and not table.empty(cluster_desk) then
        LOG_DEBUG("-----------seatVipRoom 已有房间，-----cluster_desk:", cluster_desk)
        local ok, deskInfo = pcall(cluster.call, cluster_desk.server, cluster_desk.address, "getDeskInfo", {uid=uid})
        LOG_DEBUG("-----------seatVipRoom deskInfo-----:", deskInfo)
        if ok then
            local tmp = {
                ['deskid'] = deskInfo.deskid,
                ['conf'] = deskInfo.conf,
                ['users'] = deskInfo.users
            }
            resp.deskinfo = tmp
        else
            LOG_ERROR("seatVipRoom 获取房间信息失败, uid:", uid, ' cluster_desk:', cluster_desk)
        end
        return PDEFINE.RET.SUCCESS, resp
    end

    local targetid = deskids[math.random(1, #deskids)]
    local deskInfo = vip_desk_list[gameid][targetid]
    LOG_DEBUG("seatVipRoom vip_desk_list: ", vip_desk_list[gameid], 'deskid:', targetid, ' type:', type(targetid))
    if not deskInfo then
        return 400
    end
    local ok, code, deskAddr, _ = joinDesk(deskInfo, uid, nil, gameid)
    if code ~= PDEFINE.RET.SUCCESS then
        resp.spcode = code
        return PDEFINE.RET.SUCCESS, resp
    end
    local deskinfo = {
        ['deskid'] = targetid,
        ['conf'] = deskAddr.deskinfo.conf,
        ['users'] = deskAddr.deskinfo.users
    }
    resp.deskinfo = deskinfo
    LOG_DEBUG("seatVipRoom joinVIPRoom deskAddr:", deskAddr)
    leaveVipRoomListPage(uid, PDEFINE.BAL_ROOM_TYPE.VIP)
    WAITING_USERS[uid] = targetid
    refreshVipRoomList(gameid)
    return PDEFINE.RET.SUCCESS, resp
end

--! 退出vip房间
function CMD.exitVipRoom(rcvobj)
    local uid = rcvobj.uid
    local deskid = math.floor(rcvobj.deskid or 0)
    local gameid = tonumber(rcvobj.gameid or GAME_ID)
    local deskInfo = nil
    if vip_desk_list[gameid] and vip_desk_list[gameid][deskid] then
        deskInfo = vip_desk_list[gameid][deskid]
    end
    LOG_DEBUG("exitVipRoom deskInfo:", deskInfo, ' rcvobj:', rcvobj)
    if deskInfo then
        local exists = false
        for i= #deskInfo.users, 1, -1 do
            if deskInfo.users[i].uid == uid then
                table.remove(deskInfo.users, i)
                deskInfo.curseat = deskInfo.curseat - 1
                exists = true
            end
        end
        LOG_DEBUG("exists:", exists, " deskInfo.users:", deskInfo.users)
        if exists then
            local ok, retcode, retobj = pcall(cluster.call, deskInfo.server, deskInfo.address, 'exitG', rcvobj)
            LOG_DEBUG("exists agent:", ok, retcode, retobj)
            if ok and retcode== PDEFINE.RET.SUCCESS then
                if deskInfo.owner == uid then
                    LOG_DEBUG("owner exitVipRoom ", uid)
                    local resp = {c=PDEFINE.NOTIFY.BALOOT_DISMISS_VIPROOM, code=PDEFINE.RET.SUCCESS, deskid = deskInfo.deskid}
                    for _, muser in pairs(deskInfo.users) do
                        pcall(cluster.call, deskInfo.server, deskInfo.address, 'exitG', {uid=muser.uid})
                        local agent = getAgent(muser.uid)
                        if agent then
                            pcall(cluster.call, agent.server, agent.address, "sendToClient", cjson.encode(resp))
                        end
                    end
                    vip_desk_list[gameid][deskid] = nil
                else
                    LOG_DEBUG("user exitVipRoom ", uid)
                    local resp = {c=PDEFINE.NOTIFY.BALOOT_JOIN_VIPROOM, code=PDEFINE.RET.SUCCESS}
                    resp.deskid = deskInfo.deskid
                    resp.users  = deskInfo.users
                    resp.conf   = deskInfo.conf
                    for _, muser in pairs(deskInfo.users) do
                        local agent = getAgent(muser.uid)
                        if agent then
                            pcall(cluster.call, agent.server, agent.address, "sendToClient", cjson.encode(resp))
                        end
                    end
                end
            end
        end
    end
    WAITING_USERS[uid] = nil
    skynet.send('.invitemgr', 'lua', 'enter', uid, PDEFINE.BAL_ROOM_TYPE.VIP)
    return PDEFINE.RET.SUCCESS
end

-- call by balootagent
function CMD.removeVipWaitUsers(uids)
    if #uids > 0 then
        for _, uid in pairs(uids) do 
            WAITING_USERS[uid] = nil
        end
    end
end



--! 获取vip房间列表
function CMD.getVipRoomList(rcvobj)
    local uid = rcvobj.uid
    local state = tonumber(rcvobj.state or 0)
    local entry = tonumber(rcvobj.entry or 0)
    local turntime = tonumber(rcvobj.turntime or 0)
    local shuffle = tonumber(rcvobj.shuffle or 0)
    local voice = tonumber(rcvobj.voice or 0)
    local gameid = tonumber(rcvobj.gameid or GAME_ID)
    local seat = tonumber(rcvobj.seat or 0)
    local filters = {}
    filters.private = 2 --只显示公开房
    if seat > 0 then
        filters.seat = seat
    end
    if state == 2 then
        filters.state = 2 --隐藏满员的房间
    end
    if entry > 0 then
        filters.entry = math.floor( entry )
    end
    if turntime > 0 then
        filters.turntime = math.floor( turntime )
    end
    if shuffle > 0 then
        filters.shuffle = shuffle
    end
    if voice > 0 then
        filters.voice = voice
    end

    local roomList = filterDeskList(filters, gameid)

    skynet.send('.invitemgr', 'lua', 'enter', uid, PDEFINE.BAL_ROOM_TYPE.VIP, gameid)
    local resp = {c=rcvobj.c, code=PDEFINE.RET.SUCCESS}
    resp.data = roomList
    return PDEFINE.RET.SUCCESS, resp
end

--! 退出房间列表(退出online/league/viproomlit页面)
function CMD.exitRoomList(rcvobj)
    local uid = rcvobj.uid
    local roomtype = tonumber(rcvobj.roomtype or 1)
    if roomtype == PDEFINE.BAL_ROOM_TYPE.VIP then
        if nil ~= WAITING_USERS[uid] then
            local deskid = WAITING_USERS[uid]
            LOG_DEBUG("exitVipRoomList uid:", uid, ' deskid:', deskid)
        end
    end

    leaveVipRoomListPage(uid) --回大厅了
    return PDEFINE.RET.SUCCESS
end

-- 从房间内同步
function CMD.syncVipRoomData(gameid, deskid, users, score)
    LOG_DEBUG("syncVipRoomData deskid:", deskid, ' users:', users, ' score:', score)
    deskid = tonumber(deskid)
    local ok, uids = pcall(skynet.call, ".invitemgr", "lua", "getUidsByRoomType", PDEFINE.BAL_ROOM_TYPE.VIP)
    if ok and uids and vip_desk_list[gameid] then
        for did, row in pairs(vip_desk_list[gameid]) do
            if tonumber(did) == deskid then
                LOG_DEBUG("did == deskid ", deskid)
                if #users == 0 then
                    LOG_DEBUG("删除桌子了 deskid:", deskid)
                    vip_desk_list[gameid][did] = nil --直接删除列表
                    break
                else
                    row.score = score or 0
                    local vipUsers = {}
                    for _, user in pairs(users) do
                        local item = {
                            ['uid']  = user.uid,
                            ['playername'] = user.playername,
                            ['usericon'] = user.icon,
                            ['seatid'] = user.seatid
                        }
                        table.insert(vipUsers, item)
                    end
                    row.users = vipUsers
                end
            end
        end

        local roomList = filterDeskList({}, gameid)
        local resp = {c= PDEFINE.NOTIFY.BALOOT_REFLASH_VIPROOM, code=PDEFINE.RET.SUCCESS, data = roomList}

        for uid, _ in pairs(uids) do
            local agent = getAgent(uid)
            if agent then
                pcall(cluster.call, agent.server, agent.address, "sendToClient", cjson.encode(resp))
            end
        end
    end
end

-- 删除vip房间列表中的房间信息 call by agentdesk.lua
function CMD.removeVipRoom(deskid)
    deskid = tonumber(deskid)
    for gameid, items in pairs(vip_desk_list) do
        for mdeskid, deskinfo in pairs(items) do
            if mdeskid == deskid then
                if #deskinfo.users == 0 then
                    vip_desk_list[gameid][deskid] = nil
                end
                refreshVipRoomList(gameid)
            end
        end
    end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = assert(CMD[cmd])
        skynet.retpack(f(...))
	end)
    skynet.register(".balviproommgr")
    collectgarbage("collect")
end)