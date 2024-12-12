-- 在线baloot游戏
local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local queue     = require "skynet.queue"
local player_tool = require "base.player_tool"
local cjson = require "cjson"
local cs = queue()
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local APP = tonumber(skynet.getenv("app")) or 1

local GAME_ID = 256
local NO_LEAGUE_UID = 100  --hand无多人排位赛，用100代替队友id，和baloot通用接口

--接口
local CMD = {}

local WAITING_USERS_LEAGUE_1 = {} --排位赛 单排
local WAITING_USERS_LEAGUE_2 = {} --排位赛 双排
local creating_users = {}
local assignUsers = {}

local function genAssignId()
    local mailid = do_redis({ "incr", "baloot_assign"})
    return mailid
end

local function genAssignObj(stype, entry)
    local matchid = genAssignId()
    if nil == entry then
        entry = 0
    end
    local item = {
        id = matchid,
        bet = entry,
        type = stype,
        users = {}
    }
    return item
end

local function getAgent(uid)
    return skynet.call(".userCenter", "lua", "getAgent", uid)
end

local function addAi(desk, aiuser)
    local retok, retcode, num = pcall(cluster.call, desk.server, desk.address, "aiJoin", aiuser)
    if retok and retcode == PDEFINE.RET.SUCCESS then
        desk.curseat = desk.curseat + num
        return true
    end
    return false;
end

-- 加入桌子
local function joinDesk(desk, uid, seatid)
    local agent = getAgent(uid)
    local params = {}
    params.gameid = desk.gameid
    params.deskid = desk.deskid
    params.uid = uid
    params.c = 43
    if seatid and seatid > 0 then
        params.seatid = 3
    end
    LOG_DEBUG("joinDesk: msg:", params)
    local retok,retcode,retobj,deskAddr = pcall(cluster.call, desk.server, ".dsmgr", "joinDeskInfo", agent, params, "127.0.0.1", params.gameid)
    LOG_DEBUG("joinDesk return retcode:".. retcode .. "retobj:", retobj, ' deskAddr:', deskAddr)
    if not retok or retcode ~= PDEFINE.RET.SUCCESS then
        LOG_WARNING("加入匹配房间失败", retok, retcode)
        if desk.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.VIP then
            local resp = {c=PDEFINE.NOTIFY.BALOOT_JOIN_VIPROOM, code=PDEFINE.RET.SUCCESS, spcode=retcode}
        end
        return retok,retcode,retobj,deskAddr
    end
    -- 加入桌子
    skynet.call(".agentdesk","lua","joinDesk", deskAddr, uid)

    -- 人数加1
    desk.curseat = desk.curseat + 1

    --通知客户端
    if desk.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        retobj.c = 43
        retobj.code = PDEFINE.RET.SUCCESS
        pcall(cluster.call, agent.server, agent.address, "sendToClient", cjson.encode(retobj))
    else
        local resp = {c=PDEFINE.NOTIFY.BALOOT_JOIN_VIPROOM, code=PDEFINE.RET.SUCCESS}
        resp.deskid = retobj.deskinfo.deskid
        resp.users  = retobj.deskinfo.users
        resp.conf   = retobj.deskinfo.conf
        local users = {}
        for _, muser in pairs(retobj.deskinfo.users) do
            local agent = getAgent(muser.uid)
            if agent then
                pcall(cluster.call, agent.server, agent.address, "sendToClient", cjson.encode(resp))
            end

            table.insert(users, {
                ['uid'] = muser.uid,
                ['playername'] = muser.playername,
                ['usericon'] = muser.usericon,
                ['seatid'] = muser.seatid,
            })
        end
        desk.users = users
    end
    skynet.send('.invitemgr', 'lua', 'leave', {uid})
    -- 设置玩家桌子
    pcall(cluster.call, agent.server, agent.address, "setClusterDesk", deskAddr)
    return true, 200, retobj, deskAddr
end

-- 创建桌子
local function createDesk(uid, params)
    params = params or {}
    params.uid = uid
    params.gameid = params.gameid or GAME_ID
    local gameName = skynet.call(".mgrdesk", "lua", "getMatchGameName", params.gameid)
    local needSeat = PDEFINE.GAME_TYPE_INFO[APP][1][params.gameid].SEAT
    params.seat = needSeat

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
        seat = retobj.deskinfo.seat,
        conf = retobj.deskinfo.conf, --conf.roomtype 房间类型1：匹配房 2:vip房 3排位赛
        users = {},
        score = retobj.deskinfo.panel and retobj.deskinfo.panel.score or 0,
        owner = uid,
    }
    for _, user in pairs(retobj.deskinfo.users) do
        local item = {
            ['uid']  = user.uid,
            ['playername'] = user.playername,
            ['usericon'] = user.usericon,
            ['seatid'] = user.seatid
        }
        table.insert(desk.users, item)
    end
    skynet.send('.invitemgr', 'lua', 'leave', {uid})
    pcall(cluster.call, agent.server, agent.address, "setClusterDesk", deskAddr)
    return true, desk, retobj
end

local function entryDesk(users, entry, league, matchid, gameid)
    local usersData = table.copy(users)
    local size = #users --是否要加机器人
    local needSeat = PDEFINE.GAME_TYPE_INFO[APP][1][gameid].SEAT
    if size < needSeat then
        local num = needSeat - size
        local ok, aiUserList = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", num, true)
        -- LOG_DEBUG("entryDesk 加入机器人个数：", num, aiUserList)
        if ok and not table.empty(aiUserList) then
            for _, ai in pairs(aiUserList) do
                local itemData = {
                    ['uid'] = ai.uid,
                    ['playername'] = ai.playername,
                    ['usericon'] = ai.usericon
                }
                table.insert(usersData, itemData)

                for _, muser in pairs(users) do
                    if muser.agent then
                        local retobj = {}
                        retobj.c = PDEFINE.NOTIFY.BALOOT_MATH_RESULT
                        retobj.code = PDEFINE.RET.SUCCESS
                        retobj.spcode = 0
                        retobj.users = usersData
                        retobj.gameid = gameid
                        pcall(cluster.call, muser.agent.server, muser.agent.address, "sendToClient", cjson.encode(retobj))
                    end
                end
                skynet.sleep(20)
            end
        end
    end
    local owner = usersData[1]['uid'] --房主uid
    local params = {
        ['conf'] = {
            ['roomtype'] = PDEFINE.BAL_ROOM_TYPE.MATCH,
            ['bet'] = entry,
            ['round'] = 1
        }
    }
    if league then --baloot玩法(1:单排;2:双排;3:多人匹配)； hand(1：单人单局；2:5局单人排位赛；3:5局匹配赛)
        if league == 3 then  -- 3 是从 assignOnlineTwo 方法调用过来的
            params['conf']['roomtype'] = PDEFINE.BAL_ROOM_TYPE.MATCH
        else  -- 1 是从 assignLeagueSingle 从过来的 2 是从 assignLeaguePair 传过来的
            params['conf']['roomtype'] = PDEFINE.BAL_ROOM_TYPE.LEAGUE
            params['conf']['league'] = 1
        end
        if gameid == PDEFINE.GAME_TYPE.HAND then
            if league == 2 or league == 3 then -- 3是双人匹配
                params['conf']['round'] = 5
            end
        end
        if gameid == PDEFINE.GAME_TYPE.HAND_SAUDI then
            if league == 2 or league == 3 then -- 3是双人匹配
                params['conf']['round'] = 5
            end
        end
    end
    params.gameid = gameid
    LOG_DEBUG("before createDesk owner:", owner, ' params:', params)
    local ok, desk = createDesk(owner, params)
    LOG_DEBUG("after createDesk ok:", ok, ' desk:', desk)
    creating_users[owner] = nil
    if not ok or type(desk)=="number" or desk ==nil then
        LOG_DEBUG("entryDesk createDeskfailed uid:", owner, ' retobj:', desk)
        local retcode = desk
        for _, muser in pairs(users) do
            if muser.agent then
                local retobj = {}
                retobj.c = PDEFINE.NOTIFY.BALOOT_MATH_RESULT
                retobj.code = PDEFINE.RET.SUCCESS
                retobj.spcode = retcode
                retobj.users = usersData
                pcall(cluster.call, muser.agent.server, muser.agent.address, "sendToClient", cjson.encode(retobj))
            end
        end
        return
    end
    for i= 2, needSeat do
        if usersData[i].agent then
            local seatid = 0
            if league and (league == 2 or league == 3) and i==2 and needSeat == 4 then
                seatid = 3 --双排，第2个人是好友，坐对门
            end
            joinDesk(desk, usersData[i].uid, seatid)
            creating_users[usersData[i].uid] = nil
        else
            addAi(desk, usersData[i])
        end
    end
    LOG_DEBUG("matchid:", matchid, ' assignUsers:', assignUsers)
    if matchid then
        assignUsers[matchid] = nil
    end
    local ok, deskInfo = pcall(cluster.call, desk.server, desk.address, "getDeskInfo", {uid=owner})
    LOG_DEBUG("ok:", ok, ' deskInfo:', deskInfo)
    if ok then 
        local retobj = {}
        retobj.c = 43
        retobj.gameid= gameid
        retobj.code = PDEFINE.RET.SUCCESS
        retobj.deskinfo = deskInfo
        for _, muser in pairs(usersData) do 
            if muser.agent then
                pcall(cluster.call, muser.agent.server, muser.agent.address, "sendToClient", cjson.encode(retobj))
            end
        end
    else
        LOG_ERROR("广播房间信息失败, desk:", desk)
    end
end

local function addMatchUsersMsg(users, uid, matchid, gameid)
    local agent = getAgent(uid)
    LOG_DEBUG("addMatchUsersMsg users:", users, ' uid：',uid, ' matchid:', matchid, ' agent:', agent)
    local ok, info = pcall(cluster.call, agent.server, agent.address, "getPlayerInfo")
    table.insert(users, {
        ['uid'] = uid,
        ['playername'] = info.playername,
        ['usericon'] = info.usericon,
        ['agent'] = agent,
    })
    for _, muser in pairs(users) do --匹配1个通知1次
        local retobj = {}
        retobj.c = PDEFINE.NOTIFY.BALOOT_MATH_RESULT
        retobj.code = PDEFINE.RET.SUCCESS
        retobj.users = users
        retobj.matchid= matchid
        retobj.gameid = gameid
        retobj.spcode = 0
        pcall(cluster.call, muser.agent.server, muser.agent.address, "sendToClient", cjson.encode(retobj))
    end
end

local function checkUserCoin(userInfo, isParter, entry)
    if userInfo.coin < entry then
        if isParter then
            return PDEFINE.RET.ERROR.LEAGUE_PARTER_COIN
        else
            return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        end
    end
    if isParter then
        local onlineData = skynet.call(".userCenter", "lua", "checkOnline", {userInfo.uid})
        if not onlineData[userInfo.uid] then
            return PDEFINE.RET.ERROR.PARTER_NOT_ONLINE
        end
    end
    return 0
end

--! 邀请好友，切换场次
function CMD.changeSess(rcvobj)
    local uid = tonumber(rcvobj.uid)
    local parterId = math.floor(rcvobj.frienduid or 0)
    local gameid = math.floor(rcvobj.gameid or GAME_ID)
    local entry = tonumber(rcvobj.entry or 2000)
    local retobj = {c= rcvobj.c, code= PDEFINE.RET.SUCCESS, spcode=0, entry=entry, gameid=gameid}
    local minCoin = entry
    if nil == minCoin then
        LOG_DEBUG('error uid:',uid, ' entry:', entry)
        retobj.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        return PDEFINE.RET.SUCCESS, retobj
    end

    local userInfo = player_tool.getPlayerInfo(uid)
    local spcode = checkUserCoin(userInfo, false, minCoin)
    if spcode > 0 then
        retobj.spcode = spcode
        return PDEFINE.RET.SUCCESS, retobj
    end
       
    if parterId ~= NO_LEAGUE_UID then
        local parterInfo = player_tool.getPlayerInfo(parterId)
        spcode = checkUserCoin(parterInfo, true, minCoin)
        if spcode > 0 then
            retobj.spcode = spcode
            return PDEFINE.RET.SUCCESS, retobj
        end
    end
    return PDEFINE.RET.SUCCESS, retobj
end

-- 检查门票
local function checkTicket(userInfo, isParter, gameid, ticketIdx)
    local TICKETS = PDEFINE.TICKET
    local useTicket = TICKETS["TICKET"][ticketIdx] --排位赛固定采用hand的
    local flag = 0
    if gameid == PDEFINE.GAME_TYPE.HAND and ticketIdx == 2 then --hand normal排位赛
        flag = 1
    end
    if userInfo.ticket <= flag then
        -- local agent = skynet.call(".userCenter", "lua", "getAgent", userInfo.uid)
        -- if agent then
            local cacheKey = "today_league_time:".. userInfo.uid
            local times = do_redis({"get", cacheKey})
            times = times or 0
            times = times + 1
            if times >= 1 and times  <= 5 then
                local vip = userInfo.svip or 0
                if vip < 0 then
                    vip = 0
                end
                local useDiamond = TICKETS['VIP'..userInfo.svip][times]
                if flag == 1 then
                    useDiamond = useDiamond * 2
                end
                if userInfo.diamond < useDiamond then
                    if isParter then
                        return PDEFINE.RET.ERROR.LEAGUE_PARTER_DIAMOND
                    else
                        return PDEFINE.RET.ERROR.LEAGUE_USER_DIAMOND
                    end
                else
                    local up_data = {
                        diamond = - useDiamond,
                        act = "ticket"
                    }
                    skynet.call(".userCenter", "lua", "updateUserLevelInfo", userInfo.uid, up_data)
                end
            else
                if isParter then
                    return PDEFINE.RET.ERROR.LEAGUE_PARTER_TIMES
                else
                    return PDEFINE.RET.ERROR.LEAGUE_USER_TIMES
                end
            end

            if times == 1 then --第1次超额
                local leftTime = getThisPeriodTimeStamp()
                do_redis({"setex", cacheKey , times, leftTime})
            else
                do_redis({"set", cacheKey , times})
            end
        -- else
        --     if isParter then
        --         return PDEFINE.RET.ERROR.LEAGUE_PARTER_TIMES
        --     else
        --         return PDEFINE.RET.ERROR.LEAGUE_USER_TIMES
        --     end
        -- end
    else
        local leftTicket = userInfo.ticket - useTicket
        local up_data = {
            ticket = leftTicket
        }
        skynet.call(".userCenter", "lua", "updateUserLevelInfo", userInfo.uid, up_data)
    end
    return 0
end


--! 进入排位赛
function CMD.joinLeague(rcvobj)
    local uid = rcvobj.uid
    local parterId = math.floor(rcvobj.frienduid or 0) -- frienduid大于0 表示双排, 否则单排
    local gameid = math.floor(rcvobj.gameid or 0) --游戏id
    local retobj = {c= rcvobj.c, code= PDEFINE.RET.SUCCESS, spcode=0, users={}, gameid=gameid}

    local ticketIdx = 1
    if gameid == PDEFINE.GAME_TYPE.HAND and parterId == 100 then
        ticketIdx = 2
    end
    local userInfo = player_tool.getPlayerInfo(uid)
    local spcode = checkTicket(userInfo, false, gameid, ticketIdx)
    if spcode > 0 then
        retobj.spcode = spcode
        return PDEFINE.RET.SUCCESS, retobj
    end

    table.insert(retobj.users, {
        ['uid'] = uid,
        ['playername'] = userInfo.playername,
        ['usericon'] = userInfo.usericon,
        ['avatarframe'] = userInfo.avatarframe
    })
    local uids = {uid}
    if parterId > 0 and gameid == PDEFINE.GAME_TYPE.BALOOT then
        local onlineData = skynet.call(".userCenter", "lua", "checkOnline", {parterId})
        if not onlineData[parterId] then
            retobj.spcode = PDEFINE.RET.ERROR.PARTER_NOT_ONLINE
            return PDEFINE.RET.SUCCESS, retobj
        end
        local parterInfo = player_tool.getPlayerInfo(parterId)
        spcode = checkTicket(parterInfo, true, gameid, ticketIdx)
        if spcode > 0 then
            retobj.spcode = spcode
            return PDEFINE.RET.SUCCESS, retobj
        end
        table.insert(retobj.users, {
            ['uid'] = parterId,
            ['playername'] = parterInfo.playername,
            ['usericon'] = parterInfo.usericon,
            ['avatarframe'] = parterInfo.avatarframe
        })
        table.insert(uids, parterId)
    end

    skynet.send(".userCenter", "lua", "leagueResume", uids)
    if parterId == 0 then
        if nil == WAITING_USERS_LEAGUE_1[gameid] then
            WAITING_USERS_LEAGUE_1[gameid] = {}
        end
        if not table.contain(WAITING_USERS_LEAGUE_1[gameid], uid) then
            table.insert(WAITING_USERS_LEAGUE_1[gameid], uid)
        end
    else
        if nil == WAITING_USERS_LEAGUE_2[gameid] then
            WAITING_USERS_LEAGUE_2[gameid] = {}
        end
        if WAITING_USERS_LEAGUE_2[gameid] and not table.contain(WAITING_USERS_LEAGUE_2[gameid], uid) then
            table.insert(WAITING_USERS_LEAGUE_2[gameid], uid)
            if parterId > 0 and parterId ~= NO_LEAGUE_UID then
                table.insert(WAITING_USERS_LEAGUE_2[gameid], parterId)
            end
        end
        if parterId ~= NO_LEAGUE_UID then
            skynet.send(".userCenter", "lua", "pushInfoByUid", parterId, cjson.encode(retobj))
        end
    end
    return PDEFINE.RET.SUCCESS, retobj
end

-- 单人排位赛分配
local function assignLeagueSingle()
    local league = 1
    for gameid, _ in pairs(WAITING_USERS_LEAGUE_1) do
        local tryTimes = 0
        local count = #WAITING_USERS_LEAGUE_1[gameid]
        local entry = 500 --无用
        LOG_DEBUG(" entry" .. entry .. " assignLeagueSingle 的等待人数: " .. count)
        local needSeat = PDEFINE.GAME_TYPE_INFO[APP][1][gameid].SEAT
        while count > 0 do
            if count >= needSeat then
                local assignObj = genAssignObj('league1')
                assignUsers[assignObj.id] = assignObj
                local users = {}
                for i=1,needSeat do
                    local uid = table.remove(WAITING_USERS_LEAGUE_1[gameid], 1)
                    creating_users[uid] = 1 --正在进入房间
                    table.insert(assignObj.users, uid)
                    addMatchUsersMsg(users, uid, assignObj.id, gameid)
                end
                entryDesk(users, entry, league, assignObj.id, gameid)
            end
            tryTimes = tryTimes + 1
            if tryTimes >= 4 then
                if count < needSeat then
                    local users = {}
                    local assignObj = genAssignObj('league1')
                    assignUsers[assignObj.id] = assignObj
                    for i=1, count do
                        local uid = table.remove(WAITING_USERS_LEAGUE_1[gameid], 1)
                        creating_users[uid] = 1 --正在进入房间
                        table.insert(assignObj.users, uid)
                        addMatchUsersMsg(users, uid, assignObj.id, gameid)
                    end
                    entryDesk(users, entry, league, assignObj.id, gameid)
                end
                break
            end
            skynet.sleep(100)
            count = #WAITING_USERS_LEAGUE_1[gameid]
        end
    end
end

local function assignLeaguePair()
    local league = 2
    for gameid, _ in pairs(WAITING_USERS_LEAGUE_2) do
        local tryTimes = 0
        local count = #WAITING_USERS_LEAGUE_2[gameid]
        local entry = 500
        local needSeat = PDEFINE.GAME_TYPE_INFO[APP][1][gameid].SEAT
        LOG_DEBUG(" entry" .. entry .. " 的assignLeaguePair等待人数: " .. count)
        while count > 0 do
            if count >= needSeat then
                local assignObj = genAssignObj('league2')
                assignUsers[assignObj.id] = assignObj
                local users = {}
                for i=1,needSeat do
                    local uid = table.remove(WAITING_USERS_LEAGUE_2[gameid], 1)
                    creating_users[uid] = 1 --正在进入房间
                    table.insert(assignObj.users, uid)
                    addMatchUsersMsg(users, uid, assignObj.id, gameid)
                end
                entryDesk(users, entry, league, assignObj.id, gameid)
            end
            tryTimes = tryTimes + 1
            if tryTimes >= 4 then
                if count < needSeat then
                    local assignObj = genAssignObj('league2')
                    assignUsers[assignObj.id] = assignObj
                    local users = {}
                    for i=1, count do
                        local uid = table.remove(WAITING_USERS_LEAGUE_2[gameid], 1)
                        creating_users[uid] = 1 --正在进入房间
                        table.insert(assignObj.users, uid)
                        addMatchUsersMsg(users, uid, assignObj.id, gameid)
                    end
                    entryDesk(users, entry, league, assignObj.id, gameid)
                end
                break
            end
            skynet.sleep(100)
            count = #WAITING_USERS_LEAGUE_2[gameid]
        end
    end
end

-- 单人排位赛队列
local function threadLeagueSingle(interval)
    while true do
        xpcall(assignLeagueSingle,
            function(errmsg)
                print(debug.traceback(tostring(errmsg)))
            end,
            interval)
        skynet.sleep(100)
    end
end

-- 双人排位赛 队列
local function threadLeaguePair(interval)
    while true do
        xpcall(assignLeaguePair,
            function(errmsg)
                print(debug.traceback(tostring(errmsg)))
            end,
            interval)
        skynet.sleep(100)
    end
end

function CMD.start()
    -- skynet.fork(threadOnlineOne, 100)
    -- skynet.fork(threadOnlineTwo, 100)
    skynet.fork(threadLeagueSingle, 100)
    skynet.fork(threadLeaguePair, 100)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = assert(CMD[cmd])
        skynet.retpack(f(...))
	end)
    skynet.register(".balmatchmgr")
    collectgarbage("collect")
end)
