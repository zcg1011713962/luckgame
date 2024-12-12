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
local raceCfg = require "conf.raceCfg"
local record = require "base.record"
local BetStgy = require "betgame.betstgy"
local cs = queue()
local GAME_NAME = skynet.getenv("gamename") or "game"
local DEBUG = skynet.getenv("DEBUG")
local CMD = {}
local closeServer = false

math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 7)))

---@type BetStgy
local stgy = BetStgy.new()

--控制参数
--参数值一般规则：为1时保持平衡；大于1时玩家buff；小于1时玩家debuff
local ControlParams = { --控制参数，
    robot_exchange_cards_prob = 0.9,  --机器人交换手牌的概率(注意，实际概率是1-0.8=0.2)
    robot_check_hand_cards_prob = 0.75  --机器人检测下家手牌的概率(0.8->0.2)
}

---@type BaseDeskInfo @instance of dominoagent
local deskInfo = nil  -- 桌子信息
---@type BaseAgent
local agent = nil  -- 游戏实例

local LastDealerSeat = nil

local config = {
    -- 由initCard生成
    Cards = {
    },
    -- 错误码
    Spcode = {
        ParamsError = 1,  -- 参数错误
        UserNotFound = 2,  -- 用户未找到
        UserStateError = 3,  -- 用户状态错误
        CanNotPass =  202,  -- 不能pass
        CanNotConnect = 203, --不能接龙
    },
    discardTime = 3, -- 发牌动画时间
    -- 发牌数量
    InitCardLen = 7,
    -- 最大牌值 A 0x0E
    MaxValue = 14,
    AutoDelayTime = 50,
}

local function initCards()
    local cards = {}
    for i = 6, 0, -1 do
        for j = i, 0, -1 do
            local cnt = #cards
            table.insert(cards, {u = i, l = j, id=cnt+1})
        end
    end
    config.Cards = cards
end

local function getCard(id)
    for _, card in pairs(config.Cards) do
        if card.id == id then
            return card
        end
    end
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

local function initDeskInfoRound(uid, seatid)
    deskInfo.round = {}
    deskInfo.round.cards = {} -- 堆上的牌
    deskInfo.round.activeSeat = seatid -- 当前活动座位
    deskInfo.round.settle = {} -- 小结算
    deskInfo.round.connect = {} --待接的点(1,2)：表示前后2个位置能接的点
    deskInfo.round.dealer = { ----此把的庄家(庄家先出)
        uid = uid,
        seatid = seatid
    }
    deskInfo.round.roundCards = {}  -- 当前出的牌(最多28张)
    deskInfo.round.firstCardId = 0 --首牌
    deskInfo.round.passSeatid = {} --本轮pass的座位号，要给第一个pass的上家金币
    deskInfo.round.winuid = 0 --赢家
    deskInfo.roundstime = 0 --小局开始时间
    initCards()
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
    user.round.pass        = 0  -- 是否选择pass
    user.round.lastCard    = nil  -- 最后出的一张牌
    user.round.passCard = {} --用户pass的点数
    user.round.initcards = {}
    user.round.deductcoin  = 0
    user.round.addcoin     = 0
end

local function assignSeat()
    local seatid_list = {1, 3, 2, 4}
    for _, seatid in ipairs(seatid_list) do
        if table.contain(deskInfo.seatList, seatid) then
            for i=#deskInfo.seatList, 1, -1 do
                if deskInfo.seatList[i] == seatid then
                    table.remove(deskInfo.seatList, i)
                    break
                end
            end
            return seatid
        end
    end
    LOG_ERROR("assignSeat error", deskInfo.seatList)
end

local function formatCards(cards)
    local cardstrs = {}
    for _, card in ipairs(cards) do
        table.insert(cardstrs, card.l..card.u)
    end
    return "["..table.concat(cardstrs, ",").."]"
end

--计算均值
local function calcMean(tbl)
    local c = #tbl
    if c < 1 then return 0 end
    local s = 0
    for _, v in ipairs(tbl) do
        s = s + v
    end
    return s/c
end

--计算方差
local function calcVariance(tbl)
    local c = #tbl
    if c < 2 then return 0 end
    local m = calcMean(tbl)
    local s = 0
    for _, v in ipairs(tbl) do
        s = s + (v-m)*(v-m)
    end
    return s/(c-1)
end

--计算手牌独立性
local function calcCardsIndependence(cards)
    local pointsCnt = {0,0,0,0,0,0,0} --数值下表1~7分别代表点数0~6
    for _, c in ipairs(cards) do
        pointsCnt[c.l+1] = pointsCnt[c.l+1] + 1
        pointsCnt[c.u+1] = pointsCnt[c.u+1] + 1
    end
    local alonePointCnt = 0
    for i = 1, 7 do
        if pointsCnt[i] > 0 then
            alonePointCnt = alonePointCnt + 1
        end
    end
    local variance = calcVariance(pointsCnt)
    return {
        apc = alonePointCnt,    --独立点数
        var = variance          --点数方差
    }
end

--比较卡牌，如果cards1优于cards2，返回true，否则返回false
local function compareCards(cards1, cards2)
    local idp1 = calcCardsIndependence(cards1)
    local idp2 = calcCardsIndependence(cards2)
    if idp1.apc == idp2.apc then
        return idp1.var < idp2.var
    else
        return idp1.apc > idp2.apc
    end
end

--找出最优的出牌
local function getBestDiscardCard(handcards, outcards)
    local counts = {}
    for _, card in ipairs(handcards) do
        counts[card.l] = (counts[card.l] or 0) + 1
        counts[card.u] = (counts[card.u] or 0) + 1
    end
    local pointCnts = {}
    for _, card in ipairs(outcards) do
        for __, p in ipairs({card.l, card.u}) do
            local exist
            for ___, item in ipairs(pointCnts) do
                if item.point == p then
                    exist = true
                end
            end
            if not exist then
                assert(counts[p], "counts "..p.." is null")
                table.insert(pointCnts, {point=p, count=counts[p]})
            end
        end
    end
    table.sort(pointCnts, function(a, b)
        if a.count == b.count then
            return a.point > b.point
        else
            return a.count > b.count
        end
    end)

    local maxPoint = pointCnts[1].point
    for _, card in ipairs(outcards) do
        if card.l == maxPoint and card.u == maxPoint then
            LOG_DEBUG("getBestDiscardCard1", formatCards(handcards), formatCards(outcards), card.l..card.u)
            return card
        end
    end

    local secondMaxPoint = pointCnts[1].point
    if #pointCnts > 1 then
        secondMaxPoint = pointCnts[2].point
    end
    local badcards = {}
    for _, card in ipairs(outcards) do
        if card.l == maxPoint or card.u == maxPoint then
            table.insert(badcards, card)
        end
    end
    for _, card in ipairs(badcards) do
        if (card.l == maxPoint and card.u == secondMaxPoint) or (card.l == secondMaxPoint and card.u == maxPoint) then
            LOG_DEBUG("getBestDiscardCard2", formatCards(handcards), formatCards(outcards), card.l..card.u)
            return card
        end
    end
    local card = badcards[math.random(#badcards)]
    LOG_DEBUG("getBestDiscardCard3", formatCards(handcards), formatCards(outcards), card.l..card.u)
    return card
end

-- 挑选出下家可以接起的牌
-- blockedPoints: 要得起的点数
local function findNextUserCanConnectCard(randomCards, availablePoints)
    local cards = {}
    local connect = deskInfo.round.connect
    if #connect > 0 then
        for _, c in ipairs(randomCards) do
            local canput = false
            if c.l == connect[1] and (table.contain(availablePoints, c.u) or table.contain(availablePoints, connect[2])) then
                canput = true
            end
            if c.l == connect[2] and (table.contain(availablePoints, c.u) or table.contain(availablePoints, connect[1])) then
                canput = true
            end
            if c.u == connect[1] and (table.contain(availablePoints, c.l) or table.contain(availablePoints, connect[2])) then
                canput = true
            end
            if c.u == connect[2] and (table.contain(availablePoints, c.l) or table.contain(availablePoints, connect[1])) then
                canput = true
            end
            if canput then
                table.insert(cards, c)
            end
        end
    end
    return cards
end

-- 挑选下家接不起的牌
-- blockedPoints: 要不起的点数
local function findNextUserCanNotConnectCards(randomCards, blockedPoints)
    local cards = {}
    local connect = deskInfo.round.connect
    for _, c in pairs(randomCards) do
        local canput = false
        if #connect == 0 then
            if table.contain(blockedPoints, c.u) and table.contain(blockedPoints, c.l) then
                canput = true
            end
        else
            if c.l == connect[1] and table.contain(blockedPoints, c.u) and table.contain(blockedPoints, connect[2]) then
                canput = true
            end
            if c.l == connect[2] and table.contain(blockedPoints, c.u) and table.contain(blockedPoints, connect[1]) then
                canput = true
            end
            if c.u == connect[1] and table.contain(blockedPoints, c.l) and table.contain(blockedPoints, connect[2]) then
                canput = true
            end
            if c.u == connect[2] and table.contain(blockedPoints, c.l) and table.contain(blockedPoints, connect[1]) then
                canput = true
            end
        end
        if canput then
            table.insert(cards, c)
        end
    end
    return cards
end

-- 自动出牌
local function autoDiscard(uid)
    return cs(function()
        LOG_DEBUG("autoDiscard 用户自动出牌 uid:".. uid)
        
        local user = deskInfo:findUserByUid(uid)
        if not user then
            LOG_DEBUG("autoDiscard uid:", uid, ' user not found')
        end
        user:clearTimer()
        if deskInfo.round.activeSeat ~= user.seatid then
            LOG_DEBUG("出牌对象错误: uid:", uid, ' seatid:', user.seatid, " activeSeat:", deskInfo.round.activeSeat)
            return
        end
        if user.state ~= PDEFINE.PLAYER_STATE.Discard then
            LOG_DEBUG("出牌状态错误: uid:", uid, ' seatid:', user.seatid, " state:", user.state)
            return
        end
        local delayTime = 1
        -- 找牌
        local randomCards = {}
        for _, item in pairs(user.round.cards) do
            if #deskInfo.round.connect > 0 then
                if (item.u == deskInfo.round.connect[1] or item.u == deskInfo.round.connect[2] or item.l == deskInfo.round.connect[1] or item.l == deskInfo.round.connect[2]) then
                    table.insert(randomCards, item) --能接上
                end
            else
                table.insert(randomCards, item)
            end
        end

        if #randomCards == 0 then
            local msg = { --没牌出就pass
                ['c'] = 25715,
                ['uid'] = uid,
                ['is_auto'] = 1
            }
            LOG_DEBUG("autoDiscard 自动出牌要不起：", uid)
            return CMD.pass(nil, msg)
        end

        -- 玩家随机出牌，机器人按策略出牌
        local card = nil
        if user.cluster_info then
            card = randomCards[math.random(1, #randomCards)]
        else
            local nextUser = deskInfo:findNextUser(user.seatid)
            local check_hand_cards_prob = getControlParam("robot_check_hand_cards_prob")
            local availablePoints = {}
            for _, item in pairs(nextUser.round.cards) do
                if not table.contain(availablePoints, item.l) then
                    table.insert(availablePoints, item.l)
                end
                if not table.contain(availablePoints, item.u) then
                    table.insert(availablePoints, item.u)
                end
            end
            if nextUser.cluster_info then   --下一个是玩家
                local cards
                if math.random() > check_hand_cards_prob then
                    local blockedPoints = {}
                    for p = 0, 6 do
                        if not table.contain(availablePoints, p) then
                            table.insert(blockedPoints, p)
                        end
                    end
                    cards = findNextUserCanNotConnectCards(randomCards, blockedPoints)
                    LOG_DEBUG("findNextUserCanNotConnectCards1", formatCards(cards), formatCards(user.round.cards), formatCards(nextUser.round.cards), table.concat(deskInfo.round.connect, ","))
                else
                    cards = findNextUserCanNotConnectCards(randomCards, nextUser.round.passCard)
                    LOG_DEBUG("findNextUserCanNotConnectCards2", formatCards(cards), formatCards(user.round.cards), formatCards(nextUser.round.cards), table.concat(nextUser.round.passCard, ","), table.concat(deskInfo.round.connect, ","))
                end
                if #cards > 0 then
                    card = getBestDiscardCard(user.round.cards, cards)
                end
            else --下一个是机器人
                if math.random() < 0.5 and #nextUser.round.cards < #user.round.cards then --下家机器人的牌比我少
                    local cards = findNextUserCanConnectCard(randomCards, availablePoints)
                    LOG_DEBUG("findNextUserCanConnectCard", formatCards(cards), formatCards(user.round.cards), formatCards(nextUser.round.cards), table.concat(deskInfo.round.connect, ","))
                    if #cards > 0 then
                        card = getBestDiscardCard(user.round.cards, cards)
                    end
                end
            end
            if not card then
                card = getBestDiscardCard(user.round.cards, randomCards)
            end
            if not card then
                card = randomCards[math.random(1, #randomCards)]
            end
        end

        -- 如果是pass则不需要设置成托管
        if user.cluster_info then
            if user.auto == 0 then
                user.auto = 1
                delayTime = config.AutoDelayTime
                deskInfo:autoMsgNotify(user, 1, 0)
            end
        end
        skynet.timeout(delayTime, function()
            local msg = {
                c = 25702,
                uid = uid,
                cardid = card.id,
                isauto = true,
            }
            local _, resp = CMD.discard(nil, msg)
            LOG_DEBUG("自动出牌 msg:", msg, "返回: ", resp)
        end)
    end)
end

-- 先判断是否pass, 再判断是否自动出牌
local function checkDiscard(uid, autoTime, extraTime)
    return cs(function()
        local user = deskInfo:findUserByUid(uid)
        if deskInfo.round.activeSeat ~= user.seatid then
            LOG_DEBUG("checkDiscard 出牌对象错误: uid:", uid, ' seatid:', user.seatid, " activeSeat:", deskInfo.round.activeSeat)
            return
        end
        if user.state ~= PDEFINE.PLAYER_STATE.Discard then
            LOG_DEBUG("checkDiscard 出牌状态错误: uid:", uid, ' seatid:', user.seatid, " state:", user.state)
            return
        end
        -- 找牌
        if #deskInfo.round.roundCards > 0 then
            local randomCards = {}
            for _, item in pairs(user.round.cards) do
                if #deskInfo.round.connect>0 and (item.u == deskInfo.round.connect[1] or item.u == deskInfo.round.connect[2] 
                    or item.l == deskInfo.round.connect[1] or item.l == deskInfo.round.connect[2]) then
                    table.insert(randomCards, item) --能接上
                end
            end
            if #randomCards == 0 then
                local msg = { --没牌出就pass
                    ['c'] = 25715,
                    ['uid'] = uid,
                }
                LOG_DEBUG("checkDiscard 自动出牌要不起：", uid)
                return CMD.pass(nil, msg)
            end
        end
        CMD.userSetAutoState('autoDiscard', autoTime, user.uid, extraTime)
    end)
end

-- 自动准备
local function autoReady(uid)
    return cs(function()
        LOG_DEBUG("自动准备 uid:".. uid)
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
    if deskInfo.conf and deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.VIP then
        pcall(cluster.send, "master", ".balviproommgr", "syncVipRoomData", deskInfo.gameid, deskInfo.deskid, deskInfo.users, deskInfo.panel.score)
    end
    
    collectgarbage("collect")
    skynet.exit()
end

local function shouldAddAi()
    local hasPlayer = false
    for _, user in pairs(deskInfo.users) do
        if user.cluster_info then
            hasPlayer = true
            break
        end
    end
    if hasPlayer and #deskInfo.users< 2 then
        return true
    end
    return false
end

-- 开始发牌
local function roundStart()
    local retobj = {}
    LOG_DEBUG("开始游戏: deskid:", deskInfo.uuid)
    deskInfo.curround = deskInfo.curround + 1
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH and shouldAddAi() then --匹配房人数不够继续填充机器人
        deskInfo:aiJoin()
    end
    if #deskInfo.users == 0 then
        for _, user in ipairs(deskInfo.users) do
            user.state = PDEFINE.PLAYER_STATE.Wait
            user:clearTimer()
        end
        deskInfo:destroy()
        return
    end
  
    retobj.c = PDEFINE.NOTIFY.GAME_DEAL
    retobj.code = PDEFINE.RET.SUCCESS
    local newDealer = 0
    -- 如果没有选出庄家，则使用当前庄家
    retobj.activeUid = deskInfo.round.dealer['uid']
    retobj.dealerUid = deskInfo.round.dealer['uid']

    -- 切换桌子状态
    deskInfo:updateState(PDEFINE.DESK_STATE.PLAY)
    -- 开始发牌
    retobj.cards = nil
    retobj.delayTime = deskInfo.delayTime
    retobj.passCard = {}
    -- 先规划牌,用来随即出状态

    for _, user in ipairs(deskInfo.users) do
        local cards = {}
        for i = 1, config.InitCardLen do
            local card = table.remove(deskInfo.round.cards)
            table.insert(cards, card)
        end
        table.sort(cards, function (a, b)
            if a.u ~= b.u then
                return a.u < b.u
            end
            if a.l ~= b.l then
                return a.l < b.l
            end
            return false
        end)
        user.round.cards = cards
    end
    --是否需要换牌
    local exchange_cards_prob = getControlParam("robot_exchange_cards_prob")
    if math.random() > exchange_cards_prob then
        for _, robot in ipairs(deskInfo.users) do
            if not robot.cluster_info then
                for __, player in ipairs(deskInfo.users) do
                    if player.cluster_info then
                        if compareCards(player.round.cards, robot.round.cards) then
                            LOG_DEBUG("exchange cards", formatCards(robot.round.cards), "-->", formatCards(player.round.cards))
                            local tmpcards = robot.round.cards
                            robot.round.cards = player.round.cards
                            player.round.cards = tmpcards
                        end
                    end
                end 
            end
        end
    end

    for _, user in ipairs(deskInfo.users) do
        for _, card in ipairs(user.round.cards) do
            -- 是否需要重新选庄家
            if newDealer == 1 then
                if card.u == 6 and card.l == 6 then
                    retobj.activeUid = user.uid
                    retobj.dealerUid = user.uid
                    deskInfo.round.dealer = {
                        uid = user.uid,
                        seatid = user.seatid
                    }
                end
            end
        end
        user.round.initcards = table.copy(user.round.cards)
        user.round.passCard = {}
    end

    for _, user in pairs(deskInfo.users) do
        retobj.cards = user.round.cards

        -- 庄家切换到出牌阶段
        if user.seatid == deskInfo.round.dealer['seatid'] then
            -- 切换状态
            user.state = PDEFINE.PLAYER_STATE.Discard
            deskInfo.round.activeSeat = user.seatid
            -- 设置定时器
            LOG_DEBUG("roundStart autoDiscard delayTime:", deskInfo.delayTime, ' uid:', user.uid)
            local autoTime = deskInfo.delayTime
            skynet.timeout(30, function()
                checkDiscard(user.uid, autoTime, config.discardTime)
            end)
        else
            user.state = PDEFINE.PLAYER_STATE.Wait
        end
        
        LOG_DEBUG("round start uid:", user.uid, ' cards:', formatCards(user.round.cards))
        -- 广播消息
        if user.cluster_info and user.isexit == 0 then
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(retobj))
        end
    end
    -- 广播给观看者
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

    if delayTime then
        delayTime = delayTime * 100
    else
        delayTime = 30
    end
    skynet.timeout(delayTime, function()
        -- 调用基类的新的一轮
        deskInfo:roundStart()
        roundStart()
    end)
end

-- 是否能接上
local function canConnect(wincard, Card, NextCard)
    if nil == NextCard then
        return false
    end
    if NextCard.u == Card.u or NextCard.l == Card.u then --card.u链接了上一张牌
        if Card.l == wincard.u or Card.l == wincard.l then --如果card.u == card.l 也满足此情况
            return true
        end
    elseif NextCard.l == Card.l or NextCard.u == Card.l then --card.l链接了上一张牌
        if Card.u == wincard.u or Card.u == wincard.l then --如果card.u == card.l 也满足此情况
            return true
        end
    end
    return false
end

-- 计算倍数
local function calMult()
    local mult = 1
    if deskInfo.round.winuid == 0 then
        local settle = {} --剩余手牌点数
        local upper = 6 --高点
        for _, user in pairs(deskInfo.users) do
            local score = 0
            for _, card in pairs(user.round.cards) do
                score = score + card.u + card.l
                if card.u < upper then
                    upper = card.u
                end
            end
            table.insert(settle, {uid=user.uid, score = score, cnt=#user.round.cards, upper = upper})
        end
        table.sort(settle, function(a, b)
            if a.score < b.score then --第1 比点数
                return true
            else
                if a.score == b.score then
                    if a.cnt < b.cnt then --第2 比剩余手牌数
                        return true
                    else
                        if a.cnt == b.cnt then
                            if a.upper < b.upper then --第3 比手牌中的最大高点
                                return true
                            else
                                return false
                            end
                        else
                            return false
                        end
                    end
                else
                    return false
                end
            end
        end)
        deskInfo.round.winuid = settle[1].uid
        return mult
    end
    local winner = deskInfo:findUserByUid(deskInfo.round.winuid) --赢家
    local winCard = winner.round.lastCard
    local firstCard = deskInfo.round.roundCards[1]
    local lastCard = deskInfo.round.roundCards[#deskInfo.round.roundCards]
    local connectFrist = canConnect(winCard, firstCard, deskInfo.round.roundCards[2])
    local connectLast = canConnect(winCard, lastCard, deskInfo.round.roundCards[#deskInfo.round.roundCards-1])

    if winCard.u ~= winCard.l then --win card 高低点不同
        if connectFrist and connectLast then
            mult = 4 -- Quartet 4倍
        else
            mult = 2 -- Double 2倍
        end
    else --高低先相同
        if connectFrist and connectLast then
            mult = 5 -- Qunitet 5倍
        else
            mult = 3 -- Triple 3倍
        end
    end
    return mult
end

-- 游戏结束，大结算
local function gameOver(isDismiss)
    ---@type Settle
    local settle = {
        uids = {}, -- 座位号对应的uid
        league = {},  -- 排位经验
        coins = {}, -- 结算的金币
        scores = {}, -- 获得的分数
        levelexps = {}, -- 经验值
        rps = {} -- 经验值
    }
    for i = 1, deskInfo.seat do
        local u = deskInfo:findUserBySeatid(i)
        if u then
            table.insert(settle.uids, u.uid)
        else
            table.insert(settle.uids,0)
        end
        table.insert(settle.league, 0)
        table.insert(settle.coins, 0)
        table.insert(settle.scores, 0)
        table.insert(settle.levelexps, 0)
        table.insert(settle.rps, 0)
    end

    for _, user in ipairs(deskInfo.users) do
        settle.scores[user.seatid] = user.score
    end
    deskInfo:gameOver(settle, isDismiss)
end

-- 此轮游戏结束
--  结算规则要重写
local function roundOver(isDismiss)
    LOG_DEBUG("结束了，要开始下一轮了:", deskInfo.deskid)
    -- 是否在结算中
    if deskInfo.in_settle then
        return
    end
    deskInfo.in_settle = true
    deskInfo:updateState(PDEFINE.DESK_STATE.SETTLE, true)
    -- 如果有解散房间，则取消操作
    if not isDismiss then
        -- 取消解散
        deskInfo:cancelDismiss()
    end
    -- 清除玩家定时器
    -- 处理玩家状态
    local uids = {} -- 这个游戏要单独处理，因为没有走gameover
    for _, user in ipairs(deskInfo.users) do
        if user.cluster_info then
            table.insert(uids, user.uid)
        end
        user.state = PDEFINE.PLAYER_STATE.Wait
        user:clearTimer()
    end
    pcall(cluster.send, "master", ".mgrdesk", "unlockPlayer", deskInfo.deskid, uids, deskInfo.gameid, deskInfo.conf.roomtype)

    local mult = calMult()
    local winuid = deskInfo.round.winuid --赢家的uid

    -- 赢的人作为下一轮的庄家
    deskInfo.preWinUid = winuid

    -- 做下处理用于记录战绩信息
    local settle = {
        uids = {},  -- uids
        league = {},  -- 排位经验
        coins = {}, -- 结算的金币
        scores = {}, -- 获得的分数
        levelexps = {}, -- 经验值
        rps = {},  -- rp 值
        fcoins = {},  -- 最终的金币
    }
    local dangerUids = {}  -- 快要破产的人
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

    local playertotalbet = 0
    local playertotalwin = 0

    local DelayTime = 12
    local retobj = {}
    retobj.c = PDEFINE.NOTIFY.GAME_ROUND_OVER
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.settle = {}  -- 四个位置上的分数
    retobj.mult = mult
    retobj.winuid = winuid
    retobj.delayTime = DelayTime
    retobj.isDismiss = isDismiss and 1 or 0  -- 是否解散
    if #deskInfo.round.passSeatid == #deskInfo.users then
        retobj.mult = 0 --single dead end
        mult = 1
    end
    LOG_DEBUG("roundOver mult:", mult)
    local totalBetCoin = 0
    local totalTaxCoin = 0
    -- 开始结算分数
    local winUidsAndCoin = {}
    for _, user in pairs(deskInfo.users) do
        local bet = deskInfo.bet
        local singleUserPay = bet * mult
        local winCoin = 0
        local addExp = player_tool.boosterExp(user.uid, (user.uid == winuid), deskInfo.conf.roomtype, deskInfo.gameid)
        local tax = 0

        user.levelexp = user.levelexp + addExp
        settle.levelexps[user.seatid] = addExp

        if user.uid == winuid then
            if user.race_id > 0 and user.race_type == PDEFINE.RACE_TYPE.ROUND_WIN_COUNT then
                pcall(cluster.send, "master", ".raceroommgr", "addRaceScore", user.uid, user.race_id, 1)
            end

            local rate = (1-deskInfo.taxrate)
            winCoin = (#deskInfo.users-1) * singleUserPay
            tax = math.round_coin(winCoin * deskInfo.taxrate)
            winCoin = winCoin - tax

            local settleItem = {
                uid = user.uid,
                seatid = user.seatid,
                coin = user.coin,
                addcoin = winCoin,
                addrp = 0,
                addexp = addExp,
                leagueexp = 0,  -- 增加排位分
            }
            user.settlewin = user.settlewin + mult*(#deskInfo.users - 1) * rate
            user.wincoin = user.wincoin + winCoin
            user:changeCoin(PDEFINE.ALTERCOINTAG.WIN, winCoin, deskInfo)
            settleItem.coin = user.coin
            winUidsAndCoin[user.uid] = winCoin
            local rp = player_tool.calGameWinRp(deskInfo.gameid)
            user.rp = user.rp + rp
            settleItem.addrp = settleItem.addrp + rp
            table.insert(retobj.settle, settleItem)
            settle.rps[user.seatid] = rp
            settle.coins[user.seatid] = winCoin
        else
            local settleItem = {
                uid = user.uid,
                seatid = user.seatid,
                coin = user.coin,
                addcoin = -singleUserPay,
                addexp = addExp,
                addrp = 0,
            }
            table.insert(retobj.settle, settleItem)
            -- 不需要扣，在changeCoin里面扣除了
            -- user.coin = user.coin - singleUserPay
            user.settlewin = user.settlewin - mult
            user.wincoin = user.wincoin - singleUserPay
            settle.coins[user.seatid] = -singleUserPay
            user:changeCoin(PDEFINE.ALTERCOINTAG.WIN, -singleUserPay, deskInfo)
            settleItem.coin = user.coin
        end

        local result = {cards = user.round.initcards}
        local realwincoin = settle.coins[user.seatid] - user.round.deductcoin + user.round.addcoin
        record.betGameLog(deskInfo, user, deskInfo.bet, realwincoin, result, tax)

        if user.cluster_info and user.istest ~= 1 then
            playertotalwin = playertotalwin + realwincoin
            playertotalbet = playertotalbet + deskInfo.bet
        end

        totalTaxCoin = totalTaxCoin + tax
        totalBetCoin = totalBetCoin + deskInfo.bet

        -- 好友房和匹配房踢人的门槛不同，所以分开判断
        if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
            if user.coin - deskInfo.conf.mincoin < (2+PDEFINE_GAME.DANGER_BET_MULT-1)*bet then
                table.insert(dangerUids, user.uid)
            end
        else
            if user.coin < (2+PDEFINE_GAME.DANGER_BET_MULT)*bet then
                table.insert(dangerUids, user.uid)
            end
        end
        settle.fcoins[user.seatid] = user.coin
    end
    retobj.fbshare = deskInfo:recordWinTimes(winUidsAndCoin)
    retobj.fcoins = settle.fcoins

    -- 私人房需要给房主分成
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        local totalbet = (deskInfo.private.totalbet or 0) + totalBetCoin
        deskInfo.private.totalbet = totalbet
        pcall(cluster.send, "master", ".balprivateroommgr", "gameOver", deskInfo.deskid, deskInfo.owner, totalTaxCoin, deskInfo.bet, totalbet)
    end

    local allCards = {}
    local updateAiUsers = {}
    for _, user in pairs(deskInfo.users) do
        table.insert(allCards, {
            uid = user.uid,
            cards = user.round.initcards
        })
        -- 机器人也写入记录
        local win = 0 
        if user.uid == winuid then
            win = 1
        end
        -- 记录托管时间
        if user.autoStartTime then
            user.autoTotalTime = user.autoTotalTime + os.time() - user.autoStartTime
            user.autoStartTime = os.time()
        end
        -- 更新机器人
        if not user.cluster_info then
            table.insert(updateAiUsers, {uid=user.uid, coin=user.coin, rp=user.rp, levelexp=user.levelexp, leagueexp=settle.league[user.seatid], gameid=deskInfo.gameid})
        end
    end
    --pcall(cluster.send, "ai", ".aiuser", "updateAiInfo", updateAiUsers)
    deskInfo:recordDB(0, winuid, retobj.settle, allCards, 1)

    for _, user in pairs(deskInfo.users) do
        local bet = deskInfo.bet

        retobj.wincoins = {}
        for _, muser in pairs(deskInfo.users) do
            table.insert(retobj.wincoins, {
                uid = muser.uid,
                wincoinshow = math.round_coin(muser.settlewin * bet)
            })
        end
        if  user.cluster_info and user.isexit == 0 then
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(retobj))
        end
    end
    -- 广播给观战玩家
    retobj.wincoins = {}
    for _, muser in pairs(deskInfo.users) do
        table.insert(retobj.wincoins, {
            uid = muser.uid,
            wincoinshow = math.round_coin(muser.settlewin * deskInfo.bet)
        })
    end
    deskInfo:broadcastViewer(cjson.encode(retobj))
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        if isMaintain() then
            local notify_retobj = { c=PDEFINE.NOTIFY.GAME_DISMISS_ROOM, code = PDEFINE.RET.SUCCESS, deskid=deskInfo.deskid }
            skynet.timeout(10, function()
                deskInfo:broadcast(cjson.encode(notify_retobj))
            end)
            deskInfo:destroy()
        else
            skynet.timeout(30, function()
                deskInfo:resetDesk(DelayTime)  -- 前端需要播放结算动画，耗时比较长
            end)
        end
    else
        local maintain = isMaintain()
        if maintain or isDismiss then
            local notify_retobj = { c= maintain and PDEFINE.NOTIFY.NOTIFY_SYS_KICK or PDEFINE.NOTIFY.GAME_DISMISS_ROOM, code = PDEFINE.RET.SUCCESS, deskid=deskInfo.deskid }
            skynet.timeout(10, function()
                deskInfo:broadcast(cjson.encode(notify_retobj))
                if isDismiss then
                    deskInfo:destroy(true)
                else
                    deskInfo:destroy()
                end
            end)
        else
            deskInfo:updateState(PDEFINE.DESK_STATE.READY, false)
            skynet.timeout(30, function()
                deskInfo:resetDesk(DelayTime)
            end)
        end
    end

    if stgy:isValid() then
        stgy:update(playertotalbet, playertotalwin)
    end

    return PDEFINE.RET.SUCCESS
end

local function userCanAppend(user)
    if #deskInfo.round.connect == 0 then --第一个出牌
        return true
    end
    for _, item in pairs(user.round.cards) do
        if #deskInfo.round.connect>0 and (item.u == deskInfo.round.connect[1] or item.u == deskInfo.round.connect[2] 
            or item.l == deskInfo.round.connect[1] or item.l == deskInfo.round.connect[2]) then
            return true
        end
    end
    return false
end

-------- 设定玩家定时器 --------
function CMD.userSetAutoState(type,autoTime,uid,extraTime)
    autoTime = autoTime + 1

    LOG_DEBUG("设定玩家定时器:", type, " uid:", uid)
    -- 调试期间，机器人只间隔2秒操作
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    if not user then
        return
    end
    deskInfo.round.expireTime = os.time() + autoTime
    user:clearTimer()
    if not user.cluster_info then
        autoTime = math.random(20, 50) / 10
    end
    if type ~= "autoReady" and user.auto == 1 then
        autoTime = 2
    end

    if extraTime then
        autoTime = autoTime + extraTime
    end

    --TODO: 真实环境要去掉
    if user.cluster_info and user.isexit == 0 then
        -- if userCanAppend(user) then
        --     autoTime = 1000000 --真人能接起牌的时候，倒计时时间延长，如果接不起，就直接pass
        -- else
        --     autoTime = 0
        -- end
        -- LOG_DEBUG("下一个自动出牌的人：", user.uid, ' autoTime:', autoTime)
    end
    -- 自动出牌
    if type == "autoDiscard" then
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

-- 过牌(定时器自动触发)
function CMD.pass(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.isOver = 0
    retobj.spcode = 0
    local user = deskInfo:findUserByUid(uid)
    LOG_DEBUG("cmd.pass 用户 pass:", uid, ' 用户个数:', #deskInfo.users, ' pass个数:', #deskInfo.round.passSeatid)
    local preUser
    if #deskInfo.round.passSeatid == 0 then
        preUser = baseUtil.FindPrevUser(user.seatid, deskInfo)
    else
        local firstPassUser = deskInfo:findUserBySeatid(deskInfo.round.passSeatid[1])
        preUser = baseUtil.FindPrevUser(firstPassUser.seatid, deskInfo)
    end
    for _, dot in pairs(deskInfo.round.connect) do
        if not table.contain(user.round.passCard, dot) then
            table.insert(user.round.passCard, dot)
        end
    end
    table.insert(deskInfo.round.passSeatid, user.seatid)

    if #deskInfo.round.passSeatid ~= #deskInfo.users then
        --下一家出牌
        local nextUser = deskInfo:findNextUser(user.seatid)
        deskInfo.round.activeSeat = nextUser.seatid
        user.state = PDEFINE.PLAYER_STATE.Wait
        nextUser.state = PDEFINE.PLAYER_STATE.Discard

        retobj.nextUid = nextUser.uid
        retobj.nextState = nextUser.state
        local timeout = deskInfo.delayTime
        if not userCanAppend(nextUser) then
            timeout = 0
        end
        retobj.delayTime = timeout
        CMD.userSetAutoState('autoDiscard', timeout, nextUser.uid, 1)

        local deductCoin = deskInfo.bet

        user.settlewin = user.settlewin - 1
        user.round.deductcoin = user.round.deductcoin + deductCoin
        if user.cluster_info then
            user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -deductCoin, deskInfo)
        else
            user.coin = user.coin - deductCoin --扣pass的金币
        end
        retobj.usercoin = user.coin
        retobj.passCard = user.round.passCard

        --第1家pass的上家
        local addcoin = deskInfo.bet
        local leagueInfo = player_tool.getLeagueInfo(deskInfo.conf.roomtype, preUser.uid)
        if leagueInfo.isSign == 1 then
            -- addcoin = addcoin * 2
            -- preUser.settlewin = preUser.settlewin + 1
        end
        preUser.settlewin = preUser.settlewin + 1
        preUser.round.addcoin = preUser.round.addcoin + addcoin
        if preUser.race_id > 0 and preUser.race_type == PDEFINE.RACE_TYPE.DOMINO_WIN_COUNT then
            pcall(cluster.send, "master", ".raceroommgr", "addRaceScore", preUser.uid, preUser.race_id, 1)
        end
        if preUser.cluster_info then
            preUser:changeCoin(PDEFINE.ALTERCOINTAG.WIN, addcoin, deskInfo)
        else
            preUser.coin = preUser.coin + addcoin
        end
        retobj.isOver = 0
        
        retobj.receive = { --接收金币的人
            uid = preUser.uid,
            seatid = preUser.seatid,
            coin = preUser.coin,
        }

        for _, _user in pairs(deskInfo.users) do
            local bet = deskInfo.bet
            retobj.coin = bet --飞的金币数
            if recvobj.ia_auto and user.uid == _user.uid then
                retobj.is_auto = 1
            else
                retobj.is_auto = nil
            end
    
            retobj.wincoins = {}
            for _, muser in pairs(deskInfo.users) do
                if muser.uid == uid then
                    table.insert(retobj.wincoins, {
                        uid = muser.uid,
                        wincoinshow = math.round_coin(muser.settlewin*bet)
                    })
                elseif muser.uid == preUser.uid then
                    table.insert(retobj.wincoins, {
                        uid = muser.uid,
                        wincoinshow = math.round_coin(muser.settlewin*bet)
                    })
                end
            end
            _user:sendMsg(cjson.encode(retobj))
        end
        -- 也需要单独发送给观看人
        for _, viewer in ipairs(deskInfo.views) do
            local bet = deskInfo.bet
            retobj.coin = bet --飞的金币数
            retobj.wincoins = {}
            for _, muser in pairs(deskInfo.users) do
                if muser.uid == uid then
                    table.insert(retobj.wincoins, {
                        uid = muser.uid,
                        wincoinshow = math.round_coin(muser.settlewin*bet)
                    })
                elseif muser.uid == preUser.uid then
                    table.insert(retobj.wincoins, {
                        uid = muser.uid,
                        wincoinshow = math.round_coin(muser.settlewin*bet)
                    })
                end
            end
            viewer:sendMsg(cjson.encode(retobj))
        end
    else
        --所有玩家都pass，就流局结算
        deskInfo.round.winuid = uid
        LOG_DEBUG("pass人数等于用户数，直接over, users:", #deskInfo.users, ' pass users:', deskInfo.round.passSeatid)
        skynet.timeout(200, function()
            agent:roundOver()
        end)
        return
    end
    return warpResp(retobj)
end

-- 用户出牌
function CMD.discard(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local cardid = math.floor(recvobj.cardid)
    local append = math.floor(recvobj.append or 0)
    local isauto = msg.isauto or false --是否自动出牌
    local card = getCard(cardid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    -- 检测参数
    if not card then
        retobj.spcode = PDEFINE.RET.ERROR.PARAMS_ERROR
        return warpResp(retobj)
    end

    LOG_DEBUG("用户出牌: user:", uid, " card", card.l..card.u)
    retobj.card = card

    -- 检测用户
    local user = deskInfo:findUserByUid(uid)
    local ok
    ok, retobj = checkUserAndState(user, PDEFINE.PLAYER_STATE.Discard, retobj)
    if not ok then
        return warpResp(retobj)
    end

    local initCon = false
    local calAppend = 0
    if #deskInfo.round.roundCards > 0 then
        if card.u == deskInfo.round.connect[1] or card.l == deskInfo.round.connect[1] then
            calAppend = 1 --可以接到左边
        end
        if card.u == deskInfo.round.connect[2] or card.l == deskInfo.round.connect[2] then
            if calAppend > 0 then
                calAppend = 3 --两头都能接
            else
                calAppend = 2 --只能接到右边
            end
        end
        
        if calAppend == 0 then
            retobj.spcode = config.Spcode.CanNotConnect --不能接
            return warpResp(retobj)
        end
    else
        deskInfo.round.firstCardId = cardid --记录首牌(牌桌上最中间的牌)
        deskInfo.round.connect[1] = card.l --第1张牌，小的在前面
        deskInfo.round.connect[2] = card.u
        LOG_DEBUG("init deskInfo.round.connect:", table.concat(deskInfo.round.connect, ","))
        initCon = true
    end

    if append ~= calAppend then --只能接1头的话，以服务端为准
        if calAppend == 3 then
            if append ~= 1 and append ~= 2 then
                append = 1
                if math.random(1, 1000) < 500 then
                    append = 2
                end
            end
        else
            append = calAppend
        end
    end

    -- 扣除手牌
    local finalCards = baseUtil.RemoveDominoCard(user.round.cards, card)
    if not finalCards then
        retobj.spcode = PDEFINE.RET.ERROR.HAND_CARDS_ERROR
        return warpResp(retobj)
    end
    user.round.cards = finalCards

    -- 清除计时器
    user:clearTimer()
    user.round.lastCard = card

    if append == 1 then --接到左边
        table.insert(deskInfo.round.roundCards, 1, card)
    elseif append ==2 then --接到右边
        table.insert(deskInfo.round.roundCards, card)
    else --随意接
        if math.random(1, 1000) < 500 then
            table.insert(deskInfo.round.roundCards, 1, card)
            append = 1
        else
            table.insert(deskInfo.round.roundCards, card)
            append = 2
        end
    end
    if not initCon then
        local points = {card.u, card.l}
        LOG_DEBUG("deskInfo.round.connect  左边:", deskInfo.round.connect[1], " 右边:" .. deskInfo.round.connect[2],  ' points:', points[1], points[2] , " append:", append)
        for _, v in pairs(points) do
            if v ~= deskInfo.round.connect[append] then
                deskInfo.round.connect[append] = v --设置接上的这头待接的点数
                LOG_DEBUG("set deskInfo.round.connect[".. append .."]:", v)
                break
            end
        end
    end
    retobj.connect = deskInfo.round.connect
    retobj.roundCards = deskInfo.round.roundCards
    deskInfo.round.passSeatid = {}

    -- 如果手牌空了，就意味着赢了，要结算
    local isOver = 0
    user.state = PDEFINE.PLAYER_STATE.Wait
    if #user.round.cards == 0 then
        LOG_DEBUG("手牌空了，要结算了:", user.uid)
        isOver = 1
        retobj.nextUid = 0
        retobj.nextState = 0
        retobj.delayTime = deskInfo.delayTime
        retobj.winSeatid = user.seatid
        deskInfo.round.winuid = user.uid
    else
        -- 如果当轮没结束
        ---@type BaseUser
        local nextUser = deskInfo:findNextUser(user.seatid)
        deskInfo.round.activeSeat = nextUser.seatid
        nextUser.state = PDEFINE.PLAYER_STATE.Discard

        retobj.nextUid = nextUser.uid
        retobj.nextState = nextUser.state
        local timeout = deskInfo.delayTime
        if not userCanAppend(nextUser) then
            timeout = 0
        end
        retobj.delayTime = timeout
        CMD.userSetAutoState('autoDiscard', timeout, nextUser.uid)
    end
        
    retobj.isOver = isOver
    retobj.cnt = #user.round.cards -- 用户剩余手牌
    retobj.firstCardId = deskInfo.round.firstCardId --第一次出的牌
    retobj.append = append --接牌方向 1：左边 2：右边

    -- 广播给房间里的所有人
    local notify_object = {}
    notify_object.c  = PDEFINE.NOTIFY.PLAYER_DISCARD
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.seat = user.seatid
    notify_object.uid    = uid
    notify_object.card   = card
    notify_object.nextUid  = retobj.nextUid
    notify_object.nextState  = retobj.nextState
    notify_object.delayTime = retobj.delayTime
    notify_object.winSeatid = retobj.winSeatid
    notify_object.roundCards = retobj.roundCards
    notify_object.connect = retobj.connect
    if not isauto then
        notify_object.fight = 1 --主动打牌的标识
    end
    notify_object.isOver = isOver
    notify_object.cnt = #user.round.cards -- 用户剩余手牌
    notify_object.firstCardId = deskInfo.round.firstCardId --第一次出的牌
    notify_object.append = append --接牌方向 1：左边 2：右边
    deskInfo:broadcast(cjson.encode(notify_object))

    if isOver == 1 then
        skynet.timeout(300, function()
            agent:roundOver()
        end)
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
    local uid = math.floor(recvobj.uid)
    local user = deskInfo:findUserByUid(uid)

    local retobj = {c = recvobj.cmd, code= PDEFINE.RET.SUCCESS, spcode=0}
    if not user then
        return warpResp(retobj)
    end
    if user.auto == 0 then
        return warpResp(retobj)
    end
    
    user:clearTimer()
    user.auto = 0 --关闭自动

    -- 根据状态，重新开启计时器
    if user.state == PDEFINE.PLAYER_STATE.Discard then
        local timeout = deskInfo.delayTime
        if not userCanAppend(user) then
            timeout = 0
        end
        retobj.delayTime = timeout
        CMD.userSetAutoState('autoDiscard', timeout, uid)
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
    if not deskInfoStr then
        return
    end
    deskInfoStr.round.roundCards = deskInfo.round.roundCards
    deskInfoStr.round.firstCardId = deskInfo.round.firstCardId
    deskInfoStr.round.connect = deskInfo.round.connect
    local userInfo = deskInfo:findUserByUid(msg.uid)
    local bet = deskInfo.bet
    for _, user in pairs(deskInfoStr.users) do
        user.wincoinshow = math.round_coin(user.settlewin * bet)
    end
    -- 断线重连把用户的手牌高点从大到小排列
    if userInfo and userInfo.round then
        table.sort(userInfo.round.cards, function (a, b)
            if a.u ~= b.u then
                return a.u < b.u
            end
            if a.l ~= b.l then
                return a.l < b.l
            end
            return false
        end)
    end
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
        assignSeat = assignSeat,
    }
    deskInfo.round.roundCards = {}
    deskInfo.round.firstCardId = 0
    deskInfo.round.connect = {}
    deskInfo.seatList = {1, 3, 2, 4}
    if msg.conf then
        msg.conf.seat = 4
    end
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

    if msg.sid then
        stgy:load(msg.sid, gameid)
    end

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
        deskInfo:syncChatItem()
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

-- 观战坐下
function CMD.seatDown(source, msg)
    return agent:seatDown(msg)
end

--! 语聊的按钮
function CMD.chatIcon(source, msg)
    agent:actChatIcon(msg)
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
    local deskInfoStr = deskInfo:toResponse()
    return deskInfoStr
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