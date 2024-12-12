-- 此文件用于定义游戏中用到的方法
local utils = {}

local function debug_print(value)
    -- print(value)
end

-- 算出牌值
utils.ScanValue = function (value)
    if utils.IsJoker(value) then
        return value
    end
    return value & 0x0F
end

-- 根据花色和值算出牌
utils.getCard = function (suit, value)
    return 16*suit + value
end

-- 算出花色
utils.ScanSuit = function (value)
    return (value & 0xF0) // 16
end

-- 是Ace
utils.IsAce = function (value)
    return value & 0x0F == 0x0E
end

-- 是3
utils.IsThree = function (value)
    return value & 0x0F == 0x03
end

-- 是2
utils.IsTwo = function (value)
    return value < 0x50 and (value & 0x0F == 0x02)
end

-- 是大小王
utils.IsJoker = function (value)
    return value == 0x51 or value == 0x52
end

-- 是大王
utils.IsBigJoker = function (value)
    return value == 0x52
end

utils.IsLitteJoker = function (value)
    return value == 0x51
end

-- 是Q
utils.IsQueen = function (value)
    return value & 0x0F == 0x0C
end

-- 是K
utils.IsKing = function (value)
    return value & 0x0F == 0x0D
end

-- 移除手牌
utils.RemoveCard = function(cards, card)
    local idx = nil
    for i, c in ipairs(cards) do
        if c == card then
            idx = i
            break
        end
    end
    if idx then
        table.remove(cards, idx)
        return cards
    end
    return nil
end

utils.RemoveDominoCard = function (cards, card)
    local idx = nil
    for i, c in ipairs(cards) do
        if c.id == card.id then
            idx = i
            break
        end
    end
    if idx then
        table.remove(cards, idx)
        return cards
    end
    return nil
end

-- 找出牌最多的一个花色
utils.FindMaxSuit = function (cards)
    local suits = {0,0,0,0}
    for _, c in ipairs(cards) do
        local suit = utils.ScanSuit(c)
        if suit <= 4 then
            suits[suit] = suits[suit] + 1 
        end
    end
    local maxSuit = nil
    local maxCnt = nil
    for suit, cnt in ipairs(suits) do
        if not maxSuit or maxCnt < cnt then
            maxSuit = suit
            maxCnt = cnt
        end
    end
    return maxSuit
end

-- 找出上家座位的用户
utils.FindPrevUser = function (seatid, deskInfo)
    local seats = {}
    for _, user in pairs(deskInfo.users) do
        table.insert(seats, user.seatid)
    end

    table.sort(seats, function (a, b)
        return a < b
    end)
    local idx = 0
    for k, v in ipairs(seats) do
        if v == seatid then
            idx = k
            break
        end
    end
    local preSeatid = 0
    if idx == 1 then
        preSeatid = seats[#seats]
    else
        preSeatid = seats[idx-1]
    end
	for _, user in pairs(deskInfo.users) do
		if user.seatid == preSeatid then
			return user
		end
	end
	return nil
end

-- 定义花色
utils.SuitType = {
    Diamond = 1,  -- 方块
    Club = 2,  -- 梅花
    Heart = 3,  -- 红心
    Spade = 4,  -- 黑桃
    None = 5,  -- 无花色
}

-- 找到指定牌的索引位置
utils.findCardIndex = function(cards, card)
    for idx, c in ipairs(cards) do
        if c == card then
            return idx
        end
    end
    return nil
end


return utils