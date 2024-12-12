local cluster = require "cluster"
local config = require"cashslots.common.config"
local settleTool = require "cashslots.common.gameSettle"
local freeTool = require"cashslots.common.gameFree"
local skynet  = require "skynet"

--================套用通用免费检测方法====================
local function checkFreeGameFuc(deskInfo, _cards, gameConf)
	local freeGameConf = gameConf.freeGameConf
	return freeTool.checkFreeGame(_cards, freeGameConf)
end
--=================根据配置权重取牌==========================
local function get_col_cards(cardmap, col, col_num, row_num)
	local startIdx = math.random(1, #cardmap[col]) -- 从后往前取
	local col_cards = {} 
	local  endIdx = startIdx < row_num and startIdx or row_num
	for j = 1, endIdx do
		table.insert(col_cards, cardmap[col][startIdx - j + 1])
	end

	if startIdx < row_num then -- 不连续的取, 需要呈现卷轴方式的的取
		for j = #cardmap[col], #cardmap[col] - row_num - startIdx, -1 do
			table.insert(col_cards, cardmap[col][j])
		end
	end
	return col_cards, startIdx
end

local function get_15_cards(cardmap, col_num, row_num )
	col_num = col_num or 5
	row_num = row_num or 3
	local cards = {}
	local col_start_idx = {}
	for col = 1, col_num do
		local col_cards, startIdx = get_col_cards(cardmap, col, col_num, row_num)
		col_start_idx[col] = startIdx

		local col_idxs = {}
		for row = 1, row_num do
			table.insert(col_idxs, col + (col_num)*(row - 1) )
		end

		for i, idx in ipairs(col_idxs) do
			cards[idx] = col_cards[i]
		end
	end
	return cards, col_start_idx
end

--获取卷轴
local function getCardMap(deskInfo, mapKey)
	local isFree = deskInfo.state == config.GAME_STATE["FREE"]
	if mapKey == nil then
		mapKey = "cardmap"
	end
	local scroll = require ("cashslots.config.scroll.scroll_"..deskInfo.gameid)
	local map = scroll[mapKey]
	if isFree then
    	if mapKey == "cardmap" and scroll.freemap then
    		map = scroll.freemap
    	end
	end
	return map
end


local function getWinResultCards(deskInfo, gameConf)
	local cardmap = getCardMap(deskInfo)
	local col_num = gameConf and (gameConf.COL_NUM or gameConf.x or 5) or 5
    local row_num = gameConf and (gameConf.ROW_NUM or gameConf.y or 3) or 3

	return get_15_cards(cardmap, col_num, row_num)
end




-- =================================根据概率发牌======================================
local free_exceed_cnt = 0
local function get_free_cards(deskInfo, gameConf, needFreeCards, checkFreeFunc, getCardsFunc, funList)
	local num = 0
	local resultCards
	while true do
		num = num + 1
		resultCards = getCardsFunc(deskInfo, gameConf)

		local freeResult = checkFreeFunc(deskInfo, resultCards, gameConf)
		if needFreeCards and  not table.empty(freeResult) then
			if funList and funList.checkSubGame then 
				local isTriggerSub = funList.checkSubGame(deskInfo, gameConf, resultCards)
				if not isTriggerSub then
					return resultCards, true
				end
			else
				return resultCards, true
			end
		end
		if not needFreeCards and table.empty(freeResult) then
			return resultCards, false
		end
		if num > 1000 then
            LOG_ERROR("get_free_cards failed exceeded error", deskInfo.gameid, needFreeCards)
            if TEST_RTP then
                free_exceed_cnt = free_exceed_cnt + 1
                sprint("get_free_cards failed exceeded error", free_exceed_cnt)
            end
			break
		end
	end
	return resultCards, false
end

local sub_exceed_cnt = 0
local function get_sub_cards(deskInfo, gameConf, needSubCards, checkSubGame, getCardsFunc, checkFree)
	local num = 0
	local resultCards
	while true do
		num = num + 1
		resultCards = getCardsFunc(deskInfo, gameConf)

		local isTriggerSub = checkSubGame(deskInfo, gameConf, resultCards)
		if needSubCards and isTriggerSub then
			if checkFree then
				local freeResult = checkFree(deskInfo, resultCards, gameConf)
				if table.empty(freeResult) then
					return resultCards, true
				end
			else
				return resultCards, true
			end
		end
		if not needSubCards and not isTriggerSub then
			return resultCards, false
		end
		if num > 1000 then
            LOG_ERROR("get_sub_cards failed exceeded error", deskInfo.gameid, needSubCards)
            if TEST_RTP then
                sub_exceed_cnt = sub_exceed_cnt + 1
                sprint("get_sub_cards failed exceeded error", sub_exceed_cnt)
            end
			break
		end
	end
	return resultCards, false
end

local function checkNoFreeNoSubNoFullCards(deskInfo, gameConf, funList, cards)
	local _cards = table.copy(cards)
	local checkFree  = funList and funList.checkFreeGame or checkFreeGameFuc
	local freeResult = checkFree(deskInfo, _cards, gameConf)

	local isTriggerSub = false
	if funList and funList.checkSubGame then
		isTriggerSub = funList.checkSubGame(deskInfo, gameConf, _cards)
	end

	local isFullScreen = false
	if funList and funList.checkFullScreen then
		isFullScreen = funList.checkFullScreen(deskInfo, gameConf, _cards)
	end

	local getBigGameResult = funList and funList.getBigGameResult or settleTool.getBigGameResult
	local winCoin = getBigGameResult(deskInfo, _cards, gameConf)

	return winCoin, freeResult, isTriggerSub, isFullScreen
end

-- 免费游戏中最后几局获取一副必赢的牌
local function getFreeWinCards(deskInfo, gameConf, funList, tmp_cards, tmp_col_start_idxs)
    local cards = table.copy(tmp_cards) 
    local col_start_idxs = tmp_col_start_idxs
    local getCardsFunc = funList and funList.getResultCards or  getWinResultCards

    for i = 1, 100 do 
        local winCoin, freeResult, isTriggerSub, isFullScreen = checkNoFreeNoSubNoFullCards(deskInfo, gameConf, funList, cards)
        local condition_1 = table.empty(freeResult) and not isTriggerSub and not isFullScreen
        if  condition_1 and winCoin > 0  then
            return cards, col_start_idxs 
        else
            cards, col_start_idxs = getCardsFunc(deskInfo, gameConf)
        end
    end
    LOG_ERROR("get_must_free_win_cards failed exceeded error", deskInfo.gameid)
    if TEST_RTP then
        sprint("get_must_free_win_cards failed exceeded error")
    end
    return cards, col_start_idxs
end

-- 普通游戏中取一副必赢的牌
local function getMustWinCards(deskInfo, gameConf, funList)
    local getCardsFunc = funList and funList.getResultCards or getWinResultCards
    local cards, col_start_idxs = getCardsFunc(deskInfo, gameConf)
    for i = 1, 100 do
        local winCoin, freeResult, isTriggerSub, isFullScreen = checkNoFreeNoSubNoFullCards(deskInfo, gameConf, funList, cards)
        local condition_1 = table.empty(freeResult) and not isTriggerSub and not isFullScreen
        if  condition_1 and winCoin > 0  then
            return cards, col_start_idxs
        else
            cards, col_start_idxs = getCardsFunc(deskInfo, gameConf,funList)
        end
    end
    LOG_ERROR("get_must_win_cards_in_normal_game exceeded error, deskInfo.gameid:", deskInfo.gameid)
    if TEST_RTP then
        sprint("get_must_win_cards failed exceeded error")
    end
    return cards, col_start_idxs
end

local function getNoFreeNoSubNoFullCards(deskInfo, gameConf, funList, loseType)
	local caulCnt = 0
	while true do 
		caulCnt = caulCnt + 1
		local getCardsFunc = funList and funList.getResultCards or getWinResultCards
		local cards, col_start_idxs = getCardsFunc(deskInfo, gameConf)
		local winCoin, freeResult, isTriggerSub, isFullScreen = checkNoFreeNoSubNoFullCards(deskInfo, gameConf, funList, cards)

		if table.empty(freeResult) and not isTriggerSub and not isFullScreen then
			local isEligibleCards = false
			if not loseType then
				local isFree = deskInfo.state == config.GAME_STATE["FREE"]
				if not isFree then
					isEligibleCards = true
				else
					-- 代码中配置：mustWinFreeCoin 免费必赢金币；剩余免费次数小于等于3次，没有赢到过金币。
					if gameConf.mustWinFreeCoin and deskInfo.freeGameData.restFreeCount <= 3 and deskInfo.freeGameData.freeWinCoin == 0 and winCoin == 0 then
						cards, col_start_idxs = getFreeWinCards(deskInfo, gameConf, funList, cards)
						if cards ~= nil then
							isEligibleCards = true
						end
					else
						isEligibleCards = true
					end
				end
			elseif winCoin == 0 then
				isEligibleCards = true
			end

			if isEligibleCards then
				return cards, col_start_idxs
			end
		end

		if caulCnt > 1000 then
			-- if loseType then
			-- 	assert()
			-- else
			return cards, col_start_idxs
			-- end
		end
	end
end

local function getLoseResultCards(deskInfo, gameConf, funList)
	if funList and funList.getLoseResultCards then
		return funList.getLoseResultCards(deskInfo, gameConf)
	end
	return getNoFreeNoSubNoFullCards(deskInfo, gameConf, funList, true)
end

local DEFAULT_THRESHOLD_COMMON = 80  -- 默认普通卷轴阈值
local DEFAULT_THRESHOLD_FREE = 100  -- 默认免费卷轴阈值

-- 一局，只会触发免费游戏或者小游戏中的一个。
local function get_cards(deskInfo, gameConf, funList)
    local w_l_random = math.random(1, 100)
    local control = deskInfo.control
    local deskFree = deskInfo.state == config.GAME_STATE["FREE"]

    local threshold = deskFree and DEFAULT_THRESHOLD_FREE or DEFAULT_THRESHOLD_COMMON
    if control and control.threshold then
        if deskFree then
            threshold = control.threshold.free or DEFAULT_THRESHOLD_FREE
        else
            threshold = control.threshold.common or DEFAULT_THRESHOLD_COMMON
        end
    end

    --DEBUG
    local user_id_game_id_str = "uid:"..deskInfo.user.uid.." gameid:"..deskInfo.gameid
    LOG_DEBUG(user_id_game_id_str.." random_threshold:"..w_l_random..' threshold:'..threshold)

    local freeCoeff = 1.0
    if deskFree and deskInfo.freeGameData then  --这里暂时保留一定的免费游戏的触发概率系数，避免调整后数值变动过大，后期数值跳过后再改回来
        local allFreeCount = deskInfo.freeGameData.allFreeCount
        if allFreeCount and allFreeCount >= 8 then
            freeCoeff = math.max(0.2, 4.0/allFreeCount)
        else
            freeCoeff = 0.5
        end
    end
    local getCardsFunc = funList and funList.getResultCards or getWinResultCards
    local resultCards = getCardsFunc(deskInfo, gameConf)
    local checkFree
    if control then
        if control.freeControl and nil == gameConf.noFree then
            local random_free = math.random()*1000

            checkFree  = funList and funList.checkFreeGame or checkFreeGameFuc
            local freeResult = checkFree(deskInfo, resultCards, gameConf)

            -- 免费游戏
            local free_probability = control.freeControl.probability * freeCoeff
            if deskFree then
                if gameConf.free_in_free_control then  --新增判断条件，有的游戏，免费中不可触发免费游戏。
                    free_probability = gameConf.free_in_free_control
                end
            end

            local trigger_free = (random_free < free_probability)
            LOG_DEBUG(user_id_game_id_str.." trigger_free:"..tostring(trigger_free).." random_free:"..random_free.." free_probability:"..free_probability)
            if trigger_free then
                local cards, triggerd = get_free_cards(deskInfo, gameConf, true, checkFree, getCardsFunc, funList)
                if triggerd then
                    deskInfo.strategy:onAutoTriggerFree(deskInfo)
                end
                return cards
            elseif not table.empty(freeResult) then-- 如果这幅牌是触发免费游戏的，那么换掉。
                return getNoFreeNoSubNoFullCards(deskInfo, gameConf, funList)
            end
        end

        if funList and funList.checkSubGame then
            local random_sub = math.random()*1000
            local isTriggerSub = funList.checkSubGame(deskInfo, gameConf, resultCards)

            local bonus_probability = control.bonusControl.probability * freeCoeff
            if deskFree then
                if deskInfo.freeGameData and deskInfo.freeGameData.restFreeCount and deskInfo.freeGameData.restFreeCount <= 1 then  --免费游戏最后一局不触发Bonus游戏
                    bonus_probability = 0
                end
            end
            local trigger_sub = (random_sub < bonus_probability)
            LOG_DEBUG(user_id_game_id_str.." trigger_sub:"..tostring(trigger_sub).." random_sub:"..random_sub.." bonus_probability:"..bonus_probability)
            if trigger_sub then
                if isTriggerSub then
                    deskInfo.strategy:onAutoTriggerBonus(deskInfo)
                    return resultCards
                else
                    local cards, triggerd = get_sub_cards(deskInfo, gameConf, true, funList.checkSubGame, getCardsFunc, checkFree)
                    if triggerd then
                        deskInfo.strategy:onAutoTriggerBonus(deskInfo)
                    end
                    return cards
                end
            elseif isTriggerSub then
                return getNoFreeNoSubNoFullCards(deskInfo, gameConf, funList)
            end
        end

        if funList and funList.checkFullScreen and funList.get_full_cards then
            local random_full = math.random()*1000
            local isTriggerFull = funList.checkFullScreen(deskInfo, gameConf, resultCards)
            local get_full_cards = funList.get_full_cards
            if random_full < control.fullScreenControl.probability then
                if isTriggerFull then
                    return resultCards
                else
                    return get_full_cards(deskInfo, gameConf, true)
                end	
            elseif isTriggerFull then
                return getNoFreeNoSubNoFullCards(deskInfo, gameConf, funList)
            end
        end

        if not deskFree and w_l_random > threshold then
            local func =  funList and funList.getLoseResultCards or getLoseResultCards
            return func(deskInfo, gameConf, funList)
        end
    else
        if not deskFree and w_l_random > threshold then
            local func =  funList and funList.getLoseResultCards or getLoseResultCards
            return func(deskInfo, gameConf, funList)
        end
    end

    if deskFree and gameConf.mustWinFreeCoin and deskInfo.freeGameData.restFreeCount <= 3 and deskInfo.freeGameData.freeWinCoin == 0 then
        resultCards = getFreeWinCards(deskInfo, gameConf, funList, resultCards)
    end

    return resultCards
end

local function get_you_15_cards(deskInfo, gameConf, funList)
	return get_cards(deskInfo, gameConf, funList)
end

return {
	get_cards_1 = get_15_cards, 			--根据传入的卡牌配置以及规则
	get_cards_2 = getWinResultCards,	--与概率无关取15张卡牌, 根据规则取牌
	get_cards_3 = get_you_15_cards,	--根据概率控制取牌
	getCardMap = getCardMap , --获取游戏的卷轴配置
}