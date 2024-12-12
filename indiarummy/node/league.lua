-- 排位赛信息接口
local cjson   = require "cjson"
local skynet = require "skynet"
local cluster = require "cluster"
local player_tool = require "base.player_tool"
local queue = require "skynet.queue"
local date = require "date"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local league = {}
local ENTRY = 0 --匹配场的场次金币
local handle
local UID
local league_info = {
    data = {},
    iscaptain = false, --是否队长
    parterId = 0, --队友
}

function league.bind(agent_handle)
	handle = agent_handle
end

function league.initUid(uid)
    UID = uid
end

function league.init(uid)
    UID = uid
end

local function initInfo(data)
    league_info.data = data
end

local function setCaptain(flag)
    league_info.iscaptain = flag
end

local function setParter(uid)
    league_info.parterId = uid
end

-- 获取赛季信息
local function getLeagueInfo()
    local redisKey = PDEFINE.LEAGUE.SEASON_KEY
    local seasonInfo = do_redis({"hgetall", redisKey})
    if not seasonInfo or table.empty(seasonInfo) then
        local stopTime = date.GetNextWeekDayTime(os.time(), 1)
        seasonInfo = {
            id = 1,
            startTime = stopTime-7*24*60*60,
            stopTime = stopTime
        }
        LOG_DEBUG("初始化联赛赛季信息...", seasonInfo)
        do_redis({"hset", redisKey, "id", seasonInfo.id})
        do_redis({"hset", redisKey, "startTime", seasonInfo.startTime})
        do_redis({"hset", redisKey, "stopTime", seasonInfo.stopTime})
    else
        seasonInfo = make_pairs_table_int(seasonInfo)
    end
    return seasonInfo
end

local function initLeagueInfo(gameid, uid)
    local playerInfo = handle.moduleCall("player","getPlayerInfo", uid)
    local ok, season = pcall(cluster.call, "master", ".configmgr", "getCurrSeason")
    local userLeagueLevel = playerInfo.leaguelevel or 0
    local userLeagueExp = playerInfo.leagueexp or 0
    local ok, leagueArr = pcall(cluster.call, "master", ".cfgleague", "getCurAndNextLvInfo", userLeagueLevel)
    if ok then
        userLeagueExp = leagueArr[1].score + userLeagueExp
    end
    local next_id = userLeagueLevel + 1
    LOG_DEBUG("initLeagueInfo season:", season)
    local data = {
        next_id = next_id,
        season = season.id, -- 第几个赛季
        season_start_time = season.start_time, --这个赛季开始时间
        season_end_time = season.end_time , --这个赛季结束时间
        open_time = 0, --比赛开始时间
        close_time = 7, --比赛结束时间
    }
    if data.next_id > 31 then
        data.next_id = 31
    end

    local sql = string.format( "select * from d_user_statis where uid=%d and gameid=%d", uid, gameid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local league_wintimes, league_times, winRate = 0, 0, 0
    if #rs > 0 then
        league_wintimes = rs[1].league_wintimes or 0
        league_times    = rs[1].league_times or 0
        if rs[1].league_wintimes and rs[1].league_times and rs[1].league_wintimes > 0 then
            winRate = string.format("%.2f", rs[1].league_wintimes/rs[1].league_times * 100)
            winRate = tonumber(winRate)
        end
    end
    local userinfo = {
        ticket = playerInfo.ticket, --入场券数量
        league_level = userLeagueLevel, --排位赛等级
        points = userLeagueExp, --当前排位赛积分 客户端的total
        win_streak = league_wintimes, --连胜次数 
        matches = league_times, --参赛次数
        win_rate = winRate , --胜率
        uid = uid,
        playername = playerInfo.playername,
        usericon = playerInfo.usericon,
        avatarframe = playerInfo.avatarframe,
        owner = 0,
        svip = playerInfo.svip,
    }
    return data, userinfo
end

local function calConsume(userInfo, gameid, double)
    local data = {type=PDEFINE.PROP_ID.LEAGUE_TICKET, count=1}
    local flag = 0
    if double then
        flag = 1
    end
    if userInfo.ticket <= flag then
        local TICKETS = PDEFINE.TICKET
        local cacheKey = "today_league_time:".. userInfo.uid
        local times = do_redis({"get", cacheKey})
        times = times or 0
        times = times + 1
        local vip = userInfo.svip or 0
        if vip < 0 then
            vip = 0
        end
        LOG_DEBUG("calConsume, vip:", vip, ' times:', times, ' TICKETS:',TICKETS)
        if times>0 and times <= 5 then
            data.type = PDEFINE.PROP_ID.DIAMOND
            data.count = TICKETS['VIP'..vip][times]
        else
            data = {type=PDEFINE.PROP_ID.LEAGUE_TICKET, count=1} --今日次数已经消耗完, 重新使用门票
        end
    end
    -- LOG_DEBUG("calConsume, double:", double, ' data:', data)
    if double and data.count then
        data.count = data.count * 2
    end
    return data
end

--! 获取我的排位赛信息
function league.info(msg)
    local recvobj   = cjson.decode(msg)
    local gameid = recvobj.gameid
    local data, userinfo = initLeagueInfo(gameid, UID)
    local retobj = {['c'] = math.floor(recvobj.c), ['code']= PDEFINE.RET.SUCCESS}
    retobj.info = data
    retobj.userinfo = userinfo
    retobj.can = 1
    local consume = calConsume(userinfo, gameid, false)
    if table.size(consume) == 0 then
        retobj.can = 0
    end
    retobj.use = consume
    retobj.use2 = calConsume(userinfo, gameid, true)
    if retobj.can == 0 then
        retobj.use = {type=PDEFINE.PROP_ID.LEAGUE_TICKET, count=1}
        retobj.use2 = {type=PDEFINE.PROP_ID.LEAGUE_TICKET, count=2}
    end
    initInfo(data)
    pcall(cluster.call, "master", ".invitemgr", "enter", UID, PDEFINE.BAL_ROOM_TYPE.LEAGUE)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

local function isHandGame(gameid)
    if gameid == PDEFINE.GAME_TYPE.HAND_SAUDI or gameid == PDEFINE.GAME_TYPE.HAND then
        return true
    end
    return false
end

-- 检查门票
local function checkTicket(userInfo, isParter, gameid, ticketIdx)
    local TICKETS = PDEFINE.TICKET
    local useTicket = TICKETS["TICKET"][ticketIdx] --排位赛固定采用hand的
    if userInfo.ticket <= useTicket then
        local cacheKey = "today_league_time:".. userInfo.uid
        local times = do_redis({"get", cacheKey})
        times = times or 0
        times = times + 1
        if times >= 1 and times  <= 5 then
            local useDiamond = TICKETS['VIP'..userInfo.svip][times]
            if isHandGame(gameid) then
                useDiamond = useDiamond * 2
            end
            if userInfo.diamond < useDiamond then
                if isParter then
                    return PDEFINE.RET.ERROR.LEAGUE_PARTER_DIAMOND
                else
                    return PDEFINE.RET.ERROR.LEAGUE_USER_DIAMOND
                end
            end
        else
            if isParter then
                return PDEFINE.RET.ERROR.LEAGUE_PARTER_TIMES
            else
                return PDEFINE.RET.ERROR.LEAGUE_USER_TIMES
            end
        end
    end
    return 0
end

--!邀请好友进行(排位赛/多人匹配)
function league.invite(msg)
    local recvobj   = cjson.decode(msg)
    local roomtype = tonumber(recvobj.roomtype or 1)
    local frienduid = math.floor(recvobj.frienduid or 0)
    local gameid = math.floor( recvobj.gameid or 0 )
    local deskid = math.floor(recvobj.deskid or 0) --vip房间邀请
    local bet = math.floor(recvobj.entry or 0)
    local retobj = {c=math.floor(recvobj.c), code= PDEFINE.RET.SUCCESS, spcode=0, gameid=gameid}
    if frienduid == 0 then
        retobj.spcode = PDEFINE.RET.ERROR.PARTERID_EMPTY
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    local ticketIdx = 1
    if isHandGame(gameid) then
        ticketIdx = 2
    end

    local isonline = true
    local ok , online_list = pcall(cluster.call, "master", ".userCenter", "checkOnline", {frienduid})
    if not ok or online_list[frienduid] == nil then
        isonline = false
    end
    if not isonline then
        retobj.spcode = 2
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    local playerInfo = handle.moduleCall("player","getPlayerInfo", UID)
    if roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        if playerInfo.coin < bet then
            retobj.spcode = PDEFINE_ERRCODE.ERROR.COIN_NOT_ENOUGH
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end

        local parterInfo = handle.moduleCall("player","getPlayerInfo", frienduid)
        if parterInfo.coin < bet then
            retobj.spcode = PDEFINE_ERRCODE.ERROR.LEAGUE_PARTER_COIN
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end
    elseif roomtype == PDEFINE.BAL_ROOM_TYPE.LEAGUE then
        local spcode = checkTicket(playerInfo, false, gameid, ticketIdx)
        if spcode > 0 then
            retobj.spcode = spcode
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end
        local parterInfo = handle.moduleCall("player","getPlayerInfo", frienduid)
        spcode = checkTicket(parterInfo, true, gameid, ticketIdx)
        if spcode > 0 then
            retobj.spcode = spcode
            return PDEFINE.RET.SUCCESS, retobj
        end
    end
    
    if roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        ENTRY = bet
    end
    pcall(cluster.call, "master", ".invitemgr", "enter", UID, roomtype)
    local notify = {
        c = PDEFINE.NOTIFY.BALOOT_LEAGUE_INVITE,
        code = 200,
        roomtype = roomtype,
        deskid = deskid,
        gameid = gameid,
        friend = {
            uid = UID,
            playername = playerInfo.playername,
            usericon = playerInfo.usericon,
            avatarframe = playerInfo.avatarframe,
            vip = playerInfo.svip, --vip级别
            league = playerInfo.leaguelevel, --段位信息
            entry = bet,
        }
    }
    pcall(cluster.call, "master", ".userCenter", "pushInfoByUid", frienduid, cjson.encode(notify))

    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 获取邀请的用户id call by agent
function league.getInfo()
    return league_info, ENTRY
end

--! 被邀请人同意了 (call by parter agent)
function league.invitRet(parterId)
    setCaptain(true) --我是队长
    setParter(parterId)
    local retobj = {c=182, code= PDEFINE.RET.SUCCESS, spcode=0}
    local userInfo = player_tool.getPlayerInfo(parterId)
    local info = {
        uid = parterId,
        playername = userInfo.playername,
        usericon = userInfo.usericon,
        avatarframe = userInfo.avatarframe,
        vip = userInfo.svip,
        league = userInfo.leaguelevel,
    }
    retobj.friend = info
    local ok, roomtype = pcall(cluster.call, "master", ".invitemgr", "getRoomType", UID)
    retobj.roomtype = roomtype
    handle.sendToClient(cjson.encode(retobj)) --通知自己
end

--! 被邀请人接受邀请
function league.accept(msg)
    local recvobj   = cjson.decode(msg)
    local captainId = math.floor(recvobj.frienduid or 0)
    local roomtype = math.floor(recvobj.roomtype or 1)
    local retobj = {c=math.floor(recvobj.c), code= PDEFINE.RET.SUCCESS, spcode=0}

    local ok, captainRoomtype = pcall(cluster.call, "master", ".invitemgr", "getRoomType", captainId) --获取队长邀请匹配的类型
    LOG_DEBUG("league.accept captainId:", captainId, '  roomtype:', captainRoomtype)
    if captainRoomtype == 0 then
        retobj.spcode = 2 --队长可能已经游戏中或者走了
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    if roomtype ~= captainRoomtype then
        retobj.spcode = 3 --队长已经再其他房间了
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    local ok, friendLeague, entry = pcall(cluster.call, "master", ".userCenter", "leagueAct", captainId, "getLeagueInfo")
    LOG_DEBUG("league.accept captainId:", captainId, '  friendLeague:', friendLeague)
    if not ok or table.empty(friendLeague) or friendLeague.parterId > 0 then
        retobj.spcode = 2 --队长已经有队友了
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    setCaptain(false)  --我是队友
    setParter(captainId)
    LOG_DEBUG("league.accept captainId:", captainId, '  after setParter')
    pcall(cluster.call, "master", ".userCenter", "leagueAct", captainId, "leagueInvite", UID)
    handle.changeGstatus(1)
    LOG_DEBUG("after changeGstatus 1")
    retobj.entry = entry --匹配场被邀请的场次押注金币
    retobj.roomtype = roomtype
    local userInfo = player_tool.getPlayerInfo(captainId)
    local info = {
        uid = captainId,
        playername = userInfo.playername,
        usericon = userInfo.usericon,
        avatarframe = userInfo.avatarframe,
        vip = userInfo.svip,
        league = userInfo.leaguelevel,
    }
    retobj.friend = info

    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 在排位赛等待界面被T掉 (call by parter agent)
function league.kicked(friendUid)
    setParter(0) --没队友了
    setCaptain(true) --自己变为队长
    handle.changeGstatus(0)
    local notify = {
        c = 184,
        code = 200,
        frienduid = friendUid,
        spcode= 0,
    }
    handle.sendToClient(cjson.encode(notify)) --通知自己, 队友离开了
end

--! 踢掉
function league.kickout(msg)
    local recvobj   = cjson.decode(msg)
    local parterId = math.floor(recvobj.frienduid or 0)
    local retobj = {c=math.floor(recvobj.c), code= PDEFINE.RET.SUCCESS, spcode = 0, frienduid = parterId}
    if not league_info.iscaptain then
        retobj.spcode = 1 --无权限
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    if parterId > 0 then
        pcall(cluster.call, "master", ".userCenter", "leagueAct", parterId, "leagueKick", UID)
    end
    setParter(0) --T掉队友
    
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--！ 队友离开了(call by parter agent)
function league.leaved(friendUid)
    setParter(0)
    setCaptain(true)
    local notify = {
        c = 184,
        code = 200,
        frienduid = friendUid,
        spcode= 0,
    }
    handle.sendToClient(cjson.encode(notify)) --通知自己
end

--! 我关掉页面走了(可能在匹配中)
function league.leavePage()
    setCaptain(false)
    if league_info.parterId > 0 then
        
        pcall(cluster.call, "master", ".userCenter", "leagueAct", league_info.parterId, "leagueLeave", UID)
        setParter(0)
        -- local notify = {
        --     c = 184,
        --     code = 200,
        --     frienduid = UID,
        --     spcode= 0,
        -- }
        -- pcall(cluster.call, "master", ".userCenter", "pushInfoByUid", league_info.parterId, cjson.encode(notify))
    end
end

--! 队友主动离开
function league.leave(msg)
    local recvobj   = cjson.decode(msg)
    local retobj = {c=math.floor(recvobj.c), code= PDEFINE.RET.SUCCESS, spcode = 0, frienduid = UID}

    setCaptain(false)
    if league_info.parterId > 0 then
        pcall(cluster.call, "master", ".userCenter", "leagueAct", league_info.parterId, "leagueLeave", UID)
        setParter(0)
    end

    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 用户进入匹配房
function league.enteronline(msg)
    pcall(cluster.call, "master", ".invitemgr", "enter", UID, PDEFINE.BAL_ROOM_TYPE.MATCH)
end

-- 进入排位赛后，恢复数据
function league.resume()
    setCaptain(false)
    setParter(0)
end

-- 查找用户达到指定等级的赛季数量
function league.findLeagueCnt(level)
    local sql = string.format("select count(*) as cnt from d_user_league where uid=%d and level>=%d", UID, level)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if rs and #rs > 0 then
        return rs[1]['cnt']
    end
    return 0
end

--! 联赛信息及是否已报名
function league.signupinfo(msg)
    local recvobj   = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local gameid = math.floor(recvobj.gameid or 0)
    local retobj = {c=math.floor(recvobj.c), code= PDEFINE.RET.SUCCESS, spcode = 0, gameid=gameid, signup = 0, seasonstop=0,isopen=0,timeslot={}}
    retobj.rewards = {} -- TODO:上个赛季是否有奖励

    local cacheKey = PDEFINE.LEAGUE.SIGN_UP_KEY.. uid
    local times = do_redis({"get", cacheKey}) --标记
    times = times and tonumber(times) or 0
    if math.floor(times) > 0 then
        retobj.signup = 1
    end

    local maxscore, level = player_tool.getPlayerLeagueInfo(uid, gameid)
    retobj.leagueexp = maxscore
    retobj.prize = PDEFINE.LEAGUE.PRIZE --报名费
    local now = os.time()
    local seasonInfo = getLeagueInfo()
    retobj.seasonstop = seasonInfo.stopTime-os.time()
    retobj.seasonstoptime = seasonInfo.stopTime or 0
    retobj.getrewards = 0 -- 0:无奖励  1:有奖励
    local sql = string.format("select count(*) as cnt from d_user_league where uid=%d and status=0 and gameid=%d and seasonid=%d", uid, gameid, seasonInfo.id-1)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if rs and #rs > 0 then
        retobj.getrewards = rs[1]['cnt'] > 0 and 1 or 0
    end

    local hour = os.date("%H", now)
    hour = tonumber(hour)
    retobj.timestop = 0
    local temp_date = os.date("*t", now)
    local todayBeginTime = os.time({year=temp_date.year, month=temp_date.month, day=temp_date.day, hour=0})

    for i=#PDEFINE.LEAGUE.HOUR, 1, -1 do
        LOG_DEBUG("PDEFINE.LEAGUE.HOUR[i].stop:", PDEFINE.LEAGUE.HOUR[i], ' stop:', PDEFINE.LEAGUE.HOUR[i].stop)
        if PDEFINE.LEAGUE.HOUR[i].stop > hour and PDEFINE.LEAGUE.HOUR[i].start <= hour then
            retobj.isopen = 1 --已开始
            retobj.timestop = (todayBeginTime+ PDEFINE.LEAGUE.HOUR[i].stop * 3600) - now
            retobj.timeslot = PDEFINE.LEAGUE.HOUR[i]
            break
        end
    end
    LOG_DEBUG("retobj.isopen:", retobj.isopen, ' retobj:', retobj)
    if retobj.isopen == 0 then --未开始,等待下一个时间段
        local addDay = false
        local maxHour = 0
        for i =1, #PDEFINE.LEAGUE.HOUR do
            if PDEFINE.LEAGUE.HOUR[i].stop >= maxHour then
                maxHour = PDEFINE.LEAGUE.HOUR[i].stop
            end
        end
        if maxHour <= hour then
            addDay = true
        end
        LOG_DEBUG("retobj.isopen:", retobj.isopen, ' addDay:', addDay)
        if addDay then --跨天
            LOG_DEBUG("retobj.isopen:", retobj.isopen, ' 跨天')
            retobj.timeslot = PDEFINE.LEAGUE.HOUR[1]
            retobj.timestop = (todayBeginTime + 86400 +  (PDEFINE.LEAGUE.HOUR[1].start) * 3600) - now
        else --不跨天，下一阶段
            LOG_DEBUG("retobj.isopen:", retobj.isopen, ' 不跨天，下一阶段')
            for i =1, #PDEFINE.LEAGUE.HOUR do
                if PDEFINE.LEAGUE.HOUR[i].start > hour then
                    retobj.timeslot = PDEFINE.LEAGUE.HOUR[i]
                    retobj.timestop = (todayBeginTime+ (PDEFINE.LEAGUE.HOUR[i].start) * 3600) - now
                    break
                end
            end
        end
    end
    retobj.cfg = {}
    local ok, leagueArr = pcall(cluster.call, "master", ".cfgleague", "getCfgList")
    if ok then
        retobj.cfg = leagueArr
    end 
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 排位赛报名
function league.signup(msg)
    local recvobj   = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local retobj = {c=math.floor(recvobj.c), code= PDEFINE.RET.SUCCESS, spcode = 0}
    local cacheKey = PDEFINE.LEAGUE.SIGN_UP_KEY.. uid
    local signed = do_redis({"get", cacheKey})
    signed = tonumber(signed or 0)
    if signed > 0 then
        retobj.spcode = PDEFINE.RET.ERROR.LEAGUE_USER_HAND_SIGNED
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    local prize = PDEFINE.LEAGUE.PRIZE --联赛报名费
    local playerInfo = handle.moduleCall("player","getPlayerInfo", uid)
    if playerInfo.diamond < prize then
        retobj.spcode = PDEFINE.RET.ERROR.LEAGUE_USER_DIAMOND
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    handle.addProp(PDEFINE.PROP_ID.DIAMOND, -prize, 'league')

    
    -- 报名后当天天有效
    local expire_time = date.GetTodayZeroTime(os.time()) + 24*60*60 - os.time()
    do_redis({"setex", cacheKey, 1, expire_time})


    playerInfo = handle.moduleCall("player","getPlayerInfo", uid)
    handle.notifyCoinChanged(playerInfo.coin, playerInfo.diamond, 0, -prize)

    -- 赛季以周为单位
    local seasonInfo = getLeagueInfo()
    local now = os.time()
    local hour = os.date("%H", now)
    hour = tonumber(hour)
    local starthour =0
    for i=#PDEFINE.LEAGUE.HOUR, 1, -1 do
        if tonumber(PDEFINE.LEAGUE.HOUR[i].stop) >= hour and tonumber(PDEFINE.LEAGUE.HOUR[i].start) < hour then
            starthour = i
            break
        end
    end
    retobj.isopen = starthour>0 and 1 or 0
    if starthour == 0 then
        for i =1, #PDEFINE.LEAGUE.HOUR do
            if PDEFINE.LEAGUE.HOUR[i].start >= hour then
                starthour = i
                break
            end
        end
    end

    local sql = string.format("insert into d_league_signup(uid, seasonid, starttime, starthour, create_time, diamond)  values (%d, %d, %d, %d, %d, %d)", playerInfo.uid, seasonInfo.id, seasonInfo.startTime, starthour, now, prize)
    skynet.call(".mysqlpool", "lua", "execute", sql)
    retobj.diamond = PDEFINE.LEAGUE.PRIZE

    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 该游戏历史段位排行榜
function league.gameRankHistory(msg)
    local recvobj   = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local gameid = math.floor(recvobj.gameid or 257)
    local retobj = {c=math.floor(recvobj.c), code= PDEFINE.RET.SUCCESS, spcode = 0,gameid=gameid}

    local sql = string.format( "select * from d_league_record where gameid=%d order by seasonid desc, rank", gameid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local datalist = {}
    if #rs > 0 then
        -- 按照赛季来分组
        local currSeason = nil
        local nowRanks = nil
        for _, row in pairs(rs) do
            if currSeason and currSeason.id ~= row.seasonid then
                table.insert(datalist, currSeason)
                currSeason = nil
            end
            if not currSeason then
                currSeason = {
                    id = row.seasonid,
                    start = row.seasonstart,
                    stop = row.seasonstop,
                    gameid = row.gameid,
                    users = {}
                }
                nowRanks = {}  -- 存放当前等级
            end
            if not table.contain(nowRanks, row.rank) then
                local userInfo = player_tool.getPlayerInfo(row.uid)
                if not userInfo then
                    LOG_ERROR("排行榜中找不到该用户:", row.uid)
                else
                    local user = {
                        playername = userInfo.playername,
                        usericon = userInfo.usericon,
                        avatarframe = userInfo.avatarframe,
                        svip = userInfo.svip,
                        rank = row.rank,
                        uid = row.uid,
                        leaguelevel = row.leaguelevel,
                    }
                    table.insert(currSeason.users, user)
                    table.insert(nowRanks, row.rank)
                end
            end     
        end
        if currSeason then
            table.insert(datalist, currSeason)
            currSeason = nil
        end
    end
    retobj.datalist = datalist
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 领取奖励
function league.getPrevSeasonReward(msg)
    local recvobj   = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local gameid = math.floor(recvobj.gameid or 257)
    local retobj = {c=math.floor(recvobj.c), code= PDEFINE.RET.SUCCESS, spcode = 0, gameid=gameid}
    local seasonInfo = getLeagueInfo()
    retobj.rewards = {}
    local sql = string.format("select * from d_league_record where uid=%d and status=0 and gameid=%d and seasonid=%d", uid, gameid, seasonInfo.id-1)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if rs and #rs > 0 then
        retobj.rewards = cjson.decode(rs[1]['rewards'])
        for _, reward in ipairs(retobj.rewards) do
            handle.moduleCall("upgrade","sendSkins", reward.img, reward.days*24*60*60)
        end
        -- 更新状态
        local updateSql = string.format("update d_league_record set status=1 where uid=%d and gameid=%d and seasonid=%d", uid, gameid, seasonInfo.id-1)
        LOG_DEBUG("getPrevSeasonReward:", updateSql)
        skynet.call(".mysqlpool", "lua", "execute", updateSql)
    else
        -- 防止重复领取
        retobj.spcode = PDEFINE.RET.ERROR.ALREADY_AWARD
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    -- 领取段位奖励
    local addCoin, addDiamond = 0, 0
    local levelSql = string.format("select level from d_user_league where uid=%d and status=0 and gameid=%d and seasonid=%d", uid, gameid, seasonInfo.id-1)
    local levelRs = skynet.call(".mysqlpool", "lua", "execute", levelSql)
    if levelRs and #levelRs > 0 then
        retobj.level = levelRs[1]['level']
        local rewards = PDEFINE.LEAGUE.RANK_REWARD[levelRs[1]['level']]
        for _, reward in ipairs(rewards) do
            table.insert(retobj.rewards, reward)
            if reward.type == PDEFINE.PROP_ID.SKIN_FRAME then
                handle.moduleCall("upgrade","sendSkins", reward.img, reward.days*24*60*60)
            else
                handle.addProp(reward.type, reward.count, 'league')
            end
            if reward.type == PDEFINE.PROP_ID.COIN then
                addCoin = addCoin + reward.count
            elseif reward.type == PDEFINE.PROP_ID.DIAMOND then
                addDiamond = addDiamond + reward.count
            end
        end
        --同步钻石
        if addCoin > 0 or addDiamond > 0 then
            local playerInfo = handle.moduleCall("player","getPlayerInfo", uid)
            handle.notifyCoinChanged(playerInfo.coin, playerInfo.diamond, addCoin, addDiamond)
        end
        -- 更新状态
        local updateSql = string.format("update d_user_league set status=1 where uid=%d and gameid=%d and seasonid=%d", uid, gameid, seasonInfo.id-1)
        LOG_DEBUG("getPrevSeasonReward:", updateSql)
        skynet.call(".mysqlpool", "lua", "execute", updateSql)
        handle.moduleCall("player","syncLobbyInfo", UID)
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

return league