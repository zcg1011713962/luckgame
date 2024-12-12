local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local queue     = require "skynet.queue"
local snax = require "snax"
local player_tool = require "base.player_tool"
local baseDeskInfo = require "base.deskInfo"
local baseUser = require "base.user"
local baseAgent = require "base.agent"
local baseUtil = require "base.utils"
local record = require "base.record"
local utils = require "blackjack.blackjaclutils"
local BetStgy = require "betgame.betstgy"
local cs = queue()
local GAME_NAME = skynet.getenv("gamename") or "game"
local DEBUG = skynet.getenv("DEBUG")
local CMD = {}
local closeServer = false

---@type BetStgy
local stgy = BetStgy.new()

math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 7)))

---@type BaseDeskInfo
local deskInfo = nil  -- 桌子信息
---@type BaseAgent
local agent = nil  -- 游戏实例
local config = {
    -- 0x4* 为黑桃, 0x3*为红桃，, 0x2*为梅花, 0x1*为方块
    Cards = {
        0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,
        0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,
        0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,
        0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,
    },
    -- 发牌数量
    InitCardLen = 2,
}

--玩家状态
local PlayerState = {
    Wait = 1,       --等待状态
    Ready = 2,     --就绪状态(还没轮到操作)
    Bet = 3,    --下注状态
    Insure = 4,--选择保险状态（该状态必须选择投保还是拒保）
    Play = 5,   --玩牌状态(该状态可以选择停牌/要牌/加倍/拆牌)
    Stand = 6,  --停牌状态(操作已完成)
}

--游戏状态
local DeskState = {
    Match = PDEFINE.DESK_STATE.MATCH,      --匹配阶段（1）
    Ready = PDEFINE.DESK_STATE.READY,      --准备阶段（2）
    Play = PDEFINE.DESK_STATE.PLAY,       --玩牌阶段（3）
    Settle = PDEFINE.DESK_STATE.SETTLE,     --结算阶段(4)
    Bet = 5,        --下注阶段
    Insure = 6,  --选择保险阶段
}

-- 成功返回
local function warpResp(retobj)
    return PDEFINE.RET.SUCCESS, retobj
end

-- 检测用户，和检测状态
local function checkUserAndState(user, state, retobj)
    -- 检测用户
    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return false, retobj
    else
        retobj.seat   = user.seatid
        retobj.uid    = user.uid
    end
    -- 检测状态，只有非等待状态才能操作
    if user.state ~= state then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return false, retobj
    end
    return true, retobj
end

local function initDeskInfoRound()
    local turnid = math.random(1, deskInfo.seat)
    if deskInfo.round and deskInfo.round.turnid then turnid = deskInfo.round.turnid + 1 end
    if turnid > deskInfo.seat then turnid = 1 end
    deskInfo.round = {}
    deskInfo.round.bankercard = {} -- 庄家的牌，card[1]翻开,card[2]盖住,
    deskInfo.round.activeSeat = 0
    deskInfo.round.multiple = 1 --房间倍数
    deskInfo.round.turnid = turnid
    -- 随机堆上的牌
    deskInfo.round.cards = table.copy(config.Cards)
    shuffle(deskInfo.round.cards)
end

---@param user BaseUser
local function initUserRound(user)
    user.state             = PlayerState.Wait
    user.round = {}
    user.round.order       = 0
    user.round.tileid      = 1 -- 当前牌堆，有两堆牌时分别用1，2表示，单堆牌为1
    user.round.handcard    = {} --手中的牌(可能有两副)
    user.round.cardtype    = {} --牌型
    user.round.betcoin     = {} --押注金额
    user.round.insurecoin  = -1 --保险金额 -1表示未执行保险 ，0表示拒保， >0表示保险金额
    user.round.wincoin     = 0  --赢分
end

local function formatHandcard(handcard)
    local str = ""
    for _, cards in ipairs(handcard) do
        str = str .. "[" .. table.concat(cards, ",") .. "]"
    end
end

-- 自动下注
local function autoBet(uid)
    return cs(function()
        local user = deskInfo:findUserByUid(uid)
        user:clearTimer()

        if user.state ~= PlayerState.Bet then
            LOG_WARNING("状态错误: uid:", uid, ' seatid:', user.seatid, " state:", user.state)
            return
        end
        if user.cluster_info then
            if user.auto == 0 then
                user.auto = 1
                deskInfo:autoMsgNotify(user, 1, 0)
            end
        end

        local betcoin = deskInfo.minBet
        if not user.cluster_info then --机器人随机下注
            if math.random() < 0.5 then
                local coin = betcoin + math.floor(deskInfo.maxBet*math.random()*0.2)
                coin = math.min(coin, deskInfo.maxBet)
                if coin < user.coin then
                    betcoin = coin
                end
            end
        end
        local msg = {
            c = 25501,
            uid = uid,
            betcoin = betcoin,
        }
        local _, resp = CMD.bet(nil, msg)
        LOG_DEBUG("自动下注返回: ", uid, cjson.encode(resp))
        resp.is_auto = 1
        if resp.spcode == 0 then
            user:sendMsg(cjson.encode(resp))
        else
            LOG_ERROR("autoBet error", resp.spcode)
        end
    end)
end

--停牌
local function stand(user)
    local msg = {
        c = 25502,
        uid = user.uid,
    }
    local _, resp = CMD.stand(nil, msg)
    LOG_DEBUG("自动停牌返回: ", user.uid, cjson.encode(resp))
    resp.is_auto = 1
    if resp.spcode == 0 then
        user:sendMsg(cjson.encode(resp))
    else
        LOG_ERROR("stand error", resp.spcode)
    end
end

--要牌
local function hit(user)
    local msg = {
        c = 25503,
        uid = user.uid,
    }
    local _, resp = CMD.hit(nil, msg)
    LOG_DEBUG("自动要牌返回: ", user.uid, cjson.encode(resp))
    if resp.spcode == 0 then
        user:sendMsg(cjson.encode(resp))
    else
        LOG_ERROR("hit error", resp.spcode)
    end
end

--加倍
local function double(user)
    local msg = {
        c = 25504,
        uid = user.uid,
    }
    local _, resp = CMD.double(nil, msg)
    LOG_DEBUG("自动加倍返回: ", user.uid, cjson.encode(resp))
    if resp.spcode == 0 then
        user:sendMsg(cjson.encode(resp))
    else
        LOG_ERROR("double error", resp.spcode)
    end
end

--分牌
local function split(user)
    local msg = {
        c = 25505,
        uid = user.uid,
    }
    local _, resp = CMD.split(nil, msg)
    LOG_DEBUG("自动分牌返回: ", user.uid, cjson.encode(resp))
    if resp.spcode == 0 then
        user:sendMsg(cjson.encode(resp))
    else
        LOG_ERROR("split error", resp.spcode)
    end
end

local function checkDoubleCondition(user)
    local tileid = user.round.tileid
    local cardtype = user.round.cardtype[tileid]
    if #(user.round.handcard[tileid]) == 2   --两张牌
        and user.round.betcoin[tileid] < user.coin         --满足押注金额
        and not utils.IsAce(deskInfo.round.bankercard[1])  --庄家看起来点数不大
    then
        local rand = math.random()
        if (cardtype==10 or cardtype==11) and rand<0.75 then return true end
        if (cardtype==9  or cardtype==12) and rand<0.5 then return true end
    end
    return false
end

local function checkSplitCondition(user)
    local tileid = user.round.tileid
    if tileid==1 and #(user.round.handcard)==1 --只有1手牌
        and #(user.round.handcard[tileid]) == 2   --两张牌
        and utils.CalcPoint(user.round.handcard[tileid][1]) == utils.CalcPoint(user.round.handcard[tileid][2]) --牌值相等
        and user.round.betcoin[1] < user.coin   --满足押注金额
        and not utils.IsAce(deskInfo.round.bankercard[1])  --庄家看起来点数不大
    then
        return true
    end
    return false
end

--自动打牌（机器人）
local function autoPlay(uid)
    return cs(function()
        local user = deskInfo:findUserByUid(uid)
        user:clearTimer()

        if user.state ~= PlayerState.Play then
            LOG_WARNING("出牌状态错误: uid:", uid, ' seatid:', user.seatid, " state:", user.state)
            return
        end

        if user.cluster_info then
            if user.auto == 0 then
                user.auto = 1
                deskInfo:autoMsgNotify(user, 1, 0)
            end
        end

        local tileid = user.round.tileid
        local cardtype = user.round.cardtype[tileid]
        if user.cluster_info then  --玩家直接执行停牌操作
            if user.isexit == 0 and cardtype <= 11 then
                hit(user)
            else
                stand(user)
            end
        else  --机器人有策略的选择
            --如果点数小于16/17点，则要牌，否则停牌
            if checkSplitCondition(user) and utils.CalcPoint(user.round.handcard[tileid][1]) == 11 then --两张A
                split(user)
            elseif checkDoubleCondition(user) then
                double(user)
            elseif checkSplitCondition(user) and math.random() < 0.75 then
                split(user)
            elseif cardtype > 0 and cardtype < math.random(16, 17) then
                hit(user)
            else
                stand(user)
            end
        end
    end)
end

--自动保险
local function autoInsure(uid)
    return cs(function()
        local user = deskInfo:findUserByUid(uid)
        user:clearTimer()

        if user.state ~= PlayerState.Insure then
            LOG_WARNING("出牌状态错误: uid:", uid, ' seatid:', user.seatid, " state:", user.state)
            return
        end

        if user.cluster_info then
            if user.auto == 0 then
                user.auto = 1
                deskInfo:autoMsgNotify(user, 1, 0)
            end
        end

        local choice = 0
        if not user.cluster_info then  --机器人随机选择是否保险
            local insurecoin = math.round_coin(user.round.betcoin[1] / 2) --保险金额
            if user.coin > insurecoin then
                choice = math.random(0, 1)
            end
        end

        local msg = {
            c = 25506,
            uid = uid,
            choice = choice,
        }
        local _, resp = CMD.insure(nil, msg)
        LOG_DEBUG("自动保险返回: ", uid, cjson.encode(resp))
        resp.is_auto = 1
        if resp.spcode == 0 then
            user:sendMsg(cjson.encode(resp))
        else
            LOG_ERROR("autoInsure error", resp.spcode)
        end
    end)
end

-- 自动准备
local function autoReady(uid)
    return cs(function()
        LOG_DEBUG("自动准备 uid:".. uid)
        local user = deskInfo:findUserByUid(uid)

        if not user or user.state >= PDEFINE.PLAYER_STATE.Ready then
            return
        end
        user:clearTimer()

        local msg = {
            ['c'] = 25708,
            ['uid'] = uid,
        }
        CMD.ready(nil, msg)
    end)
end

local function getAiAutoTime(type, user, maxDelayTime)
    local minTime = 25
    local maxTime = 70
    if type == "autoPlay" then
        local tileid = user.round.tileid
        local cardtype = user.round.cardtype[tileid]
        if cardtype < 11 then  --快速
            maxTime = 50
        elseif utils.CalcPoint(user.round.handcard[tileid][1]) ~= utils.CalcPoint(user.round.handcard[tileid][2]) and cardtype>18 then
            maxTime = 60
        else
            minTime = 30
            maxTime = 90
        end
    end
    maxTime = math.min(maxTime, (maxDelayTime-2)*10)
    return math.random(minTime, maxTime)/10
end

-------- 设定玩家定时器 --------
local function userSetAutoState(type,autoTime,uid)
    autoTime = autoTime + 1
    deskInfo.round.expireTime = os.time() + autoTime
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    user:clearTimer()
    if not user.cluster_info then
        autoTime = getAiAutoTime(type, user, autoTime)
    end
    -- if DEBUG and user.cluster_info and user.isexit == 0 then
    --     autoTime = 1000000
    -- end

    -- 自动下注
    if type == "autoBet" then
        user:setTimer(autoTime, autoBet, uid)
    end
    -- 自动停牌
    if type == "autoPlay" then
        user:setTimer(autoTime, autoPlay, uid)
    end
    -- 自动保险
    if type == "autoInsure" then
        user:setTimer(autoTime, autoInsure, uid)
    end
    -- 自动准备
    if type == "autoReady" then
        user:setTimer(autoTime, autoReady, uid, true)
    end
end

local function setAutoReady(delayTime, uid)
    userSetAutoState('autoReady', delayTime, uid)
end

--! agent退出
function CMD.exit()
    collectgarbage("collect")
    skynet.exit()
end

-- 观战坐下
function CMD.seatDown(source, msg)
    return agent:seatDown(msg)
end

function CMD.chatIcon(source, msg)
    agent:actChatIcon(msg)
    return PDEFINE.RET.SUCCESS
end

--按order查找玩家
local function findUserByOrder(order)
    for _, user in pairs(deskInfo.users) do
        if user.round.order == order then
            return user
        end
    end
    return nil
end

--找到下一个未停牌的玩家
local function findNextUser(fromOrder)
    for order = fromOrder+1, deskInfo.seat do
        for _, user in pairs(deskInfo.users) do
            if user.round.order == order and user.state > PlayerState.Wait and user.state ~= PlayerState.Stand then
                return user
            end
        end
    end
    return nil
end

-- 开始发牌
local function roundStart(addTime)
    if not addTime then
        addTime = 1
    end
    deskInfo.curround = deskInfo.curround + 1
    LOG_DEBUG("roundStart: deskid:", deskInfo.uuid, deskInfo.curround)
    for _, user in pairs(deskInfo.users) do
        user.state = PlayerState.Ready  --所有人就绪
    end
   
    -- 切换桌子状态到下注阶段
    deskInfo:updateState(DeskState.Bet)

    local retobj = {}
    retobj.c = PDEFINE.NOTIFY.GAME_BET
    retobj.code = PDEFINE.RET.SUCCESS

    local delayTime = 10
    retobj.delayTime = delayTime
    retobj.orders = {}
    -- 确定玩家序号
    local order = 1
    local seatid = deskInfo.round.turnid
    for i = 1, deskInfo.seat do
        local user = deskInfo:findUserBySeatid(seatid)
        if user then
            --分配序号
            user.round.order = order
            order = order + 1

            -- 切换到下注阶段
            user.state = PlayerState.Bet
            -- 设置定时器
            userSetAutoState('autoBet', delayTime+1, user.uid)

            table.insert(retobj.orders, {uid=user.uid, seatid=user.seatid, order=user.round.order})
        end
        seatid = seatid + 1
        if seatid > deskInfo.seat then seatid = 1 end
    end
    deskInfo:broadcast(cjson.encode(retobj))
end

-- 创建房间后第1次开始游戏
---@param delayTime integer 用于指定发牌前的延迟时间
local function startGame(delayTime)
    if deskInfo.state ~= PDEFINE.DESK_STATE.MATCH then
        return
    end
    LOG_INFO("startGame:", delayTime)
    -- 调用基类的开始游戏
    deskInfo:stopAutoKickOut()
    -- 这里需要先切了，反之有人退出
    deskInfo:updateState(DeskState.Bet, true)
    local uids = {}
    for _, user in pairs(deskInfo.users) do
        if user.cluster_info then
            table.insert(uids, user.uid)
        end
    end
    pcall(cluster.send, "master", ".mgrdesk", "lockPlayer", deskInfo.deskid, uids, deskInfo.gameid, deskInfo.conf.roomtype)

    -- 初始化桌子信息
    deskInfo:initDeskRound()
    -- LOG_DEBUG("deskInfo ", deskInfo)

    delayTime = (delayTime or 0) * 100 + 10
    skynet.timeout(delayTime, function()
        -- 调用基类的新的一轮
        deskInfo:roundStart()
        roundStart()
    end)
end

local function aiJoin(maxNum)
    if deskInfo.private.aijoin == 0 then return end

    maxNum = maxNum or math.random(2, 5)
    local num = maxNum - #deskInfo.users
    local curNum = num
    if curNum > 2 then
        curNum = 2
    end
    if curNum > 0 then
        local ok, aiUserList = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", curNum, true)
        if ok and not table.empty(aiUserList) then
            for _, ai in pairs(aiUserList) do
                if #deskInfo.users == maxNum then
                    deskInfo:RecycleAi(ai)
                    break
                end
                -- 防止加入重复的机器人
                local exist_user = deskInfo:findUserByUid(ai.uid)
                if not exist_user then
                    local seatid = deskInfo:getSeatId()
                    if not seatid then
                        deskInfo:RecycleAi(ai)
                        break
                    end
                    ai.ssid = deskInfo.ssid

                    local userObj = baseUser(ai, deskInfo)
                    -- 初始化金币
                    userObj.coin = deskInfo:initAiCoin()
                    userObj:init(seatid, deskInfo)
                    deskInfo:insertUser(userObj)
                    deskInfo:broadcastPlayerEnterRoom(userObj.uid)
                    LOG_DEBUG("加入机器人: seatid->", userObj.seatid, "uid->", userObj.uid, "state->", deskInfo.state)
                end
            end
        end
        pcall(cluster.send, "node", ".chat", "changeDeskInfoUsers", deskInfo.deskid, deskInfo.gameid, deskInfo.users, deskInfo.cid)
    end

    if curNum < num and #deskInfo.users < maxNum then
        skynet.timeout(math.random(100, 150), function ()
            aiJoin(maxNum)
        end)
    else
        if #deskInfo.users == deskInfo.seat and deskInfo.curround == 0 then
            startGame(1)
         end
    end

    return PDEFINE.RET.SUCCESS, num
end

local function roundNext()
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        -- 匹配方倒计时开始下一轮游戏
        if deskInfo:hasRealPlayer() then
            if #deskInfo.users < deskInfo.seat then
                skynet.timeout(math.random(100,300), function()
                    aiJoin()
                end)
            end
            deskInfo.func.startGame()
        else
            deskInfo:destroy()
        end
    else
        if deskInfo:hasRealPlayer() then
            for _, u in ipairs(deskInfo.users) do
                if u.state ~= PDEFINE.PLAYER_STATE.Ready then
                    if deskInfo.conf.autoStart == 1 or not u.cluster_info then
                        LOG_DEBUG("DeskInfo:resetDesk userReady:", u.uid)
                        deskInfo:userReady(u.uid)
                    end
                end
            end
            if deskInfo:getUserCnt() == deskInfo.seat then
                deskInfo:setAutoKickOut()
            end
        else
            local uids = {}
            for _, u in ipairs(deskInfo.users) do
                table.insert(uids, u.uid)
            end
            for _, uid in ipairs(uids) do
                deskInfo:userExit(uid)
            end
        end
    end
end

-- 重置桌子，准备下一大局
local function resetDesk(delayTime, isDismiss)
    local now = os.time()
    deskInfo.uuid = deskInfo.deskid..now  -- 更改uuid
    deskInfo:newIssue()

    local exitedUsers = {}
    local uids = {}
    local killUsers = {}  -- 需要踢掉的人
    local offlineUsers = {}  -- 离线的人
    local dismissUsers = {}  -- 解散踢人
    local autoUsers = {}  --托管的人
    for _, user in ipairs(deskInfo.users) do
        -- 游戏大局结束之后，解禁所有玩家，可以加入其它房间
        table.insert(uids, user.uid)
        if not user.cluster_info and (now > user.leavetime) then
            user.isexit = 1
        end
        -- 判断金币是否够, 或者已经离线
        local minCoin = deskInfo.conf.mincoin
        if isDismiss then
            table.insert(dismissUsers, {uid=user.uid, seatid=user.seatid})
        elseif user.isexit == 1 then
            table.insert(exitedUsers, {uid=user.uid, seatid=user.seatid})
        elseif user.offline == 1 then  -- 放这里，会清除cluster信息
            table.insert(offlineUsers, {uid=user.uid, seatid=user.seatid})
        elseif user.coin < minCoin then
            table.insert(killUsers, {uid=user.uid, seatid=user.seatid})
        elseif user.auto == 1 then
            table.insert(autoUsers, {uid=user.uid, seatid=user.seatid})
        end
        user.state             = PDEFINE.PLAYER_STATE.Wait
        user.autoStartTime     = nil -- 托管开始时间
        if user.auto == 1 then
            user.autoStartTime = os.time()
        end
        user.autoTotalTime     = 0 -- 当局游戏处于托管的时间
    end

    -- 将已经退出的玩家删除，并且广播
    for _, user in ipairs(exitedUsers) do
        deskInfo:userExit(user.uid)
    end

    -- 将需要剔除的玩家剔除，并且广播
    for _, user in ipairs(killUsers) do
        local duser = deskInfo:findUserByUid(user.uid)
        deskInfo:userExit(user.uid, PDEFINE.RET.ERROR.COIN_NOT_ENOUGH)
        if duser and duser.cluster_info then
            pcall(cluster.send, duser.cluster_info.server, duser.cluster_info.address, "deskBack", deskInfo.gameid, deskInfo.deskid) --释放桌子对象
        end
    end

    -- 离线的玩家，从桌子信息中删除用户
    for _, user in ipairs(offlineUsers) do
        deskInfo:userExit(user.uid, PDEFINE.RET.ERROR.USER_OFFLINE)
        local duser = deskInfo:findUserByUid(user.uid)
        if duser and duser.cluster_info then
            pcall(cluster.send, duser.cluster_info.server, duser.cluster_info.address, "deskBack", deskInfo.gameid, deskInfo.deskid)
        end
        pcall(cluster.send, "master", ".agentdesk", "removeDesk", user.uid, deskInfo.deskid)
    end

    -- 解散踢人
    for _, user in ipairs(dismissUsers) do
        for _, u in ipairs(deskInfo.users) do
            if u.uid == user.uid and u.cluster_info then
                pcall(cluster.send, u.cluster_info.server, u.cluster_info.address, "deskBack", deskInfo.gameid, deskInfo.deskid)
            end
        end
        pcall(cluster.send, "master", ".agentdesk", "removeDesk", user.uid, deskInfo.deskid)
        deskInfo:userExit(user.uid, user.seatid, PDEFINE.RET.ERROR.GAME_ALREADY_DELTE)
    end

    --托管踢人
    if not DEBUG then
        for _, user in ipairs(autoUsers) do
            local duser = deskInfo:findUserByUid(user.uid)
            deskInfo:userExit(user.uid, PDEFINE.RET.ERROR.AUTO_COUNT_LIMIT)
            if duser and duser.cluster_info then
                pcall(cluster.send, duser.cluster_info.server, duser.cluster_info.address, "deskBack", deskInfo.gameid, deskInfo.deskid) --释放桌子对象
            end
            pcall(cluster.send, "master", ".agentdesk", "removeDesk", user.uid, deskInfo.deskid)
        end
    end

    -- 切换回匹配状态
    deskInfo:updateState(DeskState.Match)
    deskInfo.waitTime = delayTime
    deskInfo.beginTime = skynet.now() + deskInfo.waitTime*100
    pcall(cluster.send, "master", ".mgrdesk", "changDeskSeat", deskInfo.name, deskInfo.gameid, deskInfo.deskid, deskInfo:getUserCnt(), deskInfo:getRealUserCnt())
    deskInfo.uuid = deskInfo.deskid..now  -- 更改uuid
    deskInfo.conf.create_time = now
    deskInfo:writeDB()  -- 写入数据库
    deskInfo:initDeskRound()

    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        delayTime = delayTime + 2
    end
    skynet.timeout(delayTime*100+20, function()
        cs(function ()
            roundNext()
        end)
    end)
end

-- 游戏结束
local function gameOver(isDismiss, delayTime)
    local uids = {}
    for _, user in ipairs(deskInfo.users) do
        if user.cluster_info then
            table.insert(uids, user.uid)
        end
    end
    -- 需要将玩家解禁，可以退出后加入其它房间
    pcall(cluster.send, "master", ".mgrdesk", "unlockPlayer", deskInfo.deskid, uids, deskInfo.gameid, deskInfo.conf.roomtype)

    if isDismiss then
        local notify_retobj = { c=PDEFINE.NOTIFY.NOTIFY_SYS_KICK, code = PDEFINE.RET.SUCCESS, deskid=deskInfo.deskid }
        deskInfo:broadcast(cjson.encode(notify_retobj))
        deskInfo:destroy()
    else
        resetDesk(delayTime, isDismiss)  --8秒结束时间
    end
end


local function getRandomResult(shuffle)
    local bankercards = {}
    local bankertypes = {}

    local isInsure = utils.IsAce(deskInfo.round.bankercard[1])  --是否保险
    local bankercard = {deskInfo.round.bankercard[1], deskInfo.round.bankercard[2]}
    local cards = table.copy(deskInfo.round.cards)
    if shuffle then
        table.shuffle(cards)
        for i = #cards, 1, -1 do
            if (not isInsure) or (utils.CalcPoint(cards[2]) ~= 10) then
                bankercard[2] = table.remove(cards, i)
                break
            end
        end
    end

    table.insert(bankercards, table.copy(bankercard))
    local bankertype = utils.CalcType(bankercard)
    table.insert(bankertypes, bankertype)
    -- 庄家继续要牌，直到不小于17点
    while bankertype > 0 and bankertype < 17 do
        local card = table.remove(cards)
        table.insert(bankercard, card)
        bankertype = utils.CalcType(bankercard)
        --每次要牌结果都发到前端
        table.insert(bankercards, table.copy(bankercard))
        table.insert(bankertypes, bankertype)
    end
    return {
        bankercards = bankercards,
        bankertypes = bankertypes,
        bankercard = bankercard,
        bankertype = bankertype
    }
end

local function tryGetRestrictiveBankerCard(retobj)
    local res = getRandomResult()

    local bankertype = utils.CalcType(deskInfo.round.bankercard)
    if bankertype == utils.CardType.BalckJack then
        return res
    end

    --是否需要控制
    local restriction = 0 --0：随机 -1：输 1：赢
    if stgy:isValid() then
        stgy:reload()
        restriction = stgy:getRestriction()
    end
    LOG_DEBUG("restriction", restriction)
    if restriction ~= -1 then
        return res
    end

    --需要控制
    local maxUserCardType = 0
    for _, user in ipairs(deskInfo.users) do
        if user.cluster_info and user.state > PlayerState.Wait and #user.round.betcoin > 0 then
            for i, cardtype in ipairs(user.round.cardtype) do
                maxUserCardType = math.max(maxUserCardType, cardtype)
            end
        end
    end
    for tryCnt = 1, 200 do
        if res.bankertype >= maxUserCardType then
            return res
        end
        res = getRandomResult(true)
    end
    return res
end

-- 此轮游戏结束
local function roundOver()
    deskInfo:updateState(DeskState.Settle)
    -- 清除玩家定时器
    for _, user in ipairs(deskInfo.users) do
        user:clearTimer()
    end

    local retobj = {}
    retobj.c = PDEFINE.NOTIFY.GAME_ROUND_OVER
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.waitTime = 8
    retobj.settle = {}

    local res = tryGetRestrictiveBankerCard()
    retobj.bankercard = res.bankercards
    retobj.bankertype = res.bankertypes

    deskInfo.round.bankercard = res.bankercard
    local bankertype = res.bankertype
    local totalBetCoin = 0
    local totalTaxCoin = 0
    -- 系统赢取的金币
    local playertotalwin = 0
    local playertotalbet = 0
    for _, user in ipairs(deskInfo.users) do
        if user.state > PlayerState.Wait and #user.round.betcoin > 0 then
            user.round.wincoin = 0
            local res = {
                seatid = user.seatid,
                wincoin = {},
            }
            local betcoin = 0
            for i, cardtype in ipairs(user.round.cardtype) do
                if user.round.betcoin[i] then
                    local coin = user.round.betcoin[i] * 2
                    local wincoin = 0
                    if cardtype > bankertype then
                        wincoin = coin
                        if cardtype >= utils.CardType.FiveCard then  --blackjack和五小是1.5倍，其余是1倍
                            wincoin = wincoin + user.round.betcoin[i]/2
                        end
                    elseif cardtype ~= utils.CardType.Boom and cardtype == bankertype then
                        wincoin = user.round.betcoin[i]  --平局退还押注
                    else
                        wincoin = 0
                    end
                    table.insert(res.wincoin, wincoin)
                    user.round.wincoin = user.round.wincoin + wincoin
                    betcoin = betcoin + user.round.betcoin[i]
                else
                    LOG_ERROR("betcoin error", user.round.cardtype, user.round.betcoin, user.round.handcard)
                end
            end
            local tax = 0
            if user.round.wincoin > betcoin and deskInfo.taxrate > 0 then
                tax = math.round_coin(deskInfo.taxrate * (user.round.wincoin - betcoin))
                user.round.wincoin = user.round.wincoin - tax
            end
            if user.round.wincoin > 0 then
                user:notifyLobby(user.round.wincoin, user.uid, deskInfo.gameid)
                user:changeCoin(PDEFINE.ALTERCOINTAG.WIN, user.round.wincoin, deskInfo)
            end
            if user.cluster_info and user.istest ~= 1 then
                playertotalbet = playertotalbet + betcoin
                playertotalwin = playertotalwin + user.round.wincoin
            end
            if betcoin > 0 then
                local result = {bankercard=deskInfo.round.bankercard, playercard=user.round.handcard, remark="round"}
                record.betGameLog(deskInfo, user, betcoin, user.round.wincoin, result, tax)
            end
            res.coin = user.coin
            table.insert(retobj.settle, res)

            totalTaxCoin = totalTaxCoin + tax
            totalBetCoin = totalBetCoin + betcoin
            retobj.waitTime = retobj.waitTime + 0.3 * #(user.round.cardtype)  --增加结算时间
        end
    end

    if stgy:isValid() then
        stgy:update(playertotalbet, playertotalwin)
    end

    retobj.waitTime = math.floor(retobj.waitTime + 0.5)

    --结算小局记录
    local winner = 0
    local multiple = 1
    local allCards = {}
    for _, user in ipairs(deskInfo.users) do
        table.insert(allCards, {
            uid = user.uid,
            cards = user.round.handcard
        })
    end
    deskInfo:recordDB(0, winner, retobj.settle, allCards, multiple)

    -- 私人房需要给房主分成
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        local totalbet = (deskInfo.private.totalbet or 0) + totalBetCoin
        deskInfo.private.totalbet = totalbet
        pcall(cluster.send, "master", ".balprivateroommgr", "gameOver", deskInfo.deskid, deskInfo.owner, totalTaxCoin, deskInfo.bet, totalbet)
    end

    deskInfo:broadcast(cjson.encode(retobj))

    local notifyMsg = function ()
        local dismiss = isMaintain()  -- 维护强行大结算
        gameOver(dismiss, retobj.waitTime)
    end
    skynet.timeout(1, notifyMsg)

    return PDEFINE.RET.SUCCESS
end

-- 保险结算
local function insureOver()
    -- 清除玩家定时器
    for _, user in ipairs(deskInfo.users) do
        user:clearTimer()
    end
    local retobj = {}
    retobj.c = PDEFINE.NOTIFY.GAME_INSURE_OVER
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.waitTime = 8

    local bankertype = utils.CalcType(deskInfo.round.bankercard)
    if bankertype == utils.CardType.BalckJack then
        -- 系统赢取的金币
        local playertotalwin = 0
        local playertotalbet = 0
        --如果庄家是黑杰克
        retobj.res = 1
        retobj.bankercard = deskInfo.round.bankercard
        retobj.bankertype = bankertype

        deskInfo:updateState(DeskState.Settle)

        --买保险的玩家获得2倍保险金额
        retobj.settle = {}
        local totalBetCoin = 0
        local totalTaxCoin = 0
        for _, user in ipairs(deskInfo.users) do
            if user.state > PlayerState.Wait and user.round.insurecoin >= 0 then
                local coin = user.round.insurecoin * 3  --赢得投保+押注的钱
                if coin > 0 then
                    user.round.wincoin = coin
                else
                    user.round.wincoin = 0
                end
                local betcoin = user.round.betcoin[1] + user.round.insurecoin
                local tax = 0
                if user.round.wincoin > betcoin and deskInfo.taxrate > 0 then
                    tax = math.round_coin(deskInfo.taxrate * (user.round.wincoin - betcoin))
                    user.round.wincoin = user.round.wincoin - tax
                end
                if user.round.wincoin > 0 then
                    user:notifyLobby(user.round.wincoin, user.uid, deskInfo.gameid)
                    user:changeCoin(PDEFINE.ALTERCOINTAG.WIN, coin, deskInfo)
                end
                if user.cluster_info and user.istest ~= 1 then
                    playertotalbet = playertotalbet + betcoin
                    playertotalwin = playertotalwin + user.round.wincoin
                end
                local result = {bankercard=deskInfo.round.bankercard, playercard=user.round.handcard, remark="insure"}
                record.betGameLog(deskInfo, user, betcoin, user.round.wincoin, result, tax)

                table.insert(retobj.settle, {
                    seatid = user.seatid,
                    wincoin = user.round.wincoin,
                    coin = user.coin
                })

                totalTaxCoin = totalTaxCoin + tax
                totalBetCoin = totalBetCoin + betcoin
            end
        end

        if stgy:isValid() then
            stgy:update(playertotalbet, playertotalwin)
        end

        --结算小局记录
        local winner = 0
        local multiple = 1
        local allCards = {}
        for _, user in ipairs(deskInfo.users) do
            table.insert(allCards, {
                uid = user.uid,
                cards = user.round.handcard
            })
        end
        deskInfo:recordDB(0, winner, retobj.settle, allCards, multiple)

        -- 私人房需要给房主分成
        if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
            local totalbet = (deskInfo.private.totalbet or 0) + totalBetCoin
            deskInfo.private.totalbet = totalbet
            pcall(cluster.send, "master", ".balprivateroommgr", "gameOver", deskInfo.deskid, deskInfo.owner, totalTaxCoin, deskInfo.bet, totalbet)
        end

        deskInfo:broadcast(cjson.encode(retobj))

        local notifyMsg = function ()
            local dismiss = isMaintain()  -- 维护强行大结算
            gameOver(dismiss, retobj.waitTime)
        end
        skynet.timeout(1, notifyMsg)  --进入下一轮

    else
        --游戏记录
        for _, user in ipairs(deskInfo.users) do
            if user.state > PlayerState.Wait and user.round.insurecoin > 0 then
                local betcoin = user.round.insurecoin
                local result = {bankercard=deskInfo.round.bankercard, playercard=user.round.handcard, remark="insure"}
                record.betGameLog(deskInfo, user, betcoin, 0, result, 0)
            end
        end

        --如果庄家不是黑杰克，玩家将输掉保险赌金，游戏照常继续
        retobj.res = 0

        deskInfo:updateState(DeskState.Play)
        for _, user in pairs(deskInfo.users) do
            if user.state > PlayerState.Wait and user.round.cardtype[1] >= utils.CardType.P21 then  --超过21点直接停牌
                user.state = PlayerState.Stand
            end
        end
        local delayTime = deskInfo.delayTime
        local activeUser = findNextUser(0) --从序号号最小的玩家开始
        if not activeUser then  --所有玩家已完成，进入结算阶段
            deskInfo.round.activeSeat = 0
            retobj.activeSeat = 0
            retobj.activeState = 0
            retobj.activeTile = 0
            skynet.timeout(100, function()
                agent:roundOver()
            end)
        else
            activeUser.state = PlayerState.Play
            userSetAutoState('autoPlay', delayTime, activeUser.uid)

            deskInfo.round.activeSeat = activeUser.seatid
            retobj.activeSeat = activeUser.seatid
            retobj.activeState = activeUser.state
            retobj.activeTile = activeUser.round.tileid
        end
        retobj.delayTime = delayTime

        deskInfo:broadcast(cjson.encode(retobj))
    end

    return PDEFINE.RET.SUCCESS
end


--发牌
local function dealCards()
    if #(deskInfo.round.bankercard) > 0 then return end

    local retobj = {
        c = PDEFINE.NOTIFY.GAME_DEAL,
        code = PDEFINE.RET.SUCCESS,
        seats = {},
        handcards = {},
        cardtypes = {}
    }

    --庄家发两张
    for i = 1, 2 do
        table.insert(deskInfo.round.bankercard, table.remove(deskInfo.round.cards))
        -- if DEBUG and math.random()<0.6 then
        --     local ace = {0x1E,0x2E,0x2E,0x4E}
        --     deskInfo.round.bankercard[1] = ace[math.random(1, #ace)]
        -- end
    end
    retobj.bankercard = {deskInfo.round.bankercard[1], 0}

    for order = 1, deskInfo.seat do  --按顺序发牌
        local user = findUserByOrder(order)
        if user and #user.round.betcoin > 0 then
            user.state = PlayerState.Ready  --切换的就绪状态
            local cards = {}
            for i = 1, 2 do
                table.insert(cards, table.remove(deskInfo.round.cards))
            end
            -- if DEBUG and user.cluster_info and math.random()<0.6 then
            --     local testcase = {{0x17,0x27}, {0x23,0x33}, {0x14,0x44}, {0x26,0x36}}
            --     cards = testcase[math.random(1, #testcase)]
            -- end
            table.insert(user.round.handcard, cards)
            table.insert(user.round.cardtype, utils.CalcType(cards))
            user.round.tileid = 1
            local showcardtypes = {}
            table.insert(showcardtypes, utils.CalcShowType(cards))

            table.insert(retobj.seats, user.seatid)
            table.insert(retobj.handcards, user.round.handcard)
            table.insert(retobj.cardtypes, showcardtypes)
        end
    end

    local delayTime = deskInfo.delayTime
    local activeUser = nil
    if utils.IsAce(deskInfo.round.bankercard[1]) then --如果庄家明牌是A，则玩家选择是否保险
        deskInfo:updateState(DeskState.Insure)
        activeUser = findNextUser(0) --从序号号最小的玩家开始
        activeUser.state = PlayerState.Insure
        userSetAutoState('autoInsure', delayTime, activeUser.uid)
    else
        deskInfo:updateState(DeskState.Play)
        for _, user in pairs(deskInfo.users) do
            if user.state > PlayerState.Wait and user.round.cardtype[1] >= utils.CardType.P21 then  --超过21点直接停牌
                user.state = PlayerState.Stand
            end
        end
        activeUser = findNextUser(0) --从序号号最小的玩家开始
        if not activeUser then  --所有玩家已完成，进入结算阶段
            deskInfo.round.activeSeat = 0
            retobj.activeSeat = 0
            retobj.activeState = 0
            retobj.activeTile = 0
            skynet.timeout(200, function()
                agent:roundOver()
            end)
        else
            activeUser.state = PlayerState.Play
            userSetAutoState('autoPlay', delayTime, activeUser.uid)
        end
    end
    if activeUser then
        deskInfo.round.activeSeat = activeUser.seatid
        retobj.activeSeat = activeUser.seatid
        retobj.activeState = activeUser.state
        retobj.activeTile = activeUser.round.tileid
    end
    retobj.delayTime = delayTime

    deskInfo:broadcast(cjson.encode(retobj))
end

-- 下注
function CMD.bet(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    local betcoin = math.round_coin(tonumber(recvobj.betcoin) or 0)
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.betcoin= betcoin
    retobj.spcode = 0

    local ok
    ok, retobj = checkUserAndState(user, PlayerState.Bet, retobj)
    if not ok then
        return warpResp(retobj)
    end

    -- 判断金额
    if betcoin <= 0 or betcoin > user.coin then
        retobj.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        return warpResp(retobj)
    end
    if betcoin < deskInfo.minBet or betcoin > deskInfo.maxBet then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        return warpResp(retobj)
    end
    -- 清除计时器
    user:clearTimer()
    --扣除下注
    user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -betcoin, deskInfo)
    user.round.betcoin = {betcoin}
    user.state = PlayerState.Ready

    retobj.seat = user.seatid
    retobj.userState = user.state
    deskInfo:broadcast(cjson.encode(retobj), uid)

    --如果所有人都提交完成
    local done = true
    for _, u in ipairs(deskInfo.users) do
        if u.state > PlayerState.Wait and #u.round.betcoin <= 0 then
            done = false
            break
        end
    end
    if done then
        skynet.timeout(50, dealCards)
    end

    return warpResp(retobj)
end

--下一名玩家开始操作(如果还有牌堆没操作完，则继续操作下一牌堆)
local function TurnToNext(user, retobj)
    local tileid = user.round.tileid - 1
    if tileid > 0 and user.round.cardtype[tileid] < utils.CardType.P21 then
        user.round.tileid = tileid
        -- 下一个牌堆
        --刷新定时器
        userSetAutoState('autoPlay', retobj.delayTime, user.uid)
        --继续操作
        retobj.activeSeat = user.seatid
        retobj.activeState = user.state
        retobj.activeTile = user.round.tileid
    else
        user.round.tileid = 0
        user.state = PlayerState.Stand
        --下一名玩家
        local activeUser = findNextUser(user.round.order)
        if not activeUser then  --所有玩家已完成，进入结算阶段
            deskInfo.round.activeSeat = 0
            retobj.activeSeat = 0
            retobj.activeState = 0
            retobj.activeTile = 0
            skynet.timeout(100, function()
                agent:roundOver()
            end)
        else
            activeUser.state = PlayerState.Play
            --定时器
            userSetAutoState('autoPlay', retobj.delayTime, activeUser.uid)
            --继续操作
            deskInfo.round.activeSeat = activeUser.seatid
            retobj.activeSeat = activeUser.seatid
            retobj.activeState = activeUser.state
            retobj.activeTile = activeUser.round.tileid
        end
    end

    return retobj
end

-- 停牌
function CMD.stand(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    local ok
    ok, retobj = checkUserAndState(user, PlayerState.Play, retobj)
    if not ok then
        return warpResp(retobj)
    end

    -- 清除计时器
    user:clearTimer()

    retobj.seat = user.seatid
    retobj.tileid = user.round.tileid
    retobj.delayTime = deskInfo.delayTime

    --下一个玩家
    retobj = TurnToNext(user, retobj)

    retobj.userState = user.state
    deskInfo:broadcast(cjson.encode(retobj), uid)

    return warpResp(retobj)
end

-- 要牌
function CMD.hit(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    local ok
    ok, retobj = checkUserAndState(user, PlayerState.Play, retobj)
    if not ok then
        return warpResp(retobj)
    end

    -- 判断牌数量
    local tileid = user.round.tileid
    if user.round.cardtype[tileid] == 0 or user.round.cardtype[tileid] >= utils.CardType.P21 then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        retobj.errmsg = "card is boom or cardtype >= 21"
        return warpResp(retobj)
    end

    retobj.seat = user.seatid
    retobj.tileid = tileid
    retobj.delayTime = deskInfo.delayTime

    -- 清除计时器
    user:clearTimer()

    --加牌
    local card = table.remove(deskInfo.round.cards)
    local cards = user.round.handcard[tileid]
    table.insert(cards, card)
    local cardtype = utils.CalcType(cards)
    user.round.cardtype[tileid] = cardtype

    if cardtype == 0 or cardtype >= utils.CardType.P21 then  --爆牌，或者达成21点
        --轮到下一位
        retobj = TurnToNext(user, retobj)
    else
        --可以继续要牌
        --刷新定时器
        userSetAutoState('autoPlay', retobj.delayTime, user.uid)
        --继续操作
        retobj.activeSeat = user.seatid
        retobj.activeState = user.state
        retobj.activeTile = user.round.tileid
    end

    --更新后的状态
    retobj.userState = user.state
    retobj.handcard = user.round.handcard
    local showcardtypes = {}
    for _, handcard in ipairs(user.round.handcard) do
        table.insert(showcardtypes, utils.CalcShowType(handcard))
    end
    retobj.cardtype = showcardtypes

    deskInfo:broadcast(cjson.encode(retobj), uid)

    return warpResp(retobj)
end

-- 加倍
function CMD.double(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    local ok
    ok, retobj = checkUserAndState(user, PlayerState.Play, retobj)
    if not ok then
        return warpResp(retobj)
    end
    local tileid = user.round.tileid
    if #(user.round.handcard[tileid]) ~= 2 then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        retobj.errmsg = "cards more than 2"
        return warpResp(retobj)
    end

    -- 判断金额
    local betcoin = user.round.betcoin[tileid]
    if betcoin <= 0 or betcoin > user.coin then
        retobj.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        return warpResp(retobj)
    end

    retobj.seat = user.seatid
    retobj.tileid = tileid
    retobj.delayTime = deskInfo.delayTime

    -- 清除计时器
    user:clearTimer()

    --扣除下注
    user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -betcoin, deskInfo)
    user.round.betcoin[tileid] = betcoin*2

    --加倍后补一张牌
    local card = table.remove(deskInfo.round.cards)
    local cards = user.round.handcard[tileid]
    table.insert(cards, card)
    local cardtype = utils.CalcType(cards)
    user.round.cardtype[tileid] = cardtype

    --轮到下一位
    retobj = TurnToNext(user, retobj)

    --更新后的状态
    retobj.userState = user.state
    retobj.handcard = user.round.handcard
    retobj.cardtype = user.round.cardtype
    retobj.betcoin = user.round.betcoin

    deskInfo:broadcast(cjson.encode(retobj), uid)

    return warpResp(retobj)
end

-- 拆牌
function CMD.split(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    local ok
    ok, retobj = checkUserAndState(user, PlayerState.Play, retobj)
    if not ok then
        return warpResp(retobj)
    end

    if #(user.round.handcard) ~= 1 or #(user.round.handcard[1]) ~= 2 then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        retobj.errmsg = "cards more than 2"
        return warpResp(retobj)
    end

    local tileid = 1
    local cards = user.round.handcard[tileid]
    if utils.CalcPoint(cards[1]) ~= utils.CalcPoint(cards[2]) then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        retobj.errmsg = "points not equal"
        return warpResp(retobj)
    end

    -- 判断金额
    local betcoin = user.round.betcoin[1]
    if betcoin <= 0 or betcoin > user.coin then
        retobj.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        return warpResp(retobj)
    end

    retobj.seat = user.seatid
    retobj.tileid = tileid
    retobj.delayTime = deskInfo.delayTime

    -- 清除计时器
    user:clearTimer()

    --扣除下注
    user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -betcoin, deskInfo)
    user.round.betcoin = {betcoin, betcoin}

    --拆分牌组
    user.round.handcard = {{cards[1]}, {cards[2]}}
    for i = 1, 2 do
        table.insert(user.round.handcard[i], table.remove(deskInfo.round.cards))
        user.round.cardtype[i] = utils.CalcType(user.round.handcard[i])
    end
    --拆分后先操作牌堆2
    user.round.tileid = 2
    if user.round.cardtype[1] >= utils.CardType.P21 and user.round.cardtype[2] >= utils.CardType.P21 then  --如果两手牌都是21点
        --跳两次
        user.round.tileid = user.round.tileid - 1
        retobj = TurnToNext(user, retobj)
    elseif user.round.cardtype[2] >= utils.CardType.P21 then  --如果第一手21点
        --跳到下一位
        retobj = TurnToNext(user, retobj)
    else
        --刷新定时器
        userSetAutoState('autoPlay', retobj.delayTime, user.uid)
        --继续操作
        retobj.activeSeat = user.seatid
        retobj.activeState = user.state
        retobj.activeTile = user.round.tileid
    end

    --更新后的状态
    retobj.userState = user.state
    retobj.handcard = user.round.handcard
    local showcardtypes = {}
    for _, handcard in ipairs(user.round.handcard) do
        table.insert(showcardtypes, utils.CalcShowType(handcard))
    end
    retobj.cardtype = showcardtypes

    deskInfo:broadcast(cjson.encode(retobj), uid)

    return warpResp(retobj)
end

-- 投保/拒保
function CMD.insure(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    local choice = math.sfloor(recvobj.choice)
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    local ok
    ok, retobj = checkUserAndState(user, PlayerState.Insure, retobj)
    if not ok then
        return warpResp(retobj)
    end

    local insurecoin = math.round_coin(user.round.betcoin[1] / 2) --保险金额
    if choice ~= 0 then  --投保
        if insurecoin > user.coin then
            retobj.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
            return warpResp(retobj)
        end
    end

    -- 清除计时器
    user:clearTimer()
    user.state = PlayerState.Ready

    retobj.seat = user.seatid
    retobj.delayTime = deskInfo.delayTime

    if choice == 0 then  --拒保
        user.round.insurecoin = 0
    else
        user.round.insurecoin = insurecoin
        --扣除下注
        user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -insurecoin, deskInfo)
    end

    --下一名玩家
    local activeUser = findNextUser(user.round.order)
    if not activeUser then  --所有玩家已完成保险，进入开保险阶段
        retobj.activeSeat = 0
        retobj.activeState = 0
        skynet.timeout(100, function()
            insureOver()
        end)
    else
        activeUser.state = PlayerState.Insure
        deskInfo.round.activeSeat = activeUser.seatid
        --定时器
        userSetAutoState('autoInsure', retobj.delayTime, activeUser.uid)
        --继续操作
        retobj.activeSeat = activeUser.seatid
        retobj.activeState = activeUser.state
    end

    retobj.choice = choice
    retobj.insurecoin = user.round.insurecoin
    retobj.userState = user.state
    deskInfo:broadcast(cjson.encode(retobj), uid)

    return warpResp(retobj)
end

-- 自动加入机器人
function CMD.aiJoin(source, aiUser)
end

-- 退出房间
function CMD.exitG(source, msg)
    return cs(function()
        local unlock = false
        local user = deskInfo:findUserByUid(msg.uid)
        if user and user.state == PlayerState.Wait then
            unlock = true
        end
        local ret = agent:exitG(msg, unlock)
        return warpResp(ret)
    end)
end

-- 发起解散
function CMD.applyDismiss(source, msg)
    local retobj = agent:applyDismiss(msg)
    return warpResp(retobj)
end

-- 同意/拒绝 解散房间
function CMD.replyDismiss(source, msg)
    local retobj = agent:replyDismiss(msg)
    return warpResp(retobj)
end

function CMD.enterAuto(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    local user = deskInfo:findUserByUid(uid)
    if not user then return end

    local retobj = {c = recvobj.c, code= PDEFINE.RET.SUCCESS, spcode=0}

    if user.auto == 1 then
        return warpResp(retobj)
    end

    user.auto = 1 -- 进入托管

    deskInfo:autoMsgNotify(user, 1)
    
    return warpResp(retobj)
end

--! 出牌过程中 取消托管
function CMD.cancelAuto(source, msg)
    local recvobj  = msg
    LOG_DEBUG('cancelAuto, msg:', recvobj)
    local uid = math.sfloor(recvobj.uid)
    local user = deskInfo:findUserByUid(uid)
    if not user then return end

    local retobj = {c = recvobj.cmd, code= PDEFINE.RET.SUCCESS, spcode=0}
    if user.auto == 0 then
        return warpResp(retobj)
    end
    
    user:clearTimer()
    user.auto = 0 --关闭自动

    -- 根据状态，重新开启计时器
    if user.state == PlayerState.Play then
        retobj.delayTime = deskInfo.delayTime
        userSetAutoState('autoPlay', retobj.delayTime, uid)
    elseif user.state == PlayerState.Bet and #user.round.betcoin <= 0 then
        retobj.delayTime = deskInfo.delayTime
        userSetAutoState('autoBet', retobj.delayTime, uid)
    elseif user.state == PlayerState.Insure then
        retobj.delayTime = deskInfo.delayTime
        userSetAutoState('autoInsure', retobj.delayTime, uid)
    end
    
    deskInfo:autoMsgNotify(user, 0, retobj.delayTime)
    
    return warpResp(retobj)
end

-- 更新玩家的桌子信息
function CMD.updateUserClusterInfo(source, uid, _agent)
    deskInfo:updateUserAgent(uid, _agent)
end

local function filterDeskData(desk)
    if desk and desk.round then
        desk.round.cards = nil
        if desk.round.bankercard then
            for i = 2, #desk.round.bankercard do
                desk.round.bankercard[i] = 0
            end
        end
    end
end

-- 用户离线获取牌桌信息
function CMD.getDeskInfo(source, msg)
    local desk = deskInfo:toResponse(msg.uid)
    filterDeskData(desk)
    return desk
end

-- 用户在线离线
function CMD.offline(source, offline, uid)
    agent:offline(offline, uid)
end

-- 用户更改麦克风状态
function CMD.updateUserMic(source, msg)
    return agent:updateUserMic(msg)
end

-- 通知用户比赛结束
function CMD.updateRaceStatus(source, msg)
    return agent:updateRaceStatus(msg)
end

-- 创建房间
function CMD.create(source, cluster_info, msg, ip, deskid, newplayercount, gameid)
    -- 实例化桌子
    deskInfo = baseDeskInfo(GAME_NAME, gameid, deskid)
    -- 绑定自定义方法
    ---@type DeskInfoFunc
    deskInfo.func = {
        initDeskRound = initDeskInfoRound,
        initUserRound = initUserRound,
        startGame = startGame,
        setAutoReady = setAutoReady,
    }
    -- 实例化游戏
    agent = baseAgent(gameid, deskInfo)
    -- 绑定自定义方法
    ---@type AgentFunc
    local function autoAiJoin()
        return false
    end
    agent.func = {
        gameOver = gameOver,
        roundOver = roundOver,
        autoAiJoin = autoAiJoin,
    }
    -- 创建房间
    local err = agent:createRoom(msg, deskid, gameid, cluster_info)
    if err then
        return err
    end
    -- 设置结束分数
    local bet = deskInfo.bet
    local minBet = deskInfo.conf.param1 or bet
    local maxBet = deskInfo.conf.param2 or bet*10
    minBet = math.max(0.01, minBet)
    maxBet = math.max(maxBet, minBet*10)
    deskInfo.minBet = minBet
    deskInfo.maxBet = maxBet
    if maxBet < minBet * 20 then
        deskInfo.fixedBets = {maxBet*0.2, maxBet*0.3, maxBet*0.5, maxBet*0.8}
    else
        deskInfo.fixedBets = {maxBet*0.1, maxBet*0.2, maxBet*0.3, maxBet*0.5}
    end

    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        deskInfo.waitTime = 10
        --10秒后开始
        skynet.timeout((deskInfo.waitTime+2)*100, function()
            startGame(0)
        end)

        --加入机器人
        skynet.timeout(math.random(100,500), function()
            aiJoin()
        end)
    else
        deskInfo.waitTime = 0
    end
    deskInfo.beginTime = skynet.now() + deskInfo.waitTime*100

    if msg.sid then
        stgy.ssid = msg.sid
        stgy.gameid = gameid
    end

    -- 获取桌子回复
    local desk = deskInfo:toResponse(deskInfo.owner)
    -- LOG_DEBUG("desk", desk)
    return PDEFINE.RET.SUCCESS, desk
end

function CMD.setPlayerExit(source, uid)
    return deskInfo:setPlayerExit(uid)
end

-- 加入房间
function CMD.join(source, cluster_info, msg, ip)
    return cs(function()
        local uid = msg.uid
        local err, retobj = agent:joinRoom(msg, cluster_info)
        -- 有返回则直接返回了对象
        if err then
            if retobj and retobj.deskinfo then
                filterDeskData(retobj.deskinfo)
            end
            return err, retobj
        end
        -- 获取加入房间回复
        retobj = agent:joinRoomResponse(msg.c, uid)
        if retobj.deskinfo and retobj.deskinfo.round then
            filterDeskData(retobj.deskinfo)
            if deskInfo.state ~= DeskState.Match then
                retobj.deskinfo.deskFlag = 1
            end
        end
        if #deskInfo.users == deskInfo.seat and deskInfo.curround == 0 then
           startGame(2)
        end
        return warpResp(retobj)
    end)
end

-- 准备，如果是私人房，则有这个阶段
function CMD.ready(source, msg)
    local errono = deskInfo:userReady(msg.uid)
    if errono == PDEFINE.RET.ERROR.COIN_NOT_ENOUGH then
        local retobj  = {code = PDEFINE.RET.SUCCESS, c = math.floor(msg.c), uid=msg.uid, spcode=PDEFINE.RET.ERROR.COIN_NOT_ENOUGH}
        return PDEFINE.RET.SUCCESS, retobj
    end
    return PDEFINE.RET.SUCCESS
end

-- 发送聊天信息
function CMD.sendChat(source, msg)
    agent:sendChat(msg)
    return PDEFINE.RET.SUCCESS
end

-- 房主解散房间
function CMD.dismissRoom(source)
    return deskInfo:dismissRoom()
end

-- 剔除一个观战玩家
function CMD.removeViewer(source, uid)
    local viewer = deskInfo:findViewUser(uid)
    if viewer then
        deskInfo:viewExit(uid)
        pcall(cluster.send, viewer.cluster_info.server, viewer.cluster_info.address, "deskBack", deskInfo.gameid, deskInfo.deskid) --释放桌子对象
    end
end

-- 换桌子
function CMD.switchDesk(source, msg)
    local spcode = 0
    local uid = msg.uid
    if (deskInfo.state == DeskState.Match or deskInfo.state == DeskState.Settle) then
        spcode = agent:switchDesk(msg)
    else
        local user = deskInfo:findUserByUid(uid)
        -- 未发牌也可以换桌
        if user and user.state == PlayerState.Wait then
            spcode = agent:switchDesk(msg)
        else
            spcode = 1
        end
    end
    local retobj = {
        c = msg.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = spcode,
    }
    return warpResp(retobj)
end

-- 更新玩家信息
function CMD.updateUserInfo(source, uid)
    agent:updateUserInfo(uid)
end

-------- API更新桌子里玩家的金币 --------
function CMD.addCoinInGame(source, uid, coin, diamond)
    agent:addCoinInGame(uid, coin, diamond)
end

------ api取牌桌信息 ------
function CMD.apiGetDeskInfo(source,msg)
    return deskInfo:toResponse()
end

------ api停服清房 ------
function CMD.apiCloseServer(source,csflag)
    closeServer = csflag
end

------ api解散房间 ------
function CMD.apiKickDesk(source)
    agent:apiKickDesk()
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.retpack(f(source, ...))
    end)

    collectgarbage("collect")
end)
