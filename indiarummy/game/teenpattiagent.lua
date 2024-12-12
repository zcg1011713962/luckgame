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
local BetStgy = require "betgame.betstgy"
local cs = queue()
local GAME_NAME = skynet.getenv("gamename") or "game"
local DEBUG = skynet.getenv("DEBUG")
local CMD = {}
local closeServer = false

math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 7)))

local GOOD_CARD_REPEAT_OBTAIN_PROBABILITY = 0.3   --设定为0.3可以将好牌率（对子及以上）从0.25提升到0.31

--[[
    规则: 
    1. 封顶: Pot Limit 牌桌池里面最多能容纳的金额，超过之后，就自动比牌结算
    2. 盲下: Blind 没有看牌
    3. 看牌: Seen 已经看牌
    4. 下注封顶: Chaal Limit 最高下注额
    5. 底注: Boot Amount 发牌前需要付出的起始资金
    6. 请求看牌: Sideshow 和前一个看牌的人比牌，同意就比牌，不同意就只能继续加注或者弃牌
    7. 看牌: Show 当只剩下两个人时，可以要求看牌，无法拒绝，赢者获得奖金池
]]

---@type BetStgy
local stgy = BetStgy.new()

--控制参数
--参数值一般规则：为1时保持平衡；大于1时玩家buff；小于1时玩家debuff
local ControlParams = { --控制参数，
    deal_card_exchange_prob = 1,    --发牌换牌的反向概率
    robot_lose_total_mult = 60,    --机器人输最大总倍数
    robot_lose_total_coin = 2500,   --机器人输最大金币数
}

---@type BaseDeskInfo @instance of tarneeb
local deskInfo = nil  -- 桌子信息
---@type BaseAgent
local agent = nil  -- 游戏实例
local biddingAddTime =2
local discardTime = 2 -- 发牌动画时间
local sideShowTime = 4  -- 比牌时间
local lastDealerSeatid = nil  -- 最后做庄家的位置
local beforeRoundTime = 1 -- 小结算之前的延迟时间
local config = {
    -- 0x4* 为黑桃, 0x3*为红桃，, 0x2*为梅花, 0x1*为方块
    Cards = {
        0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,
        0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,
        0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,
        0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,
    },
    -- 发牌数量
    InitCardLen = 3,
    -- 最大牌值 A 0x0E
    MaxValue = 14,
    -- 托管和自动操作之间的延迟时间(teenpatti 不需要)
    AutoDelayTime = 1,
    -- 牌型
    CardType = {
        None = 1,  -- 散牌
        Pair = 2, -- 对子
        Color = 3, -- 同花
        Sequence = 4, -- 顺子
        StraightFlush = 5,  -- 同花顺
        Trail = 6,  -- 三条
    },
    SettleType = {
        Show = 1,  -- 发起比牌结算
        Live = 2,  -- 剩下一人结算
        Limit = 3,  -- 触发封顶结算
    },
    SeeCardWeight = {  -- 看牌的概率
        [1] = 0.3,
        [2] = 0.4,
        [3] = 0.5,
    }
}

local logic = {}

local robot = {}

-- 判断是否是3张
robot.isTrail = function(cards)
    return baseUtil.ScanValue(cards[1]) == baseUtil.ScanValue(cards[2]) and baseUtil.ScanValue(cards[2]) == baseUtil.ScanValue(cards[3])
end

-- 判断是否是同花
robot.isColor = function(cards)
    return baseUtil.ScanSuit(cards[1]) == baseUtil.ScanSuit(cards[2]) and baseUtil.ScanSuit(cards[2]) == baseUtil.ScanSuit(cards[3])
end

-- 判断是否是顺子
robot.isSequence = function(cards)
    local pureCards = {}
    for _, card in ipairs(cards) do
        table.insert(pureCards, baseUtil.ScanValue(card))
    end
    table.sort(pureCards)
    if pureCards[1] + 2 == pureCards[2] + 1 and pureCards[2] + 1 == pureCards[3] then
        return true
    end
    if pureCards[1] == 2 and pureCards[2] == 3 and pureCards[3] == config.MaxValue then
        return true
    end
    return false
end

-- 判断是否是对子
robot.isPair = function(cards)
    local cnt = 0
    if baseUtil.ScanValue(cards[1]) == baseUtil.ScanValue(cards[2]) then
        cnt = cnt + 1
    end
    if baseUtil.ScanValue(cards[1]) == baseUtil.ScanValue(cards[3]) then
        cnt = cnt + 1
    end
    if baseUtil.ScanValue(cards[2]) == baseUtil.ScanValue(cards[3]) then
        cnt = cnt + 1
    end
    return cnt == 1
end

-- 获取对子相同的牌
robot.getPairCard = function(cards)
    if baseUtil.ScanValue(cards[1]) == baseUtil.ScanValue(cards[2]) then
        return cards[1]
    end
    if baseUtil.ScanValue(cards[1]) == baseUtil.ScanValue(cards[3]) then
        return cards[1]
    end
    if baseUtil.ScanValue(cards[2]) == baseUtil.ScanValue(cards[3]) then
        return cards[2]
    end
    return nil
end

-- 判断是否是同花顺
robot.isStraightFlush = function(cards)
    return robot.isSequence(cards) and robot.isColor(cards)
end

-- 判断牌型
-- 从最高牌型判断，逐步判断
robot.findCardType = function(cards)
    if robot.isTrail(cards) then
        return config.CardType.Trail
    elseif robot.isStraightFlush(cards) then
        return config.CardType.StraightFlush
    elseif robot.isSequence(cards) then
        return config.CardType.Sequence
    elseif robot.isColor(cards) then
        return config.CardType.Color
    elseif robot.isPair(cards) then
        return config.CardType.Pair
    end
    return config.CardType.None
end

-- 判断大小
-- 先判断类型，类型一样判断最大值，都一样，就是平局
-- 大于 : 1, 小于: -1 , 等于 : 0
robot.compare = function(lcards, rcards)
    local ltype = robot.findCardType(lcards)
    local rtype = robot.findCardType(rcards)
    if ltype > rtype then
        return 1
    end
    if ltype < rtype then
        return -1    
    end
    -- 从大到小，比较大小
    local lPureCards = {}
    for _, card in ipairs(lcards) do
        table.insert(lPureCards, baseUtil.ScanValue(card))
    end
    local rPureCards = {}
    for _, card in ipairs(rcards) do
        table.insert(rPureCards, baseUtil.ScanValue(card))
    end
    table.sort(lPureCards)
    table.sort(rPureCards)
    -- 对子有点特殊，需要先比较对子的大小
    if ltype == config.CardType.Pair then
        local lPairCard = robot.getPairCard(lPureCards)
        local rPairCard = robot.getPairCard(rPureCards)
        if lPairCard > rPairCard then
            return 1
        end
        if lPairCard < rPairCard then
            return -1
        end
    end
    for i = 3, 1, -1 do
        if lPureCards[i] > rPureCards[i] then
            return 1
        end
        if lPureCards[i] < rPureCards[i] then
            return -1
        end
    end
    -- 同花的情况下，颜色大的组合胜利
    if robot.isColor(lcards) then
        if baseUtil.ScanSuit(lcards[1]) > baseUtil.ScanSuit(rcards[1]) then
            return 1
        end
        if baseUtil.ScanSuit(lcards[1]) < baseUtil.ScanSuit(rcards[1]) then
            return -1
        end
    end
    return 0
end

--计算手牌牌力，取值范围[0,1]，取值越大，牌力越大
robot.calcCardsForce = function(cards)
    if robot.isTrail(cards) then
        return 1
    elseif robot.isStraightFlush(cards) then
        return 0.99
    elseif robot.isSequence(cards) then
        return 0.96
    elseif robot.isColor(cards) then
        return 0.91
    elseif robot.isPair(cards) then
        local pairCard = robot.getPairCard(cards)
        local value = baseUtil.ScanValue(pairCard)
        if value > 9 then
            return 0.851
        elseif value > 6 then
            return 0.81
        end
        return 0.75
    else
        local pureCards = {}
        for _, card in ipairs(cards) do
            table.insert(pureCards, baseUtil.ScanValue(card))
        end
        table.sort(pureCards)
        local maxValue = pureCards[3]
        if pureCards[3] == 0x0e then
            return 0.57
        elseif maxValue == 0x0d then
            if pureCards[2] >= 0xb then
                return 0.52
            end
            return 0.42
        elseif maxValue == 0x0c then
            return 0.3
        elseif maxValue == 0x0b then
            return 0.21
        elseif maxValue == 0x0a then
            return 0.14
        else
            return 0.013 * maxValue
        end
    end
    return 0
end

-- 判断机器人是否是最大牌
-- 如果自己能赢，则一直跟注，如果有人要看自己牌，就给看
-- 如果自己不能赢，则每次都有50%的概率跟下去
robot.checkWin = function(user)
    local cards = user.round.cards
    for _, u in ipairs(deskInfo.users) do
        if u.uid ~= user.uid and u.round.packed == 0 then
            if robot.compare(cards, u.round.cards) == -1 then
                return false
            end
        end
    end
    return true
end

-- 成功返回
local function warpResp(retobj)
    return PDEFINE.RET.SUCCESS, retobj
end

--获取控制系数
local function getControlParam(key)
    local param = ControlParams[key]
    if not param then return 1 end
    local rtp = 100
    if stgy:isValid() then
        rtp = stgy.rtp
    end
    local p = param * (rtp / 100)
    return p
end 

-- 找出当前还未弃牌的用户
logic.findLiveUser = function()
    local users = {}
    for _, u in ipairs(deskInfo.users) do
        if u.round.packed == 0 then
            table.insert(users, u)
        end
    end
    return users
end

-- 找出下一个活着的人
logic.findNextLiveUser = function(seatid)
    local cnt = deskInfo.seat
    while cnt > 0 do
        cnt = cnt - 1
        local nextUser = deskInfo:findNextUser(seatid)
        if nextUser.round.packed == 0 then
            return nextUser
        end
        seatid = nextUser.seatid
    end
    return nil
end

-- 找出上一个活着的人
logic.findPrevLiveUser = function(seatid)
    local cnt = deskInfo.seat
    while cnt > 0 do
        cnt = cnt - 1
        local prevUser = deskInfo:findPrevUser(seatid)
        if prevUser.round.packed == 0 then
            return prevUser
        end
        seatid = prevUser.seatid
    end
    return nil
end

-- 获取当前可下注列表
logic.getBetList = function(user)
    if deskInfo.round.activeSeat ~= user.seatid then
        return nil
    end
    local betList = {}
    if user.round.seen == 1 then
        if deskInfo.round.baseCoin*4 > deskInfo.conf.betLimit then
            betList = {
                deskInfo.round.baseCoin*2,
            }
        else
            betList = {
                deskInfo.round.baseCoin*2,
                deskInfo.round.baseCoin*4,
            }
        end
    else
        if deskInfo.round.baseCoin*2 > deskInfo.conf.betLimit then
            betList = {
                deskInfo.round.baseCoin,
            }
        else
            betList = {
                deskInfo.round.baseCoin,
                deskInfo.round.baseCoin*2,
            }
        end
    end
    return betList
end

-- 广播下一个操作人
logic.broadcastNextUser = function(user)
    local betList = logic.getBetList(user)
    local extra = {betList=betList, state=user.state}
    logic.injectBtnStatus(extra, user)
    deskInfo:broadcastNextUser(user, deskInfo.delayTime, extra)
end

-- 告知前端show和side_show按钮的状态
logic.injectBtnStatus = function(notify_object, user)
    if not user then
        return 
    end
    -- 这里需要加入判断，自己是否显示side_show和show按钮
    -- 前端依靠后端判断按钮状态
    notify_object.can_show = 0
    notify_object.can_side_show = 0
    local liveUsers = logic.findLiveUser()
    local prevUser = logic.findPrevLiveUser(user.seatid)
    if #liveUsers == 2 and prevUser.round.seen == 1 then
        notify_object.can_show = 1
    end
    if user.round.seen == 1 and prevUser.round.seen == 1 and #liveUsers > 2 then
        notify_object.can_side_show = 1
    end
end

-- 看牌广播
logic.broadcastSeeCard = function(user)
    -- 广播给房间里的所有人
    local notify_object = {}
    notify_object.c  = PDEFINE.NOTIFY.PLAYER_SEE_CARDS
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.uid    = user.uid
    user.round.seen = 1
    deskInfo:broadcastViewer(cjson.encode(notify_object))
    for _, u in ipairs(deskInfo.users) do
        if  u.cluster_info and u.isexit == 0 then
            if u.uid == user.uid then
                notify_object.cards = user.round.cards
                notify_object.cardType = robot.findCardType(user.round.cards)
                notify_object.betList = logic.getBetList(u)
            end
            -- 这里需要加入判断，自己是否显示side_show和show按钮
            logic.injectBtnStatus(notify_object, u)
            pcall(cluster.send, u.cluster_info.server, u.cluster_info.address, "sendToClient", cjson.encode(notify_object))
        end
    end
end

local function initDeskInfoRound(uid, seatid)
    deskInfo.round = {}
    deskInfo.round.cards = {} -- 堆上的牌
    deskInfo.round.activeSeat = 0 -- 当前活动座位
    deskInfo.round.settle = {} -- 小结算
    deskInfo.round.multiple = 1 --房间倍数
    deskInfo.round.dealer = { ----此把的庄家(庄家的下家选牌型和出牌)
        uid = uid,
        seatid = seatid
    }
    deskInfo.round.baseCoin = deskInfo.bet  -- 基础下注额
    deskInfo.round.potCoin = 0  -- 桌面池子
    deskInfo.round.showUid = nil  -- 查看牌的人
    deskInfo.round.sideShowUid = nil  -- 申请比牌的人

    -- 随机堆上的牌
    deskInfo.round.cards = table.copy(config.Cards)
    shuffle(deskInfo.round.cards)
end

---@param user BaseUser
local function initUserRound(user)
    user.state       = PDEFINE.PLAYER_STATE.Wait
    user.round = {}
    user.round.seen       = 0  -- 是否看牌
    user.round.packed     = 0  -- 是否弃牌
    user.round.betCoin    = 0  -- 轮分
    user.round.cards      = {} -- 手中的牌
    user.round.isWin      = 0  -- 是否赢了
    user.round.betCnt     = 1  -- 下注次数
end

-- 选择看牌
local function chooseSeeCards(uid)
    local msg = {
        c = 25736,
        uid = uid,
    }
    local _, resp = CMD.seeCards(nil, msg)
    deskInfo:print("自动seeCards msg:", msg, "返回: ", resp)
    assert(resp.spcode==0, "chooseSeeCards")
end

-- 选择弃牌
local function choosePack(uid)
    local msg = {}
    msg.c = 25740
    msg.uid = uid
    local _, resp = CMD.pack(nil, msg)
    deskInfo:print("自动pack msg:", msg, "返回: ", resp)
    assert(resp.spcode==0, "choosePack")
end

-- 选择show牌
local function chooseShow(uid)
    local msg = {
        c = 25739,
        uid = uid,
    }
    local _, resp = CMD.show(nil, msg)
    deskInfo:print("自动show msg:", msg, "返回: ", resp)
    assert(resp.spcode==0, "chooseShow")
end

-- 选择sideshow
local function chooseSideShow(uid)
    local msg = {}
    msg.c = 25737
    msg.uid = uid
    local _, resp = CMD.sideShow(nil, msg)
    deskInfo:print("自动sideShow msg:", msg, "返回: ", resp)
    assert(resp.spcode==0, "chooseSideShow")
end

-- 选择下注
local function chooseBet(uid, coin)
    local msg = {
        c = 25735,
        uid = uid,
        coin = coin
    }
    local _, resp = CMD.bet(nil, msg)
    deskInfo:print("自动bet msg:", msg, "返回: ", resp)
    assert(resp.spcode==0, "chooseBet")
end

-- 选择sideshowres
local function chooseSideShowRes(uid, rtype)
    local msg = {}
    msg.c = 25738
    msg.uid = uid
    msg.rtype = rtype or 1
    local _, resp = CMD.sideShowRes(nil, msg)
    deskInfo:print("自动sideShowRes msg:", msg, "返回: ", resp)
    assert(resp.spcode==0, "chooseSideShowRes")
end

-- 自动相应sideShow
local function autoSideShow(uid)
    return cs(function()
        deskInfo:print("用户自动响应看牌 uid:".. uid)
        
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
            -- 如果是进入托管，则延后一点操作
            skynet.timeout(delayTime, function()
                chooseSideShowRes(uid, 0)
            end)
        else
            local SideShowResRate = 0.3
            if math.random() < SideShowResRate then
                chooseSideShowRes(uid, 1)
            else
                chooseSideShowRes(uid, 0)
            end
        end
    end)
end

-- 真人自动弃牌
local function autoPack(uid)
    return cs(function()
        deskInfo:print("用户自动弃牌 uid:".. uid)
        
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
        -- 如果是进入托管，则延后一点操作
        skynet.timeout(delayTime, function()
            local msg = {
                ['c'] = 25740,
                ['uid'] = uid,
            }
            local _, resp = CMD.pack(nil, msg)
            deskInfo:print("自动弃牌 msg:", msg, "返回: ", resp)
        end)
    end)
end

-- 机器人自动操作
--- @param rtype 操作类型 
local function autoAiDecide(uid, rtype)
    return cs(function()
        deskInfo:print("自动操作 uid:".. uid)
        
        local user = deskInfo:findUserByUid(uid)
        user:clearTimer()
        if deskInfo.round.activeSeat ~= user.seatid then
            deskInfo:print("出牌对象错误: uid:", uid, ' seatid:', user.seatid, " activeSeat:", deskInfo.round.activeSeat)
            return
        end

        local canWin = robot.checkWin(user)
        local betCnt = user.round.betCnt
        local betList = logic.getBetList(user)
        local restUsers = logic.findLiveUser()
        -- 如果能赢的情况下，也需要根据概率开对方的牌，防止太假一直跟
        local cardType = robot.findCardType(user.round.cards)
        local f = robot.calcCardsForce(user.round.cards)
        local seeCard = false

        -- 增加一个看牌的概率
        if user.round.seen == 0 and config.SeeCardWeight[betCnt] and math.random() < config.SeeCardWeight[betCnt] then
            chooseSeeCards(uid)
            betList = logic.getBetList(user)
            seeCard = true
        end

        if user.state == PDEFINE.PLAYER_STATE.Bet and user.coin >= betList[1] then
            --未看牌不计算牌力
            if user.round.seen == 0 and betCnt < 3 and math.random() < 0.95 then
                chooseBet(uid, betList[1])
                return
            end

            if #restUsers == 2 and canWin and betCnt > 4 then
                -- 根据自己的牌型来，散牌大概率会show, 对子低一点，高于同花和顺子 再低一点，其他的一直跟
                local isShow = false
                if cardType == config.CardType.None and math.random() < 0.8 then
                    isShow = true
                elseif cardType == config.CardType.Pair and betCnt > 6 and math.random() < 0.4 then
                    isShow = true
                elseif cardType == config.CardType.Color and betCnt > 7 and math.random() < 0.4 then
                    isShow = true
                elseif cardType == config.CardType.Sequence and betCnt > 8 and math.random() < 0.4 then
                    isShow = true
                end
                if isShow then
                    skynet.timeout(math.random(150, 300), function()
                        chooseShow(uid)
                    end)
                    return
                end
            end
            -- 钱不够的情况下，赶紧看牌或者sideshow
            if user.coin <= 6*betList[1] then
                if #restUsers == 2 then
                    for _, u in ipairs(restUsers) do
                        if u.uid ~= uid then
                            if u.round.seen == 1 then
                                skynet.timeout(math.random(150, 300), function()
                                    chooseShow(uid)
                                end)
                                return
                            end
                        end
                    end
                elseif #restUsers > 2 then
                    local prevUser = logic.findPrevLiveUser(user.seatid)
                    if prevUser.round.seen == 1 then
                        if user.round.seen == 0 then
                            chooseSeeCards(uid)
                            betList = logic.getBetList(user)
                        end 
                        if user.coin >= betList[1] then
                            skynet.timeout(math.random(150, 300), function()
                                chooseSideShow(uid)
                            end)
                            return
                        end
                    end
                end
            end

            local totalBet = 0
            local totalmult = getControlParam("robot_lose_total_mult")
            local maxtotalmult = math.random(math.floor(totalmult*0.9), math.floor(totalmult*1.1))
            maxtotalmult = math.max(40, maxtotalmult)
            local totalcoin = getControlParam("robot_lose_total_coin")
            local maxtotalcoin = math.random(math.floor(totalcoin*0.9), math.floor(totalcoin*1.1))
            for _, u in ipairs(deskInfo.users) do
                if not u.cluster_info then
                    totalBet = totalBet + user.round.betCoin
                end
            end
            totalBet = totalBet + betList[1]
            if (totalBet > deskInfo.bet * maxtotalmult or totalBet > maxtotalcoin) and (not canWin) then --如果机器人总押注大于60倍，且不能赢
                if user.round.seen == 0 then
                    chooseSeeCards(uid)
                    skynet.timeout(math.random(150, 300), function()
                        choosePack(uid)
                    end)
                else
                    choosePack(uid)
                end
                return
            end

            if user.coin >= betList[1] and (canWin or (betCnt<5 and f>=0.3 and math.random() < f*(1-betCnt*0.1))) then  --押注概率
                local SideShowRate = 0.25
                --牌力在0.4~0.6之间（不大不小），可以考虑sideshow，拼掉一个人
                if user.round.seen == 1 and #restUsers == 3 and (f>=0.4 and f<=0.6) and betCnt > 3 then
                    if math.random() < SideShowRate then
                        local prevUser = logic.findPrevLiveUser(user.seatid)
                        --if prevUser.round.seen == 1 then
                        if prevUser.cluster_info and prevUser.round.seen == 1 then
                            local delayTime = 0
                            if seeCard then delayTime = math.random(150, 300) end
                            skynet.timeout(delayTime, function()
                                chooseSideShow(uid)
                            end)
                            return
                        end
                    end
                end

                local doubleRate = -1
                if betList[2] and user.coin >= betList[2]*2 and canWin then
                    if f > 0.75 then
                        doubleRate = 0.2
                    elseif f > 0.8 then
                        doubleRate = 0.3
                    elseif f > 0.9 then
                        doubleRate = 0.4
                    elseif f > 0.95 then
                        doubleRate = 0.5
                    elseif f >= 1 then
                        doubleRate = 0.75
                    end
                end
                if math.random() < doubleRate then
                    chooseBet(uid, betList[2])
                else
                    chooseBet(uid, betList[1])
                end
            else
                -- 判断自己牌型，如果是散牌且没有K A，则不用挣扎了，直接弃牌吧
                local shouldPack = f < 0.5
                -- 如果只剩下两个人了，则机器人主动show, 前提得有钱
                if #restUsers == 2 and user.coin >= betList[1] and not shouldPack then
                    for _, u in ipairs(restUsers) do
                        if u.uid ~= uid then
                            if u.round.seen == 1 then
                                skynet.timeout(math.random(150, 300), function()
                                    chooseShow(uid)
                                end)
                                return
                            end
                        end
                    end
                end
                if user.round.seen == 0 then
                    chooseSeeCards(uid)
                    betList = logic.getBetList(user)
                end
                skynet.timeout(math.random(150, 300), function()
                    choosePack(uid)
                end)
                return
            end
        elseif user.state == PDEFINE.PLAYER_STATE.SideShowRes then
            local ratio = 0.3
            if math.random() < ratio then
                chooseSideShowRes(uid, 1)
            else
                chooseSideShowRes(uid, 0)
            end
        else
            if user.round.seen == 0 then
                chooseSeeCards(uid)
                betList = logic.getBetList(user)
            end
            choosePack(uid)
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

--自动离开
local function autoLeave(uid)
    if deskInfo.conf.roomtype ~= PDEFINE.BAL_ROOM_TYPE.MATCH then return end
    return cs(function()
        deskInfo:onRobotDropLeave(uid)
        LOG_DEBUG("弃牌后离桌", uid)
    end)
end

local function setAutoReady(delayTime, uid)
    CMD.userSetAutoState('autoReady', delayTime, uid)
end

-- 开始发牌
local function roundStart()
    local retobj = {}
    LOG_DEBUG("开始游戏: deskid:", deskInfo.uuid)
    -- 设置庄家的下一家为叫牌用户
    local dealer = deskInfo:findUserByUid(deskInfo.round.dealer['uid'])
    local startUser = deskInfo:findNextUser(dealer.seatid)
    deskInfo.round.activeSeat = dealer.seatid
    deskInfo.curround = deskInfo.curround + 1
    -- 设置定时器
    retobj.c = PDEFINE.NOTIFY.GAME_DEAL
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.activeUid = startUser.uid
    retobj.dealerUid = dealer.uid

    -- 开始发牌
    retobj.cards = nil
    retobj.discardUids = {}  -- 发牌的人
    retobj.delayTime = deskInfo.delayTime
    retobj.potCoin = deskInfo.round.potCoin
    for _, user in pairs(deskInfo.users) do
        table.insert(retobj.discardUids, user.uid)
    end
    for _, user in pairs(deskInfo.users) do
        local cards = {}
        -- 庄家切换到叫牌阶段
        if user.seatid == startUser.seatid then
            -- 切换状态
            user.state = PDEFINE.PLAYER_STATE.Bet
            deskInfo.round.activeSeat = user.seatid
            -- 设置定时器
            -- 刚开局，时间设置久一点
            if user.cluster_info then
                CMD.userSetAutoState('autoPack', retobj.delayTime+discardTime, user.uid, discardTime)
            else
                CMD.userSetAutoState('autoAiDecide', retobj.delayTime+discardTime, user.uid, discardTime)
            end

            -- 广播下一个操作人, 延迟3秒，用于前端发牌动画
            skynet.timeout(discardTime*100, function()
                logic.broadcastNextUser(user)
            end)
        else
            user.state = PDEFINE.PLAYER_STATE.Wait
        end

        for i = 1, config.InitCardLen do
            table.insert(cards, table.remove(deskInfo.round.cards))
        end

        --发好牌
        local ctype = robot.findCardType(cards) --计算牌力
        if ctype == config.CardType.None then
            local ratio = GOOD_CARD_REPEAT_OBTAIN_PROBABILITY
            if not user.cluster_info then
                ratio = ratio * 1.2
            end
            if math.random() < ratio then
                --换一副牌
                for _, card in ipairs(cards) do
                    table.insert(deskInfo.round.cards, 1, card)
                end
                cards = {}
                for i = 1, config.InitCardLen do
                    table.insert(cards, table.remove(deskInfo.round.cards))
                end
            end
        end
        user.round.cards = table.copy(cards)
        user.round.initcards = table.copy(cards)
    end
    --杀率控制
    local exchangeprob = getControlParam("deal_card_exchange_prob")
    if math.random() > exchangeprob and math.random() > exchangeprob*0.5 then
        local maxuser = deskInfo.users[1]
        for i = 2, #deskInfo.users do
            local user = deskInfo.users[i]
            if robot.compare(maxuser.round.cards, user.round.cards) == -1 then
                maxuser = user
            end
        end
        if maxuser.cluster_info then
            local users = {}
            for _, user in ipairs(deskInfo.users) do
                if not user.cluster_info then
                    table.insert(users, user)
                end
            end
            if #users > 0 then
                local user = users[math.random(1, #users)]
                LOG_DEBUG("before exchange cards", maxuser.uid, table.concat(maxuser.round.cards, ","), robot.calcCardsForce(maxuser.round.cards), user.uid, table.concat(user.round.cards, ","), robot.calcCardsForce(user.round.cards))
                local cards = table.copy(maxuser.round.cards)
                maxuser.round.cards = table.copy(user.round.cards)
                user.round.cards = cards
                LOG_DEBUG("after exchange cards", maxuser.uid, table.concat(maxuser.round.cards, ","), robot.calcCardsForce(maxuser.round.cards), user.uid, table.concat(user.round.cards, ","), robot.calcCardsForce(user.round.cards))
            end
        end
    end
    --广播消息
    for _, user in pairs(deskInfo.users) do
        retobj.cards = user.round.cards
        if user.cluster_info and user.isexit == 0 then
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(retobj))
        end
    end
    retobj.cards = {}
    deskInfo:broadcastViewer(cjson.encode(retobj))
end

-- 创建房间后第1次开始游戏
---@param delayTime integer 用于指定发牌前的延迟时间
local function startGame(delayTime)
    if deskInfo.state ~= PDEFINE.DESK_STATE.MATCH and deskInfo.state ~= PDEFINE.DESK_STATE.READY then
        return
    end
    -- 调用基类的开始游戏
    deskInfo:startGame()
    -- 庄家轮着来
    local dealer = lastDealerSeatid and deskInfo:findNextUser(lastDealerSeatid)
    if not dealer then
        dealer = deskInfo.users[math.random(#deskInfo.users)]
    end
    LOG_DEBUG("dealer ", dealer.uid, dealer.seatid)
    -- 初始化桌子信息
    deskInfo:initDeskRound(dealer.uid, dealer.seatid)
    -- 将玩家的初始金币放入桌面池中
    for _, u in ipairs(deskInfo.users) do
        u:changeCoin(PDEFINE.ALTERCOINTAG.BET, -1*deskInfo.bet, deskInfo)
        deskInfo.round.potCoin = deskInfo.round.potCoin + deskInfo.bet
        u.round.betCoin = u.round.betCoin + deskInfo.bet
    end
    -- LOG_DEBUG("deskInfo ", deskInfo)
    -- 发牌前，延迟几秒显示倒计时
    delayTime = delayTime or 0
    -- deskInfo:notifyStart(delayTime)
    skynet.timeout(delayTime*100, function()
        -- 调用基类的新的一轮
        deskInfo:roundStart()
        roundStart()
    end)

end

-- 游戏结束，大结算
local function gameOver(isDismiss, winners, settle, reduceTime)

    deskInfo:gameOver(settle, isDismiss, true, winners, nil, reduceTime)
end

-- 此轮游戏结束
--- @param rtype integer 结算类型 1.发起比牌结算, 2.封顶自动结算, 3.剩下一个人结算
local function roundOver(rtype)
    -- 防止多次调用roundover
    if deskInfo.state ~= PDEFINE.DESK_STATE.PLAY then
        return
    end
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
    retobj.rtype = rtype  -- 结算方式
    retobj.allCards = {}  -- 展示所有的牌

    ---@type Settle
    local settle = {
        uids = {},  -- uid
        league = {},  -- 排位经验
        coins = {}, -- 结算的金币
        taxes = {}, -- 税收
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
        table.insert(settle.taxes, 0)
        table.insert(settle.scores, 0)
        table.insert(settle.levelexps, 0)
        table.insert(settle.rps, 0)
        table.insert(settle.fcoins, 0)
    end

    local allCards = {}
    for _, user in ipairs(deskInfo.users) do
        table.insert(allCards, {
            uid = user.uid,
            cards = user.round.initcards,
            ctype=robot.findCardType(user.round.cards),
            packed = user.round.packed,
            seen = user.round.seen,
        })
        if user.round.packed == 0 then
            table.insert(retobj.allCards, {
                uid=user.uid,
                cards=user.round.cards,
                cardType=robot.findCardType(user.round.cards),
                coin=0
            })
        end
    end

    -- 找出最终玩家
    local winner = nil
    local winners = {}
    if rtype == config.SettleType.Limit or rtype == config.SettleType.Show then
        -- 触发封顶结算，如果有相同的，则平分奖金
        -- 有人看牌结束，如果有相同的，则看牌人输
        for _, u in ipairs(deskInfo.users) do
            if u.round.packed == 0 then
                if not winner then
                    winner = u
                    winners = {winner.uid}
                else
                    local result = robot.compare(winner.round.cards, u.round.cards)
                    if result == 0 then
                        -- 平局
                        if rtype == config.SettleType.Show then
                            if u.uid ~= deskInfo.round.showUid then
                                winner = u
                                winners = {u.uid}
                            end
                        else
                            table.insert(winners, winner.uid)
                        end
                    elseif result == -1 then
                        winners = {u.uid}
                        winner = u
                    end
                end
            end
        end
    elseif rtype == config.SettleType.Live then
        -- 剩下一人结算，奖池都是他的
        for _, u in ipairs(deskInfo.users) do
            if u.round.packed == 0 then
                winner = u
                winners = {u.uid}
                break
            end
        end
    end

    retobj.winners = winners
    local winCoin = math.round_coin(deskInfo.round.potCoin / #winners)

    for _, uid in ipairs(winners) do
        local u = deskInfo:findUserByUid(uid)
        local tax = 0
        if winCoin > u.round.betCoin then
            tax = math.round_coin((winCoin - u.round.betCoin) * deskInfo.taxrate)
        end
        local finalCoin = winCoin - tax
        u:notifyLobby(finalCoin, u.uid, deskInfo.gameid)
        u:changeCoin(PDEFINE.ALTERCOINTAG.WIN, finalCoin, deskInfo)
        settle.coins[u.seatid] = finalCoin
        settle.taxes[u.seatid] = tax
        for _, item in ipairs(retobj.allCards) do
            if item.uid == uid then
                item.coin = winCoin
                break
            end
        end
    end

    for _, u in ipairs(deskInfo.users) do
        settle.fcoins[u.seatid] = u.coin
    end

    retobj.settle = settle

    if stgy:isValid() then
        local playertotalbet = 0
        local playertotalwin = 0
        for _, user in ipairs(deskInfo.users) do
            if user.cluster_info and user.istest ~= 1 then
                playertotalbet = playertotalbet + user.round.betCoin
                playertotalwin = playertotalwin + settle.coins[user.seatid]
            end
        end
        stgy:update(playertotalbet, playertotalwin)
    end

    --结算小局记录
    local multiple = 1
    deskInfo:recordDB(0, winner.uid, retobj.settle, allCards, multiple)

    -- 记录庄家
    lastDealerSeatid = deskInfo.round.dealer and deskInfo.round.dealer.seatid

    -- 清除用户身上的卡牌信息和公示牌信息
    for _, u in ipairs(deskInfo.users) do
        u.round.cards = {}
    end
    deskInfo.round.cards = {}

    local reduceTime = 5

    if rtype == config.SettleType.show then
        reduceTime = -5
    elseif rtype == config.SettleType.Limit then
        reduceTime = -4
    else
        reduceTime = -1
    end

    local notifyMsg = function ()
        -- 维护强行大结算
        if isMaintain() then
            agent:gameOver(true, winners, settle, reduceTime)
        else
            agent:gameOver(false, winners, settle, reduceTime)
        end
    end
    skynet.timeout(1, notifyMsg)

    deskInfo:broadcast(cjson.encode(retobj))
    
    return PDEFINE.RET.SUCCESS
end

-------- 游戏接口 --------

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

function CMD.userSetAutoState(type,autoTime,uid, extraTime)
    autoTime = autoTime + 1
    deskInfo.round.expireTime = os.time() + autoTime

    -- 调试期间，机器人只间隔2秒操作
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    user:clearTimer()
    if not user.cluster_info then
        local maxOptTime = 6
        if user.round.seen == 0 then --没看牌操作快一些
            maxOptTime = 5
        end
        local minOptTime = 2
        local maxTime = autoTime > maxOptTime and maxOptTime or autoTime
        local minTime = autoTime < minOptTime and autoTime or minOptTime
        autoTime = math.random(minTime*10, maxTime*10)/10
        if extraTime then
            autoTime = autoTime + extraTime
        end
    end
    if type ~= "autoReady" and user.auto == 1 then
        autoTime = 1
        if extraTime then
            autoTime = autoTime + extraTime
        end
    end
    if DEBUG and false and user.cluster_info and user.isexit == 0 then
        autoTime = 100000
    end

    -- 机器人自动操作
    if type == "autoAiDecide" then
        user:setTimer(autoTime, autoAiDecide, uid)
    end
    -- 自动弃牌
    if type == "autoPack" then
        user:setTimer(autoTime, autoPack, uid)
    end
    -- 自动响应看牌
    if type == "autoSideShow" then
        user:setTimer(autoTime, autoSideShow, uid)
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
    local ret
    local user = deskInfo:findUserByUid(msg.uid)
    if user and user.round.packed == 1 then
        ret = agent:exitG(msg, true)
    else
        ret = agent:exitG(msg)
    end
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

-- 押注
function CMD.bet(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local coin = tonumber(recvobj.coin or 0)  -- 下注数量
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    LOG_DEBUG("用户下注: user:", uid, " coin:", coin)
    local user = deskInfo:findUserByUid(uid)
    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return warpResp(retobj)
    end

    if deskInfo.round.activeSeat ~= user.seatid then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end

    if user.state ~= PDEFINE.PLAYER_STATE.Bet then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end

    -- 金币不够下注额
    if user.coin < coin or coin < 0 then
        retobj.spcode = PDEFINE.RET.ERROR.BET_COIN_NOT_ENOUGH
        return warpResp(retobj)
    end

    -- 区分盲注和看牌下注
    -- 盲注能下两倍底注，chaal能下4倍底注
    -- 不能超过规定chaal下注额
    local betList = logic.getBetList(user)
    if not table.contain(betList, coin) then
        retobj.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return warpResp(retobj)
    end
    if user.round.seen == 1 then
        retobj.blind = 0
        deskInfo.round.baseCoin = math.round_coin(coin / 2)
    else
        retobj.blind = 1
        deskInfo.round.baseCoin = coin
    end
    retobj.coin = coin
    user:clearTimer()
    user.state = PDEFINE.PLAYER_STATE.Wait

    -- 扣去金币
    user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -1*coin, deskInfo)
    user.round.betCoin = user.round.betCoin + coin
    user.round.betCnt = user.round.betCnt + 1
    if user.coin < deskInfo.round.baseCoin*4 then
        retobj.lackcoin = 1
    end

    -- 增加奖池金额
    deskInfo.round.potCoin = deskInfo.round.potCoin + coin
    retobj.potCoin = deskInfo.round.potCoin
    
    -- 检测是否触发封顶
    retobj.isOver = 0
    if deskInfo.round.potCoin >= deskInfo.conf.potLimit then
        retobj.isOver = 1
    end

    local nextUser = logic.findNextLiveUser(user.seatid)
    deskInfo.round.activeSeat = nextUser.seatid
    nextUser.state = PDEFINE.PLAYER_STATE.Bet

    -- 广播给房间里的所有人
    local notify_object = {}
    notify_object.c  = PDEFINE.NOTIFY.PLAYER_BET
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.uid  = uid
    notify_object.blind = retobj.blind
    notify_object.coin = coin
    notify_object.betCoin = user.round.betCoin
    notify_object.betCnt = user.round.betCnt
    notify_object.isOver = retobj.isOver
    notify_object.potCoin = deskInfo.round.potCoin
    -- 广播操作
    deskInfo:broadcast(cjson.encode(notify_object))

    if retobj.isOver == 0 then
        -- 设置定时器
        retobj.delayTime = deskInfo.delayTime
        if nextUser.cluster_info then
            CMD.userSetAutoState('autoPack', deskInfo.delayTime, nextUser.uid)
        else
            CMD.userSetAutoState('autoAiDecide', deskInfo.delayTime, nextUser.uid)
        end
    
        -- 广播下一个操作人
        logic.broadcastNextUser(nextUser)

        -- 如果下注超过4轮，则强制看牌
        if nextUser.round.betCnt == deskInfo.conf.blindCnt and nextUser.round.seen == 0 then
            logic.broadcastSeeCard(nextUser)
        end
    end

    -- 是否结算
    if retobj.isOver == 1 then
        skynet.timeout(beforeRoundTime*100, function()
            roundOver(config.SettleType.Limit)
        end)
    end

    return warpResp(retobj)
end

-- 看牌
function CMD.seeCards(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    LOG_DEBUG("用户看牌: user:", uid)
    local user = deskInfo:findUserByUid(uid)
    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return warpResp(retobj)
    end

    if user.round.seen == 1 then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end

    -- 如果身上没牌，就不用看两
    if #user.round.cards == 0 then
        retobj.spcode = PDEFINE.RET.ERROR.SEE_CARD_ERROR
        return warpResp(retobj)
    end

    user.round.seen = 1
    retobj.cards = user.round.cards

    -- 广播给房间里的所有人
    logic.broadcastSeeCard(user)

    return warpResp(retobj)
end

-- 比牌 side show
function CMD.sideShow(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    LOG_DEBUG("用户比牌: user:", uid)
    local user = deskInfo:findUserByUid(uid)
    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return warpResp(retobj)
    end

    -- 必须是自己下注的时候，才能使用sideShow, 且自己先看牌
    if deskInfo.round.activeSeat ~= user.seatid or user.round.seen == 0 then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end

    -- 查看上一个玩家是否已经看牌
    local prevUser = logic.findPrevLiveUser(user.seatid)
    if prevUser.round.seen == 0 then
        retobj.spcode = PDEFINE.RET.ERROR.PREV_USER_NO_SEEN
        return warpResp(retobj)
    end

    -- 查看当前剩余人数是否大于2
    local liveUsers = logic.findLiveUser()
    if #liveUsers < 3 then
        retobj.spcode = PDEFINE.RET.ERROR.USER_COUNT_NO_ENOUGH
        return warpResp(retobj)
    end

    local coin = deskInfo.round.baseCoin
    if user.round.seen == 1 then
        coin = coin * 2
    end

    -- 查看金币是否够
    if user.coin < coin then
        retobj.spcode = PDEFINE.RET.ERROR.BET_COIN_NOT_ENOUGH
        return warpResp(retobj)
    end

    -- 移除定时器
    user:clearTimer()
    user.state = PDEFINE.PLAYER_STATE.Wait

    -- 扣除金币
    user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -1*coin, deskInfo)
    user.round.betCoin = user.round.betCoin + coin
    user.round.betCnt = user.round.betCnt + 1

    -- 记录申请的人
    deskInfo.round.sideShowUid = uid

    -- 增加奖池金额
    deskInfo.round.potCoin = deskInfo.round.potCoin + coin
    retobj.potCoin = deskInfo.round.potCoin
    
    -- 检测是否触发封顶
    if deskInfo.round.potCoin >= deskInfo.conf.potLimit then
        retobj.isOver = 1
        -- 寻问上家是否同意side show
        local notify_object = {}
        notify_object.c  = PDEFINE.NOTIFY.PLAYER_BET
        notify_object.code = PDEFINE.RET.SUCCESS
        notify_object.uid  = uid
        notify_object.coin = coin
        notify_object.betCoin = user.round.betCoin
        notify_object.isOver = retobj.isOver
        notify_object.delayTime = deskInfo.delayTime
        notify_object.potCoin = deskInfo.round.potCoin
        deskInfo:broadcast(cjson.encode(notify_object))

        -- 是否结算
        skynet.timeout(beforeRoundTime*100, function()
            roundOver(config.SettleType.Limit)
        end)
    else
        retobj.isOver = 0
        -- 切换状态
        user.state = PDEFINE.PLAYER_STATE.SideShowReq
        prevUser.state = PDEFINE.PLAYER_STATE.SideShowRes

        -- 设置定时器
        retobj.delayTime = deskInfo.delayTime
        CMD.userSetAutoState('autoSideShow', deskInfo.delayTime, prevUser.uid)
    
        -- 寻问上家是否同意side show
        local notify_object = {}
        notify_object.c  = PDEFINE.NOTIFY.PLAYER_SIDE_SHOW
        notify_object.code = PDEFINE.RET.SUCCESS
        notify_object.ask_uid  = uid
        notify_object.coin = coin
        notify_object.betCoin = user.round.betCoin
        notify_object.ans_uid = prevUser.uid
        notify_object.isOver = retobj.isOver
        notify_object.delayTime = deskInfo.delayTime
        deskInfo:broadcast(cjson.encode(notify_object))
    end
    deskInfo.round.activeSeat = prevUser.seatid

    -- 广播下一个操作人
    logic.broadcastNextUser(prevUser)

    return warpResp(retobj)
end

-- 响应是否看牌
function CMD.sideShowRes(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local rtype = math.floor(recvobj.rtype)  -- 0代表不同意，1代表同意
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    local isAgree = false
    if rtype == 1 then
        isAgree = true
    end

    LOG_DEBUG("用户响应比牌: user:", uid, " rtype:", rtype)
    local user = deskInfo:findUserByUid(uid)
    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return warpResp(retobj)
    end

    -- 必须是自己下注的时候，才能使用sideShow, 且自己先看牌
    if deskInfo.round.activeSeat ~= user.seatid then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end

    user:clearTimer()
    user.state = PDEFINE.PLAYER_STATE.Wait

    -- 如果是同意，则进行比牌操作
    -- 如果拒绝，则切换到下一个人操作
    local notify_object = {}
    notify_object.c = PDEFINE.NOTIFY.PLAYER_SIDE_SHOW_RESP
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.ans_uid = uid
    notify_object.rtype = rtype
    notify_object.ask_uid = deskInfo.round.sideShowUid

    local oUser = deskInfo:findUserByUid(deskInfo.round.sideShowUid)
    local nextUserDelayTime = sideShowTime
    if isAgree and oUser then
        local result = robot.compare(oUser.round.cards, user.round.cards)
        if result == 1 then
            -- 比牌成功
            user.round.packed = 1
            notify_object.win_uid = oUser.uid
        else
            oUser.round.packed = 1
            notify_object.win_uid = user.uid
        end
        notify_object.lcards = {0,0,0}
        notify_object.rcards = {0,0,0}
        deskInfo:broadcastViewer(cjson.encode(notify_object))
        for _, u in ipairs(deskInfo.users) do
            if u.cluster_info and u.isexit == 0 then
                notify_object.lcards = {0,0,0}
                notify_object.rcards = {0,0,0}
                if u.uid == oUser.uid or u.uid == user.uid then
                    notify_object.lcards = oUser.round.cards
                    notify_object.lcardType = robot.findCardType(oUser.round.cards)
                    notify_object.rcards = user.round.cards
                    notify_object.rcardType = robot.findCardType(user.round.cards)
                end
                -- 这里需要加入判断，自己是否显示side_show和show按钮
                logic.injectBtnStatus(notify_object, u)
                pcall(cluster.send, u.cluster_info.server, u.cluster_info.address, "sendToClient", cjson.encode(notify_object))
            end
        end
    else
        deskInfo:broadcast(cjson.encode(notify_object))
        nextUserDelayTime = 0
    end

    deskInfo.round.sideShowUid = nil

    
    -- 找到下一个人
    local nextUser = logic.findNextLiveUser(oUser.seatid)
    nextUser.state = PDEFINE.PLAYER_STATE.Bet
    -- 设置定时器
    retobj.delayTime = deskInfo.delayTime
    if nextUser.cluster_info then
        CMD.userSetAutoState('autoPack', deskInfo.delayTime+nextUserDelayTime, nextUser.uid, sideShowTime)
    else
        CMD.userSetAutoState('autoAiDecide', deskInfo.delayTime+nextUserDelayTime, nextUser.uid, sideShowTime)
    end

    deskInfo.round.activeSeat = nextUser.seatid
    skynet.timeout(nextUserDelayTime*100, function()
        -- 广播下一个操作人
        logic.broadcastNextUser(nextUser)
        -- 如果下注超过4轮，则强制看牌
        if nextUser.round.betCnt == 4 and nextUser.round.seen == 0 then
            logic.broadcastSeeCard(nextUser)
        end
    end)

    return warpResp(retobj)
end

-- 用户请求看牌
function CMD.show(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    LOG_DEBUG("用户看牌: user:", uid)
    local user = deskInfo:findUserByUid(uid)
    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return warpResp(retobj)
    end

    -- 必须是自己下注的时候，才能使用sideShow, 且自己先看牌
    if deskInfo.round.activeSeat ~= user.seatid then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end

    -- 查看当前剩余人数是否等于2
    local liveUsers = logic.findLiveUser()
    if #liveUsers ~= 2 then
        retobj.spcode = PDEFINE.RET.ERROR.USER_COUNT_NO_ENOUGH
        return warpResp(retobj)
    end

    local coin = deskInfo.round.baseCoin
    if user.round.seen == 1 then
        coin = coin * 2
    end

    -- 查看金币是否够
    if user.coin < coin then
        retobj.spcode = PDEFINE.RET.ERROR.BET_COIN_NOT_ENOUGH
        return warpResp(retobj)
    end

    user:clearTimer()
    user.state = PDEFINE.PLAYER_STATE.Wait

    -- 扣除金币
    user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -1*coin, deskInfo)
    user.round.betCoin = user.round.betCoin + coin
    user.round.betCnt = user.round.betCnt + 1

    -- 增加奖池金额
    deskInfo.round.potCoin = deskInfo.round.potCoin + coin
    retobj.potCoin = deskInfo.round.potCoin

    local prevUser = logic.findPrevLiveUser(user.seatid)

    -- 看牌是不需要响应的，直接看牌结算
    retobj.isOver = 1
    deskInfo.round.showUid = user.uid
    deskInfo.round.activeSeat = nil

    local notify_object = {}
    notify_object.c  = PDEFINE.NOTIFY.PLAYER_SHOW
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.uid    = uid
    notify_object.coin   = coin
    notify_object.betCoin = user.round.betCoin

    -- 广播操作
    deskInfo:broadcast(cjson.encode(notify_object))

    -- 开始结算
    skynet.timeout(beforeRoundTime*100, function()
        roundOver(config.SettleType.Show)
    end)

    return warpResp(retobj)
end

-- 用户弃牌
function CMD.pack(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    LOG_DEBUG("用户弃牌: user:", uid)
    local user = deskInfo:findUserByUid(uid)
    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return warpResp(retobj)
    end

    -- 查看自己是否是当前操作用户
    if user.seatid ~= deskInfo.round.activeSeat then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end

    if user.uid == deskInfo.round.sideShowUid or user.state == PDEFINE.PLAYER_STATE.SideShowRes then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end

    -- 查看当前剩余人数是否等于2
    local liveUsers = logic.findLiveUser()

    user.round.packed = 1
    local isOver = 0
    -- 如果只剩下一个人，则剩下的那个人就是赢家
    if #liveUsers <= 2 then
        isOver = 1
    end

    -- 弃牌
    local notify_object = {}
    notify_object.c  = PDEFINE.NOTIFY.PLAYER_PACK
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.uid    = uid

    deskInfo:broadcastViewer(cjson.encode(notify_object))

    for _, u in ipairs(deskInfo.users) do
        if  u.cluster_info and u.isexit == 0 then
            -- 这里需要加入判断，自己是否显示side_show和show按钮
            logic.injectBtnStatus (notify_object, u)
            pcall(cluster.send, u.cluster_info.server, u.cluster_info.address, "sendToClient", cjson.encode(notify_object))
        end
    end

    user:clearTimer()
    user.state = PDEFINE.PLAYER_STATE.Wait

    local nextUser = logic.findNextLiveUser(user.seatid)

    if isOver == 1 then
        -- 开始结算
        skynet.timeout(beforeRoundTime*100, function()
            roundOver(config.SettleType.Live)
        end)
    else
        -- 设置定时器
        retobj.delayTime = deskInfo.delayTime
        deskInfo.round.activeSeat = nextUser.seatid
        -- 广播下一个操作人
        nextUser.state = PDEFINE.PLAYER_STATE.Bet
        if nextUser.cluster_info then
            CMD.userSetAutoState('autoPack', deskInfo.delayTime, nextUser.uid)
        else
            CMD.userSetAutoState('autoAiDecide', deskInfo.delayTime, nextUser.uid)
        end
        logic.broadcastNextUser(nextUser)
        -- 如果下注超过4轮，则强制看牌
        if nextUser.round.betCnt == 4 and nextUser.round.seen == 0 then
            logic.broadcastSeeCard(nextUser)
        end

        if not user.cluster_info and math.random() < PDEFINE.ROBOT.DROP_LEAVE_ROOM_PROB then
            user:setTimer(math.random(1, 5), autoLeave, user.uid)
        end
    end

    return warpResp(retobj)
end

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

--! 出牌过程中 取消托管
function CMD.cancelAuto(source, msg)
    local recvobj  = msg
    deskInfo:print('cancelAuto, msg:', recvobj)
    local uid = math.floor(recvobj.uid)
    local user = deskInfo:findUserByUid(uid)

    local retobj = {c = recvobj.cmd, code= PDEFINE.RET.SUCCESS, spcode=0}
    if not user or user.auto == 0 then
        return warpResp(retobj)
    end
    
    user:clearTimer()
    user.auto = 0 --关闭自动

    -- 根据状态，重新开启计时器
    if user.state == PDEFINE.PLAYER_STATE.SideShowRes then
        retobj.delayTime = deskInfo.delayTime
        CMD.userSetAutoState('autoSideShow', retobj.delayTime, uid)
    elseif user.state == PDEFINE.PLAYER_STATE.Bet then
        retobj.delayTime = deskInfo.delayTime
        CMD.userSetAutoState('autoPack', retobj.delayTime, uid)
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
        local user = deskInfo:findUserByUid(uid)
        -- 弃牌后也可以换桌
        if user and user.round.packed == 1 then
            spcode = agent:switchDesk(msg)
        elseif not user then
            user = deskInfo:findViewUser(uid)
            if user then
                -- 观战的可以换桌
                spcode = agent:switchDesk(msg)
            else
                spcode = 1
            end
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
    local userInfo = deskInfo:findUserByUid(msg.uid)
    local deskInfoStr = deskInfo:toResponse(msg.uid)
    if not deskInfoStr then
        return nil
    end
    -- 这里需要加入判断，自己是否显示side_show和show按钮
    logic.injectBtnStatus (deskInfoStr, userInfo)
    -- 加入牌型
    for _, u in ipairs(deskInfoStr.users) do
        if u.uid == msg.uid and #u.round.cards > 0 then
            u.round.cardType = robot.findCardType(u.round.cards)
        end
        u.round.can_show = 0
        u.round.can_side_show = 0
        local liveUsers = logic.findLiveUser()
        local prevUser = logic.findPrevLiveUser(u.seatid)
        if #liveUsers == 2 and prevUser.round.seen == 1 then
            u.round.can_show = 1
        end
        if u.round.seen == 1 and prevUser.round.seen == 1 and #liveUsers > 2 then
            u.round.can_side_show = 1
        end
        u.round.betList = logic.getBetList(u)
    end
    --deskInfo:print("getDeskInfo msg:", msg)
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

    -- 打乱桌子位置，不用按照顺序坐下
    shuffle(deskInfo.seatList)
    if not deskInfo.conf.betLimit then
        deskInfo.conf.betLimit = 50 * deskInfo.bet
    end

    if not deskInfo.conf.potLimit then
        deskInfo.conf.potLimit = 128 * deskInfo.bet
    end

    -- 最大限制blind次数
    if not deskInfo.conf.blindCnt then
        deskInfo.conf.blindCnt = 4
    end

    if msg.sid then
        stgy:load(msg.sid, gameid)
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
            startGame(3)
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