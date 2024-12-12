--[[
    计算baloot玩法的牌型
]]
local config = require "baloot/config"
local balootutil = {}

local SUN_DICT = { --sun玩法的算分规则 7，8，9不算分
    [14] = 11, --A
    [13] = 4, --K
    [12] = 3, --Q
    [11] = 2, --J
    [10] = 10, -- 10
    [9] = 0,
    [8] = 0,
    [7] = 0,
}

local HOKOM_DICT = { --hokom主牌算分规则，7，8不算分
    [14] = 11, --A
    [13] = 4, --K
    [12] = 3, --Q
    [11] = 20, --J
    [10] = 10, -- 10
    [9] = 14, --9
    [8] = 0,
    [7] = 0,
}

-- 在sun玩法中计算每次4张牌的得分 A > 10 > K > Q > J > 9 > 8 > 7
-- firtCard: 首牌,此轮的第1张牌
-- userCards: 用户出牌的数组 uid=>card
function balootutil.calCardScoreInSun(firstCard, userCards)
    local filterCards = {} --跟首牌花色相同的牌
	local score = 0 --本次出牌总得分
	local tenCard = 0 --是不是包含10
	local firstCardColor = getCardColor(firstCard)
	for _, card in pairs(userCards) do
		local value = getCardValue(card)
		if nil ~= SUN_DICT[value] then --算分
			score = score + SUN_DICT[value]
		end

		if firstCardColor == getCardColor(card) then --找到花色相同的用来比大小
			table.insert(filterCards, card)
			if value == 10 then
				tenCard = card
			end
		end
	end
	table.sort(filterCards, function(a, b) --大牌在前面
		return a > b
	end)
	local maxCard = filterCards[1]
	if tenCard > 0 and getCardValue(maxCard) ~= 14 then --有10, 最大牌不是A
		maxCard = tenCard
	end
	local maxuid
	for userid, card in pairs(userCards) do
		if card == maxCard then
			maxuid = userid
			break
		end
	end
	return score, maxuid
end


--hokom玩法 按照牌的花色是否是主花色算分
--主牌：J > 9 > A > 10 > K > Q > 8 > 7
--others: A > 10 > K > Q > J > 9 > 8 > 7
-- @firtCard: 首牌
-- @userCards: 用户出牌的数组
-- @mainColor: 主花色
function balootutil.calCardScoreInHokom(firstCard, userCards, mainColor)
    local score = 0 --本次出牌总得分
    local filterCards = {} --其他花色
    local suitCards = {} --主
    local hokom = false
    local firtCardColor = getCardColor(firstCard)
    if firtCardColor == mainColor then --此轮是不是吊主牌
        hokom = true
    end

    local tenCard = 0 --是不是包含10
    local tenCardSuit = 0
    local suitMax = 0 --主牌里最大的牌
    for _, card in pairs(userCards) do
        local color = getCardColor(card)
        local scoreDict = SUN_DICT
        if color == mainColor then
            scoreDict = HOKOM_DICT
        end
        local cardValue = getCardValue(card)
        score = score + scoreDict[cardValue]
        if hokom then --吊主牌
            if mainColor == color then
                table.insert(suitCards, card) --有主牌
                if suitMax == 0 and table.contain({25,41,57,73}, card) then --9
                    suitMax = card
                end

                if table.contain({27,43,59,75}, card) then --J最大
                    suitMax = card
                end

                if cardValue == 10 then
                    tenCardSuit = card
                end
            end
        else --打副牌，有人用主牌毙
            if firtCardColor == color then
                table.insert(filterCards, card) --找到副牌花色相同的用来比大小
                if cardValue == 10 then
                    tenCard = card
                end
            end
            if color == mainColor then
                table.insert(suitCards, card) --有主牌
                if suitMax == 0 and table.contain({25,41,57,73}, card) then --9
                    suitMax = card
                end

                if table.contain({27,43,59,75}, card) then --J
                    suitMax = card
                end

                if cardValue == 10 then
                    tenCardSuit = card
                end
            end
        end
    end
    local maxuid, maxCard = 0, 0
    if table.empty(suitCards) then --纯打副牌，按照sun玩法的规则决定大小
        table.sort(filterCards, function(a, b)
            return a > b
        end)
        maxCard = filterCards[1]
        local maxCardValue = getCardValue(maxCard)
        if tenCard > 0 and maxCardValue ~= 14 then --有10, 最大牌不是A
            maxCard = tenCard
        end
    else --吊主 或者 有主毙副牌
        if suitMax > 0 then
            maxCard = suitMax
        else
            table.sort(suitCards, function(a, b)
                return a > b
            end)
            maxCard = suitCards[1]
            local maxCardValue = getCardValue(maxCard)
            if tenCardSuit > 0 and maxCardValue ~= 14 then --主牌里去掉j和9，最大的一张还不是10
                maxCard = tenCardSuit
            end
        end
    end
    for userid, card in pairs(userCards) do
        if card == maxCard then
            maxuid = userid
            break
        end
    end
    return score, maxuid
end

local HOKOM_SORT = {11, 9 , 14, 10, 13, 12, 8, 7}
local SUN_SORT = {14, 10, 13, 12, 11, 9, 8, 7}

-- Hokom 主花色 第1张牌a是否比b大 J > 9 > A > 10 > K > Q > 8 > 7
local function compairCard(a, b, gametype, specifycolor)
    if specifycolor then
        if getCardColor(a) ~= getCardColor(b) then
            return true
        end
    end
    
    local sortDict = SUN_SORT
    if gametype == 1 then
        sortDict = HOKOM_SORT --Hokom 主花色 第1张牌a是否比b大 J > 9 > A > 10 > K > Q > 8 > 7
    end
    local aKey, bKey = 0, 0
    local aVal, bVal = getCardValue(a), getCardValue(b)
    for k, val in ipairs(sortDict) do
        if val == aVal then
            aKey = k
        end
        if val == bVal then
            bKey = k
        end
    end
    if aKey > bKey then
        return false
    end
    return true
end

-- hokom玩法下，主花色的Q或K是否已经被打出去
function balootutil.canBaloot(suitColor, user, outCardValue)
    local myCard
    if outCardValue == 13 then
        local cardQs = {0x1C, 0x2C, 0x3C, 0x4C}
        for _, card in pairs(cardQs) do
            if getCardColor(card) == suitColor then
                myCard = card
                break
            end
        end
    else
        local cardKs = {0x1D, 0x2D, 0x3D, 0x4D}
        for _, card in pairs(cardKs) do
            if getCardColor(card) == suitColor then
                myCard = card
                break
            end
        end
    end
    if table.contain(user.round.cards, myCard) and not table.contain(user.round.handInCards, myCard) then
        LOG_DEBUG("balootutil.canBaloot myCard color:", getCardColor(myCard), ' val:', getCardValue(myCard), ' outCardValue:', outCardValue, ' suitColor:',suitColor)
        return true
    end
    return false
end

--! 判断我出的牌是否是最大的牌
function balootutil.isMaxCard(outCard, cards, suit)
    if getCardColor(outCard) ~= suit then
        local otherCards = {} --副牌
        for _, card in pairs(cards) do
            local color = getCardColor(card)
            if color ~= suit then
                table.insert(otherCards, card)
                if not compairCard(outCard, card, 2, false) then
                    return false --副牌里不是最大
                end
            end
        end
    end
    return true
end

-- 判断是否可以sawa
-- @maxCards 先出的玩家的手牌
-- @otherCards 其他用户的手牌 uid=>usercards
-- @gametype 玩法 1:hokom 2:sun
-- @suit 主花色
-- hokom:
--主牌：J > 9 > A > 10 > K > Q > 8 > 7
--others: A > 10 > K > Q > J > 9 > 8 > 7
-- sun
-- A > 10 > K > Q > J > 9 > 8 > 7
function balootutil.canSawa(maxCards, otherCards, gametype, suit)
    local score = 0
    if gametype == 2 or gametype ==3 then --sun
        for _, maxCard in pairs(maxCards) do
            for _, cards in pairs(otherCards) do
                for _, card in pairs(cards) do
                    if not compairCard(maxCard, card, 2, true) then
                        return false, 0
                    end
                end
            end
            score = score + SUN_DICT[getCardValue(maxCard)] --自己的牌分
        end
        for _, cards in pairs(otherCards) do --大家的牌分
            for _, card in pairs(cards) do
                score = score + SUN_DICT[getCardValue(card)]
            end
        end
    else
        --优先判断主牌张数
        local maxSuitCards, maxOtherCards = {}, {} --主牌、副牌
        for _, card in pairs(maxCards) do
            local color = getCardColor(card)
            if color == suit then
                table.insert(maxSuitCards, card)
            else
                table.insert(maxOtherCards, card)
            end
        end

        for _, cards in pairs(otherCards) do
            local userSuitCards = {}
            local userOtherCards = {}
            for _, card in pairs(cards) do
                if getCardColor(card) == suit then
                    table.insert(userSuitCards, card)
                else
                    table.insert(userOtherCards, card)
                end
            end
            if #userSuitCards > #maxSuitCards then --主牌数量就比出牌人的多
                return false, 0
            else
                if #userSuitCards == #maxSuitCards then
                    for _, maxSuit in pairs(maxSuitCards) do -- 比主牌
                        for _, userSuit in pairs(userSuitCards) do
                            if not compairCard(maxSuit, userSuit, 1, true) then
                                return false, 0
                            end
                        end
                    end
                end
                for _, maxOther in pairs(maxOtherCards) do --比副牌
                    for _, userOther in pairs(userOtherCards) do
                        if not compairCard(maxOther, userOther, 2, true) then
                            return false, 0
                        end
                    end
                end
            end
            for _, userSuit in pairs(userSuitCards) do
                score = score + HOKOM_DICT[getCardValue(userSuit)] --他的主牌分数
            end
            for _, userOther in pairs(userOtherCards) do
                score = score + SUN_DICT[getCardValue(userOther)] --他的副牌分数
            end
        end
        for _, card in pairs(maxSuitCards) do
            score = score + HOKOM_DICT[getCardValue(card)] --我的牌分
        end
        for _, card in pairs(maxOtherCards) do
            score = score + SUN_DICT[getCardValue(card)] --我的牌分
        end
    end
    return true, score
end

-- 计算手牌的顺子
-- 炸弹计算规则：只能用10,J,Q,K,A (其中A只能在sun玩法下计算)
function balootutil.calSequence(userCards, gametype, suitColor)
	local tbl = {}
	local size = {}
	local handInCards = table.copy(userCards)
	for i=#handInCards, 1, -1 do --先处理炸弹
		local value = getCardValue(handInCards[i])
		if 10 <= value and value <= 13 then
			if nil == size[value] then
				size[value] = 1
			else
				size[value] = size[value] +1
			end
		end

		if value == 14 and gametype == config.TYPE.SUN then
			if nil == size[value] then
				size[value] = 1
			else
				size[value] = size[value] +1
			end
		end
	end

	for val, num in pairs(size) do
		if num == 4 then
			local item = {['score'] = 100, ['cards'] = {}, ['ps'] = 100, ['stype']=3} --4张一样大小的给100分
			for i=#handInCards, 1 , -1 do
				if getCardValue(handInCards[i]) == val then
					table.insert(item['cards'], table.remove(handInCards, i))--1张牌只计算1次
				end
			end
			if val == 14 then
				item['score'] = 200 --但4张A 给400分
				item['ps'] = 200
                item['stype']=5 --排名用
			end
			table.insert(tbl, item)
		end
	end

	local cardsByColor = {}
	for _, card in pairs(handInCards) do
		local color = getCardColor(card)
		if nil == cardsByColor[color] then
			cardsByColor[color] = {}
		end
		table.insert(cardsByColor[color], {
			['card'] = card,
			['value'] = getCardValue(card)
		}) --按花色分开
	end
	for _, cards in pairs(cardsByColor) do --按花色算同花顺
		local i = #cards
		if i >= 2 then
			table.sort(cards, function(a,b) --大的排后面
				return a.card < b.card
			end)

			while i >= 2 do
				if i >= 5 then
					if (cards[i].value == (cards[i-1].value + 1)) and (cards[i-1].value == (cards[i-2].value + 1)) and (cards[i-2].value == (cards[i-3].value + 1))  and (cards[i-3].value == (cards[i-4].value + 1)) then
						local item = {
							['score'] = 100,
							['ps'] = 100,
							['cards'] = {cards[i].card, cards[i-1].card, cards[i-2].card, cards[i-3].card, cards[i-4].card},
                            ['stype']=4
						}
						table.insert(tbl, item)
						for j=1, 5 do
							table.remove(cards)
						end
						i = i -5
					elseif (cards[i].value == (cards[i-1].value + 1)) and (cards[i-1].value == (cards[i-2].value + 1)) and (cards[i-2].value == (cards[i-3].value + 1)) then
						local item = {
							['score'] = 50,
							['ps'] = 50,
							['cards'] = {cards[i].card, cards[i-1].card, cards[i-2].card, cards[i-3].card,},
                            ['stype']=2
						}
						table.insert(tbl, item)
						for j=1, 4 do
							table.remove(cards)
						end
						i=i-4
					elseif (cards[i].value == (cards[i-1].value + 1)) and (cards[i-1].value == (cards[i-2].value + 1)) then
						local item = {
							['score'] = 20,
							['ps'] = 20,
                            ['stype']=1,
							['cards'] = {cards[i].card, cards[i-1].card, cards[i-2].card}
						}
						table.insert(tbl, item)
						for j=1, 3 do
							table.remove(cards)
						end
						i=i-3
					elseif (cards[i].value == (cards[i-1].value + 1)) and cards[i].value == 13 and gametype == config.TYPE.HOKOM then
						local item = {
							['score'] = 20, 
							['ps'] = 200,--特意让它不同
							['cards'] = {cards[i].card, cards[i-1].card},
                            ['stype']=0
						}
						table.insert(tbl, item)
						for j=1, 2 do
							table.remove(cards)
						end
						i=i-2
					else
						i = i -1
					end
				elseif i >= 4 then
					if (cards[i].value == (cards[i-1].value + 1)) and (cards[i-1].value == (cards[i-2].value + 1)) and (cards[i-2].value == (cards[i-3].value + 1)) then
						local item = {
							['score'] = 50,
							['ps'] = 50,
							['cards'] = {cards[i].card, cards[i-1].card, cards[i-2].card, cards[i-3].card,},
                            ['stype']=2
						}
						table.insert(tbl, item)
						for j=1, 4 do
							table.remove(cards)
						end
						i=i-4
					elseif (cards[i].value == (cards[i-1].value + 1)) and (cards[i-1].value == (cards[i-2].value + 1)) then
						local item = {
							['score'] = 20,
							['ps'] = 20,
							['cards'] = {cards[i].card, cards[i-1].card, cards[i-2].card},
                            ['stype']=1
						}
						table.insert(tbl, item)
						for j=1, 3 do
							table.remove(cards)
						end
						i=i-3
					elseif (cards[i].value == (cards[i-1].value + 1)) and cards[i].value == 13 and gametype == config.TYPE.HOKOM then
						local item = {
							['score'] = 20, 
							['ps'] = 200,--特意让它不同
							['cards'] = {cards[i].card, cards[i-1].card},
                            ['stype']=0
						}
						table.insert(tbl, item)
						for j=1, 2 do
							table.remove(cards)
						end
						i=i-2
					else
						i = i -1
					end
				elseif i >= 3 then
					if (cards[i].value == (cards[i-1].value + 1)) and (cards[i-1].value == (cards[i-2].value + 1)) then
						local item = {
							['score'] = 20,
							['ps'] = 20,
							['cards'] = {cards[i].card, cards[i-1].card, cards[i-2].card},
                            ['stype']=1
						}
						table.insert(tbl, item)
						for j=1, 3 do
							table.remove(cards)
						end
						i=i-3
					elseif (cards[i].value == (cards[i-1].value + 1)) and cards[i].value == 13 and gametype == config.TYPE.HOKOM then
						local item = {
							['score'] = 20, 
							['ps'] = 20,--特意让它不同
							['cards'] = {cards[i].card, cards[i-1].card},
                            ['stype']=0
						}
						table.insert(tbl, item)
						for j=1, 2 do
							table.remove(cards)
						end
						i=i-2
					else
						i = i -1
					end
				elseif i>=2 then
					if (cards[i].value == (cards[i-1].value + 1)) and cards[i].value == 13 and gametype == config.TYPE.HOKOM and (getCardColor(cards[i].card) == suitColor) then
						local item = {
							['score'] = 20, 
							['ps'] = 200,--特意让它不同
							['cards'] = {cards[i].card, cards[i-1].card},
                            ['stype']=0
						}
						table.insert(tbl, item)
						for j=1, 2 do
							table.remove(cards)
						end
						i=i-2
					else
						i = i -1
					end
				else
					i = i -1
				end
			end
		end
	end
	return tbl
end

-- 计算手牌中A和10的个数
function balootutil.calATenCount(cards)
    local total = 0
    local cardA = {0x1E, 0x2E, 0x3E, 0x4E}
    local cardTen = {0x1A, 0x2A, 0x3A, 0x4A}
    for _, myCard in pairs(cards) do
        if table.contain(cardA, myCard) or table.contain(cardTen, myCard) then
            total = total + 1
        end
    end
    return total
end

-- 计算花色最多的牌
function balootutil.calColorCnt(cards)
    local maxColor, maxCnt = 0, 0
    local tmp = {}
    for _, card in pairs(cards) do
        local color = getCardColor(card)
        if nil == tmp[color] then
			tmp[color] = 0
		end
        tmp[color] = tmp[color] + 1
    end
    for color, cnt in pairs(tmp) do
        if cnt > maxCnt then
            maxCnt = cnt
            maxColor = color
        end
    end
    return maxColor, maxCnt
end

-- 获取指定玩法下，指定花色最大或最小的牌
-- @sortType 1:max 2:min
-- @handInCards 手牌
-- @gametype 玩法  1:sun, 2:hokom
-- @color 指定花色 
local function getSortedCardByType(sortType, handInCards, gametype, color)
    local DICT_SORT = SUN_SORT
    if gametype == 2 then
        DICT_SORT = HOKOM_SORT
    end
    local cards = handInCards
    if color then
        cards = {}
        for _, card in pairs(handInCards) do
            if getCardColor(card) == color then
                table.insert(cards, card)
            end
        end
        if #cards == 0 then
            cards = handInCards --没有指定花色的牌了
        end
    end
    local tmp= {}
    for k, val in ipairs(DICT_SORT) do
        tmp[k] = 0
        for key, card in pairs(cards) do
            if getCardValue(card) == val then
                tmp[k] = key
            end
        end
    end
    local outCard
    if sortType == 1 then --最大的牌
        for _, key in ipairs(tmp) do
            if key > 0 then
                outCard = cards[key]
                break
            end
        end
    else --最小的牌
        for i=#tmp, 1, -1 do
            if tmp[i] > 0 then
                outCard = cards[tmp[i]]
                break
            end
        end
    end
    return outCard
end

--Hokom 主花色 第1张牌a是否比b大 J > 9 > A > 10 > K > Q > 8 > 7
local function getHokomMaxCard(handInCards, suitColor)
    local cards = {}
    for _, card in pairs(handInCards) do
        if getCardColor(card) == suitColor then
            table.insert(cards, card)
        end
    end
    local outCard = 0
    if #cards > 0 then
        local tmp= {}
        for k, val in ipairs(HOKOM_SORT) do
            tmp[k] = 0
            for key, card in pairs(cards) do
                if getCardValue(card) == val then
                    tmp[k] = key
                end
            end
        end
        for _, key in ipairs(tmp) do
            if key > 0 then
                outCard = cards[key]
                return outCard
            end
        end
    end
    return outCard
end

local function getHokomMinCard(cards)
    local outCard = 0
    if #cards > 0 then
        local tmp= {}
        for k, val in ipairs(HOKOM_SORT) do
            tmp[k] = 0
            for key, card in pairs(cards) do
                if getCardValue(card) == val then
                    tmp[k] = key
                end
            end
        end
        for i=#tmp, 1, -1 do
            if tmp[i] > 0 then
                return cards[tmp[i]]
            end
        end
    end
    return outCard
end

-- 挑选最大的牌
local function getSunMaxCard(handInCards, color)
    local cards = {}
    if color then --指定花色
        for _, card in pairs(handInCards) do
            if getCardColor(card) == color then
                table.insert(cards, card)
            end
        end
    else
        cards = handInCards
    end
    local outCard = 0
    local tens = {}
    local cardVals = {0}
    for _, card in pairs(cards) do
        if card == 0x1E or card == 0x2E or card == 0x3E or card == 0x4E then --出A
            outCard = card
            return outCard
        end
        if card == 0x1A or card == 0x2A or card == 0x3A or card == 0x4A then --出10
            table.insert(tens, card)
        end

        local value = getCardValue(card)
        if value > cardVals[1] then
            outCard = card
            table.insert(cardVals, 1, value)
        else
            table.insert(cardVals, value)
        end
    end
    if #tens > 0 then
        outCard = tens[math.random(1, #tens)]
        return outCard
    end
    return outCard
end

local function getParterSeatid(user)
	local seatIdList = {1,3}
	if user.seatid % 2 == 0 then
		seatIdList = {2, 4}
	end
	for _, seatid in pairs(seatIdList) do
		if seatid ~= user.seatid then
			return seatid
		end
	end
end

--根据队友座位号 找到队友
local function getParterUser(seatid, deskInfo)
    for _, user in pairs(deskInfo.users) do
        if user.seatid == seatid then
            return user
        end
    end
end

local function randomCardInSun(cards, color)
    local tmpCards = {}
    if color then
        for _, card in pairs(cards) do
            if getCardColor(card) == color then
                table.insert(tmpCards, card)
            end
        end
        if #tmpCards == 0 then
            tmpCards = cards
        end
    else
        tmpCards = cards
    end
    local tmp = {}
    for _, card in pairs(tmpCards) do
        if getCardValue(card) ~= 11 then
            table.insert(tmp, card)
        end
    end
    if #tmp > 0 then
        return tmp[math.random(1, #tmp)]
    end
    if table.empty(tmpCards) then
        return 0
    end
    return tmpCards[math.random(1, #tmpCards)]
end

local function isSameColor(card, color)
    return getCardColor(card) == color
end

-- 获取sun玩法中最大的牌
function balootutil.getSunMaxCard(cards, color)
    return getSunMaxCard(cards, color)
end

-- 对比2张牌
function balootutil.compairCard(a, b, gametype, specifycolor)
    return compairCard(a, b, gametype, specifycolor)
end

--TODO: hokom玩法可能有bug
function balootutil.cardIsMax(card, cards, gametype, suit, roundShowCards)
    LOG_DEBUG("balootutil.cardIsMax card:", card, ' cards:', cards, ' gametype:', gametype, ' suit:', suit, ' roundShowCards:', roundShowCards)
    if config.TYPE.HOKOM == gametype then
        local mhkMax = getHokomMaxCard(cards, suit)
        if mhkMax ~= 0 then --有主花色的牌
            if compairCard(card, mhkMax, 1, true) then
                return true
            end
        else --桌面上和大家的手牌都没有主了
            local firstCardColor = getCardColor(card) --我的花色
            if roundShowCards and #roundShowCards > 0 then
                firstCardColor = getCardColor(roundShowCards[1]) --桌上第1个人的花色(副牌)
            end
            local maxcard = getSunMaxCard(cards, firstCardColor)
            if compairCard(card, maxcard, 2, false) then
                return true
            end
        end
    else
        local firstCardColor = getCardColor(card) --我的花色
        if roundShowCards and #roundShowCards > 0 then --桌面上第一个出牌的花色
            firstCardColor = getCardColor(roundShowCards[1])
        end
        LOG_DEBUG("balootutil.cardIsMax firstCardColor:", firstCardColor)
        local maxcard = getSunMaxCard(cards, firstCardColor)
        LOG_DEBUG("balootutil.cardIsMax maxcard:", maxcard)
        local ret = compairCard(card, maxcard, 2, false)
        LOG_DEBUG("balootutil.cardIsMax maxcard:", maxcard, ' card:', card, ' ret:', ret)
        if ret then
            return true
        end
    end
    return false
end

-- 智能自动出牌
-- @deskInfo 桌子信息
-- @user 我的信息， 手牌user.round.handInCards和座位seatid
--如果是第一家出牌，就出大牌
--如果是中间出牌，下家能管上我，就出小牌
--如果是最后出牌，能管上就出大牌，打不过，就出小牌
function balootutil.aiPutCard(user, deskInfo)
    local outCard = 0
    local cnt = #deskInfo.round.showCard --这一轮在“我”之前已出了的几张牌
    local cardListSuit = {} --主花色
    local otherColorList = {} --其他花色牌
    local firstCardColor= 0
    if #user.round.handInCards == 0 then
        return outCard
    end
    local parterSeatId = getParterSeatid(user)
    if deskInfo.panel.gametype == config.TYPE.HOKOM then
        for _, card in pairs(user.round.handInCards) do
            local color = getCardColor(card)
            if color == deskInfo.panel.suit then
                table.insert(cardListSuit, card)
            else
                table.insert(otherColorList, card)
            end
        end
    end
    LOG_DEBUG("aiPutCard uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' cardListSuit:', cardListSuit)
    if cnt == 0 then --作为第1家出牌
        if deskInfo.panel.gametype == config.TYPE.HOKOM then
            local canputSuitCard = true
            if deskInfo.panel.open == config.TYPE.LOCK and #otherColorList > 0 then
                canputSuitCard = false --LOCK后，每轮的第一个出牌，当有副牌的时候，就不能出主牌
            end
            if #cardListSuit > 0 and canputSuitCard then --我有主牌
                local hkMaxCard = getHokomMaxCard(cardListSuit, deskInfo.panel.suit)
                local isMax = true
                local usersMaxSuitCard = {}
                for _, muser in pairs(deskInfo.users) do
                    if muser.uid ~= user.uid and muser.seatid ~= parterSeatId then
                        local mhkMax = getHokomMaxCard(muser.round.handInCards, deskInfo.panel.suit)
                        usersMaxSuitCard[muser.uid] = mhkMax
                        if not compairCard(hkMaxCard, mhkMax, 1, true) then
                            isMax = false --最大的主牌小于对手的最大主牌
                            break
                        end
                    end
                end
                if isMax then
                    LOG_DEBUG("aiPutCard 作为第1家出牌 我有主牌 isMax true uid:", user.uid, ' cards:', user.round.handInCards, ' hkMaxCard:',hkMaxCard)
                    return hkMaxCard --我的主牌最大，直接出主牌
                else
                    isMax = true
                    local parter = getParterUser(user.seatid, deskInfo)
                    if parter then  --看看队友是不是主牌最大
                        isMax = true
                        local hkMaxCard2 = getHokomMaxCard(parter.round.handInCards, deskInfo.panel.suit)
                        for _, muser in pairs(deskInfo.users) do
                            if muser.uid ~= user.uid and muser.uid ~= parter.uid then
                                local mhkMax
                                if usersMaxSuitCard[muser.uid] then
                                    mhkMax = usersMaxSuitCard[muser.uid]
                                else
                                    mhkMax = getHokomMaxCard(muser.round.handInCards, deskInfo.panel.suit)
                                end
                                if not compairCard(hkMaxCard2, mhkMax, 1, true) then
                                    isMax = false --最大的主牌小于对手的最大主牌
                                    break
                                end
                            end
                        end
                        if isMax then
                            LOG_DEBUG("aiPutCard 作为第1家出牌 我有主牌 isMax false 我出主牌，队友能管上，那么我就出主牌 uid:", user.uid, ' cards:', user.round.handInCards, ' hkMaxCard:',hkMaxCard)
                            return hkMaxCard --我出主牌，队友能管上，那么我就出主牌
                        end
                    end
                end
            end
            --考虑我有主牌但是不是最大 或者我没有主牌的情况
            local sunMaxCard = getSunMaxCard(otherColorList) --直接出副牌里最大的牌
            if sunMaxCard == 0 then
                local hkMaxCard = getHokomMaxCard(cardListSuit, deskInfo.panel.suit)
                LOG_DEBUG("aiPutCard 作为第1家出牌 我有主牌 考虑我有主牌但是不是最大 或者我没有主牌的情况 截胡 uid:", user.uid, ' cards:', user.round.handInCards, ' sunMaxCard:',sunMaxCard)
                return hkMaxCard
            end
            LOG_DEBUG("aiPutCard 作为第1家出牌 我有主牌 考虑我有主牌但是不是最大 或者我没有主牌的情况 uid:", user.uid, ' cards:', user.round.handInCards, ' sunMaxCard:',sunMaxCard)
            return sunMaxCard
        else --sun玩法
            local card = getSunMaxCard(user.round.handInCards)
            LOG_DEBUG("aiPutCard 作为第1家出牌 sun玩法 挑我最大的出 uid:", user.uid, ' cards:', user.round.handInCards, ' card:',card)
            return card --挑我最大的出
        end
    else
        firstCardColor = getCardColor(deskInfo.round.showCard[1])
        if cnt == 3 then --第4个出牌
            local parterCard = deskInfo.round.showCard[2]
            if deskInfo.panel.gametype == config.TYPE.HOKOM then --hokom玩法
                local parterIsSuit = isSameColor(parterCard, firstCardColor)
                if firstCardColor == deskInfo.panel.suit then --打主牌
                    if parterIsSuit then
                        if compairCard(parterCard, deskInfo.round.showCard[1], 1, true) and compairCard(parterCard, deskInfo.round.showCard[3], 1, true) then
                            --队友赢了
                            local outpucard
                            if #cardListSuit > 0 then
                                --主牌里随便打一张
                                outpucard = cardListSuit[math.random(1, #cardListSuit)]
                                LOG_DEBUG("aiPutCard 第4个出牌 队友赢了 主牌里随便打一张 uid:", user.uid, ' cards:', user.round.handInCards, ' card:',outpucard, ' cardListSuit:', cardListSuit)
                                 
                            else
                                --副牌里随便打一张
                                -- print('1第4个出牌, 队友赢了, 副牌里随便打一张 uid:', user.uid, ' cards:', user.round.handInCards, ' otherColorList:', otherColorList)
                                outpucard = randomCardInSun(otherColorList)
                                LOG_DEBUG("第4个出牌 队友赢了 副牌里随便打一张 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, 'outpucard:', outpucard)
                            end
                            return outpucard
                        end
                    end

                    --队友输了
                    local hkMaxCard = getHokomMaxCard(user.round.handInCards, deskInfo.panel.suit)
                    if hkMaxCard == 0 then
                        local outpucard = randomCardInSun(user.round.handInCards)
                        LOG_DEBUG("第4个出牌 队友输了 没主牌，反正打不过，随便出了 uid:", user.uid, ' cards:', user.round.handInCards, ' outpucard:', outpucard)
                        return outpucard --没主牌，反正打不过，随便出了
                    else
                        if compairCard(hkMaxCard, deskInfo.round.showCard[1], 1, true) and compairCard(hkMaxCard, deskInfo.round.showCard[3], 1, true) then
                            LOG_DEBUG("第4个出牌 队友输了 我的主牌最大，能管上就打 uid:", user.uid, ' cards:', user.round.handInCards, ' hkMaxCard:', hkMaxCard)
                            return hkMaxCard --我的主牌最大，能管上就打
                        else
                            local outpucard =  getHokomMinCard(cardListSuit)
                            LOG_DEBUG("第4个出牌 队友输了 我的最大主牌都管不上，挑最小的主牌出 uid:", user.uid, ' cards:', user.round.handInCards, ' outpucard:', outpucard)
                            return outpucard --我的最大主牌都管不上，挑最小的主牌出
                        end
                    end
                else --打副牌
                    if parterIsSuit then --队友出了主牌
                        if compairCard(parterCard, deskInfo.round.showCard[3], 1, true) then --队友赢, 掌控全场
                            if #otherColorList > 0 then
                                LOG_DEBUG("第4个出牌 打副牌 队友出了主牌 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' firstCardColor:', firstCardColor)
                                outCard = randomCardInSun(otherColorList, firstCardColor) --副牌里，这个花色里随便打一张
                                if outCard == 0 then
                                    local outpucard =  randomCardInSun(otherColorList)
                                    LOG_DEBUG("第4个出牌 打副牌 队友出了主牌 没有这个花色的副牌，随便打一张 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outpucard:', outpucard)
                                    return outpucard --没有这个花色的副牌，随便打一张
                                end
                            else
                                local outpucard =  getHokomMinCard(cardListSuit)
                                LOG_DEBUG("第4个出牌 打副牌 队友出了主牌 主牌里打一张最小的 uid:", user.uid, ' cards:', user.round.handInCards, ' cardListSuit:',cardListSuit, ' outpucard:', outpucard)
                                return outpucard --主牌里打一张最小的
                            end
                        else --队友的主牌被第3家管上了, 说明第3家是主牌
                            local maxCard = getSunMaxCard(user.round.handInCards, firstCardColor)
                            if maxCard == 0 then --我没有此花色的副牌
                                local hkMaxCard = getHokomMaxCard(user.round.handInCards, deskInfo.panel.suit)
                                if hkMaxCard == 0 then
                                    local outCard = randomCardInSun(user.round.handInCards) 
                                    LOG_DEBUG("第4个出牌 队友的主牌被第3家管上了, 说明第3家是主牌 我没有此花色的副牌 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                                    return outCard --没主牌，反正打不过，随便出了
                                else
                                    if compairCard(hkMaxCard, deskInfo.round.showCard[3], 1, true) then
                                        LOG_DEBUG("第4个出牌 队友的主牌被第3家管上了, 说明第3家是主牌 我的主牌最大，能管上就打 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' hkMaxCard:', hkMaxCard)
                                        return hkMaxCard --我的主牌最大，能管上就打
                                    else
                                        local outCard
                                        if #otherColorList > 0 then --我的最大主牌，打不过第3家，优先考虑出副牌
                                            outCard = randomCardInSun(otherColorList) --没有这个花色的副牌，随便打一张
                                            LOG_DEBUG("第4个出牌 打副牌 我的最大主牌，打不过第3家，优先考虑出副牌 我没有此花色的副牌 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                                        else
                                            outCard = getHokomMinCard(cardListSuit) --主牌里打一张最小的
                                            LOG_DEBUG("第4个出牌 打副牌 我的最大主牌，打不过第3家，主牌里打一张最小的 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                                        end
                                        return outCard
                                    end
                                end
                            else
                                local outCard = randomCardInSun(otherColorList, firstCardColor)
                                LOG_DEBUG("第4个出牌 打副牌 我的最大主牌，打不过第3家  我有此花色的副牌 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                                return outCard
                            end
                        end
                    else --队友出了副牌
                        local maxCard = getSunMaxCard(user.round.handInCards, firstCardColor)
                        if getCardColor(deskInfo.round.showCard[3]) == deskInfo.panel.suit then --第3家出了主牌
                            if maxCard == 0 then --我没有此花色的副牌
                                local hkMaxCard = getHokomMaxCard(user.round.handInCards, deskInfo.panel.suit)
                                if hkMaxCard == 0 then
                                    local outCard = randomCardInSun(user.round.handInCards) --没主牌，反正打不过，随便出了
                                    LOG_DEBUG("第4个出牌 打副牌 队友出了副牌  我没有此花色的副牌 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                                    return outCard
                                else
                                    if compairCard(hkMaxCard, deskInfo.round.showCard[3], 1, true) then
                                        LOG_DEBUG("第4个出牌 打副牌 队友出了副牌  我的主牌最大，能管上就打 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' hkMaxCard:', hkMaxCard)
                                        return hkMaxCard --我的主牌最大，能管上就打
                                    else
                                        local outCard
                                        if #otherColorList > 0 then --我的最大主牌，打不过第3家，优先考虑出副牌
                                            
                                
                                            outCard = randomCardInSun(otherColorList) --没有这个花色的副牌，随便打一张
                                            LOG_DEBUG("第4个出牌 打副牌 队友出了副牌  没有这个花色的副牌，随便打一张 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                                        else
                                            outCard = getHokomMinCard(cardListSuit) --主牌里打一张最小的
                                            LOG_DEBUG("第4个出牌 打副牌 队友出了副牌  主牌里打一张最小 uid:", user.uid, ' cards:', user.round.handInCards, ' cardListSuit:',cardListSuit, ' outCard:', outCard)
                                        end
                                        return outCard
                                    end
                                end
                            else
                                local outCard = randomCardInSun(otherColorList, firstCardColor)
                                LOG_DEBUG("第4个出牌 打副牌 队友出了副牌  我有此花色的副牌  uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                                return outCard
                            end
                        else
                            if maxCard == 0 then --我没有此花色的副牌
                                local _card = getHokomMinCard(cardListSuit) --主牌里打一张最小的
                                if _card == 0 then  -- 如果没有主牌，则随便打一张
                                    local outCard = randomCardInSun(otherColorList)
                                    LOG_DEBUG("第4个出牌 打副牌 我没有此花色的副牌 如果没有主牌，则随便打一张  uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                                    return outCard
                                else
                                    LOG_DEBUG("第4个出牌 打副牌 我没有此花色的副牌 主牌里打一张最小的  uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', _card)
                                    return _card
                                end
                            else
                                if compairCard(maxCard, deskInfo.round.showCard[1], 2, false) and compairCard(maxCard, deskInfo.round.showCard[3], 2, false) then --我挑选了最大的副牌，打不过
                                    LOG_DEBUG("第4个出牌 打副牌 我有此花色的副牌 我挑选了最大的副牌，打不过  uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', maxCard)
                                    return maxCard
                                end
                                local outCard = randomCardInSun(otherColorList, firstCardColor) --没有这个花色的副牌，随便打一张
                                LOG_DEBUG("第4个出牌 打副牌 队友出了副牌2222222  没有这个花色的副牌，随便打一张  uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                                return  outCard
                            end
                        end
                    end
                end
            else
                if compairCard(parterCard, deskInfo.round.showCard[1], 2, false) and compairCard(parterCard, deskInfo.round.showCard[3], 2, false) then --队友的牌最大
                    local outCard = randomCardInSun(user.round.handInCards, firstCardColor)
                    LOG_DEBUG("第4个出牌 打副牌 33333  队友的牌最大  uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                                
                    return outCard
                end
                
                local maxcard = getSunMaxCard(user.round.handInCards, firstCardColor)
                if maxcard == 0 then
                    local outCard =  randomCardInSun(user.round.handInCards) --没有此花色的牌
                    LOG_DEBUG("第4个出牌 打副牌 44444  没有此花色的牌  uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                    return outCard
                end
                if not compairCard(maxcard, deskInfo.round.showCard[1], 2, false) or not compairCard(maxcard, deskInfo.round.showCard[3], 2, false) then
                    local outCard = randomCardInSun(user.round.handInCards, firstCardColor)
                    LOG_DEBUG("第4个出牌 打副牌 55555  队友的牌最大  uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                       
                    return outCard
                end
                return maxcard
            end
        elseif cnt==2 then --第3个出牌
            local parterCard = deskInfo.round.showCard[1]
            if deskInfo.panel.gametype == config.TYPE.HOKOM then
                if firstCardColor == deskInfo.panel.suit then --队友打主牌
                    if compairCard(parterCard, deskInfo.round.showCard[2], 1, true) then --队友是不是大第2个人的牌
                        if #cardListSuit > 0 then
                            local outCard = cardListSuit[math.random(1, #cardListSuit)]
                            LOG_DEBUG("第3个出牌 队友牌比较大，随便出 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                            return outCard --队友牌比较大，随便出
                        else
                            local outCard = randomCardInSun(user.round.handInCards)
                            LOG_DEBUG("第3个出牌 33 我没主牌，无能为力 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                            return  outCard --我没主牌，无能为力
                        end
                    else
                        local hkMaxCard = getHokomMaxCard(user.round.handInCards, deskInfo.panel.suit)
                        if hkMaxCard == 0 then
                            local outCard =  randomCardInSun(user.round.handInCards) --我没主牌，无能为力
                            LOG_DEBUG("第3个出牌 44 我没主牌，无能为力 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                            return outCard
                        else
                            if compairCard(hkMaxCard, deskInfo.round.showCard[2], 1, true) then
                                LOG_DEBUG("第3个出牌 41 能管上就打 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', hkMaxCard)
                                return hkMaxCard --能管上就打
                            else
                                local outCard = getHokomMinCard(cardListSuit)
                                LOG_DEBUG("第3个出牌 42 挑最小的主牌打 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                                return outCard --挑最小的主牌打
                            end
                        end
                    end
                else --队友打副牌
                    local maxCard = getSunMaxCard(user.round.handInCards, firstCardColor)
                    if getCardColor(deskInfo.round.showCard[2]) == firstCardColor then
                        if maxCard == 0 then --我没有此花色的副牌
                            local hkMaxCard = getHokomMaxCard(user.round.handInCards, deskInfo.panel.suit)
                            if hkMaxCard == 0 then
                                local outCard = randomCardInSun(user.round.handInCards, firstCardColor)
                                LOG_DEBUG("第3个出牌 55 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                                return outCard --没主牌，反正打不过，随便出了
                            else
                                if compairCard(hkMaxCard, deskInfo.round.showCard[2], 1, true) then
                                    LOG_DEBUG("第3个出牌 51 我的主牌最大，能管上就打 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' hkMaxCard:', hkMaxCard)
                                    return hkMaxCard --我的主牌最大，能管上就打
                                else
                                    local outCard
                                    if #otherColorList > 0 then --我的最大主牌打不过第2家，优先考虑出副牌
                                        outCard =  randomCardInSun(otherColorList) --没有这个花色的副牌，随便打一张
                                        LOG_DEBUG("第3个出牌 66 没有这个花色的副牌，随便打一张 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                                    else
                                        outCard =  getHokomMinCard(cardListSuit) --主牌里打一张最小的
                                        LOG_DEBUG("第3个出牌 66 主牌里打一张最小的 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                                    end
                                    return outCard
                                end
                            end
                        else
                            
                            local outCard = randomCardInSun(user.round.handInCards, firstCardColor)
                            LOG_DEBUG("第3个出牌 77 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                            return outCard
                        end
                    else
                        if maxCard == 0 then --我没有此花色的副牌
                            local outCard
                            if #cardListSuit > 0 then
                                outCard = cardListSuit[math.random(1, #cardListSuit)] --随便出主牌
                                LOG_DEBUG("第3个出牌 71 随便出主牌 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                            else
                                outCard = user.round.handInCards[math.random(1, #user.round.handInCards)] --随便出牌
                                LOG_DEBUG("第3个出牌 72 随便出牌 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                            end
                            return outCard
                        else
                            if compairCard(maxCard, deskInfo.round.showCard[2], 2, false) then --我挑选了最大的副牌，打不过
                                LOG_DEBUG("第3个出牌 81 我挑选了最大的副牌，打不过 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' maxCard:', maxCard)
                                return maxCard
                            end
                            
                            local outCard = randomCardInSun(otherColorList, firstCardColor) --没有这个花色的副牌，随便打一张
                            LOG_DEBUG("第3个出牌 88 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                            return outCard
                        end
                    end
                end
            else
                
                if compairCard(parterCard, deskInfo.round.showCard[2], 2, false) then --队友的牌最大
                    local outCard = randomCardInSun(user.round.handInCards, firstCardColor)
                    LOG_DEBUG("第3个出牌 11 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                    return outCard
                else
                    local maxCard = getSunMaxCard(user.round.handInCards, firstCardColor)
                    LOG_DEBUG("第3个出牌 22 uid:", user.uid, " maxCard:", maxCard)
                    if maxCard == 0 then --我没有此花色的副牌
                        local outCard =  randomCardInSun(user.round.handInCards, firstCardColor) --随便出牌
                        LOG_DEBUG("第3个出牌 23 uid:", user.uid, " outCard:", outCard)
                        return outCard
                    else
                        if compairCard(maxCard, deskInfo.round.showCard[2], 2, false) then --我挑选了最大的副牌，打不过
                            LOG_DEBUG("第3个出牌 21 我挑选了最大的副牌，打不过 uid:", user.uid, " maxCard:", maxCard)
                            return maxCard
                        end
                        local outCard = randomCardInSun(user.round.handInCards, firstCardColor) --没有这个花色的副牌，随便打一张
                        LOG_DEBUG("第3个出牌 20 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                        return outCard
                    end
                end
            end
        else --第2个出牌
            if deskInfo.panel.gametype == config.TYPE.HOKOM then
                local hkMaxCard = getHokomMaxCard(user.round.handInCards, deskInfo.panel.suit)
                if firstCardColor == deskInfo.panel.suit then --打主牌
                    if hkMaxCard == 0 then --我没有主牌
                        local outCard = randomCardInSun(user.round.handInCards)
                        LOG_DEBUG("第2个出牌 11 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                        return outCard
                    end
                    
                    if compairCard(hkMaxCard, deskInfo.round.showCard[1], 1, true) then
                        LOG_DEBUG("第2个出牌 11 能管上就打 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' hkMaxCard:', hkMaxCard)
                        return hkMaxCard --能管上就打
                    end
                    return getHokomMinCard(cardListSuit)
                else
                    local maxCard = getSunMaxCard(user.round.handInCards, firstCardColor)
                    if maxCard == 0 then
                        local outCard
                        if #cardListSuit > 0 then
                            outCard = cardListSuit[math.random(1, #cardListSuit)]
                            LOG_DEBUG("第2个出牌 22 主牌里随便打一张 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                            return outCard--主牌里随便打一张
                        end
                        outCard = randomCardInSun(otherColorList) --副牌里随便打一张
                        LOG_DEBUG("第2个出牌 22 副牌里随便打一张 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                        return outCard
                    else
                        if compairCard(maxCard, deskInfo.round.showCard[1], 2, false) then
                            LOG_DEBUG("第2个出牌 33 能管上就打 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' maxCard:', maxCard)
                            return maxCard --能管上就打
                        end
                        local outCard = randomCardInSun(otherColorList, firstCardColor)
                        LOG_DEBUG("第2个出牌 33111 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                        return outCard
                    end
                end
            else
                local maxCard = getSunMaxCard(user.round.handInCards, firstCardColor)
                if maxCard == 0 then
                    local outCard = randomCardInSun(user.round.handInCards, firstCardColor) --副牌里随便打一张
                    LOG_DEBUG("第2个出牌 51 副牌里随便打一张 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                    return outCard
                else
                    if compairCard(maxCard, deskInfo.round.showCard[1], 2, false) then
                        LOG_DEBUG("第2个出牌 52 能管上就打 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' maxCard:', maxCard)
                        return maxCard --能管上就打
                    end
                    local outCard = randomCardInSun(user.round.handInCards, firstCardColor)
                    LOG_DEBUG("第2个出牌 55 uid:", user.uid, ' cards:', user.round.handInCards, ' otherColorList:',otherColorList, ' outCard:', outCard)
                    return outCard
                end
            end
        end
    end
    return outCard
end

return balootutil