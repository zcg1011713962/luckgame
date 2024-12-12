--[[
    用于德州扑克中的算法
    通过 0b11111111111110 来存储一个花色的14张牌
    通过 位操作来判断相应的牌型
]]

local Algo = {}

-- 牌型
-- 数额越大代表级别越高
Algo.Level = {
    HighCard = 1,  -- 高牌
    OnePair  = 2,  -- 一对(5012)
    TwoPair  = 3,  -- 两对(9237)
    ThreeKind = 4,  -- 三条(9713)
    Straight = 5,  -- 顺子(9924)
    Flush    = 6,  -- 同花(9963)
    FullHouse = 7,  -- 葫芦(9983)
    FourKind = 8,  -- 四条(9997)
    StraightFlush = 9, -- 同花顺(9999)
    RoyalFlush = 10,  -- 皇家同花顺(10000)
}

-- 花色
Algo.SuitType = {
    Diamond = 1,  -- 方块
    Club = 2,  -- 梅花
    Heart = 3,  -- 红心
    Spade = 4,  -- 黑桃
}

-- 花色对应字符
Algo.SuitIcon = {
    [Algo.SuitType.Diamond] = '♦',  -- 方块
    [Algo.SuitType.Club] = '♣',  -- 梅花
    [Algo.SuitType.Heart] = '♥',  -- 红心
    [Algo.SuitType.Spade] = '♠',  -- 黑桃
}

-- 牌型对应的字符
Algo.LevelString = {
    [Algo.Level.HighCard] = "高牌",
    [Algo.Level.OnePair] = "一对",
    [Algo.Level.TwoPair] = "两对",
    [Algo.Level.ThreeKind] = "三条",
    [Algo.Level.Straight] = "顺子",
    [Algo.Level.Flush] = "同花",
    [Algo.Level.FullHouse] = "葫芦",
    [Algo.Level.FourKind] = "四条",
    [Algo.Level.StraightFlush] = "同花顺",
    [Algo.Level.RoyalFlush] = "皇家同花顺",
}

-- 所有牌
Algo.AllCards = {
    0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,
    0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,
    0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,
    0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,
}

-- 皇家同花顺二进制数字
Algo.RoyalFlushValue = 15872

-- 获取花色
Algo.ScanSuit = function (value)
    return (value & 0xF0) // 16
end

-- 获取面值
Algo.ScanValue = function (value)
    return value & 0x0F
end

-- 面值同花色转成牌值
Algo.ConvertCard = function(value, suit)
    if value == 1 then
        return suit * 16 + 14
    else
        return suit * 16 + value
    end
end

-- 是否是Ace
Algo.IsAce = function (value)
    return value & 0x0F == 0x0E
end

-- 牌值转成字符
Algo.ConvertString = function(card)
    local suit = Algo.ScanSuit(card)
    local value = Algo.ScanValue(card)
    local str = Algo.SuitIcon[suit]
    if value <= 10 then
        return str..value
    elseif value == 11 then
        return str..'J'
    elseif value == 12 then
        return str..'Q'
    elseif value == 13 then
        return str..'K'
    elseif value == 14 then
        return str..'A'
    end
end

-- 将牌型转换成二进制
Algo.ConvertBinCards = function(cards)
    local cardMap = {  -- 按照花色分成4组
        [1] = 0,
        [2] = 0,
        [3] = 0,
        [4] = 0,
    }
    for _, c in ipairs(cards) do
        local suit = Algo.ScanSuit(c)
        local value = Algo.ScanValue(c)
        cardMap[suit] = cardMap[suit] | 1 << (value - 1)
        if Algo.IsAce(c) then
            cardMap[suit] = cardMap[suit] | 0x01
        end
    end
    return cardMap
end

-- 检测皇家同花顺
Algo.CheckRoyalFlush = function(cardMap)
    local cards = {}
    for suit, value in pairs(cardMap) do
        if value & Algo.RoyalFlushValue == Algo.RoyalFlushValue then
            for _, v in ipairs({14,13,12,11,10}) do
                table.insert(cards, Algo.ConvertCard(v, suit))
            end
            return true, cards
        end
    end
    return false
end

-- 检测同花顺
Algo.CheckStraightFlush = function(cardMap)
    local cards = {}
    for suit, value in pairs(cardMap) do
        local sCnt = 0  -- 连续的牌数量
        for i = 13, 0, -1 do
            if value & 1 << i == 1 << i then
                sCnt = sCnt + 1
            else
                sCnt = 0
            end
            if sCnt == 5 then
                for j = 5, 1, -1 do
                    table.insert(cards, Algo.ConvertCard(i+j, suit))
                end
                return true, cards
            end
        end
    end
    return false
end

-- 检测四条
Algo.CheckFourKind = function(cardMap)
    local cards = {}
    local comboValue = nil
    -- 四种花色相与，如果还大于0，则说明有4条
    for suit, value in pairs(cardMap) do
        if comboValue == nil then
            comboValue = value
        else
            comboValue = comboValue & value
        end
    end
    if comboValue == 0 then
        return false
    end
    -- 这里从1开始，是因为要绕过0位置的ace
    local targetV = nil
    for i = 1, 13, 1 do
        if comboValue & 1 << i == 1 << i then
            for suit = 4, 1, -1 do
                table.insert(cards, Algo.ConvertCard(i+1, suit))
            end
            targetV = i
        end
    end
    -- 再塞一个最大的散牌
    for i = 13, 1, -1 do
        if i ~= targetV then
            local binValue = 1 << i
            for suit = 4, 1, -1 do
                if cardMap[suit] & binValue == binValue then
                    table.insert(cards, Algo.ConvertCard(i+1, suit))
                    return true, cards
                end
            end
        end
    end
    -- 没有5个就返回4个牌
    return true, cards
end

-- 检测葫芦
-- 葫芦有个特殊情况，有可能是 2 2 3 这样的牌型，则需要找出最大牌型
Algo.ChecFullHouse = function(cardMap)
    local cards = {}
    -- 这里从1开始，是因为要绕过0位置的ace
    local hasThree = false
    local hasTwo = false
    for i = 13, 1, -1 do
        local cnt = 0
        local suits = {}
        local binValue = 1 << i
        for suit = 4, 1, -1 do
            if cardMap[suit] & binValue == binValue then
                cnt = cnt + 1
                table.insert(suits, suit)
            end
        end
        if cnt == 3 and not hasThree then
            for _, suit in ipairs(suits) do
                -- 三条的牌要放到两条之前
                table.insert(cards, 1, Algo.ConvertCard(i+1, suit))
            end
            hasThree = true
        elseif (cnt == 2 or cnt == 3) and not hasTwo then
            -- 如果已经有3条了，则剩下的3条可以作为两条
            for idx, suit in ipairs(suits) do
                table.insert(cards, Algo.ConvertCard(i+1, suit))
                if idx == 2 then
                    break
                end
            end
            hasTwo = true
        end
        if hasThree and hasTwo then
            return true, cards
        end
    end
    return false
end

-- 检测同花
Algo.CheckFlush = function(cardMap)
    for suit, value in pairs(cardMap) do
        local sCnt = 0  -- 同花的数量
        local cards = {}
        -- 倒序到1，排除0位置的ace,满足5个即可返回
        for i = 13, 1, -1 do
            if value & 1 << i == 1 << i then
                sCnt = sCnt + 1
                table.insert(cards,  Algo.ConvertCard(i+1, suit))
            end
            if sCnt == 5 then
                return true, cards
            end
        end
    end
    return false
end

-- 检测顺子
Algo.CheckStraight = function(cardMap)
    local sCnt = 0 -- 顺子数量
    local cards = {}
    for i = 13, 0, -1 do
        local value = 1 << i
        local forward = false
        for suit = 4, 1, -1 do
            if cardMap[suit] & value == value then
                sCnt = sCnt + 1
                table.insert(cards, Algo.ConvertCard(i+1, suit))
                forward = true
                break
            end
        end
        if not forward then
            sCnt = 0
            cards = {}
        end
        if sCnt == 5 then
            return true, cards
        end
    end
    return false
end

-- 检测3条
Algo.CheckThreeKind = function(cardMap)
    local cards = {}
    local targetV = 0
    -- 这里从1开始，是因为要绕过0位置的ace
    for i = 13, 1, -1 do
        local cnt = 0
        local suits = {}
        local binValue = 1 << i
        for suit = 4, 1, -1 do
            if cardMap[suit] & binValue == binValue then
                cnt = cnt + 1
                table.insert(suits, suit)
            end
        end
        if cnt == 3 then
            for _, suit in ipairs(suits) do
                table.insert(cards, Algo.ConvertCard(i+1, suit))
            end
            targetV = i
            break
        end
    end
    if targetV == 0 then
        return false
    end
    -- 再塞两个个最大的散牌
    for i = 13, 1, -1 do
        if i ~= targetV then
            local binValue = 1 << i
            for suit = 4, 1, -1 do
                if cardMap[suit] & binValue == binValue then
                    table.insert(cards, Algo.ConvertCard(i+1, suit))
                    if #cards == 5 then
                        return true, cards
                    end
                end
            end
        end
    end
    -- 没有5个就返回3个
    return true, cards
end

-- 检测两对
Algo.CheckTwoPair = function(cardMap)
    local cards = {}
    local pairCnt = 0  -- 对子数量
    local targetVs = {}
    -- 这里从1开始，是因为要绕过0位置的ace
    for i = 13, 1, -1 do
        local cnt = 0  -- 同值牌数量
        local suits = {}
        local binValue = 1 << i
        for suit = 4, 1, -1 do
            if cardMap[suit] & binValue == binValue then
                cnt = cnt + 1
                table.insert(suits, suit)
            end
        end
        if cnt >= 2 then
            pairCnt = pairCnt + 1
            for idx, suit in ipairs(suits) do
                table.insert(cards, Algo.ConvertCard(i+1, suit))
                if idx == 2 then
                    break
                end
            end
            table.insert(targetVs, i)
            if pairCnt == 2 then
                break
            end
        end
    end
    if pairCnt ~= 2 then
        return false
    end
    -- 再塞一个最大的散牌
    for i = 13, 1, -1 do
        if i ~= targetVs[1] and i ~= targetVs[2] then
            local binValue = 1 << i
            for suit = 4, 1, -1 do
                if cardMap[suit] & binValue == binValue then
                    table.insert(cards, Algo.ConvertCard(i+1, suit))
                    return true, cards
                end
            end
        end
    end
    -- 没有5个就返回两个
    return true, cards
end

-- 检测对子
Algo.CheckOnePair = function(cardMap)
    local cards = {}
    local targetV = 0
    -- 这里从1开始，是因为要绕过0位置的ace
    for i = 13, 1, -1 do
        local cnt = 0  -- 同值牌数量
        local suits = {}
        local binValue = 1 << i
        for suit = 4, 1, -1 do
            if cardMap[suit] & binValue == binValue then
                cnt = cnt + 1
                table.insert(suits, suit)
            end
        end
        if cnt >= 2 then
            targetV = i
            for idx, suit in ipairs(suits) do
                table.insert(cards, Algo.ConvertCard(i+1, suit))
                if idx == 2 then
                    break
                end
            end
        end
    end
    if targetV == 0 then
        return false
    end
    -- 再找出最大的3张牌
    for i = 13, 1, -1 do
        if i ~= targetV then
            local binValue = 1 << i
            for suit = 4, 1, -1 do
                if cardMap[suit] & binValue == binValue then
                    table.insert(cards, Algo.ConvertCard(i+1, suit))
                    if #cards == 5 then
                        return true, cards
                    end
                end
            end
        end
    end
    -- 没有5个就随便返回几个
    return true, cards
end

-- 获得高牌组合
Algo.GetHighCard = function(cardMap)
    local cards = {}
    local cnt = 0
    for i = 13, 1, -1 do
        local binValue = 1 << i
        for suit = 4, 1, -1 do
            if cardMap[suit] & binValue == binValue then
                cnt = cnt + 1
                table.insert(cards, Algo.ConvertCard(i+1, suit))
            end
            if cnt == 5 then
                return true, cards
            end
        end
    end
    -- 有可能没有5张牌
    return true, cards
end

-- 从7张牌中，得出最大组合，以及相应的牌型
Algo.Check = function(cards_, extra)
    local cardMap = Algo.ConvertBinCards(cards_)
    local isEnd = false
    local cards = nil
    local ctype = Algo.Level.RoyalFlush
    isEnd, cards = Algo.CheckRoyalFlush(cardMap)
    if not isEnd then
        ctype = Algo.Level.StraightFlush
        isEnd, cards = Algo.CheckStraightFlush(cardMap)
    end
    if not isEnd then
        ctype = Algo.Level.FourKind
        isEnd, cards = Algo.CheckFourKind(cardMap)
    end
    if not isEnd then
        ctype = Algo.Level.FullHouse
        isEnd, cards = Algo.ChecFullHouse(cardMap)
    end
    if not isEnd then
        ctype = Algo.Level.Flush
        isEnd, cards = Algo.CheckFlush(cardMap)
    end
    if not isEnd then
        ctype = Algo.Level.Straight
        isEnd, cards = Algo.CheckStraight(cardMap)
    end
    if extra then
        if isEnd then
            return ctype, cards
        else
            return nil, nil
        end
    end
    if not isEnd then
        ctype = Algo.Level.ThreeKind
        isEnd, cards = Algo.CheckThreeKind(cardMap)
    end
    if not isEnd then
        ctype = Algo.Level.TwoPair
        isEnd, cards = Algo.CheckTwoPair(cardMap)
    end
    if not isEnd then
        ctype = Algo.Level.OnePair
        isEnd, cards = Algo.CheckOnePair(cardMap)
    end
    if not isEnd then
        ctype = Algo.Level.HighCard
        isEnd, cards = Algo.GetHighCard(cardMap)
    end
    return ctype, cards
end

-- 根据目前已有牌，判断可能的牌型，以及胜率
-- 只需要判断葫芦，顺子，同花，同花顺，皇家同花顺其中的最大牌型
Algo.CheckExpectCards = function(cards)
    -- 先判断目前是否已经满足
    local tmpCard = table.copy(cards)
    local ctype, finalCards = Algo.Check(tmpCard, true)
    if ctype then
        -- 已经组成了，就不提示
        return nil
        -- return {ctype=ctype, isAny=true, cards=finalCards, suit=nil, need=nil}
    end

    -- 可以是5张，也可以是6张
    local maybeCards = {}
    local nowCtype = nil
    for _, card in ipairs(Algo.AllCards) do
        if not table.contain(cards, card) then
            tmpCard = table.copy(cards)
            table.insert(tmpCard, card)
            ctype, finalCards = Algo.Check(tmpCard, true)
            if ctype then
                if not nowCtype or nowCtype < ctype then
                    nowCtype = ctype
                    maybeCards = {}
                end
                if ctype == nowCtype then
                    table.insert(maybeCards, card)
                end
            end
        end
    end

    if nowCtype then
        local maybeValue = {}
        local needCards = {}
        local isAny = false
        if nowCtype == Algo.Level.Flush then
            -- return {ctype=nowCtype, isAny=isAny, need=nil, suit=Algo.ScanSuit(finalCards[1]), cards=finalCards}
            return {ctype=nowCtype, cards={maybeCards[1]}}
        end
        for _, c in ipairs(maybeCards) do
            local v = Algo.ScanValue(c)
            if table.contain(maybeValue, v) then
                isAny = true
            else
                table.insert(maybeValue, v)
                table.insert(needCards, c)
            end
        end
        -- return {ctype=nowCtype, isAny=isAny, need=needCards, suit=nil, cards=finalCards}
        return {ctype=nowCtype, cards=needCards}
    end
    return nil
end

-- 获取所有能成型的牌，大于等于3张
Algo.getAllExpectCards = function(cards)
    -- 可以是5张，也可以是6张
    local maybeCards = {}
    local nowCtype = nil
    for _, card in ipairs(Algo.AllCards) do
        if not table.contain(cards, card) then
            local tmpCard = table.copy(cards)
            table.insert(tmpCard, card)
            local ctype, finalCards = Algo.Check(tmpCard, true)
            if ctype then
                table.insert(maybeCards, card)
            end
        end
    end
    
   return maybeCards 
end

-- 检测是否符合要求
Algo.testCtype = function()
    math.randomseed(os.time())
    for i = 1, 20, 1 do
        local _cards = {}
        local origin_str = ""
        local _cardMap = {}
        for i = 1, 7, 1 do
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
        print("原牌: ", origin_str)
        local str = ""
        -- _cards = {44, 75, 42, 73, 24}
        local ctype, cards = Algo.Check(_cards)
        print("牌型: ", Algo.LevelString[ctype])
        for _, card in ipairs(cards) do
            str = str.." "..Algo.ConvertString(card)
        end
        print("牌组: ", str)
    end
end

-- 检测需要牌
Algo.testMaybeCards = function()
    math.randomseed(os.time())
    local cnt = math.random(5,6)
    for i = 1, 10, 1 do
        local _cards = {}
        local origin_str = ""
        local _cardMap = {}
        for i = 1, cnt, 1 do
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
        local str = ""
        local result = Algo.CheckExpectCards(_cards)
        print("牌型: ", result and Algo.LevelString[result.ctype] or "无")
        if result then
            for _, card in ipairs(result.cards) do
                str = str.." "..Algo.ConvertString(card)
            end
            local needStr = ""
            if result.need then
                for _, card in ipairs(result.need) do
                    needStr = needStr.." "..Algo.ConvertString(card)
                end
            end
            if result.suit then
                needStr = needStr..Algo.SuitIcon[result.suit]
            end
            print("原牌: ", origin_str)
            print("牌组: ", str)
            print("需要: ", needStr)
        end
    end
end

-- -- 深拷贝
-- table.copy = function(t, nometa)
--     local result = {}

--     if not nometa then
--         setmetatable(result, getmetatable(t))
--     end

--     for k, v in pairs(t) do
--         if type(v) == "table" then
--             result[k] = table.copy(v, nometa)
--         else
--             result[k] = v
--         end
--     end
--     return result
-- end

-- table.contain = function(t, val)
--     for _, v in pairs(t) do
--         if v == val then
--             return true
--         end
--     end
--     return false
-- end


-- Algo.testCtype()
-- Algo.testMaybeCards()

return Algo