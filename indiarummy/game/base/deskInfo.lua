--[[
    桌子基类
]]

local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
local date = require "date"
local player_tool = require "base.player_tool"
local baseRecord = require "base.record"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
-- local player_tool = require "base.player_tool"
local DEBUG = skynet.getenv("DEBUG")
local baseUser  = require "base.user"

local AutoReadyTimeout = 11  -- 自动准备时间，需要加上大结算播放特效时间
local FirstReadyTimeout = 14  -- 第一次进房间自动准备时间，包括过场动画4秒
local AutoStartTimeout = 8  -- 沙龙房结算之后的开始时间，比匹配房多一点
local SettleAnimalTimeout = 5  -- 前端大结算动画时间
local MatchAutoStartTimeout = 6  -- 匹配方自动开始下一局的时间
local MatchWaitTimeout = 10  -- 匹配等待时间
local TournamentWaitTimeout = 3  -- 锦标赛第二局等待时间

---@type BaseDeskInfo
local DeskInfo = {}
DeskInfo.__index = DeskInfo

setmetatable(DeskInfo, {
    __call = function (cls, ...)
        return cls.new(...)
    end
})

local function ai_set_timeout(ti, f)
    local function t()
        if f then
            f()
        end
    end
    skynet.timeout(ti, t)
    return function() f=nil end
end

---@class Settle
---@field league integer[]  排位经验
---@field coins integer[]  结算的金币
---@field taxes integer[]  税收
---@field scores integer[]  获得的分数
---@field levelexps integer[]  经验值
---@field rps integer[]  rp 值
---@field fcoins integer[]  最终的金币

---@class SettledByGame
---@field settlewin integer[] 游戏内已结算输赢分数
---@field betcoin integer[] 游戏内已计算押注金币
---@field wincoin integer[] 游戏内已结算输赢金币
---@field tax integer[] 税收

---@class DeskInfoFunc
---@field initDeskRound function 清理桌子轮次信息
---@field initUserRound function 清理用户轮次信息
---@field resetDesk function 清理桌子信息，方便不解散继续玩

-- 创建新的游戏
---@return BaseDeskInfo
function DeskInfo.new(name, gameid, deskid)
    ---@class BaseDeskInfo
    local desk = setmetatable({}, DeskInfo)
    desk.name = name  -- 桌子名称
    desk.cid = nil  -- 俱乐部id
    desk.gameid = gameid  -- 游戏gameid
    desk.deskid = deskid  -- 房间号
    desk.uuid = nil  -- 当前桌子uuid
    desk.state = nil  -- 桌子状态
    desk.bet = 1    -- 下注底注
    desk.ssid = nil  -- 对应匹配的ssid
    desk.curround = 0  -- 当前第几轮
    desk.maxRound = 1  -- 最大轮数
    desk.seat = nil  -- 默认人数
    desk.curseat = 0  -- 当前人数
    desk.seatList = {}  -- 可用座位id
    desk.delayTime = 8  -- 默认延迟时间为15秒
    desk.owner = nil  -- 房主uid
    desk.conf = nil  -- 房间配置信息
    desk.taxrate = PDEFINE_GAME.NUMBER.settleCharge  --税率
    desk.issue = nil  --投注期号
    desk.no = 0       --流水号
    ---@type BaseUser[]
    desk.users = {}  -- 玩家对象
    desk.views = {}  -- 观战的人
    desk.maxView = PDEFINE_GAME.MAX_VIEW_NUM  -- 最大观战人数
    desk.round = {}  -- 牌局信息
    desk.isDestroy = false  -- 是否回收中
    ---@type DeskInfoFunc
    desk.func = {}  -- 自定义方法
    
    desk.dismiss = nil  -- 解散相关信息
    desk.autoFuc = {}  -- 自动操作函数
    desk.aiAutoFuc = nil  -- 自动加机器人函数
    desk.autoStartInfo = {}  -- 自动开始函数
    desk.autoRecycleInfo = {}  -- 自动解散函数
    desk.autoKickOutInfo = {}  -- 自动踢人函数
    desk.matchWaitInfo = {}  -- 匹配等待信息
    desk.preWinners = {} --上一把赢的人
    desk.startTimestamp = nil  -- 游戏开始时间戳
    desk.maxScore = nil  -- 部分游戏有这个字段，用来判断大结算条件，没有则默认1局
    desk.randSeat = nil  -- 随机座位数
    desk.private = { --桌子私有信息保存在这里（不会发给前端）
        aijoin = 1, --是否加机器人
    }
    return desk
end

-- 初始化桌子信息
function DeskInfo:init(uid,msg)
    local conf = msg.conf or {}
    local cid = msg.cid  -- 俱乐部id
    if cid then
        cid = math.floor(cid)
        self.cid = cid
    end
    self.conf = conf
    self.owner = uid
    self.ssid = msg.ssid
    self.openleadboard = msg.openleadboard or 0
    if msg.taxrate then
        self.taxrate = msg.taxrate
    end
    if msg.aijoin then
        self.private.aijoin = msg.aijoin
    end
    -- 设置人数, 默认4人，如果配置中有，则使用配置中的人数
    if not self.seat then
        if self.conf.seat then
            self.seat = self.conf.seat
        else
            self.seat = 4
        end
    end
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        self.bet = conf.entry
        if PDEFINE_GAME.DEFAULT_MATCH_CONF[self.gameid] then
            self.delayTime = PDEFINE_GAME.DEFAULT_MATCH_CONF[self.gameid].turntime
            self.minSeat = PDEFINE_GAME.DEFAULT_MATCH_CONF[self.gameid].minSeat
        end
    elseif self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        self.bet = self.conf.entry
    elseif self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
        self.bet = self.conf.entry
    end
    if not self.minSeat then
        self.minSeat = PDEFINE_GAME.DEFAULT_CONF[self.gameid].minSeat
    end
    -- 初始化状态为匹配状态
    self.state = PDEFINE.DESK_STATE.MATCH
    -- 记录创房时间
    self.conf.create_time = os.time()
    -- 设置定时器延迟时间
    if self.conf.turntime and self.conf.turntime > 0 then
        self.delayTime = self.conf.turntime
    end
    -- 设置局数
    if conf.round then
        self.maxRound = conf.round
    end
    -- 最低开始座位数
    if self.conf.minSeat then
        self.minSeat = tonumber(self.conf.minSeat)
    end
    -- 结算分数
    if self.conf.maxScore then
        self.maxScore = tonumber(self.conf.maxScore)
    end
    -- 根据座位数初始化可用座位id列表
    if not self.func.assignSeat then
        -- 调整座位，1,3,2,4 这样坐下的顺序
        for i = 1, self.seat, 2 do
            table.insert(self.seatList, 1, i)
        end
        for i = 2, self.seat, 2 do
            table.insert(self.seatList, 1, i)
        end
    end
    -- 是否打开777
    self.open777 = isOpen777(self.gameid)
    -- 设置随机座位
    self.randSeat = self:getRandSeat()
    self:setUuid()
    self:newIssue()
end

-- 设置桌子uuid
function DeskInfo:setUuid()
    self.uuid = self.deskid .. os.time()
end

---生成投注期号
function DeskInfo:newIssue()
    local shortname = PDEFINE.GAME_SHORT_NAME[self.gameid] or 'XX'
    local osdate = os.date("%y%m%d")
    self.no = self.no + 1
    local number = string.format("%04d", self.no%10000)
    self.issue = shortname..osdate..(self.deskid)..number
end

-- 获取座位号
function DeskInfo:getSeatId()
    return table.remove(self.seatList)
end

-- 将空闲的座位号塞入可用列表
function DeskInfo:recycleSeatId(seatid)
    if not table.contain(self.seatList, seatid) then
        table.insert(self.seatList, seatid)
    end
end

-- 判断是否需要加机器人
function DeskInfo:isJoinAi()
    -- domino是个例外
    if not PDEFINE_GAME.AUTO_JOIN_ROBOT then
        return false
    end
    if self.conf.roomtype ~= PDEFINE.BAL_ROOM_TYPE.PRIVATE then
		return false
	end
    if not self.conf.pwd or self.conf.pwd == "" then
        return true
    end
    return false
end

-- 打印消息
function DeskInfo:print(...)
    LOG_DEBUG(self.uuid , ' => ', self.deskid, ...)
end

-- 打印机器人错误信息
function DeskInfo:checkMsg(user, resp)
    if resp and resp.spcode and resp.spcode > 0 then
        if user and user.round and user.round.cards then
            LOG_DEBUG("自动操作错误: cards:", user.round.cards, "resp", resp)
        end
    end
end

-- 确定奖金
function DeskInfo:confirmPrize()
    local userCnt = #self.users
    self.prize = userCnt * self.bet * (1-self.taxrate)
    self.prize = math.round_coin(self.prize)
    if self:isCoinGame() then
        self.prize = 0
    end
end

-- 判断状态是否是match ready 等状态
function DeskInfo:isMatchState()
    if self.state == PDEFINE.DESK_STATE.MATCH or self.state == PDEFINE.DESK_STATE.READY or self.state == PDEFINE.DESK_STATE.WaitStart then
        return true
    end
    return false
end

-- 判断是否不允许中途退出
function DeskInfo:canNotExitInPlaying()
    if self.gameid == PDEFINE_GAME.GAME_TYPE.DOMINO
    or self.gameid == PDEFINE_GAME.GAME_TYPE.UNO
    or self.gameid == PDEFINE_GAME.GAME_TYPE.INDIA_RUMMY then
        return true
    end
    return false
end

-- 暂停玩家定时器
function DeskInfo:pauseTimer()
    for _, user in ipairs(self.users) do
        user:pauseTimer()
    end
end

-- 重启玩家身上的定时器
function DeskInfo:recoverTimer()
    for _, user in ipairs(self.users) do
        user:recoverTimer()
    end
end

-- 设置定时器
function DeskInfo:setTimeout(ti, f, uid)
    local function t()
        if f then
            f()
        end
    end
    skynet.timeout(ti, t)
    return function(parme) f=nil end
end

-- 设置开局等待计时器
function DeskInfo:setWaitTime(delayTime)
    if not delayTime then
        delayTime = MatchWaitTimeout + 2
    end
    if self.matchWaitInfo.func then
        self.matchWaitInfo.func()
    end
    self.matchWaitInfo.startTime = os.time() + delayTime
    -- 等待时间的二分之一开始
    self.matchWaitInfo.func = ai_set_timeout(10, function ()
        self:setAiAutoJoin()
    end)
    ai_set_timeout(delayTime*100, function()
        local minSeat = self:getMinSeat()
        local currCnt = self:getUserCnt()
        if self.gameid == PDEFINE.GAME_TYPE.KOUTBO then
            if currCnt > 4 then
                minSeat = 6
            end
        end
        if currCnt >= minSeat then
            self.func.startGame()
        else
            self:setAiAutoJoin(true)
        end
    end)
end

-- 剔除所有人
function DeskInfo:killViews()
    LOG_DEBUG("killViews")
    local uids = {}
    for _, user in ipairs(self.views) do
        table.insert(uids, user.uid)
    end
    for _, uid in ipairs(uids) do
        self:viewExit(uid)
    end
end

-- 设置自动解散
function DeskInfo:setAutoRecycle()
    if self.autoRecycleInfo.func then
        self.autoRecycleInfo.func()
    end
    local delayTime = PDEFINE_GAME.AUTO_DISMISS_TIME
    -- 如果是特殊房间，则10分钟才解散
    if self.conf.spcial and self.conf.spcial == 1 then
        delayTime = delayTime * 2
    end
    self.autoRecycleInfo.func = self:setTimeout(delayTime*100, function()
        local notify_retobj = { c=PDEFINE.NOTIFY.GAME_DISMISS_ROOM, code = PDEFINE.RET.SUCCESS, deskid=self.deskid }
        self:broadcast(cjson.encode(notify_retobj))
        self:destroy()
    end)
    self.autoRecycleInfo.resetTime = os.time() + delayTime
end

-- 有人加入的时候暂停回收房间
function DeskInfo:stopAutoRecycle()
    if self.autoRecycleInfo.func then
        self.autoRecycleInfo.func()
        self.autoRecycleInfo = {}
    end
end

-- 设置自动解散
function DeskInfo:setAutoKickOut()
    if self.autoKickOutInfo.func then
        self.autoKickOutInfo.func()
    end
    local delayTime = PDEFINE_GAME.AUTO_KICK_OUT_TIME
    self.autoKickOutInfo.func = self:setTimeout(delayTime*100, function()
        if self.state == PDEFINE.DESK_STATE.MATCH then
            local tmpUsers = {}
            for _, u in ipairs(self.users) do
                table.insert(tmpUsers, u)
            end
            for _, u in ipairs(tmpUsers) do
                if self.state == PDEFINE.DESK_STATE.MATCH and u.state ~= PDEFINE.PLAYER_STATE.Ready then
                    -- 此项目不踢人，直接帮忙准备
                    self:userReady(u.uid)
                    -- self:userExit(u.uid, PDEFINE.RET.ERROR.TIMEOUT_KICK_OUT)
                    -- if u and u.cluster_info then
                    --     local ok = pcall(cluster.call, u.cluster_info.server, u.cluster_info.address, "deskBack", self.gameid, self.deskid) --释放桌子对象
                    --     -- 如果调用不成功，则直接删除master上的记录
                    --     if not ok then
                    --         pcall(cluster.send, "master", ".agentdesk", "removeDesk", u.uid, self.deskid)
                    --     end
                    -- end
                end
            end
        end
    end)
    self.autoKickOutInfo.resetTime = os.time() + delayTime
end

-- 有人退出的时候暂停踢人操作
function DeskInfo:stopAutoKickOut()
    if self.autoKickOutInfo.func then
        self.autoKickOutInfo.func()
        self.autoKickOutInfo = {}
    end
end

-- 判断是否是coinGame,这种房间，可以一直玩，而且可以中途加入
function DeskInfo:isCoinGame()
    if self.gameid == PDEFINE.GAME_TYPE.TEENPATTI or self.gameid == PDEFINE.GAME_TYPE.TEXAS_HOLDEM then
        return true
    end
    return false
end

-- 判断是否是比赛房，锦标赛的房间
function DeskInfo:isTNGame()
    return self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT
end

-- 广播下一个人
function DeskInfo:broadcastNextUser(user, delayTime, extra)
    local notify_object = {}
    notify_object.c = PDEFINE.NOTIFY.PLAYER_TURN_TO
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.spcode = 0
    notify_object.nextUid = user.uid
    notify_object.nextState = user.state
    notify_object.coin = user.coin
    notify_object.delayTime = delayTime
    if extra then
        table.merge(notify_object, extra)
    end

    self:broadcast(cjson.encode(notify_object))
end

-- 广播消息
function DeskInfo:broadcast(retobj, uid)
    if self.users ~= nil then
        if not uid then
            for _, muser in pairs(self.users) do
                if  muser.cluster_info and muser.isexit == 0 then
                    pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", retobj)
                end
            end
        else
            for _, muser in pairs(self.users) do
                if muser.uid ~= uid then
                    if  muser.cluster_info and muser.isexit == 0 then
                        pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", retobj)
                    end
                end
            end
        end
    end
    for _, muser in ipairs(self.views) do
        if muser.cluster_info then
            pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", retobj)
        end
    end
end

-- 单独广播给观看者
function DeskInfo:broadcastViewer(retobj)
    for _, muser in ipairs(self.views) do
        if muser.cluster_info then
            pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", retobj)
        end
    end
end

-- 广播用户更新信息
function DeskInfo:broadcastPlayerInfo(user)
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
    notify_object.diamond = user.diamond
    notify_object.playername = user.playername
    notify_object.usericon = user.usericon
    notify_object.charm = user.charm
    notify_object.avatarframe = user.avatarframe
    notify_object.chatskin = user.chatskin
    notify_object.tableskin = user.tableskin
    notify_object.pokerskin = user.pokerskin
    notify_object.frontskin = user.frontskin
    notify_object.emojiskin = user.emojiskin
    notify_object.faceskin = user.faceskin
    self:broadcast(cjson.encode(notify_object), user.uid)
end

-- 更新某个用户信息
function DeskInfo:syncUserInfo(exist_user, playerInfo)
	exist_user.svip = playerInfo.svip or 0
	exist_user.svipexp = playerInfo.svipexp or 0
	exist_user.rp = playerInfo.rp or 0
	exist_user.level = playerInfo.level or 1
	exist_user.levelexp = playerInfo.levelexp or 0
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
        exist_user.realCoin = playerInfo.coin or 0
    else
        exist_user.coin = playerInfo.coin or 0
    end
    exist_user.diamond = playerInfo.diamond or 0
	exist_user.playername = playerInfo.playername
	exist_user.usericon     = playerInfo.usericon
	exist_user.charm = playerInfo.charm or 0
	exist_user.avatarframe = playerInfo.avatarframe
	exist_user.chatskin = playerInfo.chatskin
	exist_user.tableskin = playerInfo.tableskin
	exist_user.pokerskin = playerInfo.pokerskin
	exist_user.frontskin = playerInfo.frontskin
	exist_user.emojiskin = playerInfo.emojiskin
	exist_user.faceskin = playerInfo.faceskin
end

-- 房间内是否还有真人
function DeskInfo:hasRealPlayer()
    local hasPlayer = false
    for _, u in ipairs(self.users) do
        if u.cluster_info then
            hasPlayer = true
        end
        -- 特殊房间，只要房主在，不管是不是真人
        if self.conf.spcial == 1 and u.uid == self.owner then
            hasPlayer = true
        end
    end
    return hasPlayer
end

-- 是否含有观战玩家
function DeskInfo:hasViews()
    -- 观战玩家，也算真实用户
    if #self.views > 0 then
        return true
    end
    return false
end

-- 检测是否可以开始游戏
function DeskInfo:checkCanStart()
    if self.conf.roomtype ~= PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        return 0
    end
    local can_start = 1
    for _, user in ipairs(self.users) do
        if user.state ~= PDEFINE.PLAYER_STATE.Ready then
            can_start = 0
            break
        end
    end
    -- 如果人数少于最小人数，或者没有最小人数这个参数，则不能开始
    if not self.minSeat or self:getUserCnt() < self.minSeat then
        can_start = 0
    end
    -- 如果是分队玩法，则需要是双数人数
    if self.gameid == PDEFINE_GAME.GAME_TYPE.KOUTBO or self.gameid == PDEFINE_GAME.GAME_TYPE.LUDO then
        if self:getUserCnt() % 2 == 1 then
            can_start = 0
        end
    end

    return can_start
end

-- 检测金币是否已经达到危险值
function DeskInfo:checkDangerCoin(user)
    if not user.cluster_info or user.isexit == 1 then
        return
    end
    local dangerUids = {}
    -- 好友房和匹配房踢人的门槛不同，所以分开判断
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        local mult = PDEFINE_GAME.DANGER_BET_MULT-1
        if self.gameid == PDEFINE_GAME.GAME_TYPE.DOMINO then
            mult = mult + 2
        end
        if user.coin - self.conf.mincoin < (mult-1)*self.bet then
            table.insert(dangerUids, user.uid)
        end
    else
        local mult = PDEFINE_GAME.DANGER_BET_MULT
        if self.gameid == PDEFINE_GAME.GAME_TYPE.DOMINO then
            mult = mult + 2
        end
        if user.coin < mult*self.bet then
            table.insert(dangerUids, user.uid)
        end
    end
    if #dangerUids > 0 then
        local notify_object = {}
        notify_object.c = PDEFINE.NOTIFY.PLAYER_DANGER_COIN
        notify_object.code = PDEFINE.RET.SUCCESS
        notify_object.dangerUids = dangerUids
        pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(notify_object))
    end
end

-- 回收桌子
function DeskInfo:destroy(isDismiss)
    if not isDismiss then
        self.isDestroy = true
    end
    for _,user in pairs(self.users) do
        -- 将机器人回收
        if not user.cluster_info then
            pcall(cluster.send, "ai", ".aiuser", "recycleAi", user.uid, user.score, os.time()+10, self.deskid)
        end
    end
    if not isDismiss then
        pcall(cluster.send, "master", ".userCenter", "updateRoomStatusInChat", self.deskid, self.gameid, self.cid)
        skynet.send(".dsmgr", "lua", "recycleAgent", skynet.self(), self.deskid, self.gameid)
    end
    local uids = {}
    for _, user in ipairs(self.users) do
        if user.cluster_info then
            table.insert(uids, user.uid)
        end
    end
    -- 通知解锁玩家
    pcall(cluster.send, "master", ".mgrdesk", "unlockPlayer", self.deskid, uids, self.gameid, self.conf.roomtype)
    -- 通知私人房管理服，房间已经解散
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE and not isDismiss then
        pcall(cluster.send, "master", ".balprivateroommgr", "removeRoom", self.deskid, self.gameid)
    end
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE and isDismiss then
        self:resetDesk(nil, true)
        LOG_DEBUG("不需要解散房间, 继续游戏:", self.deskid)
    end
end

-- 处理用户退出
---@param isSitup boolean 是否是站起来
function DeskInfo:userExit(uid,spcode, isSitup)
    ---@type BaseUser
    local user = self:findUserByUid(uid)
    if not user then
        return
    end
    -- 退出时，处理身上的定时器
    if user then
        user:clearTimer()
    end
    if not user.cluster_info then
        self:RecycleAi(user)
    end
    LOG_DEBUG("userExit uid:", user.uid, "spcode:", spcode)
    local exitNotifyMsg = { c=PDEFINE.NOTIFY.PLAYER_EXIT_ROOM, code = PDEFINE.RET.SUCCESS, uid = uid, seatid = user.seatid, spcode = spcode}
    if isSitup then
        exitNotifyMsg.c = PDEFINE.NOTIFY.PLAYER_SIT_UP
    end
    self:broadcast(cjson.encode(exitNotifyMsg))
    self.curseat = self.curseat - 1
    -- 回收座位号
    self:recycleSeatId(user.seatid)
    -- 从桌子列表中删除玩家
    -- 不能提前删除，因为会造成广播失败
    for i, u in ipairs(self.users) do
        if u.uid == uid then
            table.remove(self.users, i)
            break
        end
    end
    self:updateMicStatus()
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
		pcall(cluster.send, "master", ".balprivateroommgr", "exitRoom", self.deskid, self.gameid, uid)
        -- 加机器人的房间，退出房间在另外一个地方判断(每次resetDesk都会加入机器人倒计时)
        if not self:isJoinAi() then
            -- 判断下房间人数，如果符合最低要求则直接开始
            local can_start = self:checkCanStart()
            if can_start == 1 then
                self.func.startGame()
            end
        else
            -- 有人退出，则立即检测是否可以开始，或者继续加一个机器人
            self:autoStartGame(true)
        end
        -- 房间没人则开启倒计时解散
        if self:getUserCnt() == 0 then
            self:setAutoRecycle()
        end
	end
    local userCnt = self:getUserCnt()
    local realUserCnt = self:getRealUserCnt()
    pcall(cluster.send, "master", ".mgrdesk", "changDeskSeat", self.name, self.gameid, self.deskid, userCnt, realUserCnt)
end

-- 处理观战人退出
function DeskInfo:viewExit(uid)
    local user
    for i, u in ipairs(self.views) do
        if u.uid == uid then
            user = u
            break
        end
    end
    if user then
        -- 回收座位号
        if user.seatid > 0 then
            self:recycleSeatId(user.seatid)
        end
        local exitNotifyMsg = { c=PDEFINE.NOTIFY.PLAYER_VIEWER_EXIT_ROOM, code = PDEFINE.RET.SUCCESS, uid = uid, seatid = user.seatid, spcode = 0}
        self:broadcast(cjson.encode(exitNotifyMsg))
        -- 不能提前删除，因为会造成广播失败
        for i, u in ipairs(self.views) do
            if u.uid == uid then
                table.remove(self.views, i)
                break
            end
        end
        -- 需要通知master服，观战玩家退出了
        pcall(cluster.send, "master", ".balprivateroommgr", "exitView", self.deskid, {user.uid}, self.gameid, false)
        local userCnt = self:getUserCnt()
        local realUserCnt = self:getRealUserCnt()
        pcall(cluster.send, "master", ".mgrdesk", "changDeskSeat", self.name, self.gameid, self.deskid, userCnt, realUserCnt)
    end
end

-- 删除某位观战人员
function DeskInfo:removeViewUser(uid)
    local idx = nil
    for i, u in ipairs(self.views) do
        if u.uid == uid then
            idx = i
            break
        end
    end
    if idx then
        table.remove(self.views, idx)
        -- 需要通知master服，观战玩家退出了
        pcall(cluster.send, "master", ".balprivateroommgr", "exitView", self.deskid, {uid}, self.gameid, true)
        local userCnt = self:getUserCnt()
        local realUserCnt = self:getRealUserCnt()
        pcall(cluster.send, "master", ".mgrdesk", "changDeskSeat", self.name, self.gameid, self.deskid, userCnt, realUserCnt)
    end
end

-- 获取观战对象
function DeskInfo:findViewUser(uid)
    if self.isDestroy then
        return nil
    end
    for _, user in pairs(self.views) do
        if user.uid == uid then
            return user
        end
    end
    return nil
end

-- 根据座位号，找到上一个玩家
function DeskInfo:findPrevUser(seatId, isReverse)
    local tryCnt = self.seat
    while tryCnt > 0 do
        if isReverse then
            seatId = seatId + 1
            if seatId > self.seat then seatId = 1 end
        else
            seatId = seatId - 1
            if seatId < 1 then seatId = self.seat end
        end
        for _,user in pairs(self.users) do
            if user.seatid == seatId then
                return user
            end
        end
        tryCnt = tryCnt - 1
    end
    return nil
end

-- 根据座位号，找到下一个玩家
-- isReverse 是否是逆时针
function DeskInfo:findNextUser(seatId, isReverse)
    local tryCnt = self.seat
    while tryCnt > 0 do
        if isReverse then
            seatId = seatId - 1
            if seatId <= 0 then seatId = self.seat end
        else
            seatId = seatId + 1
            if seatId > self.seat then seatId = 1 end
        end
        for _,user in pairs(self.users) do
            if user.seatid == seatId then
                return user
            end
        end
        tryCnt = tryCnt - 1
    end
    return nil
end

-- 通过uid获取用户对象
---@return BaseUser
function DeskInfo:findUserByUid(uid)
    for _, user in pairs(self.users) do
        if user.uid == uid then
            return user
        end
    end
    return nil
end

-- 通过座位号查找对象
function DeskInfo:findUserBySeatid(seatid)
    for _, user in pairs(self.users) do
        if user.seatid == seatid then
            return user
        end
    end
    return nil
end

local EMOJI_SEND_TIME = {}
function DeskInfo:isParter(uid, toUid)
	local a = self:findUserByUid(uid)
	local b = self:findUserByUid(toUid)
    if table.contain({1,3,5}, a.seatid) and table.contain({1,3,5}, b.seatid) then
        return true
    end
    if table.contain({2,4,6}, a.seatid) and table.contain({2,4,6}, b.seatid) then
        return true
    end
	return false
end

function DeskInfo:aiSendTextChat()
    local aiUids = {}
    for _, muser in pairs(self.users) do
        if not muser.cluster_info then
            table.insert(aiUids, muser.uid)
        end
    end
    if #aiUids == 0 then
        return
    end
    local auid = aiUids[math.random(#aiUids)]
    local userInfo = self:findUserByUid(auid)
    local retobj = buildChatMsg(userInfo, math.random(0, 6))
    self:broadcast(cjson.encode(retobj))
end

function DeskInfo:aiSendEmoji()
	if math.random() < PDEFINE.EMOJI.PROB then --控制自动赠送的百分比
		-- 如果没发emoji, 则判断是否发文字消息
        if math.random() > PDEFINE.EMOJI.TEXT then
            self:aiSendTextChat()
        end
        return
	end
	local aiUids = {}
	for _, muser in pairs(self.users) do
		if not muser.cluster_info then
			table.insert(aiUids, muser.uid)
		end
	end
	if #aiUids == 0 then
        return
    end
	local auid = aiUids[math.random(1, #aiUids)]

	local nowtime = os.time()
	if nil ~= EMOJI_SEND_TIME[auid] then
		if (nowtime - EMOJI_SEND_TIME[auid]) < 15 then --每个人间隔最少xs
			return
		end
	end
	EMOJI_SEND_TIME[auid] = nowtime
	
	local friendEmoji = PDEFINE.EMOJI.FRIEND -- 给队友的
	local otherEmoji = PDEFINE.EMOJI.RIVAL
	local userInfo = self:findUserByUid(auid)
	local emojiId = math.random(1, #PDEFINE.EMOJI.ALL)
	local playeruids = {}
	for _, muser in pairs(self.users) do
		if muser.uid ~= auid then
			table.insert(playeruids, muser.uid)
		end
	end
	local idx = math.random(1,#playeruids)
	local toUid = playeruids[idx]

	if math.random(1, 1000) < 700 then
		if self:isParter(auid, toUid) then
			emojiId = friendEmoji[math.random(1, #friendEmoji)]
		else
			emojiId = friendEmoji[math.random(1, #otherEmoji)]
		end
	end
    -- 需要扣掉相应的金币
    local ok, charmCfg = pcall(cluster.call, "master", ".configmgr", "getCharmPropList")
    if ok and nil ~= charmCfg[emojiId] then
        local item = charmCfg[emojiId]
        if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
            if userInfo.realCoin < item.count then
                return
            end
            userInfo.realCoin = userInfo.realCoin - item.count
        else
            if userInfo.coin < item.count then
                return
            end
            userInfo.coin = userInfo.coin - item.count
        end
    end
	local retobj = buildEmojiMsg(userInfo, emojiId, toUid)
	self:broadcast(cjson.encode(retobj))
	-- self:broadcastViewer(cjson.encode(retobj))
end

-- 创建桌子成功，写入数据到数据库
function DeskInfo:writeDB()
    self:print("writeDB self.prize:",self.prize)
    if nil == self.prize then
        self.prize = 0
    else
        self.prize = math.round_coin(self.prize)
    end

    local sql = string.format("insert into d_desk_game(deskid,gameid,uuid,owner,roomtype,bet,prize,conf,create_time) values(%d,%d,'%s',%d,%d,%.2f,%.2f,'%s',%d)", 
                                self.deskid, self.gameid, self.uuid, self.owner, self.conf.roomtype, self.bet, self.prize, cjson.encode(self.conf), os.time())
    skynet.call(".mysqlpool", "lua", "execute", sql)
end

-- 更新桌子状态，并同步到数据库
function DeskInfo:updateState(state, syncDB)
    self.state = state
    pcall(cluster.send, "master", ".mgrdesk", "changeMatchDeskStatus", self.name, self.gameid, self.deskid, self.state)
    if syncDB then
        local sql
        if self.state == PDEFINE.DESK_STATE.PLAY then
            local users = {}
            for _, muser in pairs(self.users) do 
                table.insert(users, {
                    ['uid'] = muser.uid,
                    ['seatid'] = muser.seatid,
                })
            end
            sql = string.format( "update d_desk_game set users='%s' where uuid='%s'", cjson.encode(users), self.uuid)
        elseif self.state == PDEFINE.DESK_STATE.SETTLE or self.state == PDEFINE.DESK_STATE.GAMEOVER then
            sql = string.format( "update d_desk_game set `status`=%d where uuid='%s'", 2, self.uuid)
        end
        if sql then
            self:print("updateDataToDB sql:", sql)
            skynet.call(".mysqlpool", "lua", "execute", sql)
        end
    end
end

-- 更新牌局结果
---@param score integer 最终分数
---@param winner integer 赢家uid
---@param settle table 结算信息
---@param allCards table 玩家对应的牌
---@param multiple integer 倍数
function DeskInfo:recordDB(score, winner, settle, allCards, multiple)
    self:print("recordDB uuid:", self.uuid)
    local cost_time = 0
	if self.roundstime then
		cost_time = os.time() - self.roundstime
	end
    local dealer_uid = self.round.dealer and self.round.dealer['uid'] or 0
    local sql = string.format("insert into d_desk_game_record(gameid,deskid,uuid,score,win,settle,cards,create_time,decider,gahwa,multiple,suit,gametype,dealer,multipler,roomtype,cost_time) values(%d,%d,'%s',%d,%d,'%s','%s',%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)", 
                                self.gameid,self.deskid,self.uuid, 0, winner, cjson.encode(settle), cjson.encode(allCards), os.time(), 0, 0, 0, 0,0,dealer_uid, multiple, self.conf.roomtype, cost_time)
                                -- LOG_DEBUG('recordDB uuid:'.. self.uuid.. ' sql:', sql)
    skynet.call(".mysqlpool", "lua", "execute", sql)
end

-- 德州扑克单独记录数据
-- 提取用户德州扑克的数据
function DeskInfo:fetchTexasFromDB(user)
    local sql = string.format("select * from d_texas_record where uid=%d", user.uid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    ---@class TexasRecord
    local record = {
        bet_coin = 0,  -- 总下注金额
        win_coin = 0,  -- 总赢取金额
        play_cnt = 0,  -- 总游戏次数
        win_cnt = 0,  -- 总赢取次数
        allin_cnt = 0,  -- allin的次数
        raise = 0,  -- 加注的次数
        fold = 0,  -- 弃牌次数
        max_win = 0,  -- 最大单次赢取
        raise_preflop = 0,  -- 发牌前弃牌次数
        raise_flop = 0,  -- flop发牌后弃牌次数
        raise_turn = 0,  -- turn发牌后弃牌次数
        raise_river = 0,  -- river发牌后弃牌次数
    }
    if rs and #rs > 0 then
        -- 如果有数据，则将数据写入用户对象中
        record.bet_coin = rs[1].bet_coin
        record.win_coin = rs[1].win_coin
        record.play_cnt = rs[1].play_cnt
        record.win_cnt = rs[1].win_cnt
        record.allin_cnt = rs[1].allin_cnt
        record.raise = rs[1].raise
        record.fold = rs[1].fold
        record.max_win = rs[1].max_win
        record.raise_preflop = rs[1].raise_preflop
        record.raise_flop = rs[1].raise_flop
        record.raise_turn = rs[1].raise_turn
        record.raise_river = rs[1].raise_river
    else
        -- 如果没有数据就初始化一个数据
        local sql = string.format([[
            insert into `d_texas_record` (
                id, uid, bet_coin, win_coin, play_cnt, win_cnt, allin_cnt, 
                raise, fold, max_win, raise_preflop, raise_flop, raise_turn, 
                raise_river, create_time, update_time
            ) values (
                null, %d, %d, %d, %d, %d, %d, 
                %d, %d, %d, %d, %d, %d,
                %d, %d, %d
            )
        ]], user.uid, record.bet_coin, record.win_coin, record.play_cnt, record.win_cnt, record.allin_cnt,
            record.raise, record.fold, record.max_win, record.raise_preflop, record.raise_flop, record.raise_turn,
            record.raise_river, os.time(), os.time()
        )
        skynet.call(".mysqlpool", "lua", "execute", sql)
    end
    user.record = record
    LOG_DEBUG("fetchTexasFromDB uid:", user.uid, " last record:", user.record)
end

-- 记录解散
---@param type number PDEFINE.GAME.DISMISS_RESULT_TYPE
function DeskInfo:recodeDismissInfo(status, uid)
    local sql = nil
    if status == PDEFINE.GAME.DISMISS_STATUS.Waiting then
        sql = string.format([[
            insert into d_desk_dismiss
                (deskid,uuid,gameid,uid,status,create_time,update_time)
            values
                (    %d,  %s,    %d, %d,    %d,         %d,         %d);
        ]], self.deskid, self.uuid, self.gameid, uid, status, os.time(), os.time())
    else
        sql = string.format([[
            update d_desk_dismiss set status=%d,update_time=%d where gameid=%d and uuid=%s and uid=%d order by id desc limit 1;
        ]], status, os.time(), self.gameid, self.uuid, uid)
    end
    self:print("recodeDismissInfo sql:", sql)
    skynet.call(".mysqlpool", "lua", "execute", sql)
end

-- 返回某个用户的相关信息
function DeskInfo:getUserReponse(uid, isself)
    local originUser = self:findUserByUid(uid)
    if not originUser then
        originUser = self:findViewUser(uid)
    end
    if not originUser then
        return nil
    end
    local user = table.copy(originUser)
    if not isself then
        if user.round and user.round.cards then
            for i = 1, #user.round.cards do
                user.round.cards[i] = 0
            end
        end
        if user.round and user.round.initcards then
            user.round.initcards = nil --用户的初始手牌
        end
    end
    -- 去掉连接信息
    user.cluster_info = nil
    -- 去掉定时器信息
    user.timer = nil
    -- cjson不支持function
    for key, v in pairs(user) do
        if type(v) == 'function' then
            user[key] = nil
        end
    end
    -- 清除元表
    user = setmetatable(user, {})
    return user
end

-- 返回桌子相应信息
function DeskInfo:toResponse(uid)
    -- 如果在回收中，则返回nil
    if self.isDestroy then
        return nil
    end
    ---@type BaseDeskInfo
    local desk = table.copy(self)
    for _, user in ipairs(desk.users) do
        if user.uid ~= uid then
            -- 去掉对方玩家手牌信息
            if user.round and user.round.cards then
                for i = 1, #user.round.cards do
                    user.round.cards[i] = 0
                end
            end
            if user.round and user.round.initcards then
                user.round.initcards = nil --用户的初始手牌
            end
            
        end
        -- 去掉连接信息
        user.cluster_info = nil
        -- 去掉定时器信息
        user.timer = nil
        -- cjson不支持function
        for key, v in pairs(user) do
            if type(v) == 'function' then
                user[key] = nil
            end
        end
        -- 清除元表
        user = setmetatable(user, {})
    end
    desk.seatList = nil
    desk.uuid = nil
    desk.func = nil
    desk.autoFuc = nil
    desk.aiAutoFuc = nil
    desk.private = nil
    if desk.round and desk.round.cards and #desk.round.cards>0 then
        local cards = {}
        for i = 1, #desk.round.cards, 1 do
            table.insert(cards, 0)
        end
        desk.round.cards = cards
    end
    if desk.autoStartInfo and desk.autoStartInfo.startTime and desk.autoStartInfo.startTime > os.time() then
        desk.autoStart = {
            delayTime = desk.autoStartInfo.startTime - os.time()
        }
    end
    if desk.matchWaitInfo and desk.matchWaitInfo.startTime and desk.matchWaitInfo.startTime > os.time() then
        desk.waitTime = desk.matchWaitInfo.startTime - os.time()
        if desk.waitTime > MatchWaitTimeout then
            desk.waitTime = MatchWaitTimeout
        end
    else
        desk.waitTime = 0
    end
    desk.autoRecycleInfo = nil
    desk.autoStartInfo = nil
    desk.autoKickOutInfo = nil
    desk.matchWaitInfo = nil
    -- cjson不支持function
    for key, v in pairs(desk) do
        if type(v) == 'function' then
            desk[key] = nil
        end
    end
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        for _, muser in pairs(desk.users) do
            muser.wincoinshow = 0
            if muser.uid ~= uid then
                muser.wincoinshow = muser.settlewin * self.bet
            else
                muser.wincoinshow = muser.settlewin * self.bet
                -- 判断是否是排位房
			    -- desk.leagueInfo = player_tool.getLeagueInfo(self.conf.roomtype, muser.uid)
            end
        end
    end

    -- 解散倒计时时长
	if self.dismiss then
        desk.dismiss = {
            uid = self.dismiss.uid,  -- 发起人
            users = self.dismiss.users,  -- 其他人信息以及是否同意
            delayTime = self.dismiss.expireTime-os.time(),  -- 解散时间
        }
    end

    -- 告知活动用户的自动托管倒计时
    desk.round.delayTime = 0
    for _, user in ipairs(self.users) do
        if user.timer.expireTime and user.timer.expireTime > 0 then
            if desk.round.expireTime then --防止机器人的实际超时时间被发送到前端
                desk.round.delayTime = desk.round.expireTime - os.time()
            else
                desk.round.delayTime = user.timer.expireTime - os.time()
            end
            if desk.round.delayTime < 0 then
                desk.round.delayTime = 0
            end
            break
        end
    end

    if desk.waitTime and desk.beginTime then
        desk.waitTime = math.floor(math.max(0, (desk.beginTime-skynet.now())/100))
    end

    -- 是否是观战
    local view = self:findViewUser(uid)
    if view then
        desk.isViewer = 1
    else
        desk.isViewer = 0
    end

    desk = setmetatable(desk, {})
    return desk
end

-- 判断金币是否足够
function DeskInfo:isCoinEnough(coin)
    -- 判断金币是否足够
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH or self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        if coin < self.conf.mincoin then --判断门槛
            return false
        end
        -- 多米诺，至少需要5倍下注额
        if self.gameid == PDEFINE.GAME_TYPE.DOMINO then
            if coin < 5 * self.bet then
                return false
            end
        end
    end
    return true
end

-- 去掉指定座位号
function DeskInfo:lockSeatid(seatid)
    local idx = nil
    for i, _seatid in ipairs(self.seatList) do
        if _seatid == seatid then
            idx = i
            break
        end
    end
    table.remove(self.seatList, idx)
end

-- 获取当前人数，包括站起的
function DeskInfo:getUserCnt()
    local cnt = #self.users
    for _, view in ipairs(self.views) do
        if view.seatid and view.seatid > 0 then
            cnt = cnt + 1
        end
    end
    return cnt
end

-- 获取当前真实玩家人数
function DeskInfo:getRealUserCnt()
    local cnt = 0
    for _, user in ipairs(self.users) do
        if user.cluster_info then
            cnt = cnt + 1
        end
    end
    for _, view in ipairs(self.views) do
        if view.cluster_info and view.seatid and view.seatid > 0 then
            cnt = cnt + 1
        end
    end
    return cnt
end

-- 将坐下的观战玩家拉入牌局中
function DeskInfo:insertSeatedView()
    -- 将坐下的观战玩家拉入牌局中
    local newViews = {}
    for _, user in ipairs(self.views) do
        if user.seatid > 0 then
            self:insertUser(user, true)
            self:userReady(user.uid)
        else
            table.insert(newViews, user)
        end
    end
    self.views = newViews
end

--满足条件直接开始游戏的房间
function DeskInfo:isDirectPlayGame()
    return self.gameid == PDEFINE.GAME_TYPE.INDIA_RUMMY or self.gameid == PDEFINE.GAME_TYPE.BLACK_JACK
end

-- 用户被淘汰
function DeskInfo:weedOut(u)
    local user = self:findUserByUid(u.uid)
    local retobj = {
        c = PDEFINE.NOTIFY.NOTIFY_TN_GAME_OVER,
        code = PDEFINE.RET.SUCCESS,
        tn_id = self.conf.tn_id,
        is_out = 1,
        ord = user.tn_ord
    }
    pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(retobj))
end

-- 更新用户比赛排名信息
function DeskInfo:updateTnOrd()
    local notifyObj = {c=PDEFINE.NOTIFY.NOTIFY_TN_GAME_UPDATE, code=PDEFINE.RET.SUCCESS, spcode=0, tn_id=self.conf.tn_id, players={}}
    for _, u in ipairs(self.users) do
        table.insert(notifyObj.players, {uid=u.uid, ord=u.tn_ord})
    end
    self:broadcast(cjson.encode(notifyObj))
end

-- 等待换桌
function DeskInfo:waitSwitchDesk()
    local ok, canSwitch = pcall(cluster.call, "master", ".tournamentmgr", "checkSwitchDesk", self.deskid, self.conf.tn_id)
    if not ok then
        LOG_INFO("waitSwitchDesk call err:", self.deskid, " tn_id:", self.conf.tn_id)
    end
    if not ok or not canSwitch then
        self.state = PDEFINE.DESK_STATE.WaitSettle
        self:waitSettle()
        return
    end
    local notifyObj = {c=PDEFINE.NOTIFY.NOTIFY_TN_GAME_WAIT_SWITCH, code=PDEFINE.RET.SUCCESS, spcode=0, tn_id=self.conf.tn_id}
    self:broadcast(cjson.encode(notifyObj))
    self.state = PDEFINE.DESK_STATE.WaitSwitch
    local uids = {}
    for _, u in ipairs(self.users) do
        table.insert(uids, u.uid)
    end
    pcall(cluster.send, "master", ".tournamentmgr", "trySwitchDesk", uids, self.deskid, self.conf.tn_id)
end

-- 等待结算
function DeskInfo:waitSettle()
    local notifyObj = {c=PDEFINE.NOTIFY.NOTIFY_TN_GAME_WAIT_SETTLE, code=PDEFINE.RET.SUCCESS, spcode=0, tn_id=self.conf.tn_id}
    self:broadcast(cjson.encode(notifyObj))
end

-- 玩家加入
function DeskInfo:insertUser(user, isViewer)
    -- 如果没有分配到座位号，就不需要插入users中
    if not user.seatid and user.cluster_info then
        pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", self.gameid, self.deskid)
        return
    end
    -- 如果房间已经开始，则丢到观战去
    if not self:isDirectPlayGame() and not self:isMatchState() then
        self:insertViews(user)
        return
    end
    -- 赛事房间, 需要通告参与人数
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
        -- pcall(cluster.send, "master", ".tournamentmgr", "useTicket", user.uid, self.conf.tn_id, self.deskid)
    end
    if self.func and self.func.initUserRound then
        self.func.initUserRound(user)
    end
    self.curseat = self.curseat + 1
    table.insert(self.users, user)
    -- 好友房,如果有玩家进入，需要取消开始倒计时
    local userCnt = self:getUserCnt()
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        if self.autoStartInfo.func then
            self.autoStartInfo.func()
            self.autoStartInfo = {}
            local notify_retobj = {
                c = PDEFINE.NOTIFY.GAME_AUTO_START_STOP,
                code = PDEFINE.RET.SUCCESS,
            }
            skynet.timeout(60, function()
                self:broadcast(cjson.encode(notify_retobj))
            end)
        end
        -- 房间加入人之后，取消解散倒计时
        self:stopAutoRecycle()
        -- 如果人满了，则开始倒计时踢掉不准备的玩家
        if userCnt == self.conf.seat then
            self:setAutoKickOut()
        end
    end
    local realUserCnt = self:getRealUserCnt()
    pcall(cluster.send, "master", ".mgrdesk", "changDeskSeat", self.name, self.gameid, self.deskid, userCnt, realUserCnt)

    -- 如果是德州扑克，则获取额外信息放入用户对象中
    if self.gameid == PDEFINE.GAME_TYPE.TEXAS_HOLDEM then
        self:fetchTexasFromDB(user)
    end
    -- 检测金币不足
    skynet.timeout(50, function()
        self:checkDangerCoin(user)
    end)
end

-- 玩家加入观战
function DeskInfo:insertViews(user)
    local viewer = self:findViewUser(user.uid)
    -- 赛事房间, 需要通告参与人数
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
        -- pcall(cluster.send, "master", ".tournamentmgr", "useTicket", user.uid, self.conf.tn_id, self.deskid)
    end
    if viewer then
        viewer.cluster_info = user.cluster_info
        -- 广播用户信息
        self:broadcastPlayerInfo(viewer)
    else
        -- 需要通知master服，观战玩家进入了
        pcall(cluster.send, "master", ".balprivateroommgr", "enterView", self.deskid, {user.uid}, self.gameid)
        table.insert(self.views, user)
        local otherRetobj = {}
        otherRetobj.c = PDEFINE.NOTIFY.PLAYER_VIEWER_ENTER_ROOM
        otherRetobj.code = PDEFINE.RET.SUCCESS
        otherRetobj.user = user
        self:broadcast(cjson.encode(otherRetobj), user.uid)
        -- 如果观战玩家有坐下，则需要重新汇报座位号
        if user.seatid > 0 then
            local userCnt = self:getUserCnt()
            local realUserCnt = self:getRealUserCnt()
            pcall(cluster.send, "master", ".mgrdesk", "changDeskSeat", self.name, self.gameid, self.deskid, userCnt, realUserCnt)
        end
    end
end

-- 玩家准备
function DeskInfo:userReady(uid)
    -- 只有准备状态才能重连
    -- LOG_DEBUG("userReady deskInfo.state:", self.state, ' uid:', uid)
    if self.state ~= PDEFINE.DESK_STATE.MATCH and self.state ~= PDEFINE.DESK_STATE.READY then
        return 
    end
    local user    = self:findUserByUid(uid)
    if not user then
        return
    end
    -- 已经准备则不需要再次准备
    if user.state == PDEFINE.PLAYER_STATE.Ready then
        return
    end
    user.state = PDEFINE.PLAYER_STATE.Ready
    local can_start = self:checkCanStart()  -- 是否可以开始
    -- LOG_DEBUG("玩家准备 DeskInfo:userReady seat:", self.seat, ' users:', #self.users, ' can_start:', can_start)
    local retobj = {
        c = PDEFINE.NOTIFY.PLAYER_READY,
        code = PDEFINE.RET.SUCCESS,
        uid=uid,
        seatid = user.seatid,
        can_start = can_start,
    }
    self:broadcast(cjson.encode(retobj))
    LOG_DEBUG("玩家准备 DeskInfo:userReady uid:", uid, ' seatid:', user.seatid)
    -- 如果都准备了，那就开始(匹配房不需要主动开始)
    if can_start == 1 then
        self.func.startGame()
        -- if self.autoStartInfo.func then
        --     self.autoStartInfo.func()
        -- end
        -- self.autoStartInfo.func = ai_set_timeout(AutoStartTimeout*100, self.func.startGame)
        -- self.autoStartInfo.startTime = os.time() + AutoStartTimeout
        -- local notify_retobj = {
        --     c = PDEFINE.NOTIFY.GAME_AUTO_START_BEGIN,
        --     code = PDEFINE.RET.SUCCESS,
        --     delayTime = self.autoStartInfo.startTime - os.time(),
        -- }
        -- skynet.timeout(60, function()
        --     self:broadcast(cjson.encode(notify_retobj))
        -- end)
    end
end

-- 设置玩家退出标记
function DeskInfo:setPlayerExit(uid)
    local user = self:findUserByUid(uid)
    if user then
        user.isexit = 1
        pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", self.gameid, self.deskid) --释放桌子对象
    else
        user = self:findViewUser(uid)
        if user then
            self:viewExit(uid)
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", self.gameid, self.deskid) --释放桌子对象
        end
    end
    return PDEFINE.RET.SUCCESS
end

-- 开始游戏
function DeskInfo:startGame()
    -- 停止加人定时器
    if self.matchWaitInfo.func then
        self.matchWaitInfo.func()
        self.matchWaitInfo = {}
    end
    -- 停止踢人定时器
    self:stopAutoKickOut()
    -- 将坐下的观战玩家拉入牌局中
    self:insertSeatedView()
    -- 这里需要先切了，反之有人退出
    self:updateState(PDEFINE.DESK_STATE.PLAY, true)
    -- 计算最终奖金
    self:confirmPrize()
    -- 去掉开始时间记录
    self.startTimestamp = nil
    -- 如果是好友房，则开启语音
    -- if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
    --     self:updateMicStatus(true)
    -- end
    local uids = {}
    for _, user in pairs(self.users) do
        if user.cluster_info then
            table.insert(uids, user.uid)
        end

        -- local leagueInfo = player_tool.getLeagueInfo(self.conf.roomtype,user.uid)
        -- if leagueInfo.isSign == 1 then
        --     user.is_league = 1
        -- else
        --     user.is_league = 0
        -- end
    end

    -- 通知聊天室，房间已经开始
    for _, user in ipairs(self.users) do
        if user.cluster_info then
            LOG_DEBUG("startGame roomStart", user.uid, self.deskid, self.gameid)
            pcall(
                cluster.send,
                user.cluster_info.server,
                user.cluster_info.address,
                "clusterModuleCall",
                "player",
                "roomStart",
                user.uid,
                self.deskid,
                self.gameid
            )
            break
        end
    end
    -- 需要通知master服，新的一轮开始了
    pcall(cluster.send, "master", ".mgrdesk", "lockPlayer", self.deskid, uids, self.gameid, self.conf.roomtype)
    if self:isTNGame() then
        -- 通知比赛服，该桌子已经开始了，解散的时候需要判断下
        pcall(cluster.send, "master", ".tournamentmgr", "deskStart", self.deskid)
    end

    for _, user in pairs(self.users) do
        local bet = self.bet
        local prize = self.prize
        
        -- 金币游戏自己控制扣钱
        if not self:isCoinGame() then
            if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE or self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
                user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -bet, self)
            end
        end
        if user.cluster_info then
            -- 检查是否是排位赛
            -- local sql = string.format("insert into d_desk_user(gameid,deskid,uuid,uid,roomtype,create_time,settle,cost_time,win,exited,bet,prize,issue) values(%d,%d,'%s',%d,%d,%d,'%s',%d,%d,%d,%d,%d,'%s')", 
            --                   self.gameid, self.deskid,self.uuid, user.uid, self.conf.roomtype, self.conf.create_time, '', 0, 0, 0, bet, prize, self.issue)
            -- -- LOG_DEBUG("d_desk_user, sql:", sql)
            -- skynet.call(".mysqlpool", "lua", "execute", sql)
        end
    end
end

-- 初始化庄家信息
function DeskInfo:electDealer()
    
end

-- 初始化用户轮次信息
function DeskInfo:initUserRound(...)
    if self.func and self.func.initUserRound then
        self.func.initUserRound(...)
    end
end

-- 初始化桌子轮次信息
function DeskInfo:initDeskRound(...)
    self.roundstime = os.time()
    if self.func and self.func.initDeskRound then
        self.func.initDeskRound(...)
    end
    for _, user in ipairs(self.users) do
        self:initUserRound(user)
    end
end

-- 设置玩家自动准备
function DeskInfo:setAutoReady(uid)
    if self.func.setAutoReady then
        self.func.setAutoReady(FirstReadyTimeout, uid)
    end
end

-- 重置桌子，准备下一大局
function DeskInfo:resetDesk(delayTime, isDismiss, waitSettle)
    local now = os.time()
    self.uuid   = self.deskid..now  -- 更改uuid
    self:newIssue()
    -- 切换回匹配状态
    -- self.state = PDEFINE.DESK_STATE.MATCH
    if waitSettle then
        self:updateState(PDEFINE.DESK_STATE.WaitSettle)
        self:waitSettle()
    else
        self:updateState(PDEFINE.DESK_STATE.MATCH)
        self.in_settle = false
        self:writeDB()  -- 写入数据库
        -- 轮数切回0
        self.curround = 0
        -- 庄家采用房主
        self:initDeskRound()
        self.conf.create_time = now
        -- 设置随机座位
        self.randSeat = self:getRandSeat()
    end
    local exitedUsers = {}
    local uids = {}
    local killUsers = {}  -- 需要踢掉的人
    local offlineUsers = {}  -- 离线的人
    local dismissUsers = {}  -- 解散踢人
    local autoUsers = {}  -- 托管的人，coinGame中托管的人
    local noCoinUsers = {}  -- 比赛房间，输掉的人
    for _, user in ipairs(self.users) do
        -- 游戏大局结束之后，解禁所有玩家，可以加入其它房间
        table.insert(uids, user.uid)
        if not user.cluster_info and (now > user.leavetime) then
            user.isexit = 1
        end
        local stayNow = true
        -- 好友房，判断金币是否够, 或者已经离线
        if isDismiss then
            stayNow = false
            table.insert(dismissUsers, {uid=user.uid, seatid=user.seatid})
        elseif user.isexit == 1 then
            stayNow = false
            table.insert(exitedUsers, {uid=user.uid, seatid=user.seatid})
        elseif user.offline == 1 and self.conf.roomtype ~= PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then  -- 放这里，会清除cluster信息
            stayNow = false
            table.insert(offlineUsers, {uid=user.uid, seatid=user.seatid})
        elseif self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
            local minCoin = self.conf.mincoin
            if user.coin < minCoin then
                stayNow = false
                table.insert(killUsers, {uid=user.uid, seatid=user.seatid})
            end
        elseif self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
            if user.coin < self.bet then
                stayNow = false
                table.insert(killUsers, {uid=user.uid, seatid=user.seatid})
            end
        elseif self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
            -- 比赛房，要判断钱不够下注的人
            if user.coin < self.bet then
                stayNow = false
                table.insert(noCoinUsers, {uid=user.uid, seatid=user.seatid})
            end
        end
        -- 这里只有没被踢才能继续走, 比赛方没这限制
        if user.auto == 1 and stayNow and self.conf.roomtype ~= PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
            user.autoCnt = user.autoCnt + 1
            self:autoMsgNotify(user, 1, 0)
            table.insert(autoUsers, {uid=user.uid, seatid=user.seatid, cnt=user.autoCnt})
        end
        user.state             = PDEFINE.PLAYER_STATE.Wait
        user.score             = 0 -- 累计总分数
        user.winTimes          = 0 -- 赢牌次数
        user.autoStartTime     = nil -- 托管开始时间
        if user.auto == 1 then
            user.autoStartTime = os.time()
        end
        user.autoTotalTime     = 0 -- 当局游戏处于托管的时间
    end

    -- 将已经退出的玩家删除，并且广播
    for _, user in ipairs(exitedUsers) do
        self:userExit(user.uid)
    end

    -- 将需要剔除的玩家剔除，并且广播
    local nowtime = os.time()
    for _, user in ipairs(killUsers) do
        local duser = self:findUserByUid(user.uid)
        self:userExit(user.uid, PDEFINE.RET.ERROR.COIN_NOT_ENOUGH)
        if duser and duser.cluster_info then
            pcall(cluster.send, duser.cluster_info.server, duser.cluster_info.address, "deskBack", self.gameid, self.deskid) --释放桌子对象
            local sql = string.format("insert into d_desk_bankrupt(uid,gameid,uuid,deskid,roomtype,bet,create_time) values(%d,%d,'%s',%d,%d,%.2f,%d)", 
								user.uid,self.gameid,self.uuid,self.deskid, self.conf.roomtype, self.bet, nowtime)
			skynet.send(".mysqlpool", "lua", "execute", sql)
        end
    end

    -- 离线的玩家，从桌子信息中删除用户
    for _, user in ipairs(offlineUsers) do
        self:userExit(user.uid, PDEFINE.RET.ERROR.USER_OFFLINE)
        -- 离线的玩家，则不能deskBack只能removeDesk
        pcall(cluster.send, "master", ".agentdesk", "removeDesk", user.uid, self.deskid)
    end

    -- 解散踢人
    for _, user in ipairs(dismissUsers) do
        pcall(cluster.send, "master", ".balprivateroommgr", "exitRoom", self.deskid, self.gameid, user.uid)
        for _, u in ipairs(self.users) do
            if u.uid == user.uid and u.cluster_info then
                pcall(cluster.send, u.cluster_info.server, u.cluster_info.address, "deskBack", self.gameid, self.deskid)
            end
        end
        pcall(cluster.send, "master", ".agentdesk", "removeDesk", user.uid, self.deskid)
        self:userExit(user.uid, user.seatid, PDEFINE.RET.ERROR.GAME_ALREADY_DELTE)
    end

    -- 踢出观战玩家
    if isDismiss then
        for _, viewer in ipairs(self.views) do
            self:viewExit(viewer.uid)
            pcall(cluster.send, viewer.cluster_info.server, viewer.cluster_info.address, "deskBack", self.gameid, self.deskid) --释放桌子对象
        end
    end

    -- 记录托管人的托管次数，子游戏会进行剔除操作
    if not DEBUG then
        for _, u in ipairs(autoUsers) do
            if u.cnt >= PDEFINE_GAME.MAX_AUTO_CNT then  --! 这里给出托管多少次被踢
                local muser = self:findUserByUid(u.uid)
                self:userExit(u.uid, PDEFINE.RET.ERROR.AUTO_COUNT_LIMIT)
                -- 如果玩家在线，则只要deskback就行
                pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "deskBack", self.gameid, self.deskid) --释放桌子对象
                -- pcall(cluster.send, "master", ".agentdesk", "removeDesk", u.uid, self.deskid)
            end
        end
    end

    -- 比赛中的人，没金币需要踢出玩家
    for _, u in ipairs(noCoinUsers) do
        local muser = self:findUserByUid(u.uid)
        -- 通知用户淘汰
        self:weedOut(u)
        self:userExit(u.uid, PDEFINE.RET.ERROR.TN_WEED_OUT)
        -- 如果玩家在线，则只要deskback就行
        pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "deskBack", self.gameid, self.deskid) --释放桌子对象
        -- 汇报给master，这个人被踢了
        pcall(cluster.send, "master", ".tournamentmgr", "weedOut", u.uid, self.conf.tn_id, self.deskid)
    end

    -- 将坐下的观战玩家拉入牌局中
    self:insertSeatedView()

    pcall(cluster.send, "master", ".mgrdesk", "changDeskSeat", self.name, self.gameid, self.deskid, self:getUserCnt(), self:getRealUserCnt())

    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
        -- 需要判断是否需要换桌
        if not waitSettle then
            skynet.timeout(delayTime*100, function()
                local userCnt = self:getUserCnt()
                if userCnt < self.minSeat then
                    -- 告诉master服，需要换桌了
                    self:waitSwitchDesk()
                else
                    -- 告诉master服，需要换桌了
                    self.func.startGame()
                end
            end)
        end
    elseif self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        for _, u in ipairs(self.users) do
            if u.cluster_info then
                u.luckBuff = hasLuckyBuffer(u.uid, self.gameid)
            end
        end
        -- 匹配方倒计时开始下一轮游戏
        if self:hasRealPlayer() or self:hasViews() then
            self:setWaitTime(delayTime)
        else
            LOG_DEBUG("destroy deskInfo:", self.deskid)
            self:destroy()
        end
    else
        if not delayTime then
            delayTime = 0.1
        end
        if self:hasRealPlayer() then
            -- 设置每个人的自动准备
            for _, user in ipairs(self.users) do
                if self.func.setAutoReady then
                    self.func.setAutoReady(delayTime, user.uid)
                end
            end
            -- 如果还没有开始，则继续添加机器人，第二个机器人开始，就只要5-10秒了
            if self.state == PDEFINE.DESK_STATE.MATCH and self:isJoinAi() then
                self:autoStartGame()
            end
        else
            local uids = {}
            for _, u in ipairs(self.users) do
                table.insert(uids, u.uid)
            end
            for _, uid in ipairs(uids) do
                self:userExit(uid)
            end
        end
        -- skynet.timeout(delayTime*100, function ()
        --     -- 匹配方倒计时开始下一轮游戏
        --     if self:hasRealPlayer() then
        --         for _, u in ipairs(self.users) do
        --             if u.state ~= PDEFINE.PLAYER_STATE.Ready then
        --                 -- if self.conf.autoStart == 1 or not u.cluster_info then
        --                 --     LOG_DEBUG("DeskInfo:resetDesk userReady:", u.uid)
        --                 -- end
        --                 -- 改成倒计时自动准备
        --                 self:userReady(u.uid)
        --             end
        --         end
        --         if self:getUserCnt() == self.seat then
        --             self:setAutoKickOut()
        --         end
        --         -- 如果还没有开始，则继续添加机器人，第二个机器人开始，就只要5-10秒了
        --         if self.state == PDEFINE.DESK_STATE.MATCH and self:isJoinAi() then
        --             self:autoStartGame()
        --         end
        --     else
        --         local uids = {}
        --         for _, u in ipairs(self.users) do
        --             table.insert(uids, u.uid)
        --         end
        --         for _, uid in ipairs(uids) do
        --             self:userExit(uid)
        --         end
        --     end
        -- end)
    -- else
    --     -- 设置每个人的自动准备
    --     for _, user in ipairs(self.users) do
    --         if self.func.setAutoReady then
    --             self.func.setAutoReady(AutoReadyTimeout, user.uid)
    --         end
    --     end
    end
end

-- 发送开始倒计时协议
function DeskInfo:notifyStart(delayTime)
    local retobj = {
        c = PDEFINE.NOTIFY.NOTIFY_GAME_START,
        code = PDEFINE.RET.SUCCESS,
        delayTime = delayTime,  -- 倒计时时间
    }
    self:broadcast(cjson.encode(retobj))
end

-- 开始新的一轮
function DeskInfo:roundStart()
    self:updateState(PDEFINE.DESK_STATE.PLAY)
    self.roundstime = os.time()
end

-- 小结算
function DeskInfo:roundOver()
    -- 如果是特殊房间，则去掉, 只打一局
    if self.conf.spcial == 1 then
        self.conf.spcial = nil
    end
end

function DeskInfo:genWinTimesKey(uid, istotal, today)
    if istotal then
        return string.format(PDEFINE_REDISKEY.SHARE.TYPE.TOTAL, today, uid)
    end
    return string.format(PDEFINE_REDISKEY.SHARE.TYPE.CONT, today, uid, self.gameid, self.deskid)
end

local function calWinTimesFBShare(totalwins, contwins, today, uid, gameid)
    local item = {}
    for i=#PDEFINE.SHARE.WINTIMES.TOTAL.KEYS, 1, -1 do
        local times = PDEFINE.SHARE.WINTIMES.TOTAL.KEYS[i]
        if totalwins == times then
            item['type'] = PDEFINE.SHARE.TYPE.TOTAL --累计分享 类型
            item['times'] = PDEFINE.SHARE.WINTIMES.TOTAL.TIMES[i] --累计分享 倍数
            break
        end
    end

    local getTimes = do_redis({"get", string.format(PDEFINE_REDISKEY.SHARE.TYPE.CONTGET, today, uid, gameid)})
    if not getTimes then
        for i=#PDEFINE.SHARE.WINTIMES.CONT.KEYS, 1, -1 do
            local times = PDEFINE.SHARE.WINTIMES.CONT.KEYS[i]
            if contwins >= (times+1) then
                if nil == item['times'] then
                    item['type'] = PDEFINE.SHARE.TYPE.CONT --连胜分享
                    item['times'] = PDEFINE.SHARE.WINTIMES.CONT.TIMES[i] --倍数
                else
                    if item['times'] == times then
                        item['type'] = PDEFINE.SHARE.TYPE.CONT --如果是同样的倍数，就直接显示连胜的分享
                    end
                end
                break
            end
        end
    end
    return item
end

-- 累计获胜或连胜记录, 可能触发分享条件
function DeskInfo:recordWinTimes(winUidsAndCoin)
    LOG_DEBUG("DeskInfo:recordWinTimes:", winUidsAndCoin)
    local fbshare = {}
    if nil==winUidsAndCoin or table.empty(winUidsAndCoin) then
        return fbshare
    end
    local leftTime = getThisPeriodTimeStamp()
    local winuids = {}
    local today = os.date("%Y%m%d",os.time()) 
    for _, user in pairs(self.users) do
        if user.cluster_info then
            local times1, times2 = 0, 0
            if winUidsAndCoin[user.uid] then
                local cumuTimesKey = self:genWinTimesKey(user.uid, true, today) --累计赢
                do_redis({"hincrby", cumuTimesKey, self.gameid, 1})
                times1 = do_redis({"hget", cumuTimesKey, self.gameid})
                times1 = tonumber(times1 or 0)
                if times1 == 1 then
                    do_redis( {"expire", cumuTimesKey, leftTime}) 
                end
                table.insert(winuids, user.uid)

                local contTimesKey = self:genWinTimesKey(user.uid, false, today)
                if table.contain(self.preWinners, user.uid) then --连赢
                    do_redis({ "incrby", contTimesKey, 1})
                    times2 = do_redis({"get", contTimesKey})
                    times2 = tonumber(times2 or 0)
                    if times2 == 1 then
                        do_redis( {"expire", contTimesKey, leftTime}) 
                    end
                else
                    do_redis({"del", contTimesKey})
                end
                LOG_DEBUG('recordWinTimes: uid:', user.uid, ' times1:', times1, ' times2:',times2)
                if times1 > 0 or times2 > 0 then
                    local item = calWinTimesFBShare(times1, times2, today, user.uid, self.gameid)
                    if not table.empty(item) then
                        fbshare[user.uid] = item
                        do_redis({"set", string.format(PDEFINE_REDISKEY.SHARE.COINKEY, user.uid, self.gameid), winUidsAndCoin[user.uid]*item.times}) --保存起来
                    end
                end
            end
            
        end
    end
    self.preWinners = winuids
    return fbshare
end

-- 大结算
---@param settle Settle 结算信息
---@param isDismiss boolean 是否是结算
---@param oneself boolean 是否是各自结算
---@param winners table 指定赢的人
---@param settledbygame SettledByGame 子游戏自己完成结算
---@param reduceTime integer 需要减少的间隔时间
function DeskInfo:gameOver(settle, isDismiss, oneself, winners, settledbygame, reduceTime)
    -- 是否在结算中
    if self.in_settle then
        return
    end
    self.state = PDEFINE.DESK_STATE.SETTLE
    self.in_settle = true
    -- 如果有解散房间，则取消操作
    if not isDismiss then
        -- 取消解散
        self:cancelDismiss()
    end
    local retobj = {
        c = PDEFINE.NOTIFY.GAME_OVER,
        code = PDEFINE.RET.SUCCESS,
        isTie = 0,  -- 是否平局
    }
    local dangerUids = {}  -- 快要破产的人
    local uids = {}
    for _, user in ipairs(self.users) do
        if user.cluster_info then
            table.insert(uids, user.uid)
        end
        if user.luckBuff then
            user.luckBuff = false
        end
    end
    -- 需要将玩家解禁，可以退出后加入其它房间
    pcall(cluster.send, "master", ".mgrdesk", "unlockPlayer", self.deskid, uids, self.gameid, self.conf.roomtype)
    -- 更改数据库数据
    self:updateState(PDEFINE.DESK_STATE.GAMEOVER, true)
    -- 游戏耗时
    local delayTime = os.time() - self.conf.create_time
    -- 平分奖励的玩家位置
    local maxScoreSeats = {}
    if winners then
        maxScoreSeats = winners
    else
        -- 最大分数
        local maxScore = table.maxn(settle.scores)
        for _, user in ipairs(self.users) do
            if settle.scores[user.seatid] == maxScore then
                table.insert(maxScoreSeats, user.seatid)
            end
        end
    end
    -- 如果赢的人数量和总数量相同，则是平局
    if #maxScoreSeats == #self.users then
        retobj.isTie = 1
    end
    -- 扎金花，只要超过两名玩家赢钱，就算平局
    if self:isCoinGame() and #winners > 0 then
        retobj.isTie = 1
    end
    -- 记录本轮游戏赢的钱
    local totalBetCoin = 0
    local totalTaxCoin = 0
    -- LOG_DEBUG("settle.coins", settle.coins)
    -- 开始结算用户金币和经验
    for _, user in ipairs(self.users) do
        local isWin = table.contain(maxScoreSeats, user.seatid)
        if not self:isCoinGame() then
            settle.coins[user.seatid] = -1 * self.bet
            if settledbygame then
                --子游戏自己结算
                user.settlewin = user.settlewin + settledbygame.settlewin[user.seatid]
            else
                if isWin then
                    if oneself then
                        user.settlewin = user.settlewin + #self.users * (1-self.taxrate) / #maxScoreSeats - 1
                    else
                        user.settlewin = user.settlewin + 2 * (1-self.taxrate) - 1
                    end
                else
                    user.settlewin = user.settlewin - 1
                end
            end
        end
        -- oneself 用来判断是否是分队游戏
        -- 进房间已经扣除了下注额，所以这里只需要考虑奖励的钱
        local winCoin = 0
        if self:isCoinGame() then
            -- 如果是金币游戏，则已经在子游戏中结算了
            totalBetCoin = totalBetCoin + user.round.betCoin
            totalTaxCoin = totalTaxCoin + settle.taxes[user.seatid]
            -- pass
        elseif settledbygame then
            winCoin = settledbygame.wincoin[user.seatid]
            settle.coins[user.seatid] = settle.coins[user.seatid] + winCoin
            totalBetCoin = totalBetCoin + self.bet
            totalTaxCoin = totalTaxCoin + settledbygame.tax[user.seatid]
            if winCoin ~= 0 then
                user:notifyLobby(winCoin, user.uid, self.gameid)
                user:changeCoin(PDEFINE.ALTERCOINTAG.WIN, winCoin, self)
            end
        else
            if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH or self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
                local prize = self.prize
                local bet = self.bet
                local tax = 0
                if oneself then
                    prize = bet * #self.users
                else
                    prize = bet * #self.users * 0.5
                end
                if oneself then
                    if isWin then
                        -- 这里需要平分金额
                        winCoin = math.round_coin(prize / #maxScoreSeats)
                        tax = math.round_coin(math.max(0, winCoin-bet) * self.taxrate)
                        winCoin = winCoin - tax
                        -- 开启了排位，金币加倍奖励, 前提是winCoin要大于下注
                        if user.is_league == 1 and winCoin > bet then
                            -- winCoin = winCoin * 2 - bet
                        end
                        settle.coins[user.seatid] = settle.coins[user.seatid] + winCoin
                        user:notifyLobby(winCoin, user.uid, self.gameid)
                        user:changeCoin(PDEFINE.ALTERCOINTAG.WIN, winCoin, self)
                    end
                else
                    if isWin then
                        winCoin = prize
                        tax = math.round_coin(math.max(0, winCoin-bet) * self.taxrate)
                        winCoin = winCoin - tax
                        -- 开启了排位，金币加倍奖励
                        if user.is_league == 1 then
                            -- winCoin = winCoin * 2 - bet
                        end
                        settle.coins[user.seatid] = settle.coins[user.seatid] + winCoin
                        user:notifyLobby(winCoin, user.uid, self.gameid)
                        user:changeCoin(PDEFINE.ALTERCOINTAG.WIN, winCoin, self)
                    end
                end
                totalBetCoin = totalBetCoin + bet
                totalTaxCoin = totalTaxCoin + tax
                -- 好友房和匹配房踢人的门槛不同，所以分开判断
                if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
                    if user.coin - self.conf.mincoin < (PDEFINE_GAME.DANGER_BET_MULT-1)*bet then
                        table.insert(dangerUids, user.uid)
                    end
                else
                    if user.coin < PDEFINE_GAME.DANGER_BET_MULT*bet then
                        table.insert(dangerUids, user.uid)
                    end
                end
            end
        end
    end
    local updateAiUsers = {}
    for _, user in ipairs(self.users) do
        local isWin = table.contain(maxScoreSeats, user.seatid)
        -- 检查是否是排位赛
        local is_league = user.is_league
        -- 记录托管时间
        if user.autoStartTime then
            user.autoTotalTime = user.autoTotalTime + os.time() - user.autoStartTime
            user.autoStartTime = os.time()
        end
        if user.cluster_info then
            local winCoin = settle.coins[user.seatid]
            local betCoin = self.bet
            if self:isCoinGame() then
                betCoin = user.round.betCoin
            else
                winCoin = winCoin + self.bet  --日志记录总赢
            end
            local tax = 0
            baseRecord.betGameLog(self, user, betCoin, winCoin, settle, tax)
        else
            -- 更新机器人
            table.insert(updateAiUsers, {uid=user.uid, coin=user.coin, rp=user.rp, levelexp=user.levelexp, leagueexp=settle.league[user.seatid], gameid=self.gameid})
        end
    end
    -- if #updateAiUsers > 0 then
    --     pcall(cluster.send, "ai", ".aiuser", "updateAiInfo", updateAiUsers)
    -- end

    -- 好友房，给房主分钱
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        local totalbet = (self.private.totalbet or 0) + totalBetCoin
        self.private.totalbet = totalbet
        pcall(cluster.send, "master", ".balprivateroommgr", "gameOver", self.deskid, self.owner, totalTaxCoin, self.bet, totalbet)
    end
    -- 增加当前金币数
    for _, user in ipairs(self.users) do
        settle.fcoins[user.seatid] = user.coin
    end
    -- 比赛房间汇报场次结果
    local waitSettle = false
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
        local players = {}
        for _, user in ipairs(self.users) do
            table.insert(players, {uid=user.uid, coin=user.coin})
        end
        local ok, ord_info, tonext = pcall(cluster.call, "master", ".tournamentmgr", "updateCoin", players, self.conf.tn_id, self.deskid)
        if ok then
            for _, info in ipairs(ord_info) do
                local u = self:findUserByUid(info.uid)
                if u then
                    u.tn_ord = info.ord
                end
            end
            self:updateTnOrd()
            if not tonext then
                waitSettle = true
            end
        end
    end
    -- 将观战玩家的也加上去
    for _, u in ipairs(self.views) do
        if u.seatid and u.seatid > 0 then
            settle.fcoins[u.seatid] = u.coin
        end
    end

    local winUidsAndCoin = {} --赢的uid=>金币数
    for _, user in ipairs(self.users) do
        if settle.coins[user.seatid] > 0 then
            winUidsAndCoin[user.uid] = settle.coins[user.seatid]
        end
    end

    retobj.fbshare = self:recordWinTimes(winUidsAndCoin)
    retobj.settle = settle
    retobj.isDismiss = isDismiss and 1 or 0  -- 是否解散
    -- 私人房不能直接删除桌子信息，需要继续 下一轮
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        -- 如果是解散结算的，则要去掉房间
        local owner = self:findUserByUid(self.owner)
        if isDismiss then
            local notify_retobj = { c=PDEFINE.NOTIFY.NOTIFY_SYS_KICK, code = PDEFINE.RET.SUCCESS, deskid=self.deskid }
            skynet.timeout(10, function()
                self:broadcast(cjson.encode(notify_retobj))
                self:destroy(true)
            end)
        else
            retobj.delayTime = AutoStartTimeout
            if reduceTime then -- 德州, 三张这些不需要加上等待时间
                retobj.delayTime = retobj.delayTime - reduceTime
            else
                retobj.delayTime = retobj.delayTime + SettleAnimalTimeout
            end
            skynet.timeout(10, function()
                self:resetDesk(retobj.delayTime)
            end)
        end
    elseif self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH or self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
        if isDismiss then
            local notify_retobj = { c=PDEFINE.NOTIFY.NOTIFY_SYS_KICK, code = PDEFINE.RET.SUCCESS, deskid=self.deskid }
            skynet.timeout(10, function()
                self:broadcast(cjson.encode(notify_retobj))
            end)
            self:destroy()
        else
            if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
                retobj.delayTime = TournamentWaitTimeout
            else
                retobj.delayTime = MatchAutoStartTimeout
            end
            if reduceTime then -- 德州, 三张这些不需要加上等待时间
                retobj.delayTime = retobj.delayTime - reduceTime
            else
                retobj.delayTime = retobj.delayTime + SettleAnimalTimeout
            end
            skynet.timeout(10, function()
                self:resetDesk(retobj.delayTime, nil, waitSettle)
            end)
        end
    else
        self:destroy()
    end
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH and not self:isCoinGame() then
        for _, user in ipairs(self.users) do
            if  user.cluster_info and user.isexit == 0 then
				retobj.wincoins = {}
				for _, muser in pairs(self.users) do
					table.insert(retobj.wincoins, {
						uid = muser.uid,
						wincoinshow = muser.settlewin * self.bet
					})
				end
                user:sendMsg(cjson.encode(retobj))
                --LOG_DEBUG("大结算", retobj)
			end
        end
        -- 汇报给观战人员
        for _, user in ipairs(self.views) do
            if user.cluster_info then
				retobj.wincoins = {}
				for _, muser in pairs(self.users) do
					table.insert(retobj.wincoins, {
						uid = muser.uid,
						wincoinshow = muser.settlewin * self.bet
					})
				end
                user:sendMsg(cjson.encode(retobj))
			end
        end
        self:broadcastViewer(cjson.encode(retobj))
    else
        self:broadcast(cjson.encode(retobj))
    end
    if #dangerUids > 0 then
        local notify_object = {}
        notify_object.c = PDEFINE.NOTIFY.PLAYER_DANGER_COIN
        notify_object.code = PDEFINE.RET.SUCCESS
        notify_object.dangerUids = dangerUids
        self:broadcast(cjson.encode(notify_object))
    end
end

-- 玩家托管状态广播
function DeskInfo:autoMsgNotify(user, auto, delayTime)
    if auto == 1 then
        if not user.autoStartTime then
            user.autoStartTime = os.time()
        end
    else
        user.autoCnt = 0
        if user.autoStartTime then
            user.autoTotalTime = user.autoTotalTime + os.time() - user.autoStartTime
            user.autoStartTime = nil
        end
    end
    local retobj = {
        c = PDEFINE.NOTIFY.PLAYER_AFK,
        code = PDEFINE.RET.SUCCESS,
        uid = user.uid,
        seatid = user.seatid,
        auto = auto,
        autoCnt = user.autoCnt,
        delayTime = delayTime
    }
    self:broadcast(cjson.encode(retobj))
    pcall(cluster.send, "master", ".balprivateroommgr", "syncUserState2DeskCache", self.gameid, self.deskid, user.uid, auto)
end

-- 更新玩家的连接信息
function DeskInfo:updateUserAgent(uid, agent)
    local user = self:findUserByUid(uid)
    if not user then
        user = self:findViewUser(uid)
    end
    if not user then
        return
    end
    self:print("updateUserClusterInfo set user agent uid:", uid, " agent:", agent, ' user old cluster_info:', user.cluster_info)
    if nil ~= user and user.cluster_info then
        user.cluster_info.address = agent
    end
    self:print("updateUserClusterInfo  user new cluster_info:", user.cluster_info)
end

-- 回收机器人
function DeskInfo:RecycleAi(user)
    if not user.cluster_info then
        pcall(cluster.send, "ai", ".aiuser", "recycleAi",user.uid, user.score, os.time()+10, self.deskid)
    end
end

function DeskInfo:initAiCoin()
    local coin = math.random(100000,999999)
    -- 如果是好友房，则是底注的100-200倍
    -- 如果是匹配房，则是最高注的一半到最高注，如果是最高房，则是底注的100-200倍
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        coin = math.random(math.ceil(self.bet*100), math.ceil(self.bet*1000))
    elseif self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        coin = math.random(math.ceil(self.bet*100), math.ceil(self.bet*1000))
    end
    coin = coin + math.random(0,99)/100
    return coin
end

function DeskInfo:getMinSeat()
    local minSeat = self.seat
    -- koubo 随机4到6人开始
    if self.gameid == PDEFINE.GAME_TYPE.KOUTBO then
        if self:getUserCnt() < 4 and math.random() < 0.5 then
            minSeat = 4
        end
    end
    if self.gameid == PDEFINE.GAME_TYPE.LUDO or self.gameid == PDEFINE.GAME_TYPE.LUDO_QUICK then
        if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH  then
            minSeat = 2
        end
    end
    -- 只需要最低人数
    if self:isCoinGame() or self:isDirectPlayGame() then
        minSeat = self.minSeat and self.minSeat or 2
    end
    return minSeat
end

-- 获取随机人数，德州和teenpatti座位较多，需要随机处理
function DeskInfo:getRandSeat()
    if not self:isCoinGame() then
        return self:getMinSeat()
    else
        local weights = {}
        if not self.conf.create_time then
            self.conf.create_time = os.time()
        end
        -- math.randomseed(self.conf.create_time)
        if self.seat <= 5 then
            if self.seat > self.minSeat then
                return math.random(self.minSeat, self.seat-1)
            else
                return math.random(self.minSeat, self.seat)
            end
        end
        for i = 1, self.seat, 1 do
            local weight
            local mid = self.seat / 2
            if i > mid then
                weight = (self.seat - i)^2
            else
                weight = i^2
            end
            if i < self.minSeat or i >= 7 then
                weight = 0
            end
            table.insert(weights, {weight=weight})
        end
        local idx, _ = randByWeight(weights)
        -- math.randomseed(os.time())
        if not idx then
            return self:getMinSeat()
        end
        return idx
    end
end

function DeskInfo:broadcastPlayerEnterRoom(uid)
    local retobj = {}
    retobj.c = PDEFINE.NOTIFY.PLAYER_ENTER_ROOM
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.gameid = self.gameid
    retobj.user = self:getUserReponse(uid)
    self:broadcast(cjson.encode(retobj), uid)
end

-- 加入机器人
function DeskInfo:aiJoin(aiUser, autoStart)
    if nil ~= aiUser then
        local seatid = 0
        if self.func and self.func.assignSeat then
            seatid = self.func.assignSeat()
            LOG_DEBUG("aiJoin msg seatid: ", seatid, ' 从 assignSeat分配')
        else
            seatid = self:getSeatId()
            LOG_DEBUG("aiJoin msg seatid: ", seatid, ' 从 deskinfo 分配')
        end
        local userObj = baseUser(aiUser, self)
        aiUser.ssid = self.ssid
        userObj:init(seatid, self)
        -- 初始化金币
        userObj.coin = self:initAiCoin()
        self:insertUser(userObj)
        self:broadcastPlayerEnterRoom(userObj.uid)

        -- 私人房需要告诉master
        if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
            -- aiSeat
            pcall(cluster.send, "master", ".balprivateroommgr", "aiSeat", self.deskid, self.gameid, {
                uid = userObj.uid,
                playername = userObj.playername,
                usericon = userObj.usericon,
                seatid = userObj.seatid
            })
        end
        pcall(cluster.send, "node", ".chat", "changeDeskInfoUsers", self.deskid, self.gameid, self.users, self.cid)
        return PDEFINE.RET.SUCCESS, 1
    end

    local minSeat = self.randSeat
    if self.private.aijoin == 1 then
        local num = minSeat - self:getUserCnt()
        if num > 0 then
            local ok, aiUserList = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", 1, true)
            -- self:print("加入机器人个数: ", num, aiUserList)
            if ok and not table.empty(aiUserList) then
                for _, ai in pairs(aiUserList) do
                    if self:getUserCnt() >= minSeat then
                        self:RecycleAi(ai)
                        break
                    end
                    -- 防止加入重复的机器人
                    local exist_user = self:findUserByUid(ai.uid)
                    if not exist_user and self.state == PDEFINE.DESK_STATE.MATCH then
                        local seatid = self:getSeatId()
                        if not seatid then
                            self:RecycleAi(ai)
                            break
                        end
                        -- ai.coin = math.random(100000,999999)
                        ai.ssid = self.ssid
        
                        local userObj = baseUser(ai, self)
                        -- 初始化金币
                        userObj.coin = self:initAiCoin()
                        userObj:init(seatid, self)
                        self:insertUser(userObj)
                        self:broadcastPlayerEnterRoom(userObj.uid)

                        self:print("加入机器人: seatid->", userObj.seatid, "uid->", userObj.uid, "state->", self.state)
                    end
                end
            end
        end
    end

    -- 判断下，如果房间没真人，则不需要继续匹配机器人了，直接重置
    if not self:hasRealPlayer() then
        self:destroy()
        return
    end
    -- 如果还没有满员，则继续添加机器人
    if autoStart then
        minSeat = self:getMinSeat()
    end
    if self:getUserCnt() >= minSeat then
        -- 判断下状态，防止重复调用
        if self:isMatchState() then
            if autoStart then
                self.func.startGame()
            end
        end
    else
        self:setAiAutoJoin(autoStart)
    end
    pcall(cluster.send, "node", ".chat", "changeDeskInfoUsers", self.deskid, self.gameid, self.users, self.cid)
    return PDEFINE.RET.SUCCESS, num
end

-- 设置机器人自动加入
-- 时间间隔，根据剩余时间来定(这个方法是匹配房专用)
function DeskInfo:setAiAutoJoin(autoStart)
    local restTime = 0
    if self.matchWaitInfo and self.matchWaitInfo.startTime and self.matchWaitInfo.startTime > os.time() then
        restTime = self.matchWaitInfo.startTime - os.time()
    end
    local randDelayTime = 10
    LOG_DEBUG("setAiAutoJoin restTime:", restTime)
    if restTime > 0 then
        randDelayTime = math.random(restTime*100*2/5,restTime*100*3/5)
    end
    LOG_DEBUG("setAiAutoJoin randDelayTime:", randDelayTime)
    self.aiAutoFuc = ai_set_timeout(randDelayTime, function()
        self:aiJoin(nil, autoStart)
    end)
end

-- 同步聊天信息中的房间中的人数
function DeskInfo:syncChatItem()
    pcall(cluster.send, "node", ".chat", "changeDeskInfoUsers", self.deskid, self.gameid, self.users, nil)
end

-- 房主解散房间
function DeskInfo:dismissRoom()
    -- 比赛房直接解散，不发送协议
    if self.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.TOURNAMENT then
        for _, u in ipairs(self.users) do
            pcall(cluster.send, u.cluster_info.server, u.cluster_info.address, "deskBack", self.gameid, self.deskid) --释放桌子对象
            pcall(cluster.send, "master", ".agentdesk", "removeDesk", u.uid, self.deskid)
        end
        self:destroy()
        return PDEFINE.RET.SUCCESS
    elseif self.state == PDEFINE.DESK_STATE.MATCH 
    or self.state == PDEFINE.DESK_STATE.SETTLE 
    or self.state == PDEFINE.DESK_STATE.READY then
        local retobj = { c=PDEFINE.NOTIFY.GAME_DISMISS_ROOM, code = PDEFINE.RET.SUCCESS, deskid=self.deskid }
        self:broadcast(cjson.encode(retobj))
        self:destroy()
        return PDEFINE.RET.SUCCESS
    else
        return PDEFINE.RET.ERROR.GAME_IS_RUNNING
    end
end

-- 取消解散操作
-- 如果遇到大结算，则会取消解散操作
function DeskInfo:cancelDismiss()
    if self.dismiss then
        self.dismiss._autoFunc()
        -- 记录到数据库
        self:recodeDismissInfo(PDEFINE.GAME.DISMISS_STATUS.Refuse, self.dismiss.uid)
        -- 不同意
        self.dismiss = nil
    
        -- 恢复用户身上的定时器
        self:recoverTimer()
        local retobj = { c=PDEFINE.NOTIFY.GAME_DISMISS_CANCEL, code = PDEFINE.RET.SUCCESS, deskid=self.deskid }
        self:broadcast(cjson.encode(retobj))
    end
end

-- 加入单个机器人
function DeskInfo:aiSingleJoin()
    if self.aiAutoFuc then
        self.aiAutoFuc()
        self.aiAutoFuc = nil
    end

    -- 这里放前面的原因，是防止已经开始游戏了，结果发现没真人，又把机器人踢掉的问题
    if self.state ~= PDEFINE.DESK_STATE.MATCH then
        return
    end
    if not self:hasRealPlayer() then
        local uids = {}
        for _, u in ipairs(self.users) do
            if not u.cluster_info then
                table.insert(uids, u.uid)
            end
        end
        for _, uid in ipairs(uids) do
            self:userExit(uid)
        end
        return
    end
    -- 如果可以开始了，则开始
    if self:checkCanStart() == 1 or self:getUserCnt() >= self.seat then
        local canAutoStart = false
        for _, u in ipairs(self.users) do
            if u.state ~= PDEFINE.PLAYER_STATE.Ready then
                LOG_DEBUG("DeskInfo:aiSingleJoin first userReady:", u.uid)
                canAutoStart = true
                if not u.cluster_info or self.conf.autoStart == 1 then
                    self:userReady(u.uid)
                end
            end
        end
        LOG_DEBUG("DeskInfo:aiSingleJoin canAutoStart:", canAutoStart)
        if not canAutoStart then
            self.func.startGame()
        end
        return
    end

    if self.private.aijoin == 1 then
        local ok, aiUserList = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", 1, true)
        if ok and #aiUserList > 0 then
            for _, ai in pairs(aiUserList) do
                -- 防止加入重复的机器人
                local exist_user = self:findUserByUid(ai.uid)
                if exist_user then
                    break
                end
                -- 防止超额，这里还要再判断下
                if self:getUserCnt() >= self.seat then
                    break
                end
                -- 如果已经有机器人了，也不会继续加机器人了
                --! domino只需要一个机器人
                local hasRobot = false
                for _, u in ipairs(self.users) do
                    if not u.cluster_info then
                        hasRobot = true
                        break
                    end
                end
                if hasRobot then
                    break
                end
                self:aiJoin(ai)
            end
        end
    end

    -- 将没有准备的人准备
    skynet.timeout(100, function()
        for _, u in ipairs(self.users) do
            if u.state ~= PDEFINE.PLAYER_STATE.Ready then
                -- 自动开始房间，或者机器人，则自动准备
                if self.conf.autoStart == 1 or not u.cluster_info then
                    LOG_DEBUG("DeskInfo:aiSingleJoin second userReady:", u.uid)
                    self:userReady(u.uid)
                end
            end
        end
        -- 如果还没有开始，则继续添加机器人，第二个机器人开始，就只要5-10秒了
        if self.state == PDEFINE.DESK_STATE.MATCH and self:checkCanStart() == 0 and self:getUserCnt() < self.seat then
            -- 如果已经有一个机器人了，就不再加入机器人了
            for _, u in ipairs(self.users) do
                if not u.cluster_info then
                    return
                end
            end
            -- 每过5-60秒，会随即添加一个机器人
            self.aiAutoFuc = ai_set_timeout(math.random(1500,3000), function()
                self:aiSingleJoin()
            end)
        end
    end)
end

-- 房间自动开启
function DeskInfo:autoStartGame(checkNow)
    if self.aiAutoFuc then
       self.aiAutoFuc() 
    end
    -- 每过15-30秒，会随即添加一个机器人
    local delayTime = math.random(1500,3000)
    if checkNow then
        delayTime = 200
    end
    self.aiAutoFuc = ai_set_timeout(delayTime, function()
        self:aiSingleJoin()
    end)
end

-- 更新mic状态
-- 有人退出房间的时候会调用
function DeskInfo:updateMicStatus(open)
    -- 判断真人数量
    local userCnt = 0
    local micCnt = 0
    local openChat = false
    for _, u in ipairs(self.users) do
        if u.cluster_info then
            userCnt = userCnt + 1
            if u.mic ~= 0 then
                micCnt = micCnt + 1
            end
        end
    end
    local notifyObj = {
        c=PDEFINE.NOTIFY.PLAYER_MIC_STATUS,
        code=PDEFINE.RET.SUCCESS,
        spcode=0,
        users={},
    }
    if userCnt > 1 and micCnt > 0 then
        openChat = true
    end
    for _, u in ipairs(self.users) do
        if u.cluster_info and openChat then
            u.joinChat = 1
        else
            u.joinChat = 0
        end
        local item = {uid=u.uid, mic=u.mic, joinChat=u.joinChat}
        table.insert(notifyObj.users, item)
    end
    for _, u in ipairs(self.views) do
        if u.cluster_info and openChat and u.seatid and u.seatid > 0 then
            u.joinChat = 1
        else
            u.joinChat = 0
        end
        local item = {uid=u.uid, mic=u.mic, joinChat=u.joinChat}
        table.insert(notifyObj.users, item)
    end
    self:broadcast(cjson.encode(notifyObj))
end

-- 机器人弃牌随机退出
function DeskInfo:onRobotDropLeave(uid)
    local deskInfo = self
    if deskInfo.state == PDEFINE.DESK_STATE.SETTLE then return end
    local user = deskInfo:findUserByUid(uid)
    if user and not user.cluster_info then
        if deskInfo:isMatchState() then
            -- 退出房间
            deskInfo:userExit(uid)
        else
            -- 部分游戏不允许中途退出
            if deskInfo:canNotExitInPlaying() then
                return
            end
            user.isexit = 1
            user.auto = 1

            local exitNotifyMsg = { c=PDEFINE.NOTIFY.PLAYER_EXIT_ROOM, code = PDEFINE.RET.SUCCESS, uid = uid, seatid = user.seatid, spcode = 0}
            deskInfo:broadcast(cjson.encode(exitNotifyMsg))
        end
    end
end

return DeskInfo