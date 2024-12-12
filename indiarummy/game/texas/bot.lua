local Algo = require "texas.algo"

local bot = {}

bot.ActionType = {
    Fold = 1,  -- 弃牌
    Call = 2,  -- 跟牌
    Raise = 3,  -- 加注
    Check = 4,  -- 看牌
    AllIn = 5,  -- 全押
    SBlind = 6,  -- 小盲
    BBlind = 7,  -- 大盲
    ReCall = 8,  -- 再下注(新的一轮第一次下注，或者大盲下注，下等于大盲的注)
}

-- 牌对应的牌力
-- 6是同花,低级顺子
-- 7是最差
bot.probabilityLevel = {
    [1] = {'AA',  'KK',  'QQ',  'AKs', 'JJ',  'AQs', 'KQs'},     -- 一等牌力(前5%)
    [2] = {'AJs', 'KJs', 'TT',  'AKo', 'ATs', 'QJs', 'KTs', 'QTs', 'JTs'},  --(前10%)
    [3] = {'99',  'AQo', 'A9s', 'KQo', '88',  'K9s', 'T9s', 'A8s', 'Q9s'},--(前15%)
    [4] = {'J9s', 'AJo', 'A5s', '77',  'A7s', 'KJo', 'A4s', 'A3s', 'A6s', 'QJo', '66',  'K8s'},--(前22%)
    [5] = {'T8s', 'A2s', '98s', 'J8s', 'ATo', 'Q8s', 'K7s', 'KTo', '55',  'JTo',
           '87s', 'QTo', '44',  '33',  '22',  'K6s', '97s', 'K5s', '76s', 'T7s'},--(前35%)
    [6] = {'K4s', 'K3s', 'K2s', 'Q7s', '86s', '65s', 'J7s', '54s', 'Q6s', '75s',
           '96s', 'Q5s', '64s', 'Q4s', 'Q3s', 'T9o', 'T6s', 'Q2s', 'A9o', '53s',
           '85s', 'J6s', 'J9o', 'K9o', 'J5s', 'Q9o', '43s', '74s', 'J4s', 'J3s'},--(前51%)
    [7] = {'95s', 'J2s', '63s', 'A8o', '52s', 'T5s', '84s', 'T4s', 'T3s', '42s',
           'T2s', '98o', 'T8o', 'A5o', 'A7o', '73s', 'A4o', '32s', '94s', '93s',
           'J8o', 'A3o', '62s', '92s', 'K8o', 'A6o', '87o', 'Q8o', '83s', 'A2o', '82s'}--(前70%)
}

bot.num2char = function(x)
    local c = ''
    if x == 10 then
        c = 'T'
    elseif x == 11 then
        c = 'J'
    elseif x == 12 then
        c = 'Q'
    elseif x == 13 then
        c = 'K'
    elseif x == 14 then
        c = 'A'
    else
        c = ''..x
    end
    return c
end

-- 根据首发牌获取相应的缩写代号
bot.convertHandCode = function(cards)
    local x, y = cards[1], cards[2]
    if Algo.ScanValue(x) < Algo.ScanValue(y) then
        x, y = y, x
    end
    local suit = 'o'
    if Algo.ScanSuit(x) == Algo.ScanSuit(y) then
        suit = 's'
    end
    return bot.num2char(Algo.ScanValue(x))..bot.num2char(Algo.ScanValue(y))..suit
end

-- 更新机器人的机会
-- @param user 机器人对象，需要有round.chance字段来存储机会值
bot.getHandLevel = function(cards)
    local handChar = bot.convertHandCode(cards)
    for level, charList in ipairs(bot.probabilityLevel) do
        for _, charPoker in ipairs(charList) do
            if string.find(handChar, charPoker) then
                return level
            end
        end
    end
    return 8
end

-- 是否有人allin
bot.isSomeOneAllIn = function(deskInfo)
    for _, u in ipairs(deskInfo.users) do
        if u.round.allin == 1 then
            return u.uid
        end
    end
    return nil
end

--获取牌型权重
bot.getCardTypeWeight = function(cardType)
    if cardType > Algo.Level.OnePair then
        return cardType
    elseif cardType == Algo.Level.OnePair then
        return 1
    end
    return 0
end

--获取期待牌型权重
--minType： 已知牌型
bot.getExpectCardsWeight = function(cards, minType)
    local weight = 0
    for _, card in ipairs(Algo.AllCards) do
        if not table.contain(cards, card) then
            local tmpCard = table.copy(cards)
            table.insert(tmpCard, card)
            local ctype = Algo.Check(tmpCard, true)
            if ctype and ctype > minType then  --要大于已知牌型（否则已知牌型随便加一张牌都大于等于已知牌型）
                weight = weight + bot.getCardTypeWeight(ctype)*0.5
            end
        end
    end
   return weight
end

-- 成牌概率，一般成牌3张以上，赢牌概率都比较大
-- 2张牌不用计算成牌概率，5张牌就需要计算成牌概率
bot.checkSuccessProb = function(deskInfo, user)
    local cards = table.copy(user.round.cards)
    for _, c in ipairs(deskInfo.round.showCards) do
        table.insert(cards, c)
    end

    local weight = 0
    -- 这里计算自己当前牌型情况，如果已经是组合牌型了，则赌注可以加大
    local myCtype = Algo.Check(cards)
    weight = weight + 3 * bot.getCardTypeWeight(myCtype)

    -- 有5张牌，就可以算可能牌型了
    if #cards == 5 or #cards == 6 then
        weight = weight + bot.getExpectCardsWeight(cards, myCtype)
    end

    if #cards == 5 then
        return weight / 20
    elseif #cards == 6 then
        return weight / 40
    else
        return weight / 20
    end
    return 0
end

-- 赔率，投入的钱和收回的钱比例
bot.checkLossPercent = function(deskInfo, user)
    local needCoin = deskInfo.round.currBet - user.round.currBet
    local totalCoin = deskInfo.round.betCoin + deskInfo.round.currBet * #deskInfo.users
    for _, u in ipairs(deskInfo.users) do
        totalCoin = totalCoin + u.round.currBet
    end
    LOG_DEBUG("checkLossPercent: ", totalCoin, " deskInfo.round.betCoin:", deskInfo.round.betCoin)
    return needCoin / totalCoin
end

-- 
bot.test = function()
    math.randomseed(os.time())
    for i = 1, 20, 1 do
        local _cards = {}
        local origin_str = ""
        local convert_str = ""
        local _cardMap = {}
        for i = 1, 2, 1 do
            local card
            while true do
                local suit = math.random(4)
                local value = math.random(2, 14)
                card = Algo.ConvertCard(value, suit)
                if not _cardMap[card] then
                    _cardMap[card] = 1
                    break
                end
            end
            table.insert(_cards, card)
            origin_str = origin_str.." "..Algo.ConvertString(card)
        end
        convert_str = bot.convertHandCode(_cards)
        print("原牌: ", origin_str)
        print("牌组: ", convert_str)
    end
end


-- bot.test()


return bot