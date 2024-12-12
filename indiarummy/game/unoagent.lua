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
local cs = queue()
local GAME_NAME = skynet.getenv("gamename") or "game"
local DEBUG = skynet.getenv("DEBUG")
local CMD = {}
local closeServer = false

math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 7)))

--[[
    规则: 
    1. 四个人玩，四种花色牌，加上特殊牌
    2. 按照花色出牌，或者出特殊牌，特殊牌有特殊功能
    3. 不能出牌就摸牌一张
    4. 最后留在手里的牌最多，则输的分最多
]]

---@type BaseDeskInfo @instance of unoagent
local deskInfo = nil  -- 桌子信息
---@type BaseAgent
local agent = nil  -- 游戏实例
local biddingAddTime = 2 -- 叫牌增加时间
local LastDealerSeat = nil

local config = {
    -- 0x1* 红色, 0x2* 黄色, 0x3* 绿色, 0x4* 蓝色, 0x5* 黑色
    -- 0x10-0x19 代表10张数字牌
    -- 0x1a +2牌, 下家跳过当轮，切摸牌两张
    -- 0x1b 禁止牌，下家跳过当轮
    -- 0x1c 转向牌, 调转出牌顺序
    -- 0x5d 万能牌，可以改变出牌颜色, 落地后变得相应颜色的牌
    -- 0x5e 王牌, 可以让下家额外多摸4张且跳过当轮, 可以改变出牌颜色, 落地后变得相应颜色的牌
    Cards = {
        -- 面值是0的扑克，每个颜色只有一张
        0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,
        0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,
        0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,
        0x40,0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,

        0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,
        0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,
        0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,
        0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,
        -- 万能牌和王牌，黑色四张
        0x5D,0x5D,0x5D,0x5D,0x5E,0x5E,0x5E,0x5E,
    },
    -- 发牌数量
    InitCardLen = 7,
    -- 托管和自动操作之间的延迟时间
    AutoDelayTime = 50,
    wildCard = 0x5d,
    drawFourCard = 0x5e,
    ChallengeDelayTime = 6,  -- 质疑时长, 暂时没用，和出牌时间一样
}

local robot = {}

-- 判断是否是 +2 牌
robot.isDrawTwoCard = function (card)
    return baseUtil.ScanValue(card) == 0x0a and baseUtil.ScanSuit(card) < 5
end

-- 判断是否是 禁止 牌
robot.isSkipCard = function (card)
    return baseUtil.ScanValue(card) == 0x0b and baseUtil.ScanSuit(card) < 5
end

-- 判断是否是 转向 牌
robot.isReverseCard = function (card)
    return baseUtil.ScanValue(card) == 0x0c and baseUtil.ScanSuit(card) < 5
end

-- 判断是否是 万能 牌
robot.isWildCard = function (card)
    return baseUtil.ScanValue(card) == baseUtil.ScanValue(config.wildCard)
end

-- 判断是否是 王 牌
robot.isDrawFourCard = function (card)
    return baseUtil.ScanValue(card) == baseUtil.ScanValue(config.drawFourCard)
end

-- 根据最后一张牌找出当前可出牌
robot.getMaybeCards = function (user)
    if #deskInfo.round.discardCards == 0 then
        return user.round.cards
    end
    local lastCard = deskInfo.round.discardCards[#deskInfo.round.discardCards]
    local maybeCards = {}
    for _, c in ipairs(user.round.cards) do
        if c == config.wildCard or c == config.drawFourCard then
            table.insert(maybeCards, c)
        elseif baseUtil.ScanSuit(c) == baseUtil.ScanSuit(lastCard) or baseUtil.ScanValue(c) == baseUtil.ScanValue(lastCard) then
            table.insert(maybeCards, c)
        end
    end
    return maybeCards
end

-- 找出机器人的maybeCards
-- 如果有普通牌，优先普通牌，没有才会出特殊牌
robot.getAutoMaybeCards = function (user)
    if #deskInfo.round.discardCards == 0 then
        return user.round.cards
    end
    local lastCard = deskInfo.round.discardCards[#deskInfo.round.discardCards]
    local maybeCards = {}
    for _, c in ipairs(user.round.cards) do
        if baseUtil.ScanSuit(c) == baseUtil.ScanSuit(lastCard) or baseUtil.ScanValue(c) == baseUtil.ScanValue(lastCard) then
            table.insert(maybeCards, c)
        end
    end
    if #maybeCards == 0 then
        for _, c in ipairs(user.round.cards) do
            if c == config.wildCard or c == config.drawFourCard then
                table.insert(maybeCards, c)
            end
        end
    end
    return maybeCards
end

-- 找出当前手牌最多花色
robot.getMaybeSuit = function (user)
    local maxSuit = math.random(4)
    local maxCnt = 0
    local suitMap = {}
    for _, c in ipairs(user.round.cards) do
        local _s = baseUtil.ScanSuit(c)
        if _s < 5 then
            if not suitMap[_s] then
                suitMap[_s] = 1
            else
                suitMap[_s] = suitMap[_s] + 1
            end
            if suitMap[_s] > maxCnt then
                maxSuit = _s
                maxCnt = suitMap[_s]
            end
        end
    end
    return maxSuit
end

-- 重新洗牌
robot.reShuffle = function ()
    if #deskInfo.round.discardCards < 3 then
        return
    end
    local maxIdx = #deskInfo.round.discardCards - 2
    for i = 1, maxIdx do
        local c = deskInfo.round.discardCards[i]
        if robot.isWildCard(c) or robot.isDrawFourCard(c) then
            c = robot.isWildCard(c) and config.wildCard or config.drawFourCard
        end
        table.insert(deskInfo.round.cards, c)
    end
    shuffle(deskInfo.round.cards)
    deskInfo.round.discardCards = {deskInfo.round.discardCards[maxIdx+1], deskInfo.round.discardCards[maxIdx+2]}
end

-- 成功返回
local function warpResp(retobj)
    return PDEFINE.RET.SUCCESS, retobj
end

-- 找对家
local function findTeamSeatid(seatid)
    if seatid == 1 then
        return 3
    elseif seatid == 2 then
        return 4
    elseif seatid == 3 then
        return 1
    else
        return 2
    end
end

-- 是否组队玩法
local function isPartnerGame()
    return deskInfo.gameid == PDEFINE.GAME_TYPE.UNO_PARTNER
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
    if not table.contain(state, user.state) then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return false, retobj
    end
    return true, retobj
end

local function initDeskInfoRound(uid, seatid)
    deskInfo.round = {}
    deskInfo.round.cards = {} -- 堆上的牌
    deskInfo.round.discardCards = {} -- 弃牌堆上的牌
    deskInfo.round.activeSeat = seatid -- 当前活动座位
    deskInfo.round.settle = {} -- 小结算
    deskInfo.round.multiple = 1 --房间倍数
    deskInfo.round.dealer = { ----此把的庄家(庄家的下家选牌型和出牌)
        uid = uid,
        seatid = seatid
    }
    deskInfo.round.currSuit = nil  -- 当前花色
    deskInfo.round.isReverse = false -- 是否调转
    -- 随机堆上的牌
    deskInfo.round.cards = table.copy(config.Cards)
    shuffle(deskInfo.round.cards)
end

---@param user BaseUser
local function initUserRound(user)
    user.state       = PDEFINE.PLAYER_STATE.Wait
    user.round = {}
    user.round.score       = 0 -- 轮分
    user.round.cards       = {} -- 手中的牌
    user.round.isWin       = 0  -- 是否赢了
    user.round.uno         = 0  -- 0: 为不可uno, 1: 为已uno, 2: 为可uno但是未uno
    user.round.drawCard    = nil  -- 这个值只有在可选择是否出牌的情况下有用
end

-- 检测自己是否可以uno
local function checkUno(user)
    if not user.cluster_info and #user.round.cards == 2 then
        local msg = {
            ['c'] = 25725,
            ['uid'] = user.uid
        }
        CMD.uno(nil, msg)
        return true
    end
    return false
end

-- 检测上家是否漏掉uno
local function checkUnoChallenge(user)
    if user.cluster_info then
        return false
    end
    local prevUser = deskInfo:findPrevUser(user.seatid, deskInfo.round.isReverse)
    if prevUser.round.uno == 2 then
        local msg = {
            ['c'] = 25726,
            ['uid'] = user.uid
        }
        CMD.unoChallenge(nil, msg)
        return true
    end
    return false
end

-- 去掉uno标记
local function clearUno(uid)
    -- 如果玩家没叫uno，且当前牌只剩余1个，则标记为可uno Challenge状态
    -- 下一个玩家出牌之后，这个状态就清零了
    for _, u in ipairs(deskInfo.users) do
        if u.uid ~= uid then
            if u.round.uno == 2 then
                skynet.timeout(20, function()
                    -- 广播消息给其他玩家
                    local notify_obj = {}
                    notify_obj.c = PDEFINE.NOTIFY.PLAYER_CAN_UNO_CHALLENGE
                    notify_obj.code = PDEFINE.RET.SUCCESS
                    notify_obj.seat = u.seatid
                    notify_obj.uid  = u.uid
                    notify_obj.rtype = 0  -- 0 代表逃过一劫
                    deskInfo:broadcast(cjson.encode(notify_obj))
                end)
                -- 逃过一劫之后，标记成uno状态
                u.round.uno = 1
            end
        end
    end
end

-- 自动出牌
local function autoDiscard(uid)
    return cs(function()
        deskInfo:print("用户自动出牌 uid:".. uid)
        
        local user = deskInfo:findUserByUid(uid)
        user:clearTimer()
        if deskInfo.round.activeSeat ~= user.seatid then
            deskInfo:print("出牌对象错误: uid:", uid, ' seatid:', user.seatid, " activeSeat:", deskInfo.round.activeSeat)
            return
        end
        local delayTime = 1
        if user.cluster_info then
            if user.auto == 0 then
                user.auto = 1
                delayTime = config.AutoDelayTime
                deskInfo:autoMsgNotify(user, 1, 0)
            end
        end
        -- 还需要检测自己是否可以uno
        local result = checkUno(user)
        if result then
            delayTime = delayTime + config.AutoDelayTime
        end
        -- 如果是进入托管，则延后一点操作
        skynet.timeout(delayTime, function()
            -- 找牌
            local cards = robot.getAutoMaybeCards(user)
            if #cards == 0 then
                deskInfo:print("自动出牌 找不到可出牌:", user.round.cards, "最后牌: ", deskInfo.round.discardCards[#deskInfo.round.discardCards])
                local msg = {
                    ['c'] = 25703,
                    ['uid'] = uid,
                }
                local _, resp = CMD.draw(nil, msg)
                deskInfo:print("没牌可出，只能抓牌 msg:", msg, "返回: ", resp)
                if user.cluster_info then
                    if user.isexit == 0 and resp.spcode == 0 then
                        pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(resp))
                    end
                end
            else
                local randCard
                if user.round.intentCard and (
                    table.contain(cards, user.round.intentCard) or
                    user.round.intentCard == config.wildCard or
                    user.round.intentCard == config.drawFourCard
                ) then
                    randCard = user.round.intentCard
                else
                    randCard = cards[math.random(#cards)]
                end
                if robot.isWildCard(randCard) or robot.isDrawFourCard(randCard) then
                    local suit = robot.getMaybeSuit(user)
                    randCard = baseUtil.ScanValue(randCard) + suit*16
                end
                local msg = {
                    ['c'] = 25702,
                    ['uid'] = uid,
                    ['card'] = randCard
                }
                local _, resp = CMD.discard(nil, msg)
                deskInfo:print("自动出牌 msg:", msg, "返回: ", resp)
                if user.cluster_info then
                    if user.isexit == 0 and resp.spcode == 0 then
                        pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(resp))
                    end
                end
            end
        end)
    end)
end

-- 自动抓牌
local function autoDraw(uid)
    return cs(function()
        deskInfo:print("用户自动抓牌 uid:".. uid)
        
        local user = deskInfo:findUserByUid(uid)
        user:clearTimer()
        if deskInfo.round.activeSeat ~= user.seatid then
            deskInfo:print("抓牌对象错误: uid:", uid, ' seatid:', user.seatid, " activeSeat:", deskInfo.round.activeSeat)
            return
        end
        local delayTime = 1
        if user.cluster_info then
            if user.auto == 0 then
                user.auto = 1
                delayTime = config.AutoDelayTime
                deskInfo:autoMsgNotify(user, 1, 0)
            end
        end
        -- 如果是进入托管，则延后一点操作
        skynet.timeout(delayTime, function()
            -- 出牌
            local msg = {
                ['c'] = 25703,
                ['uid'] = uid,
            }
            local _, resp = CMD.draw(nil, msg)
            deskInfo:print("自动抓牌 msg:", msg, "返回: ", resp)
            if user.cluster_info then
                if user.isexit == 0 and resp.spcode == 0 then
                    pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(resp))
                end
            end
        end)
    end)
end

-- 自动抓牌打出
-- 自动抓牌
local function autoDiscardPass(uid)
    return cs(function()
        deskInfo:print("用户自动打出抓的牌 uid:".. uid)

        local user = deskInfo:findUserByUid(uid)
        user:clearTimer()
        if deskInfo.round.activeSeat ~= user.seatid then
            deskInfo:print("操作对象错误: uid:", uid, ' seatid:', user.seatid, " activeSeat:", deskInfo.round.activeSeat)
            return
        end
        local delayTime = 1
        if user.cluster_info then
            if user.auto == 0 then
                user.auto = 1
                delayTime = config.AutoDelayTime
                deskInfo:autoMsgNotify(user, 1, 0)
            end
        end
        -- 如果是进入托管，则延后一点操作
        skynet.timeout(delayTime, function()
            -- 找牌
            local cards = robot.getMaybeCards(user)
            local _, resp,msg
            local card = user.round.drawCard
            if table.contain(cards, user.round.drawCard) and (not user.cluster_info or user.round.intentCard == card) then
                if robot.isWildCard(card) or robot.isDrawFourCard(card) then
                    local suit = robot.getMaybeSuit(user)
                    card = baseUtil.ScanValue(card) + suit*16
                end
                msg = {
                    ['c'] = 25702,
                    ['uid'] = uid,
                    ['card'] = card,
                }
                _, resp = CMD.discard(nil, msg)
            else
                -- 如果不能出，则选择过
                msg = {
                    ['c'] = 25715,
                    ['uid'] = uid
                }
                _, resp = CMD.pass(nil, msg)
            end
            deskInfo:print("自动出牌 msg:", msg, "返回: ", resp)
            if user.cluster_info then
                if user.isexit == 0 and resp.spcode == 0 then
                    pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(resp))
                end
            end
        end)
    end)
end

-- 自动提出质疑
local function autoChallenge(uid)
    return cs(function()
        deskInfo:print("用户自动放弃质疑 uid:".. uid)

        local user = deskInfo:findUserByUid(uid)
        user:clearTimer()
        if deskInfo.round.activeSeat ~= user.seatid then
            deskInfo:print("操作对象错误: uid:", uid, ' seatid:', user.seatid, " activeSeat:", deskInfo.round.activeSeat)
            return
        end
        -- 找牌
        local msg = {
            ['c'] = 25727,
            ['uid'] = uid,
            ['rtype'] = 0,  -- 默认不质疑
        }
        local _, resp = CMD.challenge(nil, msg)
        deskInfo:print("不质疑 msg:", msg, "返回: ", resp)
        if user.cluster_info then
            if user.isexit == 0 and resp.spcode == 0 then
                pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(resp))
            end
        end
    end)
end

-- 自动准备
local function autoReady(uid)
    return cs(function()
        deskInfo:print("自动准备 uid:".. uid)
        local user = deskInfo:findUserByUid(uid)
        
        if not user or user.state == PDEFINE.PLAYER_STATE.Ready then
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

local function setAutoReady(delayTime, uid)
    CMD.userSetAutoState('autoReady', delayTime, uid)
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
local function roundStart(addTime)
    deskInfo.state = PDEFINE.DESK_STATE.PLAY
    if not addTime then
        addTime = 0
    end
    local retobj = {}
    LOG_DEBUG("开始游戏: deskid:", deskInfo.uuid)
    -- 设置庄家的下一家为出牌用户
    local dealer = deskInfo:findUserByUid(deskInfo.round.dealer['uid'])
    deskInfo.curround = deskInfo.curround + 1
    -- 设置定时器
    retobj.c = PDEFINE.NOTIFY.GAME_DEAL
    retobj.code = PDEFINE.RET.SUCCESS

    -- 开始发牌
    retobj.cards = nil
    retobj.delayTime = deskInfo.delayTime
    for _, user in pairs(deskInfo.users) do
        local cards = {}
        if user.luckBuff then
            local randNum = math.random(2, 5)
            local luckCards = {0x5D,0x5D,0x5D,0x5D,0x5E,0x5E,0x5E,0x5E,}
            local cards = {}
            for _, card in ipairs(deskInfo.round.cards) do
                if table.contain(luckCards, card) and randNum > 0 then
                    table.insert(cards, card)
                    randNum = randNum - 1
                else
                    table.insert(cards, 1, card)
                end
            end
            deskInfo.round.cards = cards
        end
        for i = 1, config.InitCardLen do
            local card = table.remove(deskInfo.round.cards)
            table.insert(cards, card)
        end
        -- if user.seatid == 4 then
        --     cards = {0x1a, 0x1a, 0x11, 0x12}
        -- end
        user.round.cards = table.copy(cards)
        user.round.initcards = table.copy(cards)
    end

    local users = table.copy(deskInfo.users)
    for _, user in ipairs(users) do
        -- 去掉连接信息
        user.cluster_info = nil
        -- 去掉定时器信息
        user.timer = nil
        user.luckBuff = nil
        user.isexit = nil
        user.realCoin = nil
        user.settlewin = nil
        user.winTimes = nil
        user.wincoin = nil
        user.wincoinshow = nil
        -- cjson不支持function
        for key, v in pairs(user) do
            if type(v) == 'function' then
                user[key] = nil
            end
        end
        -- 清除元表
        user = setmetatable(user, {})
    end
    retobj.users = users

    retobj.activeUid = dealer.uid
    retobj.dealerUid = dealer.uid

    -- 先确定第一张牌
    local card = table.remove(deskInfo.round.cards)
    while baseUtil.ScanSuit(card) == 5 or baseUtil.ScanValue(card) >= 10 do
        table.insert(deskInfo.round.cards, 1, card)
        card = table.remove(deskInfo.round.cards)
    end
    retobj.firstCard = card  -- 第一张牌
    table.insert(deskInfo.round.discardCards, card)
    -- 告知前端可选择玩法
    deskInfo.round.activeSeat = dealer.seatid

    for _, user in pairs(deskInfo.users) do
        local delayTime = retobj.delayTime
        -- 庄家切换到出牌阶段
        if user.seatid == dealer.seatid then
            -- 切换状态
            user.state = PDEFINE.PLAYER_STATE.Discard
            -- 设置定时器
            -- 刚开局，时间设置久一点
            CMD.userSetAutoState('autoDiscard', delayTime, user.uid, addTime)
        else
            user.state = PDEFINE.PLAYER_STATE.Wait
        end
        retobj.cards = table.copy(user.round.cards)
        -- 广播消息
        if user.cluster_info and user.isexit == 0 then
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(retobj))
        end
    end
    retobj.cards = {}
    deskInfo:broadcastViewer(cjson.encode(retobj))
end

-- 创建房间后第1次开始游戏
---@param delayTime nil 用于指定发牌前的延迟时间
local function startGame(delayTime)
    if deskInfo.state ~= PDEFINE.DESK_STATE.MATCH and deskInfo.state ~= PDEFINE.DESK_STATE.READY then
        return
    end
    -- 调用基类的开始游戏
    deskInfo:startGame()
    -- 庄家
    local dealer
    if LastDealerSeat then
        dealer = deskInfo:findNextUser(LastDealerSeat)
    else
        -- 随机庄家
        dealer = deskInfo.users[math.random(#deskInfo.users)]
    end

    LOG_DEBUG("dealer", dealer.uid, dealer.seatid)
    LastDealerSeat = dealer.seatid
    -- 初始化桌子信息
    deskInfo:initDeskRound(dealer.uid, dealer.seatid)
    -- LOG_DEBUG("deskInfo ", deskInfo)
    if delayTime then
        delayTime = delayTime * 100
    else
        delayTime = 30
    end
    skynet.timeout(delayTime, function()
        -- 调用基类的新的一轮
        deskInfo:roundStart()
        roundStart(4)
    end)
end

-- 游戏结束，大结算
local function gameOver(isDismiss)
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
    end
    local delayTime = os.time() - deskInfo.conf.create_time

    -- 如果是分队玩法，分数等于两个队友之和
    for _, user in ipairs(deskInfo.users) do
        settle.scores[user.seatid] = user.score
    end
    -- 这个游戏会有两种情况，一种是打对的情况，一种是各自单干
    local oneself = true
    deskInfo:gameOver(settle, isDismiss, oneself)
end

-- 此轮游戏结束
local function roundOver()
    deskInfo.state = PDEFINE.DESK_STATE.SETTLE
    -- 清除玩家定时器
    -- 处理玩家状态
    for _, user in ipairs(deskInfo.users) do
        user.state = PDEFINE.PLAYER_STATE.Wait
        user:clearTimer()
    end
    local retobj = {}
    retobj.c = PDEFINE.NOTIFY.GAME_ROUND_OVER
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.settle = {}  -- 四个位置上的分数
    for i = 1, deskInfo.seat do
        retobj.settle[i] = 0
    end
    retobj.spcode = 0

    -- 结算每个人剩余牌的分数
    for _, user in ipairs(deskInfo.users) do
        for _, card in ipairs(user.round.cards) do
            if baseUtil.ScanValue(card) < 10 then
                user.round.score = user.round.score - baseUtil.ScanValue(card)
            elseif robot.isDrawFourCard(card) or robot.isWildCard(card) then
                user.round.score = user.round.score - 50
            else
                user.round.score = user.round.score - 20
            end
        end
        if #user.round.cards > 0 and user.round.score == 0 then
            user.round.score = -1
        end
        retobj.settle[user.seatid] = user.round.score
        user.score = user.score + user.round.score
    end

    local dealer = deskInfo:findUserByUid(deskInfo.round.dealer.uid)

    local allCards = {}
    for _, user in ipairs(deskInfo.users) do
        table.insert(allCards, {
            uid = user.uid,
            cards = user.round.initcards
        })
    end

    --结算小局记录
    local multiple = 1
    deskInfo:recordDB(0, dealer.uid, retobj.settle, allCards, multiple)

    local notifyMsg = function ()
        -- 维护强行大结算
        if isMaintain() then
            agent:gameOver(true)
        else
            agent:gameOver()
        end
    end
    skynet.timeout(100, notifyMsg)

    deskInfo:broadcast(cjson.encode(retobj))
    
    return PDEFINE.RET.SUCCESS
end

-------- 设定玩家定时器 --------
function CMD.userSetAutoState(type,autoTime,uid,extraTime)
    deskInfo.round.expireTime = os.time() + autoTime
    -- 调试期间，机器人只间隔2秒操作
    local user = deskInfo:findUserByUid(uid)
    user:clearTimer()
    if not user.cluster_info then
        local maxTime = autoTime > PDEFINE_GAME.NUMBER.maxOptTime and PDEFINE_GAME.NUMBER.maxOptTime or autoTime
        local minTime = autoTime < PDEFINE_GAME.NUMBER.minOptTime and autoTime or PDEFINE_GAME.NUMBER.minOptTime
        autoTime = math.random(minTime, maxTime)
    end
    if type ~= "autoReady" and user.auto == 1 then
        autoTime = 1
    end
    if extraTime then
        autoTime = autoTime + extraTime
    end
    if DEBUG and false and type ~= "autoChallenge" and user.cluster_info and user.isexit == 0 then
        autoTime = 1000000
    end

    -- 放弃质疑
    if type == "autoChallenge" then
        user:setTimer(autoTime, autoChallenge, uid)
    end
    -- 自动抓牌
    if type == "autoDiscardPass" then
        user:setTimer(autoTime, autoDiscardPass, uid)
    end
    -- 自动出牌
    if type == "autoDraw" then
        -- 如果操作对象是机器人，则需要判断上家是否漏uno
        checkUnoChallenge(user)
        user:setTimer(autoTime, autoDraw, uid)
    end
    -- 自动出牌
    if type == "autoDiscard" then
        -- 如果操作对象是机器人，则需要判断上家是否漏uno
        checkUnoChallenge(user)
        user:setTimer(autoTime, autoDiscard, uid)
    end
    -- 自动准备
    if type == "autoReady" then
        user:setTimer(autoTime, autoReady, uid, true)
    end

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

-- 用户选择过
function CMD.pass(_, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    -- 检测用户
    local user = deskInfo:findUserByUid(uid)
    local ok
    ok, retobj = checkUserAndState(user, {PDEFINE.PLAYER_STATE.DiscardPass}, retobj)
    if not ok then
        return warpResp(retobj)
    end

    -- 清除计时器
    user:clearTimer()
    -- 设置状态，防止重复操作
    user.state = PDEFINE.PLAYER_STATE.Wait
    user.round.drawCard = nil  -- 这个值只有在可选择是否出牌的情况下有用

    -- 选择过，则调到下一个玩家
    local nextUser = deskInfo:findNextUser(user.seatid, deskInfo.round.isReverse)
    nextUser.state = PDEFINE.PLAYER_STATE.Discard
    retobj.delayTime = deskInfo.delayTime
    deskInfo.round.activeSeat = nextUser.seatid
    CMD.userSetAutoState('autoDiscard', deskInfo.delayTime, nextUser.uid)

    retobj.nextUid = nextUser.uid
    retobj.nextState = nextUser.state

    -- 广播给房间里的所有人
    local notify_object = {}
    notify_object.c  = PDEFINE.NOTIFY.PLAYER_PASS
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.seat = user.seatid
    notify_object.uid    = uid
    notify_object.nextUid  = retobj.nextUid
    notify_object.nextState  = retobj.nextState
    notify_object.delayTime = retobj.delayTime
    deskInfo:broadcast(cjson.encode(notify_object))

    return warpResp(retobj)
end

-- 用户先指定意向牌
function CMD.intentCard(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local card = math.floor(recvobj.card)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    LOG_DEBUG("用户意向牌: user:", uid, " card", card)
    -- 检测参数
    if not card then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        return warpResp(retobj)
    end

    -- 判断出的牌是否存在
    if card < 0x10 or card > 0x5E then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        return warpResp(retobj)
    end

    -- 检测用户
    local user = deskInfo:findUserByUid(uid)
    local ok
    ok, retobj = checkUserAndState(user, {PDEFINE.PLAYER_STATE.Discard, PDEFINE.PLAYER_STATE.DiscardPass}, retobj)
    if not ok then
        return warpResp(retobj)
    end

    if not table.contain(user.round.cards, card) then
        retobj.spcode = PDEFINE.RET.ERROR.HAND_CARDS_ERROR
        return warpResp(retobj)
    end

    retobj.card = card
    user.round.intentCard = card

    return warpResp(retobj)
end

-- 用户出牌
function CMD.discard(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local card = math.floor(recvobj.card)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    LOG_DEBUG("用户出牌: user:", uid, " card", card)
    -- 检测参数
    if not card then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        return warpResp(retobj)
    end

    -- 判断出的牌是否存在
    if card < 0x10 or card > 0x5E then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        return warpResp(retobj)
    end

    retobj.card = card

    -- 检测用户
    local user = deskInfo:findUserByUid(uid)
    local ok
    ok, retobj = checkUserAndState(user, {PDEFINE.PLAYER_STATE.Discard, PDEFINE.PLAYER_STATE.DiscardPass}, retobj)
    if not ok then
        return warpResp(retobj)
    end

    -- 出的牌对应的手牌(黑色牌会转成其他颜色的牌)
    local srcCard = card
    -- 如果是万能牌和+4牌，则不需要判断花色和值，否则需要判断是否合理
    if robot.isWildCard(card) or robot.isDrawFourCard(card) then
        srcCard = robot.isWildCard(card) and config.wildCard or config.drawFourCard
    else
        if #deskInfo.round.discardCards > 0 then
            local lastCard = deskInfo.round.discardCards[#deskInfo.round.discardCards]
            if baseUtil.ScanSuit(card) ~= baseUtil.ScanSuit(lastCard) and baseUtil.ScanValue(card) ~= baseUtil.ScanValue(lastCard) then
                retobj.spcode = PDEFINE.RET.ERROR.DISCARD_ERROR
                return warpResp(retobj)
            end
        end
    end

    if user.state == PDEFINE.PLAYER_STATE.DiscardPass and user.round.drawCard then
        if user.round.drawCard ~= srcCard then
            retobj.spcode = PDEFINE.RET.ERROR.DISCARD_ERROR
            return warpResp(retobj)
        else
            if #user.round.cards == 2 and user.cluster_info then
                -- 广播uno
                user.round.uno = 1
                local notify_object = {}
                notify_object.c  = PDEFINE.NOTIFY.PLAYER_UNO
                notify_object.code = PDEFINE.RET.SUCCESS
                notify_object.seat = user.seatid
                notify_object.uid    = uid
                notify_object.success    = 1
                deskInfo:broadcast(cjson.encode(notify_object))
            end
        end
    end

    -- 扣除手牌
    local finalCards = baseUtil.RemoveCard(user.round.cards, srcCard)
    if not finalCards then
        retobj.spcode = PDEFINE.RET.ERROR.HAND_CARDS_ERROR
        return warpResp(retobj)
    end
    user.round.cards = finalCards
    user.round.intentCard = nil  -- 重置意向牌
    -- 清除计时器
    user:clearTimer()
    -- 设置状态，防止连续出牌
    user.state = PDEFINE.PLAYER_STATE.Wait
    user.round.drawCard = nil  -- 这个值只有在可选择是否出牌的情况下有用

    clearUno(uid)
    if #user.round.cards == 1 and user.round.uno == 0 then
        user.round.uno = 2
        skynet.timeout(30, function()
            -- 广播消息给其他玩家
            local notify_obj = {}
            notify_obj.c = PDEFINE.NOTIFY.PLAYER_CAN_UNO_CHALLENGE
            notify_obj.code = PDEFINE.RET.SUCCESS
            notify_obj.seat = user.seatid
            notify_obj.uid  = user.uid
            notify_obj.rtype = 1  -- 1代表可以进行uno挑战
            deskInfo:broadcast(cjson.encode(notify_obj))
        end)
    end

    -- 加入到弃牌堆
    table.insert(deskInfo.round.discardCards, card)

    -- 是否结束当轮游戏
    local isOver = 0

    -- 如果是特殊牌，则带有特殊功能，需要应用
    retobj.actionInfo = {
        cardCnt = 0,  -- 下家需要摸牌的数量
        isSkip = false, -- 下家是否跳过
        isReverse = false,  -- 是否调转顺序
    }
    retobj.reShuffle = false
    if robot.isDrawFourCard(card) then
        retobj.actionInfo.isSkip = true
        retobj.actionInfo.cardCnt = 4
    elseif robot.isDrawTwoCard(card) then
        retobj.actionInfo.isSkip = true
        retobj.actionInfo.cardCnt = 2
    elseif robot.isReverseCard(card) then
        retobj.actionInfo.isReverse = true
        deskInfo.round.isReverse = not deskInfo.round.isReverse
    elseif robot.isSkipCard(card) then
        retobj.actionInfo.isSkip = true
    end
    retobj.delayTime = deskInfo.delayTime
    local nextUser = deskInfo:findNextUser(user.seatid, deskInfo.round.isReverse)
    -- 如果是+4牌，则还有一个流程，用户可以选择是否质疑
    if robot.isDrawFourCard(card) then
        nextUser.state = PDEFINE.PLAYER_STATE.WaitChallenge
    elseif retobj.actionInfo.isSkip then
        -- 如果跳过，则下家就不能是打牌状态了
        nextUser.state = PDEFINE.PLAYER_STATE.Wait
    else
        deskInfo.round.activeSeat = nextUser.seatid
        local maybeCards = robot.getMaybeCards(nextUser)
        if #maybeCards == 0 then
            nextUser.state = PDEFINE.PLAYER_STATE.Draw
            CMD.userSetAutoState('autoDraw', retobj.delayTime, nextUser.uid)
        else
            nextUser.state = PDEFINE.PLAYER_STATE.Discard
            CMD.userSetAutoState('autoDiscard', retobj.delayTime, nextUser.uid)
        end
    end
    retobj.nextUid = nextUser.uid
    retobj.nextState = nextUser.state

    if #user.round.cards == 0 then
        isOver = 1
    end

    if #deskInfo.round.cards <= retobj.actionInfo.cardCnt then
        -- 如果牌值不够，则结束游戏
        if #deskInfo.round.discardCards + #deskInfo.round.cards <= retobj.actionInfo.cardCnt+1 then
            isOver = 1
        end
        retobj.reShuffle = true
        robot.reShuffle()
    end
    -- 如果是+4牌，则还有一个流程，用户可以选择是否质疑
    if robot.isDrawFourCard(card) and isOver == 0 then
        retobj.delayTime = deskInfo.delayTime
        deskInfo.round.activeSeat = nextUser.seatid
        CMD.userSetAutoState('autoChallenge', retobj.delayTime, nextUser.uid)
    elseif retobj.actionInfo.cardCnt > 0 then
        -- 如果下家被迫抓牌，则单独发送抓牌协议，然后通告下一个操作人
        skynet.timeout(10, function ()
            local finalNextUser = deskInfo:findNextUser(nextUser.seatid, deskInfo.round.isReverse)
            local maybeCards = robot.getMaybeCards(finalNextUser)
            deskInfo.round.activeSeat = finalNextUser.seatid
            finalNextUser.state = PDEFINE.PLAYER_STATE.Wait
            if isOver == 0 then
                if #maybeCards == 0 then
                    finalNextUser.state = PDEFINE.PLAYER_STATE.Draw
                    CMD.userSetAutoState('autoDraw', deskInfo.delayTime, finalNextUser.uid)
                else
                    finalNextUser.state = PDEFINE.PLAYER_STATE.Discard
                    CMD.userSetAutoState('autoDiscard', deskInfo.delayTime, finalNextUser.uid)
                end
            end
            -- 广播抓牌消息
            local draw_object = {}
            draw_object.c  = PDEFINE.NOTIFY.PLAYER_DRAW
            draw_object.code = PDEFINE.RET.SUCCESS
            draw_object.seat = nextUser.seatid
            draw_object.cards = {}
            draw_object.isSkip    = true  -- 表明是被动跳过的
            draw_object.uid    = nextUser.uid
            draw_object.delayTime = deskInfo.delayTime
            draw_object.nextUid = finalNextUser.uid
            draw_object.nextState = finalNextUser.state

            -- 其他人收到的卡牌列表为0值
            for i = 1, retobj.actionInfo.cardCnt do
                table.insert(draw_object.cards, 0)
            end
            deskInfo:broadcast(cjson.encode(draw_object), nextUser.uid)
            -- 自己收到的卡牌列表才有值
            draw_object.cards = {}
            for i = 1, retobj.actionInfo.cardCnt do
                local c = table.remove(deskInfo.round.cards)
                if c then
                    table.insert(draw_object.cards, c)
                    table.insert(nextUser.round.cards, c)
                end
            end
            if #nextUser.round.cards >= 2 then
                nextUser.round.uno = 0
            end
            if nextUser.cluster_info and nextUser.isexit == 0 then
                pcall(cluster.send, nextUser.cluster_info.server, nextUser.cluster_info.address, "sendToClient", cjson.encode(draw_object))
            end
        end)
    elseif retobj.actionInfo.isSkip and isOver == 0 then
        skynet.timeout(10, function ()
            -- 单纯的跳过
            local finalNextUser = deskInfo:findNextUser(nextUser.seatid, deskInfo.round.isReverse)
            local maybeCards = robot.getMaybeCards(finalNextUser)
            deskInfo.round.activeSeat = finalNextUser.seatid
            local delayTime = deskInfo.delayTime
            if #maybeCards == 0 then
                finalNextUser.state = PDEFINE.PLAYER_STATE.Draw
                CMD.userSetAutoState('autoDraw', delayTime, finalNextUser.uid)
            else
                finalNextUser.state = PDEFINE.PLAYER_STATE.Discard
                CMD.userSetAutoState('autoDiscard', delayTime, finalNextUser.uid)
            end
            -- 广播抓牌消息
            local pass_object = {}
            pass_object.c  = PDEFINE.NOTIFY.PLAYER_PASS
            pass_object.code = PDEFINE.RET.SUCCESS
            pass_object.seat = nextUser.seatid
            pass_object.uid    = nextUser.uid
            pass_object.isSkip    = true  -- 表明是被动跳过的
            pass_object.delayTime = delayTime
            pass_object.nextUid = finalNextUser.uid
            pass_object.nextState = finalNextUser.state
            deskInfo:broadcast(cjson.encode(pass_object))
        end)
    end

    retobj.isOver = isOver

    -- 广播给房间里的所有人
    local notify_object = {}
    notify_object.c  = PDEFINE.NOTIFY.PLAYER_DISCARD
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.seat = user.seatid
    notify_object.uid    = uid
    notify_object.card   = card
    notify_object.actionInfo  = retobj.actionInfo
    notify_object.reShuffle  = retobj.reShuffle
    notify_object.nextUid  = retobj.nextUid
    notify_object.nextState  = retobj.nextState
    notify_object.delayTime = retobj.delayTime
    notify_object.isOver = isOver
    deskInfo:broadcast(cjson.encode(notify_object), uid)

    -- 这个倒计时要小于上面的倒计时
    if isOver == 1 then
        skynet.timeout(50, function()
            agent:roundOver()
        end)
    end

    return warpResp(retobj)
end

-- 用户抓牌
function CMD.draw(_, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0
    retobj.reShuffle = false  -- 是否重新洗牌, 如果牌堆没有了，则会将弃牌堆重新洗牌

    local user = deskInfo:findUserByUid(uid)
    local ok
    ok, retobj = checkUserAndState(user, {PDEFINE.PLAYER_STATE.Discard, PDEFINE.PLAYER_STATE.Draw}, retobj)
    if not ok then
        return warpResp(retobj)
    end

    -- 清除计时器
    user:clearTimer()
    local isOver = 0
    clearUno(uid)
    -- 切换状态，防止重复抓牌
    user.state = PDEFINE.PLAYER_STATE.Wait
    if #deskInfo.round.cards <= 1 then
        if #deskInfo.round.discardCards < 2 then
            isOver = 1
        else
            retobj.reShuffle = true
            robot.reShuffle()
        end
    end

    retobj.isOver = isOver
    local card
    -- 如果下家是玩家，则需要根据概率判断是否给黑牌
    local nextUser = deskInfo:findNextUser(user.seatid, deskInfo.round.isReverse)
    if nextUser.cluster_info and deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH and deskInfo.ssid > 2 and math.random() < PDEFINE_GAME.GAME_CLEVER.UNO then
        local idx = nil
        for i, c in ipairs(deskInfo.round.cards) do
            if baseUtil.ScanSuit(c) == 5 then
                idx = i
                break
            end
        end
        if idx then
            card = table.remove(deskInfo.round.cards, idx)
        else
            card = table.remove(deskInfo.round.cards)
        end
    else
        card = table.remove(deskInfo.round.cards)
    end

    if card then
        retobj.cards = {card}
        table.insert(user.round.cards, card)
    end
    user.round.drawCard = nil  -- 这个值只有在可选择是否出牌的情况下有用

    retobj.delayTime = deskInfo.delayTime
    -- 抓到的牌如果可出，则需要选择是否出牌
    local canDiscard = false
    local maybeCards = robot.getMaybeCards(user)
    if table.contain(maybeCards, card) then
        user.round.drawCard = card
        user.state = PDEFINE.PLAYER_STATE.DiscardPass
        deskInfo.round.activeSeat = user.seatid
        retobj.nextUid = user.uid
        retobj.nextState = user.state
        CMD.userSetAutoState('autoDiscardPass', retobj.delayTime, user.uid)
        canDiscard = true
    end

    if not canDiscard then
        user.round.uno = 0
        local nextUser = deskInfo:findNextUser(user.seatid, deskInfo.round.isReverse)
        -- 判断下家是否有牌可出，如果有牌可出，则是打牌状态，如果没牌可出，则是抓牌状态
        local maybeCards = robot.getMaybeCards(nextUser)
        deskInfo.round.activeSeat = nextUser.seatid
        if #maybeCards == 0 then
            nextUser.state = PDEFINE.PLAYER_STATE.Draw
            CMD.userSetAutoState('autoDraw', retobj.delayTime, nextUser.uid)
        else
            nextUser.state = PDEFINE.PLAYER_STATE.Discard
            CMD.userSetAutoState('autoDiscard', retobj.delayTime, nextUser.uid)
        end
        retobj.nextUid = nextUser.uid
        retobj.nextState = nextUser.state
    end


    -- 广播给其他玩家
    local notify_object = {}
    notify_object.c  = PDEFINE.NOTIFY.PLAYER_DRAW
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.seat = user.seatid
    notify_object.uid    = uid
    notify_object.cards  = {0}
    notify_object.reShuffle = retobj.reShuffle
    notify_object.nextUid = retobj.nextUid
    notify_object.nextState = retobj.nextState
    notify_object.delayTime = retobj.delayTime
    notify_object.isOver = isOver

    deskInfo:broadcast(cjson.encode(notify_object), uid)

    if isOver == 1 then
        skynet.timeout(20, function()
            agent:roundOver()
        end)
    end

    return warpResp(retobj)
end

-- uno
function CMD.uno(_, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local user = deskInfo:findUserByUid(uid)
    local retobj = {c = recvobj.c, code= PDEFINE.RET.SUCCESS, uid=uid, spcode=0, success=0}
    local ok
    -- ok, retobj = checkUserAndState(user, {PDEFINE.PLAYER_STATE.Discard, PDEFINE.PLAYER_STATE.DiscardPass}, retobj)
    -- if not ok then
    --     return warpResp(retobj)
    -- end

    -- 判断是否可以叫uno
    if user.round.uno == 0 then
        if user.state == PDEFINE.PLAYER_STATE.Discard or user.state == PDEFINE.PLAYER_STATE.DiscardPass then
            if #user.round.cards ~= 2 then
                retobj.spcode = PDEFINE.RET.ERROR.CAN_NOT_UNO
                return warpResp(retobj)
            else
                local maybeCards = robot.getMaybeCards(user)
                if #maybeCards == 0 then
                    retobj.spcode = PDEFINE.RET.ERROR.CAN_NOT_UNO
                    return warpResp(retobj)
                end
            end
        else
            retobj.spcode = PDEFINE.RET.ERROR.CAN_NOT_UNO
            return warpResp(retobj)
        end
    elseif user.round.uno == 1 then
        retobj.spcode = PDEFINE.RET.ERROR.UNO_ALREADY
        return warpResp(retobj)
    end

    user.round.uno = 1
    retobj.success = 1
    -- 广播给其他玩家
    local notify_object = {}
    notify_object.c  = PDEFINE.NOTIFY.PLAYER_UNO
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.seat = user.seatid
    notify_object.uid    = uid
    notify_object.success    = 1
    deskInfo:broadcast(cjson.encode(notify_object))

    return warpResp(retobj)
end

-- 举报上一位玩家未进行uno
function CMD.unoChallenge(_, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local ouser
    for _, user in ipairs(deskInfo.users) do
        if user.round.uno == 2 and user.uid ~= uid then
            ouser = user
        end
    end
    local retobj = {c = recvobj.c, code= PDEFINE.RET.SUCCESS, uid=uid, spcode=0, success=0}
    if ouser then
        ouser.round.uno = 0
        retobj.success = 1
        -- 广播给其他玩家
        local notify_object = {}
        notify_object.c  = PDEFINE.NOTIFY.PLAYER_UNO_CHALLENGE
        notify_object.code = PDEFINE.RET.SUCCESS
        notify_object.ouid = ouser.uid
        notify_object.uid = uid
        notify_object.success = 1
        notify_object.cards = {0,0}

        local isOver = 0
        if #deskInfo.round.cards <= 2 then
            if #deskInfo.round.discardCards < 2 then
                isOver = 1
            end
            notify_object.reShuffle = true
            robot.reShuffle()
        end

        skynet.timeout(10, function ()
            deskInfo:broadcast(cjson.encode(notify_object), ouser.uid)
        end)

        notify_object.cards = {}
        for i = 1, 2 do
            local card = table.remove(deskInfo.round.cards)
            if card then
                table.insert(ouser.round.cards, card)
                table.insert(notify_object.cards, card)
            end
        end
        if ouser.cluster_info and ouser.isexit == 0 then
            skynet.timeout(10, function ()
                pcall(cluster.send, ouser.cluster_info.server, ouser.cluster_info.address, "sendToClient", cjson.encode(notify_object))
            end)
        end

        if isOver == 1 then
            skynet.timeout(20, function()
                agent:roundOver()
            end)
        end
    end

    return warpResp(retobj)
end

-- 玩家质疑
function CMD.challenge(_, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local rtype = math.floor(recvobj.rtype)  -- 0 放弃质疑，1提出质疑
    local retobj = {c = recvobj.c, code= PDEFINE.RET.SUCCESS, uid=uid, rtype=rtype, spcode=0, success=0}
    local user = deskInfo:findUserByUid(uid)

    if user.state ~= PDEFINE.PLAYER_STATE.WaitChallenge then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end
    user.state = PDEFINE.PLAYER_STATE.Wait
    -- 放弃质疑，则增加4个牌，并且跳过出牌
    if rtype == 0 then
        local nextUser = deskInfo:findNextUser(user.seatid, deskInfo.round.isReverse)
        -- 广播抓牌消息
        local notify_object = {}
        notify_object.c  = PDEFINE.NOTIFY.PLAYER_CHALLENGE
        notify_object.code = PDEFINE.RET.SUCCESS
        notify_object.seat = user.seatid
        notify_object.success = 0
        notify_object.result = {
            uid = uid,  -- 处理结果uid
            cardCnt = 4,  -- 需要摸取的牌
            cards = {0,0,0,0},  -- 当事人可见
            isSkip = true,  -- 是否跳过
        }
        notify_object.rtype = rtype
        notify_object.uid    = user.uid
        notify_object.delayTime = deskInfo.delayTime
        deskInfo.round.activeSeat = nextUser.seatid
        local maybeCards = robot.getMaybeCards(nextUser)
        if #maybeCards == 0 then
            nextUser.state = PDEFINE.PLAYER_STATE.Draw
            CMD.userSetAutoState('autoDraw', notify_object.delayTime, nextUser.uid)
        else
            nextUser.state = PDEFINE.PLAYER_STATE.Discard
            CMD.userSetAutoState('autoDiscard', notify_object.delayTime, nextUser.uid)
        end
        notify_object.nextUid = nextUser.uid
        notify_object.nextState = nextUser.state

        deskInfo:broadcast(cjson.encode(notify_object), uid)
        -- 自己收到的卡牌列表才有值
        notify_object.result.cards = {}
        for i = 1, notify_object.result.cardCnt do
            local c = table.remove(deskInfo.round.cards)
            if c then
                table.insert(notify_object.result.cards, c)
                table.insert(user.round.cards, c)
            end
        end
        user.round.uno = 0
        if  user.cluster_info and user.isexit == 0 then
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(notify_object))
        end
    else
        -- 提出质疑，则检测上家是否有同花色
        local prevUser = deskInfo:findPrevUser(user.seatid, deskInfo.round.isReverse)
        local prevCard = deskInfo.round.discardCards[#deskInfo.round.discardCards - 1]
        local suit = baseUtil.ScanSuit(prevCard)
        local challengeSuccess = false
        for _, c in ipairs(prevUser.round.cards) do
            if baseUtil.ScanSuit(c) == suit then
                challengeSuccess = true
                retobj.success = 1
                break
            end
        end
        local notify_object = {}
        notify_object.c = PDEFINE.NOTIFY.PLAYER_CHALLENGE
        notify_object.code = PDEFINE.RET.SUCCESS
        notify_object.uid = uid
        notify_object.rtype = rtype
        notify_object.success = 0
        notify_object.result = {
            uid = nil,  -- 处理结果uid
            cardCnt = nil,  -- 需要摸取的牌
            cards = nil,  -- 当事人可见
            isSkip = false,  -- 是否跳过
        }
        notify_object.nextUid = nil  -- 下一个操作人uid
        notify_object.nextState = nil  -- 下一个操作状态
        notify_object.delayTime = deskInfo.delayTime
        -- 质疑成功，则上家增加4张牌，轮到自己出牌
        -- 如果质疑失败，则自己增加6张牌，下家出牌
        if challengeSuccess then
            notify_object.success = 1
            user.state = PDEFINE.PLAYER_STATE.Discard
            notify_object.nextUid = user.uid
            notify_object.nextState =user.state
            notify_object.result = {
                uid = prevUser.uid,  -- 处理结果uid
                cardCnt = 4,  -- 需要摸取的牌
                isSkip = false,  -- 是否跳过
                cards = {0,0,0,0}
            }
            -- 其他人收到的卡牌列表为0值
            deskInfo:broadcast(cjson.encode(notify_object), prevUser.uid)
            -- 自己收到的卡牌列表才有值
            notify_object.result.cards = {}
            for i = 1, notify_object.result.cardCnt do
                local c = table.remove(deskInfo.round.cards)
                if c then
                    table.insert(notify_object.result.cards, c)
                    table.insert(prevUser.round.cards, c)
                end
            end
            prevUser.round.uno = 0
            if  prevUser.cluster_info and prevUser.isexit == 0 then
                pcall(cluster.send, prevUser.cluster_info.server, prevUser.cluster_info.address, "sendToClient", cjson.encode(notify_object))
            end
            deskInfo.round.activeSeat = user.seatid
            CMD.userSetAutoState('autoDiscard', notify_object.delayTime, user.uid)
        else
            notify_object.success = 0
            user.state = PDEFINE.PLAYER_STATE.Wait
            local nextUser = deskInfo:findNextUser(user.seatid, deskInfo.round.isReverse)
            deskInfo.round.activeSeat = nextUser.seatid
            local maybeCards = robot.getMaybeCards(nextUser)
            if #maybeCards == 0 then
                nextUser.state = PDEFINE.PLAYER_STATE.Draw
                CMD.userSetAutoState('autoDraw', notify_object.delayTime, nextUser.uid)
            else
                nextUser.state = PDEFINE.PLAYER_STATE.Discard
                CMD.userSetAutoState('autoDiscard', notify_object.delayTime, nextUser.uid)
            end
            notify_object.nextUid = nextUser.uid
            notify_object.nextState = nextUser.state
            notify_object.delayTime = deskInfo.delayTime
            notify_object.result = {
                uid = user.uid,  -- 处理结果uid
                cardCnt = 6,  -- 需要摸取的牌
                isSkip = true,  -- 是否跳过
                cards = {0,0,0,0,0,0}
            }
            -- 其他人收到的卡牌列表为0值
            deskInfo:broadcast(cjson.encode(notify_object), user.uid)
            -- 自己收到的卡牌列表才有值
            notify_object.result.cards = {}
            for i = 1, notify_object.result.cardCnt do
                local c = table.remove(deskInfo.round.cards)
                if c then
                    table.insert(notify_object.result.cards, c)
                    table.insert(user.round.cards, c)
                end
            end
            user.round.uno = 0
            if  user.cluster_info and user.isexit == 0 then
                pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(notify_object))
            end
        end
    end

    return warpResp(retobj)
end

-- 主动进入托管
function CMD.enterAuto(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local user = deskInfo:findUserByUid(uid)

    local retobj = {c = recvobj.c, code= PDEFINE.RET.SUCCESS, spcode=0}

    if user.auto == 1 then
        return warpResp(retobj)
    end

    user.auto = 1 -- 进入托管

    deskInfo:autoMsgNotify(user, 1)
    
    return warpResp(retobj)
end

-- 出牌过程中 取消托管
function CMD.cancelAuto(source, msg)
    local recvobj  = msg
    deskInfo:print('cancelAuto, msg:', recvobj)
    local uid = math.floor(recvobj.uid)
    local user = deskInfo:findUserByUid(uid)

    local retobj = {c = recvobj.cmd, code= PDEFINE.RET.SUCCESS, spcode=0}
    if user.auto == 0 then
        return warpResp(retobj)
    end
    
    user:clearTimer()
    user.auto = 0 --关闭自动

    -- 根据状态，重新开启计时器
    if user.state == PDEFINE.PLAYER_STATE.Discard then
        retobj.delayTime = deskInfo.delayTime
        CMD.userSetAutoState('autoDiscard', retobj.delayTime, uid)
    elseif user.state == PDEFINE.PLAYER_STATE.Draw then
        retobj.delayTime = deskInfo.delayTime
        CMD.userSetAutoState('autoDraw', retobj.delayTime, uid)
    elseif user.state == PDEFINE.PLAYER_STATE.DiscardPass then
        retobj.delayTime = deskInfo.delayTime
        CMD.userSetAutoState('autoDiscardPass', retobj.delayTime, uid)
    elseif user.state == PDEFINE.PLAYER_STATE.WaitChallenge then
        retobj.delayTime = deskInfo.delayTime
        CMD.userSetAutoState('autoChallenge', retobj.delayTime, uid)
    end

    deskInfo:autoMsgNotify(user, 0, retobj.delayTime)

    return warpResp(retobj)
end

-- 换桌子
function CMD.switchDesk(source, msg)
    local spcode = 0
    local uid = msg.uid
    if (deskInfo.state == PDEFINE.DESK_STATE.MATCH or deskInfo.state == PDEFINE.DESK_STATE.READY) then
        spcode = agent:switchDesk(msg)
    else
        local user = deskInfo:findViewUser(uid)
        -- 观战的可以换桌
        if user then
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

-- 更新玩家的桌子信息
function CMD.updateUserClusterInfo(source, uid, _agent)
    deskInfo:updateUserAgent(uid, _agent)
end

-- 用户离线获取牌桌信息
function CMD.getDeskInfo(source, msg)
    local deskInfoStr = deskInfo:toResponse(msg.uid)
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
    -- 获取桌子回复
    local deskInfoStr = deskInfo:toResponse(deskInfo.owner)
    -- LOG_DEBUG("deskInfoStr", deskInfoStr)

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
            startGame(nil)
        end
        return warpResp(retobj)
    end)
end

-- 准备，如果是私人房，则有这个阶段
function CMD.ready(source, msg)
    local recvobj = msg
    deskInfo:userReady(msg.uid)
    
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