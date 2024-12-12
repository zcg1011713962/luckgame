--[[
    子游戏基类
]]

local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local player_tool = require "base.player_tool"
local baseUser = require "base.user"
local DEBUG = os.getenv("DEBUG")

---@class AgentFunc
---@field gameOver function  结束游戏
---@field roundOver function 此轮结束

-- 成功返回
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, retobj
end

---@class BaseAgent
local Agent = {}
Agent.__index = Agent
---@type BaseDeskInfo
Agent.deskInfo = nil

setmetatable(Agent, {
    ---@return BaseAgent
    __call = function (cls, ...)
        return cls.new(...)
    end
})

-- 创建新的游戏
---@return BaseAgent
function Agent.new(gameid, deskInfo)
    ---@type BaseAgent
    local subAgent = setmetatable({}, Agent)
    subAgent.gameid = gameid  -- 游戏gameid
    ---@type BaseDeskInfo
    subAgent.deskInfo = deskInfo  -- 游戏的桌子对象
    ---@type AgentFunc
    -- subAgent.func = nil  -- 自定义方法
    return subAgent
end

-- 打印消息
function Agent:print(...)
    LOG_DEBUG(self.gameid , ' => ', ...)
end

-- 创建房间
function Agent:createRoom(msg, deskid, gameid, cluster_info)
    local uid        = math.floor(msg.uid)  -- 创房人id
    local cid        = msg.cid  -- 俱乐部id
    if cid then
        cid = math.floor(cid)
        self.cid = cid
    end
    if isMaintain() then
        return PDEFINE.RET.ERROR.ERROR_GAME_FIXING
    end
    self.gameid = gameid
    self:print("create room :",deskid, " msg:  ", msg)
    local conf = msg.conf
    -- 必须带房间配置信息
    if not conf then
        return PDEFINE.RET.ERROR.PARAM_ILLEGAL
    end
    -- 初始化桌子信息
    self.deskInfo:init(uid, msg)
    -- 获取用户信息
    local playerInfo = nil
    -- 不是排位赛和私人房间，则需要判断金币是否足够
    if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        if not cluster_info then
            local ok
            ok, playerInfo = pcall(cluster.call, "master", ".userCenter", "getPlayerInfo", uid)
        else
            playerInfo = cluster.call(cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid) --去node服找对应的player

        end
        if not playerInfo then
            return PDEFINE.RET.ERROR.CALL_FAIL
        end
        local bet = self.deskInfo.bet
        if playerInfo.coin < bet then
            return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH --金币不足
        end
    end

    -- 如果是匹配房, 设置机器人，并将房主拉入房间
    if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        -- 获取房主座位号
        local seatid = 0
        if self.deskInfo.func and self.deskInfo.func.assignSeat then
            seatid = self.deskInfo.func.assignSeat()
            LOG_DEBUG("createRoom msg seatid: ", seatid, ' 从 assignSeat分配')
        else
            seatid = self.deskInfo:getSeatId()
            LOG_DEBUG("createRoom msg seatid: ", seatid, ' 从 deskinfo 分配')
        end

        ---@type BaseUser
        local user = baseUser(playerInfo, self.deskInfo)
        user:init(seatid, self.deskInfo, cluster_info, msg.ssid)
        user.luckBuff = hasLuckyBuffer(user.uid, self.deskInfo.gameid)
        user.race_id = msg.race_id and msg.race_id or 0
        user.race_type = msg.race_type and msg.race_type or 0
        self.deskInfo:insertUser(user)

        local autoAddAi = true
        if self.func.autoAiJoin and self.func.autoAiJoin then
            autoAddAi = self.func.autoAiJoin()
        end
        if autoAddAi then
            -- 设置一个定时器，方便前端获取倒计时信息
            self.deskInfo:setWaitTime()
        end
    end
    if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE and #self.deskInfo.users == 0 then
        -- 如果是特殊房间，则加入一个机器人
        if self.deskInfo.conf.spcial == 1 then
            local ok, aiUserList = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", 1, true)
            if ok then
                self.deskInfo:aiJoin(aiUserList[1])
                self.deskInfo:userReady(aiUserList[1].uid)
            end
        end
        self.deskInfo:setAutoRecycle()
    end
    if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
        self.deskInfo.state = PDEFINE.DESK_STATE.WaitStart
    end
    -- 写入数据库
    self.deskInfo:writeDB()

    self.lastReplyChatTime = 0
    self:setAutoChatTimer(2000, 5000)

    return nil
end

-- 加入房间
function Agent:joinRoom(msg, cluster_info)
    local uid = math.floor(msg.uid)
    local seatid = msg.seatid and math.floor(msg.seatid) or nil
    local deskid = math.floor(msg.deskid)
    if self.deskInfo.isDestroy then
        return PDEFINE.RET.ERROR.DESKID_NOT_FOUND
    end
    if msg.tn_id ~= self.deskInfo.conf.tn_id then
        return PDEFINE.RET.ERROR.TN_UNREGISTERED
    end
    -- 判断是否已经在游戏中
    -- 重新加入房间
    local exist_user = self.deskInfo:findUserByUid(uid)
    if exist_user then
        local isExit = exist_user.isexit
        -- 重新生成token
        exist_user:init(exist_user.seatid, self.deskInfo, cluster_info, exist_user.ssid)
        local ok, playerInfo
        if not cluster_info then
            ok, playerInfo = pcall(cluster.call, "master", ".userCenter", "getPlayerInfo", uid)
        else
            ok, playerInfo = pcall(cluster.call, cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid)
        end
        -- 目前只需要更新金币信息(比赛房间不需要更新金币)
        if ok and playerInfo and self.deskInfo.conf.roomtype ~= PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
            exist_user.coin = playerInfo.coin
            exist_user.diamond = playerInfo.diamond
            self.deskInfo:syncUserInfo(exist_user, playerInfo)
        end
        exist_user.auto = 0
        exist_user.isexit = 0
        exist_user.race_id = msg.race_id and msg.race_id or 0
        exist_user.race_type = msg.race_type and msg.race_type or 0
        local retobj  = {}
        retobj.code = PDEFINE.RET.SUCCESS
        retobj.c = math.floor(msg.c)
        retobj.gameid = self.deskInfo.gameid
        retobj.deskinfo  = self.deskInfo:toResponse(uid)
        retobj.isViewer = 0
        if retobj.deskinfo then
            retobj.deskinfo.deskFlag = 1
        end
        -- 取消托管状态
        self.deskInfo:autoMsgNotify(exist_user, 0, nil)
        -- 广播用户信息
        if isExit then
            self.deskInfo:broadcastPlayerEnterRoom(exist_user.uid)
        else
            self.deskInfo:broadcastPlayerInfo(exist_user)
        end
        skynet.timeout(20, function()
            -- 检测金币不足
            self.deskInfo:checkDangerCoin(exist_user)
            -- 广播语聊信息
            self.deskInfo:updateMicStatus()
        end)
        return resp(retobj)
    end
    -- 判断参数是否缺失
    if not uid or not deskid then
        return PDEFINE.RET.ERROR.PARAM_ILLEGAL
    end
    -- 此桌子已经在回收流程中，直接不让匹配
    if self.deskInfo.isDestroy then
        return PDEFINE.RET.ERROR.DESK_ERROR
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
    -- 房间号错误
    if tonumber(deskid) ~= tonumber(self.deskInfo.deskid) then
        LOG_ERROR("deskid: ", deskid, " is not match ==> ", self.deskInfo.deskid)
        return PDEFINE.RET.ERROR.DESKID_FAIL
    end

    local currCnt = self.deskInfo:getUserCnt()
    if self.deskInfo.seat <= currCnt then
        return PDEFINE.RET.ERROR.DESK_NO_SEAT
    end
    if self.deskInfo.conf.maxSeat and self.deskInfo.conf.maxSeat <= currCnt then
        return PDEFINE.RET.ERROR.DESK_NO_SEAT
    end

    -- 新建用户对象
    ---@type BaseUser
    local user = baseUser(playerInfo, self.deskInfo)
    if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
        user.realCoin = user.coin
        if msg.coin then
            user.coin = msg.coin
        else
            user.coin = self.deskInfo.conf.initCoin
        end
    end
    user.race_id = msg.race_id and msg.race_id or 0
    user.race_type = msg.race_type and msg.race_type or 0
    user.luckBuff = hasLuckyBuffer(user.uid, self.deskInfo.gameid)

    -- 判断金币是否足够
    if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        if user.coin < self.deskInfo.conf.mincoin then
            return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        end
    else
        if not self.deskInfo:isCoinEnough(user.coin) then
            return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        end
    end
    -- 如果房间已经在换桌流程，或者结算流程，则反馈错误
    if self.deskInfo.state == PDEFINE.DESK_STATE.WaitSwitch or self.deskInfo.state == PDEFINE.DESK_STATE.WaitSettle then
        return PDEFINE.RET.ERROR.DESK_ERROR
    end

    -- 好友房可以观战
    -- 匹配房如果座位不够，不允许加入
    -- 匹配房如果有空座位，则作为观战者加入，并且占座位，等待下局开始
    if self.deskInfo.state ~= PDEFINE.DESK_STATE.MATCH and self.deskInfo.state ~= PDEFINE.DESK_STATE.WaitStart then
        if self.deskInfo:isCoinGame() then
            local viewer = self.deskInfo:findViewUser(user.uid)
            if viewer then
                self.deskInfo:syncUserInfo(viewer, playerInfo)
                if viewer.seatid then
                    seatid = viewer.seatid
                end
                user = viewer
            end
            if not seatid then
                if self.deskInfo.func and self.deskInfo.func.assignSeat then
                    seatid = self.deskInfo.func.assignSeat()
                    LOG_DEBUG("msg seatid: ", seatid, ' 从 assignSeat分配')
                else
                    seatid = self.deskInfo:getSeatId()
                    LOG_DEBUG("msg seatid: ", seatid, ' 从 deskinfo 分配')
                end
            end
            -- user:init(seatid, self.deskInfo, cluster_info, msg.ssid)
            -- local viewer = self.deskInfo:findViewUser(user.uid)
            -- 原来不在房间的情况下，加入观战列表
            -- 如果在房间，就不用管了
            if not viewer then
                user:init(seatid, self.deskInfo, cluster_info, msg.ssid)
                self.deskInfo:insertViews(user)
            else
                user.seatid = seatid
            end
            local retobj  = {}
            retobj.code = PDEFINE.RET.SUCCESS
            retobj.c = math.floor(msg.c)
            retobj.gameid = self.deskInfo.gameid
            retobj.deskinfo  = self.deskInfo:toResponse(uid)
            retobj.isViewer = 1
            if retobj.deskinfo then
                retobj.deskinfo.deskFlag = 1
            end
            return resp(retobj)
        elseif self.deskInfo:isDirectPlayGame() then
            --nothing to do
        elseif self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
            if #self.deskInfo.views >= self.deskInfo.maxView then
                return PDEFINE.RET.ERROR.ERROR_MORETHAN_SEAT
            end
            user:init(-1, self.deskInfo, cluster_info, msg.ssid)
            local viewer = self.deskInfo:findViewUser(user.uid)
            if viewer then
                self.deskInfo:syncUserInfo(viewer, playerInfo)
            else
                self.deskInfo:insertViews(user)
            end
            local retobj  = {}
            retobj.code = PDEFINE.RET.SUCCESS
            retobj.c = math.floor(msg.c)
            retobj.gameid = self.deskInfo.gameid
            retobj.deskinfo  = self.deskInfo:toResponse(uid)
            retobj.isViewer = 1
            if retobj.deskinfo then
                retobj.deskinfo.deskFlag = 1
            end
            return resp(retobj)
        else
            return PDEFINE.RET.ERROR.DESK_IS_PLAYING
        end
    end

    -- 指定位置是否有人
    LOG_DEBUG("msg seatid: ", seatid, ' gameid:', self.deskInfo.gameid)
    if seatid then
        if not table.contain(self.deskInfo.seatList, seatid) then
            return PDEFINE.RET.ERROR.ERROR_SEAT_EXISTS_USER
        end
        -- 锁定当前位置
        self.deskInfo:lockSeatid(seatid)
    else
        -- 随机指定位置
        if self.deskInfo.func and self.deskInfo.func.assignSeat then
            seatid = self.deskInfo.func.assignSeat()
            LOG_DEBUG("msg seatid: ", seatid, ' 从 assignSeat分配')
        else
            seatid = self.deskInfo:getSeatId()
            LOG_DEBUG("msg seatid: ", seatid, ' 从 deskinfo 分配')
        end
    end
    -- 无法获取座位号
    if not seatid then
        return PDEFINE.RET.ERROR.DESK_NO_SEAT
    end
    user:init(seatid, self.deskInfo, cluster_info, msg.ssid)
    self.deskInfo:insertUser(user)
    skynet.timeout(20, function()
        -- 广播语聊信息
        self.deskInfo:updateMicStatus()
    end)
    pcall(cluster.send, "node", ".chat", "changeDeskInfoUsers", self.deskInfo.deskid, self.deskInfo.gameid, self.deskInfo.users, self.deskInfo.cid)
end

-- 获取加入房间的回复消息
function Agent:joinRoomResponse(cmd, uid)
    local resp  = {}
    resp.code = PDEFINE.RET.SUCCESS
    resp.c = cmd
    resp.gameid = self.deskInfo.gameid
    resp.deskinfo = self.deskInfo:toResponse(uid)
    local user = self.deskInfo:findUserByUid(uid)
    -- 如果是坐下了，则需要广播加入房间消息
    if user then
        -- 私人房需要广播加入房间给其他人
        self.deskInfo:broadcastPlayerEnterRoom(uid)
    end
    if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        -- 如果是好友房，则在加入真人之后，需要开启定时器，增加机器人
        if self.deskInfo.conf.autoStart == 1 then
            skynet.timeout(100, function ()
                -- 延迟一秒之后，自动准备
                self.deskInfo:userReady(uid)
            end)
        -- else
        --     self.deskInfo:setAutoReady(uid)
        end
        if self.deskInfo:isJoinAi() then
            self.deskInfo:autoStartGame()
        end
        -- 10秒后自动准备
        -- self.deskInfo:setAutoReady(uid)
    elseif self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT and self.deskInfo.state == PDEFINE.DESK_STATE.WaitStart then
        if self.deskInfo.conf.start_time < os.time() then
            if self.deskInfo.conf.stop_time < os.time() then
                self.deskInfo:waitSwitchDesk()
            else
                self:TNGameStart(true)
            end
        end
    end
    return resp
end

-- 检测是否可以开始游戏
function Agent:checkStart()
    if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE or self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.CLUB then
        -- 如果是私人房，则需要准备才能开始
        return false
    elseif self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.VIP and #self.deskInfo.users == self.deskInfo.seat then
        -- vip 房间需要拉人进房间
        skynet.timeout(60, function()
            local resp = {}
            resp.c = 43
            resp.gameid= self.deskInfo.gameid
            resp.code = PDEFINE.RET.SUCCESS
            resp.deskinfo = self.deskInfo:toResponse()
            local uids = {}
            for _, muser in pairs(self.deskInfo.users) do
                if muser.cluster_info and muser.isexit == 0 then
                    pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", cjson.encode(resp))
                end
                table.insert(uids, muser.uid)
            end
            pcall(cluster.send, "master", ".balviproommgr", "removeVipWaitUsers", uids)
        end)
        return true
    elseif #self.deskInfo.users == self.deskInfo.seat then
        return true
    end
    return false
end

-- 赛事游戏开始
-- midStart:是否是中途开始，非系统统一开始
function Agent:TNGameStart(midStart)
    if not midStart then
        -- 标记可以开始了
        self.deskInfo.conf.is_playing = 1
    end
    LOG_DEBUG("TNGameStart", midStart, self.deskInfo.conf.is_playing)
    if self.deskInfo.state == PDEFINE.DESK_STATE.WaitStart and self.deskInfo:getUserCnt() >= self.deskInfo:getMinSeat() then
        if midStart and self.deskInfo.conf.is_playing ~= 1 then
            -- 如果中间开始，则需要查看桌子是否是可开始状态
            return 
        end
        self.deskInfo.state = PDEFINE.DESK_STATE.MATCH
        self.deskInfo.func.startGame()
    end
end

-- 赛事关闭入口
-- 目前用来处理桌子上人数不够的申请换桌
function Agent:TNNoticCloseTime()
    LOG_DEBUG("TNNoticCloseTime")
    if self.deskInfo.state == PDEFINE.DESK_STATE.WaitStart and self.deskInfo:getUserCnt() < self.deskInfo:getMinSeat() then
        self.deskInfo:waitSwitchDesk()
    end
end

function Agent:actChatIcon(msg)
    local uid = math.floor(msg.uid)
    local flag = msg.flag or 1 -- 1:开启 2:关闭
    local user = self.deskInfo:findUserByUid(uid)
    if user then
        local retobj  = {code = PDEFINE.RET.SUCCESS, c = PDEFINE.NOTIFY.PLAYER_CHOOSE_CHATICON, uid=msg.uid, flag=flag, seatid=user.seatid}
        self.deskInfo:broadcast(cjson.encode(retobj))
    end
    return PDEFINE.RET.SUCCESS
end

--机器人随机主动聊天
function Agent:setAutoChatTimer(tmin, tmax)
    local function repeat_func()
        local t = os.time()
        if math.random() < 0.5 and t - self.lastReplyChatTime > math.random(4, 8) then
            self.lastReplyChatTime = t
            self:sendRandomChat()
        end
        self:setAutoChatTimer(tmin, tmax)
    end
    local ti = math.random(tmin, tmax)
    skynet.timeout(ti, repeat_func)
end

--机器人发送随机聊天消息
function Agent:sendRandomChat()
    local users = {}
    for _, user in ipairs(self.deskInfo.users) do
        if not user.cluster_info and user.timer and user.timer.runFunc==nil then  --没有定时器
            table.insert(users, user)
        end
    end
    if #users <= 0 then return end
    local user = users[math.random(#users)]
    local msgType = 3  --文字
    local content = math.random(0, 6)
    if math.random() < 0.6 then
        msgType = 2  --表情
        content = "emoji_0_"..math.random(1,6)
    end
    local msg = cjson.encode({
        uid = user.uid,
        nick=user.playername,
        gender = user.sex,
        icon = user.usericon,
        avatar = user.avatarframe,
        fontSkin = user.frontskin,
        chatSkin = user.chatSkin,
        fcoin = user.coin,
        msgType = msgType,
        sendTime = os.time() * 1000 + skynet.now()%1000,
        content = content
    })
    self:sendChat({uid=user.uid, msg=msg})
end

-- 聊天
function Agent:sendChat(msg)
    local uid     = math.floor(msg.uid)
    local user = self.deskInfo:findUserByUid(uid)
    if not user then
        user = self.deskInfo:findViewUser(uid)
    end
    if user then
        local retobj = {c = PDEFINE.NOTIFY.NOTIFY_ROOM_CHAT, code = PDEFINE.RET.SUCCESS, uid=uid, seatid = user.seatid, msg = msg.msg}
        self.deskInfo:broadcast(cjson.encode(retobj))

        local t = os.time()
        --有概率回复玩家的聊天信息
        if user.cluster_info and math.random() < 0.66 and t - self.lastReplyChatTime > math.random(4, 8) then
            self.lastReplyChatTime = t
            skynet.timeout(math.random(200, 400), function()
                self:sendRandomChat()
            end)
        end
    end
    return PDEFINE.RET.SUCCESS
end

-- API更新桌子里玩家的金币
function Agent:addCoinInGame(uid, coin, diamond)
    local user = self.deskInfo:findUserByUid(uid)
    if not user then
        user = self.deskInfo:findViewUser(uid)
    end
    if nil ~= user then
        if coin then
            if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
                user.realCoin = user.realCoin + coin
            else
                user.coin = user.coin + coin
            end
        end
        if diamond then
			user.diamond = user.diamond + diamond
		end
    end
    return PDEFINE.RET.SUCCESS
end

-- 玩家离线
function Agent:offline(offline, uid)
    LOG_INFO("CMD.offline", "offline:", offline, "uid:", uid)
    local user = self.deskInfo:findUserByUid(uid)
    if user then
        local retobj = {}
        retobj.c = PDEFINE.NOTIFY.NOTIFY_ONLINE
        retobj.code = PDEFINE.RET.SUCCESS
        retobj.offline = offline --2:离线 1:在线
        retobj.uid = uid
        retobj.seatid = user.seatid
        self.deskInfo:broadcast(cjson.encode(retobj),uid)

        if offline == 2 then
            user.offline = 1
            user.auto = 1
            user.mic = 0
            self.deskInfo:autoMsgNotify(user, 1, 0)
        else
            user.offline = 0
        end
        self.deskInfo:updateMicStatus()
    end
end

-- 通过api踢人
function Agent:apiKickDesk()
    for _, muser in pairs(self.deskInfo.users) do
        if muser.cluster_info and muser.isexit == 0 then
            pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "deskBack", self.gameid, self.deskInfo.deskid) --释放桌子对象
            
            self:print("apiKickDesk ", self.deskInfo.gameid, self.deskInfo.deskid," after changMatchCurUsers deskInfo.curseat:", self.deskInfo.curseat)
        end
    end

    for _, muser in pairs(self.deskInfo.views) do
        if muser.cluster_info then
            pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "deskBack", self.gameid, self.deskInfo.deskid) --释放桌子对象
        end
    end

    local retobj = {
        c = PDEFINE.NOTIFY.ALL_GET_OUT,
        code = PDEFINE.RET.SUCCESS
    }
    self.deskInfo:broadcast(cjson.encode(retobj))
    self.deskInfo:destroy()
end

-- 玩家退出房间
function Agent:exitG(msg, unlock)
    local uid     = math.floor(msg.uid)
    local ret = {c=msg.c, uid=msg.uid, code=PDEFINE.RET.SUCCESS}
    local user  = self.deskInfo:findUserByUid(uid)
    if user and user.cluster_info then  --玩家离开 必须存在房间中

        -- 比赛房，退出房间直接算淘汰，算放弃
        if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
            user.isexit = 1
            user.auto = 1
            pcall(cluster.send, "master", ".tournamentmgr", "exitRoom", uid, self.deskInfo.deskid, self.deskInfo.conf.tn_id)
            if self.deskInfo.state == PDEFINE.DESK_STATE.WaitStart then
                self.deskInfo:userExit(user.uid)
            else
                self.deskInfo:autoMsgNotify(user, 1)
            end
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", self.gameid, self.deskInfo.deskid) --释放桌子对象
            return
        end

        if self.deskInfo:isMatchState() then
            local seatid = user.seatid
            -- 退出房间
            self.deskInfo:userExit(uid)
            -- 停止踢人定时器
            self.deskInfo:stopAutoKickOut()
        else
            -- 部分游戏不允许中途退出
            if self.deskInfo:canNotExitInPlaying() and not unlock then
                ret.spcode = PDEFINE.RET.ERROR.DESK_STATE_ERROR
                return ret
            end
            user.isexit = 1
            user.auto = 1

            if unlock then
                --通知前端删除，但后端并不真正删除（结算时还需要，这里有待优化）
                local exitNotifyMsg = { c=PDEFINE.NOTIFY.PLAYER_EXIT_ROOM, code = PDEFINE.RET.SUCCESS, uid = uid, seatid = user.seatid, spcode = 0}
                self.deskInfo:broadcast(cjson.encode(exitNotifyMsg))
            end
        end
        user.auto = 1
        self.deskInfo:autoMsgNotify(user, 1)
        pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", self.gameid, self.deskInfo.deskid) --释放桌子对象

        if unlock then
            pcall(cluster.send, "master", ".mgrdesk", "unlockPlayer", self.deskInfo.deskid, {uid}, self.gameid, self.deskInfo.conf.roomtype)
            if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
                pcall(cluster.send, "master", ".mgrdesk", "markDesk", uid, self.deskInfo.deskid)
            end
        end

    end
    local viewer = self.deskInfo:findViewUser(uid)
    if viewer then
        -- 比赛房，退出房间直接算淘汰，算放弃
        if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
            pcall(cluster.send, "master", ".tournamentmgr", "exitRoom", uid, self.deskInfo.deskid, self.deskInfo.conf.tn_id)
        end
        self.deskInfo:viewExit(uid)
        pcall(cluster.send, viewer.cluster_info.server, viewer.cluster_info.address, "deskBack", self.gameid, self.deskInfo.deskid) --释放桌子对象
        -- 通知mgrdesk, 短时间内不能再分配这个房间
        if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
            pcall(cluster.send, "master", ".mgrdesk", "markDesk", uid, self.deskInfo.deskid)
        end
    end
    return ret
end

function Agent:switchDesk(msg)
    if self.deskInfo.conf.roomtype ~= PDEFINE.BAL_ROOM_TYPE.MATCH then
        return 2    --匹配房才能换
    end
    local uid = math.sfloor(msg.uid)
    local user = self.deskInfo:findUserByUid(uid)
    local minCoin = self.deskInfo.conf.mincoin
    if user and user.coin < minCoin then
        return 4     --金币不足
    end
    if user and user.cluster_info and user.isexit == 0 then
        user.isexit = 1
        if self.deskInfo.state == PDEFINE.DESK_STATE.MATCH or (self.deskInfo:isDirectPlayGame() and user.state == PDEFINE.PLAYER_STATE.Wait) then
            -- 退出房间
            self.deskInfo:userExit(user.uid, PDEFINE.RET.ERROR.SWITCH_DESK)
            -- 停止踢人定时器
            self.deskInfo:stopAutoKickOut()
        else
            user.auto = 1
            self.deskInfo:autoMsgNotify(user, 1)
        end
        pcall(cluster.send, "master", ".mgrdesk", "unlockPlayer", self.deskInfo.deskid, {uid}, self.gameid, self.deskInfo.conf.roomtype)
    else
        user = self.deskInfo:findViewUser(uid)
        if user then
            self.deskInfo:viewExit(uid)
        end
    end
    if user then
        pcall(cluster.send, "master", ".mgrdesk", "markDesk", uid, self.deskInfo.deskid) --标记为暂不分配该桌子
        local server = user.cluster_info.server
        local address = user.cluster_info.address
        skynet.timeout(50, function()
            pcall(cluster.send, server, address, "deskSwitch", self.gameid, self.deskInfo.ssid) --交换桌子
        end)
        return 0    --切换成功
    end
    return 3  --不在房间内
end

-- 观战期间坐下
function Agent:seatDown(msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local seatid = math.floor(recvobj.seatid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.seatid = seatid
    retobj.spcode = 0
    local viewer = self.deskInfo:findViewUser(uid)
    if not viewer then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return resp(retobj)
    end
    -- 先判断金币是否足够
    -- 判断金币是否足够
    if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        if viewer.coin < self.deskInfo.conf.mincoin then
            retobj.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
            return resp(retobj)
        end
    else
        if not self.deskInfo:isCoinEnough(viewer.coin) then
            retobj.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
            return resp(retobj)
        end
    end
    if not table.contain(self.deskInfo.seatList, seatid) then
        retobj.spcode = PDEFINE.RET.ERROR.ERROR_SEAT_EXISTS_USER
        return resp(retobj)
    end
    -- 回收现在的位置
    if viewer.seatid > 0 then
        self.deskInfo:recycleSeatId(viewer.seatid)
    end
    -- 锁定当前位置
    self.deskInfo:lockSeatid(seatid)
    -- 如果是匹配阶段，则直接坐下
    -- 否则锁定座位号到观战者身上
    viewer.seatid = seatid
    if self.deskInfo.state == PDEFINE.DESK_STATE.MATCH or self.deskInfo.state == PDEFINE.DESK_STATE.READY then
        self.deskInfo:removeViewUser(uid)
        self.deskInfo:insertUser(viewer, true)
        -- 如果是匹配阶段，则直接准备
        skynet.timeout(50, function()
            self.deskInfo:userReady(uid)
            if self.deskInfo:isJoinAi() then
                self.deskInfo:autoStartGame()
            end
        end)
    end
    -- 告诉master有人坐下了
    -- 这里放到后面，不然会被删除
    -- viewerSeat
    pcall(cluster.send, "master", ".balprivateroommgr", "viewerSeat", self.deskInfo.deskid, self.deskInfo.gameid, {
        uid = uid,
        playername=viewer.playername,
        usericon = viewer.usericon,
        seatid = viewer.seatid
    })
    
    local notify_object = {}
    notify_object.c = PDEFINE.NOTIFY.PLAYER_SEAT_DOWN
    notify_object.uid = uid
    notify_object.seatid = seatid
    notify_object.code = PDEFINE.RET.SUCCESS
    self.deskInfo:broadcast(cjson.encode(notify_object))
    skynet.timeout(20, function()
        -- 广播语聊状态
        self.deskInfo:updateMicStatus()
    end)
    return resp(retobj)
end

-- 发起解散
function Agent:applyDismiss(msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local user = self.deskInfo:findUserByUid(uid)

    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.delayTime = self.deskInfo.delayTime
    -- 已经不在房间中
    if not user then
        LOG_DEBUG("agent:applyDismiss not found user")
        retobj.spcode = PDEFINE.RET.ERROR.NOT_IN_ROOM
        return retobj
    end
    LOG_DEBUG("applyDismiss", self.deskInfo.state)
    -- 如果还没有开局，则不需要解散
    if self.deskInfo.state == PDEFINE.DESK_STATE.MATCH 
    or self.deskInfo.state == PDEFINE.DESK_STATE.SETTLE 
    or self.deskInfo.state == PDEFINE.DESK_STATE.READY then
        LOG_DEBUG("agent:applyDismiss DESK_STATE error")
        retobj.spcode = PDEFINE.RET.ERROR.GAME_NOT_SART
        return retobj
    end

    -- 如果已经有人发起解散，则这个解散无效
    if self.deskInfo.dismiss then
        retobj.spcode = PDEFINE.RET.ERROR.GAME_ALREADY_DELTE
        LOG_DEBUG("agent:applyDismiss PDEFINE.RET.ERROR.GAME_ALREADY_DELTE error")
        return retobj
    end

    self.deskInfo.dismiss = {
        uid = uid,  -- 发起人
        users = {},  -- 其他人信息以及是否同意
        expireTime = os.time()+PDEFINE.GAME.DISMISS_DELAY_TIME,  -- 解散倒计时时长
        _autoFunc = nil,
    }

    for _, user in ipairs(self.deskInfo.users) do
        if user.uid ~= uid then
            table.insert(self.deskInfo.dismiss.users, {uid=user.uid, status=0})
        else
            table.insert(self.deskInfo.dismiss.users, {uid=user.uid, status=1})
        end
    end
    local gameid = self.gameid
    self.deskInfo.dismiss._autoFunc = self.deskInfo:setTimeout(PDEFINE.GAME.DISMISS_DELAY_TIME*100, function()
        -- 记录到数据库
        self.deskInfo:recodeDismissInfo(PDEFINE.GAME.DISMISS_STATUS.Timeout, uid)
        -- if gameid == PDEFINE_GAME.GAME_TYPE.DOMINO
        -- or gameid == PDEFINE_GAME.GAME_TYPE.LUDO then
        --     self.func.roundOver(true)
        -- else
        --     self.func.gameOver(true)
        -- end

        local notify_object = {
            c = PDEFINE.NOTIFY.GAME_DISMISS_TIMEOUT,
            code = PDEFINE.RET.SUCCESS,
            dismiss = {
                uid = self.deskInfo.dismiss.uid,  -- 发起人
                users = self.deskInfo.dismiss.users,  -- 其他人信息以及是否同意
                delayTime = 0  -- 解散时间
            },
        }
        self.deskInfo:broadcast(cjson.encode(notify_object))
        -- 超时
        if self.deskInfo.dismiss then
            self.deskInfo.dismiss._autoFunc()
        end
        self.deskInfo.dismiss = nil

        -- 恢复用户身上的定时器
        self.deskInfo:recoverTimer()
    end)

    -- 机器人自动同意
    skynet.timeout(100, function ()
        for _, u in ipairs(self.deskInfo.users) do
            if not u.cluster_info then
                self:replyDismiss({uid=u.uid,rtype=1})
            end
        end
    end)

    -- 暂停玩家身上的定时器
    self.deskInfo:pauseTimer()

    -- 记录到数据库
    self.deskInfo:recodeDismissInfo(PDEFINE.GAME.DISMISS_STATUS.Waiting, uid)

    retobj.dismiss = {
        uid = uid,  -- 发起人
        users = self.deskInfo.dismiss.users,  -- 其他人信息以及是否同意
        delayTime = self.deskInfo.dismiss.expireTime-os.time(),  -- 解散时间
    }

    -- 广播消息给其他玩家
    local notify_object = {
        c = PDEFINE.NOTIFY.PLAYER_APPLY_DISMISS,
        code = PDEFINE.RET.SUCCESS,
        dismiss = retobj.dismiss
    }
    self.deskInfo:broadcast(cjson.encode(notify_object), uid)

    LOG_DEBUG("agent:applyDismiss return:", retobj)
    return retobj
end

-- 同意/拒绝 解散房间
function Agent:replyDismiss(msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local rtype = math.floor(recvobj.rtype or 2)  -- 默认不同意, 1: 同意，2: 不同意
    local user = self.deskInfo:findUserByUid(uid)

    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.code   = PDEFINE.RET.SUCCESS

    -- 已经不在房间中
    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return retobj
    end

    -- 没人发起解散
    if not self.deskInfo.dismiss then
        retobj.spcode = PDEFINE.RET.ERROR.ACTION_ERROR
        return retobj
    end
    local allAgree = true
    for _, user in ipairs(self.deskInfo.dismiss.users) do
        if user.uid == uid then
            user.status = rtype
        end
        -- 只要有一个人还没有选择，则就不能解散房间
        if user.status ~= 1 then
            allAgree = false
        end
    end

    local notify_object = {
        c = PDEFINE.NOTIFY.PLAYER_REPLY_DISMISS,
        code = PDEFINE.RET.SUCCESS,
        uid = uid,
        rtype = rtype,
        dismiss = {
            uid = self.deskInfo.dismiss.uid,  -- 发起人
            users = self.deskInfo.dismiss.users,  -- 其他人信息以及是否同意
            delayTime = self.deskInfo.dismiss.expireTime-os.time()  -- 解散时间
        },
    }
    self.deskInfo:broadcast(cjson.encode(notify_object))

    if rtype == 1 then
        -- 同意， 判断所有人是否同意，同意则解散房间
        if allAgree then
            -- 记录到数据库
            self.deskInfo:recodeDismissInfo(PDEFINE.GAME.DISMISS_STATUS.Agree, self.deskInfo.dismiss.uid)
            self.deskInfo.dismiss._autoFunc()
            self.deskInfo.dismiss = nil
            if self.gameid == PDEFINE.GAME_TYPE.DOMINO 
            or self.gameid == PDEFINE.GAME_TYPE.LUDO 
            or self.gameid == PDEFINE.GAME_TYPE.LUDO_QUICK then
                self.func.roundOver(true)
            else
                self.func.gameOver(true)
            end
        end
    else
        -- 记录到数据库
        self.deskInfo:recodeDismissInfo(PDEFINE.GAME.DISMISS_STATUS.Refuse, self.deskInfo.dismiss.uid)
        -- 不同意
        self.deskInfo.dismiss._autoFunc()
        self.deskInfo.dismiss = nil

        -- 恢复用户身上的定时器
        self.deskInfo:recoverTimer()
    end
    return retobj
end

-- 小局结算
function Agent:roundOver(...)
    self.deskInfo:roundOver(...)
    if self.func and self.func.roundOver then
        self.func.roundOver(...)
    end
end

-- 大局结算
function Agent:gameOver(...)
    self.func.gameOver(...)
end

-- 更新某个用户信息,并且广播
function Agent:updateUserInfo(uid)
    LOG_DEBUG("updateUserInfo", "uid:", uid)
    if self.deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
        return
    end
    local exist_user = self.deskInfo:findUserByUid(uid)
    if exist_user and exist_user.cluster_info then
        local ok, playerInfo = pcall(cluster.call, exist_user.cluster_info.server, exist_user.cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid)
        if ok and playerInfo then
            self.deskInfo:syncUserInfo(exist_user, playerInfo)
            self.deskInfo:broadcastPlayerInfo(exist_user)
        end
    end
end

-- 更改用户麦克风状态
function Agent:updateUserMic(msg)
    local uid = msg.uid
    local mic = msg.mic  -- 0 关, 1 开, 2 开但是不加入语聊
    local user = self.deskInfo:findUserByUid(uid)
    local retobj = {c=msg.c, code=PDEFINE.RET.SUCCESS, spcode=0, uid=uid, mic=mic}
    if not user then
        user = self.deskInfo:findViewUser(uid)
    end
    if not user or not user.seatid or user.seatid <= 0 then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return resp(retobj)
    end
    if mic ~= 0 and mic ~= 1 then
        retobj.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return resp(retobj)
    end
    -- 做下判断，只有两个人都开启的情况下，才切换到1状态，其他时候改成2状态
    user.mic = mic
    self.deskInfo:updateMicStatus()
    return resp(retobj)
end

-- 通知用户比赛结束
function Agent:updateRaceStatus(msg)
    local uid = msg.uid
    local race_id = msg.race_id
    local status = msg.status
    local user = self.deskInfo:findUserByUid(uid)
    if not user or user.race_id ~= race_id then
        return PDEFINE.RET.SUCCESS
    end
    local notifyObj = {c=PDEFINE.NOTIFY.NOTIFY_RACE_END, code=PDEFINE.RET.SUCCESS, uid=uid,spcode=0}
    table.merge(notifyObj, msg)
    pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(notifyObj))
    user.race_id = 0
    user.race_type = nil
    return PDEFINE.RET.SUCCESS
end

return Agent
