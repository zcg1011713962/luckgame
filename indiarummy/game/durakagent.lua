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
local robot = require "durak.robot"
local cs = queue()
local GAME_NAME = "durak"
local DEBUG = skynet.getenv("DEBUG")
local CMD = {}
local closeServer = false

---@type BaseDeskInfo @instance of leekha
local deskInfo = nil  -- 桌子信息
---@type BaseAgent
local agent = nil  -- 游戏实例
local MaxTileCount = 6 --桌面最大牌堆数量

--玩家状态
local PlayerState = {
    Wait = PDEFINE.PLAYER_STATE.Wait,       --等待
    Ready = PDEFINE.PLAYER_STATE.Ready,      --准备
    Attack = 3,     --攻击
    Defend = 4,     --防守
    Done = 5,       --完成（完成进攻）
    Pass = 6,       --通过（完成补牌）
    Take = 7,       --拿牌（完成防守）
    AddExtra = 8,   --补牌
    End = 9,        --结束（出完手牌）
}
--协议
local Protocol = {
    Discard = 25702,
    Pass = 25715,
    Take = 27401,
    Done = 27402,
}
--出牌类型
local DiscardType = {
    Attack = 1,     --进攻出牌
    Defend = 2,     --防守出牌
    Transfer = 3,   --转移出牌
    AddExtra = 4,   --补牌出牌
}
--游戏配置
local config = {
    -- 0x4* 为黑桃, 0x3*为红桃，, 0x2*为梅花, 0x1*为方块
    Cards = {
        0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,
        0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,
        0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,
        0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,
    },
    --发牌数量
    InitCardLen = 6,
    --座位数量
    Seats = {2, 3, 4, 5, 6},
    --牌堆数量    
    CardDeck = {24, 36, 52},
    --攻击模式
    AttackType = {
        Neighbors = 1,  --相邻玩家参与攻击
        All = 2,        --全部玩家参与攻击
    },
    --赢分比例
    ScoreRate = {
        [2] = {0.96, 0},        --2人
        [3] = {0.60, 0.34, 0},  --3人
        [4] = {0.50, 0.30, 0.12, 0},        --4人
        [5] = {0.40, 0.25, 0.20, 0.05, 0},  --5人
        [6] = {0.35, 0.20, 0.16, 0.12, 0.05, 0} --6人
    }
}

-- 成功返回
local function warpResp(retobj)
    return PDEFINE.RET.SUCCESS, retobj
end

local function formatRoundCards(roundCards)
    local t = {}
    for _, cards in ipairs(roundCards) do
        table.insert(t, "{"..table.concat(cards, ",").."}")
    end
    return table.concat(t, ",")
end

local function convertArray(t)
    if #t == 0 then
        return 0
    elseif #t == 1 then
        return t[1]
    else
        return t
    end
end

--lua浮点数有误差，10000.0可能取整后是9999
local function safe_floor(val)
    return math.floor(val+0.001)
end

-- 检测用户
local function checkUser(user, retobj)
    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return false, retobj
    else
        retobj.seat   = user.seatid
        retobj.uid    = user.uid
        return true, retobj
    end
end

-- 根据座位号，找到上一个玩家
local function findPrevUser(seatId)
    local tryCnt = deskInfo.seat
    while tryCnt > 0 do
        seatId = seatId - 1
        if seatId < 1 then seatId = deskInfo.seat end
        for _,user in pairs(deskInfo.users) do
            if user.seatid == seatId and #user.round.cards > 0 then
                return user
            end
        end
        tryCnt = tryCnt - 1
    end
    return nil
end

-- 根据座位号，找到下一个玩家
local function findNextUser(seatId)
    local tryCnt = deskInfo.seat
    while tryCnt > 0 do
        seatId = seatId + 1
        if seatId > deskInfo.seat then seatId = 1 end
        for _,user in pairs(deskInfo.users) do
            if user.seatid == seatId and #user.round.cards > 0 then
                return user
            end
        end
        tryCnt = tryCnt - 1
    end
    return nil
end

local function calcUserMultiple(user)
    local mult = deskInfo.bet
    -- 匹配赛，奖励需要根据下注额来定
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        mult = PDEFINE_GAME.SESS['match'][deskInfo.gameid][user.ssid].entry
    end
    return mult
end

local function initDeskInfoRound()
    deskInfo.round = {}
    deskInfo.round.cards = {}
    deskInfo.round.cardCnt = 0    --剩余牌数
    deskInfo.round.activeSeat = {} -- 当前活动座位
    deskInfo.round.attackSeats = {} --所有进攻座位号
    deskInfo.round.attackSeat = {} --当前参与进攻的座位号
    deskInfo.round.drawSeats = {} --补牌玩家
    deskInfo.round.defendSeat = 0  --防守座位号
    deskInfo.round.masterCard = 0  --主牌
    deskInfo.round.masterSuit = 0 --主花色
    deskInfo.round.roundCards = {}  -- 当前轮次出的牌
end

---@param user BaseUser
local function initUserRound(user)
    user.state = PlayerState.Wait
    user.round = {}
    user.round.score = 0 --轮分
    user.round.cards = {} --手中的牌
    user.round.winrate = 0 --赢分比例
    user.round.rank = 0  --名次
    user.round.mult = calcUserMultiple(user)
end

--检查进攻牌最大张数
local function checkTileLimit()
    --第一次攻击最多5张，后续每次攻击最多6张
    local tileCnt = #deskInfo.round.roundCards --当前堆数
    local tileLimit = MaxTileCount  --不能超过6张
    if deskInfo.curround == 1 then  --第一轮5张
        tileLimit = MaxTileCount - 1
    end
    if tileCnt >= tileLimit then
        return false
    end
    --任何攻击都不能超过防御者手中的牌张数
    local attackCardCnt = 0
    for _, cards in ipairs(deskInfo.round.roundCards) do
        if #cards == 1 then
            attackCardCnt = attackCardCnt + 1
        end
    end
    local defendUser = deskInfo:findUserBySeatid(deskInfo.round.defendSeat)
    tileLimit = #defendUser.round.cards
    return attackCardCnt < tileLimit
end

--是否能继续进攻
local function checkCanKeepAttack()
    local haveAttackCards = false
    for _, seatid in ipairs(deskInfo.round.attackSeats) do
        local u = deskInfo:findUserBySeatid(seatid)
        if #u.round.cards > 0 then  --进攻方还没出完
            haveAttackCards = true
            break
        end
    end
    if haveAttackCards and checkTileLimit() then  --还能继续加牌
        return true
    end
    return false
end

-- 找到一张进攻牌
local function findSingleCard(roundCards)
    for idx, cards in ipairs(roundCards) do
        if #cards == 1 then
            return idx, cards[1]
        end
    end
end

-- 自动进攻
local function autoAttack(uid)
    local user = deskInfo:findUserByUid(uid)
    LOG_DEBUG("用户自动进攻 uid:".. uid, "round cards: "..table.concat(user.round.cards, ","))

    if user.state ~= PlayerState.Attack then
        LOG_WARNING("进攻状态错误: uid:", uid, ' seatid:', user.seatid, " state:", user.state)
        return
    end

    if user.cluster_info then
        if user.auto == 0 then
            user.auto = 1
            deskInfo:autoMsgNotify(user, 1, 0) --通知进入托管
        end
    end

    local card = robot.findAttackCard(user.round.cards, deskInfo)
    if card and checkTileLimit() then
        --出牌
        local msg = {
            c = Protocol.Discard,
            uid = uid,
            card = card,
            op = DiscardType.Attack,
        }
        local _, resp = CMD.discard(nil, msg)
        resp.c = PDEFINE.NOTIFY.PLAYER_DISCARD
        resp.is_auto = 1
        if resp.spcode == 0 then
            user:sendMsg(cjson.encode(resp))
        end
        LOG_DEBUG("自动进攻 discard msg:", msg, "返回: ", resp)
    else
        --要不起(完成进攻)
        local msg = {
            c = Protocol.Done,
            uid = uid,
        }
        local _, resp = CMD.done(nil, msg)
        resp.c = PDEFINE.NOTIFY.PLAYER_DONE
        resp.is_auto = 1
        if resp.spcode == 0 then
            user:sendMsg(cjson.encode(resp))
        end
        LOG_DEBUG("自动进攻 done msg:", msg, "返回: ", resp)
    end
end

-- 自动防守
local function autoDefend(uid)
    local user = deskInfo:findUserByUid(uid)
    LOG_DEBUG("用户自动防守 uid:".. uid, "round cards: "..table.concat(user.round.cards, ","))

    if user.state ~= PlayerState.Defend then
        LOG_WARNING("防守状态错误: uid:", uid, ' seatid:', user.seatid, " state:", user.state)
        return
    end

    if user.cluster_info then
        if user.auto == 0 then
            user.auto = 1
            deskInfo:autoMsgNotify(user, 1, 0) --通知进入托管
        end
    end

    --找牌
    local tileid, attackCard = findSingleCard(deskInfo.round.roundCards)
    local card = robot.findDefendCard(user.round.cards, attackCard, deskInfo)

    if card then
        --出牌
        local msg = {
            c = Protocol.Discard,
            uid = uid,
            card = card,
            tileid = tileid,
            op = DiscardType.Defend,
        }
        local _, resp = CMD.discard(nil, msg)
        resp.c = PDEFINE.NOTIFY.PLAYER_DISCARD
        resp.is_auto = 1
        if resp.spcode == 0 then
            user:sendMsg(cjson.encode(resp))
        end

        LOG_DEBUG("自动防守 discard msg:", msg, "返回: ", resp)
    else
        --要不起（拿牌）
        local msg = {
            c = Protocol.Take,
            uid = uid,
        }
        local _, resp = CMD.take(nil, msg)
        resp.c = PDEFINE.NOTIFY.PLAYER_TAKE
        resp.is_auto = 1
        if resp.spcode == 0 then
            user:sendMsg(cjson.encode(resp))
        end
        LOG_DEBUG("自动防守 take msg:", msg, "返回: ", resp)
    end
end

-- 自动补牌
local function autoAddExtra(uid)
    local user = deskInfo:findUserByUid(uid)
    LOG_DEBUG("用户自动补牌 uid:".. uid, "round cards: "..table.concat(user.round.cards, ","))
    user:clearTimer()

    if user.state ~= PlayerState.AddExtra then
        LOG_WARNING("补牌状态错误: uid:", uid, ' seatid:', user.seatid, " state:", user.state)
        return
    end

    if user.cluster_info then
        if user.auto == 0 then
            user.auto = 1
            deskInfo:autoMsgNotify(user, 1, 0) --通知进入托管
        end
    end

    local card = robot.findAddExtraCard(user.round.cards, deskInfo)
    if (not user.cluster_info) and card and checkTileLimit() then
        --出牌
        local msg = {
            c = Protocol.Discard,
            uid = uid,
            card = card,
            op = DiscardType.AddExtra,
        }
        local _, resp = CMD.discard(nil, msg)
        resp.c = PDEFINE.NOTIFY.PLAYER_DISCARD
        resp.is_auto = 1
        if resp.spcode == 0 then
            user:sendMsg(cjson.encode(resp))
        end
        LOG_DEBUG("自动补牌 discard msg:", msg, "返回: ", resp)
    else
        --要不起(不要)
        local msg = {
            c = Protocol.Pass,
            uid = uid,
        }
        local _, resp = CMD.pass(nil, msg)
        resp.c = PDEFINE.NOTIFY.PLAYER_PASS
        resp.is_auto = 1
        if resp.spcode == 0 then
            user:sendMsg(cjson.encode(resp))
        end
        LOG_DEBUG("自动补牌 pass msg:", msg, "返回: ", resp)
    end
end

-- 自动准备
local function autoReady(uid)
    LOG_DEBUG("自动准备 uid:".. uid)
    local user = deskInfo:findUserByUid(uid)
    
    if not user or user.state == PlayerState.Ready then
        return 
    end
    user:clearTimer()

    local msg = {
        ['c'] = 25708,
        ['uid'] = uid,
    }
    CMD.ready(nil, msg)
end

-- 设定玩家定时器
local function userSetAutoState(rtype,autoTime,uid)
    autoTime = autoTime + 1
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    user:clearTimer()
    if not user.cluster_info or (rtype ~= "autoReady" and user.auto == 1) then
        autoTime = math.random(20,30)/10
    end
    if DEBUG and user.cluster_info and user.isexit == 0 then
        autoTime = 1000000
    end

    local funcs = {
        ["autoAttack"] = autoAttack,      --自动进攻
        ["autoDefend"] = autoDefend,      --自动防守
        ["autoAddExtra"] = autoAddExtra,  --自动补牌
        ["autoReady"] = autoReady         --自动准备
    }
    local func = funcs[rtype]
    if func then
        user:setTimer(autoTime, func, uid)
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


-- 开始发牌
-- 调用顺序
local function roundStart()
    deskInfo.curround = deskInfo.curround + 1
    LOG_DEBUG("roundStart deskid:", deskInfo.uuid, deskInfo.seat, deskInfo.curround)
    -- 切换桌子状态
    deskInfo:updateState(PDEFINE.DESK_STATE.PLAY)

    local retobj = {}
    retobj.c = PDEFINE.NOTIFY.GAME_DEAL
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.cards = nil
    retobj.curround = deskInfo.curround

    local minValue = 1
    if deskInfo.params.CardDeck == 24 then
        minValue = 9
    elseif deskInfo.params.CardDeck == 36 then
        minValue = 6
    end
    --发牌
    local dealcards = {}
    for _, card in ipairs(config.Cards) do
        if baseUtil.ScanValue(card) >= minValue then
            table.insert(dealcards, card)
        end
    end
    deskInfo.round.cards = dealcards
    shuffle(deskInfo.round.cards)

    --最后一张牌为主牌
    local masterCard = deskInfo.round.cards[1]
    --主牌花色为主花色
    local masterSuit = baseUtil.ScanSuit(masterCard)

    -- 开始发牌
    for _, user in ipairs(deskInfo.users) do
        local cards = {}
        user.state = PlayerState.Wait
        for i = 1, config.InitCardLen do
            table.insert(cards, table.remove(deskInfo.round.cards))
        end
        user.round.cards = cards
        user.round.initcards = table.copy(cards)
    end

    --确定攻击者和防守者
    --手牌中与主牌点数最小的玩家为进攻方
    local activeUser = deskInfo.users[1]    --活动玩家
    local attackSeats = {}  --进攻方
    local maxValue = 0
    for _, user in ipairs(deskInfo.users) do
        for _, card in ipairs(user.round.cards) do
            if baseUtil.ScanSuit(card) == masterSuit then
                if maxValue < baseUtil.ScanValue(card) then
                    maxValue = baseUtil.ScanValue(card)
                    activeUser = user
                end
            end
        end
    end
    activeUser.state = PlayerState.Attack
    userSetAutoState('autoAttack', deskInfo.delayTime, activeUser.uid)
    table.insert(attackSeats, activeUser.seatid)

    --攻击者下一位为防守者
    local defendUser = findNextUser(activeUser.seatid)
    defendUser.state = PlayerState.Defend
    --防守者下一位为另一名攻击者
    if #deskInfo.users > 2 then
        local nextAttackUser = findNextUser(defendUser.seatid)
        if nextAttackUser ~= activeUser and nextAttackUser ~= defendUser then
            table.insert(attackSeats, nextAttackUser.seatid)
        end
    end

    deskInfo.round.cardCnt = #deskInfo.round.cards
    deskInfo.round.masterCard = masterCard
    deskInfo.round.masterSuit = masterSuit
    deskInfo.round.activeSeat = {activeUser.seatid}
    deskInfo.round.attackSeats = attackSeats
    deskInfo.round.attackSeat = {activeUser.seatid}
    deskInfo.round.defendSeat = defendUser.seatid

    retobj.cardCnt = deskInfo.round.cardCnt
    retobj.masterCard = masterCard
    retobj.masterSuit = masterSuit
    retobj.activeSeat = deskInfo.round.activeSeat
    retobj.activeState = PlayerState.Attack
    retobj.delayTime = deskInfo.delayTime
    retobj.attackSeats = deskInfo.round.attackSeats
    retobj.attackSeat = deskInfo.round.attackSeat
    retobj.defendSeat = deskInfo.round.defendSeat

    local handcards = {}
    for _, user in ipairs(deskInfo.users) do
        local cards = table.fill({}, 0, #user.round.cards)
        handcards[user.seatid] = cards
    end
    for _, user in ipairs(deskInfo.users) do
        retobj.handcards = table.copy(handcards)
        retobj.handcards[user.seatid] = table.copy(user.round.cards) --自己的牌显示出来
        --广播消息
        user:sendMsg(cjson.encode(retobj))
        if _ == 1 then
            LOG_DEBUG("发牌", retobj)
        end
    end

    retobj.handcards = table.copy(handcards)
    deskInfo:broadcastViewer(cjson.encode(retobj))
end

-- 创建房间后第1次开始游戏
---@param delayTime integer 用于指定发牌前的延迟时间
local function startGame(delayTime)
    if deskInfo.state ~= PDEFINE.DESK_STATE.MATCH and deskInfo.state ~= PDEFINE.DESK_STATE.READY then
        return
    end
    --调用基类的开始游戏
    deskInfo:startGame()

    --初始化桌子信息
    deskInfo:initDeskRound()

    delayTime = (delayTime or 0) * 100 + 30
    skynet.timeout(delayTime, function()
        --开始游戏轮次
        roundStart()
    end)
end

-- 游戏结束
local function gameOver(isDismiss)
    LOG_DEBUG("gameOver isDismiss:", isDismiss)
    ---@type Settle
    local settle = {
        uids = {},  -- uid
        league = {},  -- 排位经验
        coins = {}, -- 结算的金币
        scores = {}, -- 获得的分数
        levelexps = {}, -- 经验值
        rps = {},  -- rp 值
        fcoins = {},  -- 最终的金币
    }
    ---@type SettledByGame
    local settledbygame = {
        settlewin = {}, --计算分数
        betcoin = {},
        wincoin = {},   --计算金币
    }
    for i = 1, deskInfo.seat do
        local u = deskInfo:findUserBySeatid(i)
        if u then
            table.insert(settle.uids, u.uid)
        else
            table.insert(settle.uids, 0)
        end
        table.insert(settle.league, 0)
        table.insert(settle.coins, 0)
        table.insert(settle.scores, 0)
        table.insert(settle.levelexps, 0)
        table.insert(settle.rps, 0)
        table.insert(settle.fcoins, 0)

        table.insert(settledbygame.settlewin, 0)
        table.insert(settledbygame.betcoin, 0)
        table.insert(settledbygame.wincoin, 0)
    end

    local winners = {}
    for _, user in ipairs(deskInfo.users) do
        local seatid = user.seatid
        settle.scores[seatid] = user.score

        local rank = user.round.rank
        if rank > 0 then
            settledbygame.settlewin[seatid] = user.round.winrate

            local bet = user.round.mult
            settledbygame.betcoin[seatid] = bet
            settledbygame.wincoin[seatid] = bet + user.round.score

            if user.round.score >= 0 then
                table.insert(winners, seatid)
            end
        end
    end

    deskInfo:gameOver(settle, isDismiss, false, winners, settledbygame)
end

--下一轮
local function roundNext(activeSeat, addcards)
    deskInfo.curround = deskInfo.curround + 1
    LOG_DEBUG("roundNext activeSeat:"..activeSeat, "curround:"..deskInfo.curround)

    local retobj = {}
    retobj.c = PDEFINE.NOTIFY.GAME_DEAL_IN_PLAY  --游戏中发牌
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.curround = deskInfo.curround

    --第一位攻击者
    local activeUser = deskInfo:findUserBySeatid(activeSeat)

    if activeUser.state == PlayerState.End then
        --如果已完成出牌，就顺延给下一位
        activeUser = findNextUser(activeUser.seatid)
    end

    local attackSeats = {}  --进攻方
    activeUser.state = PlayerState.Attack
    userSetAutoState('autoAttack', deskInfo.delayTime, activeUser.uid)
    table.insert(attackSeats, activeUser.seatid)

    --攻击者下一位为防守者
    local defendUser = findNextUser(activeUser.seatid)
    defendUser.state = PlayerState.Defend
    --防守者下一位为另一名攻击者
    if #deskInfo.users > 2 then
        local nextAttackUser = findNextUser(defendUser.seatid)
        if nextAttackUser ~= activeUser and nextAttackUser ~= defendUser then
            table.insert(attackSeats, nextAttackUser.seatid)
        end
    end

    deskInfo.round.cardCnt = #deskInfo.round.cards
    deskInfo.round.activeSeat = {activeUser.seatid}
    deskInfo.round.attackSeats = attackSeats
    deskInfo.round.attackSeat = {activeUser.seatid}
    deskInfo.round.defendSeat = defendUser.seatid

    retobj.cardCnt = deskInfo.round.cardCnt
    retobj.activeSeat = deskInfo.round.activeSeat
    retobj.activeState = PlayerState.Attack
    retobj.delayTime = deskInfo.delayTime
    retobj.attackSeats = deskInfo.round.attackSeats
    retobj.attackSeat = deskInfo.round.attackSeat
    retobj.defendSeat = defendUser.seatid

    local handcards = {}
    for _, user in ipairs(deskInfo.users) do
        local cards = table.fill({}, 0, #user.round.cards)
        handcards[user.seatid] = cards
    end
    for _, user in ipairs(deskInfo.users) do
        --手牌
        retobj.handcards = table.copy(handcards)
        retobj.handcards[user.seatid] = table.copy(user.round.cards) --自己的牌显示出来
        --补牌
        retobj.addcards = table.copy(addcards)
        for _, v in ipairs(retobj.addcards) do
            if v.seatid ~= user.seatid then --不是自己的牌，填0
                table.fill(v.cards, 0, #(v.cards))
            end
        end
        --广播消息
        user:sendMsg(cjson.encode(retobj))
    end

    retobj.handcards = table.copy(handcards)
    retobj.addcards = table.copy(addcards)
    for _, v in ipairs(retobj.addcards) do
        table.fill(v.cards, 0, #(v.cards))
    end
    deskInfo:broadcastViewer(cjson.encode(retobj))

    LOG_DEBUG("补牌", retobj)

    return PDEFINE.RET.SUCCESS
end

-- 此轮游戏结束
-- res：1防守成功 2防守失败
local function roundOver(res)
    LOG_DEBUG("roundOver res:"..res)
    deskInfo.state = PDEFINE.DESK_STATE.SETTLE
    --清除玩家定时器
    --处理玩家状态
    for _, user in ipairs(deskInfo.users) do
        if user.state ~= PlayerState.End then
            user.state = PlayerState.Wait
        end
        user:clearTimer()
    end
    local retobj = {}
    retobj.c = PDEFINE.NOTIFY.GAME_ROUND_OVER
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.res = res

    --桌牌
    local takeCards = {}
    if res == 2 then
        local defendUser = deskInfo:findUserBySeatid(deskInfo.round.defendSeat)
        --防守失败, 收走桌上的牌
        for _, cards in ipairs(deskInfo.round.roundCards) do
            for _, card in ipairs(cards) do
                table.insert(takeCards, card)
                table.insert(defendUser.round.cards, card)
            end
        end
    end
    deskInfo.round.roundCards = {}

    retobj.defendSeat = deskInfo.round.defendSeat
    retobj.takeCards = takeCards

    --补牌(这里先补牌，是为了看是否有玩家出完牌也不用补牌直接胜出)
    local addcards = {}
    if #deskInfo.round.cards > 0 then
        --先补进攻者,再补防守者
        local seats = {}
        for _, seatid in ipairs(deskInfo.round.drawSeats) do
            if seatid ~= deskInfo.round.defendSeat then
                table.insert(seats, seatid)
            end
        end
        table.insert(seats, deskInfo.round.defendSeat)

        for _, seatid in ipairs(seats) do
            local cards = {}
            local user = deskInfo:findUserBySeatid(seatid)
            local cardCnt = MaxTileCount - #user.round.cards
            for i = 1, cardCnt do
                if #deskInfo.round.cards > 0 then
                    local card = table.remove(deskInfo.round.cards)
                    table.insert(user.round.cards, card)
                    table.insert(cards, card)
                end
            end
            if #cards > 0 then
                table.insert(addcards, {seatid = seatid, cards = table.copy(cards)})
            end
        end
    end
    deskInfo.round.drawSeats = {}

    --是否有玩家胜出
    local winners = {}
    local rank = 0
    for _, user in ipairs(deskInfo.users) do
        rank = math.max(rank, user.round.rank)
    end
    rank = rank + 1
    local winUsers = {}
    local totalWinRate = 0
    local seat = deskInfo.seat
    for _, user in ipairs(deskInfo.users) do
        if user.state ~= PlayerState.End and #user.round.cards <= 0 then
            user.state = PlayerState.End
            user.round.rank = rank
            totalWinRate = totalWinRate + config.ScoreRate[seat][rank]
            table.insert(winUsers, user)
            rank = rank + 1
        end
    end
    --同时出完牌的人平分得分
    local winRate = totalWinRate / #winUsers
    for _, user in ipairs(winUsers) do
        user.round.winrate = seat * winRate - 1
        user.round.score = safe_floor(user.round.mult * user.round.winrate)
        table.insert(winners, {
            seatid = user.seatid,
            rank = user.round.rank,
            score = user.round.score,
            state = user.state
        })
    end

    retobj.winners = winners

    --判断是否结束
    local cnt = 0
    for _, user in ipairs(deskInfo.users) do
        if user.state ~= PlayerState.End then
            cnt = cnt + 1
        end
    end
    local isOver = (cnt <= 1)

    local activeSeat = 0
    if isOver then
        for _, user in ipairs(deskInfo.users) do
            if user.state ~= PlayerState.End then
                user.state = PlayerState.End
                user.round.rank = rank
                user.round.winrate = seat * config.ScoreRate[seat][rank] - 1
                user.round.score = safe_floor(user.round.mult * user.round.winrate)
                rank = rank + 1
            end
        end
    else
        if res == 1 then
            --防守成功：防守方成为下一轮的第一进攻方
            activeSeat = deskInfo.round.defendSeat
        else
            --防守失败：下一个玩家成为攻击方
            local nextUser = findNextUser(deskInfo.round.defendSeat)
            activeSeat = nextUser.seatid
        end
    end

    local notifyMsg = function ()
        -- 维护强行大结算
        if isMaintain() then
            agent:gameOver(true)
        elseif isOver then
            agent:gameOver()
        else
            roundNext(activeSeat, addcards)
        end
    end
    skynet.timeout(100, notifyMsg)

    LOG_DEBUG("小结算", retobj)
    deskInfo:broadcast(cjson.encode(retobj))

    return PDEFINE.RET.SUCCESS
end

-- 自动加入机器人
function CMD.aiJoin(source, aiUser)
    return deskInfo:aiJoin(aiUser)
end

-- 退出房间
function CMD.exitG(source, msg)
    local ret = agent:exitG(msg)
    return warpResp(ret)
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

-- take 防守方要不起，拿牌
function CMD.take(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)

    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    LOG_DEBUG("take: user:"..uid)

    --检测用户
    local user = deskInfo:findUserByUid(uid)
    local ok
    ok, retobj = checkUser(user, retobj)
    if not ok then
        return warpResp(retobj)
    end

    --检查状态
    if user.state ~= PlayerState.Defend then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end

    --检查桌牌
    local checkRule = false
    for _, cards in ipairs(deskInfo.round.roundCards) do
        if #cards == 1 then --存在未防守的牌
            checkRule = true
            break
        end
    end
    if not checkRule then
        retobj.spcode = PDEFINE.RET.ERROR.TAKE_ERROR
        return warpResp(retobj)
    end

    --修改状态
    user.state = PlayerState.Take
    --清除计时器
    user:clearTimer()

    if checkCanKeepAttack() then
        local activeSeat = {}
        local delayTime = deskInfo.delayTime
        --进攻玩家可以补牌
        for _, seatid in ipairs(deskInfo.round.attackSeat) do
            local u = deskInfo:findUserBySeatid(seatid)
            if u.state ~= PlayerState.End then
                u.state = PlayerState.AddExtra
                userSetAutoState('autoAddExtra', delayTime, u.uid)
                table.insert(activeSeat, u.seatid)
            end
        end

        deskInfo.round.activeSeat = activeSeat

        retobj.delayTime = delayTime
        retobj.activeSeat = deskInfo.round.activeSeat
        retobj.activeState = PlayerState.AddExtra
    else
        --回合结束，防守失败
        deskInfo.round.activeSeat = {}
        skynet.timeout(100, function()
            roundOver(2)
        end)

        --攻击者直接变成done或pass状态
        local userState = {}
        local firstAttack = #deskInfo.round.attackSeat == #deskInfo.round.attackSeats
        for _, seatid in ipairs(deskInfo.round.attackSeat) do
            local u = deskInfo:findUserBySeatid(seatid)
            if firstAttack then
                u.state = PlayerState.Done
            else
                u.state = PlayerState.Pass
            end
            table.insert(userState, {seatid=u.seatid, state=u.state})
        end
        retobj.userState = userState
    end

    --广播给房间里的所有人
    local notify_object = table.copy(retobj)
    notify_object.c  = PDEFINE.NOTIFY.PLAYER_TAKE
    deskInfo:broadcast(cjson.encode(notify_object), uid)

    --返回操作结果
    return warpResp(retobj)
end

-- done 进攻方完成进攻
function CMD.done(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)

    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    LOG_DEBUG("done: user:"..uid)

    -- 检测用户
    local user = deskInfo:findUserByUid(uid)
    local ok
    ok, retobj = checkUser(user, retobj)
    if not ok then
        return warpResp(retobj)
    end

    --检查状态
    if user.state ~= PlayerState.Attack then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end

    --必须防守方防守完所有的牌
    local singlecard = findSingleCard(deskInfo.round.roundCards)
    if singlecard then
        retobj.spcode = PDEFINE.RET.ERROR.CAN_NOT_DONE
        return warpResp(retobj)
    end

    --修改状态
    user.state = PlayerState.Done
    --清除计时器
    user:clearTimer()

    --所有进攻玩家都done
    local activeSeat = {}
    for _, seatid in ipairs(deskInfo.round.attackSeats) do
        local u = deskInfo:findUserBySeatid(seatid)
        if u.state ~= PlayerState.Done then
            table.insert(activeSeat, seatid)
            break
        end
    end
    --所有玩家进攻完成
    if #activeSeat == 0 then
        --回合结束，防守成功
        deskInfo.round.activeSeat = {}
        skynet.timeout(100, function()
            roundOver(1)
        end)
    else
        --进攻状态转移给其他进攻玩家
        local delayTime = deskInfo.delayTime
        for _, seatid in ipairs(activeSeat) do
            local u = deskInfo:findUserBySeatid(seatid)
            u.state = PlayerState.Attack
            u:clearTimer()
            userSetAutoState('autoAttack', delayTime, u.uid)
            if not table.contain(deskInfo.round.attackSeat, u.seatid) then
                table.insert(deskInfo.round.attackSeat, u.seatid)
            end
        end

        deskInfo.round.activeSeat = activeSeat

        retobj.attackSeat = deskInfo.round.attackSeat
        retobj.activeSeat = deskInfo.round.activeSeat
        retobj.activeState = PlayerState.Attack
        retobj.delayTime = delayTime
    end

    --广播给房间里的所有人
    local notify_object = table.copy(retobj)
    notify_object.c = PDEFINE.NOTIFY.PLAYER_DONE
    deskInfo:broadcast(cjson.encode(notify_object), uid)

    --返回操作结果
    return warpResp(retobj)
end

-- pass 进攻方完成补牌
function CMD.pass(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)

    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid    = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    LOG_DEBUG("pass: user:"..uid)

    -- 检测用户
    local user = deskInfo:findUserByUid(uid)
    local ok
    ok, retobj = checkUser(user, retobj)
    if not ok then
        return warpResp(retobj)
    end

    --检查状态
    if user.state ~= PlayerState.AddExtra then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end

    --修改状态
    user.state = PlayerState.Pass
    --清除计时器
    user:clearTimer()

    --是否所有进攻玩家完成补牌
    local passCnt = 0
    for _, seatid in ipairs(deskInfo.round.attackSeats) do
        local u = deskInfo:findUserBySeatid(seatid)
        if u.state == PlayerState.Pass then
            passCnt = passCnt + 1
        end
    end
    if passCnt >= #deskInfo.round.attackSeats then
        --回合结束，防守失败
        deskInfo.round.activeSeat = {}
        skynet.timeout(100, function()
            roundOver(2)
        end)
    else
        --刷新定时器
        local delayTime = deskInfo.delayTime
        --所有进攻玩家开始补牌
        local activeSeat = {}
        for _, seatid in ipairs(deskInfo.round.attackSeats) do
            local u = deskInfo:findUserBySeatid(seatid)
            if u.state ~= PlayerState.Pass then
                u.state = PlayerState.AddExtra
                u:clearTimer()
                userSetAutoState('autoAddExtra', delayTime, u.uid)
                table.insert(activeSeat, u.seatid)
            end
        end

        deskInfo.round.activeSeat = activeSeat

        retobj.activeSeat = deskInfo.round.activeSeat
        retobj.activeState = PlayerState.AddExtra
        retobj.delayTime = delayTime
    end

    --广播给房间里的所有人
    local notify_object = table.copy(retobj)
    notify_object.c = PDEFINE.NOTIFY.PLAYER_PASS
    deskInfo:broadcast(cjson.encode(notify_object), uid)

    --返回操作结果
    return warpResp(retobj)
end

--进攻
local function attack(user, card, retobj)
    LOG_DEBUG("attack: user:", user.uid, " card", card)

    --检查状态(Attack状态和Done状态都能进攻)
    if user.state ~= PlayerState.Attack and user.state ~= PlayerState.Done then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return false, retobj
    end

    --检查牌堆数量
    if not checkTileLimit() then
        retobj.spcode = PDEFINE.RET.ERROR.DISCARD_ERROR
        retobj.errmsg = "tiles limit exceed"
        return false, retobj
    end

    --检查出牌
    --如果桌面无牌，随意出一张，如果桌面上有牌，需要与桌面上的任意一张牌点数相同
    if #deskInfo.round.roundCards > 0 then
        if not robot.checkSameValue(card, deskInfo.round.roundCards) then
            retobj.spcode = PDEFINE.RET.ERROR.DISCARD_ERROR
            retobj.errmsg = "not same value with other cards"
            return false, retobj
        end
    end

    --清除计时器
    user:clearTimer()

    --添加到牌堆
    table.insert(deskInfo.round.roundCards, {card})
    retobj.tileid = #deskInfo.round.roundCards
    --扣除手牌
    baseUtil.RemoveCard(user.round.cards, card)

    local userState = {}
    --如果进攻方出完手中的牌，自动切换done状态
    if #user.round.cards <= 0 then
        user.state = PlayerState.Done
        table.insert(userState, {seatid=user.seatid, state=user.state})
        --进攻状态转移给其他进攻玩家
        for _, seatid in ipairs(deskInfo.round.attackSeats) do
            if not table.contain(deskInfo.round.attackSeat, seatid) then
                table.insert(deskInfo.round.attackSeat, seatid)
            end
        end
    end

    --done状态重新变成attack状态
    for _, seatid in ipairs(deskInfo.round.attackSeat) do
        local u = deskInfo:findUserBySeatid(seatid)
        if #u.round.cards > 0 then
            u.state = PlayerState.Attack  --重新变为进攻状态
            table.insert(userState, {seatid=u.seatid, state=u.state})
        end
    end

    --防守方刷新计时器
    local delayTime = deskInfo.delayTime
    local defendUser = deskInfo:findUserBySeatid(deskInfo.round.defendSeat)
    defendUser.state = PlayerState.Defend
    userSetAutoState('autoDefend', delayTime, defendUser.uid)
    deskInfo.round.activeSeat = {defendUser.seatid}

    retobj.userState = userState
    retobj.activeSeat = deskInfo.round.activeSeat
    retobj.activeState = PlayerState.Defend
    retobj.attackSeat = deskInfo.round.attackSeat
    retobj.delayTime = delayTime

    LOG_DEBUG("attack: uid:"..user.uid.." card:"..card, " desk.roundCards:"..formatRoundCards(deskInfo.round.roundCards))

    return true, retobj
end

--防守
local function defend(user, card, tileid, retobj)
    LOG_DEBUG("defend: user:", user.uid, " card", card, " tileid", tileid)

    --检查状态
    if user.state ~= PlayerState.Defend then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return false, retobj
    end

    --检查出牌
    if tileid < 1 or tileid > #deskInfo.round.roundCards then --错误的牌堆
        retobj.spcode = PDEFINE.RET.ERROR.DISCARD_ERROR
        retobj.errmsg = "error tileid"
        return false, retobj
    end
    --需要有且只有一张底牌且出牌大于底牌
    local masterSuit = deskInfo.round.masterSuit
    local cards = deskInfo.round.roundCards[tileid]
    if not ((#cards == 1) and robot.compare(cards[1], card, masterSuit)) then --需要比底下的牌大
        retobj.spcode = PDEFINE.RET.ERROR.DISCARD_ERROR
        retobj.errmsg = "must large than attack card"
        return false, retobj
    end

    --清除计时器
    user:clearTimer()

    --添加到牌堆
    table.insert(cards, card)
    retobj.tileid = tileid
    --扣除手牌
    baseUtil.RemoveCard(user.round.cards, card)

    local delayTime = deskInfo.delayTime
    local singlecard = findSingleCard(deskInfo.round.roundCards)
    if singlecard then
        --如果防守未完成，则刷新计时器，继续防御
        userSetAutoState('autoDefend', delayTime, user.uid)

        deskInfo.round.activeSeat = {user.seatid}
        retobj.activeSeat = deskInfo.round.activeSeat
        retobj.activeState = PlayerState.Defend
        retobj.delayTime = delayTime
    else
        --如果防守完成
        if not checkCanKeepAttack() then
            --如果不能继续进攻，则防守成功
            deskInfo.round.activeSeat = {}
            skynet.timeout(100, function()
                roundOver(1)
            end)
        else
            --进攻玩家继续进攻
            local activeSeat = {}
            for _, seatid in ipairs(deskInfo.round.attackSeat) do
                local u = deskInfo:findUserBySeatid(seatid)
                if #u.round.cards > 0 then
                    u.state = PlayerState.Attack
                    u:clearTimer()
                    userSetAutoState('autoAttack', delayTime, u.uid)
                    table.insert(activeSeat, seatid)
                end
            end

            deskInfo.round.activeSeat = activeSeat

            retobj.activeSeat = deskInfo.round.activeSeat
            retobj.activeState = PlayerState.Attack
            retobj.delayTime = delayTime
        end
    end

    LOG_DEBUG("defend: uid:"..user.uid.." card:"..card, " desk.roundCards:"..formatRoundCards(deskInfo.round.roundCards))

    return true, retobj
end

--转移
local function transfer(user, card, retobj)
    --检查状态
    if user.state ~= PlayerState.Defend then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return false, retobj
    end
    --检查出牌
    --只有在还未开始防守的情况下，且出的牌的点数与桌面上的牌的点数相同，才能转移
    local roundCards = deskInfo.round.roundCards
    if #roundCards <= 0 then
        retobj.spcode = PDEFINE.RET.ERROR.DISCARD_ERROR
        return false, retobj
    end
    for _, cards in ipairs(roundCards) do
        if #cards ~= 1 then
            retobj.spcode = PDEFINE.RET.ERROR.DISCARD_ERROR
            retobj.errmsg = "defend has began"
            return false, retobj
        end
    end
    if baseUtil.ScanValue(card) ~= baseUtil.ScanValue(roundCards[1][1]) then
        retobj.spcode = PDEFINE.RET.ERROR.DISCARD_ERROR
        retobj.errmsg = "transfer need same value card"
        return false, retobj
    end

    --转移给下一个玩家
    local defendUser = findNextUser(user.seatid)
    if not defendUser or defendUser == user then --找不到转移的玩家
        retobj.spcode = PDEFINE.RET.ERROR.DISCARD_ERROR
        retobj.errmsg = "no next user"
        return false, retobj
    end

    --清除计时器
    user:clearTimer()

    --加入牌堆
    table.insert(deskInfo.round.roundCards, {card})
    retobj.tileid = #deskInfo.round.roundCards
    --扣除手牌
    baseUtil.RemoveCard(user.round.cards, card)

    --转移防守玩家
    user.state = PlayerState.Wait
    defendUser.state = PlayerState.Defend

    --上家和下家成为进攻方
    local attackSeats = {}
    local prevUser = findPrevUser(defendUser.seatid)
    if prevUser ~= defendUser then
        prevUser.state = PlayerState.Attack
        table.insert(attackSeats, prevUser.seatid)
    end
    local nextUser = findNextUser(defendUser.seatid)
    if nextUser ~= defendUser and nextUser ~= prevUser then
        table.insert(attackSeats, nextUser.seatid)
    end
    --原来的攻击玩家变为wait状态
    for _, u in ipairs(deskInfo.users) do
        if u.state == PlayerState.Attack and not table.contain(attackSeats, u.seatid) then
            u.state = PlayerState.Wait
        end
    end

    deskInfo.round.activeSeat = {defendUser.seatid}
    deskInfo.round.defendSeat = defendUser.seatid
    deskInfo.round.attackSeats = attackSeats
    deskInfo.round.attackSeat = {attackSeats[1]}

    local delayTime = deskInfo.delayTime
    userSetAutoState('autoDefend', delayTime, defendUser.uid)

    retobj.defendSeat = defendUser.seatid
    retobj.activeSeat = deskInfo.round.activeSeat
    retobj.activeState = PlayerState.Defend
    retobj.attackSeats = deskInfo.round.attackSeats
    retobj.attackSeat = deskInfo.round.attackSeat
    retobj.delayTime = delayTime

    return true, retobj
end

--补牌
local function addextra(user, card, retobj)
    --检查状态
    if user.state ~= PlayerState.AddExtra then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return false, retobj
    end

    --检查牌堆数量
    if not checkTileLimit() then
        retobj.spcode = PDEFINE.RET.ERROR.DISCARD_ERROR
        retobj.errmsg = "tiles limit exceed"
        return false, retobj
    end

    --检查出牌
    --需要与桌面上任意一张牌的点数相同
    if not robot.checkSameValue(card, deskInfo.round.roundCards) then
        retobj.spcode = PDEFINE.RET.ERROR.DISCARD_ERROR
        retobj.errmsg = "not same value with other cards"
        return false, retobj
    end

    --添加到牌堆
    table.insert(deskInfo.round.roundCards, {card})
    retobj.tileid = #deskInfo.round.roundCards
    --扣除手牌
    baseUtil.RemoveCard(user.round.cards, card)

    if not checkCanKeepAttack() then
        --进攻完成，防守失败
        deskInfo.round.activeSeat = {}
        skynet.timeout(100, function()
            roundOver(2)
        end)

        --玩家状态通知
        local userState = {}
        for _, u in ipairs(deskInfo.users) do
            if u.state == PlayerState.AddExtra then
                u.state = PlayerState.Pass
                table.insert(userState, {seatid=u.seatid, state=u.state})
            end
        end
        if #userState > 0 then
            retobj.userState = userState
        end
    else
        --刷新定时器
        local delayTime = deskInfo.delayTime
        local activeSeat = {}
        for _, u in ipairs(deskInfo.users) do
            if u.state == PlayerState.AddExtra then
                u:clearTimer()
                userSetAutoState('autoAddExtra', delayTime, u.uid)
                table.insert(activeSeat, u.seatid)
            end
        end

        deskInfo.round.activeSeat = activeSeat

        retobj.activeSeat = deskInfo.round.activeSeat
        retobj.activeState = PlayerState.AddExtra
        retobj.delayTime = delayTime
    end

    LOG_DEBUG("addextra: uid:"..user.uid.." card:"..card, " desk.roundCards:"..formatRoundCards(deskInfo.round.roundCards))

    return true, retobj
end

--用户出牌
function CMD.discard(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    local card = math.sfloor(recvobj.card)
    local op = math.sfloor(recvobj.op)   --op:1 进攻  2:防守  3:转移 4:补牌
    local tileid = math.sfloor(recvobj.tileid)

    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.op     = op
    retobj.uid    = uid
    retobj.card   = card
    retobj.tileid = tileid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    LOG_DEBUG("discard: user:"..uid, " card:"..card, " op:"..op)
    -- 检测参数
    if (not card) or (not op) or (op < 1 or op > 4) then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        return warpResp(retobj)
    end

    -- 检测用户
    local user = deskInfo:findUserByUid(uid)
    local ok
    ok, retobj = checkUser(user, retobj)
    if not ok then
        return warpResp(retobj)
    end

    --检查手牌
    if not table.contain(user.round.cards, card) then
        retobj.spcode = PDEFINE.RET.ERROR.HAND_CARDS_ERROR
        return warpResp(retobj)
    end

    if op == 1 then --进攻出牌
        ok, retobj = attack(user, card, retobj)
    elseif op == 2 then --防御出牌
        ok, retobj = defend(user, card, tileid, retobj)
    elseif op == 3 then --转移出牌
        ok, retobj = transfer(user, card, retobj)
    elseif op == 4 then --添加额外牌
        ok, retobj = addextra(user, card, retobj)
    end
    if not ok then
        return warpResp(retobj)
    end

    --补牌玩家
    if not table.contain(deskInfo.round.drawSeats, user.seatid) then
        table.insert(deskInfo.round.drawSeats, user.seatid)
    end

    --当前桌牌
    retobj.roundCards = table.copy(deskInfo.round.roundCards)

    --广播给房间里的所有人
    local notify_object = table.copy(retobj)
    notify_object.c  = PDEFINE.NOTIFY.PLAYER_DISCARD
    deskInfo:broadcast(cjson.encode(notify_object), uid)

    -- 返回操作结果
    return warpResp(retobj)
end

function CMD.enterAuto(source, msg)
    local recvobj  = msg
    local uid = math.sfloor(recvobj.uid)
    local user = deskInfo:findUserByUid(uid)

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

    local retobj = {c = recvobj.cmd, code= PDEFINE.RET.SUCCESS, spcode=0}
    if user.auto == 0 then
        return warpResp(retobj)
    end

    user:clearTimer()
    user.auto = 0 --关闭自动

    -- 根据状态，重新开启计时器
    if user.state == PlayerState.Attack then
        retobj.delayTime = deskInfo.delayTime
        userSetAutoState('autoAttack', retobj.delayTime, uid)
    elseif user.state == PlayerState.Defend then
        retobj.delayTime = deskInfo.delayTime
        userSetAutoState('autoDefend', retobj.delayTime, uid)
    elseif user.state == PlayerState.AddExtra then
        retobj.delayTime = deskInfo.delayTime
        userSetAutoState('autoAddExtra', retobj.delayTime, uid)
    end

    deskInfo:autoMsgNotify(user, 0, retobj.delayTime)

    return warpResp(retobj)
end

-- 更新玩家的桌子信息
function CMD.updateUserClusterInfo(source, uid, _agent)
    deskInfo:updateUserAgent(uid, _agent)
end

-- 用户离线获取牌桌信息
function CMD.getDeskInfo(source, msg)
    local userInfo = deskInfo:findUserByUid(msg.uid)
    local deskInfoStr = deskInfo:toResponse(msg.uid)

    LOG_DEBUG("getDeskInfo msg:", msg)
    return deskInfoStr
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
    agent.func = {
        gameOver = gameOver,
        roundOver = roundOver,
    }
    -- 创建房间
    local err = agent:createRoom(msg, deskid, gameid, cluster_info)
    if err then
        return err
    end

    if not deskInfo.params then
        deskInfo.params = {}
    end
    deskInfo.params.Seats = deskInfo.seat
    deskInfo.params.AttackType = config.AttackType.Neighbors
    local cardDeck = 36
    if deskInfo.conf.maxScore then
        if table.contain(config.CardDeck, deskInfo.conf.maxScore) then
            cardDeck = deskInfo.conf.maxScore --maxScore表示牌数
        end
        if deskInfo.seat <= 2 then
            cardDeck = math.min(cardDeck, config.CardDeck[2])
        elseif deskInfo.seat >= 5 then
            cardDeck = math.max(cardDeck, config.CardDeck[2])
        end
    else
        --匹配场次，2人24张牌，3~5人36张牌，6人52张牌
        if deskInfo.seat <= 2 then
            cardDeck = config.CardDeck[1]
        elseif deskInfo.seat > 5 then
            cardDeck = config.CardDeck[3]
        end
    end
    deskInfo.params.CardDeck = cardDeck

    -- 获取桌子回复
    local deskInfoStr = deskInfo:toResponse(deskInfo.owner)

    return PDEFINE.RET.SUCCESS, deskInfoStr
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
            return err, retobj
        end
        -- 获取加入房间回复
        local retobj = agent:joinRoomResponse(msg.c, uid)

        -- 检测是否可以开始游戏
        local canStart = agent:checkStart()
        if canStart then
            skynet.timeout(300, startGame)
        end
        return warpResp(retobj)
    end)
end

-- 准备，如果是私人房，则有这个阶段
function CMD.ready(source, msg)
    local recvobj = msg
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
        pcall(cluster.send, viewer.cluster_info.server, viewer.cluster_info.address, "deskBack", deskInfo.gameid) --释放桌子对象
    end
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