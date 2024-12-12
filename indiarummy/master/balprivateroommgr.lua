-- 私人房，数据存在内存中
-- 如果服务器重启，需要调用解散命令，将全部房间强行解散

local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local queue     = require "skynet.queue"
local player_tool = require "base.player_tool"
local club_db = require "base.club_db"
local cjson = require "cjson"
local s_special_quest = require "conf.s_special_quest"
local cs = queue()
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local GAME_ID = 256

local ROOM_COST = 400  -- 一个房间消耗400枚金币
local VIP_LIST

--接口
local CMD = {}

local desk_list = {} -- 所有桌子列表, 二维数组 [gameid][deskid] = desk
local view_in_game = {}  -- 正在观战的用户
local uid_desk = {} -- 记录自己所有的桌子列表

local function getAgent(uid)
    return skynet.call(".userCenter", "lua", "getAgent", uid)
end

local function leaveRoomListPage(uid, roomtype)
    skynet.send('.invitemgr', 'lua', 'leave', {uid}, roomtype)
end

-- 设置桌子缓存
local function setDeskCache(desk, deskid)
    local deskid = tonumber(deskid)
    local gameid = tonumber(desk.gameid)
    if nil == desk_list[gameid] then
        desk_list[gameid] = {}
    end
    if nil == desk_list[gameid][deskid] then
        desk_list[gameid][deskid] = desk
    end
    if not uid_desk[desk.owner] then
        uid_desk[desk.owner] = {}
    end
    desk.create_time = os.time()
    uid_desk[desk.owner][deskid] = desk
end

-- 获取桌子缓存
local function getDeskCache(deskid, gameid)
    local gameid = tonumber(gameid)
    local deskid = tonumber(deskid)
    if nil == desk_list[gameid] then
        return
    end
    return desk_list[gameid][deskid]
end

-- 通过deskid来找到桌子缓存
local function getDeskCacheByDeskid(deskid)
    local deskid = tonumber(deskid)
    for gameid, desks in pairs(desk_list) do
        for _deskid, desk in pairs(desks) do
            if _deskid == deskid then
                return desk
            end
        end
    end
    return nil
end

-- 获取房主桌子列表
local function getOwnerDeskList(uid)
    if not uid_desk[uid] then
        return {}
    end
    local desks = {}
    for _, desk in pairs(uid_desk[uid]) do
        table.insert(desks, desk)
    end
    return desks
end

-- 获取房主桌子数量
local function getOwnerDeskCnt(uid)
    if not uid_desk[uid] then
        return 0
    end
    local cnt = 0
    for _, desk in pairs(uid_desk[uid]) do
        cnt = cnt + 1
    end
    return cnt
end

-- 根据房主信息获取桌子信息
local function getDeskByOnwer(uid, deskid)
    local deskid = tonumber(deskid)
    if not uid_desk[uid] then
        return nil
    end
    for _, desk in pairs(uid_desk[uid]) do
        if desk.deskid == deskid then
            return desk
        end
    end
    return nil
end

-- 清理桌子缓存
local function clearDeskCache(deskid, gameid)
    local gameid = tonumber(gameid)
    local deskid = tonumber(deskid)
    if nil == desk_list[gameid] then
        return
    end
    local desk = desk_list[gameid][deskid]
    desk_list[gameid][deskid] = nil
    if not desk or not uid_desk[desk.owner] then
        return
    end
    uid_desk[desk.owner][deskid] = nil
end

-- 获取vip配置信息
local function getVipCfg()
    if not VIP_LIST then
        VIP_LIST = skynet.call(".configmgr", "lua", "getVipUpCfg")
    end
    return VIP_LIST
end

--获取收益比例
local function getSalonRate(totalbet)
    totalbet = totalbet or 0
    local rate = 0.1
    local cfg = skynet.call(".configmgr", "lua", "get", "salonrate")
    if cfg then
        local salonrates = cjson.decode(cfg.v)
        if salonrates and type(salonrates)=="table" then
            for _, item in ipairs(salonrates) do
                if totalbet>=tonumber(item.min) and (tonumber(item.max)<0 or totalbet<tonumber(item.max)) then
                    rate = item.rate
                    break
                end
            end
        end
    end
    return rate
end

-- 玩家进入观战
function CMD.enterView(deskid, uids, gameid)
    for _, uid in ipairs(uids) do
        view_in_game[tonumber(uid)] = {deskid=tonumber(deskid), gameid=tonumber(gameid)}
    end
end

-- 玩家退出观战
function CMD.exitView(deskid, uids, gameid, isSeat)
    local desk = getDeskCache(tonumber(deskid), tonumber(gameid))
    for _, uid in ipairs(uids) do
        view_in_game[tonumber(uid)] = nil
        if desk and not isSeat then
            for idx, user in ipairs(desk.users) do
                if user.uid == uid then
                    table.remove(desk.users, idx)
                    break
                end
            end
        end
    end
    return PDEFINE.RET.SUCCESS
end

-- 获取当前玩家观战房间
function CMD.getViewRoom(uid)
    return view_in_game[tonumber(uid)]
end

-- 加入桌子
local function joinDesk(desk, uid, gameid)
    local agent = getAgent(uid)
    local params = {}
    params.gameid = gameid or GAME_ID
    params.deskid = desk.deskid
    params.uid = uid
    params.c = 43
    LOG_DEBUG("joinDesk: msg:", params)
    local retok,retcode,retobj,deskAddr = pcall(cluster.call, desk.server, ".dsmgr", "joinDeskInfo", agent, params, "127.0.0.1", params.gameid)
    LOG_DEBUG("joinDesk return retcode:".. retcode .. "retobj:", retobj, ' deskAddr:', deskAddr)
    if not retok or retcode ~= PDEFINE.RET.SUCCESS then
        LOG_WARNING("加入房间失败", retok, retcode)
        return retok,retcode,retobj,deskAddr
    end
    -- 加入桌子
    skynet.call(".agentdesk","lua","joinDesk", deskAddr, uid)
    -- desk.curseat = desk.curseat + 1 -- 人数加1

    local users = {}
    for _, muser in pairs(retobj.deskinfo.users) do
        table.insert(users, {
            ['uid'] = muser.uid,
            ['playername'] = muser.playername,
            ['usericon'] = muser.usericon,
            ['seatid'] = muser.seatid,
            ['avatarframe'] = muser.avatarframe, 
            ['auto'] = muser.auto or 0, --是否自动托管
        })
    end
    desk.curseat = #retobj.deskinfo.users
    desk.users = users
    if agent then
        pcall(cluster.send, agent.server, agent.address, "setClusterDesk", deskAddr) -- 设置玩家桌子
    end
    setDeskCache(desk, desk.deskid)
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
        LOG_WARNING("创建房间失败", retok, retcode)
        return retok, retcode
    end
    -- 不需要加入房间
    -- skynet.call(".agentdesk","lua","joinDesk", deskAddr, uid)

    local playerInfo = skynet.call(".userCenter", "lua", "getPlayerInfo", uid)

    local desk = {
        server = deskAddr.server,
        address = deskAddr.address,
        gameid = deskAddr.gameid,
        deskid = deskAddr.desk_id,
        desk_uuid = deskAddr.desk_uuid,
        create_time = os.time(),
        curseat = 1,
        owner = uid,
        owner_info = {uid=uid, playername=playerInfo.playername},
        cur_round = 0,  -- 当前是第几轮，一大局算一轮, 未开始算0轮
        is_playing = 0,  -- 当前是否是游戏状态, 代表是否可以加入
        is_no_pay = 0,  -- 是否已经付款，防止漏扣然后返金币的情况
        seat = retobj.deskinfo.seat,
        maxSeat = params.conf.maxSeat,
        users = retobj.deskinfo.users,
        turntime = params.conf.turntime,
        round = params.conf.round,
        maxScore = params.conf.maxScore,
        pwd = params.conf.pwd,
        entry = params.conf.entry,
    }

    local deskid = deskAddr.desk_id
    deskid = tonumber(deskid)
    setDeskCache(desk, deskid)

    -- 不需要加入房间
    -- pcall(cluster.call, agent.server, agent.address, "setClusterDesk", deskAddr)

    -- 自动发送邀请消息
    -- if params and params.conf.invite == 1 and agent then
    --     local content = string.format("%d;%d;%d", desk.gameid, desk.deskid, desk.entry)
    --     pcall(cluster.send, agent.server, agent.address, "sendInviteMsg", content, PDEFINE.CHAT.MsgType.PrivateRoom)
    -- end
    return true, desk, retobj
end

-- 游戏内同步桌子状态过来
function CMD.syncUserState2DeskCache(gameid, deskid, uid, autoState)
    deskid = tonumber(deskid)
    local desk = getDeskCache(deskid, tonumber(gameid))
    if desk then
        for _, muser in pairs(desk.users) do
            if muser.uid == uid then
                muser.auto = autoState or 0
                break
            end
        end
        setDeskCache(desk, deskid)
    end
    return PDEFINE.RET.SUCCESS
end

--! 获取vip房间信息
function CMD.getDeskInfoFromCache(deskid, gameid)
    return getDeskCache(deskid, gameid)
end

-- 创建房间
function CMD.createRoom(rcvobj)
    local uid = tonumber(rcvobj.uid)
    local entry = tonumber(rcvobj.entry or 0) -- 最小携带
    local gameid = tonumber(rcvobj.gameid)
    local maxScore = rcvobj.maxScore and tonumber(rcvobj.maxScore) or nil  -- 选择最大分数
    local minScore = rcvobj.minScore and tonumber(rcvobj.minScore) or nil  -- 用于部分游戏godown最低分数
    local autoStart = rcvobj.autoStart and tonumber(rcvobj.autoStart) or 0 -- 是否自动开始, 自动开始会自动添加机器人
    local spcial = rcvobj.spcial and tonumber(rcvobj.spcial) or 0  -- 是否是特殊房间
    local maxSeat  = tonumber(rcvobj.maxSeat)
    local pwd -- 密码
    if rcvobj.pwd and rcvobj.pwd ~= "" then
        pwd  = rcvobj.pwd
    end
    local resp = {c=rcvobj.c, code=PDEFINE.RET.SUCCESS, spcode=0}
    local sessList = skynet.call(".sessmgr", "lua", "getSessByGameId", gameid)
    local sessInfo
    for _, info in ipairs(sessList) do
        if not sessInfo then
            sessInfo = info
        end
        if info.basecoin == entry then
            sessInfo = info
        end
    end
    if not sessInfo then
        resp.spcode = PDEFINE.RET.ERROR.CAN_NOT_FOUND_SESS
        return resp
    end
    local playerInfo = skynet.call(".userCenter", "lua", "getPlayerInfo", uid)
    local svip = playerInfo.svip or 0

    -- 根据vip等级判断是否可以继续创建房间
    local vipCfg = getVipCfg()
    local maxCnt = vipCfg[svip].salonrooms
    local now = os.time()
    playerInfo.salontesttime = tonumber(playerInfo.salontesttime or 0)
    if maxCnt < 3 and playerInfo.salontesttime>now then
        maxCnt = 3 --试用道具，加2个房间限制
    end
    local currCnt = getOwnerDeskCnt(uid)
    if currCnt >= maxCnt then
        resp.spcode = PDEFINE.RET.ERROR.ROOM_CNT_NO_ENOUGH
        return resp
    end

    local params = {}
    -- 这里会取一个默认配置
    params.conf = PDEFINE_GAME.DEFAULT_CONF[gameid]
    if maxScore then
        params.conf.maxScore = maxScore  -- 用传的参数覆盖
    end
    if minScore then
        params.conf.minScore = minScore
    end
    params.gameid = gameid
    params.conf.maxSeat = maxSeat
    params.conf.roomtype = PDEFINE.BAL_ROOM_TYPE.PRIVATE
    params.conf.entry = sessInfo.basecoin
    params.conf.pwd = pwd
    params.conf.autoStart = autoStart
    params.conf.spcial = spcial
    params.conf.mincoin = sessInfo.mincoin
    params.conf.maxcoin = sessInfo.maxcoin
    params.conf.param1 = sessInfo.param1
    params.conf.param2 = sessInfo.param2
    local ok, desk, retobj = createDesk(uid, params)
    LOG_DEBUG("createPrivateRoom ok:", ok, ' desk:', desk, ' retobj:', retobj)
    if not ok or type(desk)=="number" or desk ==nil then
        LOG_DEBUG("createPrivateRoom createDesk failed uid:", uid, ' retobj:', desk)
        resp.spcode = desk
        return resp
    end

    resp.deskinfo = {
        deskid = desk.deskid,
        conf = params.conf,
        users = desk.users,
        gameid = gameid,
        owner_info = desk.owner_info,
    }

    local agent = getAgent(uid)
    if agent then
        local msg = {uid=uid, roomcnt= getOwnerDeskCnt(uid)}
        LOG_DEBUG("syncUserInfo211:", msg)
        local ok = pcall(cluster.send, agent.server, agent.address, "syncUserInfo", msg)
        LOG_DEBUG("syncUserInfo211 result:", ok)
        -- 创建房间，完成任务
        pcall(cluster.send, agent.server, agent.address, "updateSpecialQuest", uid, s_special_quest.type.CreateSalon, 1)
    end
       
    return resp, retobj
end

-- 使用房间号查询游戏id
function CMD.queryGameByRoomid(rcvobj)
    local uid = tonumber(rcvobj.uid)
    local deskid = tonumber(rcvobj.deskid or 0)
    local resp = {c=rcvobj.c, code=PDEFINE.RET.SUCCESS,spcode=0, uid=uid, deskid=deskid, gameid=0}
    local deskInfo = getDeskCacheByDeskid(deskid)
    if not deskInfo then
        resp.spcode = PDEFINE.RET.ERROR.DESKID_NOT_FOUND
        return resp
    end

    resp.gameid = deskInfo.gameid
    return resp
end

-- 使用房间号加入房间
function CMD.joinRoom(rcvobj)
    local uid = tonumber(rcvobj.uid)
    local pwd -- 密码
    if rcvobj.pwd and rcvobj.pwd ~= "" then
        pwd  = rcvobj.pwd
    end
    local deskid = tonumber(rcvobj.deskid or 0)
    local resp = {c=rcvobj.c, code=PDEFINE.RET.SUCCESS,spcode=0, uid=uid, pwd=pwd, deskid=deskid, gameid=rcvobj.gameid}

    local playerInfo = skynet.call(".userCenter", "lua", "getPlayerInfo", uid)
    local row = skynet.call(".configmgr", "lua", "get", "popbindphone")
    local ispopbindphone = tonumber(row.v or 0)
    if (nil==playerInfo.isbindphone or playerInfo.isbindphone == 0) and ispopbindphone == 1 then
        resp.code   = PDEFINE.RET.ERROR.GAME_NOT_BIND_PHONE
        resp.spcode = PDEFINE.RET.ERROR.GAME_NOT_BIND_PHONE
        return resp
    end

    -- 如果已经在观战中，则会退出当前观战房间
    local viewDesk = CMD.getViewRoom(uid)
    if viewDesk and viewDesk.deskid ~= deskid then
        local desk = getDeskCache(viewDesk.deskid, viewDesk.gameid)
        if desk then
            pcall(cluster.call, desk.server, ".dsmgr", "removeViewer", viewDesk.deskid, uid)
        end
    end

    local deskInfo
    -- 如果已经在游戏中，则不能加入其它好友房间
    local nowdesk = skynet.call(".mgrdesk", "lua", "getPlayerDesk", uid, PDEFINE.BAL_ROOM_TYPE.PRIVATE)
    if nowdesk then
        -- 强行拉回原有房间
        deskInfo = getDeskCache(nowdesk.deskid, tonumber(nowdesk.gameid))
    end
    -- 如果已经在匹配游戏中，则告诉现有游戏，玩家已退出
    skynet.send(".mgrdesk", "lua", "setPlayerExit", uid, deskid)
    -- 这里规避下，如果显示在房间，但是找不到房间，也让重新加入其他房间
    if not deskInfo then
        if not rcvobj.gameid then
            deskInfo = getDeskCacheByDeskid(deskid)
        else
            deskInfo = getDeskCache(deskid, tonumber(rcvobj.gameid))
        end
        if not deskInfo then
            resp.spcode = PDEFINE.RET.ERROR.DESKID_NOT_FOUND
            return resp
        end
        -- 判断密码是否正确
        if deskInfo.pwd and deskInfo.pwd ~= pwd and deskInfo.owner ~= uid then
            resp.spcode = PDEFINE_ERRCODE.ERROR.PASSWORD_ERROR
            return resp
        end
    end
    resp.gameid = deskInfo.gameid

    local ok, retcode, retobj, deskAddr = joinDesk(deskInfo, uid, deskInfo.gameid)

    -- 房间已满
    if retcode == PDEFINE.RET.ERROR.SEATID_EXIST then
        resp.spcode = PDEFINE_ERRCODE.ERROR.DESK_NO_SEAT
        return resp
    elseif retcode ~= PDEFINE.RET.SUCCESS then
        resp.spcode = retcode
        return resp
    end

    return resp, retobj, deskAddr
end

-- 结束一轮，顺便给房主分钱
---@param deskid integer 房间号
---@param owner integer 房间所有者
---@param coin number 房间结算金币数
---@param bet number 房间号下注数量
---@param totalbet number 房间号累计下注数量
function CMD.gameOver(deskid, owner, coin, bet, totalbet)
    local desk = getDeskByOnwer(owner, deskid)
    if not desk then
        LOG_ERROR("calc private income error, can not found desk: ", deskid)
        return nil
    end

    local playerInfo = skynet.call(".userCenter", "lua", "getPlayerInfo", owner)
    local now = os.time()
    local svip = playerInfo.svip or 0
    if playerInfo and ((playerInfo.salonskin and playerInfo.salonskin ~= "") or (playerInfo.salontesttime and playerInfo.salontesttime>now))then
        local salonrate = getSalonRate(totalbet)
        local addCoin = math.round_coin(coin * salonrate)
        -- 记录抽水情况
        local redisKey = PDEFINE.REDISKEY.OTHER.private_room_reward..owner
        local rewardInfo = do_redis({"hgetall", redisKey})
        if not rewardInfo or table.empty(rewardInfo) then
            rewardInfo = {coin=0, round=0, exp=0}
        else
            rewardInfo = make_pairs_table_int(rewardInfo)
        end
        rewardInfo.coin = rewardInfo.coin + addCoin
        rewardInfo.round = rewardInfo.round + 1
        local addExp = 50
        -- skynet.call(".userCenter", "lua", "updateUserExp", owner, addExp)
        -- 每局增加50的经验值
        if not rewardInfo.exp then
            rewardInfo.exp = addExp
        else
            rewardInfo.exp = rewardInfo.exp + addExp
        end
        do_redis({"hmset", redisKey, rewardInfo})
        -- 插入数据表存储起来
        local insertSql = string.format(
            [[
                insert into d_private_room_income
                (
                    owner, deskid, gameid, bet, total, income, exp, create_time
                ) values(
                    %d, %d, %d, %0.2f, %0.2f, %0.2f, %d, %d
                )
            ]], owner, deskid, desk.gameid, bet, coin, addCoin, addExp, os.time()
        )
        skynet.call(".mysqlpool", "lua", "execute", insertSql)
        LOG_DEBUG("salon benifit", owner, deskid, desk.gameid, bet, coin, addCoin, totalbet)
    end


    local agent = getAgent(owner) --同步房主现在开的房间数
    if agent then
        local msg = {uid=owner, roomcnt= getOwnerDeskCnt(owner)}
        pcall(cluster.send, agent.server, agent.address, "syncUserInfo", msg)
        -- 房间完成一局，完成任务
        -- pcall(cluster.send, agent.server, agent.address, "updateSpecialQuest", owner, s_special_quest.type.PlaySalon, 1)
    end
end

-- 解散后, 从列表中删除
function CMD.removeRoom(deskid, gameid)
    deskid = tonumber(deskid)
    local desk = getDeskCache(deskid, gameid)
    if not desk then
        LOG_DEBUG("removeRoom no desk", deskid, gameid, desk_list)
        return
    end
    -- 如果房间还未开始，需要返回房主金币
    -- 防止多次调用
    clearDeskCache(deskid, gameid)
    LOG_DEBUG("removeRoom success", deskid, gameid)
    local agent = getAgent(desk.owner)
    if agent then
        local msg = {uid=desk.owner, roomcnt= getOwnerDeskCnt(desk.owner)}
        LOG_DEBUG("removeRoom syncUserInfo211:", msg)
        local ok = pcall(cluster.send, agent.server, agent.address, "syncUserInfo", msg, true)
        LOG_DEBUG("removeRoom syncUserInfo211 result:", ok)
    end
end

-- 邀请好友
function CMD.inviteFriend(rcvobj)
    local uid = tonumber(rcvobj.uid)
    local frienduid = tonumber(rcvobj.frienduid)
    local deskid = tonumber(rcvobj.deskid)
    local gameid = tonumber(rcvobj.gameid)
    local friendAgent = getAgent(frienduid)

    local cacheKey = string.format("invite_%d_%d", uid,frienduid)
    local flag = do_redis({"get", cacheKey})
    flag = tonumber(flag or 0)
    if flag ~= 0 then
        return {c=rcvobj.c, spcode=PDEFINE.RET.ERROR.INVITE_FRIEND_HAD_SEND, code=PDEFINE.RET.SUCCESS, uid=uid, frienduid=frienduid}
    end
    do_redis({"setnx", cacheKey, 1, 10})

    local desk = getDeskCache(deskid, gameid)
    if not friendAgent then
        return {c=rcvobj.c, spcode=PDEFINE.RET.ERROR.FRIEND_OFFLINE, code=PDEFINE.RET.SUCCESS, uid=uid, frienduid=frienduid}
    end
    if desk then
        local playerInfo = skynet.call(".userCenter", "lua", "getPlayerInfo", uid)
        local ok, cluster_desk = pcall(cluster.call, friendAgent.server, friendAgent.address, "getClusterDesk")
        if ok and not table.empty(cluster_desk) then
            return {c=rcvobj.c, spcode=PDEFINE.RET.ERROR.FRIEND_IS_INGAME, code=PDEFINE.RET.SUCCESS, uid=uid, frienduid=frienduid}
        end
        local resp = {
            c = PDEFINE.NOTIFY.FRIEND_INVITE_GAME,
            code = PDEFINE.RET.SUCCESS,
            deskid = deskid,
            gameid = gameid,
            from = uid,
            playername  = playerInfo.playername,
            usericon = playerInfo.usericon,
            idx = os.time(),
        }
        pcall(cluster.call, friendAgent.server, friendAgent.address, "sendToClient", cjson.encode(resp))
        return {c=rcvobj.c, spcode=0, code=PDEFINE.RET.SUCCESS, uid=uid, frienduid=frienduid}
    else
        return {c=rcvobj.c, spcode=PDEFINE.RET.ERROR.NOT_FOUND_FRIEND, code=PDEFINE.RET.SUCCESS, uid=uid, frienduid=frienduid}
    end
end

-- 按条件过滤
local function filterDeskList(filterObj, gameid, uid, sorted)
    local roomList = {}
    for _gameid, games in pairs(desk_list) do
        if not gameid or gameid == _gameid then
            for deskid, row in pairs(games) do
                local item = {
                    deskid = deskid,
                    onwer_info = row.owner_info,
                    entry = row.entry,
                    -- score = row.conf.bet,
                    prize = row.prize,
                    turntime = row.turntime,
                    shuffle = row.shuffle,
                    voice = row.voice,
                    curseat = row.curseat,
                    users = row.users,
                    private = row.private,
                    timeout = 0,
                    seat = row.seat, --最大座位数
                    gameid = row.gameid, --游戏id
                    pwd = row.pwd, -- 密码
                    maxScore = row.maxScore,  -- 结算分数
                    maxSeat = row.maxSeat or row.seat, --最大座位号
                    create_time = row.create_time, --创建时间
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
                        if sorted == 3 then --自己开的房间和自己正在打的
                            local add7 = false
                            if uid then
                                if item.onwer_info.uid == uid then
                                    add7 = true
                                end
                                if not add7 then
                                    for _, muser in pairs(item.users) do
                                        if muser.uid == uid then
                                            add7 = true
                                            break
                                        end
                                    end
                                end
                            end
                            if add7 then
                                local onwer_info = item.onwer_info
                                local userInfo = player_tool.getSimplePlayerInfo(onwer_info.uid)
                                onwer_info.playername = userInfo.playername
                                onwer_info.usericon = userInfo.usericon
                                onwer_info.leagueexp = userInfo.leagueexp
                                onwer_info.svipexp = userInfo.svipexp
                                onwer_info.levelexp = userInfo.levelexp
                                onwer_info.level = userInfo.level
                                onwer_info.avatarframe = userInfo.avatarframe
                                table.insert(roomList, item)
                            end
                        elseif sorted == 2 then --TODO: 按时间优先
                            local onwer_info = item.onwer_info
                            local userInfo = player_tool.getSimplePlayerInfo(onwer_info.uid)
                            onwer_info.playername = userInfo.playername
                            onwer_info.usericon = userInfo.usericon
                            onwer_info.leagueexp = userInfo.leagueexp
                            onwer_info.svipexp = userInfo.svipexp
                            onwer_info.levelexp = userInfo.levelexp
                            onwer_info.level = userInfo.level
                            onwer_info.avatarframe = userInfo.avatarframe
                            table.insert(roomList, item)
                        else --自己开的房在前面
                            local onwer_info = item.onwer_info
                            local userInfo = player_tool.getSimplePlayerInfo(onwer_info.uid)
                            onwer_info.playername = userInfo.playername
                            onwer_info.usericon = userInfo.usericon
                            onwer_info.leagueexp = userInfo.leagueexp
                            onwer_info.svipexp = userInfo.svipexp
                            onwer_info.levelexp = userInfo.levelexp
                            onwer_info.level = userInfo.level
                            onwer_info.avatarframe = userInfo.avatarframe
                            if uid and item.onwer_info.uid == uid then
                                table.insert(roomList, 1, item)
                            else
                                table.insert(roomList, item)
                            end
                        end
                    end
                end
            end
        end
    end
    if sorted == 2 then --按创建时间排序
        table.sort(roomList, function (a, b)
            if a.create_time < b.create_time then
                return true
            end
            return false
        end)
    end
    return roomList
end

local function refreshRoomList(gameid)
    LOG_DEBUG("refreshRoomList start gameid:", gameid)
    if nil == gameid then
        gameid = PDEFINE.GAME_TYPE.HAND
    end
    local roomList = filterDeskList({}, gameid)
    local resp = {c= PDEFINE.NOTIFY.BALOOT_REFLASH_VIPROOM, code=PDEFINE.RET.SUCCESS, data = roomList, gameid=gameid}
    local ok, uids, userVIPGames = pcall(skynet.call, ".invitemgr", "lua", "getRoomListUIDAndGame", PDEFINE.BAL_ROOM_TYPE.PRIVATE)
    LOG_DEBUG("refreshRoomList ok:", ok, uids, userVIPGames)
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

--! 获取房间列表
function CMD.getRoomList(rcvobj)
    local uid = rcvobj.uid
    local state = tonumber(rcvobj.state or 0)
    local entry = tonumber(rcvobj.entry or 0)
    local turntime = tonumber(rcvobj.turntime or 0)
    local shuffle = tonumber(rcvobj.shuffle or 0)
    local voice = tonumber(rcvobj.voice or 0)
    local gameid = tonumber(rcvobj.gameid)
    local seat = tonumber(rcvobj.seat or 0)
    local sorted = tonumber(rcvobj.sort or 1) --1:自己优先 2:时间优先 3:自己开的房间和自己正在打的
    local iscache = rcvobj.cache --是否客户端缓存数据请求的
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

    local roomList = filterDeskList(filters, gameid, uid, sorted)

    -- skynet.send('.invitemgr', 'lua', 'enter', uid, PDEFINE.BAL_ROOM_TYPE.PRIVATE, gameid)
    local resp = {c=rcvobj.c, code=PDEFINE.RET.SUCCESS}
    resp.common = {}
    resp.super = {}
    resp.data = {}  -- 为了兼容
    local superMap = {}
    -- 从roomlist中分出普通房间和超级房(开发沙龙提成的)
    local noSuperUser = {} -- 未开通的人
    local selfrooms = {} --自己的，没开沙龙道具，可以不给
    local now = os.time()

    local opensalon = false
    local userInfo = skynet.call(".userCenter", "lua", "getPlayerInfo", uid)
    userInfo.salontesttime = tonumber(userInfo.salontesttime or 0)
    if ((userInfo.salonskin and userInfo.salonskin ~= "") or userInfo.salontesttime>now) then
        opensalon = true --自己开了沙龙房
    end

    for _, room in ipairs(roomList) do
        for _, user in pairs(room.users) do
            user.auto = 0 --全部关闭自动托管状态，不同步给客户端
        end
        local ouid = room.onwer_info.uid
        if not superMap[ouid] then
            if noSuperUser[ouid] then
                table.insert(resp.data, room)
            else
                local playerInfo = skynet.call(".userCenter", "lua", "getPlayerInfo", ouid)
                playerInfo.salontesttime = tonumber(playerInfo.salontesttime or 0)
                if playerInfo and ((playerInfo.salonskin and playerInfo.salonskin ~= "") or playerInfo.salontesttime>now) then
                    superMap[ouid] = {room}
                    if ouid == uid then
                        table.insert(selfrooms, room)
                    end
                else
                    noSuperUser[ouid] = 1
                    table.insert(resp.data, room)
                end
            end
        else
            if ouid == uid then
                table.insert(selfrooms, room)
            end
            table.insert(superMap[ouid], room)
        end
    end
    resp.selfrooms = selfrooms
    -- 插入resp.super中
    for _uid, rlist in pairs(superMap) do
        if opensalon then
            if _uid ~= uid then
                table.insert(resp.super, rlist)
            end
        else
            if _uid == uid then
                table.insert(resp.super, 1, rlist)
            else
                table.insert(resp.super, rlist)
            end
        end
    end

    -- 记录自己的抽水情况
    local redisKey = PDEFINE.REDISKEY.OTHER.private_room_reward..uid
    local rewardInfo = do_redis({"hgetall", redisKey})
    if not rewardInfo or table.empty(rewardInfo) then
        rewardInfo = {coin=0, round=0, exp=0}
    else
        rewardInfo = make_pairs_table_int(rewardInfo)
    end
    resp.income = {
        coin = rewardInfo.coin,
        round = rewardInfo.round,
        exp = rewardInfo.exp or 0
    }
    resp.shop = {}
    local agent = getAgent(uid)
    if agent then
        local ok, shopinfo = pcall(cluster.call, agent.server, agent.address,
                                "clusterModuleCall", "player", "getCatSkin",  uid, 10)
        if ok then
            resp.shop = shopinfo[1]
        end
    end

    return PDEFINE.RET.SUCCESS, resp
end

--! 退出房间列表(退出online/league/viproomlit页面)
function CMD.exitRoomList(rcvobj)
    local uid = rcvobj.uid
    local roomtype = tonumber(rcvobj.roomtype or 1)
    if roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
 
    end

    leaveRoomListPage(uid) --回大厅了
    return PDEFINE.RET.SUCCESS
end

-- 退出房间列表
function CMD.exitRoom(deskid, gameid, uid)
    local desk = getDeskCache(tonumber(deskid), tonumber(gameid))
    LOG_DEBUG("player exit private rooom deskid: ", deskid, "gameid: ", gameid, "uid: ", uid)
    if not desk then
        return
    end
    for idx, user in ipairs(desk.users) do
        if user.uid == uid then
            table.remove(desk.users, idx)
            break
        end
    end
    return PDEFINE.RET.SUCCESS
end

-- 观战玩家坐下
function CMD.viewerSeat(deskid, gameid, userInfo)
    local desk = getDeskCache(tonumber(deskid), tonumber(gameid))
    if not desk then
        return
    end
    for idx, user in ipairs(desk.users) do
        if user.uid == userInfo.uid then
            return
        end
    end
    table.insert(desk.users, {
        ['uid'] = userInfo.uid,
        ['playername'] = userInfo.playername,
        ['usericon'] = userInfo.usericon,
        ['seatid'] = userInfo.seatid,
    })
    return PDEFINE.RET.SUCCESS
end

-- 机器人加入
function CMD.aiSeat(deskid, gameid, userInfo)
    local desk = getDeskCache(tonumber(deskid), tonumber(gameid))
    if not desk then
        return
    end
    for idx, user in ipairs(desk.users) do
        if user.uid == userInfo.uid then
            return
        end
    end
    table.insert(desk.users, {
        ['uid'] = userInfo.uid,
        ['playername'] = userInfo.playername,
        ['usericon'] = userInfo.usericon,
        ['seatid'] = userInfo.seatid,
    })
    return PDEFINE.RET.SUCCESS
end

--! 房间列表中 直接点快速坐下
function CMD.seatRoom(rcvobj)
    local uid = tonumber(rcvobj.uid)
    local deskids = {}
    local gameid = rcvobj.gameid and tonumber(rcvobj.gameid) -- 如果没有gameid, 就找空座位的房间
    local resp = {c=rcvobj.c, code=PDEFINE.RET.SUCCESS, gameid=gameid, spcode = 0}
    local targetDeskId = nil
    -- 如果已经在游戏中，则不能加入其它好友房间
    local nowdesk = skynet.call(".mgrdesk", "lua", "getPlayerDesk", uid, PDEFINE.BAL_ROOM_TYPE.PRIVATE)
    if nowdesk then
        -- 直接拉到原有的房间
        gameid = nowdesk.gameid
        resp.gameid = nowdesk.gameid
        targetDeskId = nowdesk.deskid
    else
        if gameid then
            if nil ~= desk_list[gameid] then
                for deskid, row in pairs(desk_list[gameid]) do
                    if row.private ~=1 and #row.users < row.seat then
                        table.insert(deskids, deskid)
                    end
                end
            end
        else
            local playerInfo = skynet.call(".userCenter", "lua", "getPlayerInfo", uid)
            for _gameid, gameRooms in pairs(desk_list) do
                for deskid, row in pairs(gameRooms) do
                    if row.private ~=1 and #row.users < row.seat and row.entry <= playerInfo.coin then
                        table.insert(deskids, deskid)
                    end
                end
                if #deskids > 0 then
                    gameid = _gameid
                    break
                end
            end
        end

        if table.empty(deskids) then
            resp.spcode = PDEFINE.RET.ERROR.NO_AVAILABLE_ROOM
            return resp
        else
            targetDeskId = deskids[math.random(1, #deskids)]
        end
    end

    local joinParams = {
        uid = uid,
        deskid = targetDeskId,
        gameid = gameid,
    }
    local joinResp, retobj,deskAddr = CMD.joinRoom(joinParams)
    if joinResp.spcode ~= 0 then
        resp.spcode = joinResp.spcode
        if resp.spcode == PDEFINE.RET.ERROR.GAME_NOT_BIND_PHONE then
            resp.code = PDEFINE.RET.ERROR.GAME_NOT_BIND_PHONE
        end
        resp.deskid = targetDeskId
        return resp
    end
    return resp, retobj,deskAddr
end

--! 获取房主的开房数
function CMD.getOwnerDeskCnt(uid)
    return getOwnerDeskCnt(uid)
end

function CMD.getOwnerDeskGameIdList(uid)
    local deskList = getOwnerDeskList(uid)
    if #deskList == 0 then
        return {}
    end
    local gameIdList = {}
    for _, desk in pairs(deskList) do
        if gameIdList[desk.gameid] == nil then
            gameIdList[desk.gameid] = 0
        end
        gameIdList[desk.gameid] = gameIdList[desk.gameid] + 1
    end
    return gameIdList
end

-- 解散房间
function CMD.dismissRoom(deskid, gameid, uid)
    local desk = getDeskCache(deskid, gameid)
    if not desk then
        return PDEFINE.RET.ERROR.DESKID_NOT_FOUND
    end
    if desk.owner ~= uid then
        return PDEFINE.RET.ERROR.NOT_ROOM_OWNER
    end
    local ok, errCode = pcall(cluster.call, desk.server, ".dsmgr", "dismissRoom", deskid)
    if errCode then
        local agent = getAgent(uid)
        if agent then
            local msg = {uid=uid, roomcnt= getOwnerDeskCnt(uid)}
            pcall(cluster.send, agent.server, agent.address, "syncUserInfo", msg, true)
        end
        return errCode
    else
        return PDEFINE.RET.ERROR.CALL_FAIL
    end
end

-- 使用真实uid，创建一部分房间
-- 策略: 10分钟轮询一次，从列表中找出2个uid
-- 每个uid创建两个房间一个房间在打，一个房间闲置
-- 在打的房间，只要一轮就退出，下一轮循环的时候，创建一个新房间继续打
-- 闲置的房间随机加入1-2个机器人，有真人进入后再补齐机器人
-- 闲置的房间自动解散时间延长到20分钟

local function autoCreateRoom()
    local redisKey = PDEFINE.REDISKEY.OTHER.persistent_room_uids
    local uidStr = do_redis({"get", redisKey})
    local currUids = {}
    if uidStr then
        local uids = string.split_to_number(uidStr, ',')
        shuffle(uids)
        for _, uid in ipairs(uids) do
            -- 如果已经有创建房间了，则忽略
            if not uid_desk[uid] or table.empty(uid_desk[uid]) then
                table.insert(currUids, uid)
            end
            if #currUids > 2 then
                break
            end
        end
    end
    local vipCfg = PDEFINE_GAME.SESS.vip
    local allGames = PDEFINE_GAME.AUTO_PRIVATE_GAME
    -- 创建空房间
    for _, uid in ipairs(currUids) do
        local gameid = allGames[math.random(#allGames)]
        local resp, retobj = CMD.createRoom({
            c = 500,
            uid = uid,
            entry = vipCfg[gameid][math.random(4)].entry,
            gameid = gameid,
            autoStart = 1,
            spcial = 1,  -- 是否是特殊房间
        })
        LOG_DEBUG("autoCreateRoom:", resp)
        if resp and resp.deskinfo then
            -- 加入房间
            local resp = CMD.joinRoom({
                uid = uid,
                deskid = resp.deskinfo.deskid,
                gameid = gameid,
            })
            LOG_DEBUG("autoJoinRoom", resp)
        end
        -- 再额外创建2个空房间
        for i = 1, 2 do
            gameid = allGames[math.random(#allGames)]
            CMD.createRoom({
                c = 500,
                uid = uid,
                entry = vipCfg[gameid][math.random(4)].entry,
                gameid = gameid,
                autoStart = 1,
                spcial = 1,  -- 是否是特殊房间
            })
        end
    end
    skynet.timeout(10*60*100, function()
        autoCreateRoom()
    end)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = assert(CMD[cmd])
        skynet.retpack(f(...))
	end)
    -- skynet.timeout(180*100, function ()
    --     -- autoCreateRoom()
    -- end)
    skynet.register(".balprivateroommgr")
    collectgarbage("collect")
end)