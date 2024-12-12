-- captain jackpot
-- 航海宝藏

--[[
    基础规则
    1. 正常游戏3行5列，线路是30线
    2. 3个scatter触发免费游戏
    3. 卷轴中出现bonus图标，5个图标触发子游戏

    免费规则
    1. 免费游戏中，出现船会在当轮结束时移动到左边列随机位置，可以合并，并且中线奖励翻倍，最多3倍
    2. 免费游戏中3个以上的scatter触发固定10次免费游戏
    
    bonus游戏
    1. 5个bonus图标触发小游戏，给予3次spin机会
    2. 每获得一个bonus图标会重置spin次数
    3. 结束spin之后，会让玩家选择3个金币上的金币作为奖励
    4. 金币的最终数量决定能获得jackpot奖励
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
    gameid = 696,
    line = 30,
    winTrace = config.LINECONF[30][1],
    mults = config.MULTSCONF[888][1],
    RESULT_CFG = config.CARDCONF[696],
    wilds = {1},
    scatter = 2,
    bonus = 3,
    freeGameConf = {card = 2, min = 3, freeCnt = 10, addMult = 1},
    COL_NUM = 5,
    ROW_NUM = 3,
    collectionCard = 3,
}

-- 对应的jackpotId
local JackPot = {
    jp5 = 1,
    jp6 = 2,
    jp7 = 3,
    jp8 = 4,
    jp9 = 5,
    jp10 = 6,
    jp11 = 7,
    jp12 = 8,
    jp13 = 9,
    jp14 = 10,
    jpmax = 10,
}

---------------------------------------------------------------------------------------
--- 参数配置
---------------------------------------------------------------------------------------

-- 配置普通图标的数量, 对应零个上升图标
-- moveUpProb 对应出现上升图标的概率，一局只会出现一个图标
local BonusCountConfig = {
    [1] = {cnt=5, jackpotId=JackPot.jp5, weight=60, moveUpProb=0.15},
    [2] = {cnt=6, jackpotId=JackPot.jp6, weight=120, moveUpProb=0.1},
    [3] = {cnt=7, jackpotId=JackPot.jp7, weight=250, moveUpProb=0.1},
    [4] = {cnt=8, jackpotId=JackPot.jp8, weight=500, moveUpProb=0.05},
    [5] = {cnt=9, jackpotId=JackPot.jp9, weight=500, moveUpProb=0.02},
    [6] = {cnt=10, jackpotId=JackPot.jp10, weight=80, moveUpProb=0.01},
    [7] = {cnt=11, jackpotId=JackPot.jp11, weight=30, moveUpProb=0},
    [8] = {cnt=12, jackpotId=JackPot.jp12, weight=10, moveUpProb=0},
    [9] = {cnt=13, jackpotId=JackPot.jp13, weight=2, moveUpProb=0},
}

-- 进入bonusGame的前提下，bonus图标上的金币大小以及概率
local BonusItemConfig = {
    [1] = {mult=1, weight=200},
    [2] = {mult=1.5, weight=200},
    [3] = {mult=2, weight=150},
    [4] = {mult=2.5, weight=100},
    [5] = {mult=3, weight=100},
}

-- 小游戏最后选择item时，含有pick+1的概率
local BonusItemExtraPickConfig = {
    [1] = {cnt=0, weight=1000},  -- 没有pickCnt
    [2] = {cnt=1, weight=200},  -- pick + 1
    [3] = {cnt=2, weight=20},  -- pick + 2
    [4] = {cnt=3, weight=10},  -- pick + 3
}

--收集所需数量
local COLLECT_NEED_COUNT = 150

-- 进度条满之后的转盘配置
local WheelMultConfig = {
    [1] = {mult = 1, weight = 10, type = 1}, -- type代表三个不同的物品
    [2] = {mult = 2, weight = 2, type = 1},
    [3] = {mult = 1, weight = 10, type = 2},
    [4] = {mult = 2, weight = 2, type = 2},
    [5] = {mult = 1, weight = 10, type = 3},
    [6] = {mult = 2, weight = 2, type = 3}
}

-- bonus游戏集满21个图标之后，切分的倍数配置
local SliceMultConfig = {1, 2, 3, 6, 10, 20, 50}

-- bonus游戏集满之后，切分的行数和列数权重
local SliceColRowConfig = {
    cols = {1, 2, 3, 4},
    rows = {1, 2, 3, 4},
}

---------------------------------------------------------------------------------------
--- 基础函数
---------------------------------------------------------------------------------------

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

local function initProgressBar(deskInfo)
    local needCnt = DEBUG and 20 or COLLECT_NEED_COUNT

    local progressData = {
        needCnt = needCnt, -- 进度条需要的收集数量
        totalCnt = 0, -- 进度条当前收集数量
        totalCoin = 0, -- 进度条收集到的金币数量，用于计算出最终价值
        currCnt = 0,  -- 当前收集数量
    }
    return progressData
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

-- 取正常的牌, 跟概率无关
local function getCards(deskInfo)
    local isFreeState = checkIsFreeState(deskInfo)
    local cardmap
    if isFreeState then
        cardmap = cardProcessor.getCardMap(deskInfo, "freemap")
    else
        cardmap = cardProcessor.getCardMap(deskInfo, "cardmap")
    end
    local cards = cardProcessor.get_cards_1(cardmap, GAME_CFG.COL_NUM, GAME_CFG.ROW_NUM)

    -- 将已有wild放入卷轴中
    if isFreeState then
        for _, wildItem in ipairs(deskInfo.customData.wildInfo) do
            cards[wildItem.idx] = GAME_CFG.wilds[1]
        end
    end

    return cards
end

--- 免费游戏检测方法
local function checkFreeGame(deskInfo, realCards, gameConf)
    local isFreeState = checkIsFreeState(deskInfo)
    local freeCardIdxs = {}
    local ret = {}
    for k, v in pairs(realCards) do
        if v == GAME_CFG.freeGameConf.card then
            table.insert(freeCardIdxs, k)
        end
    end
    if #freeCardIdxs >= GAME_CFG.freeGameConf.min then
        ret.freeCnt = GAME_CFG.freeGameConf.freeCnt
        ret.scatterIdx = freeCardIdxs
        ret.scatter = GAME_CFG.freeGameConf.card
        ret.addMult = GAME_CFG.freeGameConf.addMult or 1
    end
    return ret
end

-- 检测子游戏
local function checkSubGame(deskInfo, _, cards)
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
    -- 计算结果
    local winCoin = 0
    local traceResult = {}
    local scatterResult = {}
    winCoin, traceResult, scatterResult = settleTool.getBigGameResult(deskInfo, cards, GAME_CFG)

    return winCoin, traceResult, scatterResult
end

-- 发牌逻辑
local function initResultCards(deskInfo)
    local funcList = {
        getResultCards = getCards,
        checkFreeGame = checkFreeGame,
        checkSubGame = checkSubGame,
        getBigGameResult = getBigGameResult,
    }
    local cards = cardProcessor.get_cards_3(deskInfo, GAME_CFG, funcList)

    -- 记录新出现的wild
    if checkIsFreeState(deskInfo) then
        local existIdxs = {}
        for _, item in ipairs(deskInfo.customData.wildInfo) do
            existIdxs[item.idx] = 1
        end
        for idx, card in ipairs(cards) do
            if not existIdxs[idx] and card == GAME_CFG.wilds[1] then
                table.insert(deskInfo.customData.wildInfo, {idx=idx, mult=1, prevIdx = nil})
            end
        end
    end

    local design = cashBaseTool.addDesignatedCards(deskInfo)
    if design ~= nil then
        cards = table.copy(design)
    end
    return cards
end

---------------------------------------------------------------------------------------
--- bonusGame信息
---------------------------------------------------------------------------------------

-- 初始化bonusGame
local function initBonusGame(deskInfo, bonusIdxs)
    local bonusGame = {
        state = 1,  -- 游戏状态 1=等待开始，2=spin状态，3=选择金币状态
        items = {},  -- 位置上的bonus图标, 位置是从1-30
        spinCnt = 3,  -- 剩余spin的次数
        pickCnt = 3,  -- 剩余的选择次数
        restItemCnt = 0,  -- 剩余的可选bonus数量
        row = 3,  -- 当前行数
        jackpotValues = {},  -- 对应的jackpot值
        winCoin = 0,  -- 最终赢的钱
        jackpot = nil,  -- 最终获得的jackpot
        isEnd = false,  -- 是否结束

        results = {},  -- 每次中的内容
        jackpotId = nil,  -- 最终获得的jackpotId
    }
    for jp = 1, JackPot.jpmax do
        local jackpotValue = getJackpotValue(GAME_CFG.gameid, jp, deskInfo.totalBet)
        bonusGame.jackpotValues[jp] = jackpotValue
    end
    -- 转换已有图标位置
    local exist_idxs = {}
    for _, idx in ipairs(bonusIdxs) do
        local _, rs = utils.randByWeight(BonusItemConfig)
        local _, pickRs = utils.randByWeight(BonusItemExtraPickConfig)
        local item = {idx=idx, pickCnt=pickRs.cnt, coin=math.round_coin(deskInfo.totalBet*rs.mult), isOpen=false}
        table.insert(bonusGame.items, item)
        table.insert(exist_idxs, item.idx)
    end
    -- 计算可用位置
    local ledgal_idxs = {}
    for idx = 1, 15 do
        if not table.contain(exist_idxs, idx) then
            table.insert(ledgal_idxs, idx)
        end
    end
    local configs = table.copy(BonusCountConfig)
    -- 去掉不合理的数量
    for _, cfg in ipairs(configs) do
        if cfg.cnt < #bonusGame.items then
            cfg.weight = 0
        end
    end
    -- 根据随机情况，生成结果
    local _, cnt_rs = utils.randByWeight(configs)
    bonusGame.jackpotId = cnt_rs.jackpotId
    local finalCnt = cnt_rs.cnt - #bonusGame.items
    -- 判断是否出现moveUp图标
    -- 如果出现moveUp图标，就在初始的5个图标中选一个
    if math.random() < cnt_rs.moveUpProb then
        bonusGame.items[math.random(#bonusGame.items)].moveUp = true
    end

    -- 生成bonus图标
    local results = {}

    -- 如果有上升图标，则需要在16-30中塞一个
    utils.shuffle(ledgal_idxs)
    local row = 3
    -- 如果没有图标需要随机，则直接插入3个空白
    if finalCnt == 0 then
        for i = 1, 3 do
            table.insert(results, {})
        end
    else
        -- 开始随机其他位置的图标
        local randindex = utils.genRandIdxs(#ledgal_idxs, finalCnt)
        local randIdxs = {}
        for _, i in ipairs(randindex) do
            table.insert(randIdxs, ledgal_idxs[i])
        end
        -- 将结果分散到不同步数中
        local randCnt = utils.breakUpResult(#randIdxs, #randIdxs)
        local spinCnt = 3
        while spinCnt > 0 do
            spinCnt = spinCnt - 1
            local cnt = table.remove(randCnt, 1) or 0
            local _rs = {}
            if cnt > 0 then
                for i = 1, cnt do
                    local idx = table.remove(randIdxs, 1)
                    if idx then
                        local _, itemRs = utils.randByWeight(BonusItemConfig)
                        local _, pickRs = utils.randByWeight(BonusItemExtraPickConfig)
                        table.insert(_rs, {idx=idx, pickCnt=pickRs.cnt, coin=math.round_coin(itemRs.mult*deskInfo.totalBet),isOpen=false})
                    end
                end
            end
            if #_rs > 0 then
                spinCnt = 3
            end
            -- 这里防止出现3个连续的空白，造成游戏结束，但是结果还没有完全结束
            if #_rs == 0 and spinCnt == 0 and #results > 0 then
                spinCnt = spinCnt + 1
            else
                table.insert(bonusGame.results, _rs)
            end
        end
    end
    deskInfo.customData.bonusGame = bonusGame
end

-- 获取bonus游戏内容
local function getBonusGame(deskInfo)
    if not deskInfo.customData.bonusGame then
        return nil
    end
    local bonusGame = table.copy(deskInfo.customData.bonusGame)
    bonusGame.results = nil
    if bonusGame.state ~= 3 then
        bonusGame.jackpotId = nil
    end
    return bonusGame
end

-- bonus游戏转动一次
local function spinBonusGame(deskInfo)
    local bonusGame = deskInfo.customData.bonusGame
    -- 切换状态
    if bonusGame.state == 1 then
        bonusGame.state = 2
    end
    local currResult = {}
    
    bonusGame.spinCnt = bonusGame.spinCnt - 1
    -- 从预先的结果中弹出一个结果
    local result = table.remove(bonusGame.results, 1)
    -- 将结果加入卷轴中，并发送给前端
    if result and #result > 0 then
        bonusGame.spinCnt = 3
        for _, item in ipairs(result) do
            table.insert(currResult, item)
            table.insert(bonusGame.items, item)
        end
    end

    -- 如果剩余次数小于0 或者已有位置满了
    local currCnt = #bonusGame.items
    if bonusGame.spinCnt <= 0 then
        -- 切换状态，客户端选择最终的3个物品
        bonusGame.state = 3
        bonusGame.spinCnt = 0
        bonusGame.restItemCnt = #bonusGame.items
    end
    return currResult
end

-- 选择bonus图标作为最终奖励
local function pickBonusItem(deskInfo, choiceId)
    local bonusGame = deskInfo.customData.bonusGame
    if bonusGame.state ~= 3 then
        return nil
    end
    for _, item in ipairs(bonusGame.items) do
        if item.idx == choiceId then
            item.isOpen = true
            bonusGame.winCoin = bonusGame.winCoin + item.coin
            bonusGame.pickCnt = bonusGame.pickCnt - 1
            bonusGame.restItemCnt = bonusGame.restItemCnt - 1
            if item.pickCnt then
                bonusGame.pickCnt = bonusGame.pickCnt + item.pickCnt
            end
            -- 如果有moveUp，则需要将jackpot往上涨一层
            if item.moveUp then
                bonusGame.jackpotId = bonusGame.jackpotId + 1
            end
            break
        end
    end
    -- 选择完之后，需要加上jackpot的值
    if bonusGame.pickCnt == 0 or bonusGame.restItemCnt == 0 then
        bonusGame.jackpot = {
            id = bonusGame.jackpotId,
            value = bonusGame.jackpotValues[bonusGame.jackpotId]
        }
        bonusGame.winCoin = bonusGame.winCoin + bonusGame.jackpot.value
        bonusGame.isEnd = true
    end
end

---------------------------------------------------------------------------------------
--- 收集游戏
---------------------------------------------------------------------------------------

-- 初始化collectGame数据
local function initCollectGame(deskInfo)
    if deskInfo.customData == nil then
        initCustomData(deskInfo)
    end

    deskInfo.customData.collectGame = {
        choiceId = nil,  -- 进入最终游戏阶段选择的物品类型
        state = 0, -- 状态， 0=收集状态，1=转盘状态，2=结算前选择类型
        col = 4, -- 多少列
        row = 4, -- 多少行
        collectionItems = {}, -- 已收集到的物品 {coin=1000, type=1}
        collectionIdxs = {}, -- 已收集到物品的位置
        progressData = initProgressBar(deskInfo)
    }
    -- 开发阶段，直接满上，方便测试
    if DEBUG then
        deskInfo.customData.collectGame.collectionItems = {
            {coin=1000, type=1},{coin=1000, type=1},{coin=1000, type=1},
            {coin=1000, type=1},{coin=1000, type=1},{coin=1000, type=1},
            {coin=1000, type=1},{coin=1000, type=1},{coin=1000, type=1},
            {coin=1000, type=1},{coin=1000, type=1},{coin=1000, type=1},
            {coin=1000, type=1},{coin=1000, type=1}
        }
        deskInfo.customData.collectGame.collectionIdxs = {1,2,3,4,5,6,7,8,9,10,11,12,13,14} -- 已收集到物品的位置
    end
end

-- 增加一个游戏物品
-- item: {coin=1000, type=1}
local function addCollectItem(deskInfo, item)
    local collectGameData = deskInfo.customData.collectGame
    local noFillIdx = {} -- 未放物品的位置
    local totalCnt = collectGameData.col * collectGameData.row
    -- 计算出未放物品的位置
    for i = 1, totalCnt do
        if not table.contain(collectGameData.collectionIdxs, i) then
            table.insert(noFillIdx, i)
        end
    end
    -- 随机出一个位置
    local idx = noFillIdx[math.random(#noFillIdx)]
    table.insert(collectGameData.collectionIdxs, idx)
    table.insert(collectGameData.collectionItems, table.copy(item))
    if #collectGameData.collectionIdxs == collectGameData.col * collectGameData.row then
        collectGameData.state = 2 -- 切换状态，进入最终奖励阶段，选择类型阶段
    else
        collectGameData.state = 0
    end
    return idx
end

-- 格子满了触发bonus游戏结算
local function settleCollectGame(deskInfo)
    local collectGameData = deskInfo.customData.collectGame
    local result = {} -- 产生最终结果的过程 {{col=1, row=1, coin=2}, }
    local winCoin = 0
    -- 判断是否可以结算
    if collectGameData.col * collectGameData.row ~= #collectGameData.collectionIdxs then
        return nil
    end
    local sliceColRowConfigCopy = table.copy(SliceColRowConfig)
    utils.shuffle(sliceColRowConfigCopy.rows)
    utils.shuffle(sliceColRowConfigCopy.cols)
    local settleIdxs = {}  -- 存储已经结算过的位置，防止重复计算
    -- 一共随机6次，最后两次只需要随机一行，或者一列
    for ranIdx = 1, 7 do
        local item = {col = nil, row = nil, coin = 0} -- 每一步对应的行列和增加的钱
        -- 如果是第7次，则只要选剩下的那个就行
        if ranIdx == 7 then
            if #sliceColRowConfigCopy.rows == 1 then
                item.row = sliceColRowConfigCopy.rows[1]
            else
                item.col = sliceColRowConfigCopy.cols[1]
            end
        else
            -- 只要行列大于1，就可以随机
            if #sliceColRowConfigCopy.rows > 1 then
                if #sliceColRowConfigCopy.cols > 1 and math.random() > 0.5 then
                    item.col = table.remove(sliceColRowConfigCopy.cols)
                else
                    item.row = table.remove(sliceColRowConfigCopy.rows)
                end
            else
                item.col = table.remove(sliceColRowConfigCopy.cols)
            end
        end

        for index, idx in ipairs(collectGameData.collectionIdxs) do
            -- 如果符合行列的，需要将钱累加起来
            local col = math.fmod(idx, collectGameData.col)
            if col == 0 then
                col = collectGameData.col
            end
            local row = math.ceil(idx / collectGameData.col)
            if (item.col == col or item.row == row) then
                if not table.contain(settleIdxs, idx) then
                    -- 如果是最后一个item，且item的类型等于选择的类型，则需要翻倍
                    if ranIdx == 7 and collectGameData.collectionItems[index].type == collectGameData.choiceId then
                        item.coin = item.coin + collectGameData.collectionItems[index].coin * SliceMultConfig[ranIdx] * 2
                    else
                        item.coin = item.coin + collectGameData.collectionItems[index].coin * SliceMultConfig[ranIdx]
                    end
                end
                table.insert(settleIdxs, idx)
            end
        end
        table.insert(result, item)
        winCoin = winCoin + item.coin
    end
    -- 重置状态
    initCollectGame(deskInfo)
    return result, winCoin
end

---------------------------------------------------------------------------------------
--- 收集
---------------------------------------------------------------------------------------

-- 能量收集
local function collectProgressBar(deskInfo, cards)
    local times = 0
    if deskInfo.currmult >= getNeedBet(deskInfo) then
        for _, v in ipairs(cards) do
            if v == GAME_CFG.collectionCard then
                times = times + 1
            end
        end
    end
    return times
end

-- 将卷轴里能收集的个数汇总到进度条
local function addProgressBar(deskInfo, addTotal)
    -- local ret = {}
    local curCnt = 0
    local nextStep = false
    if DEBUG then  -- 调试阶段，降低门槛
        if deskInfo.currmult >= 2 then
            nextStep = true
        end
    else
        if deskInfo.currmult >= getNeedBet(deskInfo) then
            nextStep = true
        end
    end
    if nextStep and addTotal > 0 then
        curCnt = addTotal
        -- 总的收集进度
        local totalCnt = deskInfo.customData.collectGame.progressData.totalCnt + addTotal
        -- 总的收集金币数量
        local totalCoin = deskInfo.customData.collectGame.progressData.totalCoin + addTotal * deskInfo.totalBet
        deskInfo.customData.collectGame.progressData.totalCnt = totalCnt
        deskInfo.customData.collectGame.progressData.totalCoin = totalCoin
        if deskInfo.customData.collectGame.progressData.totalCnt >= deskInfo.customData.collectGame.progressData.needCnt then
            -- if deskInfo.customData.collectGame.progressData.totalCnt >= 1 then
            deskInfo.customData.collectGame.state = 1 -- 切换状态， 进入转盘选择奖励阶段
            local items = {}
            for key, value in pairs(WheelMultConfig) do
                local coin =
                    value.mult *
                    math.round_coin(
                        deskInfo.customData.collectGame.progressData.totalCoin /
                            deskInfo.customData.collectGame.progressData.totalCnt
                    )
                table.insert(
                    items,
                    {
                        id = key,
                        type = value.type,
                        coin = coin,
                        mult = value.mult
                    }
                )
            end
            deskInfo.customData.collectGame.progressData.wheelItems = items
        end
    end
    return curCnt
end

--------------------------------------------------------------------------------
--- 协议流程
--------------------------------------------------------------------------------


local function start_696(deskInfo)
    local isFreeState = checkIsFreeState(deskInfo)
    local result = {}

    -- 如果是免费游戏，则需要移动已有的wild记录
    if isFreeState and #deskInfo.customData.wildInfo > 0 then
        local tmp_map = {}
        for _, item in ipairs(deskInfo.customData.wildInfo) do
            local col = math.fmod(item.idx, GAME_CFG.COL_NUM)
            if col == 0 then
                col = GAME_CFG.COL_NUM
            end
            if col > 1 then
                local row = math.random(GAME_CFG.ROW_NUM)
                local idx = (row-1)*GAME_CFG.COL_NUM + col - 1
                -- 记录前一个位置
                item.prevIdx = {item.idx}
                -- 记录当前位置
                item.idx = idx
                -- 如果当前位置有wild, 则mult累加
                if tmp_map[idx] then
                    table.insert(tmp_map[idx].prevIdx, item.prevIdx[1])
                    tmp_map[idx].mult = tmp_map[idx].mult + item.mult
                    if tmp_map[idx].mult > 3 then
                        tmp_map[idx].mult = 3
                    end
                else
                    tmp_map[idx] = item
                end
            end
        end
        -- 清空现有记录, 将变化后的数据导入
        deskInfo.customData.wildInfo = {}
        for _, item in pairs(tmp_map) do
            table.insert(deskInfo.customData.wildInfo, item)
        end
    end

    --发牌
    result.resultCards = initResultCards(deskInfo)

    --检车是否触发免费
    result.freeResult = checkFreeGame(deskInfo, result.resultCards, GAME_CFG)

    -- 检测是否触发bonus游戏
    local triggerSubGame, bonusIdxs = checkSubGame(deskInfo, GAME_CFG, result.resultCards)

    -- 初始化bonus游戏
    if triggerSubGame then
        initBonusGame(deskInfo, bonusIdxs)
    end

    -- 计算结果
    result.winCoin, result.zjLuXian, result.scatterResult = getBigGameResult(deskInfo, result.resultCards)

    -- 如果是免费游戏，还需要计算wild的倍数
    if isFreeState and #deskInfo.customData.wildInfo > 0 then
        local mult_map = {}
        for _, item in ipairs(deskInfo.customData.wildInfo) do
            if item.mult > 1 then
                mult_map[item.idx] = item.mult
            end
        end
        for _, rs in ipairs(result.zjLuXian) do
            local mult = 1
            for _, idx in ipairs(rs.indexs) do
                if mult_map[idx] then
                    mult = mult * mult_map[idx]
                end
            end
            if mult > 1 then
                -- 先增加总金额
                result.winCoin = result.winCoin + rs.coin * (mult - 1)
                -- 然后再计算线路的金币
                rs.coin = rs.coin * mult
            end
        end
    end

    -- 如果触发了免费，则需要初始化wildInfo
    if not isFreeState and not table.empty(result.freeResult) then
        deskInfo.customData.wildInfo = {}
    end

    -- 生成回复协议
    local retobj = cashBaseTool.genRetobjProto(deskInfo, result)

    retobj.bonusGame = getBonusGame(deskInfo)
    if deskInfo.customData.wildInfo then 
        retobj.wildInfo = table.copy(deskInfo.customData.wildInfo)
    end
    return retobj
end

---------------------------------------------------------------------------------------
--- CMD 43 交互
---------------------------------------------------------------------------------------

local function create(deskInfo, uid)
    if not deskInfo.customData then
        initCustomData(deskInfo)
    end
    if not deskInfo.customData.collectGame then
        initCollectGame(deskInfo)
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
    if deskInfo.customData.collectGame and deskInfo.customData.collectGame.state ~= 0 then
        LOG_ERROR("the collectGame state is not 0")
        return {
            errMsg = "the collectGame state is not 0",
            spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
        }
    end
    local isFreeState = checkIsFreeState(deskInfo)
    -- 自己的服务器，免费不能触发免费，防止无限免费
    if DEBUG and isFreeState then
        deskInfo.control.freeControl.probability = 50
    end
    --免费游戏中不能触发bonus游戏
    if isFreeState then
        deskInfo.control.bonusControl.probability = 0
    end
    -- 如果需要的收集数量少于15，则不能触发bonus游戏, 防止同时触发
    if deskInfo.customData.collectGame.progressData.needCnt - deskInfo.customData.collectGame.progressData.totalCnt < 13 then
        deskInfo.control.bonusControl.probability = 0
    end
    local betCoin = caulBet(deskInfo)

    local retobj = start_696(deskInfo)

    local collectNum = collectProgressBar(deskInfo, retobj.resultCards) --牌里能收集的个数
    local currCnt = addProgressBar(deskInfo, collectNum) -- 增加能量

    retobj.collectGame = table.copy(deskInfo.customData.collectGame)
    retobj.collectGame.progressData.currCnt = currCnt -- 单独加上当轮增加的数量, 方便前端做特效

    if isFreeState and table.empty(retobj.freeResult.freeInfo) and deskInfo.freeGameData.restFreeCount == 1 then
        deskInfo.customData.wildInfo = nil
    end

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
    if rtype == 1 then	-- bonus游戏, spin阶段
        if not deskInfo.customData.bonusGame then
            retobj.errMsg = "The bonusGame is nil"
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        retobj.currResult = spinBonusGame(deskInfo)
        retobj.bonusGame = getBonusGame(deskInfo)
    elseif rtype == 2 then	-- bonus游戏, pick阶段
        if not deskInfo.customData.bonusGame then
            retobj.errMsg = "The bonusGame is nil"
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        if not recvobj.choiceId then
            LOG_ERROR("The choiceId is not exist.")
            retobj.errMsg = "The choiceId is not exist."
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        retobj.choiceId = recvobj.choiceId
        pickBonusItem(deskInfo, retobj.choiceId)
        retobj.bonusGame = getBonusGame(deskInfo)
        if retobj.bonusGame.isEnd then
            --普通中触发免费游戏，金币需要叠加在freeWinCoin上
            if checkIsFreeState(deskInfo) then
                deskInfo.freeGameData.freeWinCoin = deskInfo.freeGameData.freeWinCoin + retobj.bonusGame.winCoin
            else
                cashBaseTool.caulCoin(deskInfo, retobj.bonusGame.winCoin, PDEFINE.ALTERCOINTAG.WIN)
            end
            local result = {
                kind = "bonus",
                desc = "pick bonus item",
            }
            baseRecord.slotsGameLog(deskInfo, 0, retobj.bonusGame.winCoin, result, 0)
            deskInfo.customData.bonusGame = nil
        end
    elseif rtype == 3 then -- 转盘随机收集游戏倍数
        local collectGame = deskInfo.customData.collectGame
        if collectGame.state ~= 1 then
            retobj.errMsg = "The bonusGame state is now: " .. collectGame.state .. "expect 1."
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        local id, value = utils.randByWeight(WheelMultConfig)
        retobj.id = id
        retobj.mult = value.mult
        -- 计算平均值
        -- 将平均下注额暴露出来
        retobj.avgBet = math.floor(collectGame.progressData.totalCoin / collectGame.progressData.totalCnt)
        retobj.coin = value.mult * retobj.avgBet
        retobj.type = value.type
        -- 免费游戏中，奖励不直接加到人身上
        if checkIsFreeState(deskInfo) then
            deskInfo.freeGameData.freeWinCoin = deskInfo.freeGameData.freeWinCoin + retobj.coin
        else
            cashBaseTool.caulCoin(deskInfo, retobj.coin, PDEFINE.ALTERCOINTAG.WIN)
        end
        local result = {
            kind = "bonus",
            desc = "collect game wheel",
        }
        baseRecord.slotsGameLog(deskInfo, 0, retobj.coin, result, 0)
        local item = {coin = retobj.coin, type = value.type} -- 加入已有列表中
        retobj.idx = addCollectItem(deskInfo, item) -- 此次酒杯出现的位置
        retobj.collectGame = table.copy(collectGame)
        -- 重置进度条
        collectGame.progressData = initProgressBar(deskInfo)
    elseif rtype == 4 then -- bonus游戏结算前选择物品类型
        if deskInfo.customData.collectGame.state ~= 2 then
            LOG_ERROR("The collectGame state is now: " .. deskInfo.customData.collectGame.state .. "expect 2.")
            retobj.errMsg = "The collectGame state is now: " .. deskInfo.customData.collectGame.state .. "expect 2."
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        if not recvobj.choiceId then
            LOG_ERROR("without choiceId parameter.")
            retobj.errMsg = "without choiceId parameter."
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        if not table.contain({1, 2, 3}, recvobj.choiceId) then
            LOG_ERROR("illegal choiceId, expect one of {1,2,3}.")
            retobj.errMsg = "illegal choiceId, expect one of {1,2,3}."
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        deskInfo.customData.collectGame.choiceId = recvobj.choiceId
        local result, winCoin = settleCollectGame(deskInfo)
        retobj.choiceId = recvobj.choiceId
        retobj.result = result
        retobj.winCoin = winCoin
        retobj.collectGame = deskInfo.customData.collectGame
        -- 免费游戏中，奖励不直接加到人身上
        if checkIsFreeState(deskInfo) then
            deskInfo.freeGameData.freeWinCoin = deskInfo.freeGameData.freeWinCoin + retobj.winCoin
        else
            cashBaseTool.caulCoin(deskInfo, retobj.winCoin, PDEFINE.ALTERCOINTAG.WIN)
        end
        local results = {
            kind = "bonus",
            desc = "bonus game choice",
        }
        baseRecord.slotsGameLog(deskInfo, 0, retobj.winCoin, results, 0)
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
        simpleDeskData.bonusGame = getBonusGame(deskInfo)
    end
    simpleDeskData.collectGame = deskInfo.customData.collectGame
    simpleDeskData.wildInfo = deskInfo.customData.wildInfo
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
    jp5 = 1,
    jp6 = 2,
    jp7 = 3,
    jp8 = 4,
    jp9 = 5,
    jp10 = 6,
    jp11 = 7,
    jp12 = 8,
    jp13 = 9,
    jp14 = 10,
}


-- bonus游戏
local bonusGame = {
    state = 1,  -- 游戏状态 1=等待开始，2=spin状态，3=选择金币状态
    items = {},  -- 位置上的bonus图标, 位置是从1-30
    spinCnt = 3,  -- 剩余spin的次数
    pickCnt = 3,  -- 剩余的选择次数
    row = 3,  -- 当前行数
    jackpotValues = {},  -- 对应的jackpot值
    winCoin = 0,  -- 最终赢的钱
    jackpot = nil,  -- 最终获得的jackpot
    isEnd = false,  -- 是否结束
}

-- 收集游戏
collectGame = {
    choiceId = nil,  -- 进入最终游戏阶段选择的物品类型
    state = 0, -- 状态， 0=收集状态，1=转盘状态，2=结算前选择类型
    col = 3, -- 多少列
    row = 7, -- 多少行
    collectionItems = {}, -- 已收集到的物品 {coin=1000, type=1}
    collectionIdxs = {}, -- 已收集到物品的位置
    progressData = progressData
}

progressData = {
    needCnt = needCnt, -- 进度条需要的收集数量
    totalCnt = 0, -- 进度条当前收集数量
    totalCoin = 0, -- 进度条收集到的金币数量，用于计算出最终价值
    currCnt = 0,  -- 当前收集数量
    wheelItems = {},  -- 如果出现转盘，则有这个配置
}


-- 44协议额外字段
retobj.bonusGame = bonusGame  -- bonus游戏信息
retobj.bonusInfo = bonusInfo  -- {idx=1, coin=1000, jackpot={id=1}}


-- 51协议
{rtype=1}  -- bonus游戏 spin阶段
res: {
    currResult = {{idx=1, coin=1000,isOpen=false}} -- 当轮的bonus图标
    bonusGame = extraFreeInfo
}

{rtype=2, choiceId=2} bonus游戏, pick阶段
res: {
    choiceId = 2,
    bonusGame = bonusGame
}

{rtype=3}  -- 进度条满之后，转盘的配置在 collectGame.progressData.wheelItems
res: {
    idx = idx, -- 物品出现在格子中的位置
    collectGame = collectGame,  -- 收集游戏信息
    type = 1,  -- 收集到的物品类型，有1，2，3
    coin = 1000， -- 收集到物品的金币
    avgBet = 1000，  -- 平均下注额
    id = 1， -- 对应转盘的id
    mult = 1,  -- 对应随机到的倍率
}

{type=4, choiceId} -- 收集满物品之后，要选择一个类型
res: {
    choiceId = 1,
    result = result,  -- 出现的结果列表{{col=1, row=1, coin=2}, }
    winCoin = 1000,
    collectGame = collectGame,
}

]]