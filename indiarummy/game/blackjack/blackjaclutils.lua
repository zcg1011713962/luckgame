--21点算法

local CardType =
{
    Boom = 0,   --爆牌
    P1 = 1,   P2 = 2,   P3 = 3,   P4 = 4,   P5 = 5,     --1~5点
    P6 = 6,   P7 = 7,   P8 = 8,   P9 = 9,   P10 = 10,   --6~10点
    P11 = 11, P12 = 12, P13 = 13, P14 = 14, P15 = 15,   --11~15点
    P16 = 16, P17 = 17, P18 = 18, P19 = 19, P20 = 20,   --16~20点
    P21 = 21,           --21点
	FiveCard = 100,		--五张
	BalckJack = 101,	--black jack
}

local utils = {}

utils.CardType = CardType

-- 算出牌值
utils.ScanValue = function (value)
    return value & 0x0F
end

-- 算出花色
utils.ScanSuit = function (value)
    return (value & 0xF0) // 16
end

-- 是否Ace
utils.IsAce = function (value)
    return value & 0x0F == 0x0E
end

--洗牌
utils.RandomCards = function(cards)
    for i = #cards, 2, -1 do
        local j = math.random(i)
        cards[i], cards[j] = cards[j], cards[i]
    end
    return cards
end

--计算Ace数量
utils.GetAceNum = function(cards)
    local num = 0
    for _, card in pairs(cards) do
        if utils.IsAce(card) then
            num = num + 1
        end
    end
    return num
end

--计算牌点数
utils.CalcPoint = function(card)
    if utils.IsAce(card) then
        return 11
    else
        local value = utils.ScanValue(card)
        return math.min(10, value)
    end
end

--计算牌型
utils.CalcType = function(cards)
    local AceNum = utils.GetAceNum(cards)
    if AceNum == 0 then  --如果没有A
        local point = 0
        for _, card in ipairs(cards) do
            point = point + utils.CalcPoint(card)
        end
        if point > 21 then  --超过21点爆牌
            return CardType.Boom
        else
            if #cards == 5 then  --五张
                return CardType.FiveCard
            else
                return point
            end
        end
    else  --如果有A
        if #cards == 2 then --如果正好一张A，一张10点的牌，则为Black Jack
            if (utils.IsAce(cards[1]) and utils.CalcPoint(cards[2]) == 10)
                or (utils.IsAce(cards[2]) and utils.CalcPoint(cards[1]) == 10) then
                return CardType.BalckJack
            end
        end
        local point = 0
        --先计算不为A的牌的点数
        for _, card in ipairs(cards) do
            if not utils.IsAce(card) then
                point = point + utils.CalcPoint(card)
            end
        end
        --把A分别用11或1加上去，并使之不超过21
        for i = 1, AceNum do
            if point + 11 + (AceNum-i) > 21 then   --注意，要考虑所有A同时加起来时也不能超过21
                point = point + 1
            else
                point = point + 11
            end
        end
        if point > 21 then
            return CardType.Boom
        else
            if #cards == 5 then --五张
                return CardType.FiveCard
            else
                return point
            end
        end
    end
end

--计算显示牌型（未结算前需要显示所有的组合值）
utils.CalcShowType = function(cards)
    local point = utils.CalcType(cards)
    if point <= 0 or point >= 21 then
        return point
    end
    local AceNum = utils.GetAceNum(cards)
    if AceNum == 0 then  --如果没有A
        return point
    else  --如果有A
        local point = 0
        --先计算不为A的牌的点数
        for _, card in ipairs(cards) do
            if not utils.IsAce(card) then
                point = point + utils.CalcPoint(card)
            end
        end
        --多张A，只能有0个或1个11，因为2个以上11会爆
        local points = {}
        --一，所有都是1
        table.insert(points, point+AceNum)
        --二，一个11，其他为1
        local val = point + 11 + AceNum - 1
        if val <= 21 then
            table.insert(points, val)
        end
        if #points == 1 then
            return points[1]
        else
            return points
        end
    end
end

--[[
local testcast = {
    {0x1E, 0x1a},  --101
    {0x1E, 0x2E},  --101
    {0x22, 0x35,0x23,0x1E,0x26},    --100
    {0x24,0x26},    --10
    {0x37,0x1D,0x1A},   --0
    {0x49,0x1E,0x2E,0x4a},  --21
}
for _, cards in ipairs(testcast) do
    print(table.concat(cards, ","), ":", utils.CalcType(cards))
end
]]--

return utils