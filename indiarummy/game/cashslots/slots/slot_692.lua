-- magic orb
-- 魔法球

--[[
    基础规则
    1. 正常游戏3行5列，线路是50线
    2. 3个scatter触发免费游戏
    3. 卷轴中出现bonus图标，图标上会随机出免费游戏，金币，jackpot，5个图标触发子游戏

    免费规则
    1. 免费游戏中，中间3列合并成一列3行的大图标
    2. 一共9行，5列，线路变成150线
    3. 中间3列，在取图标的时候，会取每个slot中间3列最多的那个图标扩充

    bonus游戏
    1. bonus图标会复制到三个slot,每个slot都可以单独卷动，最后获得所有的魔法球上的金币和jackpot
    2. 如果有一个slot满上，则会奖励10倍，如果有两个slot满上则会奖励100倍，如果有三列满上，则会奖励1000倍
]]

local skynet = require "skynet"
local cluster = require "cluster"
local config = require "cashslots.common.config"
local cardProcessor = require "cashslots.common.cardProcessor"
local cashBaseTool = require "cashslots.common.base"
local settleTool = require "cashslots.common.gameSettle"
local player_tool = require "base.player_tool"
local baseRecord = require "base.record"
local recordTool = require "cashslots.common.gameRecord"
local gameData = recordTool.gameData
local record = recordTool.pushLog
local freeTool = require "cashslots.common.gameFree"
local checkIsFreeState = freeTool.isFreeState
local updateFreeData = freeTool.updateFreeData
local caulBet = cashBaseTool.caulBetandLastBetCoin
local utils = require "cashslots.common.utils"

local DEBUG = os.getenv("DEBUG")  -- 是否是调试阶段


local GAME_CFG = {
    gameid = 692,
    line = 50,
    winTrace = config.LINECONF[50][4],
    mults = config.MULTSCONF[888][1],
    RESULT_CFG = config.CARDCONF[692],
    wilds = {1},
    scatter = 2,
    bonus = 3,
    freeGameConf = {card = 2, min = 3, freeCnt = {[3]=5, [4]=8, [5]=12}, freeCntInFree=3, addMult = 1}, -- 免费游戏配置
    COL_NUM = 5,
    ROW_NUM = 3,
    middleIdxs = {2,3,4,7,8,9,12,13,14},  -- 中间三列的位置
    middleIdx = 8, -- 中间位置
}

-- 对应的jackpotId
local JackPot = {
    Mini = 1,
    Minor = 2,
    Major = 3,
    Grand = 4,
}

---------------------------------------------------------------------------------------
--- 参数配置
---------------------------------------------------------------------------------------

-- bonus游戏中最终获得的bonus图标数量权重
local BonusCountConfig = {
    [1] = {cnt=8, weight=50},
    [2] = {cnt=9, weight=200},
    [3] = {cnt=10, weight=400},
    [4] = {cnt=11, weight=600},
    [5] = {cnt=12, weight=1000},
    [6] = {cnt=13, weight=600},
    [7] = {cnt=14, weight=400},
    [8] = {cnt=15, weight=200},
}

-- 进入bonusGame的前提下，bonus图标上的金币大小以及概率
local BonusItemConfig = {
    [1] = {mult=nil, jackpotId=JackPot.Mini, weight=50},
    [2] = {mult=nil, jackpotId=JackPot.Minor, weight=20},
    [3] = {mult=nil, jackpotId=JackPot.Major, weight=2},
    [4] = {mult=nil, jackpotId=JackPot.Grand, weight=0},
    [5] = {mult=0.1, jackpotId=nil, weight=1000},
    [6] = {mult=0.2, jackpotId=nil, weight=600},
    [7] = {mult=0.5, jackpotId=nil, weight=300},
    [8] = {mult=1, jackpotId=nil, weight=100},
    [9] = {mult=2, jackpotId=nil, weight=40},
    [10] = {mult=5, jackpotId=nil, weight=10},
}

-- 正常旋转中bonus未进bonus游戏的概率
-- 这个概率可以稍微高一点
local FailBonusItemConfig = {
    [1] = {mult=nil, jackpotId=JackPot.Mini, weight=80},
    [2] = {mult=nil, jackpotId=JackPot.Minor, weight=40},
    [3] = {mult=nil, jackpotId=JackPot.Major, weight=10},
    [4] = {mult=nil, jackpotId=JackPot.Grand, weight=2},
    [5] = {mult=0.1, jackpotId=nil, weight=500},
    [6] = {mult=0.2, jackpotId=nil, weight=300},
    [7] = {mult=0.5, jackpotId=nil, weight=100},
    [8] = {mult=1, jackpotId=nil, weight=100},
    [9] = {mult=2, jackpotId=nil, weight=50},
    [10] = {mult=5, jackpotId=nil, weight=20},
}

-- 如果bonus游戏中slot满上之后的奖励
local BonusFullSlotConfig = {
    [1] = 10,  -- 第一个满上奖励10倍
    [2] = 100,  -- 第二个满上奖励100倍
    [3] = 1000,  -- 第三个满上奖励1000倍
}

---------------------------------------------------------------------------------------
--- 基础函数
---------------------------------------------------------------------------------------


-- 获取jackpot的列表
local function getJackpotList(deskInfo, gameId, totalBet)
    if TEST_RTP then
        return {1, 2, 3, 4}
    else
        -- 获取jackpot的列表
        local jackpotlist = {}
        local UNLOCK = config.JACKPOTCONF[gameId].UNLOCK
        local mults = deskInfo.mults
        for idx, unlockmultidx in ipairs(UNLOCK) do
            if unlockmultidx<=#mults and totalBet >= mults[unlockmultidx] then
                table.insert(jackpotlist, idx)
            end
        end
        return jackpotlist
    end
end

-- 获取jackpot数值
local function getJackpotValue(gameId, jackpotId, totalBet)
    local jackpotMult = config.JACKPOTCONF[gameId].MULT
    if TEST_RTP then
        return totalBet * jackpotMult[jackpotId]
    else
        return math.floor(totalBet * jackpotMult[jackpotId] * (0.95 + math.random()*0.1))
    end
end

-- 获取当前解锁进度条需要的下注额
local function getNeedBet(deskInfo)
    if DEBUG then
        return 2
    end
    local needBet = deskInfo.needbet or 5
    if needBet == 0 then
        needBet = 10
    end
    return needBet
end

local function initCustomData(deskInfo)
    if deskInfo.customData == nil then
        deskInfo.customData = {}
    end
end

---------------------------------------------------------------------------------------
--- 正常slot逻辑
---------------------------------------------------------------------------------------

local function getLine()
    return GAME_CFG.line
end

local function getInitMult()
    return GAME_CFG.defaultInitMult
end

-- 获取配置信息
local function getGameConf(deskInfo)
    local gameConf = GAME_CFG
    if checkIsFreeState(deskInfo) then
        gameConf.RESULT_CFG = config.CARDCONF[GAME_CFG.gameid]["free"]
    else
        gameConf.RESULT_CFG = config.CARDCONF[GAME_CFG.gameid]["base"]
    end
    return gameConf
end

-- 取正常的牌, 跟概率无关
local function getCards(deskInfo)
    local isFreeState = checkIsFreeState(deskInfo)
    local cardmap
    if isFreeState then
        cardmap = cardProcessor.getCardMap(deskInfo, "freemap")
    else
        cardmap = cardProcessor.getCardMap(deskInfo, "cardmap")
    end
    local cards
    -- 免费游戏，会随机3个slot, 拼接在一起
    if isFreeState then
        cards = {}
        -- 如果出现一个scatter，这个值就为false, 防止出现多个scatter
        local useScatter = true
        for i = 1, 3 do
            local subCards = cardProcessor.get_cards_1(cardmap, GAME_CFG.COL_NUM, GAME_CFG.ROW_NUM)
            local middleCard = subCards[GAME_CFG.middleIdx]
            if middleCard == GAME_CFG.scatter then
                -- 如果已经有scatter了，则这里不能再出现scatter
                if not useScatter then
                    middleCard = subCards[GAME_CFG.middleIdx+5]
                else
                    useScatter = false
                end
            end
            for _, idx in ipairs(GAME_CFG.middleIdxs) do
                subCards[idx] = middleCard
            end
            for idx, card in ipairs(subCards) do
                table.insert(cards, card)
            end
        end
    else
        cards = cardProcessor.get_cards_1(cardmap, GAME_CFG.COL_NUM, GAME_CFG.ROW_NUM)
    end
    return cards
end

--- 免费游戏检测方法
local function checkFreeGame(deskInfo, realCards, gameConf)
    local isFreeState = checkIsFreeState(deskInfo)
    local freeCardIdxs = {}
    local ret = {}
    -- 免费游戏卷轴不同，所以方式不同
    if isFreeState then
        -- 免费游戏只要出现了scatter图标，就会增加次数
        -- 只检测3个位置就行
        for _, idx in ipairs({2, 17, 32}) do
            if realCards[idx] == GAME_CFG.freeGameConf.card then
                table.insert(freeCardIdxs, idx)
            end
        end
        if #freeCardIdxs > 0 then
            ret.freeCnt = GAME_CFG.freeGameConf.freeCntInFree
            ret.scatterIdx = freeCardIdxs
            ret.scatter = GAME_CFG.freeGameConf.card
            ret.addMult = GAME_CFG.freeGameConf.addMult or 1
        end
    else
        for k, v in pairs(realCards) do
            if v == GAME_CFG.freeGameConf.card then
                table.insert(freeCardIdxs, k)
            end
        end
        if #freeCardIdxs >= GAME_CFG.freeGameConf.min then
            ret.freeCnt = GAME_CFG.freeGameConf.freeCnt[#freeCardIdxs]
            ret.scatterIdx = freeCardIdxs
            ret.scatter = GAME_CFG.freeGameConf.card
            ret.addMult = GAME_CFG.freeGameConf.addMult or 1
        end
    end
    return ret
end

-- 检测子游戏
local function checkSubGame(deskInfo, _, cards)
    if checkIsFreeState(deskInfo) then
        return false
    end
    local bonusIdxs = {}
    --- 统计目标牌
    for k, v in ipairs(cards) do
        if v == GAME_CFG.bonus then
            table.insert(bonusIdxs, k)
        end
    end
    -- 检测是否触发小游戏
    if #bonusIdxs >= 5 then
        return true, bonusIdxs
    end
    return false, bonusIdxs
end

-- 计算结果
local function getBigGameResult(deskInfo, cards, _)
    local isFreeState = checkIsFreeState(deskInfo)
    local gameConf = getGameConf(deskInfo)
    -- 免费游戏需要计算3个slot卷轴
    if isFreeState then
        local winCoin = 0
        local zjLuXian = {}
        local scatterResult = {}
        for i = 0, 2 do
            local resultCards = {}
            for j = 1, 15 do
                local idx = j + i*15
                table.insert(resultCards, cards[idx])
            end
            local _winCoin, _zjLuXian, _scatterResult = settleTool.getBigGameResult(deskInfo, resultCards, gameConf)
            winCoin = winCoin + _winCoin
            for _, rs in ipairs(_zjLuXian) do
                local indexs = {}
                for _, idx in ipairs(rs.indexs) do
                    table.insert(indexs, idx + i*15)
                end
                rs.indexs = indexs
                table.insert(zjLuXian, rs)
            end
        end
        return winCoin, zjLuXian, scatterResult
    else
        return settleTool.getBigGameResult(deskInfo, cards, gameConf)
    end
end

-- 发牌逻辑
local function initResultCards(deskInfo)
    local funcList = {
        getResultCards = getCards,
        checkFreeGame = checkFreeGame,
        checkSubGame = checkSubGame,
        getBigGameResult = getBigGameResult,
    }
    local gameConf = getGameConf(deskInfo)
    local cards = cardProcessor.get_cards_3(deskInfo, gameConf, funcList)

    local design = cashBaseTool.addDesignatedCards(deskInfo)
    if design ~= nil then
        cards = table.copy(design)
    end
    return cards
end

---------------------------------------------------------------------------------------
--- bonusGame信息
---------------------------------------------------------------------------------------

-- 根据概率生成卷轴中的bonus图标
local function genBonusCards(deskInfo, bonusIdxs, triggerBonusGame)
    local randNum = math.random()
    local itemConfigs = nil
    -- 触发了bonus游戏和没触发，对应bonus图标上的金币概率不同
    if triggerBonusGame then
        itemConfigs = table.copy(BonusItemConfig)
        local jackpotList = getJackpotList(deskInfo, GAME_CFG.gameid, deskInfo.totalBet)
        for _, cfg in pairs(itemConfigs) do
            if cfg.jackpotId and not table.contain(jackpotList, cfg.jackpotId) then
                cfg.weight = 0
            end
        end
    else
        itemConfigs = table.copy(FailBonusItemConfig)
    end

    local bonusItems = {}
    for _, idx in ipairs(bonusIdxs) do
        local _, rs = utils.randByWeight(itemConfigs)
        if rs.jackpotId then
            local jackpotId = rs.jackpotId
            if triggerBonusGame and jackpotId >= JackPot.Major then
                jackpotId = JackPot.Minor
            end
            table.insert(bonusItems, {idx=idx, jackpot={id=jackpotId}})
        else
            table.insert(bonusItems, {idx=idx, coin=math.round_coin(deskInfo.totalBet*rs.mult)})
        end
    end
    return bonusItems
end

-- 初始化bonusGame
local function initBonusGame(deskInfo)
    local bonusGame = {
        state = 0,  -- 0: 正常bonus游戏, 1: spin完之后，选择额外spin次数
        slots = {},  -- 三个卷轴对应的数据
        startPrize = deskInfo.totalBet,  -- 基础下注额
        spinCnt = 0,  -- 剩余spin的次数, 在后面根据bonus数量进行初始化
        totalSpinCnt = 0,  -- 总共spin的次数, 在后面根据bonus数量进行初始化
        jackpotValues = {},  -- 对应的jackpot值
        isEnd = false,  -- 是否结束
        winCoin = 0,  -- 最终赢的钱
        fullSlotCnt = 0,  -- slot满上的数量

        finalResult = {  -- 最终结果，提前算出，但是对前端隐藏
            extraSpins = {1,2,3}, -- 额外的次数选项
            extraSpinId = nil,  -- 额外中的选项索引
            results = {},  -- 每次中的内容{idxs, items}, spin之后，从前端取出结果
        }
    }
    for _, jp in ipairs({JackPot.Mini, JackPot.Minor, JackPot.Major, JackPot.Grand}) do
        local jackpotValue = getJackpotValue(GAME_CFG.gameid, jp, bonusGame.startPrize)
        bonusGame.jackpotValues[jp] = jackpotValue
    end
    deskInfo.customData.bonusGame = bonusGame
end

-- 初始化bonus游戏中的卷轴
local function initBonusGameSlots(deskInfo, bonusGame, bonusIdxs, bonusItems)
    bonusGame.spinCnt = #bonusIdxs
    bonusGame.totalSpinCnt = #bonusIdxs
    local slot = {
        bonusIdxs = bonusIdxs,
        bonusItems = table.copy(bonusItems),
        extraCoin = 0,  -- slot满上之后触发的奖励
    }
    for _, item in ipairs(slot.bonusItems) do
        if item.jackpot then
            item.jackpot.value = bonusGame.jackpotValues[item.jackpot.id]
        end
    end

    -- 计算出额外次数
    bonusGame.finalResult.extraSpins = utils.shuffle(bonusGame.finalResult.extraSpins)
    bonusGame.finalResult.extraSpinId = math.random(#bonusGame.finalResult.extraSpins)
    -- 总次数
    local extraSpinCnt = bonusGame.finalResult.extraSpins[bonusGame.finalResult.extraSpinId]
    local totalSpinCnt = bonusGame.spinCnt + extraSpinCnt
    -- 最终获得图标数量的配置
    local configs = table.copy(BonusCountConfig)
    -- 去掉不合理的权重(少于当前数量的)
    for _, cfg in pairs(configs) do
        if cfg.cnt < #bonusIdxs then
            cfg.weight = 0
        end
    end
    -- 获取bonusItem的配置表,并去掉不合理的jackpot选项
    local bonusItemConfigs = table.copy(BonusItemConfig)
    local jackpotList = getJackpotList(deskInfo, GAME_CFG.gameid, bonusGame.startPrize)
    for _, cfg in pairs(bonusItemConfigs) do
        if cfg.jackpotId and not table.contain(jackpotList, cfg.jackpotId) then
            cfg.weight = 0
        end
    end
    -- 提前生成三个slot的结果
    local totalCount = 0
    for i = 1, 3 do
        local copySlot = table.copy(slot)
        local currBonusIdxs = table.copy(bonusIdxs)
        local unUsedIdxs = {}  -- 空余的位置
        for idx = 1, GAME_CFG.COL_NUM * GAME_CFG.ROW_NUM do
            if not table.contain(currBonusIdxs, idx) then
                table.insert(unUsedIdxs, idx)
            end
        end
        -- 打散剩下的位置
        utils.shuffle(unUsedIdxs)
        -- 算出最终能获得的图标数量
        local _, rs = utils.randByWeight(configs)
        local rscnt = rs.cnt
        totalCount = totalCount + rscnt
        if totalCount >= 45 then
            rscnt = rscnt - 1
        end
        local finalCnt = rscnt - #bonusIdxs
        local results = {}
        -- 计算差值, 然后将差值的数量分配到可spin的次数内
        if finalCnt > 0 then
            local finalResult = utils.breakUpResult(finalCnt, totalSpinCnt)
            for _, cnt in ipairs(finalResult) do
                local result = {idxs={}, items={}}
                if cnt > 0 then
                    for _ = 1, cnt do
                        local _, itemRs = utils.randByWeight(bonusItemConfigs)
                        local item = {}
                        local idx = table.remove(unUsedIdxs)
                        if itemRs.jackpotId then
                            local jackpotValue = bonusGame.jackpotValues[itemRs.jackpotId]
                            table.insert(result.items, {idx=idx, jackpot={id=itemRs.jackpotId, value=jackpotValue}})
                            if itemRs.jackpotId >= JackPot.Major then
                                itemRs.weight = 0
                            end
                        elseif itemRs.mult then
                            table.insert(result.items, {idx=idx, coin=math.round_coin(bonusGame.startPrize * itemRs.mult)})
                        end
                        table.insert(result.idxs, idx)
                    end
                end
                table.insert(results, result)
            end
        else
            -- 一个都每中，那么每次都是空
            for _ = 1, totalSpinCnt do
                table.insert(results, {idxs={}, items={}})
            end
        end

        bonusGame.finalResult.results[i] = results
        bonusGame.slots[i] = copySlot
    end
end

-- 获取bonus游戏内容
local function getBonusGame(deskInfo)
    if not deskInfo.customData.bonusGame then
        return nil
    end
    local bonusGame = table.copy(deskInfo.customData.bonusGame)
    bonusGame.finalResult = nil
    return bonusGame
end

-- 随机额外次数
local function chooseExtraCnt(deskInfo, retobj)
    local bonusGame = deskInfo.customData.bonusGame
    if bonusGame.state ~= 1 then
        return nil
    end
    retobj.extraSpins = bonusGame.finalResult.extraSpins
    retobj.extraSpinId = bonusGame.finalResult.extraSpinId
    local spinCnt = retobj.extraSpins[retobj.extraSpinId]
    -- 更正下位置，用户选择的位置
    table.remove(retobj.extraSpins, retobj.extraSpinId)
    table.insert(retobj.extraSpins, retobj.choiceId, spinCnt)
    retobj.extraSpinId = retobj.choiceId
    bonusGame.state = 0
    bonusGame.spinCnt = bonusGame.spinCnt + spinCnt
    bonusGame.totalSpinCnt = bonusGame.totalSpinCnt + spinCnt
    retobj.bonusGame = getBonusGame(deskInfo)
    return retobj
end

-- bonus游戏转动一次
local function spinBonusGame(deskInfo)
    local bonusGame = deskInfo.customData.bonusGame
    if bonusGame.state ~= 0 then
        return nil
    end
    local currResult = {
        -- {
        --     idxs={},
        --     items={}
        -- },
        -- {
        --     idxs={},
        --     items={}
        -- }
    }
    
    bonusGame.spinCnt = bonusGame.spinCnt - 1
    -- 从预先的结果中弹出一个结果
    for i = 1, 3 do
        -- body
        local copySlot = bonusGame.slots[i]
        local result = table.remove(bonusGame.finalResult.results[i], 1)
        -- 将结果加入卷轴中，并发送给前端
        local hasNewItem = false
        for index, idx in ipairs(result.idxs) do
            if not table.contain(copySlot.bonusIdxs, idx) then
                table.insert(copySlot.bonusIdxs, idx)
                table.insert(copySlot.bonusItems, result.items[index])
                hasNewItem = true
            end
        end
        if hasNewItem and #copySlot.bonusIdxs == GAME_CFG.ROW_NUM*GAME_CFG.COL_NUM then
            bonusGame.fullSlotCnt = bonusGame.fullSlotCnt + 1
            copySlot.extraCoin = BonusFullSlotConfig[bonusGame.fullSlotCnt] * bonusGame.startPrize
        end
        currResult[i] = result
    end

    -- 如果剩余次数小于0
    if bonusGame.spinCnt <= 0 then
        -- 如果还没有转完，说明还有额外次数
        if #bonusGame.finalResult.results[2] > 0 then
            bonusGame.state = 1
            return {}
        else
            bonusGame.isEnd = true
            -- 结算
            for i = 1, 3 do
                local copySlot = bonusGame.slots[i]
                for _, item in ipairs(copySlot.bonusItems) do
                    if item.jackpot then
                        bonusGame.winCoin = bonusGame.winCoin + item.jackpot.value
                    else
                        bonusGame.winCoin = bonusGame.winCoin + item.coin
                    end
                end
                -- 加上满列奖励的钱
                bonusGame.winCoin = bonusGame.winCoin + copySlot.extraCoin
            end
        end
    end
    return currResult
end


local function start_692(deskInfo)
    local isFreeState = checkIsFreeState(deskInfo)
    local result = {}

    --发牌
    result.resultCards = initResultCards(deskInfo)
    --检车是否触发免费
    result.freeResult = checkFreeGame(deskInfo, result.resultCards, GAME_CFG)

    -- 检测是否触发bonus游戏
    local triggerSubGame, bonusIdxs, bonusItems
    if not isFreeState then
        triggerSubGame, bonusIdxs = checkSubGame(deskInfo, GAME_CFG, result.resultCards)
        bonusItems = genBonusCards(deskInfo, bonusIdxs, triggerSubGame)
        if triggerSubGame then
            initBonusGame(deskInfo)
            initBonusGameSlots(deskInfo, deskInfo.customData.bonusGame, bonusIdxs, bonusItems)
        end
    end

    --计算结果
    result.winCoin, result.zjLuXian, result.scatterResult = getBigGameResult(deskInfo, result.resultCards)

    local retobj = cashBaseTool.genRetobjProto(deskInfo, result)
    retobj.bonusGame = deskInfo.customData.bonusGame
    retobj.bonusIdxs = bonusIdxs
    retobj.bonusItems = bonusItems
    return retobj
end

---------------------------------------------------------------------------------------
--- CMD 43 交互
---------------------------------------------------------------------------------------

local function create(deskInfo, uid)
    if not deskInfo.customData then
        initCustomData(deskInfo)
    end
end

---------------------------------------------------------------------------------------
--- CMD 44 交互
---------------------------------------------------------------------------------------

local function start(deskInfo) --正常游戏
    if deskInfo.customData.bonusGame then
        LOG_ERROR("the bonusGame is not nil")
        return {
            errMsg = "the bonusGame is not nil",
            spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
        }
    end
    local isFreeState = checkIsFreeState(deskInfo)
    -- 免费不能触发bonus游戏
    if isFreeState then
        -- 免费游戏触发免费游戏的概率加大
        deskInfo.control.freeControl.probability = deskInfo.control.freeControl.probability * 2
        deskInfo.control.bonusControl.probability = 0
    end
    local betCoin = caulBet(deskInfo)

    local retobj = start_692(deskInfo)

    -- 如果是最后一局，需要清除掉免费信息
    -- if isFreeState and deskInfo.freeGameData.restFreeCount == 1 and table.empty(retobj.freeResult.freeInfo) then
        
    -- end
    cashBaseTool.settle(deskInfo, betCoin, retobj)
    return retobj
end

local function resetDeskInfo(deskInfo)
    gameData.set(deskInfo)
end

---------------------------------------------------------------------------------------
--- CMD 51 交互
---------------------------------------------------------------------------------------

local function gameLogicCmd(deskInfo, recvobj)
    local retobj = {}
    local rtype = math.floor(recvobj.rtype)
    retobj.rtype = rtype
    if rtype == 1 then -- 存在bonusGame, 且bonusGame.state == 1
        if not deskInfo.customData.bonusGame then
            retobj.errMsg = "The bonusGame is nil"
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        if deskInfo.customData.bonusGame.state ~= 1 then
            retobj.errMsg = "The bonusGame.state is not 1"
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        if not recvobj.choiceId then
            retobj.errMsg = "The choiceId is nil"
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        retobj.choiceId = recvobj.choiceId
        retobj = chooseExtraCnt(deskInfo, retobj)
    elseif rtype == 2 then -- 存在bonusGame, 且bonusGame.state == 0
        if not deskInfo.customData.bonusGame then
            retobj.errMsg = "The bonusGame is nil"
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        if deskInfo.customData.bonusGame.state ~= 0 then
            retobj.errMsg = "The bonusGame.state is not 0"
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        retobj.result = spinBonusGame(deskInfo)
        retobj.bonusGame = getBonusGame(deskInfo)
        -- 如果游戏结束，则清空bonusGame
        if retobj.bonusGame.isEnd then
            if checkIsFreeState(deskInfo) then
                deskInfo.freeGameData.freeWinCoin = deskInfo.freeGameData.freeWinCoin + retobj.bonusGame.winCoin
            else
                cashBaseTool.caulCoin(deskInfo, retobj.bonusGame.winCoin, PDEFINE.ALTERCOINTAG.WIN)
            end
            local result = {
                kind = "bonus",
                desc = "spin bonus game",
            }
            baseRecord.slotsGameLog(deskInfo, 0, retobj.bonusGame.winCoin, result, 0)
            deskInfo.customData.bonusGame = nil
        end
    end
    gameData.set(deskInfo)
    return retobj
end

---------------------------------------------------------------------------------------
--- CMD 43 额外增加的字段
---------------------------------------------------------------------------------------

local function addSpecicalDeskInfo(deskInfo, simpleDeskData)
    simpleDeskData.needBet = getNeedBet(deskInfo)
    if deskInfo.customData.bonusGame then
        simpleDeskData.bonusGame = deskInfo.customData.bonusGame
    end
    return simpleDeskData
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
    addSpecicalDeskInfo = addSpecicalDeskInfo
}

---------------------------------------------------------------------------------------
--- 消息结构说明
---------------------------------------------------------------------------------------

--[[

-- 对应的jackpotId
local JackPot = {
    Mini = 1,
    Minor = 2,
    Major = 3,
    Grand = 4,
}

-- bonus游戏信息
local bonusGame = {
    state = 0,  -- 0: 正常bonus游戏, 1: spin完之后，选择额外spin次数
    slots = { -- 两个卷轴对应的数据
        bonusIdxs = bonusIdxs,  -- bonus位置
        bonusItems = table.copy(bonusItems),  -- bonus内容 {coin=nil, jackpot=nil}
        extraCoin = 0,  -- slot满上之后触发的奖励
    },
    startPrize = deskInfo.totalBet,  -- 基础下注额
    spinCnt = 6,  -- 剩余spin的次数
    totalSpinCnt = 6,  -- 总共spin的次数
    jackpotValues = {},  -- 对应的jackpot值
    isEnd = false,  -- 是否结束
    winCoin = 0,  -- 最终赢的钱
    fullSlotCnt = 0,  -- 已经满上的slot数量
}


-- 44协议额外字段
retobj.bonusGame = bonusGame  -- bonus游戏信息
retobj.bonusIdxs = bonusIdxs  -- 辣椒位置
retobj.bonusItems = bonusItems  -- 辣椒上面的值

-- 51协议
{rtype=1, choiceId=1}  -- bonus游戏结束后要选择额外次数

res: {
    choiceId=choiceId,
    extraSpins = {1,3,2},  -- 中的结果
    extraSpinId = choiceId,  -- 中的位置
    bonusGame = bonusGame,  -- bonusGame信息
}

{rtype=2}  -- bonus游戏中spin
res: {
    result = {  -- 对应两个slot新增的辣椒图标
        {
            idxs={},
            items={}  -- {coin=nil, jackpot=nil, baseCoin=nil} baseCoin代表金辣椒
        },
        {
            idxs={},
            items={}
        }
    },
    bonusGame = bonusGame,
}
]]