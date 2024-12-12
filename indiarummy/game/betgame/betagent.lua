--[[
    百人游戏基类
]]

local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local BetUser = require "betgame.betuser"
local BetStgy = require "betgame.betstgy"
local ServerId = skynet.getenv("serverid") or 0

local TABLE_USER_COUNT = 6  --上桌的玩家数量

local MAX_USER = 400 --房间最大人数

--公用桌子状态，无特殊情况使用下面3个状态
local DESK_STATE = {
    FREE = 1,   --空闲阶段
    BETTING = 2,--押注阶段
    SETTLE = 3, --结算阶段
}

local ResultSize = 0 --游戏开奖记录条数

local isMaintaining = false --是否正在维护

-- 成功返回
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, retobj
end
-- 过滤数据
local function filterData(tbl)
    -- 去掉连接信息
    tbl.cluster_info = nil
    -- cjson不支持function
    for key, v in pairs(tbl) do
        if type(v) == 'function' then
            tbl[key] = nil
        end
    end
    -- 清除元表
    tbl = setmetatable(tbl, {})
    return tbl
end
--拷贝数据
local function copyData(tbl)
    local t = table.copy(tbl)
    return filterData(t)
end

---@class BetAgent
local BetAgent = class()


-- 创建新的游戏
function BetAgent:ctor(name, gameid, deskid)
    ---@type BetAgent

    self.name = name        -- 游戏名字
    self.gameid = gameid    -- 游戏gameid
    self.deskid = deskid    -- 桌子id
    self.seatids = {}
    for i=1,TABLE_USER_COUNT do
        table.insert(self.seatids, i)
    end
    self.lastRandomChatTime = 0
    --玩家列表
    ---@type BetUser[]
    self.users = {}    -- 玩家对象

    -- 游戏的桌子信息
    ---@class DeskInfo
    local deskInfo = {
        --桌子基本信息
        cid = nil,      -- 俱乐部id
        gameid = gameid,  -- 游戏gameid
        deskid = deskid,  -- 房间号
        uuid = nil,     -- 当前桌子uuid
        state = 0,      -- 桌子状态
        time = 0,       -- 状态剩余时间
        endtime = 0,    -- 状态结束时间
        ssid = nil,     -- 对应匹配的ssid
        conf = nil,
        curround = 0,   -- 当前第几轮
        seat = 100,     -- 默认人数
        curseat = 0,    -- 当前人数
        owner = nil,    -- 房主uid
        banker = nil,   -- 庄家
        chips = {},     -- 筹码列表
        --桌子游戏数据
        round = {},    -- 此轮桌子信息
        records = {},  -- 历史记录
        taxrate = 0,    --税率
        issue = nil,    --投注期号
        no = 0,         --序号
        ---@type BetUser[]
        users = {}      -- 桌上玩家列表。注：列表里的玩家不在这里面
    }
    self.deskInfo = deskInfo
    --策略对象
    ---@type BetStgy
    self.stgy = BetStgy.new()
end

function BetAgent:getDeskInfo()
    return self.deskInfo
end

---@return BetUser[]
function BetAgent:getUsers()
    return self.users
end

---生成投注期号
function BetAgent:newIssue()
    local shortname = PDEFINE.GAME_SHORT_NAME[self.deskInfo.gameid] or 'XX'
    local osdate = os.date("%y%m%d")
    self.deskInfo.no = self.deskInfo.no + 1
    local number = string.format("%04d", self.deskInfo.no%10000)
    self.deskInfo.issue = shortname..osdate..(self.deskInfo.deskid)..number
end

-- 桌子状态
function BetAgent:setState(state, time)
    self.deskInfo.state = state
    self.deskInfo.time = 0
    if time then
        self.deskInfo.time = time
        self.deskInfo.endtime = os.time() + time
    end
end
function BetAgent:getState()
    return self.deskInfo.state
end

-- 设置定时器(时间单位：秒)
function BetAgent:setTimer(sec, func, params)
    return skynet.timeout(math.floor(sec*100), function()
        if func then func(params) end
    end)
end

-- 机器人金币值
function BetAgent:initAiCoin()
    local minCoin = 200
    local maxCoin = 20000
    local rand = math.random()
    if rand < 0.4 then  --40%
        maxCoin = 200000
    elseif rand < 0.6 then  --20%
        minCoin = 1000
        maxCoin = 500000
    elseif rand < 0.64 then --4%
        minCoin = 10000
        maxCoin = 1000000
    elseif rand < 0.65 then --1%
        minCoin = 20000
        maxCoin = 2000000
    end
    return math.random(minCoin*100,maxCoin*100)/100
end

-- 回收机器人
function BetAgent:RecycleAi(user)
    if not user.cluster_info then
        pcall(cluster.send, "ai", ".aiuser", "recycleAi",user.uid, user.score, os.time()+10, self.deskid)
    end
end

-- 获取房间投放人数，根据时间段不同补充机器人数量
function BetAgent:getSuitableAiNum()
    local ts = os.date("*t", os.time())
    local num = math.random(20, 30)
    if (ts.hour >= 9 and ts.hour < 12)  or (ts.hour >= 14 and ts.hour < 18) then
        num = math.random(25, 40)
    elseif ts.hour >= 19 and ts.hour <= 23 then
        num = math.random(35, 50)
    end
    if #self.users > 200 then
        num = math.floor(num*0.8)
    elseif #self.users > 100 then
        num = math.floor(num*0.9)
    end
    return num
end

-- 加入机器人
function BetAgent:aiJoin(aiUser)
    local deskInfo = self.deskInfo
    if nil ~= aiUser then
        local seatid = 0
        local user = BetUser.new(aiUser, deskInfo)
        user:init(seatid, self)
        user.coin = self:initAiCoin()
        if self.gamelogic.initUser then
            self.gamelogic.initUser(user)
        end
        
        self:insertUser(user, true)

        if user.seatid > 0 then
            local retobj  = {}
            retobj.c      = PDEFINE.NOTIFY.PLAYER_ENTER_ROOM --有用户加入了
            retobj.code   = PDEFINE.RET.SUCCESS
            retobj.user   = copyData(user)
            retobj.user.round = nil
            self:broadcast(cjson.encode(retobj), user.uid)
        end

        -- TODO: chat
        --pcall(cluster.send, "node", ".chat", "changeDeskInfoUsers", self.deskid, self.gameid, self.users, self.cid)
        return PDEFINE.RET.SUCCESS, 1
    end

    local maxNum = self:getSuitableAiNum()
    local curNum  = 0
    for _, user in ipairs(self.users) do
        if not user.cluster_info then
            curNum = curNum + 1
        end
    end

    local realAddNum = 0
    local toAddNum = maxNum - curNum
    toAddNum = math.min(toAddNum, 8) --一次最多添加8个
    if toAddNum > 0 then
        local ok, aiUserList = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", toAddNum, true)
        if ok and not table.empty(aiUserList) then
            for _, ai in pairs(aiUserList) do
                -- 防止加入重复的机器人
                local exist_user = self:findUserByUid(ai.uid)
                if not exist_user then
                    local seatid = 0
                    local user = BetUser.new(ai, deskInfo)
                    user:init(seatid, deskInfo)
                    user.coin = self:initAiCoin()
                    if self.gamelogic.initUser then
                        self.gamelogic.initUser(user)
                    end
                    self:insertUser(user, false)
                    if user.seatid > 0 then
                        local retobj  = {}
                        retobj.c      = PDEFINE.NOTIFY.PLAYER_ENTER_ROOM --有用户加入了
                        retobj.code   = PDEFINE.RET.SUCCESS
                        retobj.user   = copyData(user)
                        retobj.user.round = nil
                        skynet.timeout(math.random(20,200), function()
                            self:broadcast(cjson.encode(retobj), ai.uid)
                        end)
                    end
                    realAddNum = realAddNum + 1
                else
                    self:RecycleAi(ai)
                end
            end
            self:syncPlayerCount()
        end
    end
    -- 如果还没有满员，则继续添加机器人
    if curNum + realAddNum < maxNum then
        skynet.timeout(100, function ()
            self:aiJoin()
        end)
    end
    -- TODO: chat
    --pcall(cluster.send, "node", ".chat", "changeDeskInfoUsers", self.deskid, self.gameid, self.users, self.cid)
    return PDEFINE.RET.SUCCESS, num
end

function BetAgent:userDelayAutoBet(gamelogic, config, bettime, user)
    local betCount = 1
    if user.seatid > 0 then
        betCount = math.random(2, 5)
    end
    for i = 1, betCount do
        local delayTime = 100
        local rand = math.random()
        if rand < 0.6 then  --60%的玩家在前半时期下完
            delayTime = math.random(50, math.floor(bettime/2))
        elseif rand < 0.85 then
            delayTime = math.random(math.floor(bettime/3), math.floor(bettime*2/3))
        else
            delayTime = math.random(math.floor(bettime/2), bettime-300)
        end
        skynet.timeout(delayTime, function()
            if gamelogic.autoBet then
                gamelogic.autoBet(user)
            else
                user:autoBet(gamelogic, config)
            end
        end)
    end
end

--机器人押注
--config.Chips 筹码配置
--config.Places 区域配置
--config.Multiples 倍数配置
function BetAgent:satrtAiBet(gamelogic, config, bettime)
    bettime = bettime * 100 --时间单位转为10ms
    local DeskBetRate = 0.9 --桌上玩家押注概率
    local AroundBetRate = 0.7 --围观玩家押注概率
    local betUserCnt = 0    --下注玩家数量
    for _, user in ipairs(self.users) do
        if not user.cluster_info then
            local bet = false
            local rate = math.random()
            if user.seatid > 0 then
                bet = rate < DeskBetRate
            else
                bet = rate < AroundBetRate
            end
            if bet then
                self:userDelayAutoBet(gamelogic, config, bettime, user)
                betUserCnt = betUserCnt + 1
                if betUserCnt > 100 then
                    break
                end
            end
        end
    end
end

--同步人数
function BetAgent:syncPlayerCount()
    local notify = {
        code = PDEFINE.RET.SUCCESS,
        c = PDEFINE.NOTIFY.BET_PLAYER_COUNT,
        count = #self.users,
    }
    self:broadcast(cjson.encode(notify))
end


-- 玩家加入
function BetAgent:insertUser(user, broadcast)
    local deskInfo = self.deskInfo
    deskInfo.curseat = deskInfo.curseat + 1
    table.insert(self.users, user)
    if #(self.deskInfo.users) < TABLE_USER_COUNT then
        local seatid = #(self.deskInfo.users) + 1
        user.seatid = seatid
        table.insert(self.deskInfo.users, user) --玩家上桌
    end
    pcall(cluster.send, "master", ".strategymgr", "updateDeskPlayerNum", self.deskid, #self.users)
    if broadcast then
        self:syncPlayerCount()
    end
end

-- 创建桌子成功，写入数据到数据库
function BetAgent:writeDB()
    local deskInfo = self.deskInfo
    local sql = string.format("insert into d_desk_game(deskid,gameid,uuid,owner,roomtype,bet,prize,conf,create_time) values(%d,%d,'%s',%d,%d,%d,%d,'%s',%d)", 
                                self.deskid, self.gameid, deskInfo.uuid, deskInfo.owner, PDEFINE.BAL_ROOM_TYPE.MATCH,  0, 0, "{}", os.time())
    skynet.send(".mysqlpool", "lua", "execute", sql)
end

function BetAgent:recordDB(settle, force)
    local deskInfo = self.deskInfo
    local issue = deskInfo.issue or ''
    local now = os.time()
    local settle_json = cjson.encode(settle)
    --写入缓存
    local key = PDEFINE.REDISKEY.GAME.resrecords..ServerId..":"..deskInfo.gameid..":"..deskInfo.ssid
    local res = {i=issue, t=now, result=settle_json}
    do_redis({"lpush", key, cjson.encode(res)})
    ResultSize = ResultSize + 1
    if ResultSize > 120 then
        do_redis({"ltrim", key, 0, 100})    --只保留100条(每20次清理一下)
        ResultSize = 100
    end

    --写入db
    if not force then
        local userbet = false
        for _, user in ipairs(self.users) do
            if user.cluster_info and user.round.totalbet and user.round.totalbet > 0 then
                userbet = true
                break
            end
        end
        if not userbet then return end
    end
    local roomtype = 1
    local sql = string.format("insert into d_desk_game_record(gameid,deskid,uuid,settle,create_time,roomtype,ssid,issue) values(%d, %d, '%s', '%s',%d, %d, %d, '%s')",
                                deskInfo.gameid, deskInfo.deskid, deskInfo.uuid, settle_json, now, roomtype, deskInfo.ssid, issue)
    skynet.send(".mysqlpool", "lua", "execute", sql)
end

-- 通过uid获取用户对象
---@return BetUser
function BetAgent:findUserByUid(uid)
    for _, user in pairs(self.users) do
        if user.uid == uid then
            return user
        end
    end
    return nil
end

-- 返回桌子相应信息
function BetAgent:getDeskInfoData(uid)
    ---@type DeskInfo
    local desk = copyData(self.deskInfo)
    --我自己的信息
    if uid and uid > 0 then
        desk.uuid = nil
        local u = self:findUserByUid(uid)
        if u then
            local user = copyData(u)
            desk.user = user
        else
            return nil
        end
    end
    for i, user in ipairs(desk.users) do
        filterData(user)
        if user.uid ~= uid then
            -- 去掉对方玩家押注信息
            user.round = nil
        end
    end
    --处理剩余时间
    if desk.endtime then
        desk.time = math.max(0, desk.endtime - os.time())
    end
    --玩家人数
    desk.playercnt = #self.users
    if desk.taxrate then
        desk.taxrate = nil
    end
    --玩法额外信息
    if self.gamelogic.additionDeskData then
        self.gamelogic.additionDeskData(desk)
    end
    return desk
end

-- 广播用户更新信息
function BetAgent:broadcastPlayerInfo(user)
    -- 广播消息给其他玩家
    local notify_object = {}
    notify_object.c = PDEFINE.NOTIFY.PLAYER_UPDATE_INFO
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.uid = user.uid
    notify_object.svip = user.svip
    notify_object.svipexp = user.svipexp
    notify_object.rp = user.rp
    notify_object.level = user.level
    notify_object.levelexp = user.levelexp
    notify_object.coin = user.coin
    notify_object.playername = user.playername
    notify_object.usericon = user.usericon
    notify_object.charm = user.charm
    notify_object.avatarframe = user.avatarframe
    self:broadcast(cjson.encode(notify_object), user.uid)
end

-- 广播消息
function BetAgent:broadcast(retobj, excludeUid)
    if not excludeUid then
        for _, muser in pairs(self.users) do
            muser:sendMsg(retobj)
        end
    else
        for _, muser in pairs(self.users) do
            if muser.uid ~= excludeUid then
                muser:sendMsg(retobj)
            end
        end
    end
end

-- 创建房间
function BetAgent:createRoom(msg, deskid, gameid, cluster_info, gamelogic)
    self.gamelogic = gamelogic
    local uid = math.sfloor(msg.uid)  -- 创房人id
    local ssid = math.sfloor(msg.ssid) or 0
    local conf = msg.conf or {}
    self.gameid = gameid
    LOG_DEBUG("create room :",deskid, " msg:  ", msg)

    local deskInfo = self.deskInfo
    deskInfo.conf = conf
    deskInfo.owner = uid
    deskInfo.ssid = ssid
    deskInfo.uuid = deskid .. os.time()
    deskInfo.taxrate = msg.taxrate or 0
    self:newIssue()
    -- 记录创房时间
    deskInfo.conf.create_time = os.time()
    if gamelogic.initDesk then
        gamelogic.initDesk(deskInfo)
    end

    -- 获取用户信息
    if cluster_info and uid > 0 then
        local playerInfo = cluster.call(cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid) --去node服找对应的player
        -- 获取房主座位号
        local seatid = 0
        ---@type BetUser
        local user = BetUser.new(playerInfo, self.deskInfo)
        user:init(seatid, self.deskInfo, cluster_info)
        if gamelogic.initUser then
            gamelogic.initUser(user)
        end
        self:insertUser(user)
    end

    --加载策略
    self.stgy:load(ssid, gameid)

    --加载趋势图
    self:loadRecords()

    -- 写入数据库
    self:writeDB()

    --随机发言定时器
    self:setAutoChatTimer(2000, 4500)
end

-- 加入房间
function BetAgent:joinRoom(msg, cluster_info)
    -- if isMaintaining then
    --     return PDEFINE.RET.ERROR.ERROR_GAME_FIXING
    -- end
    local uid = math.floor(msg.uid)
    local deskid = math.floor(msg.deskid)
    -- 判断是否已经在游戏中
    -- 重新加入房间
    local exist_user = self:findUserByUid(uid)
    if exist_user then
        -- 重新生成token
        exist_user:init(exist_user.seatid, self.deskInfo, cluster_info)
        local ok, playerInfo
        if not cluster_info then
            ok, playerInfo = pcall(cluster.call, "master", ".userCenter", "getPlayerInfo", uid)
        else
            ok, playerInfo = pcall(cluster.call, cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid)
        end
        -- 目前只需要更新金币信息
        if ok and playerInfo then
            exist_user.coin = playerInfo.coin
            exist_user.diamond = playerInfo.diamond
            exist_user:syncUserInfo(playerInfo)
        end
        exist_user.isexit = 0
        exist_user.race_id = msg.race_id and msg.race_id or 0
        exist_user.race_type = msg.race_type and msg.race_type or 0
        local retobj  = {}
        retobj.code = PDEFINE.RET.SUCCESS
        retobj.c = math.floor(msg.c)
        retobj.gameid = self.deskInfo.gameid
        retobj.deskinfo  = self:getDeskInfoData(uid)
        if retobj.deskinfo then
            retobj.deskinfo.deskFlag = 1
        end
        -- 广播用户信息
        -- self:broadcastPlayerInfo(exist_user)
        return resp(retobj)
    end
    -- 判断参数是否缺失
    if not uid or not deskid then
        return PDEFINE.RET.ERROR.PARAM_ILLEGAL
    end

    if #self.users >= MAX_USER then
        return PDEFINE.RET.ERROR.DESK_NO_SEAT
    end

    -- 获取用户信息
    local ok, playerInfo
    if not cluster_info then
        ok, playerInfo = pcall(cluster.call, "master", ".userCenter", "getPlayerInfo", uid)
    else
        ok, playerInfo = pcall(cluster.call, cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid)
    end
    if not ok or not playerInfo then
        return PDEFINE.RET.ERROR.CALL_FAIL
    end
    -- 新建用户对象
    ---@type BetUser
    local user = BetUser.new(playerInfo, self.deskInfo)
    user.race_id = msg.race_id and msg.race_id or 0
    user.race_type = msg.race_type and msg.race_type or 0
    if self.gamelogic.initUser then
        self.gamelogic.initUser(user)
    end

    -- 房间号错误
    if tonumber(deskid) ~= tonumber(self.deskInfo.deskid) then
        LOG_ERROR("deskid: ", deskid, " is not match ==> ", self.deskInfo.deskid)
        return PDEFINE.RET.ERROR.DESKID_FAIL
    end

    local seatid = 0
    user:init(seatid, self.deskInfo, cluster_info)
    self:insertUser(user, true)

    if user.seatid > 0 then
        local retobj  = {}
        retobj.c      = PDEFINE.NOTIFY.PLAYER_ENTER_ROOM --有用户加入了
        retobj.code   = PDEFINE.RET.SUCCESS
        retobj.user   = copyData(user)
        retobj.user.round = nil
        self:broadcast(cjson.encode(retobj), user.uid)
    end

    -- TODO: chat
    --pcall(cluster.send, "node", ".chat", "changeDeskInfoUsers", self.deskInfo.deskid, self.deskInfo.gameid, self.users, self.deskInfo.cid)

    local retobj  = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = math.floor(msg.c)
    retobj.gameid = self.deskInfo.gameid
    retobj.deskinfo  = self:getDeskInfoData(uid)
    if retobj.deskinfo then
        retobj.deskinfo.deskFlag = 1
    end
    return resp(retobj)
end

--开启新一轮游戏
function BetAgent:nextRound()
    self:newIssue()

    if isMaintain() then
        self:maintain()
        return
    else
        isMaintaining = false
    end

    local now = os.time()
    local exitedUsers = {}
    local offlineUsers = {}  -- 离线的人
    for _, user in ipairs(self.users) do
        if not user.cluster_info and (now > user.leavetime) then
            user.isexit = 1
        end
        if user.isexit == 1 then
            table.insert(exitedUsers, {uid=user.uid, seatid=user.seatid})
        elseif user.offline == 1 then  -- 放这里，会清除cluster信息
            table.insert(offlineUsers, {uid=user.uid, seatid=user.seatid})
        end
    end
    -- 将已经退出的玩家删除，并且广播
    for _, user in ipairs(exitedUsers) do
        self:userExit(user.uid, 0)
    end
    -- 离线的玩家，从桌子信息中删除用户
    for _, user in ipairs(offlineUsers) do
        self:userExit(user.uid, PDEFINE.RET.ERROR.USER_OFFLINE)
        pcall(cluster.send, "master", ".agentdesk", "removeDesk", user.uid, self.deskid)
    end

    --补充机器人
    local delayTime = math.random(200, 500)
    skynet.timeout(delayTime, function()
        self:aiJoin()
    end)
end

local function sortbet(a, b)
    return a.betcoin > b.betcoin
end

--更新桌上玩家
function BetAgent:updateDeskUser()
    self.deskInfo.users = {}
    local diviner = self.users[1]  --神算子
    if not diviner then
        return
    end
    local usercount = #(self.users)
    if usercount == 1 then
        diviner.seatid = 1
        table.insert(self.deskInfo.users, diviner)
        return
    end

    for i = 2, usercount do
        if self.users[i].wincoin > diviner.wincoin then
            diviner = self.users[i]
        end
    end
    --押注排名前六的土豪玩家，神算子放第2位，神算子和土豪不重复
    local userbets = {} --玩家押注
    for _, user in ipairs(self.users) do
        user.seatid = 0
        table.insert(userbets, user)
    end
    table.sort(userbets, sortbet)
    local users = {}
    for i, userbet in ipairs(userbets) do
        if userbet.uid ~= diviner.uid then
            table.insert(users, userbet)
        end
        if #users == 1 then
            table.insert(users, diviner)
        end
        if #users == TABLE_USER_COUNT then
            break
        end
    end
    --设置座位号
    for i, user in ipairs(users) do
        user.seatid = i
    end
    self.deskInfo.users = users
end

--播报玩家赢钱
function BetAgent:broadcastWinners(delaySec)
    local realuser = false
    ---@type BetUser[]
    local winners = {}
    for _, user in ipairs(self.users) do
        if (user.seatid > 0 or user.cluster_info) and user.round.wincoin >= user.round.totalbet + 5000 then
            table.insert(winners, user)
        end
        if user.cluster_info then realuser = true end
    end
    if realuser or math.random() < 0.2 then
        table.sort(winners, function(ua, ub)
            local va = ua.round.wincoin - ua.round.totalbet
            local vb = ub.round.wincoin - ub.round.totalbet
            return va > vb
        end)
        local size = math.min(2, #winners)
        for i = 1, size do
            local winner = winners[i]
            winner:notifyLobby(winner.round.wincoin-winner.round.totalbet, self.gameid, delaySec)
        end
    end
end

--获取桌上的玩家
function BetAgent:getDeskUserData()
    local users = table.copy(self.deskInfo.users)
    for i, user in ipairs(users) do
        filterData(user)
        user.round = nil
    end
    return users
end

--机器人随机主动聊天
function BetAgent:setAutoChatTimer(tmin, tmax)
    local function repeat_func()
        local t = os.time()
        if math.random() < 0.75 and t - self.lastRandomChatTime > math.random(4, 8) then
            self.lastRandomChatTime = t
            self:sendRandomChat()
        end
        self:setAutoChatTimer(tmin, tmax)
    end
    local ti = math.random(tmin, tmax)
    skynet.timeout(ti, repeat_func)
end

--机器人发送随机聊天消息
function BetAgent:sendRandomChat()
    --接收者
    local receivers = self.deskInfo.users
    local size = #receivers
    if size <= 0 then return end
    local randomseats = {}  --排名越靠前的，收到消息的概率越大
    for i = 1, size do
        for j = 1, size-i+1 do
            table.insert(randomseats, i)
        end
    end
    local idx = randomseats[math.random(#randomseats)]
    local receiver = receivers[idx]

    --发送者
    local senders = {}
    for _, user in ipairs(self.users) do
        if not user.cluster_info then
            table.insert(senders, user)
        end
    end
    local sender = senders[math.random(#senders)]
    if sender == receiver then return end

    --消息构造
    local emotionId = math.random(1, 7)
    if math.random()<0.02 then
        emotionId = 8
    end
    local cotent = cjson.encode({
        cmd='interactive_emotion',
        emotionId = emotionId,
        fromUid = sender.uid,
        toUid = receiver.uid,
    })
    local nowtime = os.time()
    local msg = cjson.encode({
        uid = sender.uid,
        nick = sender.playername,
        gender = 1,
        icon = sender.usericon,
        avatar = sender.avatarframe,
        chatSkin = "chat_000",
        fontSkin = "font_color_0",
        msgType = 4,
        sendTime = nowtime * 1000,
        content = cotent
    })
    self:sendChat({uid=sender.uid, msg=msg})
end

-- 聊天
function BetAgent:sendChat(msg)
    local uid = math.floor(msg.uid)
    local user = self:findUserByUid(uid)
    if user then
        local retobj = {c = PDEFINE.NOTIFY.NOTIFY_ROOM_CHAT, code = PDEFINE.RET.SUCCESS, uid=uid, seatid = user.seatid, msg = msg.msg}
        self:broadcast(cjson.encode(retobj))
    end
    return PDEFINE.RET.SUCCESS
end

-- API更新桌子里玩家的金币
function BetAgent:addCoinInGame(uid, coin, diamond)
    local user = self:findUserByUid(uid)
    if nil ~= user then
        if coin then
            user.coin = user.coin + coin
        end
        if diamond then
			user.diamond = user.diamond + diamond
		end
    end
    return PDEFINE.RET.SUCCESS
end

-- 玩家离线
function BetAgent:offline(offline, uid)
    LOG_INFO("CMD.offline", "offline:", offline, "uid:", uid)
    local user = self:findUserByUid(uid)
    if user then
        if offline == 2 then --掉线
            user.offline = 1
        else
            user.offline = 0
        end
    end
end

-- 回收桌子
function BetAgent:destroy(isDismiss)
    for _,user in ipairs(self.users) do
        -- 将机器人回收
        if not user.cluster_info then
            self:RecycleAi(user)
        end
    end
    local uids = {}
    for _, user in ipairs(self.users) do
        if user.cluster_info then
            table.insert(uids, user.uid)
        end
    end
    -- 通知解锁玩家
    pcall(cluster.send, "master", ".mgrdesk", "unlockPlayer", self.deskid, uids, self.gameid, PDEFINE.BAL_ROOM_TYPE.MATCH)
    -- 通知房间解散
    pcall(cluster.send, "master", ".strategymgr", "onDeskDestroy", self.deskid, self.gameid)
    -- 回收agent
    skynet.send(".dsmgr", "lua", "recycleAgent", skynet.self(), self.deskid, self.gameid)
end

--开始维护
function BetAgent:maintain()
    if isMaintaining then return end
    isMaintaining = true
    LOG_INFO("maintain", self.gameid, self.deskid)

    --将所有真人玩家踢出
    local notify_retobj = { c=PDEFINE.NOTIFY.NOTIFY_SYS_KICK, code=PDEFINE.RET.SUCCESS, deskid=self.deskid }
    self:broadcast(cjson.encode(notify_retobj))

    local uids = {}
    for i = #self.users, 1, -1 do
        local user = self.users[i]
        if user.cluster_info then
            table.insert(uids, user.uid)
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", self.gameid, self.deskid) --释放桌子对象
            if user.isexit == 0 then
                pcall(cluster.send, "master", ".agentdesk", "removeDesk", user.uid, self.deskid)
            end
            table.remove(self.users, i)
        end
    end
    -- 通知解锁玩家
    if #uids > 0 then
        pcall(cluster.send, "master", ".mgrdesk", "unlockPlayer", self.deskid, uids, self.gameid, PDEFINE.BAL_ROOM_TYPE.MATCH)
    end

    self.deskInfo.curseat = #self.users
end

-- 通过api踢人
function BetAgent:apiKickDesk()
    for _, muser in ipairs(self.users) do
        if muser.cluster_info and muser.isexit == 0 then
            pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "deskBack", self.gameid, self.deskid) --释放桌子对象

            LOG_DEBUG("apiKickDesk ", self.deskInfo.gameid, self.deskInfo.deskid," after changMatchCurUsers deskInfo.curseat:", self.deskInfo.curseat)
        end
    end

    local retobj = {
        c = PDEFINE.NOTIFY.ALL_GET_OUT,
        code = PDEFINE.RET.SUCCESS
    }
    self:broadcast(cjson.encode(retobj))
    self:destroy()
end

-- 设置玩家退出标记
function BetAgent:setPlayerExit(uid)
    local user = self:findUserByUid(uid)
    if user then
        user.isexit = 1
        if user.cluster_info then
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", self.gameid, self.deskid) --释放桌子对象
        end
    end
    return PDEFINE.RET.SUCCESS
end

function BetAgent:userExit(uid,spcode)
    ---@type BetUser
    local user = self:findUserByUid(uid)
    if not user then
        return
    end

    if user.cluster_info then
        pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", self.gameid, self.deskid) --释放桌子对象
    else
        pcall(cluster.send, "ai", ".aiuser", "recycleAi",user.uid, user.coin, os.time()+10, self.deskid)
    end
    LOG_DEBUG("userExit uid:", user.uid, "spcode:", spcode)
    --local exitNotifyMsg = { c=PDEFINE.NOTIFY.PLAYER_EXIT_ROOM, code = PDEFINE.RET.SUCCESS, uid = uid, seatid = user.seatid, spcode = spcode}
    --self:broadcast(cjson.encode(exitNotifyMsg))
    self.deskInfo.curseat = #self.users
    -- 从桌子列表中删除玩家
    for i, u in ipairs(self.users) do
        if u.uid == uid then
            table.remove(self.users, i)
            break
        end
    end
    for i, u in ipairs(self.deskInfo.users) do
        if u.uid == uid then
            table.remove(self.deskInfo.users, i)
            break
        end
    end

    self:syncPlayerCount()
end

-- 玩家退出房间
function BetAgent:exitG(msg)
    local uid = math.floor(msg.uid)
    local ret = {c=msg.c, uid=msg.uid, code=PDEFINE.RET.SUCCESS}
    local user = self:findUserByUid(uid)
    if user and user.cluster_info then
        if self.deskInfo.state == DESK_STATE.FREE then
            --还没开始下注可以直接离开，否则结算之后离开
            self:userExit(uid, 0)
        else
            user.isexit = 1
        end
        pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", self.gameid, self.deskid) --释放桌子对象
    end
    return ret
end

-- 更新玩家的连接信息
function BetAgent:updateUserAgent(uid, agent)
    local user = self:findUserByUid(uid)
    if user and user.cluster_info then
        user.cluster_info.address = agent
    end
end

-- 更新某个用户信息,并且广播
function BetAgent:updateUserInfo(uid)
    LOG_DEBUG("updateUserInfo", "uid:", uid)
    local exist_user = self:findUserByUid(uid)
    if exist_user and exist_user.cluster_info then
        local ok, playerInfo = pcall(cluster.call, exist_user.cluster_info.server, exist_user.cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid)
        if ok and playerInfo then
            exist_user:syncUserInfo(playerInfo)
            --self:broadcastPlayerInfo(exist_user)
        end
    end
end

-- 通知用户比赛结束
function BetAgent:updateRaceStatus(msg)
    local uid = msg.uid
    local race_id = msg.race_id
    local status = msg.status
    local user = self:findUserByUid(uid)
    if not user or user.race_id ~= race_id then
        return PDEFINE.RET.SUCCESS
    end
    local notifyObj = {c=PDEFINE.NOTIFY.NOTIFY_RACE_END, code=PDEFINE.RET.SUCCESS, uid=uid,spcode=0}
    pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(notifyObj))
    user.race_id = 0
    user.race_type = nil
    return PDEFINE.RET.SUCCESS
end

--获取玩家列表
function BetAgent:getUserList(msg)
    local ret = {c=msg.c, code=PDEFINE.RET.SUCCESS, list={}}
    for _, user in ipairs(self.users) do
        table.insert(ret.list, {
            uid = user.uid,
            playername = user.playername,
            coin = user.coin,
        })
    end
    return ret
end

--加载游戏记录
function BetAgent:loadRecords()
    local deskInfo = self.deskInfo
    local key = PDEFINE.REDISKEY.GAME.records..ServerId..":"..deskInfo.gameid..":"..deskInfo.ssid
    local res = do_redis({"get", key})
    if res then
        deskInfo.records = cjson.decode(res)
    end
end

--保存游戏记录
function BetAgent:saveRecords()
    local deskInfo = self.deskInfo
    local key = PDEFINE.REDISKEY.GAME.records..ServerId..":"..deskInfo.gameid..":"..deskInfo.ssid
    do_redis({"setex", key, cjson.encode(deskInfo.records), 86400*30}) --缓存30天
end

--获取游戏记录
function BetAgent:getRecords(msg)
    local ret = {c=msg.c, code=PDEFINE.RET.SUCCESS, records=self.deskInfo.records}
    return ret
end

--策略策略控制条件
function BetAgent:getRestriction()
    return self.stgy:getRestriction()
end

--重载桌子策略
function BetAgent:reloadStrategy()
    self.stgy:reload()
end

--重载桌子配置
function BetAgent:reloadSetting()
    local deskInfo = self.deskInfo
    local ok ,cfg = pcall(cluster.call, "master", ".gamemgr", "getRow", self.gameid)
    if ok and cfg then
        deskInfo.taxrate = tonumber(cfg.taxrate) or 0
    end
    LOG_DEBUG("reloadSetting", self.deskid, self.gameid, deskInfo.taxrate)
end

--更新策略数据
function BetAgent:updateStrategyData(userbet, userwin)
    self.stgy:update(userbet, userwin)
end

return BetAgent
