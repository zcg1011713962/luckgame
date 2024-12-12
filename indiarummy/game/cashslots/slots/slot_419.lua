--[[
	老虎
	和测试确认过：免费游戏中也会收集金币，收集满也会触发地图免费游戏
	特殊游戏：
	1.地图收集游戏(N77, 地图免费游戏)
	2.bonus游戏(respin类型)，地图免费中不能触发
]]
local skynet  = require "skynet"
local cluster = require "cluster"
local config = require"cashslots.common.config"
local cardProcessor = require "cashslots.common.cardProcessor"
local settleTool = require "cashslots.common.gameSettle"
local cashBaseTool = require "cashslots.common.base"
local freeTool = require "cashslots.common.gameFree"
local recordTool = require "cashslots.common.gameRecord"
local N77 = require "cashslots.common.gameN77"
local utils = require "cashslots.common.utils"
local baseRecord = require "base.record"
local updateFreeData = freeTool.updateFreeData
local isFreeState = freeTool.isFreeState
local gameData = recordTool.gameData
local record = recordTool.pushLog
local collectBase = require "cashslots.common.gameCollect"
local collect = table.copy(collectBase)
local DEBUG = os.getenv("DEBUG")

local GAME_CFG = {
	gameid = 419,
	line = 50,
	winTrace = config.LINECONF[50][4], 
    mults = config.MULTSCONF[888][1],
	RESULT_CFG = config.CARDCONF[419],

	wilds = {1},  
    scatter = 2,  --scatter,只存在1.3.5列，如果scatter存在于1.3列，那第5列需要重新旋转一次
	bonus = 12,  --金币，本游戏特殊图标
	freeGameConf = {card = 2, min = 3, freeCnt = 6, addMult = 1},  -- 免费游戏配置
	COL_NUM = 5,
	ROW_NUM = 3,
	mustWinFreeCoin = true,
}

local RANDOMCARDS = {4, 5, 6, 7, 8, 9, 10, 11}		--除特殊图标外的牌，去除了wild，scatter，bonus

local bonusGame = {}	--bonus游戏对应的函数列表
local freeGame = {}		--免费游戏对应的函数列表
local cardRule = {}		--牌规则的一些处理函数

-- =======================通用代码====================
-- 获取pos个中的随机几个位置
local function getSomeRandomPos(pos, random)
    local ret = {}
    for i = 1, random do
        local idx = math.random(1, #pos)
        table.insert(ret, pos[idx])
        table.remove(pos, idx)
    end
    return ret
end
--==========================正常游戏奖池==================================
local JACKPOT = config.JACKPOTCONF[GAME_CFG.gameid]
local function getJackPot(deskInfo, type)
    if TEST_RTP then
        return JACKPOT.MULT[type] * deskInfo.totalBet
    else
        return math.floor(JACKPOT.MULT[type] * deskInfo.totalBet * (0.95 + math.random()*0.1))
    end
end

local function getJackpotList(deskInfo)
    local poolList = {}
	for i = 1, #JACKPOT.MULT do
		table.insert(poolList, getJackPot(deskInfo, i))
    end
    return poolList
end

-- ==========================集能量地图====================
--[[
	1.和地图相关
]]
local COLLECTCFG = {
	MINBETIDX = 3,				--开启能量条收集时的最小押注额。(判断时使用的，大于等于)
	TOTAL = DEBUG and 10 or 180,	--收集满能量条需要的bonus个数， 如果DEBUG字段为true，则为50个，否则200个。其中DEBUG为本地测试时使用。
    TOTAL_PASS = {
        [1] = 80,
        [2] = 160,
        [7] = 200,
        [13] = 250,
        [20] = 300
    },
	MAP = {
		CNT  = 10, 				--地图中的免费固定为10次
		FREE = {2, 7, 13, 20},	--停留在这些位置，会触发10次免费游戏
		MULTS = {
			[2]={2, 5}, 		--2号地图位置wild的翻倍区间是2-5
			[7]={2, 10}, 		--7号地图位置wild的翻倍区间是2-10
			[13]={3, 25}, 		--13号地图位置wild的翻倍区间是3-25
			[20]={5, 100}		--20号地图位置wild的翻倍区间是5-100
			},  --免费翻倍区间，中间的wild翻倍
        REAL_MULTS = {      --实际翻倍
            [2]={2, 5}, 		--2号地图位置wild的翻倍区间是2-5
            [7]={4, 8}, 		--7号地图位置wild的翻倍区间是2-10
            [13]={10, 18}, 		--13号地图位置wild的翻倍区间是3-25
            [20]={30, 75}		--20号地图位置wild的翻倍区间是5-100
        },
		MIN = 1,				--地图开始位置
		MAX = 20,				--地图结束位置
	}
}


--能量免费游戏时，wild固定出现在卷轴中
collect.stickedWild = function(deskInfo, cards)
	local copy = table.copy(cards)
	if collect.inFree(deskInfo) then
		for _, idx in ipairs({3, 8, 13}) do
			copy[idx] = GAME_CFG.wilds[1]
		end
	end
	return copy
end

--[[
开启地图免费游戏
1.由于老虎免费游戏中也可以收集，所以存在免费游戏中触发地图收集游戏。
2. free的字段使用deskInfo.collect.freeGame，和deskInfo.freeGameData不重复使用(老虎游戏独有特色)
]]
collect.startFree = function(deskInfo)
	local idx = deskInfo.collect.idx
	local addMult = math.random(COLLECTCFG.MAP.REAL_MULTS[idx][1], COLLECTCFG.MAP.REAL_MULTS[idx][2])
	local freeCnt = COLLECTCFG.MAP.CNT
	deskInfo.collect.freeGame = {
		all = freeCnt,  	--免费次数
		rest = freeCnt,		--剩余免费次数
		addMult = addMult,	--新增的倍率
		totalWinCoin = 0,	--总赢分

	}
end

--[[
收集游戏中清除当前收集免费数据以及收集关卡数据
1.如果是普通免费的最后一局,需要在收集免费结束后才能清空普通免费游戏
]]
collect.clearFree = function(deskInfo)
	if collect.inFree(deskInfo) and deskInfo.collect.freeGame.rest <= 0 then
		deskInfo.collect.freeGame = nil
		collect.clear(deskInfo)
		if isFreeState(deskInfo) and deskInfo.freeGameData.restFreeCount <= 0 then
			updateFreeData(deskInfo, 3)
		end
	end
end

--[[
	返回给客户端的数据格式
	由于419是旧代码，所以为了字段兼容处理
]]
collect.ret = function(deskInfo)
	local data = table.copy(deskInfo.collect)
	local ret = {
		avgbet = data.bet,			--平均押注额
		minBetIdx = data.min, 		--开启的档位数
		map_idx = data.idx,			--当前地图id
		totalCoin = data.num,		--进度条玩家总金币
		needCoins = data.total,		--进度条需要总金币
		next_game = data.open,		--下一关类型 1   --普通小型slots旋转， 2 --免费游戏
		freeGame = data.freeGame,	--免费游戏数据
	}
	-- 如果是触发next_game, 则这里强制将totalCoin 改成和needCoins一样
	-- 因为不方便改公共代码，所以只能这里修补下，防止前端出现进度条满之后又变成不满的状态
	if ret.next_game == 1 or ret.next_game == 2 then
		ret.needCoins = ret.totalCoin
	end
	return ret
end

--===========================bonusGame=============================
local BONUSCFG = {
	MAX = 6,		--6个以上触发bonus游戏
	ITEM = {
		{num = 1, rtype = "MULT",weight = 2000,},
		{num = 2, rtype = "MULT",weight = 1000,},
		{num = 3, rtype = "MULT",weight = 100,},
		{num = 4, rtype = "MULT",weight = 80,},
		{num = 5, rtype = "MULT",weight = 60,},
		{num = 6, rtype = "MULT",weight = 30,},
		{num = 8, rtype = "MULT",weight = 10,},
		{num = 10, rtype = "MULT",weight = 5,},
		{num = 15, rtype = "MULT",weight = 2,},
		{num = 20, rtype = "MULT",weight = 1,},
		{num = JACKPOT.DEF.MINI, rtype = "MINI",weight = 1000,}, --10倍,此处的num表示倍数
		{num = JACKPOT.DEF.MINOR, rtype = "MINOR",weight = 50,},--50倍
		{num = JACKPOT.DEF.MAJOR, rtype = "MAJOR",weight = 1,}, --200倍
		{num = JACKPOT.DEF.GRAND, rtype = "GRAND",weight = 0,}, --5000倍
	}
}
--获取bonus游戏的概率
bonusGame.getProbabilty = function(deskInfo)
	if deskInfo.control.bonusControl then
		return deskInfo.control.bonusControl.probability
	else
		return 0
	end
end

--[[
	规则： 旋转3次都没有转出bonus, 游戏结束
]]
bonusGame.check = function(deskInfo, cfg, cards)
	if deskInfo.bonusGame == nil then
		local idxs = {}
		for idx, v in ipairs(cards)do
			if v == GAME_CFG.bonus then
				table.insert(idxs, idx)
			end
		end
		if #idxs >= BONUSCFG.MAX then
			--num  旋转次数 --add 在num次旋转中，增加的bonus的个数， --idxs bonus存在的idx -- cards 最终的卡牌
			local data = {num = 3, add = 0, cards = table.copy(cards), idxs = idxs}
			local sun = {num = data.num, total=#idxs}
			data.data = sun
			return true, data
		end
		return false
	end
	return false
end

bonusGame.getBonusItemCfg = function (deskInfo)
	local cfg = table.copy(BONUSCFG.ITEM)
	if not table.empty(deskInfo.bonusCardInfo) then
		for k, v in pairs(deskInfo.bonusCardInfo)do
			if v.rtype == "MINI" then
				for k1, v1 in ipairs(BONUSCFG.ITEM)do
					if v1.rtype == "MINI" then
						table.remove(cfg, k1)
						break
					end
				end
			elseif v.rtype == "MINOR" then
				for k1, v1 in ipairs(BONUSCFG.ITEM)do
					if v1.rtype == "MINOR" then
						table.remove(cfg, k1)
						break
					end
				end
			elseif v.rtype == "MAJOR" then
				for k1, v1 in ipairs(BONUSCFG.ITEM)do
					if v1.rtype == "MAJOR" then
						table.remove(cfg, k1)
						break
					end
				end
			elseif v.rtype == "GRAND" then
				for k1, v1 in ipairs(BONUSCFG.ITEM)do
					if v1.rtype == "GRAND" then
						table.remove(cfg, k1)
						break
					end
				end
			end
		end
	end
	return cfg
end

--给卷轴中取出的bonus图标12号赋值为带金币的图标
bonusGame.setBonusCardInfo = function(deskInfo, cards)
	deskInfo.bonusCardInfo = deskInfo.bonusCardInfo or {}
	--如果已经中过奖池了，不会再中同类型
	for k, v in ipairs(cards) do
		local key = "idx_"..k
		if v == GAME_CFG.bonus and not deskInfo.bonusCardInfo[key] then
			local cfg = bonusGame.getBonusItemCfg(deskInfo)
			local idx = utils.randByWeight(cfg)
			if cfg[idx].rtype == "MULT" then
				deskInfo.bonusCardInfo[key] = {num = deskInfo.totalBet*cfg[idx].num, rtype = cfg[idx].rtype}
			else
				deskInfo.bonusCardInfo[key] = {num = getJackPot(deskInfo, cfg[idx].num), rtype = cfg[idx].rtype}
			end
		end
	end
end

 --卡牌需要套上上一次的卡牌
bonusGame.stickUpCards = function(deskInfo, cards)
	local c_cards = table.copy(deskInfo.bonusGame.cards)
	for idx, v in ipairs(c_cards) do
		if v == GAME_CFG.bonus and cards[idx] ~= GAME_CFG.bonus then
			cards[idx] = c_cards[idx]
		end
	end
	return cards
end

--[[
	根据概率检测是否触发bonus游戏。
	如果不在概率控制内，需要把能够触发的牌换掉。
	PS:地图免费中不能触发bonus游戏
]]
bonusGame.checkTriGame = function(deskInfo, cards)
	local copy = table.copy(cards)
	local probability = bonusGame.getProbabilty(deskInfo)
	local random = math.random()*1000
	if random <= probability and not collect.inFree(deskInfo) then
		local bonuxIdxs = {}
		local otherIdxs = {}
		for k, v in ipairs(copy)do
			if v ~= GAME_CFG.bonus then
				table.insert(otherIdxs, k)
			else
				table.insert(bonuxIdxs, k)
			end
		end
		local num = BONUSCFG.MAX - #bonuxIdxs --根据现有卡牌的个数，在不是bonus的位置上，凑足剩下的bonus个数
		if num > 0 then
			local idxs = getSomeRandomPos(otherIdxs, num)
			for _, idx in ipairs(idxs)do
				copy[idx] = GAME_CFG.bonus
			end
		end
	else
		copy = cardRule.clearBonusGame(copy)
	end
	return copy
end

--bonus游戏每局信息统计以及结算
bonusGame.settle = function(deskInfo, resultCards)
    local add = 0
    for k, v in ipairs(resultCards) do
        --新旋转出了bonus图标
        local key = "idx_"..k
        if v == GAME_CFG.bonus and deskInfo.bonusCardInfo[key] == nil then
            if #deskInfo.bonusGame.idxs >= 14 then
                resultCards[k] = RANDOMCARDS[math.random(1, #RANDOMCARDS)]
            else
                add = add + 1
                table.insert(deskInfo.bonusGame.idxs, k)
                deskInfo.bonusGame.cards[k] = v
            end
        end
    end
	deskInfo.bonusGame.add = add
	--bonus游戏有新增图标个数，那么旋转次数重置为3次，否则次数减1，次数为0时游戏结束，并开始结算金币
	if add > 0 then
		deskInfo.bonusGame.num = 3
		deskInfo.bonusGame.cards = resultCards
	else
		deskInfo.bonusGame.num = deskInfo.bonusGame.num - 1
	end
	
	--旋转到了满格，直接将局数控制为0
	if #deskInfo.bonusGame.idxs == 15 then
		deskInfo.bonusGame.num = 0
	end
	deskInfo.bonusGame.data.num = deskInfo.bonusGame.num
	deskInfo.bonusGame.data.total = #deskInfo.bonusGame.idxs
	--结算金币
	if deskInfo.bonusGame.num == 0 then
		local winCoin = 0
		for _, v in pairs(deskInfo.bonusCardInfo)do
			winCoin = winCoin + v.num
		end
		--获得额外的grand奖励
		if #deskInfo.bonusGame.idxs == 15 then
			deskInfo.bonusGame.jpPrize =  deskInfo.bonusGame.poolList[JACKPOT.DEF.GRAND]
			winCoin = winCoin + deskInfo.bonusGame.jpPrize
		end
		deskInfo.bonusGame.winCoin = winCoin
		return winCoin, {}, {}
	else
		return 0, {}, {}
	end
end

--[[
	清除bonus游戏数据
	1.如果是免费游戏最后一局触发，需要在此处清除免费游戏数据
]]
bonusGame.clear = function(deskInfo)
	deskInfo.bonusGame = nil
	if isFreeState(deskInfo) and deskInfo.freeGameData.restFreeCount <= 0 then
		updateFreeData(deskInfo, 3)
	end
end

--===========================freeGame=============================
freeGame.check = function(deskInfo, cards)
	local ret = {}
	local freeCardIdxs = {}
	local colIdxs = {}
	for idx, card in ipairs(cards) do
		if card == GAME_CFG.freeGameConf.card then
        	table.insert(freeCardIdxs, idx)
        end
	end
    if #freeCardIdxs >= GAME_CFG.freeGameConf.min then
        ret.idxs = freeCardIdxs
        ret.scatter = GAME_CFG.freeGameConf.card
        ret.freeCnt = GAME_CFG.freeGameConf.freeCnt
        ret.addMult = GAME_CFG.freeGameConf.addMult
    end
	return ret
end


--===========================牌规则=============================
--修改cards, 使得这首牌不触发bonus游戏
cardRule.clearBonusGame = function(resultCards)
	local cards = table.copy(resultCards)
	local idxs = {}
	for idx, v in ipairs(resultCards)do
		if v == GAME_CFG.bonus then
			table.insert(idxs, idx)
		end
	end
	if #idxs >= 6 then
		local max = #idxs - math.random(2, 3)
		for i = 1, max do
			local tmp = math.random(1, #idxs)
			local tmp_idx = idxs[tmp]
			local tmp_card = RANDOMCARDS[math.random(1, #RANDOMCARDS)]
			cards[tmp_idx] = tmp_card
			table.remove(idxs, tmp)
		end
	end
	return cards
end

--===========================正常游戏逻辑===========================

local function getLine()
	return GAME_CFG.line
end

local function getInitMult()
	return GAME_CFG.defaultInitMult
end

local function create(deskInfo, uid)
	collect.setCFG(COLLECTCFG)
	if deskInfo.collect == nil then
		collect.init(deskInfo)
	end
	if deskInfo.select == nil then
        deskInfo.select = {state = false}
    end
	if deskInfo.bonusGame and not isFreeState(deskInfo) then
		deskInfo.state = config.GAME_STATE.OTHER
	end
end

--计算押注额
local function caulBet(deskInfo)
    local betCoin = -deskInfo.totalBet
    deskInfo.lastBetCoin = deskInfo.user.coin
    if isFreeState(deskInfo) or collect.inFree(deskInfo) or deskInfo.bonusGame ~= nil then
        betCoin = 0
    else
        cashBaseTool.caulCoin(deskInfo, betCoin, PDEFINE.ALTERCOINTAG.BET)
    end
    deskInfo.lastBetCoin = Double_Add(deskInfo.lastBetCoin, betCoin)
    return betCoin
end


--取正常的牌
local function getCards(deskInfo)
	local resultCards 
	if deskInfo.bonusGame then
		local cardmap = cardProcessor.getCardMap(deskInfo, "bonusmap")
		resultCards = cardProcessor.get_cards_1(cardmap)
	elseif collect.inFree(deskInfo) then
		local cardmap = cardProcessor.getCardMap(deskInfo, "mapfreegame")
		resultCards = cardProcessor.get_cards_1(cardmap)
		resultCards = collect.stickedWild(deskInfo, resultCards)
	elseif isFreeState(deskInfo) then
		local cardmap = cardProcessor.getCardMap(deskInfo, "freegame")
	    resultCards = cardProcessor.get_cards_1(cardmap)
	else
		resultCards = cardProcessor.get_cards_2(deskInfo)
	end
	return resultCards
end

--免费游戏发牌，第三列都是wild
local function initResultCards(deskInfo)
	local funcList = {
		getResultCards = getCards,
		checkFreeGame = freeGame.check,
		-- checkSubGame = bonusGame.check,
	}
	local resultCards =  cardProcessor.get_cards_3(deskInfo, GAME_CFG, funcList)

	--地图免费游戏不能触发bonus游戏
	if collect.inFree(deskInfo) then
		resultCards = cardRule.clearBonusGame(resultCards)
	end
	--触发免费游戏和bonusgame不能同时出现,所以6个金币触发bonusgame的游戏需要被换掉
	local freeInfo = freeGame.check(deskInfo, resultCards)
	if not table.empty(freeInfo) then
		resultCards = cardRule.clearBonusGame(resultCards)
	else
		resultCards = bonusGame.checkTriGame(deskInfo, resultCards)
	end
	--卡牌需要套上上一次的卡牌
	if deskInfo.bonusGame then  
		resultCards = bonusGame.stickUpCards(deskInfo, resultCards)
	end

	--===============测试配牌代码===============
	local design = cashBaseTool.addDesignatedCards(deskInfo)
	if design ~= nil then
		resultCards = table.copy(design)
	end
	--===============测试配牌代码===============
	return resultCards
end

local function start_419(deskInfo)
	if deskInfo.bonusGame == nil then --非bonus游戏,每局充值bonus数据的信息
		deskInfo.bonusCardInfo = {}
	end
    local result = {}
	result.resultCards = initResultCards(deskInfo) 
	if deskInfo.bonusGame == nil then --非bonus游戏
		result.winCoin, result.zjLuXian, result.scatterResult = settleTool.getBigGameResult(deskInfo, result.resultCards, GAME_CFG)
		if result.scatterResult and result.scatterResult.coin == 0 then
			result.scatterResult.indexs = {}
		end
		if collect.inFree(deskInfo) then
			result.winCoin, result.zjLuXian = collect.settleBigGame(deskInfo, result.winCoin, result.zjLuXian)
		end
		result.freeResult = freeGame.check(deskInfo, result.resultCards)
	else	--bous游戏
		result.winCoin, result.zjLuXian, result.scatterResult  = bonusGame.settle(deskInfo, result.resultCards)
		result.freeResult = {}
	end
	local retobj = cashBaseTool.genRetobjProto(deskInfo, result)
	bonusGame.setBonusCardInfo(deskInfo, retobj.resultCards)
	retobj.bonusCardInfo = table.copy(deskInfo.bonusCardInfo)
	if deskInfo.bonusGame == nil then --非bonus游戏
		local isTriBonus, bonusData = bonusGame.check(deskInfo, nil, retobj.resultCards)
		if isTriBonus then
			local poolList = getJackpotList(deskInfo)
			deskInfo.bonusGame = table.copy(bonusData)
			deskInfo.bonusGame.poolList = poolList
			deskInfo.bonusGame.open = true
			retobj.bonusData = {
				open = true,
				data = {num = bonusData.num, total = #bonusData.idxs},	
				poolList = poolList,
			}
			deskInfo.state = config.GAME_STATE.OTHER
		else
			deskInfo.bonusCardInfo = {}
			retobj.bonusData = {open = false}
			-- 做下处理，如果触发免费，则不再收集图标, 防止免费和地图游戏同时触发
			if table.empty(retobj.freeResult.freeInfo) then
				collect.add(deskInfo, retobj.resultCards, GAME_CFG.bonus)
			end
		end
	else--bonus游戏
		deskInfo.bonusGame.open = false --开始进入后，要设置为false
		retobj.bonusData = table.copy(deskInfo.bonusGame)
		if deskInfo.bonusGame.num == 0 then
			collect.add(deskInfo, retobj.resultCards, GAME_CFG.bonus) --最后一局是所有的个数，因为每局只会有新增。
			bonusGame.clear(deskInfo)
			if deskInfo.state == config.GAME_STATE.OTHER then
				if deskInfo.freeGameData and deskInfo.freeGameData.restFreeCount > 0 then
					deskInfo.state = config.GAME_STATE.FREE
				else
					deskInfo.state = config.GAME_STATE.NORMAL
				end
			end
		end
	end
    return retobj
end

local function settle_419(deskInfo, betCoin, retobj)
	local isFreeState = isFreeState(deskInfo)		--正常免费游戏
	local isMapFreeState = collect.inFree(deskInfo)	--地图免费游戏
	if isFreeState then
		if isMapFreeState and deskInfo.collect.freeGame then
			--如果是本局刚触发, 就不能够递减
			deskInfo.collect.freeGame.rest = deskInfo.collect.freeGame.rest - 1
			deskInfo.collect.freeGame.totalWinCoin = deskInfo.collect.freeGame.totalWinCoin + retobj.wincoin
			deskInfo.freeGameData.freeWinCoin = deskInfo.freeGameData.freeWinCoin + retobj.wincoin
		elseif deskInfo.bonusGame == nil then
			updateFreeData(deskInfo, 2, nil, nil, retobj.wincoin)
		end
	else
		if not table.empty(retobj.freeResult.freeInfo) then
			local freeInfo = table.copy(retobj.freeResult.freeInfo)
        	updateFreeData(deskInfo, 1, freeInfo.freeCnt, freeInfo.addMult, retobj.wincoin, freeInfo)
		else
			if not isMapFreeState or not deskInfo.collect.freeGame then							--非地图免费，实时结算金币
				cashBaseTool.caulCoin(deskInfo, retobj.wincoin, PDEFINE.ALTERCOINTAG.WIN)
			else
				deskInfo.collect.freeGame.rest = deskInfo.collect.freeGame.rest - 1
				deskInfo.collect.freeGame.totalWinCoin = deskInfo.collect.freeGame.totalWinCoin + retobj.wincoin
				if deskInfo.collect.freeGame.rest <= 0 then		--地图免费，最后一局结算金币
					cashBaseTool.caulCoin(deskInfo, deskInfo.collect.freeGame.totalWinCoin, PDEFINE.ALTERCOINTAG.WIN)
				end
			end
		end
	end
	
	--产生免费游戏返回数据结果
	cashBaseTool.genFreeProto(deskInfo, retobj)
	--上报结果
    local result = {
        kind = betCoin==0 and "free" or "base",
        cards = retobj.resultCards
    }
    baseRecord.slotsGameLog(deskInfo, betCoin, retobj.wincoin, result, 0)
	--免费游戏数据清空
    if isFreeState and deskInfo.freeGameData.restFreeCount <= 0 and not collect.inFree(deskInfo) and deskInfo.bonusGame == nil then
		updateFreeData(deskInfo, 3)
    end
	retobj.coin = deskInfo.user.coin  --最新的玩家金币
end


local function start(deskInfo) --正常游戏
	local isFreeState = isFreeState(deskInfo)
    local betCoin = caulBet(deskInfo)
    if isFreeState then
		deskInfo.control.freeControl.probability = 0
        deskInfo.control.bonusControl.probability = deskInfo.control.bonusControl.probability * 2
    end
    if deskInfo.bonusGame then
        deskInfo.control.freeControl.probability = 0
        deskInfo.control.bonusControl.probability = 0
    end

	local retobj =  start_419(deskInfo)
	settle_419(deskInfo, betCoin, retobj)
	-- 这里需要判断是否刚刚触发，如果是刚刚触发，则需要初始化数据
	if deskInfo.collect.open == 2 and not deskInfo.collect.freeGame then
		collect.startFree(deskInfo)
	end
	--收集游戏数据
	retobj.energyData = collect.ret(deskInfo)
	collect.clearFree(deskInfo)
	-- 手动存redis
	gameData.set(deskInfo)
	return retobj
end

local function resetDeskInfo(deskInfo)
	gameData.set(deskInfo)
end

local function addSpecicalDeskInfo(deskInfo, simpleDeskData)
	simpleDeskData.energyData = collect.ret(deskInfo)
	simpleDeskData.bonusData = deskInfo.bonusGame
	simpleDeskData.bonusCardInfo = deskInfo.bonusCardInfo
	return simpleDeskData
end

local function gameLogicCmd(deskInfo, recvobj)
	local retobj = {}
	local rtype = math.floor(recvobj.rtype)
	if rtype == 1 and deskInfo.collect.open == 1 then	--类型1，能量slots小游戏1，传入idx
		local ret = N77.get()
		retobj.cardsList = ret.cardsList
		retobj.wincoin = math.round_coin(ret.mult*deskInfo.collect.bet)
		-- 将平均下注额暴露出来
		retobj.avgBet = deskInfo.collect.bet
		if isFreeState(deskInfo) then
			deskInfo.freeGameData.freeWinCoin = deskInfo.freeGameData.freeWinCoin + retobj.wincoin
		else
			cashBaseTool.caulCoin(deskInfo, retobj.wincoin, PDEFINE.ALTERCOINTAG.WIN)
		end
		local result = {
			kind = "bonus",
			desc = "777"
		}
		baseRecord.slotsGameLog(deskInfo, 0, retobj.wincoin, result, 0)
		collect.clear(deskInfo)
	end
	retobj.rtype = rtype
	-- 手动存redis
	gameData.set(deskInfo)
	return retobj
end

return {
	cardsConf = GAME_CFG.RESULT_CFG,
	mults = GAME_CFG.mults,
	line = GAME_CFG.line,
	create = create,
	start = start,
	resetDeskInfo = resetDeskInfo,
	getInitMult = getInitMult,
	getLine = getLine,
	gameLogicCmd = gameLogicCmd,
	addSpecicalDeskInfo = addSpecicalDeskInfo,
}

--[[

老虎： 
deskInfo.mapInfo.openGame  = 1 需要选择51
44返回数据解释
	1. retobj.bonusData
		1.1. 触发bonus游戏  {open = true, data = {num = 3, total = #idxs}, poolList = {1000, 1000, 1000, 1000}}  -- num旋转次数， total 金币个数 poolList 触发bonus游戏时暂停奖池数据
		1.2. 没触发  {open = false}
		1.3. bonus游戏中 {num = 3, add = 0, cards = resultCards, idxs = idxs, winCoin = 0, jpPrize = 0, poolList = {1000, 1000, 1000, 1000}} 
			num  旋转次数 --add 在num次旋转中，增加的bonus的个数， --idxs bonus存在的idx -- cards 最终的卡牌 --winCoin表示总赢金币（包含jpPrize） --jpPrize 如果中15个bonus获得额外的grand奖池数据（做判空处理）
	
	2.retobj.energyData 
		{
			minBetIdx: 开启
			map_idx : 当前地图id
			next_game: 下一关类型 1   --普通小型slots旋转， 2 --免费游戏
			totalCoin： 进度条玩家总金币
			needCoins：	进度条需要总金币


			--next_game== 2时，新增数据
			freeGame = {
				all = *,  	--免费次数
				rest = *,		--剩余免费次数
				addMult = *,	--新增的倍率
				totalWinCoin = *,	--总赢分
			}
		}
	
	3.新增bonus图标返回数据
		比如： resultCards: {
			[1] = 11,
			[2] = 4,
			[3] = 12,
			[4] = 2,
			[5] = 1,
			[6] = 3,
			[7] = 10,
			[8] = 4,
			[9] = 6,
			[10] = 1,
			[11] = 3,
			[12] = 10,
			[13] = 1,
			[14] = 12,
			[15] = 12,
	}
	bonusCardInfo : {
			["idx_3"] = {
					["rtype"] = "MULT",
					["num"] = 10000,
			},
			["idx_14"] = {
                ["rtype"] = "MINI",
                ["num"] = 100000,
        	},
			["idx_15"] = {
					["rtype"] = "MULT",
					["num"] = 10000,
			},
	}


--51 能量小关游戏

c : {c: 51, uid:*, gameid:*, data:{rtype:1}}

--其中 rtype = 1 小型slots
返回数据格式：
{c:51, code:200, uid:*, gameid:*, 
	data:{
		cardsList:{{1, 2, 3}, {1, 2, 3},  {1, 2, 3},  {1, 2, 3}, }
		wincoin :1000,
		rtype:*,
	}
}

]]

