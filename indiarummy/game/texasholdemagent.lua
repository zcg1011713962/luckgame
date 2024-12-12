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
local algo = require "texas.algo"
local bot = require "texas.bot"
local BetStgy = require "betgame.betstgy"
local cs = queue()
local GAME_NAME = skynet.getenv("gamename") or "game"
local DEBUG = skynet.getenv("DEBUG")
local CMD = {}
local closeServer = false

local PRECISION = 0.000001  --精度误差

math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 7)))

--[[
    规则: 
    1. All In: 将所有金币都加入赌注
    2. Rush: 连续两轮获得底注，其他人都未跟
    3. Small Blind: 小盲 庄家的下家
    4. Big Blind: 大盲 庄家的下下家
    5. Raise: 加注
    6. call: 跟注
    7. fold: 弃牌

    大盲下家开始叫牌, 选择跟注或者加注
    如果跟注，则小盲之后，就会发三张公共牌
    如果加注，则新的一轮选择开始，知道大家都选择跟注，才会发三张公共牌
    后面两张牌，依次根据这个顺序来放出，所有牌都放出来之后，大家比牌结束
]]

---@type BetStgy
local stgy = BetStgy.new()

--控制参数
--参数值一般规则：为1时保持平衡；大于1时玩家buff；小于1时玩家debuff
local ControlParams = { --控制参数，
    robot_check_win_prob = 1,    --机器人看牌的反向概率
    robot_lose_total_mult = 100,     --机器人输最大总倍数
    robot_lose_total_coin = 5000,   --机器人输最大金币数
}

---@type BaseDeskInfo @instance of tarneeb
local deskInfo = nil  -- 桌子信息
---@type BaseAgent
local agent = nil  -- 游戏实例
local biddingAddTime =2
local discardTime = 3 -- 发牌动画时间
local lastDealerSeatid = nil  -- 最后做庄家的位置
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
    -- 最大牌值 A 0x0E
    MaxValue = 14,
    -- 托管和自动操作之间的延迟时间
    AutoDelayTime = 50,
    -- 牌型
    CardType = {
        None = 1,  -- 散牌
        Pair = 2, -- 对子
        Color = 3, -- 同花
        Sequence = 4, -- 顺子
        StraightFlush = 5,  -- 同花顺
        Trail = 6,  -- 3张相同的牌
    },
    SettleType = {
        Flow = 1,  -- 流程结束比牌
        Live = 2,  -- 剩下一人结算
    },
    LoseBetWeight = {  -- 输牌情况下跟牌的次数
        [1] = 0.5,
        [2] = 0.4,
        [3] = 0.3,
        [4] = 0.2,
        [5] = 0.1,
    },
    DelayTime = {
        CollectCoinTime = 2,  -- 前端收集筹码的时间
        MiddleDealCard = 2,  -- 中途发牌的延迟时间
        LastCardDelayTime = 5 -- 最后一张牌增加思考时间
    }
}

-- 逻辑方法
local logic = {}

-- 成功返回
local function warpResp(retobj)
    return PDEFINE.RET.SUCCESS, retobj
end

--获取控制系数
local function getControlParam(key)
    local param = ControlParams[key]
    assert(param, "param "..key.." is null")
    local rtp = 100
    if stgy:isValid() then
        rtp = stgy.rtp
    end
    local p = param * (rtp / 100)
    return p
end

-- 检测用户，和检测状态
logic.checkUserAndState = function (user, state, retobj)
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

-- 找出当前还未弃牌的用户
logic.findLiveUser = function ()
    local users = {}
    for _, u in ipairs(deskInfo.users) do
        if u.round.folded == 0 then
            table.insert(users, u)
        end
    end
    return users
end

-- 判断此轮下注是否结束
logic.checkRoundClose = function (user)
    local cnt = deskInfo.seat
    local isClose = true
    -- 先判断剩下几个活人，如果只有一个活人，则算close
    local liveUsers = logic.findLiveUser()
    if #liveUsers > 1 then
        local seatId = user.seatid
        for i = 1, deskInfo.seat - 1 do
            seatId = seatId + 1
            if seatId > deskInfo.seat then seatId = 1 end
            if seatId == deskInfo.round.startSeat then
                isClose = true
                break
            end
            local nextUser = deskInfo:findUserBySeatid(seatId)
            if nextUser and nextUser.round.folded == 0 and nextUser.round.allin == 0 then
                isClose = false
                break
            end
        end
    end
    -- 如果只有一个人存活了，则也是close
    if #logic.findLiveUser() == 1 then
        isClose = true
    end
    if isClose then
        -- 一轮结束后，则所有金币都加入到桌子池中，清空当轮下注
        for _, u in ipairs(deskInfo.users) do
            deskInfo.round.betCoin = deskInfo.round.betCoin + u.round.currBet
            u.round.currBet = 0
            if u.round.action ~= bot.ActionType.Fold then
                u.round.action = 0
            end
        end
        deskInfo.round.currBet = 0
    end
    return isClose
end

-- 判断机器人是否会赢
logic.checkWin = function (user, oneself)
    local pubCards = table.copy(deskInfo.round.showCards)
    -- 如果数量不够5，则从牌堆中拿出剩下的
    if #pubCards < 5 then
        for i = 1, 5 - #pubCards, 1 do
            table.insert(pubCards, deskInfo.round.cards[#deskInfo.round.cards+1-i])
        end
    end
    -- 查看每个人的赢取权重
    local result = logic.getFinalResult(pubCards)
    local selfWeight = result[user.uid].weight
    for _, u in ipairs(deskInfo.users) do
        if u.uid ~= user.uid and result[u.uid] and result[u.uid].weight > selfWeight then
            if oneself then
                return false
            else
                if u.cluster_info then
                    return false
                end
            end
        end
    end
    return true
end

-- 找出下一个活着的人
logic.findNextLiveUser = function (seatid)
    local cnt = deskInfo.seat
    while cnt > 0 do
        cnt = cnt - 1
        local nextUser = deskInfo:findNextUser(seatid)
        -- 已经allin了，就不需要操作了
        if nextUser.round.folded == 0 and nextUser.round.allin == 0 then
            return nextUser
        end
        seatid = nextUser.seatid
    end
    return nil
end

-- 找出上一个活着的人
logic.findPrevLiveUser = function (seatid)
    local cnt = deskInfo.seat
    while cnt > 0 do
        cnt = cnt - 1
        local prevUser = deskInfo:findPrevUser(seatid)
        if prevUser.round.folded == 0 then
            return prevUser
        end
        seatid = prevUser.seatid
    end
    return nil
end

-- 找到第一个叫牌的人
logic.findFirstUser = function ()
    if #deskInfo.round.cards == 0 then
        -- 找大盲的下家(枪手位置)
        local bBlindUser = deskInfo:findUserByUid(deskInfo.round.bBlind)
        return logic.findNextLiveUser(bBlindUser.seatid)
    else
        -- 其他情况下发牌，都是固定小盲开始叫牌，如果小盲弃牌了，则找下一家
        local sBlindUser = deskInfo:findUserBySeatid(deskInfo.round.sBlindSeat)
        if not sBlindUser or sBlindUser.round.folded == 1 or sBlindUser.round.allin == 1 then
            return logic.findNextLiveUser(deskInfo.round.sBlindSeat)
        else
            return sBlindUser
        end
    end
end

-- 广播下一个操作人
logic.broadcastNextUser = function (user)
    local extra = {
        currBet=deskInfo.round.currBet,
        userBet=user.round.currBet,
        canCheck=0,
        betCoin=deskInfo.round.betCoin
    }
    -- for _, u in ipairs(deskInfo.users) do
    --     extra.betCoin = extra.betCoin + u.round.currBet
    -- end
    extra.canCheck = logic.canCheck(user)
    local delayTime = deskInfo.delayTime
    -- 最后一张牌，给大家多几秒的思考时间
    if #deskInfo.round.showCards == 5 then
        delayTime = delayTime + config.DelayTime.LastCardDelayTime
    end
    if user.auto == 1 then
        delayTime = 0
    end
    -- 要告知前端需要显示的按钮
    deskInfo:broadcastNextUser(user, delayTime, extra)
end

-- 将所有人的牌拿出来，获取最终权重
logic.getFinalResult = function (showCards)
    local result = {}
    for _, u in ipairs(deskInfo.users) do
        if u.round.folded == 0 then
            local cards = table.copy(showCards)
            for _, c in ipairs(u.round.cards) do
                table.insert(cards, c)
            end
            local ctype, finalCards = algo.Check(cards)
            local item = {uid=u.uid, ctype=ctype, cards=finalCards, weight=ctype*0x1000000}
            local len = #item.cards
            for idx = 1, len, 1 do
                local card = item.cards[idx]
                -- 按位算最大值
                item.weight = item.weight + baseUtil.ScanValue(card) * (1 << (4*(len-idx)))
            end
            result[u.uid] = item
        end
    end
    return result
end

-- 是否可以check
logic.canCheck = function(user)
    -- local prevUser = logic.findPrevLiveUser(user.seatid)
    -- 如果此轮下注金额和上家不一样，则不能check
    if deskInfo.round.currBet ~= user.round.currBet then
        return false
    end
    return true
end

-- 清理掉用户身上此轮的下注额
logic.cleanCurrBet = function()
    for _, u in ipairs(deskInfo.users) do
        u.round.currBet = 0
    end
end

-- 返回指定金额需要下注的钱, 
logic.getRaiseCoin = function(user, coin)
    -- 如果加注的金额大于目前桌子所需要的金额，则使用该金额，否则只加注到桌子金额
    local needCoin = 0
    if deskInfo.round.currBet < coin then
        needCoin = coin - user.round.currBet
    else
        needCoin = deskInfo.round.currBet - user.round.currBet
    end
    return needCoin
end

-- 获取当前是否可以跟注
-- 原则是赔率比需要小于成牌概率比，才会跟注
logic.getBestAction = function(user)
    local level = bot.getHandLevel(user.round.cards)
    LOG_DEBUG("getBestAction: cards:", user.round.cards, " level: ", level, " deskInfo.bet:", deskInfo.bet, " currBet:", deskInfo.round.currBet)
    local coin = 0
    -- 如果还未翻牌，则只需要判断手牌
    if #deskInfo.round.showCards == 0 then
        if level > 2 and bot.isSomeOneAllIn(deskInfo) then
            -- 如果已经有人allin,则不跟注
            local mult = 10
            if level == 3 and math.random() < 0.8 then  --增加随机性
                mult = 15
            end
            if deskInfo.round.currBet > deskInfo.bet * mult then
                return bot.ActionType.Fold, 0
            end
        end
        -- 如果还没有发牌，则直接判断手牌的牌力等级，进行押注
        if level == 1 then
            -- 适当加注跟注
            if deskInfo.round.currBet < deskInfo.bet*8 and math.random() < 0.5 then --增加随机性
                coin = logic.getRaiseCoin(user,deskInfo.bet*math.random(1,2))
                return bot.ActionType.Raise, coin
            else
                coin = deskInfo.round.currBet - user.round.currBet
                return bot.ActionType.Call, coin
            end
        elseif level == 2 then
            -- 适当加注跟注
            if deskInfo.round.currBet < deskInfo.bet*6 and math.random() < 0.5 then --增加随机性
                coin = logic.getRaiseCoin(user,deskInfo.bet*math.random(1,2))
                return bot.ActionType.Raise, coin
            else
                coin = deskInfo.round.currBet - user.round.currBet
                return bot.ActionType.Call, coin
            end
        elseif level == 3 then
            -- 第二种牌力，可以适当加注，吓跑一般人
            if deskInfo.round.currBet < deskInfo.bet*4 and math.random() < 0.8 then --增加随机性
                coin = logic.getRaiseCoin(user,deskInfo.bet*math.random(1,3))
                return bot.ActionType.Raise, coin
            else
                coin = deskInfo.round.currBet - user.round.currBet
                return bot.ActionType.Call, coin
            end
        elseif level == 4 then
            -- 跟注，适当加注
            if deskInfo.round.currBet < deskInfo.bet*3 and math.random() < 0.7 then --增加随机性
                coin = logic.getRaiseCoin(user,deskInfo.bet*math.random(1,2))
                return bot.ActionType.Raise, coin
            else
                coin = deskInfo.round.currBet - user.round.currBet
                return bot.ActionType.Call, coin
            end
        elseif level == 5 then
            -- 没有4BB的情况下，跟注
            if deskInfo.round.currBet <= deskInfo.bet*3 then
                coin = deskInfo.round.currBet - user.round.currBet
                return bot.ActionType.Call, coin
            end
            return bot.ActionType.Fold, 0
        elseif level == 6 then
            -- 没有3BB的情况下，跟注, 否则弃牌
            if deskInfo.round.currBet <= deskInfo.bet*2 then
                coin = deskInfo.round.currBet - user.round.currBet
                return bot.ActionType.Call, coin
            end
            return bot.ActionType.Fold, 0
        elseif level == 7 then
            if deskInfo.round.currBet <= deskInfo.bet*2 and math.random()<0.7 then
                coin = deskInfo.round.currBet - user.round.currBet
                return bot.ActionType.Call, coin
            end
            return bot.ActionType.Fold, 0
        else
            -- 如果有一个K，则跟注
            for _, c in ipairs(user.round.cards) do
                if algo.ScanValue(c) > 12 then
                    if deskInfo.round.currBet <= deskInfo.bet*2 and math.random()<0.6 then
                        coin = deskInfo.round.currBet - user.round.currBet
                        return bot.ActionType.Call, coin
                    end
                end
            end
            return bot.ActionType.Fold, 0
        end
    elseif #deskInfo.round.showCards == 5 then --已发完所有公牌，直接看最后牌型
        local cards = table.copy(user.round.cards)
        for _, c in ipairs(deskInfo.round.showCards) do
            table.insert(cards, c)
        end
        local cardType = algo.Check(cards)
        if cardType >= algo.Level.StraightFlush then
            coin = logic.getRaiseCoin(user, user.coin)
            return bot.ActionType.Raise, coin
        elseif cardType >= algo.Level.Straight then
            coin = logic.getRaiseCoin(user, deskInfo.bet*math.random(60,100))
            return bot.ActionType.Raise, coin
        elseif cardType >= algo.Level.TwoPair then
            if deskInfo.round.currBet < user.round.currBet * 10 or deskInfo.round.currBet < deskInfo.bet*20 or math.random() < 0.67 then
                coin = deskInfo.round.currBet - user.round.currBet
                return bot.ActionType.Call, coin
            end
        elseif cardType == algo.Level.OnePair then
            local prob = 0.5
            local liveUsers = logic.findLiveUser()
            if #liveUsers > 2 then prob = 0.25 end
            if deskInfo.round.currBet < deskInfo.bet * 16 or math.random() < prob then
                coin = deskInfo.round.currBet - user.round.currBet
                return bot.ActionType.Call, coin
            end
        end
        return bot.ActionType.Fold, 0
    else
        -- 这里使用的计算方法是，计算所有人期待的牌
        -- 如果不存在用户，则大家随意下注，反正最后比大小
        -- 如果存在用户，则判断期待牌数量大小，如果用户的少，则跟注，如果用户的多，且自己的是0则弃牌，如果自己的非0，则按照概率弃牌
        local probMap = {}
        local allZero = true
        local maxUser = nil
        local maxProb = nil
        for _, u in ipairs(deskInfo.users) do
            if u.round.folded == 0 then
                probMap[u.uid] = {
                    uid = u.uid,
                    is_robot = u.cluster_info and 0 or 1,
                    prob = bot.checkSuccessProb(deskInfo, u)
                }
                if probMap[u.uid].prob > 0 then
                    allZero = false
                end
            end
        end
        -- 判断自己是不是最小的
        for uid, info in pairs(probMap) do
            if not maxProb or maxProb < info.prob then
                maxProb = info.prob
                maxUser = info
            end
        end
        if allZero then
            coin = deskInfo.round.currBet - user.round.currBet
            return bot.ActionType.Call, coin
        end

        local foldProb = (maxUser.prob - probMap[user.uid].prob) / maxUser.prob
        -- 最佳用户是真人，则低调行事，按照差距比例来弃牌
        if maxUser.is_robot == 0 then
            if bot.isSomeOneAllIn(deskInfo) then
                -- 如果已经有人allin,则不跟注
                if deskInfo.round.currBet > deskInfo.bet * 10 and probMap[user.uid].prob < 0.15 and user.round.betCoin < deskInfo.bet * 10 then
                    return bot.ActionType.Fold, 0
                end
            end
            if math.random() < foldProb then
                return bot.ActionType.Fold, 0
            else
                if probMap[user.uid].prob > 0.2 then
                    coin = logic.getRaiseCoin(user, deskInfo.bet*math.floor(probMap[user.uid].prob*10))
                    return bot.ActionType.Raise, coin
                else
                    coin = deskInfo.round.currBet - user.round.currBet
                    return bot.ActionType.Call, coin
                end
            end
        end
        -- 最佳用户不是真人，且这个人是自己
        if maxUser.uid == user.uid then
            if probMap[user.uid].prob > 1 then
                coin = logic.getRaiseCoin(user,deskInfo.bet*math.random(8,16))
                return bot.ActionType.Raise, coin
            elseif math.random() < 0.4 and probMap[user.uid].prob > 0.5 then
                -- 一般情况加注2-4倍
                coin = logic.getRaiseCoin(user,deskInfo.bet*math.random(4,8))
                return bot.ActionType.Raise, coin
            else
                coin = deskInfo.round.currBet - user.round.currBet
                return bot.ActionType.Call, coin
            end
        else
            -- 最佳不是自己
            if math.random() < foldProb*0.5 then
                return bot.ActionType.Fold, 0
            elseif deskInfo.round.currBet < deskInfo.bet * 50 and probMap[user.uid].prob > 0.2 then
                coin = deskInfo.round.currBet - user.round.currBet
                return bot.ActionType.Call, coin
            end
        end
    end
    return bot.ActionType.Fold, 0
end

-- 获取所有池子信息
-- 按阶段来，下注额从小到大，分池子，弃牌的人放入主池里面
-- 计算下注的时候，需要去掉次轮还未结束的下注金币
-- 如果没有人allin，则不会出现边池
logic.getAllPots = function ()
    local pots = {}
    -- 不同底池的金币级别
    local potLevel = {}
    for _, u in ipairs(deskInfo.users) do
        if u.round.allin == 1 then
            if not table.contain(potLevel, u.round.betCoin) then
                table.insert(potLevel, u.round.betCoin)
            end
        end
    end
    -- 根据potLevel 中的金币等级，切分不同的池子
    if #potLevel == 0 then
        local mainPot = {coin=0, uids={}, main=1}
        for _, u in ipairs(deskInfo.users) do
            if u.round.folded == 0 then
                table.insert(mainPot.uids, u.uid)
            end
            mainPot.coin = mainPot.coin + u.round.betCoin - u.round.currBet
        end
        table.insert(pots, mainPot)
    else
        -- 排序
        table.sort(potLevel)
        -- 分阶级生成池
        for i = 1, #potLevel, 1 do
            local pot = {coin=0, uids={}, main=0}
            if i == 1 then
                pot.main = 1
            end
            for _, u in ipairs(deskInfo.users) do
                -- 已收集的金币
                local collectCoin = u.round.betCoin - u.round.currBet
                if u.round.folded == 0 then
                    -- 只要下注金额大于这个等级，则有权分享这个池子
                    if collectCoin >= potLevel[i] then
                        table.insert(pot.uids, u.uid)
                    end
                end
                -- 如果是第一个池子，则所有小于等于金币的都加入这个池子
                if i == 1 then
                    -- 大于池子等级，则只加入池子等级的金币
                    -- 否则都加入这个池子中(因为有些人当轮还未结束)
                    if collectCoin >= potLevel[i] then
                        pot.coin = pot.coin + potLevel[i]
                    else
                        pot.coin = pot.coin + collectCoin
                    end
                else
                    if collectCoin >= potLevel[i] then
                        pot.coin = pot.coin + potLevel[i] - potLevel[i-1]
                    elseif collectCoin >= potLevel[i-1] then
                        pot.coin = pot.coin + collectCoin - potLevel[i-1]
                    end
                end
            end
            table.insert(pots, pot)
            -- 最后一个池子，大于的钱都放入这个池子中, 如果只有一个池子，那就不用分第二个池子了
            if i == #potLevel then
                local lastPot = {coin=0, uids={}, main=0}
                for _, u in ipairs(deskInfo.users) do
                    -- 已收集的金币
                    local collectCoin = u.round.betCoin - u.round.currBet
                    if collectCoin > potLevel[i] then
                        if u.round.folded == 0 then
                            table.insert(lastPot.uids, u.uid)
                        end
                        lastPot.coin = lastPot.coin + collectCoin - potLevel[i]
                    end
                end
                if lastPot.coin > 0 then
                    table.insert(pots, lastPot)
                end
            end
        end
    end
    return pots
end

-- 记录用户德州扑克的数据
logic.recordToDB = function(user)
    ---@type TexasRecord
    local record = user.record
    if not record then
        return
    end
    local sql = string.format([[
        update `d_texas_record` set
            bet_coin=%0.2f, win_coin=%0.2f, play_cnt=%d, win_cnt=%d, allin_cnt=%d, 
            raise=%d, fold=%d, max_win=%0.2f, raise_preflop=%d, raise_flop=%d, raise_turn=%d, 
            raise_river=%d, update_time=%d
        where uid=%d;
    ]], record.bet_coin, record.win_coin, record.play_cnt, record.win_cnt, record.allin_cnt,
    record.raise, record.fold, record.max_win, record.raise_preflop, record.raise_flop, record.raise_turn,
    record.raise_river, os.time(), user.uid)
    LOG_DEBUG("recordToDB uid:", user.uid, " current sql:", sql)
    skynet.send(".mysqlpool", "lua", "execute", sql)
end

-- 返回用户当前牌组信息(牌型等)
logic.getCardInfo = function(user)
    local cards = table.copy(user.round.cards)
    if deskInfo.round.showCards then
        for _, c in ipairs(deskInfo.round.showCards) do
            table.insert(cards, c)
        end
    end
    local rtype, finalCards = algo.Check(cards)
    return {cardType=rtype, cards=finalCards}
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
    deskInfo.round.sBlind = nil  -- 小盲位置
    deskInfo.round.sBlindSeat = nil -- 小盲座位id,防止小盲退出去了
    deskInfo.round.bBlind = nil  -- 大盲位置
    deskInfo.round.bBlindSeat = nil -- 大盲座位id,防止大盲退出去了
    deskInfo.round.showCards = {}  -- 公示的牌
    deskInfo.round.baseCoin = deskInfo.bet  -- 基础下注额
    deskInfo.round.currBet = deskInfo.bet  -- 当前下注额
    deskInfo.round.betCoin = 0  -- 用户下注的所有金币
    deskInfo.round.startSeat = nil --此轮下注开始人，防止开始人退出去了
    deskInfo.round.pots = {}  -- 所有池子, 第一个池子固定为主池

    -- 随机堆上的牌
    deskInfo.round.cards = table.copy(config.Cards)
    shuffle(deskInfo.round.cards)
end

---@param user BaseUser
local function initUserRound(user)
    user.state       = PDEFINE.PLAYER_STATE.Wait
    user.round = {}
    user.round.folded     = 0  -- 是否弃牌
    user.round.betCoin    = 0  -- 此局下注的钱
    user.round.currBet    = 0  -- 此轮下注的钱，一轮结束后会清空这个值
    user.round.cards      = {} -- 手中的牌
    user.round.allin      = 0  -- 是否allin
    user.round.betCnt     = 1  -- 下注次数
    user.round.show       = 0  -- 弃牌后显示
    user.round.action     = 0  -- 最后一个操作类型(ActionType), 0是还没有操作
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
            -- 如果前一个玩家此轮下注和自己一样，则可以check, 否则只能弃牌
            -- local prevUser = logic.findPrevLiveUser(user.seatid)
            if deskInfo.round.currBet == user.round.currBet then
                local msg = {
                    ['c'] = 25742,
                    ['uid'] = uid,
                }
                local _, resp = CMD.check(nil, msg)
                deskInfo:print("自动check msg:", msg, "返回: ", resp)
            else
                local msg = {
                    ['c'] = 25740,
                    ['uid'] = uid,
                }
                local _, resp = CMD.pack(nil, msg)
                deskInfo:print("自动弃牌 msg:", msg, "返回: ", resp)
            end
        end)
    end)
end

-- 机器人自动操作
-- 1. 如果是首轮押注，
local function autoAiDecide(uid)
    return cs(function()
        deskInfo:print("自动操作 uid:".. uid)
        
        local user = deskInfo:findUserByUid(uid)
        user:clearTimer()
        if deskInfo.round.activeSeat ~= user.seatid then
            deskInfo:print("出牌对象错误: uid:", uid, ' seatid:', user.seatid, " activeSeat:", deskInfo.round.activeSeat)
            return
        end

        local checkwinprob = getControlParam("robot_check_win_prob")
        local action, coin = logic.getBestAction(user)
        if coin > 0 then  --阈值预防
            local totalBet = 0
            for _, u in ipairs(deskInfo.users) do
                if not u.cluster_info then
                    totalBet = totalBet + user.round.betCoin
                end
            end
            totalBet = totalBet + math.min(coin, user.coin)
            local maxtotalmult = getControlParam("robot_lose_total_mult")
            local maxtotalcoin = getControlParam("robot_lose_total_coin")
            if (totalBet > deskInfo.bet * maxtotalmult) or (totalBet > maxtotalcoin) or (math.random() > checkwinprob) then
                if not logic.checkWin(user) then
                    action = bot.ActionType.Fold
                    coin = 0
                    LOG_DEBUG("checkWin false, fold", user.uid, totalBet)
                end
            end
        else
            if math.random() > checkwinprob then
                if logic.checkWin(user, true) then
                    action = bot.ActionType.Call
                    coin = deskInfo.round.currBet - user.round.currBet
                    LOG_DEBUG("checkWin true, call", user.uid)
                end
            end
        end
        LOG_DEBUG("getBestAction: ", "action:", action, " coin:", coin)
        if action == bot.ActionType.Fold or action == bot.ActionType.Check then
            -- 如果可以check的情况下，直接check，不要fold
            if logic.canCheck(user) then
                local msg = {
                    c = 25742,
                    uid = uid,
                }
                local _, res = CMD.check(nil, msg)
                deskInfo:print("自动check msg:", msg, "返回: ", res)
                if res.spcode ~= 0 then
                    deskInfo:print("错误了, 弃牌:", uid)
                    CMD.pack(nil, {c=25740, uid=uid})
                end
            else
                local msg = {
                    c = 25740,
                    uid = uid,
                }
                local _, res = CMD.pack(nil, msg)
                deskInfo:print("自动弃牌 msg:", msg, "返回: ", res)
                if res.spcode ~= 0 then
                    deskInfo:print("错误了, 弃牌:", uid)
                    CMD.pack(nil, {c=25740, uid=uid})
                end
            end
        else
            local msg = {
                c = 25735,
                uid = uid,
                coin = coin,
                isall = 0,
            }
            if action == bot.ActionType.AllIn then
                msg.isall = 1
            end
            local _, resp = CMD.bet(nil, msg)
            deskInfo:print("自动押注 msg:", msg, "返回: ", resp)
            if resp.spcode ~= 0 then
                deskInfo:print("错误了, 弃牌:", uid)
                CMD.pack(nil, {c=25740, uid=uid})
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

local function user_set_timeout(ti, f,parme)
    local function t()
        if f then
            f(parme)
        end
    end
    skynet.timeout(ti, t)
    return function(parme) f=nil end
end


-- 开始发牌
local function roundStart(addTime)
    if not addTime then
        addTime = 1
    end
    local retobj = {}
    LOG_DEBUG("开始游戏: deskid:", deskInfo.uuid)
    -- 设置庄家的下一家为叫牌用户
    local dealer = deskInfo:findUserByUid(deskInfo.round.dealer['uid'])
    deskInfo.round.activeSeat = dealer.seatid
    deskInfo.curround = deskInfo.curround + 1
    -- 设置定时器
    retobj.c = PDEFINE.NOTIFY.GAME_DEAL
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.activeUid = nil
    retobj.dealerUid = dealer.uid

    -- 开始发牌
    retobj.cards = nil
    retobj.discardUids = {}  -- 发牌的人
    retobj.delayTime = deskInfo.delayTime
    retobj.sBlind = nil -- 小盲位置
    retobj.sBlindCoin = deskInfo.round.baseCoin / 2
    retobj.bBlind = nil -- 大盲位置
    retobj.bBlindCoin = deskInfo.round.baseCoin
    local currSeatid = dealer.seatid
    local bBlindUser = nil 
    for i = 1, #deskInfo.users, 1 do
        local currUser = logic.findNextLiveUser(currSeatid)
        table.insert(retobj.discardUids, currUser.uid)
        currSeatid = currUser.seatid
        currUser.state = PDEFINE.PLAYER_STATE.Wait
        if i == 1 then  -- 小盲
            retobj.sBlind = currUser.uid
            deskInfo.round.sBlind = retobj.sBlind
            deskInfo.round.sBlindSeat = currUser.seatid
            -- 扣去金币
            currUser:changeCoin(PDEFINE.ALTERCOINTAG.BET, -1*retobj.sBlindCoin, deskInfo)
            currUser.round.betCnt = currUser.round.betCnt + 1
            currUser.round.betCoin = retobj.sBlindCoin
            currUser.round.currBet = retobj.sBlindCoin
            currUser.round.action = bot.ActionType.SBlind
        elseif i == 2 then  -- 大盲
            retobj.bBlind = currUser.uid
            deskInfo.round.bBlind = retobj.bBlind
            deskInfo.round.bBlindSeat = currUser.seatid
            -- 扣去金币
            currUser:changeCoin(PDEFINE.ALTERCOINTAG.BET, -1*retobj.bBlindCoin, deskInfo)
            currUser.round.betCnt = currUser.round.betCnt + 1
            currUser.round.betCoin = retobj.bBlindCoin
            currUser.round.currBet = retobj.bBlindCoin
            currUser.round.action = bot.ActionType.BBlind
            bBlindUser = currUser
            if currUser.coin == 0 then
                currUser.round.isall = 1
                currUser.round.action = bot.ActionType.AllIn
            end
        end
    end
    -- 大盲的下家开始出牌
    local firstUser = logic.findNextLiveUser(bBlindUser.seatid)
    retobj.activeUid = firstUser.uid
    firstUser.state = PDEFINE.PLAYER_STATE.Bet
    deskInfo.round.activeSeat = firstUser.seatid
    -- 广播下一个操作人, 延迟3秒，用于前端发牌动画
    skynet.timeout(discardTime*100, function()
        logic.broadcastNextUser(firstUser)
    end)
    -- 刚开局，时间设置久一点
    if firstUser.cluster_info then
        CMD.userSetAutoState('autoPack', retobj.delayTime+discardTime, firstUser.uid, discardTime)
    else
        CMD.userSetAutoState('autoAiDecide', retobj.delayTime+discardTime, firstUser.uid, discardTime)
    end

    -- 次轮下注开始人是大盲, 到小盲结束
    deskInfo.round.startSeat = firstUser.seatid
    retobj.pots = logic.getAllPots()
    for _, user in pairs(deskInfo.users) do
        ---@type TexasRecord
        user.record.play_cnt = user.record.play_cnt + 1
        retobj.cards = {}
        -- 这里判断下是否是幸运用户，幸运用户的卡牌会好一点
        -- 好牌的规则是，出现A K 的概率比较的
        for i = 1, config.InitCardLen do
            table.insert(retobj.cards, table.remove(deskInfo.round.cards))
        end
        -- if DEBUG and user.seatid == 1 then
        --     retobj.cards = {0x1E,0x1E,0x1E,0x1E,0x1E,0x1E,0x1E,0x1E,0x1E,0x1E,0x1E,0x1E,0x1E}
        -- end
        user.round.cards = table.copy(retobj.cards)
        user.round.initcards = table.copy(retobj.cards)
        retobj.cardInfo = logic.getCardInfo(user)
        -- 广播消息
        if user.cluster_info and user.isexit == 0 then
            pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(retobj))
        end
    end
    retobj.cards = {}
    retobj.cardInfo = nil
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
local function gameOver(isDismiss, pots, rtype,reduceTime)
    ---@type Settle
    local settle = {
        uids = {},  -- uid
        league = {},  -- 排位经验
        coins = {}, -- 结算的金币
        betcoins = {},  --下注
        taxes = {}, --税收
        scores = {}, -- 获得的分数
        levelexps = {}, -- 经验值
        rps = {},  -- rp 值
        fcoins = {},  -- 最终的金币
    }
    for i = 1, deskInfo.seat do
        local u = deskInfo:findUserBySeatid(i)
        if u then
            table.insert(settle.uids, u.uid)
            table.insert(settle.betcoins, u.round.betCoin)
        else
            table.insert(settle.uids, 0)
            table.insert(settle.betcoins, 0)
        end
        table.insert(settle.league, 0)
        table.insert(settle.coins, 0)
        table.insert(settle.scores, 0)
        table.insert(settle.levelexps, 0)
        table.insert(settle.rps, 0)
        table.insert(settle.fcoins, 0)
    end
    local winners = {}

    for idx, pot in ipairs(pots) do
        if idx == 1 then
            winners = pot.win_uids
        end
        local coin = pot.coin / #pot.win_uids
        for _, uid in ipairs(pot.win_uids) do
            local u = deskInfo:findUserByUid(uid)
            settle.coins[u.seatid] = settle.coins[u.seatid] + coin
        end
    end

    for i, coin in ipairs(settle.coins) do
        local tax = 0
        if coin > settle.betcoins[i] then
            tax = math.round_coin((coin-settle.betcoins[i]) * deskInfo.taxrate)
        end
        settle.coins[i] = coin - tax
        settle.taxes[i] = tax
    end

    for _, uid in ipairs(winners) do
        local winUser = deskInfo:findUserByUid(uid)
        local winCoin = settle.coins[winUser.seatid]
        if winCoin > 0 then
            if winUser.record.max_win < winCoin then
                ---@type TexasRecord
                winUser.record.max_win = winCoin
            end
        end
    end
    for _, u in ipairs(deskInfo.users) do
        logic.recordToDB(u)
    end
    deskInfo:gameOver(settle, isDismiss, true, winners, nil, reduceTime)
end

-- 此轮游戏结束
--- @param rtype integer 结算类型 1.发起比牌结算, 2.剩下一个人结算
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
    retobj.allCards = {} -- 目前还存在的人
    retobj.userShow = {} -- 明示牌
    retobj.fcoins = {}  -- 最终的金币
    retobj.coins = {} -- 结算的金币
    retobj.taxes = {} --税收
    retobj.rtype = rtype  -- 结算类型
    retobj.showCards = deskInfo.round.showCards
    retobj.winners = {}  -- 主池赢的人

    for i = 1, deskInfo.seat do
        table.insert(retobj.coins, 0)
        table.insert(retobj.fcoins, 0)
    end

    local allCards = {}
    table.insert(allCards, {
        pubcards = deskInfo.round.showCards
    })
    for _, user in ipairs(deskInfo.users) do
        local usercards = {
            uid = user.uid,
            cards = user.round.initcards,
            folded = user.round.folded,
        }
        -- 只有比牌结束才需要公示牌
        if rtype == config.SettleType.Flow and user.round.folded == 0 then
            local tmpCards = table.copy(user.round.cards)
            for _, c in ipairs(deskInfo.round.showCards) do
                table.insert(tmpCards, c)
            end
            -- 如果牌都没有发全，则根本不需要比牌
            if #deskInfo.round.showCards ~= 5 then
                table.insert(retobj.allCards, {
                    uid=user.uid,
                    cards = user.round.cards,
                    bestCards = {},
                })
            else
                local cardType, bestCards = algo.Check(tmpCards)
                table.insert(retobj.allCards, {
                    uid=user.uid,
                    cards = user.round.cards,
                    cardType = cardType,
                    bestCards = bestCards,
                })
                usercards.ctype = cardType
            end
        end
        table.insert(allCards, usercards)
        -- 选择明示牌的人，需要将牌广播出去
        if user.round.show > 0 then
            local item = {
                uid=user.uid,
                cards = table.copy(user.round.cards),
            }
            if user.round.show == 1 then
                item.cards[2] = 0
            elseif user.round.show == 2 then
                item.cards[1] = 0
            end
            table.insert(retobj.userShow, item)
        end
    end

    -- 边池结算
    retobj.pots = logic.getAllPots()
    -- 方便前端结算播特效
    retobj.win_config = {}
    -- 如果有边池存在, 金币需要分几部分进行发放
    local winner = nil
    if #retobj.pots > 0 then
        -- 如果是弃牌赢
        if rtype == config.SettleType.Live then
            local win_pots = {}
            for idx, pot in ipairs(retobj.pots) do
                if idx == 1 then
                    winner = pot.uids[1]
                end
                pot.win_uids = {pot.uids[1]}
                table.insert(win_pots, idx)
            end
            retobj.win_config = {win_pots}
        else
            local finalResult = logic.getFinalResult(deskInfo.round.showCards)
            LOG_DEBUG("getFinalResult:", finalResult)
            local now_exist = {}   -- 已经存在的池子
            local win_config = {}  -- 存在池子对应的列表
            for idx, pot in ipairs(retobj.pots) do
                if idx == 1 then
                    winner = pot.uids[1]
                end
                local maxUids = {}
                local maxWeight = nil
                for _, uid in ipairs(pot.uids) do
                    local currWeight = finalResult[uid].weight
                    if not maxWeight or maxWeight < currWeight then
                        maxUids = {uid}
                        maxWeight = currWeight
                    elseif maxWeight == currWeight then
                        table.insert(maxUids, uid)
                    end
                end
                pot.win_uids = maxUids
                table.sort(maxUids)
                -- 如果win_uids是一样的就合并结算
                local combStr = table.concat(maxUids, "")
                local exist_idx  = table.findIdx(now_exist, combStr)
                if exist_idx == -1 then
                    table.insert(now_exist, combStr)
                    table.insert(win_config, {idx})
                else
                    table.insert(win_config[exist_idx], idx)
                end
            end
            retobj.win_config = win_config
        end
    end

    local settleCoins = {}

    for idx, pot in ipairs(retobj.pots) do
        if pot.main == 1 then
            retobj.winners = pot.win_uids
        end
        -- 抽水需要计算净输赢, 所以先计算总数
        local coin = pot.coin / #pot.win_uids
        for _, uid in ipairs(pot.win_uids) do
            if not settleCoins[uid] then
                settleCoins[uid] = coin
            else
                settleCoins[uid] = settleCoins[uid] + coin
            end
        end
    end

    -- 根据池子来分析
    local reduceTime = 1 - math.round(#retobj.win_config * 3.3)
    if rtype == config.SettleType.Live then
        reduceTime = 1
    end
    
    -- 将金币结算到用户身上
    for uid, coin in pairs(settleCoins) do
        local u = deskInfo:findUserByUid(uid)
        local tax = 0
        if coin > u.round.betCoin then
            tax = math.round_coin((coin-u.round.betCoin) * deskInfo.taxrate)
        end
        local finalCoin = coin - tax
        u:notifyLobby(finalCoin, u.uid, deskInfo.gameid)
        u:changeCoin(PDEFINE.ALTERCOINTAG.WIN, finalCoin, deskInfo)
        retobj.coins[u.seatid] = finalCoin
        retobj.taxes[u.seatid] = tax
    end

    for _, u in ipairs(deskInfo.users) do
        retobj.fcoins[u.seatid] = u.coin
    end

    -- 将观战玩家的也加上去
    for _, u in ipairs(deskInfo.views) do
        if u.seatid and u.seatid > 0 then
            retobj.fcoins[u.seatid] = u.coin
        end
    end

    if stgy:isValid() then
        local playertotalbet = 0
        local playertotalwin = 0
        for _, user in ipairs(deskInfo.users) do
            if user.cluster_info and user.istest ~= 1 then
                playertotalbet = playertotalbet + user.round.betCoin
                playertotalwin = playertotalwin + retobj.coins[user.seatid]
            end
        end
        stgy:update(playertotalbet, playertotalwin)
    end

    --结算小局记录
    local multiple = 1
    if not winner then
        winner = 1
    else
        local winnerUser = deskInfo:findUserByUid(winner)
        ---@type TexasRecord
        winnerUser.record = winnerUser.record
        winnerUser.record.win_cnt = winnerUser.record.win_cnt + 1
    end 
    deskInfo:recordDB(0, winner, retobj.settle, allCards, multiple)

    -- 清除用户身上的卡牌信息和公示牌信息
    for _, u in ipairs(deskInfo.users) do
        u.round.cards = {}
    end
    deskInfo.round.cards = {}
    deskInfo.round.showCards = {}

    -- 记录庄家
    lastDealerSeatid = deskInfo.round.dealer and deskInfo.round.dealer.seatid

    local notifyMsg = function ()
        -- 维护强行大结算
        if isMaintain() then
            agent:gameOver(true, retobj.pots, rtype, reduceTime)
        else
            agent:gameOver(false, retobj.pots, rtype, reduceTime)
        end
    end
    skynet.timeout(1, notifyMsg)

    deskInfo:broadcast(cjson.encode(retobj))
    
    return PDEFINE.RET.SUCCESS
end

-- 切换到新的一轮下注
-- 首次是大盲下家开始押注，以后都是小盲开始叫牌
local function enterNextTurn()
    -- 清理掉用户身上次轮的下注额
    logic.cleanCurrBet()
    local notify_object = {
        c = PDEFINE.NOTIFY.GAME_BOARD_DEAL,
        code = 200,
        spcode = 0,
        cards = {}
    }
    local user = logic.findFirstUser()
    if #deskInfo.round.showCards == 0 then
        -- 发三张
        for i = 1, 3, 1 do
            local card = table.remove(deskInfo.round.cards)
            table.insert(notify_object.cards, card)
        end
        notify_object.stage = 1
    else
        if #deskInfo.round.showCards == 3 then
            notify_object.stage = 2
        else
            notify_object.stage = 3
        end
        -- 发一张
        local card = table.remove(deskInfo.round.cards)
        table.insert(notify_object.cards, card)
    end
    -- 增加一个字段表示目前全部卡牌
    skynet.timeout(30, function()
        -- 放这里，防止重连信息不统一
        for _, c in ipairs(notify_object.cards) do
            table.insert(deskInfo.round.showCards, c)
        end
        notify_object.showCards = table.copy(deskInfo.round.showCards)
        -- 广播发牌
        if #deskInfo.round.showCards == 5 then
            for _, u in ipairs(deskInfo.users) do
                if u.cluster_info and u.isexit == 0 then
                    notify_object.cardInfo = logic.getCardInfo(u)
                    pcall(cluster.send, u.cluster_info.server, u.cluster_info.address, "sendToClient", cjson.encode(notify_object))
                end
            end
            notify_object.cardInfo = nil
            deskInfo:broadcastViewer(cjson.encode(notify_object))
        else
            -- 每个人显示的提示都不同
            for _, u in ipairs(deskInfo.users) do
                if u.cluster_info and u.isexit == 0 then
                    local tmp_cards = table.copy(notify_object.showCards)
                    for _, c in ipairs(u.round.cards) do
                        table.insert(tmp_cards, c)
                    end
                    notify_object.tip = algo.CheckExpectCards(tmp_cards)
                    notify_object.cardInfo = logic.getCardInfo(u)
                    pcall(cluster.send, u.cluster_info.server, u.cluster_info.address, "sendToClient", cjson.encode(notify_object))
                end
            end
            notify_object.tip = nil
            notify_object.cardInfo = nil
            deskInfo:broadcastViewer(cjson.encode(notify_object))
        end
        -- 如果大家都已经allin了，或者只剩下一个人没有allin了，则直接发牌
        if not user or logic.findNextLiveUser(user.seatid).uid == user.uid then
            if #deskInfo.round.showCards == 5 then
                skynet.timeout(30, function()
                    roundOver(config.SettleType.Flow)
                end)
            else
                -- 下一次发牌延迟1.5秒
                skynet.timeout(config.DelayTime.MiddleDealCard*100, function()
                    enterNextTurn()
                end)
            end
            return
        end
        -- 设置定时器
        deskInfo.round.activeSeat = user.seatid
        user.state = PDEFINE.PLAYER_STATE.Bet
        -- 新的一轮开始，设置开始uid
        deskInfo.round.startSeat = user.seatid
        skynet.timeout(100, function ()
            if user.cluster_info then
                CMD.userSetAutoState('autoPack', deskInfo.delayTime, user.uid)
            else
                CMD.userSetAutoState('autoAiDecide', deskInfo.delayTime, user.uid)
            end
            -- 广播下一个下注人
            logic.broadcastNextUser(user)
        end)
    end)
end

-------- 游戏接口 --------

-- agent退出
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

function CMD.userSetAutoState(type,autoTime,uid,extraTime)
    autoTime = autoTime + 1
    -- 最后一张牌，给大家多几秒的思考时间
    if #deskInfo.round.showCards == 5 then
        autoTime = autoTime + config.DelayTime.LastCardDelayTime
    end
    deskInfo.round.expireTime = os.time() + autoTime
    
    -- 调试期间，机器人只间隔2秒操作
    ---@type BaseUser
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
    if DEBUG and false and user.cluster_info and user.isexit == 0 then
        autoTime = 1000000
    end

    -- 机器人自动操作
    if type == "autoAiDecide" then
        user:setTimer(autoTime, autoAiDecide, uid)
    end
    -- 自动弃牌
    if type == "autoPack" then
        user:setTimer(autoTime, autoPack, uid)
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
    if user and user.round.folded == 1 then
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
-- 下注必须已整数倍的底注下注，或者All in
function CMD.bet(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local coin = tonumber(recvobj.coin or 0)  -- 下注数量
    coin = math.floor(coin * 100 + PRECISION)/100  --保留2位小数
    local isall = math.floor(recvobj.isall or 0) -- 是否all in, 0=非, 1=allin
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.uid = uid
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.spcode = 0

    LOG_DEBUG("用户下注: user:", uid, " coin:", coin)
    ---@type BaseUser
    local user = deskInfo:findUserByUid(uid)
    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return warpResp(retobj)
    end
    ---@type TexasRecord
    local texasRecord = user.record

    if deskInfo.round.activeSeat ~= user.seatid or user.state ~= PDEFINE.PLAYER_STATE.Bet then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end

    local rtype = bot.ActionType.Call
    if isall == 1 then
        rtype = bot.ActionType.AllIn
        coin = user.coin
    end


    -- 金币为0，则是check
    local isCheck = false
    if coin == 0 then
        isCheck = true
        -- 如果此轮下注金额和上家不一样，则不能check
        if deskInfo.round.currBet ~= user.round.currBet then
            retobj.spcode = PDEFINE.RET.ERROR.CAN_NOT_CHECK
            return warpResp(retobj)
        end
    end

    if coin < 0 then
        retobj.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return warpResp(retobj)
    end

    -- 金币不够下注额，则自动切换到all in
    if user.coin <= coin then
        isall = 1
        coin = user.coin
    end

    if isall ~= 1 and coin + user.round.currBet + PRECISION < deskInfo.round.currBet then
        retobj.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return warpResp(retobj)
    end

    retobj.isall = isall
    user:clearTimer()
    user.state = PDEFINE.PLAYER_STATE.Wait

    -- 如果是加注，则需要重新设置发起人，其他人需要答复加注
    -- 如果是跟注，就切换到下一个
    local nextStartUid = nil
    if coin + user.round.currBet > deskInfo.round.currBet then
        deskInfo.round.startSeat = user.seatid
        if deskInfo.round.currBet == 0 then
            rtype = bot.ActionType.ReCall
        elseif deskInfo.round.currBet == deskInfo.round.baseCoin 
        and user.uid == deskInfo.round.bBlind 
        and #deskInfo.round.showCards == 0 and coin == deskInfo.round.baseCoin then
            -- 大盲可以选择下注
            rtype = bot.ActionType.ReCall
        else
            rtype = bot.ActionType.Raise
        end
        LOG_DEBUG("user bet coin:", coin, "user.round.currBet:", user.round.currBet, " deskInfo.round.currBet:", deskInfo.round.currBet)
    elseif coin + user.round.currBet == deskInfo.round.currBet then
        rtype = bot.ActionType.Call
    end
    -- 只有下注大于当前下注额，才更新桌子的下注额
    -- 因为allin可以下少于当前下注额的
    if coin + user.round.currBet > deskInfo.round.currBet then
        deskInfo.round.currBet = coin + user.round.currBet
    end

    if isall == 1 then
        user.round.allin = 1
        rtype = bot.ActionType.AllIn
    end

    if isCheck then
        rtype = bot.ActionType.Check
    end

    retobj.coin = coin
    retobj.rtype = rtype
    user.round.action = rtype

    if rtype == bot.ActionType.Raise then
        texasRecord.raise = texasRecord.raise + 1
        local showCnt = #deskInfo.round.showCards
        if showCnt == 0 then
            texasRecord.raise_preflop = texasRecord.raise_preflop + 1
        elseif showCnt == 3 then
            texasRecord.raise_flop = texasRecord.raise_flop + 1
        elseif showCnt == 4 then
            texasRecord.raise_turn = texasRecord.raise_turn + 1
        elseif showCnt == 5 then
            texasRecord.raise_river = texasRecord.raise_river + 1
        end
    elseif rtype == bot.ActionType.AllIn then
        texasRecord.allin_cnt = texasRecord.allin_cnt + 1
    end

    -- 扣去金币, 只需要扣除差值
    user:changeCoin(PDEFINE.ALTERCOINTAG.BET, -1*coin, deskInfo)
    -- 下注次数
    user.round.betCnt = user.round.betCnt + 1
    -- 玩家总下注金额
    user.round.betCoin = user.round.betCoin + coin
    -- 玩家此轮下注金额
    user.round.currBet = user.round.currBet + coin
    -- 记录玩家信息
    texasRecord.bet_coin = texasRecord.bet_coin + coin

    -- 检测是否触发封顶
    retobj.isOver = 0

    -- 找到下一个人
    local nextUser = logic.findNextLiveUser(user.seatid)


    -- 广播给房间里的所有人
    local notify_object = {}
    if isCheck then
        notify_object.c  = PDEFINE.NOTIFY.PLAYER_CHECK
    else
        notify_object.c  = PDEFINE.NOTIFY.PLAYER_BET
        notify_object.coin = coin
        notify_object.isall = isall
    end
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.uid  = uid
    -- 返回当前牌面上，需要下注的金额数量
    notify_object.currBet = deskInfo.round.currBet
    -- 返回用户此轮的下注额
    notify_object.userBet = user.round.currBet
    -- 返回用户此次游戏中下注总额
    notify_object.betCoin = user.round.betCoin
    -- 返回用户身上的金币数
    notify_object.userCoin = user.coin
    -- 额外传一个值给前端
    notify_object.potCoin = deskInfo.round.betCoin
    for _, u in ipairs(deskInfo.users) do
        -- 给前端显示用
        notify_object.potCoin = notify_object.potCoin + u.round.currBet
    end
    -- 返回桌面金币数量
    local nowUsers = logic.findLiveUser()
    -- 是否结束
    notify_object.isOver = retobj.isOver
    -- 押注类型
    notify_object.rtype = rtype  -- 押注类型
    -- 检测此轮下注是否闭环，闭环内会进行金币汇总，累积到桌子池中
    local isClose = logic.checkRoundClose(user)
    notify_object.isClose = isClose and 1 or 0
    -- 如果有人allin, 则会触发边池, 前端也会显示出不同的池子
    retobj.pots = logic.getAllPots()
    -- 返回金币池子
    notify_object.pots = retobj.pots
    -- 检查是否所有人都allin了(其他人allin, 自己跟注也算allin)
    local nextLiveUser = logic.findNextLiveUser(user.seatid)
    if not nextLiveUser or nextLiveUser.uid == user.uid then
        notify_object.fullallin = 1
    else
        notify_object.fullallin = 0
    end
    -- 广播操作
    deskInfo:broadcast(cjson.encode(notify_object))

    -- 是否结算
    if retobj.isOver == 1 then
        -- 防止前端重连导致倒计时问题
        deskInfo.round.activeSeat = -1
        skynet.timeout(config.DelayTime.CollectCoinTime*100, function()
            roundOver(config.SettleType.Flow)
        end)
    else
        -- 如果下一个人次轮的下注额和自己一样，则次轮下注结束
        -- 1. 没有公共牌，则发三张公共牌
        -- 2. 如果有3张公共牌，但是还不到5张，则发一张公共牌
        -- 3. 如果已经有5张公共牌了，则开始比牌
        if isClose then
            if #deskInfo.round.showCards == 5 then
                retobj.isOver = 1
                -- 防止前端重连导致倒计时问题
                deskInfo.round.activeSeat = -1
                    -- 开始结算
                skynet.timeout(config.DelayTime.CollectCoinTime*100, function()
                    roundOver(config.SettleType.Flow)
                end)
            else
                -- 这里需要延迟下，前端还需要收取筹码
                skynet.timeout(config.DelayTime.CollectCoinTime*100, function ()
                    enterNextTurn()
                end)
            end
        else
            deskInfo.round.activeSeat = nextUser.seatid
            nextUser.state = PDEFINE.PLAYER_STATE.Bet
            user.state = PDEFINE.PLAYER_STATE.Wait
        
            -- 设置定时器
            retobj.delayTime = deskInfo.delayTime
            if nextUser.cluster_info then
                CMD.userSetAutoState('autoPack', deskInfo.delayTime, nextUser.uid)
            else
                CMD.userSetAutoState('autoAiDecide', deskInfo.delayTime, nextUser.uid)
            end

            -- 广播下一个操作人
            logic.broadcastNextUser(nextUser)
        end
    end

    return warpResp(retobj)
end

-- 用户check
function CMD.check(source, msg)
    msg.coin = 0
    return CMD.bet(source, msg)
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
    if deskInfo.round.activeSeat ~= user.seatid or user.state ~= PDEFINE.PLAYER_STATE.Bet then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end

    -- 查看当前剩余人数是否等于2
    local liveUsers = logic.findLiveUser()

    user:clearTimer()
    user.state = PDEFINE.PLAYER_STATE.Wait
    user.round.folded = 1
    user.round.action = bot.ActionType.Fold
    ---@type TexasRecord
    user.record.fold = user.record.fold + 1
    local isOver = 0
    -- 如果只剩下一个人，则剩下的那个人就是赢家
    if #liveUsers <= 2 then
        isOver = 1
    end

    
    local notify_object = {}
    notify_object.c  = PDEFINE.NOTIFY.PLAYER_PACK
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.uid    = uid
    local nowUsers = logic.findLiveUser()
    -- 返回当前牌面上，需要下注的金额数量
    notify_object.currBet = deskInfo.round.currBet
    
    -- 检测次轮下注是否闭环
    local isClose = logic.checkRoundClose(user)
    notify_object.isClose = isClose and 1 or 0
    -- 如果有人allin, 则会触发边池, 前端也会显示出不同的池子
    retobj.pots = logic.getAllPots()
    -- 返回金币池子
    notify_object.pots = retobj.pots
    -- 检查是否所有人都allin了(其他人allin, 自己跟注也算allin)
    local nextLiveUser = logic.findNextLiveUser(user.seatid)
    if not nextLiveUser then
        notify_object.fullallin = 1
    else
        notify_object.fullallin = 0
    end
    -- 广播操作
    deskInfo:broadcast(cjson.encode(notify_object))

    local nextUser = logic.findNextLiveUser(user.seatid)

    if isOver == 1 then
        -- 开始结算
        deskInfo.round.activeSeat = -1
        skynet.timeout(config.DelayTime.CollectCoinTime*100, function()
            roundOver(config.SettleType.Live)
        end)
    elseif isClose then
        if #deskInfo.round.showCards == 5 then
            retobj.isOver = 1
            deskInfo.round.activeSeat = -1
            -- 开始结算
            skynet.timeout(config.DelayTime.CollectCoinTime*100, function()
                roundOver(config.SettleType.Flow)
            end)
        else
            enterNextTurn()
        end
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

        if not user.cluster_info and math.random() < PDEFINE.ROBOT.DROP_LEAVE_ROOM_PROB then
            user:setTimer(math.random(1, 5), autoLeave, user.uid)
        end
    end

    return warpResp(retobj)
end

function CMD.showCard(source, msg)
    local recvobj = msg
    local uid = math.floor(recvobj.uid)
    local show = math.floor(recvobj.show)  -- 0 代表不展示，1代表展示第一张，2代表展示第二张，3代表全展示
    local user = deskInfo:findUserByUid(uid)
    local retobj = {c = recvobj.c, code= PDEFINE.RET.SUCCESS, spcode=0}

    if user.round.folded == 0 then
        retobj.spcode = PDEFINE.RET.ERROR.USER_STATE_ERROR
        return warpResp(retobj)
    end

    -- 弃牌后显示自己牌
    user.round.show = show
    if user.round.show > 3 or user.round.show < 0 then
        user.round.show = 0
    end
    
    -- local notify_object = {}
    -- notify_object.c = PDEFINE.NOTIFY.PLAYER_FOLD_SHOW
    -- notify_object.uid = uid
    -- notify_object.code = PDEFINE.RET.SUCCESS
    -- notify_object.cards = user.round.cards

    -- deskInfo:broadcast(cjson.encode(notify_object))

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
    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return warpResp(retobj)
    end
    if user.auto == 0 then
        return warpResp(retobj)
    end
    
    user:clearTimer()
    user.auto = 0 --关闭自动

    -- 根据状态，重新开启计时器
    if user.state == PDEFINE.PLAYER_STATE.Bet then
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
        if user and user.round.folded == 1 then
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
    local deskInfoStr = deskInfo:toResponse(msg.uid)
    if not deskInfoStr then
        return nil
    end
    if deskInfo.state == PDEFINE.DESK_STATE.PLAY then
        -- 额外传一个值给前端,表示当前下注的所有钱
        deskInfoStr.round.potCoin = deskInfoStr.round.betCoin
        if deskInfoStr.round.potCoin then
            for _, u in ipairs(deskInfoStr.users) do
                -- 给前端显示用
                deskInfoStr.round.potCoin = deskInfoStr.round.potCoin + u.round.currBet
            end
            deskInfoStr.round.pots = logic.getAllPots()
        end
        if deskInfoStr.round.showCards and #deskInfoStr.round.showCards > 0 and #deskInfoStr.round.showCards < 5 then
            local user = deskInfo:findUserByUid(msg.uid)
            if user then
                local tmp_cards = table.copy(deskInfoStr.round.showCards)
                for _, c in ipairs(user.round.cards) do
                    table.insert(tmp_cards, c)
                end
                deskInfoStr.round.tip = algo.CheckExpectCards(tmp_cards)
            end
        end
        if deskInfoStr.users and #deskInfoStr.users > 0 then
            for _, u in ipairs(deskInfoStr.users) do
                if u.uid == msg.uid and #(u.round.cards) > 0 then
                    u.round.cardInfo = logic.getCardInfo(u)
                end
            end
        end
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
        deskInfo.conf.betLimit = 10000
    end

    if not deskInfo.conf.potLimit then
        deskInfo.conf.potLimit = 50 * deskInfo.conf.betLimit
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

-- 赛事开始游戏
function CMD.TNGameStart(source)
    agent:TNGameStart()
    return PDEFINE.RET.SUCCESS
end

-- 赛事关闭入口
function CMD.TNNoticCloseTime(source)
    agent:TNNoticCloseTime()
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