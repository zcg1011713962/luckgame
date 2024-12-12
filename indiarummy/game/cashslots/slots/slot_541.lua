-- Power Of The Kraken
-- 克拉肯之力
-- 541

--[[
    基础规则
    1. 正常游戏4行5列，线路是1024线
    2. 3个scatter触发免费游戏
    3. 卷轴中出现bonus图标，图标上会随机出金币，6个图标触发epic子游戏
    4. 收集 wild 图标可以触发 Lost Treasure Bonus 游戏

    免费规则
    1. 3个statter触发6次免费游戏
    2. 所有mini图标会从免费游戏中移除
    3. 免费中能再次触发免费
    4. 免费中能触发epic

    超级免费
    1. 每8次免费游戏奖励一次超级免费游戏
    2. 超级免费中能触发 超级epic 和 超级pick
    3. 在超级免费中bonus图标会保留在卷轴中知道触发epic
    4. 超级免费中不能触发免费游戏

    epic bonus游戏
    1. 6个bonus图标触发
    2. 初始5次spin机会，每次额外的bonus图标增加一次spin机会
    3. 银色bonus图标带有jackpot和coin标记；金色bonus图标带有OceanPick, Kraken'Power 2x, 5x, 10x标记
    4. 在超级免费游戏中触发的epic游戏升级：加入一个20x的金色bonus图标

      ocean pick bonus游戏: 选取幸运鱼赢取金币，金币会最终加到bonus图标上
      kraken’s power bonus游戏： 立即获得所有银色bonus图标上的奖励

    lost treasure jackpot bonus游戏
    1. 收集wild填充箱子随机触发
    2. 选择13个箱子，当某种箱子数首先到达3个则赢取对应的jackpot
    3. 万能jackpot箱子能代替任意其他类型jackpot箱子
    4. 超级免费中触发jackpot游戏额外多2个万能jackpot图标
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

local DEBUG = os.getenv("HAORAN_DEBUG") -- 是否是调试阶段，调试阶段，很多步数会减少

local GAME_CFG = {
    gameid = 541,
    line = 243,
    winTrace = {},
    mults = config.MULTSCONF[888][1],
    RESULT_CFG = config.CARDCONF[541],
    wilds = {1},
    scatter = 2,
    bonus = {3, 4},
    freeGameConf = {card = 2, min = 3, freeCnt = {[3] = 6, [4] = 6, [5] = 6}, addMult = 1},
    mustWinFreeCoin = true,
    commonCards = {5,6,7,8,9,12},  -- 用于随机替换的牌
    COL_NUM = 5,
    ROW_NUM = 4
}

local JACKPOT = config.JACKPOTCONF[GAME_CFG.gameid]

-- 对应的jackpotId
local JackPot = {
    Wild = 0,  --万能jackpot
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
    [1] = {cnt = 10, weight = 100},
    [2] = {cnt = 11, weight = 400},
    [3] = {cnt = 12, weight = 800},
    [4] = {cnt = 13, weight = 1000},
    --[4] = {cnt = 13, weight = 600},
    [5] = {cnt = 14, weight = 900},
    --[5] = {cnt = 14, weight = 600},
    [6] = {cnt = 15, weight = 700},
    [7] = {cnt = 16, weight = 500},
    [8] = {cnt = 17, weight = 200},
    --[8] = {cnt = 17, weight = 600},
    [9] = {cnt = 18, weight = 100},
    --[9] = {cnt = 18, weight = 400},
    [10] = {cnt = 19, weight = 50},
}

--bonus游戏的item类型
local BonusItemType = {
    Jackpot = 1,    --奖池
    Coin = 2,       --金币
    Multipler = 3,  --倍数
    OceanPick = 4,  --小游戏
    KrakensPower = 5,--小游戏
}

-- 进入bonusGame的前提下，bonus图标上的金币大小以及概率
local BonusItemConfig = {
    [1] = {c=BonusItemType.Jackpot, id=JACKPOT.DEF.MINI, weight=300}, --奖池
    [2] = {c=BonusItemType.Jackpot, id=JACKPOT.DEF.MINOR, weight=120}, --奖池
    [3] = {c=BonusItemType.Jackpot, id=JACKPOT.DEF.MAJOR, weight=50}, --奖池
    [4] = {c=BonusItemType.Jackpot, id=JACKPOT.DEF.GRAND, weight=0}, --奖池
    [5] = {c=BonusItemType.Coin, mult=0.2, weight=3000}, --金币
    [6] = {c=BonusItemType.Coin, mult=0.4, weight=2000}, --金币
    [7] = {c=BonusItemType.Coin, mult=0.6, weight=1500}, --金币
    [8] = {c=BonusItemType.Coin, mult=1, weight=1000}, --金币
    [9] = {c=BonusItemType.Coin, mult=2, weight=600}, --金币
    [10] = {c=BonusItemType.Coin, mult=5, weight=200}, --金币
    [11] = {c=BonusItemType.Multipler, times=2, weight=120}, --翻倍
    [12] = {c=BonusItemType.Multipler, times=5, weight=50}, --翻倍
    [13] = {c=BonusItemType.Multipler, times=10, weight=10}, --翻倍
    [14] = {c=BonusItemType.Multipler, times=20, weight=0}, --翻倍
    [15] = {c=BonusItemType.OceanPick, weight=150}, --小游戏(120)
    [16] = {c=BonusItemType.KrakensPower,  weight=240}, --小游戏(200)
}

-- 正常旋转中bonus未进bonus游戏的概率
-- 这个概率可以稍微高一点
local FailBonusItemConfig = {
    [1] = {c=BonusItemType.Jackpot, id=JACKPOT.DEF.MINI, weight=400}, --奖池
    [2] = {c=BonusItemType.Jackpot, id=JACKPOT.DEF.MINOR, weight=200}, --奖池
    [3] = {c=BonusItemType.Jackpot, id=JACKPOT.DEF.MAJOR, weight=80}, --奖池
    [4] = {c=BonusItemType.Jackpot, id=JACKPOT.DEF.GRAND, weight=10}, --奖池
    [5] = {c=BonusItemType.Coin, mult=0.2, weight=3000}, --金币
    [6] = {c=BonusItemType.Coin, mult=0.4, weight=2000}, --金币
    [7] = {c=BonusItemType.Coin, mult=0.6, weight=1500}, --金币
    [8] = {c=BonusItemType.Coin, mult=1, weight=1000}, --金币
    [9] = {c=BonusItemType.Coin, mult=2, weight=600}, --金币
    [10] = {c=BonusItemType.Coin, mult=5, weight=200}, --金币
    [11] = {c=BonusItemType.Multipler, times=2, weight=150}, --翻倍
    [12] = {c=BonusItemType.Multipler, times=5, weight=100}, --翻倍
    [13] = {c=BonusItemType.Multipler, times=10, weight=50}, --翻倍
    [14] = {c=BonusItemType.Multipler, times=20, weight=0}, --翻倍
    [15] = {c=BonusItemType.OceanPick, weight=200}, --小游戏
    [16] = {c=BonusItemType.KrakensPower,  weight=300}, --小游戏
}

-- pick bonus对应最终组合出现的权重
local JackpotWeightConfig = {
    [1] = {name = "grand", jackpotId = JackPot.Grand, weight = 0},
    [2] = {name = "major", jackpotId = JackPot.Major, weight = 50},
    [3] = {name = "minor", jackpotId = JackPot.Minor, weight = 400},
    [4] = {name = "mini", jackpotId = JackPot.Mini, weight = 400},
}


---------------------------------------------------------------------------------------
--- 公共函数
---------------------------------------------------------------------------------------

-- 获取jackpot的列表
local function getJackpotList(deskInfo, gameId, totalBet)
    if TEST_RTP then
        return {1, 2, 3, 4, 5, 6}
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

-- 获取jackpot的概率
local function getjackpotControlProb(deskInfo)
    return deskInfo.control.jackpotControl and deskInfo.control.jackpotControl.probability/1000 or 0.01
end 

local function initCustomData(deskInfo)
    if deskInfo.customData == nil then
        deskInfo.customData = {}
    end
end

-- 获取当前解锁进度条需要的下注额
local function getNeedBet(deskInfo)
    if DEBUG then
        return 2
    end
    local needBet = deskInfo.needbet or 10
    if needBet == 0 then
        needBet = 10
    end
    return needBet
end

--是否超级免费
local function checkIsSuperFreeState(deskInfo)
    local isFreeState = checkIsFreeState(deskInfo)
    return (isFreeState and deskInfo.customData.superFree.state == 1)
end

-- 重写243线计算
-- 适用于 wild不会出现在第一列
-- scatter 是算个数
-- 其他情况自行改动
local function checkResult(deskInfo, cards)
    local winCoin = 0
    local winResult = {}
    local wild = GAME_CFG.wilds[1]
    local scatter = GAME_CFG.scatter
    local f_card_mult = {} -- 图标对应的倍率
    local f_card_col = {} -- 图标对应的列数
    local f_card_idxs = {} -- 图标对应的位置

    -- 从第一列，找出能中线的图标
    for row = 1, GAME_CFG.ROW_NUM do
        local f_idx = (row - 1) * GAME_CFG.COL_NUM + 1
        local card = cards[f_idx]
        if card ~= scatter then
            -- 累增第一列的数量
            if not f_card_mult[card] then
                f_card_mult[card] = 1
            else
                f_card_mult[card] = f_card_mult[card] + 1
            end
            -- 初始都是一列
            f_card_col[card] = 1
            -- 记录图标的位置
            if not f_card_idxs[card] then
                f_card_idxs[card] = {f_idx}
            else
                table.insert(f_card_idxs[card], f_idx)
            end
        end
    end

    -- 从第二列开始，每个图标找到自己最高的中线倍数和数量
    for card, _ in pairs(f_card_mult) do
        for col = 2, GAME_CFG.COL_NUM do
            local cnt = 0
            for row = 1, GAME_CFG.ROW_NUM do
                local _idx = (row - 1) * GAME_CFG.COL_NUM + col
                if card ~= scatter and (cards[_idx] == card or cards[_idx] == wild) then --scatter 不算中线
                    cnt = cnt + 1
                    table.insert(f_card_idxs[card], _idx)
                end
            end
            -- 如果这一列啥都没，则说明这个图标是不连续的，直接pass
            if cnt == 0 then
                break
            else
                f_card_col[card] = col
                f_card_mult[card] = f_card_mult[card] * cnt
            end
        end
    end
    local scatterCnt = table.count(cards, scatter)
    -- 下面这里，只有在scatter算分的情况下，才进行计算scatter个数
    if scatterCnt >= GAME_CFG.RESULT_CFG[scatter].min then
        local idxs = {}
        for idx, card in ipairs(cards) do
            if card == scatter then
                table.insert(idxs, idx)
            end
        end
        f_card_idxs[scatter] = idxs
        f_card_col[scatter] = math.min(5, scatterCnt)
        f_card_mult[scatter] = 1
    end

    -- 根据结果，算出最终的结果
    for card, col in pairs(f_card_col) do
        local cardCfg = GAME_CFG.RESULT_CFG[card]
        local result = {}
        if col >= cardCfg.min then
            result.mult = f_card_mult[card]
            result.card = card
            result.indexs = f_card_idxs[card]
            table.insert(winResult, result)
            winCoin = winCoin + result.mult * deskInfo.singleBet * GAME_CFG.RESULT_CFG[card]["mult"][col]
        end
    end
    return winCoin, winResult
end

-- 算出结果
local function getBigGameResult(deskInfo, cards, gameConf)

    local winCoin = 0
    local traceResult = {}
    local scatterResult = {}
    winCoin, traceResult = checkResult(deskInfo, cards)

    return winCoin, traceResult, scatterResult
end

---------------------------------------------------------------------------------------
--- 免费游戏
---------------------------------------------------------------------------------------

--- 检测免费
local function checkFreeGame(deskInfo, cards, gameConf)
    local freeCardIdxs = {}
    for idx, card in ipairs(cards) do
        if card == GAME_CFG.scatter then
            table.insert(freeCardIdxs, idx)
        end
    end
    local ret = {}
    if #freeCardIdxs >= gameConf.freeGameConf.min then
        ret.freeCnt = gameConf.freeGameConf.freeCnt[#freeCardIdxs] or table.maxn(gameConf.freeGameConf.freeCnt)
        ret.scatterIdx = freeCardIdxs
        ret.scatter = gameConf.freeGameConf.card
        ret.addMult = gameConf.freeGameConf.addMult or 1
    end
    return ret
end

---------------------------------------------------------------------------------------
--- epic游戏
---------------------------------------------------------------------------------------

-- 检测是否触发小游戏
local function checkSubGame(deskInfo, gameConf, cards)
    local idxs = {}
    for idx, card in ipairs(cards) do
        if card == GAME_CFG.bonus[1] or card == GAME_CFG.bonus[2] then
            table.insert(idxs, idx)
        end
    end
    if #idxs >= 6 then
        return true, idxs
    end
    return false, idxs
end

local function checkSubGameInSuperFree(deskInfo, gameConf, cards)
    local idxs = {}
    local totalidxs = {}
    for idx, card in ipairs(cards) do
        if card == GAME_CFG.bonus[1] or card == GAME_CFG.bonus[2] then
            table.insert(idxs, idx)
            table.insert(totalidxs, idx)
        end
    end
    for _, idx in ipairs(deskInfo.customData.superFree.stickyIdxs) do
        if not table.contain(totalidxs, idx) then
            table.insert(totalidxs, idx)
        end
    end
    if #totalidxs >= 6 then
        return true, idxs
    end
    return false, idxs
end

--创建BonusItem
local function createBonusItem(itemCfg, startPrize)
    local item = {c = itemCfg.c}
    if itemCfg.c == BonusItemType.Jackpot then
        item.id = itemCfg.id
        item.times = 1
    elseif itemCfg.c == BonusItemType.Coin then
        item.coin = math.round_coin(itemCfg.mult * startPrize)
        item.times = 1
    elseif itemCfg.c == BonusItemType.Multipler then
        item.times = itemCfg.times
    end
    return item
end

-- 根据概率生成bonus金币数
local function genBonusCards(deskInfo, bonusIdxs, triggerBonusGame, resultCards, startPrize)
    local isFreeState = checkIsFreeState(deskInfo)
    local isSuperFreeState = checkIsSuperFreeState(deskInfo)
    local itemConfigs = nil
    -- 触发了bonus游戏和没触发，对应bonus图标上的金币概率不同
    if triggerBonusGame or isSuperFreeState then
        itemConfigs = table.copy(BonusItemConfig)
    else
        itemConfigs = table.copy(FailBonusItemConfig)
    end
    if isFreeState then
        local weight = 0
        for _, cfg in pairs(itemConfigs) do
            if cfg.c == BonusItemType.Jackpot and cfg.id == JACKPOT.MINI then
                weight = weight + cfg.weight
                cfg.weight = 0
            end
        end
        for _, cfg in pairs(itemConfigs) do
            if cfg.c == BonusItemType.Jackpot and cfg.id == JACKPOT.MINOR then
                cfg.weight = cfg.weight + weight
                break
            end
        end
    end

    local bonusItems = {}
    for _, idx in ipairs(bonusIdxs) do
        local _, rs = utils.randByWeight(itemConfigs)
        local bonusItem = createBonusItem(rs, startPrize)
        table.insert(bonusItems, bonusItem)
        if bonusItem.c < 3 then
            resultCards[idx] = GAME_CFG.bonus[1]
        else
            resultCards[idx] = GAME_CFG.bonus[2]
            --金色珠子一次只出一个
            for _, cfg in pairs(itemConfigs) do
                if cfg.c >= 3 then
                    cfg.weight = 0
                end
            end
        end
    end
    return bonusItems
end


-- 初始化bonusGame
local function initBonusGame(deskInfo, startPrize)
    local bonusGame = {
        state = 0,  -- 0:正常spin, 1:OceanPick小游戏
        slots = {},  -- 卷轴对应的数据
        startPrize = startPrize,  -- 基础下注额
        spinCnt = 5,  -- 剩余spin的次数, 在后面根据bonus数量进行初始化
        totalSpinCnt = 5,  -- 总共spin的次数, 在后面根据bonus数量进行初始化
        jackpotValues = {},  -- 对应的jackpot值
        isEnd = false,  -- 是否结束
        winCoin = 0,  -- 最终赢的钱

        finalResult = {  -- 最终结果，提前算出，但是对前端隐藏
            results = {},  -- 每次中的内容{idxs, items}, spin之后，从前端取出结果
        }
    }
    for _, jp in ipairs({JACKPOT.DEF.MINI, JACKPOT.DEF.MINOR, JACKPOT.DEF.MAJOR, JACKPOT.DEF.GRAND}) do
        local jackpotValue = getJackpotValue(GAME_CFG.gameid, jp, bonusGame.startPrize)
        bonusGame.jackpotValues[jp] = jackpotValue
    end
    deskInfo.customData.bonusGame = bonusGame
end

--所有coin和jackpot的数值翻倍
local function processMultiplerItem(bonusGame, item)
    for _, it in ipairs(bonusGame.slots.bonusItems) do
        if it.c == BonusItemType.Coin or it.c == BonusItemType.JackPot then
            it.times = math.max(it.times, item.times)
        end
    end
end

--捕鱼小游戏
local function processOceanPickItem(bonusGame, item)
    item.coins = {}
    local rand = math.random(5, 7)
    for i = 1, rand do
        table.insert(item.coins, math.round_coin(bonusGame.startPrize*math.random(2, 6)/10))
    end
    table.insert(item.coins, math.round_coin(bonusGame.startPrize*math.random(5,10)))
    item.coin = table.sum(item.coins)
end

--立即获得所有coin和jackpot
local function processKrakenPowerItem(bonusGame, item)
    local totalCoin = 0
    for _, it in ipairs(bonusGame.slots.bonusItems) do
        if it.c == BonusItemType.Coin or it.c == BonusItemType.Jackpot then
            totalCoin = totalCoin + it.coin * it.times
        end
    end
    bonusGame.winCoin = bonusGame.winCoin + totalCoin
end

-- 初始化bonus游戏中的卷轴
local function initBonusGameSlots(deskInfo, bonusGame, bonusIdxs, bonusItems)
    local slot = {
        bonusIdxs = table.copy(bonusIdxs),
        bonusItems = table.copy(bonusItems),
    }
    if checkIsSuperFreeState(deskInfo) then
        local stickyIdxs = deskInfo.customData.superFree.stickyIdxs
        local stickyItems = deskInfo.customData.superFree.stickyItems
        for i, idx in ipairs(stickyIdxs) do
            if not table.contain(slot.bonusIdxs, idx) then
                table.insert(slot.bonusIdxs, idx)
                table.insert(slot.bonusItems, table.copy(stickyItems[i]))
            end
        end
    end
    bonusGame.slots = slot

    --奖池数值
    for _, item in ipairs(slot.bonusItems) do
        if item.c == BonusItemType.Jackpot then
            item.coin = bonusGame.jackpotValues[item.id]
        end
    end
    --倍数图标处理
    for _, item in ipairs(slot.bonusItems) do
        if item.c == BonusItemType.Multipler then
            processMultiplerItem(bonusGame, item)
        end
    end
    --OnceanPick处理
    for _, item in ipairs(slot.bonusItems) do
        if item.c == BonusItemType.OceanPick then
            processOceanPickItem(bonusGame, item)
        end
    end
    --KrakenPower处理
    for _, item in ipairs(slot.bonusItems) do
        if item.c == BonusItemType.KrakensPower then
            processKrakenPowerItem(bonusGame, item)
        end
    end

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
        if cfg.c == BonusItemType.Jackpot and not table.contain(jackpotList, cfg.id) then
            cfg.weight = 0
        end
    end
    -- 提前生成slot的结果
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
    local finalCnt = rs.cnt - #bonusIdxs
    local totalSpinCnt = finalCnt + 5
    local results = {}
    -- 计算差值, 然后将差值的数量分配到可spin的次数内
    if finalCnt > 0 then
        local finalResult = utils.breakUpResult(finalCnt, totalSpinCnt)
        for _, cnt in ipairs(finalResult) do
            local result = {idxs={}, items={}}
            if cnt > 0 then
                for _ = 1, cnt do
                    local _, itemRs = utils.randByWeight(bonusItemConfigs)
                    local idx = table.remove(unUsedIdxs)
                    local item = createBonusItem(itemRs, bonusGame.startPrize)
                    if item.c == BonusItemType.Jackpot then
                        item.coin = bonusGame.jackpotValues[item.id]
                    end
                    table.insert(result.items, item)
                    table.insert(result.idxs, idx)
                end
            end
            table.insert(results, result)
            -- 如果已经满了，则不需要继续了
            if #result.idxs >= GAME_CFG.COL_NUM * GAME_CFG.ROW_NUM then
                break
            end
        end
    else
        -- 一个都每中，那么每次都是空
        for _ = 1, totalSpinCnt do
            table.insert(results, {idxs={}, items={}})
        end
    end

    bonusGame.finalResult.results = results
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


-- bonus游戏转动一次
local function spinBonusGame(deskInfo)
    --LOG_INFO("yrp spinBonusGame")
    local bonusGame = deskInfo.customData.bonusGame
    if bonusGame.state ~= 0 then
        return nil
    end
    bonusGame.spinCnt = bonusGame.spinCnt - 1
    local allFull = true
    local slots = bonusGame.slots

    -- 从预先的结果中弹出一个结果
    local result = table.remove(bonusGame.finalResult.results, 1)
    -- 将结果加入卷轴中，并发送给前端
    if not result then
        result = {idxs={}, items={}}
    end

    for index, idx in ipairs(result.idxs) do
        if not table.contain(slots.bonusIdxs, idx) then
            table.insert(slots.bonusIdxs, idx)
            table.insert(slots.bonusItems, result.items[index])
            bonusGame.spinCnt = bonusGame.spinCnt + 1
            bonusGame.totalSpinCnt = bonusGame.totalSpinCnt + 1
        end
    end
    --倍数图标处理
    for _, item in ipairs(result.items) do
        if item.c == BonusItemType.Multipler then
            processMultiplerItem(bonusGame, item)
        end
    end
    --OnceanPick处理
    for _, item in ipairs(result.items) do
        if item.c == BonusItemType.OceanPick then
            processOceanPickItem(bonusGame, item)
        end
    end
    --KrakenPower处理
    for _, item in ipairs(result.items) do
        if item.c == BonusItemType.KrakensPower then
            processKrakenPowerItem(bonusGame, item)
        end
    end
    if #slots.bonusIdxs < GAME_CFG.COL_NUM * GAME_CFG.ROW_NUM then
        allFull = false
    end

    -- 如果剩余次数小于0
    if bonusGame.spinCnt <= 0 or allFull then
        -- 如果还没有转完，说明还有额外次数
        if #bonusGame.finalResult.results > 0 then
            --sprint(#bonusGame.finalResult.results, allFull)
        end
        bonusGame.isEnd = true
        -- 结算
        for _, item in ipairs(slots.bonusItems) do
            if item.c == BonusItemType.Jackpot or item.c == BonusItemType.Coin then
                bonusGame.winCoin = bonusGame.winCoin + item.coin * item.times
            end
        end
    end
    return result
end

--epic游戏spin之后的处理
local function postSpinBonusGame(deskInfo)
    local bonusGame = deskInfo.customData.bonusGame
    if not bonusGame or bonusGame.state ~= 0 then
        return nil
    end
    local slots = bonusGame.slots
    --倍数图标和KrakenPower图标消失
    --OnceanPick图标变成金币图标
    for i = #slots.bonusItems, 1, -1 do
        local item = slots.bonusItems[i]
        if item.c == BonusItemType.Multipler or item.c == BonusItemType.KrakensPower then
            table.remove(slots.bonusItems, i)
            table.remove(slots.bonusIdxs, i)
        elseif item.c == BonusItemType.OceanPick then
            item.c = BonusItemType.Coin
            item.times = 1
            item.coins = nil
        end
    end
end


---------------------------------------------------------------------------------------
--- jackpot选宝箱游戏
---------------------------------------------------------------------------------------

-- 收集的宝箱信息
local function initBoxInfo(deskInfo)
    local boxInfo = {
        status = 1, -- 一共3个状态
        cnt = 0,  -- 总共收集的数量
        wildIdxs = {},  -- 本轮收集的位置
    }
    deskInfo.customData.boxInfo = boxInfo
end

-- 收集wild数量
local function collectWild(deskInfo, cards)
    local boxInfo = deskInfo.customData.boxInfo
    boxInfo.wildIdxs = {}
    for idx, card in ipairs(cards) do
        if card == GAME_CFG.wilds[1] then
            table.insert(boxInfo.wildIdxs, idx)
            boxInfo.cnt = boxInfo.cnt + 1
        end
    end
    -- 刷新树的状态
    boxInfo.status = math.ceil(boxInfo.cnt / 15)
    if boxInfo.status == 0 then
        boxInfo.status = 1
    end
    if boxInfo.status > 3 then
        boxInfo.status = 3
    end
    return boxInfo
end

-- 检测是否触发选宝箱游戏
-- 检测机制是，有wild图标，然后按照概率随机
local function checkJackpotGame(deskInfo, cards)
    if math.random() < getjackpotControlProb(deskInfo) then
        if not table.contain(cards, GAME_CFG.wilds[1]) then
           cards[math.random(#cards)] = GAME_CFG.wilds[1]
        end
        return true
    end
    return false
end

-- 随机出一个箱子列表
local function initJackpotGame(deskInfo)
    local jackpotGame = {
        items = {}, -- 选择出的物品
        jackpots = {},  -- 最终中到的jackpot
        winCoin = 0, -- 最终奖励
        jackpotValues = {},  -- jackpot对应的值
        isEnd = false,  -- 是否结束

        _results = {},  -- 提前算出的物品
    }

    local isSuperFreeState = checkIsSuperFreeState(deskInfo)
    local totalCnt = 13
    local wildCnt = 1
    if isSuperFreeState then
        totalCnt = 15
        wildCnt = 3
    end
    for i = 1, totalCnt do
        table.insert(jackpotGame.items, {
            isOpen = false,
            jackpotId = nil,
        })
    end

    -- 根据概率随机出结果
    local _, rs = utils.randByWeight(JackpotWeightConfig)

    -- 获取jackpot数额
    for _, jp in ipairs({JackPot.Mini, JackPot.Minor, JackPot.Major, JackPot.Grand}) do
        local jackpotValue = getJackpotValue(GAME_CFG.gameid, jp, deskInfo.totalBet)
        jackpotGame.jackpotValues[jp] = jackpotValue

        -- 生成结果，目标jackpot有三个碎片，其他只有两个碎片
        table.insert(jackpotGame._results, jp)
        table.insert(jackpotGame._results, jp)
        if jp == rs.jackpotId then
            table.insert(jackpotGame._results, jp)
        end
    end
    -- 打乱结果
    table.shuffle(jackpotGame._results)
    --确定要不要提前加入wild
    if math.random() < 0.75 then
        local tmpResults = table.copy(jackpotGame._results)
        local rand = math.random(1, #tmpResults)
        table.insert(tmpResults, rand, JackPot.Wild)
        local counts = {0, 0, 0, 0}
        for _, jp in ipairs(tmpResults) do
            if jp == JackPot.Wild then
                for i = 1, #counts do counts[i] = counts[i] + 1 end
            else
                counts[jp] = counts[jp] + 1
            end
            local isEnd = false
            for i = 1, #counts do
                if counts[i] == 3 then
                    isEnd = true
                end
            end
            if isEnd then --加入wild不能触发grand
                if counts[JackPot.Grand] >= 3 then
                    rand = 0
                end
                break
            end
        end
        if rand > 0 then
            table.insert(jackpotGame._results, rand, JackPot.Wild)
            wildCnt = wildCnt - 1
        end
    end

    -- 放入剩下的3个jackpot
    local wholeJackpot = {JackPot.Mini, JackPot.Minor, JackPot.Major, JackPot.Grand}

    for _ = 1, wildCnt do
        table.insert(wholeJackpot, JackPot.Wild)
    end
    wholeJackpot = table.shuffle(wholeJackpot)
    for _, jp in ipairs(wholeJackpot) do
        if jp ~= rs.jackpotId then
            table.insert(jackpotGame._results, jp)
        end
    end

    deskInfo.customData.jackpotGame = jackpotGame
end

-- 选择一个宝箱
local function chooseBox(deskInfo, choiceId)
    local jackpotGame = deskInfo.customData.jackpotGame
    -- 判断是否已经选过了
    local item = jackpotGame.items[choiceId]
    if item.isOpen then
        return nil
    end
    item.isOpen = true
    -- 弹出一个结果出来
    item.jackpotId = table.remove(jackpotGame._results, 1)

    -- 判断结果是否全部选择完
    local winJackpots = {}
    local counts = {0, 0, 0, 0}
    for _, it in ipairs(jackpotGame.items) do
        if it.isOpen == true then
            if it.jackpotId == JackPot.Wild then
                for i = 1, #counts do
                    counts[i] = counts[i] + 1
                end
            else
                counts[it.jackpotId] = counts[it.jackpotId] + 1
            end

            for jp = 1, 4 do
                if counts[jp] == 3 and not table.contain(winJackpots, jp) then
                    table.insert(winJackpots, jp)
                end
            end
        end
    end
    if #winJackpots > 0 then
        jackpotGame.isEnd = true
        for _, jp in ipairs(winJackpots) do
            local coin = jackpotGame.jackpotValues[jp]
            table.insert(jackpotGame.jackpots, {id=jp, coin=coin})
            jackpotGame.winCoin = jackpotGame.winCoin + coin
        end
        --剩余的箱子赋值
        for _, it in ipairs(jackpotGame.items) do
            if it.isOpen ~= true then
                it.jackpotId = table.remove(jackpotGame._results, 1)
            end
        end
    end
end

-- 重连获取数据, 屏蔽最终结果
local function getJackpotGame(deskInfo)
    if not deskInfo.customData.jackpotGame then
        return nil
    end
    local jackpotGame = table.copy(deskInfo.customData.jackpotGame)
    jackpotGame._results = nil
    return jackpotGame
end


---------------------------------------------------------------------------------------
--- 免费收集游戏 每次触发免费都会增加一次记录
---------------------------------------------------------------------------------------

-- 初始化bonus trail 结构
local function initSuperFree(deskInfo)
    --- @class SuperFree541
    local superFree = {
        state = 0,  -- 状态 0: 收集状态, 1: super free游戏状态
        count = 0,  -- 记录的免费游戏次数
        totalCount = 8,  -- 总共的次数，集满之后从0开始
        startPrize = 0,  -- 记录触发的平均下注额, 防止下注额变动
        stickyIdxs = {},
        stickyItems = {},
    }
    deskInfo.customData.superFree = superFree
end

-- 触发免费游戏时，会增加一次记录
local function addSuperFree(deskInfo)
    --- @type SuperFree541
    local superFree = deskInfo.customData.superFree
    -- 记录当前的数量和下注额，方便计算
    local currTotalBet = deskInfo.totalBet
    local currCount = superFree.count
    -- 增加次数
    superFree.count = superFree.count + 1
    -- 算出新的平均值
    superFree.startPrize = math.floor((superFree.startPrize * currCount + currTotalBet) / superFree.count)
    if superFree.count >= superFree.totalCount then
        superFree.state = 1
    end
end

-- 每局普通游戏开始时会刷新
local function refreshSuperFree(deskInfo)
    local superFree = deskInfo.customData.superFree
    -- 如果次数到达最大值，则会从0开始
    if superFree.count >= superFree.totalCount then
        superFree.count = 0
        superFree.state = 0
        superFree.startPrize = 0
        superFree.stickyIdxs = {}
        superFree.stickyItems = {}
    end
end


---------------------------------------------------------------------------------------
--- 正常slot逻辑
---------------------------------------------------------------------------------------

-- 发牌逻辑
local function initResultCards(deskInfo)
    local isSuperState = checkIsSuperFreeState(deskInfo)
    local cards
    if isSuperState then
        local cardmap = cardProcessor.getCardMap(deskInfo, "superfreemap")
        cards = cardProcessor.get_cards_1(cardmap, GAME_CFG.COL_NUM, GAME_CFG.ROW_NUM)
    else
        local funcList = {
            checkFreeGame = checkFreeGame,
            checkSubGame = checkSubGame,
            getBigGameResult = getBigGameResult
        }
        cards = cardProcessor.get_cards_3(deskInfo, GAME_CFG, funcList)
    end

    local design = cashBaseTool.addDesignatedCards(deskInfo)
    if design ~= nil then
        cards = table.copy(design)
    end
    return cards
end

local function getLine()
    return GAME_CFG.line
end

local function getInitMult()
    return GAME_CFG.defaultInitMult
end


local function start_541(deskInfo)
    local result = {}
    result.resultCards = initResultCards(deskInfo) --发牌
    local isFreeState = checkIsFreeState(deskInfo)
    local isSuperFreeState = checkIsSuperFreeState(deskInfo)

    -- 检测是否触发免费
    result.freeResult = checkFreeGame(deskInfo, result.resultCards, GAME_CFG)
    if not isFreeState and not table.empty(result.freeResult) then
        if deskInfo.currmult >= getNeedBet(deskInfo) then
            addSuperFree(deskInfo)
        end
    end

    if isSuperFreeState then
        --超级免费中，已经有bonus的位置不再继续刷出bonus
        for _, idx in ipairs(deskInfo.customData.superFree.stickyIdxs) do
            if result.resultCards[idx] == GAME_CFG.bonus[1] or result.resultCards[idx] == GAME_CFG.bonus[2] then
                result.resultCards[idx] = GAME_CFG.commonCards[math.random(#GAME_CFG.commonCards)]
            end
        end
    end

    --是否触发bonus游戏
    local triggerSubGame, bonusIdxs = checkSubGame(deskInfo, GAME_CFG, result.resultCards)
    if isSuperFreeState then
       triggerSubGame, bonusIdxs = checkSubGameInSuperFree(deskInfo, GAME_CFG, result.resultCards)
    end

    --生成bonus金币数
    local bonusItems
    local startPrize = deskInfo.totalBet
    if isSuperFreeState then startPrize = deskInfo.customData.superFree.startPrize end
    bonusItems = genBonusCards(deskInfo, bonusIdxs, triggerSubGame, result.resultCards, startPrize)
    if triggerSubGame then
        initBonusGame(deskInfo, startPrize)
        initBonusGameSlots(deskInfo, deskInfo.customData.bonusGame, bonusIdxs, bonusItems)
    end

    -- 如果不是触发免费这局，或者最后一局免费，则需要检查是否触发小游戏
    local triggerJackpotGame = false
    if (not isFreeState and table.empty(result.freeResult)) or (isFreeState and deskInfo.freeGameData.restFreeCount > 1) or (not triggerSubGame) then
        triggerJackpotGame = checkJackpotGame(deskInfo, result.resultCards)
        if triggerJackpotGame then
            initJackpotGame(deskInfo)
        end
    end

    result.winCoin, result.zjLuXian = getBigGameResult(deskInfo, result.resultCards, GAME_CFG)  --普通游戏
    if isSuperFreeState then
        -- 这里需要使用平均下注额
        local ratio = startPrize / deskInfo.totalBet
        result.winCoin = math.round_coin(result.winCoin * ratio)
    end

    -- 打包协议
    local retobj = cashBaseTool.genRetobjProto(deskInfo, result)
    retobj.bonusGame = getBonusGame(deskInfo)
    retobj.bonusIdxs = bonusIdxs
    retobj.bonusItems = bonusItems
    retobj.superFree = deskInfo.customData.superFree
    retobj.boxInfo = collectWild(deskInfo, result.resultCards)
    retobj.jackpotGame = getJackpotGame(deskInfo)
    -- 中jackpot只有，箱子就满上
    if triggerJackpotGame then
        retobj.boxInfo.status = 3
        deskInfo.customData.boxInfo.cnt = 0
    end

    if deskInfo.customData.bonusGame then
        postSpinBonusGame(deskInfo)
    end

    if isSuperFreeState then
        --超级免费的bonus图标会保留
        local superFree = deskInfo.customData.superFree
        for i, idx in ipairs(bonusIdxs) do
            if not table.contain(superFree.stickyIdxs, idx) then
                table.insert(superFree.stickyIdxs, idx)
                table.insert(superFree.stickyItems, bonusItems[i])
            end
        end
        retobj.stickyIdxs = table.copy(superFree.stickyIdxs)
        retobj.stickyItems = table.copy(superFree.stickyItems)
        --触发epic游戏后，清空悬挂的bonus图标
        if triggerSubGame then
            superFree.stickyIdxs = {}
            superFree.stickyItems = {}
        end
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
    if not deskInfo.customData.superFree then
        initSuperFree(deskInfo)
    end
    if deskInfo.customData.boxInfo == nil then
        initBoxInfo(deskInfo)
    end
end

---------------------------------------------------------------------------------------
--- CMD 44 交互
---------------------------------------------------------------------------------------

local function start(deskInfo) --正常游戏
    local isSuperState = checkIsSuperFreeState(deskInfo)
    -- 超级免费不能中免费
    if isSuperState then
        deskInfo.control.freeControl.probability = 0
    end

    if deskInfo.customData.bonusGame then
        LOG_ERROR("the bonusGame is not nil")
        return {
            errMsg = "the bonusGame is not nil",
            spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
        }
    end
    if deskInfo.customData.jackpotGame then
        LOG_ERROR("the jackpotGame is not nil")
        return {
            errMsg = "the jackpotGame is not nil",
            spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
        }
    end

    local betCoin = caulBet(deskInfo)  --得到下注金币
    local retobj = start_541(deskInfo)

    -- 超级免费最后一把刷新进度条
    if isSuperState and deskInfo.freeGameData.restFreeCount == 1 then
        refreshSuperFree(deskInfo)
    end

    cashBaseTool.settle(deskInfo, betCoin, retobj)
    return retobj
end

local function resetDeskInfo(deskInfo)
    gameData.set(deskInfo)
end

---------------------------------------------------------------------------------------
--- CMD 51 交互 用于bonus游戏交互
---------------------------------------------------------------------------------------

local function gameLogicCmd(deskInfo, recvobj)
	local retobj = {}
    local rtype = math.floor(recvobj.rtype)
    if rtype == 1 then --bonus 旋转一次
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
        local result = spinBonusGame(deskInfo)
        retobj.result = table.copy(result) --给客户端返回修改前的item
        retobj.bonusGame = getBonusGame(deskInfo)

        -- 如果游戏结束，则清空bonusGame
        if retobj.bonusGame.isEnd then
            if checkIsFreeState(deskInfo) then
                deskInfo.freeGameData.freeWinCoin = deskInfo.freeGameData.freeWinCoin + retobj.bonusGame.winCoin
            else
                cashBaseTool.caulCoin(deskInfo, retobj.bonusGame.winCoin, PDEFINE.ALTERCOINTAG.WIN)
            end
            local results = {
                kind = "bonus",
                desc = "epic game",
            }
            baseRecord.slotsGameLog(deskInfo, 0, retobj.bonusGame.winCoin, results, 0)
            deskInfo.customData.bonusGame = nil
        else
            postSpinBonusGame(deskInfo)
        end
    elseif rtype == 3 then  -- 宝箱游戏中选择宝箱
        if deskInfo.customData.jackpotGame == nil then
            LOG_ERROR("The jackpotGame is not exist.")
            retobj.errMsg = "The jackpotGame is not exist."
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        if not recvobj.choiceId then
            LOG_ERROR("without choiceId parameter.")
            retobj.errMsg = "without choiceId parameter."
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        -- 选择宝箱
        chooseBox(deskInfo, recvobj.choiceId)
        retobj.choiceId = recvobj.choiceId
        retobj.jackpotGame = getJackpotGame(deskInfo)
        -- 如果已经选完，则清除jackpotGame数据
        if retobj.jackpotGame.isEnd then
            -- 免费游戏中，奖励不直接加到人身上
            if checkIsFreeState(deskInfo) then
                deskInfo.freeGameData.freeWinCoin = deskInfo.freeGameData.freeWinCoin + retobj.jackpotGame.winCoin
            else
                cashBaseTool.caulCoin(deskInfo, retobj.jackpotGame.winCoin, PDEFINE.ALTERCOINTAG.WIN)
            end
            local results = {
                kind = "bonus",
                desc = "jackpot game",
            }
            baseRecord.slotsGameLog(deskInfo, 0, retobj.jackpotGame.winCoin, results, 0)
            deskInfo.customData.jackpotGame = nil
            deskInfo.customData.boxInfo.status = 1
        end
    end
	retobj.rtype = rtype
	gameData.set(deskInfo)
	return retobj
end

---------------------------------------------------------------------------------------
--- CMD 43 额外增加的字段
---------------------------------------`------------------------------------------------

local function addSpecicalDeskInfo(deskInfo, simpleDeskData)
    simpleDeskData.needBet = getNeedBet(deskInfo)
    simpleDeskData.bonusGame = getBonusGame(deskInfo)
    simpleDeskData.jackpotGame = getJackpotGame(deskInfo)
    simpleDeskData.boxInfo = deskInfo.customData.boxInfo
    simpleDeskData.superFree = deskInfo.customData.superFree

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
