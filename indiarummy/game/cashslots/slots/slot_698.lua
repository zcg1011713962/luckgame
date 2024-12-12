--[[
    阿拉丁神灯 Lamp of Aladdin
    1.普通游戏中随机2X 3X 4X的倍数 DOIT
    2.wild, 收集金币收集满后触发pickBonus
    3.pickBonus中点击了小鸟图标，将所有min置灰
    4.触发免费游戏，转盘旋转，触发免费则进免费游戏
    5.收集游戏，通用
]]
local cluster = require "cluster"
local skynet  = require "skynet"
local config = require"cashslots.common.config"
local cardProcessor = require "cashslots.common.cardProcessor"
local player_tool = require "base.player_tool"
local settleTool = require "cashslots.common.gameSettle"
local cashBaseTool = require "cashslots.common.base"
local freeTool = require "cashslots.common.gameFree"
local recordTool = require "cashslots.common.gameRecord"
local N77 = require "cashslots.common.gameN77"
local collectBase = require "cashslots.common.gameCollect"
local utils = require "cashslots.common.utils"
local baseRecord = require "base.record"
local collect = table.copy(collectBase)
local updateFreeData = freeTool.updateFreeData
local isFreeState = freeTool.isFreeState
local gameData = recordTool.gameData
local record = recordTool.pushLog
local caulBet = cashBaseTool.caulBetandLastBetCoin
local checkFreeGame = freeTool.checkFreeGame
local caulCoin = cashBaseTool.caulCoin
local TESTTEST= false

local GAME_CFG = {
	gameid = 698,
    line = 243,
    wilds = {10}, 
    scatter = 9,
    mults = config.MULTSCONF[888][1],
	RESULT_CFG = config.CARDCONF[698],
	freeGameConf = {card = 9, min = 3, freeCnt = 0, addMult = 1},  -- 免费游戏配置
	COL_NUM = 5,
    ROW_NUM = 3,
    mustWinFreeCoin = true, --免费游戏必须赢一局
}
local RANDOMCARDS = {2, 3, 4, 5, 6, 7, 8}
local COLLECTCARD = 1
local FREETYPE = {
	NONE = 0,
	COMMONFREE = 1,
	COLLECTFREE = 2
}
--==========================正常游戏奖池==================================
--[[
	1.免费游戏中没有MINOR，MAJOR，GRAND奖池
	2.MINOR，MAJOR， GRAND只有在触发免费那一局时，6个以上的混合2/3/4/5才会加分
]]
--type 1: MINOR  2: MAJOR  3: GRAND
local JACKPOT = config.JACKPOTCONF[GAME_CFG.gameid]

local function getJackPot(deskInfo, type)
    if TEST_RTP then
        return JACKPOT.MULT[type] * deskInfo.totalBet
    else
        return math.floor(JACKPOT.MULT[type] * deskInfo.totalBet * (0.95 + math.random()*0.1))
    end
end

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

--================收集配置=================
local COLLECTCFG = {
	MINBETIDX = 3,
	TOTAL = TESTTEST and 5 or 160,
	MAP = {
		CNT  = 10, 				--地图中的免费时10次
		FREE = {3, 7, 12, 19},	--停留在这些位置，会触发10次免费游戏
		MULTS = {
                 [3] = {2,2,3,3,4,5},
                 [7] = {2,2,3,3,4,5,7,10},
                 [12] = {3,3,3,4,4,5,6,8,10,15,25},
                 [19] = {5,5,5,6,6,8,10,12,15,20,25,30,50}
        },  --免费翻倍区间，中间的wild翻倍
		MIN = 1,
		MAX = 19,
	}
}

-- 重写collect函数
-- 更新开启免费游戏
collect.startFree = function (deskInfo)
	if collect.inFree(deskInfo) then
		updateFreeData(deskInfo, 1, COLLECTCFG.MAP.CNT, 1, 0)
	end
end

-- =====================免费游戏大转盘相关配置=========（修改！！！）==================
-- 固定金额：押注金额的倍数（5-375X），共12个，且12个固定奖励上有概率出现2X，3X，5X，10X的乘数，使该项奖励增多
local TURNTABLE = {
    default = { --默认转盘
        {id = 1, info = "GRAND",   rtype = "JP",  weight = 0},
        {id = 2, info = 5,         rtype = "MULT", weight = 50},
        {id = 3, info = 200,       rtype = "MULT", weight = 5},
        {id = 4, info = "FREE8",   rtype = "FREE", weight = 300},
        {id = 5, info = 10,        rtype = "MULT", weight = 150},
        {id = 6, info = 40,        rtype = "MULT", weight = 40},
        {id = 7, info = "MEGA",    rtype = "JP", weight = 200},
        {id = 8, info = 25,        rtype = "MULT", weight = 60},
        {id = 9, info = 10,        rtype = "MULT", weight = 150},
        {id = 10, info = "FREE10", rtype = "FREE", weight = 1200},
        {id = 11, info = 5,        rtype = "MULT", weight = 50},
        {id = 12, info = 200,      rtype = "MULT", weight = 5},
        {id = 13, info = "MINI",   rtype = "JP",   weight = 200},
        {id = 14, info = 10,       rtype = "MULT", weight = 150},
        {id = 15, info = 30,       rtype = "MULT", weight = 60},
        {id = 16, info = "FREE15", rtype = "FREE", weight = 1500},
        {id = 17, info = 45,       rtype = "MULT", weight = 30},
        {id = 18, info = 100,      rtype = "MULT", weight = 20},
    },
    mults = { --倍数
        [1] = {--2X，3X，5X，10X的乘数
            {num = 2, weight = 50,},
            {num = 3, weight = 50,},
            {num = 5, weight = 10,},
            {num = 10, weight = 1,},
        },
        [2] = {
            {num = 2, weight = 20,},
            {num = 3, weight = 5,},
        }
    }
}
local wheel = {}
wheel.conf = function(deskInfo)
    local cfg = {}
    local coinIdxs = {}             --中奖为金币的位置
    for i = 1, #TURNTABLE.default do
        if TURNTABLE.default[i].rtype == "MULT" then
            table.insert(cfg, deskInfo.totalBet*TURNTABLE.default[i].info)
            table.insert(coinIdxs, i)
        else
            table.insert(cfg, TURNTABLE.default[i].info)
        end
    end

    local mults = {}
    local pos = getSomeRandomPos(coinIdxs, math.random(5, 8))     --和数值确定
    for _, idx in ipairs(pos) do
        local tmpMultsCfg
        if TURNTABLE.default[idx].info < 20 then
            tmpMultsCfg = table.copy(TURNTABLE.mults[1])
        elseif TURNTABLE.default[idx].info < 50 then
            tmpMultsCfg = table.copy(TURNTABLE.mults[2])
        end
        if (tmpMultsCfg) then
            local _, rs = utils.randByWeight(tmpMultsCfg)
            mults["idx_"..idx] = rs.num
        end
    end
    local ret = {cfg = cfg, mults = mults}
    deskInfo.wheelInfo = table.copy(ret)
    return ret
end

wheel.result = function(deskInfo)
    local ret = {}
    local idx = utils.randByWeight(TURNTABLE.default)
    local prize =  deskInfo.wheelInfo.cfg[idx]
    local mult = deskInfo.wheelInfo.mults["idx_"..idx] or 1
    local info = {}
    if type(prize) == "string" then
        if prize == "GRAND" then
            local coin = getJackPot(deskInfo, JACKPOT.DEF.GRAND)
            info.num =coin
            info.type = "pool"
        elseif prize == "MEGA" then
            local coin = getJackPot(deskInfo, JACKPOT.DEF.MEGA)
            info.num =coin
            info.type = "pool"
        elseif prize == "MINI" then
            local coin = getJackPot(deskInfo, JACKPOT.DEF.MINI)
            info.num =coin
            info.type = "pool"
        elseif prize == "FREE8" then
            info.num = 8
            info.type = "free"
        elseif prize == "FREE10" then
            info.num = 10
            info.type = "free"
        elseif prize == "FREE15" then
            info.num = 15
            info.type = "free"
        end
    else
        info.mult = mult
        info.num = prize*mult
        info.type = "coin"
    end
    ret.idx = idx
    ret.info = info
    return ret
end

--======================收集奖池游戏，wild===========================
--rtype: 1:MINI 2:MINOR 3:MAJOR 4 MEGA 5 ULTRA 6 GRAND 7:BIRD
local MINBETIDX = 1
local TOTAL = TESTTEST and 5 or 100
local DEF = {MINI = 1,MINOR = 2, MAJOR = 3, MEGA = 4, ULTRA = 5, GRAND = 6, BIRD = 7,}
local POOLCFG = {
    {id = 1, num = DEF.MINI, weight = 100},     --x5
    {id = 2, num = DEF.MINOR, weight = 1000},   --x10
    {id = 3, num = DEF.MAJOR, weight = 500},    --x20
    {id = 4, num = DEF.MEGA, weight = 100},     --x50
    {id = 5, num = DEF.ULTRA, weight = 10},     --x500
    {id = 6, num = DEF.GRAND, weight = 0},      --x5000
}
local pool = {}
--===能量条以及地图初始化
pool.init = function(deskInfo)
	deskInfo.pool = {
		min = MINBETIDX, 				--进度条开始时的等级
		total  = math.random(TOTAL-20, TOTAL+20),					--进度条需要的总进步数值	
		num = 0,						--目前总金币(每执行完一个子游戏需要清零处理)
	}
    deskInfo.pool.total = math.max(100, deskInfo.pool.total)
end

pool.add = function(deskInfo, cards)
    if deskInfo.currmult >= MINBETIDX and deskInfo.collect.num < deskInfo.collect.total then
        for idx, v in ipairs(cards)do
			if v >= GAME_CFG.wilds[1] then	
                deskInfo.pool.num =  deskInfo.pool.num + 1
			end
        end
        if deskInfo.pool.num >= deskInfo.pool.total then
            if math.random() < 0.01 then
                pool.genResult(deskInfo)
			    deskInfo.select = {state = true, rtype = 4}
            end
		end
	end
	return deskInfo.pool
end

--生成20个格子, 其中6*3+2, 生成结果，玩家点击只是依次下发数据
pool.genResult = function(deskInfo)
    --最终获取结果MINOR或者MIN等等
    local _, rs = utils.randByWeight(POOLCFG)
    local win = rs.num
    --点击次数,至少5次
    local pickNum = math.random(5, 10)
    --指定玩家在那几次或者结果以及小飞鸟
    local pickNumInfo = {}
    for i = 1, pickNum-1 do
        table.insert(pickNumInfo, i)
    end
    --指定这3次机会将获取结果
    local serverPick = {rs = {}, bird = {}}       --服务器指定的结果信息
    serverPick.rs = getSomeRandomPos(pickNumInfo, 2) 
    table.insert(serverPick.rs, pickNum)
    --如果中奖结果不是MIN，50%的概率增加飞鸟信息
    if win ~= DEF.MINI and math.random()<0.5 then
        serverPick.bird = getSomeRandomPos(pickNumInfo, 1) 
    end
    
    --统计类型数据，小飞鸟*2 其他数据3个
    local numInfo = {}
    for k = DEF.MINI, DEF.BIRD do
        if k ~= DEF.BIRD then
            numInfo["type_"..k] = 3
        else
            numInfo["type_"..k] = 2
        end
    end
    local pos = {}
    local pick = {}
    for i = 1, 20 do
        table.insert(pos, i)
        pick["idx_"..i] = {state = false}
    end

    deskInfo.pool.allIdxs = pos     --20个图标格子，在pick中会依次移除
    deskInfo.pool.idxs = {}         --玩家点击过的idx
    deskInfo.pool.type = win
    deskInfo.pool.pickNum = pickNum
    deskInfo.pool.serverPick = serverPick
    deskInfo.pool.numInfo = numInfo
    deskInfo.pool.pick = pick
end

pool.pick = function(deskInfo, idx)
    if not table.contain(deskInfo.pool.idxs, idx)then
        local ret = {}
        --添加在已经点击的idx中
        table.insert(deskInfo.pool.idxs, idx)

        --从总idx中移除
        local rIdx = findIdx(deskInfo.pool.allIdxs, idx) 
        table.remove(deskInfo.pool.allIdxs, rIdx)

        ret.idx = idx
        deskInfo.pool.pickNum = deskInfo.pool.pickNum - 1
        deskInfo.pool.pick["idx_"..idx].state = true
        --总点击次数
        local totalPickNum = #deskInfo.pool.idxs
        local serverPickIdx = findIdx(deskInfo.pool.serverPick.rs, totalPickNum)
        local serverBirdPickIdx =  findIdx(deskInfo.pool.serverPick.bird, totalPickNum)
        if serverPickIdx ~= -1 then
            table.remove(deskInfo.pool.serverPick.rs, serverPickIdx)
            ret.type = deskInfo.pool.type
            deskInfo.pool.pick["idx_"..idx].type = deskInfo.pool.type
            
            deskInfo.pool.numInfo["type_"..deskInfo.pool.type] = deskInfo.pool.numInfo["type_"..deskInfo.pool.type] - 1
        elseif serverBirdPickIdx ~= -1 then 
            ret.type = DEF.BIRD
            table.remove(deskInfo.pool.serverPick.bird, serverBirdPickIdx)
            deskInfo.pool.numInfo["type_"..DEF.BIRD] = deskInfo.pool.numInfo["type_"..DEF.BIRD] - 1
            local minTypeIdxs =getSomeRandomPos(deskInfo.pool.allIdxs, deskInfo.pool.numInfo["type_"..DEF.MINI])

            --============点击到小飞鸟，需要下发min奖池的idx==============
            ret.minTypeIdxs = minTypeIdxs

            deskInfo.pool.pick["idx_"..idx].type = DEF.BIRD
            

            for _, tmp in ipairs(minTypeIdxs) do
                deskInfo.pool.numInfo["type_"..DEF.MINI] = deskInfo.pool.numInfo["type_"..DEF.MINI] - 1

                deskInfo.pool.pick["idx_"..tmp].type =DEF.MINI
                deskInfo.pool.pick["idx_"..tmp].state = true
            end
        else
            for k, v in pairs(deskInfo.pool.numInfo) do
                if #deskInfo.pool.serverPick.bird > 0  then
                    if k ~= "type_"..deskInfo.pool.type and k ~= "type_"..DEF.BIRD and v > 1 then
                        ret.type = string.sub(k, -1)
                        deskInfo.pool.numInfo["type_"..ret.type] = deskInfo.pool.numInfo["type_"..ret.type] - 1
                        break
                    end
                else
                    --要大于1个的才可以点击，要不然3个全点完了，结果出错了（3个获取jackpot）
                    --不能点出小飞鸟的位置
                    --随机点图标时，如果小飞鸟还没点出，要保留小飞鸟的位置
                    if k ~= "type_"..deskInfo.pool.type and k ~= "type_"..DEF.BIRD and v > 1 then
                        if #deskInfo.pool.serverPick.bird > 0 and  k == DEF.MINI then
                            if  k > 2 then
                                ret.type = string.sub(k, -1)
                                deskInfo.pool.numInfo["type_"..ret.type] = deskInfo.pool.numInfo["type_"..ret.type] - 1
                                break
                            end
                        else
                            ret.type = string.sub(k, -1)
                            deskInfo.pool.numInfo["type_"..ret.type] = deskInfo.pool.numInfo["type_"..ret.type] - 1
                            break
                        end
                    end
                end
            end
            deskInfo.pool.pick["idx_"..idx].type = math.floor(ret.type)
        end
        if deskInfo.pool.pickNum == 0 then
            ret.endFlag = true
            local other = {}
            for i = 1, 20 do
                local  tmpType
                if not deskInfo.pool.pick["idx_"..i].state then
                    for k, v in pairs(deskInfo.pool.numInfo) do
                        if k ~= "type_"..deskInfo.pool.type and v > 0 then
                            tmpType = string.sub(k, -1)
                            deskInfo.pool.numInfo["type_"..tmpType] = deskInfo.pool.numInfo["type_"..tmpType] - 1
                            break
                        end
                    end
                    deskInfo.pool.pick["idx_"..i].type = tmpType
                end
            end 
        end

        ret.pick = deskInfo.pool.pick
        return ret
    else
        return {spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR}
    end
end

pool.ret = function(deskInfo)
    return {
        min = deskInfo.pool.min, 				--进度条开始时的等级
		total  = deskInfo.pool.total,					--进度条需要的总进步数值	
		num = deskInfo.pool.num,	
        pick = deskInfo.pool.pick,
    }
end

--===========清除选择信息
local function clearSelect(deskInfo)
	deskInfo.select = {state = false}
end
--===========================正常游戏逻辑===========================
local function getLine()
	return GAME_CFG.line
end

local function getInitMult()
	return GAME_CFG.defaultInitMult
end

local function create(deskInfo, uid)
    COLLECTCFG.MINBETIDX = deskInfo.needbet or COLLECTCFG.MINBETIDX
    collect.setCFG(COLLECTCFG)
    if deskInfo.collect == nil then
		collect.init(deskInfo)
	elseif deskInfo.collect.bet == nil then
		deskInfo.collect.bet = 0						--玩家在地图关卡应当使用的押注额
		deskInfo.collect.coin = 0 						--收集过程中的总押注金币
		deskInfo.collect.cnum = 0						--收集次数
    end
    if nil ~= deskInfo.collect then
		deskInfo.collect.min = deskInfo.needbet         --设置收集游戏的开启档位
	end
	if deskInfo.select == nil then
		deskInfo.select = {state = false}
    end
    if deskInfo.pool == nil then
        pool.init(deskInfo)
    end
end

--取正常的牌
local function getCards(deskInfo)
	local resultCards = cardProcessor.get_cards_2(deskInfo)

    local cardsCnt = {0,0,0,0,0,0,0,0,0,0}
    for _, v in ipairs(resultCards) do
        cardsCnt[v] = cardsCnt[v] + 1
    end
    for i = 1, 9 do
        if cardsCnt[i] + cardsCnt[GAME_CFG.wilds[1]] >= 10 then
            resultCards = cardProcessor.get_cards_2(deskInfo)
            break
        end
    end
	-- 集能量通大关
	if deskInfo.collect.open == 2 then
		for _, idx in ipairs({3, 8, 13}) do
			resultCards[idx] = GAME_CFG.wilds[1]
		end
	end
	return resultCards
end

local function getCardCount(resultCards, value)
    local num = 0
    for idx, v in ipairs(resultCards)do
		if v == value then
            num = num + 1
		end
    end
    return num
end

local  function clearCards(resultCards, value)
	local cards = table.copy(resultCards)
	local idxs = {}
	for idx, v in ipairs(resultCards)do
		if v == value then
            cards[idx] = RANDOMCARDS[math.random(1, #RANDOMCARDS)]
		end
	end
	return cards
end

local function getBigGameResult(deskInfo, cards, GAME_CFG)
    return settleTool.getBigGameResult_2(deskInfo, cards, GAME_CFG)
end

--免费游戏发牌，第三列都是wild
local function initResultCards(deskInfo)
	local funcList = {
        getResultCards = getCards,
        getBigGameResult = getBigGameResult,
	}
    local cards =  cardProcessor.get_cards_3(deskInfo, GAME_CFG, funcList)
    --===============测试配牌代码===============
    local design = cashBaseTool.addDesignatedCards(deskInfo)
    if design ~= nil then
        cards = table.copy(design)
    end
    --===============测试配牌代码===============
	--触发免费游戏时不新增进度条数据,TODO: 触发免费游戏时不能收集
    local freeInfo = checkFreeGame(cards, GAME_CFG.freeGameConf)
    local c_cnt = getCardCount(cards, COLLECTCARD)        --收集游戏的卡牌
    local c_flag = deskInfo.collect.num + c_cnt >= deskInfo.collect.total
    local w_cnt = getCardCount(cards, GAME_CFG.wilds[1])  --bonus点击游戏的卡牌
    local w_flag = deskInfo.pool.num + c_cnt >= deskInfo.pool.total
    --去掉COLLECTCARD以及wild, 防止同时触发
    if not table.empty(freeInfo) then
        if c_flag then
            cards = clearCards(cards, COLLECTCARD)
        end
        if w_flag then
            cards = clearCards(cards, GAME_CFG.wilds[1])
        end
    else
        --防止同事触发
        if not isFreeState(deskInfo) and c_flag and w_flag then
            if math.random() < 0.5 then
                cards = clearCards(cards, COLLECTCARD)
            else
                cards = clearCards(cards, GAME_CFG.wilds[1])
            end
        end
    end
	return cards
end
-- 计算中奖线路
-- 因为是满线的游戏，所以不需要管线路，按照列来算结果就行了
local function checkResult(deskInfo, cards, mults)
    local winResult = {}  -- 存放最终结果
    local winCoin = 0  -- 存放最终赢的钱
    -- 存放格式{[col]={[card] = {count=1, indexes={}, mult=1}}}}
    local colCards = {}  -- 记录每列的牌统计
    local wild = GAME_CFG.wilds[1]  -- 获取wild图标
    -- 免费游戏，需要查看倍率
    local addMult = isFreeState(deskInfo) and deskInfo.freeGameData.addMult or 1
    -- 统计每列的牌值
    for idx = 1, #cards do  -- 轮询所有牌
        local card = cards[idx]  -- 获得牌值
        -- 计算余数来判断是哪一列
        local col = math.fmod(idx, GAME_CFG.COL_NUM)
        if col == 0 then
            col = GAME_CFG.COL_NUM
        end
        -- 初始化记录的列信息
        if colCards[col] == nil then
            colCards[col] = {}
        end
        -- scatter不能算练线，直接算个数
        if card ~= GAME_CFG.scatter then
            local mult = addMult  -- 
            local cardCnt = 1  -- 需要增加的牌数量
            if card == GAME_CFG.wilds[1] then
                -- 免费游戏中, wild的倍率不同
                if mults["idx_"..idx] then
                    cardCnt = cardCnt + mults["idx_"..idx] - 1
                end
            end
            -- 将每列的牌值和数量记录下来
            if colCards[col][card] ~= nil then
                colCards[col][card].count = colCards[col][card].count + cardCnt
                table.insert(colCards[col][card].indexes, idx)
                colCards[col][card].mult = colCards[col][card].mult * mult
            else
                colCards[col][card] = {count = cardCnt, indexes = {idx}, mult = mult}
            end
        end
    end
    --- 根据统计的牌值，来计算牌值的倍数和连线数量
    local tempResult = {}
    local allCards = {}  -- 获取所有的牌
    for card, _ in pairs(GAME_CFG.RESULT_CFG) do
        table.insert(allCards, card)
    end
    for _, card in ipairs(allCards) do
        local isLegal = false
        local mult = 0
        local indexes = {}
        local count = 0
        for i = 1, 5 do  -- 轮询5列
            -- 如果没有wild而且没有当前牌，则break
            if colCards[i][card] == nil and colCards[i][wild] == nil then
                break
            end
            -- 存在牌才合理
            if colCards[i][card] and colCards[i][card].count > 0 then
                isLegal = true
            end
            -- currMult 必定大于0，因为上方已经判断过两个都为空的情况
            local currMult =
                (colCards[i][card] and colCards[i][card].count or 0) +
                (colCards[i][wild] and colCards[i][wild].count or 0)
            -- 计算这条线需要乘以的倍数
            if mult == 0 then
                mult = currMult
            else
                mult = mult * currMult
            end
            count = count + 1
            -- 如果有当前牌值，则加入索引
            if colCards[i][card] then
                for _, v in ipairs(colCards[i][card].indexes) do
                    table.insert(indexes, v)
                end
            end
            -- 如果有wild牌，则加入索引
            if colCards[i][wild] then
                for _, v in ipairs(colCards[i][wild].indexes) do
                    table.insert(indexes, v)
                end
            end
        end
        -- 如果是合法的，则计算线路
        if isLegal then
            tempResult[card] = {mult = mult, indexes = indexes, count = count}
        end
    end
    -- 下面这里，只有在scatter算分的情况下，才进行计算
    if GAME_CFG.RESULT_CFG[GAME_CFG.scatter].min <= 5 then
        local count = 0
        local idxs = {}
        for idx, card in ipairs(cards) do
            if card == GAME_CFG.scatter then
                count = count + 1
                table.insert(idxs, idx)
            end
        end
        if count > 0 then
            tempResult[GAME_CFG.scatter] = {mult = addMult, indexes = idxs, count = count}
        end
    end
    -- 根据统计的数据，计算结果
    for k, v in pairs(tempResult) do
        local result = {}
        if k ~= wild then
            -- 如果牌的数量大于最小配置，则可以算钱
            if GAME_CFG.RESULT_CFG[k].min <= v.count then
                result.mult = v.mult
                result.card = k
                result.indexs = v.indexes
                result.coin =  result.mult * deskInfo.singleBet * GAME_CFG.RESULT_CFG[k]["mult"][v.count]
                table.insert(winResult, result)
                winCoin = winCoin + result.coin
            end
        end
    end
    winCoin = math.round_coin(winCoin)
    return winCoin, winResult
end


local function start_698(deskInfo)
    local result = {}
    --发牌
    local cards = initResultCards(deskInfo) 
    local mults = {}
    if not isFreeState(deskInfo) then
        --随机产生wild的倍数 deskInfo.wildMult = math.random(2, 4)
        local wildCnt = 0
        for _, v in ipairs(cards)do
            if v == GAME_CFG.wilds[1] then
                wildCnt = wildCnt + 1
            end
        end
        if wildCnt > 0 then
            local ms = {2,2,2,3,3,4}
            if wildCnt >= 3 then
                ms = {2}
            elseif wildCnt >= 2 then
                ms = {2,2,2,3}
            end
            for k, v in ipairs(cards)do
                if v == GAME_CFG.wilds[1] then
                    mults["idx_"..k] = ms[math.random(1,#ms)]
                end
            end
        end
    end
    if collect.inFree(deskInfo) then
        -- 如果是地图触发的大游戏，则需要随机中间列相应的倍数
        local idx = deskInfo.collect.idx
        local ms = COLLECTCFG.MAP.MULTS[idx]
        deskInfo.collect.mult = ms[math.random(1, #ms)]
        mults = {}
    end
    result.resultCards = {cards = cards, mults = mults}
    result.winCoin, result.zjLuXian = checkResult(deskInfo, cards, mults)
    if collect.inFree(deskInfo) then
        result.winCoin, result.zjLuXian = collect.settleBigGame(deskInfo, result.winCoin, result.zjLuXian)
    end
    if result.scatterResult and result.scatterResult.coin == 0 then
		result.scatterResult.indexs = {}
	end
    --检车是否触发免费
	result.freeResult = checkFreeGame(cards, GAME_CFG.freeGameConf)
    return cashBaseTool.genRetobjProto(deskInfo, result)
end

local function settle_698(deskInfo, betCoin, retobj)
    local isFreeState = isFreeState(deskInfo)
    if isFreeState then
        updateFreeData(deskInfo, 2, nil, nil, retobj.wincoin)
    else
        if table.empty(retobj.freeResult.freeInfo) then
            caulCoin(deskInfo, retobj.wincoin, PDEFINE.ALTERCOINTAG.WIN)
        end
    end

    if not table.empty(retobj.freeResult.freeInfo) then
        deskInfo.select = {state = true, rtype = 3, wincoin = retobj.wincoin}
        retobj.wheelInfo = wheel.conf(deskInfo)
    end
    cashBaseTool.genFreeProto(deskInfo, retobj)  --产生免费游戏数据结果
    local result = {
        kind = betCoin==0 and "free" or "base",
        cards = retobj.resultCards
    }
	baseRecord.slotsGameLog(deskInfo, betCoin, retobj.wincoin, result, 0)
    if isFreeState and deskInfo.freeGameData.restFreeCount <= 0 then
        --如果是收集免费游戏，才清空数据
        if collect.inFree(deskInfo) then
            collect.clear(deskInfo)
        end
        updateFreeData(deskInfo, 3)
    end

	gameData.set(deskInfo)
	retobj.coin = deskInfo.user.coin  --最新的玩家金币
end


local function getColCards(cards, col, COLMAX, ROWMAX)
    local colIdxs = {}
    for row = 1, ROWMAX do
        table.insert(colIdxs, col + (row - 1)*COLMAX)
    end
    local colCards ={}
    for row = 1, ROWMAX do
        table.insert(colCards, cards[colIdxs[row]])
    end
    return colCards, colIdxs
end

local function getAllColCards(cards, COLMAX, ROWMAX)
    local colCards = {}
    for col = 1, COLMAX do
        local list = getColCards(cards, col, COLMAX, ROWMAX)
        table.insert(colCards, list)
    end
    return colCards
end

local function shuffle(tbl)
    if type(tbl)~="table" then
        return
	end
	local tmp = {}
	for i = 1, #tbl do
		local idx = math.random(1, #tbl)
		table.insert(tmp, tbl[idx])
		table.remove(tbl, idx)
	end
    return tmp
end

local function start(deskInfo) --正常游戏
	--如果有需要选择的，一定要先选择，才能旋转44
	if deskInfo.select and deskInfo.select.state then
        return {
			spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
		}
	end
	if isFreeState(deskInfo) then
		deskInfo.control.freeControl.probability = 0
    end
    local betCoin = caulBet(deskInfo)
    local retobj =  start_698(deskInfo)
    retobj.wildMults = table.copy(retobj.resultCards.mults)
    retobj.resultCards = table.copy(retobj.resultCards.cards)
	if not isFreeState(deskInfo) then
        collect.add(deskInfo, retobj.resultCards, COLLECTCARD)
        retobj.collect = table.copy(deskInfo.collect)
        pool.add(deskInfo, retobj.resultCards)
        retobj.pool = pool.ret(deskInfo)
    end
    retobj.collect = table.copy(deskInfo.collect)
    -- if collect.inFree(deskInfo) then
    --     retobj.collect = table.copy(deskInfo.collect)
    -- end
    if collect.inFree(deskInfo) then
		retobj.freeType = FREETYPE.COLLECTFREE
        -- 将平均下注额暴露出来
        retobj.avgBet = deskInfo.collect.bet
	elseif isFreeState(deskInfo) then
		retobj.freeType = FREETYPE.COMMONFREE
	else
		retobj.freeType = FREETYPE.NONE
	end
    settle_698(deskInfo, betCoin, retobj)
    retobj.select = deskInfo.select
    retobj.colcards = getAllColCards(retobj.resultCards, GAME_CFG.COL_NUM, GAME_CFG.ROW_NUM)
    for k, v in ipairs(retobj.colcards)do
        local scatterCnt = 0
        for _, i in ipairs(v)do
            if i == 9 then
                scatterCnt = scatterCnt + 1
            end
        end
        if scatterCnt > 1 then
            assert()
        end
    end
	return retobj
end

local function addSpecicalDeskInfo(deskInfo, simpleDeskData)
    simpleDeskData.select = deskInfo.select
    simpleDeskData.collect = deskInfo.collect
    simpleDeskData.wheelInfo = deskInfo.wheelInfo
    if deskInfo.pool then
        simpleDeskData.pool = pool.ret(deskInfo)
    end
	return simpleDeskData
end

local function gameLogicCmd(deskInfo, recvobj)
	local retobj = {}
	local rtype = math.floor(recvobj.rtype)
	if deskInfo.select and deskInfo.select.state then
		if rtype == 1 and deskInfo.collect.open == 1 and deskInfo.select.rtype == 1 then	--类型1，能量slots小游戏1，传入idx
			local ret = N77.get()
			retobj.cardsList = ret.cardsList
			retobj.wincoin = math.round_coin(ret.mult*deskInfo.collect.bet)
            -- 将平均下注额暴露出来
			retobj.avgBet = deskInfo.collect.bet
			cashBaseTool.caulCoin(deskInfo, retobj.wincoin, PDEFINE.ALTERCOINTAG.WIN)
            local result = {
                kind = "bonus",
                desc = "777",
            }
            baseRecord.slotsGameLog(deskInfo, 0, retobj.wincoin, result, 0)
			collect.clear(deskInfo)
			clearSelect(deskInfo)
		elseif rtype == 2 and collect.inFree(deskInfo)  and deskInfo.select.rtype == 2 then 	--类型2  地图大关免费游戏，需要下发选择	
			collect.startFree(deskInfo)	
			clearSelect(deskInfo)
        elseif rtype == 3 and deskInfo.select.rtype == 3  then		--类型3  转盘获取奖励，或者获取旋转免费次数，触发免费游戏
            local ret = wheel.result(deskInfo)
            for k, v in pairs(ret)do
                retobj[k] = v
            end
            if retobj.info.type ~= "free" then --金币
                cashBaseTool.caulCoin(deskInfo, retobj.info.num+deskInfo.select.wincoin, PDEFINE.ALTERCOINTAG.WIN)
                local result = {
                    kind = "bonus",
                    desc = "wheel coin",
                }
                baseRecord.slotsGameLog(deskInfo, 0, retobj.info.num+deskInfo.select.wincoin, result, 0)
            else    --免费次数
                updateFreeData(deskInfo, 1, retobj.info.num, 1, deskInfo.select.wincoin)
                local result = {
                    kind = "bonus",
                    desc = "wheel",
                }
                baseRecord.slotsGameLog(deskInfo, 0, deskInfo.select.wincoin, result, 0)
            end
            clearSelect(deskInfo)
        elseif rtype == 4 and deskInfo.select.rtype == 4  then		--类型4  点击罐子，获取大奖，pickBonus
            local idx = math.floor(recvobj.idx)
            retobj = pool.pick(deskInfo, idx)
            retobj.coin = 0
            if retobj.endFlag then
                retobj.coin = getJackPot(deskInfo, deskInfo.pool.type)
                cashBaseTool.caulCoin(deskInfo, retobj.coin, PDEFINE.ALTERCOINTAG.WIN)
                local result = {
                    kind = "bonus",
                    desc = "pick bonus",
                }
                baseRecord.slotsGameLog(deskInfo, 0, retobj.coin, result, 0)
                clearSelect(deskInfo)
                pool.init(deskInfo)
            end
		end
	end
	retobj.rtype = rtype
	gameData.set(deskInfo)
	return retobj
end

return {
	cardsConf = GAME_CFG.RESULT_CFG,
	mults = GAME_CFG.mults,
	line = GAME_CFG.line,
	create = create,
	start = start,
	getInitMult = getInitMult,
	getLine = getLine,
	gameLogicCmd = gameLogicCmd,
	addSpecicalDeskInfo = addSpecicalDeskInfo,
}

--[[
======================44中新增返回==========================
0. 是否需要选择(断线重连数据一致)
"select" :{
	rtype = 3, 			--上行51类型
	state = true		-- true 需要选择， false 不需要选择
}

1.进度条数据(免费游戏状态不下发)
	"collect":{
		"min":1				--最小押注等级开启能量条收集
		"total":100,		--能量条应收集总值(100个coinboom)
		"num":0,			--能量条收集数(当前收集0个)
		"idx":0,			--地图所处在的idx 1~20
		"open":0,			--地图当前开启的游戏类型 1：N77 2：free
		"mult":1,			--地图免费游戏时才会存在的数据, 第三列wild所需乘的倍数(!!!只有地图免费才会下发)
		}
	1.2能量条满
		"collect":{"idx":1,"total":10,"num":10,"open":1,"min":1}

2.正常游戏中wild翻倍信息
"wildMults":{"idx_4":3,"idx_12":3},

3.触发免费的转盘游戏
"wheelInfo":{
    "cfg":[     --18个配置，一Grand表示1， 组合：字符串+数字
        "GRAND",50000,2000000,"FREE8",100000,400000,"MEGA",25,100000,"FREE10",
        50000,2000000,"MINI",100000,300000,"FREE15",450000,1000000
        ],  
        --对应的翻倍的位置
    "mults":{"idx_12":3,"idx_15":2,"idx_18":2,"idx_3":2,"idx_17":2,"idx_2":2,"idx_6":2,"idx_11":5}
},

4.pickBonus信息，点击罐子获取奖池信息
"pool":{
    "min":1,        --最小押注额开启
    "total":30,     --总收集数
    "num":0         --当前收集数
    },
--触发bonus游戏
"pool":{
    "min":1,
    "total":5,
    "num":5，
    "pick":{
        "idx_12":{"state":false},"idx_11":{"state":false},"idx_17":{"state":false},"idx_16":{"state":false},
        "idx_20":{"state":false},"idx_10":{"state":false},"idx_3":{"state":false},"idx_14":{"state":false},
        "idx_6":{"state":false},"idx_13":{"state":false},"idx_8":{"state":false},"idx_15":{"state":false},
        "idx_4":{"state":false},"idx_2":{"state":false},"idx_18":{"state":false},"idx_9":{"state":false},
        "idx_5":{"state":false},"idx_1":{"state":false},"idx_7":{"state":false},"idx_19":{"state":false}
        },
    }
"select":{"state":true,"rtype":4}



4.新增错误码返回
spcode = 967, 	--流程错误, 有需要选择时没有选择


--==================2：51 ==========================
2.1能量小关游戏
	c : {c: 51, uid:*, gameid:*, data:{rtype:1}}
	--其中 rtype = 1 小型slots
	返回数据格式：
	{
		"data":{
			"rtype":1,
			"wincoin":1,		--赢分
			"cardsList":[
				[5,6,6],[1,1,7],[4,8,4],[1,1,1],[7,8,7] -每一局旋转的结果，最后一个是赢的牌
				]
			},
		"uid":102176,"c":51,"code":200}

2.2 地图大关游戏
	c : {c: 51, uid:*, gameid:*, data:{rtype:2}}  不需要处理返回结果
	返回数据格式：
	{c:51, code:200, uid:*, gameid:*, 
		data:{

        }
	}
2.3 触发免费游戏时的转盘游戏
    c : {c: 51, uid:*, gameid:*, data:{rtype:3}}
    返回数据格式：
    --1.免费类型结果信息
    {"data":{
        "idx":4,
        "rtype":3,
        "info":{"num":8,"type":"free"}
    },"uid":102804,"c":51,"code":200}
    2.金币类型结果信息
    {"data":{
        "idx":2,
        "rtype":3,
        "info":{"mult":2,"num":100000,"type":"coin"}
    },"uid":102804,"c":51,"code":200}
    3.奖池类型结果信息
     {"data":{
        "idx":2,
        "rtype":3,
        "info":{"num":100000,"type":"pool"}
    },"uid":102804,"c":51,"code":200}

2.4 类型4  点击罐子，获取大奖，pickBonus
    c : {c: 51, uid:*, gameid:*, data:{rtype:4, idx:1~20}}  不需要处理返回结果
	返回数据格式：
    s: {"data":{
        "idx":1,        --当前选择idx
        "coin":0,       --中奖金币
        "type":1,       --当前图标中奖类型
        "rtype":4,
        "pick":{        --20个格子信息 其中state = true表示该格子数据已经被点击过
            "idx_12":{"state":false},"idx_11":{"state":false},"idx_17":{"state":false},"idx_16":{"state":false},
            "idx_20":{"state":false},"idx_10":{"state":false},"idx_3":{"state":false},"idx_14":{"state":false},
            "idx_6":{"state":false},"idx_13":{"state":false},"idx_8":{"state":false},"idx_15":{"state":false},
            "idx_4":{"state":false},"idx_2":{"state":false},"idx_18":{"state":false},"idx_9":{"state":false},
            "idx_5":{"state":false},"idx_1":{"state":true,"type":1},"idx_7":{"state":false},"idx_19":{"state":false}
            }
        },"uid":102795,"c":51,"code":200}
    --最后一次点击信息
    {"data":{
        "endFlag":true,
        "type":3,
        "coin":225900,
        "rtype":4,
        "pick":{    
            "idx_6":{"state":true,"type":3},"idx_14":{"state":false,"type":"7"},"idx_13":{"state":false,"type":"7"},
            "idx_15":{"state":false,"type":"4"},"idx_7":{"state":true,"type":5},"idx_2":{"state":true,"type":1},
            "idx_11":{"state":false,"type":"6"},"idx_10":{"state":false,"type":"1"},"idx_3":{"state":true,"type":6},
            "idx_8":{"state":true,"type":1},"idx_5":{"state":true,"type":5},"idx_16":{"state":false,"type":"4"},
            "idx_4":{"state":true,"type":6},"idx_19":{"state":false,"type":"2"},"idx_18":{"state":false,"type":"2"},
            "idx_17":{"state":false,"type":"4"},"idx_1":{"state":true,"type":3},"idx_20":{"state":false,"type":"2"},
            "idx_9":{"state":true,"type":3},"idx_12":{"state":false,"type":"5"}
        },
        "idx":9
    },
    "uid":102799,"c":51,"code":200}


]]

