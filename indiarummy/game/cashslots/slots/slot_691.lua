-- Double Thunder
-- 双倍神力
-- 691

--[[
    基础规则
    1. 正常游戏3行5列，线路是243线
    2. 3个scatter触发免费游戏
    3. 卷轴中出现bonus图标，图标上会随机出金币，6个图标触发子游戏

    免费规则


    bonus游戏


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

local DEBUG = os.getenv("DEBUG") -- 是否是调试阶段，调试阶段，很多步数会减少

local GAME_CFG = {
    gameid = 691,
    line = 243,
    winTrace = {},
    mults = config.MULTSCONF[888][1],
    RESULT_CFG = config.CARDCONF[691],
    wilds = {1},
    scatter = 2,
    bonus = 3,
    freeGameConf = {card = 2, min = 3, freeCnt = {[3] = 8, [4] = 8, [5] = 8}, addMult = 1},
    NormalCards = {7,8,9,10,11,12,13},
    COL_NUM = 5,
    ROW_NUM = 3
}

local JACKPOT = config.JACKPOTCONF[GAME_CFG.gameid]
---------------------------------------------------------------------------------------
--- 参数配置
---------------------------------------------------------------------------------------

-- bonus游戏中最终获得的bonus图标数量权重
local BonusCountConfig = {
    [1] = {cnt = 8, weight = 50},
    [2] = {cnt = 9, weight = 200},
    [3] = {cnt = 10, weight = 400},
    [4] = {cnt = 11, weight = 600},
    [5] = {cnt = 12, weight = 1000},
    [6] = {cnt = 13, weight = 500},
    [7] = {cnt = 14, weight = 400},
    [8] = {cnt = 15, weight = 300},
}

-- 进入bonusGame的前提下，bonus图标上的金币大小以及概率
local BonusItemConfig = {
    [1] = {mult=nil, jackpotId=JACKPOT.DEF.MINI, weight=150},
    [2] = {mult=nil, jackpotId=JACKPOT.DEF.MINOR, weight=40},
    [3] = {mult=nil, jackpotId=JACKPOT.DEF.MAJOR, weight=5},
    [4] = {mult=nil, jackpotId=JACKPOT.DEF.GRAND, weight=1},
    [5] = {mult=0.25, jackpotId=nil, weight=2500},
    [6] = {mult=0.5, jackpotId=nil, weight=2000},
    [7] = {mult=1, jackpotId=nil, weight=1500},
    [8] = {mult=2, jackpotId=nil, weight=400},
    [9] = {mult=3, jackpotId=nil, weight=150},
    [10] = {mult=5, jackpotId=nil, weight=50},
    [11] = {mult=10, jackpotId=nil, weight=20},
    [12] = {baseCoin=true, weight=100},  -- 获得初始时所有bonus的总和, 红钻只有在bonus游戏中才有
}

-- 正常旋转中bonus未进bonus游戏的概率
-- 这个概率可以稍微高一点
local FailBonusItemConfig = {
    [1] = {mult=nil, jackpotId=JACKPOT.DEF.MINI, weight=200},
    [2] = {mult=nil, jackpotId=JACKPOT.DEF.MINOR, weight=50},
    [3] = {mult=nil, jackpotId=JACKPOT.DEF.MAJOR, weight=10},
    [4] = {mult=nil, jackpotId=JACKPOT.DEF.GRAND, weight=2},
    [5] = {mult=0.25, jackpotId=nil, weight=1000},
    [6] = {mult=0.5, jackpotId=nil, weight=1000},
    [7] = {mult=1, jackpotId=nil, weight=1000},
    [8] = {mult=2, jackpotId=nil, weight=600},
    [9] = {mult=3, jackpotId=nil, weight=300},
    [10] = {mult=5, jackpotId=nil, weight=200},
    [11] = {mult=10, jackpotId=nil, weight=50},
}

-- 地图游戏的配置
-- id 代表第几关
-- type 代表类型 1：小关卡 2:大关卡
-- needCnt 代表该步骤需要收集的图标数量
local MapConfig = {
    [1] = {id=1, type = 1, needCnt=160},
    [2] = {id=2, type = 1, needCnt=180},
    [3] = {id=3, type = 2, needCnt=240, freeCnt=8, slots = 2},
    [4] = {id=4, type= 1, needCnt=200},
    [5] = {id=5, type= 1, needCnt=200},
    [6] = {id=6, type= 1, needCnt=200},
    [7] = {id=7, type = 2, needCnt=280, freeCnt=8, slots = 3},
    [8] = {id=8, type = 1, needCnt=200},
    [9] = {id=9, type = 1, needCnt=200},
    [10] = {id=10, type = 1, needCnt=200},
    [11] = {id=11, type = 1, needCnt=200},
    [12] = {id=12, type = 2, needCnt=320, freeCnt=8, slots = 6},
    [13] = {id=13, type = 1, needCnt=200},
    [14] = {id=14, type = 1, needCnt=200},
    [15] = {id=15, type = 1, needCnt=200},
    [16] = {id=16, type = 1, needCnt=240},
    [17] = {id=17, type = 1, needCnt=280},
    [18] = {id=18, type = 2, needCnt=450, freeCnt=8, slots = 8}
}

local MapWheelConfig = {
    [1] = {mult = nil, winAll = true, weight = 0},
    [2] = {mult = 1, weight = 100},
    [3] = {mult = 2, weight = 500},
    [4] = {mult = 2.5, weight = 600},
    [5] = {mult = 3, weight = 1000},
    [6] = {mult = 5, weight = 1500},
    [7] = {mult = 8, weight = 500},
    [8] = {mult = 10, weight = 250},
}



---------------------------------------------------------------------------------------
--- 公共函数
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
    local needBet = deskInfo.needbet or 5
    if needBet == 0 then
        needBet = 10
    end
    return needBet
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
    winCoin = math.round_coin(winCoin)
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

-- 获取当前免费游戏信息
local function getFreeGameInfo(deskInfo)
    if not deskInfo.customData.freeGameInfo then
        return nil
    end
    local freeGameInfo = table.copy(deskInfo.customData.freeGameInfo)
    freeGameInfo.isLast = nil
    if freeGameInfo.config then
        freeGameInfo.weights = nil
    end
    return freeGameInfo
end

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
--- 小游戏
---------------------------------------------------------------------------------------

-- 检测是否触发小游戏
local function checkSubGame(deskInfo, gameConf, cards)
    local idxs = {}
    for idx, card in ipairs(cards) do
        if card == GAME_CFG.bonus then
            table.insert(idxs, idx)
        end
    end
    if #idxs >= 6 then
        return true, idxs
    end
    return false, idxs
end


-- 根据概率生成bonus金币数
local function genBonusCards(deskInfo, bonusIdxs, triggerBonusGame)
    local randNum = math.random()
    local itemConfigs = nil
    local baseCoin = 0
    -- 触发了bonus游戏和没触发，对应bonus图标上的金币概率不同
    if triggerBonusGame then
        itemConfigs = table.copy(BonusItemConfig)
        local jackpotList = getJackpotList(deskInfo, GAME_CFG.gameid, deskInfo.totalBet)
        for _, cfg in pairs(itemConfigs) do
            if cfg.jackpotId and not table.contain(jackpotList, cfg.jackpotId) then
                cfg.weight = 0
            end
            -- 红钻只有在bonus游戏中才有
            if cfg.baseCoin then
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
            table.insert(bonusItems, {jackpot={id=rs.jackpotId}})
        else
            table.insert(bonusItems, {coin=math.round_coin(deskInfo.totalBet*rs.mult)})
            baseCoin = baseCoin + math.round_coin(deskInfo.totalBet*rs.mult)
        end
    end
    return bonusItems, baseCoin
end


-- 初始化bonusGame
local function initBonusGame(deskInfo, baseCoin)
    local bonusGame = {
        state = 0,  -- 0: 正常bonus游戏, 1: spin完之后，选择额外spin次数
        slots = {},  -- 两个卷轴对应的数据
        startPrize = deskInfo.totalBet,  -- 基础下注额
        baseCoin = baseCoin,  -- 初始化时所有bonus上的金币之和
        spinCnt = 0,  -- 剩余spin的次数, 在后面根据bonus数量进行初始化
        totalSpinCnt = 0,  -- 总共spin的次数, 在后面根据bonus数量进行初始化
        jackpotValues = {},  -- 对应的jackpot值
        isEnd = false,  -- 是否结束
        winCoin = 0,  -- 最终赢的钱

        finalResult = {  -- 最终结果，提前算出，但是对前端隐藏
            extraSpins = {1,2,3}, -- 额外的次数选项
            extraSpinId = nil,  -- 额外中的选项索引
            results = {},  -- 每次中的内容{idxs, items}, spin之后，从前端取出结果
        }
    }
    for _, jp in ipairs({JACKPOT.DEF.MINI, JACKPOT.DEF.MINOR, JACKPOT.DEF.MAJOR, JACKPOT.DEF.GRAND}) do
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
    -- 提前生成两个slot的结果
    for i = 1, 2 do
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
        local finalCnt = rs.cnt - #bonusIdxs
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
                            table.insert(result.items, {jackpot={id=itemRs.jackpotId, value=jackpotValue}})
                        elseif itemRs.mult then
                            table.insert(result.items, {coin=math.round_coin(bonusGame.startPrize * itemRs.mult)})
                        else  -- 金钻，取初始化金币
                            table.insert(result.items, {coin=bonusGame.baseCoin, isGold=true})
                        end
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
    local currResult = {}
    bonusGame.spinCnt = bonusGame.spinCnt - 1
    local allFull = true
    -- 从预先的结果中弹出一个结果
    for i = 1, 2 do
        -- body
        local copySlot = bonusGame.slots[i]
        local result = table.remove(bonusGame.finalResult.results[i], 1)
        -- 将结果加入卷轴中，并发送给前端

        for index, idx in ipairs(result.idxs) do
            if not table.contain(copySlot.bonusIdxs, idx) then
                table.insert(copySlot.bonusIdxs, idx)
                table.insert(copySlot.bonusItems, result.items[index])

            end
        end
        if #copySlot.bonusIdxs < GAME_CFG.COL_NUM * GAME_CFG.ROW_NUM then
            allFull = false
        end
        currResult[i] = result
    end

    -- 如果剩余次数小于0
    if bonusGame.spinCnt <= 0 or allFull then
        -- 如果还没有转完，说明还有额外次数
        if #bonusGame.finalResult.results[2] > 0 then
            bonusGame.state = 1
            return currResult
        else
            bonusGame.isEnd = true
            -- 结算
            for i = 1, 2 do
                local copySlot = bonusGame.slots[i]
                for _, item in ipairs(copySlot.bonusItems) do
                    if item.jackpot then
                        bonusGame.winCoin = bonusGame.winCoin + item.jackpot.value
                    else
                        bonusGame.winCoin = bonusGame.winCoin + item.coin
                    end
                end
            end
        end
    end
    return currResult
end

---------------------------------------------------------------------------------------
--- 收集游戏
---------------------------------------------------------------------------------------
-- 初始化进度条
local function initProgressBar(deskInfo, nextId)
    local needCnt = MapConfig[nextId].needCnt
    if DEBUG then
        needCnt = 20
    end
    local progressData = {
        needCnt = needCnt, -- 进度条需要的收集数量
        totalCnt = 0, -- 进度条当前收集数量
        totalCoin = 0, -- 进度条收集到的金币数量，用于计算出最终价值
    }
    return progressData
end

-- 初始化地图游戏
local function initMapInfo(deskInfo)
    local mapInfo = {
        state = 0,  -- 状态: 0=收集状态, 1=小关卡状态, 2=大关卡状态
        currId = 0,  -- 当前所处位置
        nextId = 1,  -- 下一关
        startPrice = 0,  -- 基础金币数
        totalPrice = 0,  -- 所有关卡的基础金币之和,用于计算大关卡的开始金币
        progressData = nil,  -- 进度条
    }

    local progressData = initProgressBar(deskInfo, mapInfo.nextId)
    mapInfo.progressData = progressData
    deskInfo.customData.mapInfo = mapInfo
end

-- 初始化小关卡 Wheel Game
local function initWheel(deskInfo, nextId)
    local mapInfo = deskInfo.customData.mapInfo
    local baseCoin = deskInfo.customData.mapInfo.startPrice
    
    -- 免费游戏转盘配置
    local wheel = {
        items = nil,  -- wheel 对应的选项
        finalItemId = nil,  -- 最终的结果，前端不会有这个字段
    }
    local items = table.copy(MapWheelConfig)
    local id, _ = utils.randByWeight(items)
    wheel.finalItemId = id
    local winAllId
    local winAllCoin = 0
    for k, cfg in pairs(items) do
        if cfg.winAll then
            winAllId = k
        else
            cfg.coin = math.round_coin(baseCoin * cfg.mult)
            winAllCoin = winAllCoin + cfg.coin
        end
        cfg.weight = nil
        cfg.mult = nil
    end
    items[winAllId].coin = winAllCoin
    wheel.items = items
    deskInfo.customData.mapInfo.wheel = wheel
end


-- 点击小关卡Wheel Game的spin按钮
local function spinWheelGame(deskInfo)
    local mapInfo = deskInfo.customData.mapInfo
    local wheel = mapInfo.wheel
    local item = wheel.items[wheel.finalItemId]
    local result = {
        itemId = wheel.finalItemId,
        winCoin = item.coin,
    }
    local progressData = initProgressBar(deskInfo, mapInfo.nextId)
    mapInfo.progressData = progressData
    mapInfo.state = 0
    mapInfo.wheel = nil
    return result
end

-- 获取地图游戏
local function getMapInfo(deskInfo)
    return table.copy(deskInfo.customData.mapInfo)
end

-- 收集进度条
local function collectProgressBar(deskInfo, cards)
    local times = 0
    if deskInfo.currmult >= getNeedBet(deskInfo) then
        for _, v in ipairs(cards) do
            if v == GAME_CFG.bonus then
                times = times + 1
            end
        end
    end
    return times
end

-- 将卷轴里能收集的个数汇总到进度条
local function addProgressBar(deskInfo, addTotal)
    local curCnt = 0
    if deskInfo.currmult >= getNeedBet(deskInfo) and addTotal > 0 then
        curCnt = addTotal
        local mapInfo = deskInfo.customData.mapInfo
        -- 总的收集进度
        local totalCnt = mapInfo.progressData.totalCnt + addTotal
        -- 总的收集金币数量
        local totalCoin = mapInfo.progressData.totalCoin + addTotal * deskInfo.totalBet
        mapInfo.progressData.totalCnt = totalCnt
        mapInfo.progressData.totalCoin = totalCoin
        if mapInfo.progressData.totalCnt >= mapInfo.progressData.needCnt then
            local mapCfg = MapConfig[mapInfo.nextId]
            if mapCfg.type == 2 then -- 切换状态，进入大关卡 免费游戏阶段
                mapInfo.state = 2
                mapInfo.totalPrice = mapInfo.totalPrice + math.floor(totalCoin/totalCnt)  -- 累增startPrice
                mapInfo.startPrice = math.floor(mapInfo.totalPrice/mapInfo.nextId)  -- 大关卡的基础金币等于前面所有startPrice的平均值
                mapInfo.currId = mapInfo.nextId  -- 记录当前关卡位置
                mapInfo.nextId = mapInfo.nextId + 1  -- 记录下一个关卡位置
            else
                mapInfo.state = 1 -- 切换状态， 进入小关卡
                mapInfo.startPrice = math.floor(totalCoin/totalCnt)
                mapInfo.totalPrice = mapInfo.totalPrice + mapInfo.startPrice
                mapInfo.currId = mapInfo.nextId
                mapInfo.nextId = mapInfo.nextId + 1
                initWheel(deskInfo, mapInfo.currId)
            end
        end
    end
    return curCnt
end


-- 地图大关卡, 进入免费状态
local function applyFreeInfo(deskInfo)
    --- @type MapInfo426
    local mapInfo = deskInfo.customData.mapInfo
    -- 当前大关卡
    local mapCfg = MapConfig[mapInfo.currId]
    -- 只有关卡正确才能继续进行
    if mapCfg.type ~= 2 then
        LOG_ERROR("这里发生了错误,当前关卡不是大关卡!")
        return nil
    end
    -- 应用免费游戏
    local freeResult = {
        freeCnt = mapCfg.freeCnt,
        scatterIdx = {},
        scatter = GAME_CFG.scatter,
        addMult = 1,
    }
    -- 切换mapInfo的状态
    return freeResult
end


---------------------------------------------------------------------------------------
--- 正常slot逻辑
---------------------------------------------------------------------------------------

-- 发牌逻辑
local function initResultCards(deskInfo)
    local isFreeState = checkIsFreeState(deskInfo)
    local cards = {}
    if isFreeState and deskInfo.customData.mapInfo.state == 2 then
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


local function start_691(deskInfo)
    local result = {}
    result.resultCards = initResultCards(deskInfo) --发牌
    local isFreeState = checkIsFreeState(deskInfo)
    local mapInfo = deskInfo.customData.mapInfo

    -- 检测是否触发免费
    result.freeResult = checkFreeGame(deskInfo, result.resultCards, GAME_CFG)
    local triggerFree = not table.empty(result.freeResult)
    --是否触发bonus游戏
    local triggerSubGame, bonusIdxs = checkSubGame(deskInfo, GAME_CFG, result.resultCards)

    --免费游戏最后一局不能触发bonus  客户端出现卡死
    if triggerSubGame and deskInfo.freeGameData.restFreeCount == 1 then
        local bonusTotal = #bonusIdxs
        for idx, _ in pairs(result.resultCards) do
            if result.resultCards[idx] == GAME_CFG.bonus then
                local cards = {4,5,6,7,8,10,11,12,13}
                result.resultCards[idx] = cards[math.random(1, #cards)] --换掉一个bonus
                bonusTotal = bonusTotal - 1
                if bonusTotal < 6 then
                   break
                end
            end
        end
        triggerSubGame, bonusIdxs = checkSubGame(deskInfo, GAME_CFG, result.resultCards)
    end
    
    --此轮收集游戏收集个数
    local collectNum = 0
    if not isFreeState then
        collectNum = collectProgressBar(deskInfo, result.resultCards)
    end
    local collectTotal = mapInfo.progressData.totalCnt + collectNum
    
    --防止两个同时触发 免费和bonus游戏取牌时已经不会同时出现
    if (triggerFree and collectTotal >= mapInfo.progressData.needCnt) or (triggerSubGame and collectTotal >= mapInfo.progressData.needCnt) then 
        for idx, _ in pairs(result.resultCards) do
            if result.resultCards[idx] == GAME_CFG.bonus then
                local cards = {4,5,6,7,8,10,11,12,13}
                result.resultCards[idx] = cards[math.random(1, #cards)] --换掉一个bonus
                collectTotal = collectTotal - 1
                if collectTotal < mapInfo.progressData.needCnt then
                   break
                end
            end
        end
        collectNum = collectProgressBar(deskInfo, result.resultCards)
        triggerSubGame, bonusIdxs = checkSubGame(deskInfo, GAME_CFG, result.resultCards)
    end
    
    -- 不是免费游戏收集
    local currCnt
    if not isFreeState then
        currCnt = addProgressBar(deskInfo, collectNum)
        if deskInfo.customData.mapInfo.state == 2 then
            -- 如果处于大关卡,且当前非免费游戏阶段,说明此轮触发了免费游戏
            result.freeResult = applyFreeInfo(deskInfo)
        end
    end

    --生成bonus金币数
    local bonusItems, baseCoin
    bonusItems, baseCoin = genBonusCards(deskInfo, bonusIdxs, triggerSubGame)
    if triggerSubGame then
        initBonusGame(deskInfo, baseCoin)
        initBonusGameSlots(deskInfo, deskInfo.customData.bonusGame, bonusIdxs, bonusItems)
    end

    local wildIdx = {}
    if isFreeState and deskInfo.customData.mapInfo.state == 2 then   --大关卡游戏 重新发牌
        local calcCards = {}  --后用来计算的牌
        local ratio = deskInfo.customData.mapInfo.startPrice / deskInfo.totalBet
        result.resultCards = {}  --清空前面发的牌 大关卡的牌有多个slots
        local slotsCount = MapConfig[deskInfo.customData.mapInfo.currId].slots
        for i = 1, slotsCount do
            local cards = initResultCards(deskInfo)
            local wildCnt = #wildIdx
            for idx, card in ipairs(cards) do
                if card == GAME_CFG.wilds[1] and not table.contain(wildIdx, idx) then
                    wildCnt = wildCnt + 1
                    break
                end
            end
            if wildCnt > 2 and slotsCount > 3 then
                for idx, card in ipairs(cards) do
                    if card == GAME_CFG.wilds[1] then
                        cards[idx] = GAME_CFG.NormalCards[math.random(#GAME_CFG.NormalCards)]
                    end
                end
            end

            table.insert(result.resultCards, cards)
            table.insert(calcCards, table.copy(cards))
            for key, value in ipairs(cards) do --找出slots wild所有位置
                if value == GAME_CFG.wilds[1] and not table.contain(wildIdx, key) then --前端需要不能重复的位置
                    table.insert(wildIdx, key)
                end
            end
        end

        result.winCoin = 0
        result.zjLuXian = {}
        for _, value in ipairs(calcCards) do
            for _, idx in ipairs(wildIdx) do  --把牌先变了
                value[idx] = GAME_CFG.wilds[1]
            end

            local _winCoin, _zjLuXian = getBigGameResult(deskInfo, value, GAME_CFG)
            table.insert(result.zjLuXian, _zjLuXian)
            result.winCoin = result.winCoin + math.round_coin(_winCoin * ratio)
        end
    else
        result.winCoin, result.zjLuXian = getBigGameResult(deskInfo, result.resultCards, GAME_CFG)  --普通游戏
    end
    

    -- 打包协议
    local retobj = cashBaseTool.genRetobjProto(deskInfo, result)
    retobj.bonusGame = deskInfo.customData.bonusGame
    retobj.bonusIdxs = bonusIdxs
    retobj.bonusItems = bonusItems
    retobj.mapInfo = getMapInfo(deskInfo)
    retobj.mapInfo.progressData.currCnt = currCnt or 0 -- 单独加上当轮增加的数量, 方便前端做特效
    retobj.wildIdx = wildIdx -- 大关卡中的wild位置
    return retobj
end

---------------------------------------------------------------------------------------
--- CMD 43 交互
---------------------------------------------------------------------------------------

local function create(deskInfo, uid)
    if not deskInfo.customData then
        initCustomData(deskInfo)
    end
    if not deskInfo.customData.mapInfo then
        initMapInfo(deskInfo)
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

    local betCoin = caulBet(deskInfo)  --得到下注金币
    local retobj = start_691(deskInfo)

    local mapInfo = deskInfo.customData.mapInfo
    if checkIsFreeState(deskInfo) and mapInfo.state == 2 and deskInfo.freeGameData.restFreeCount == 1 then --地图大关卡游戏转完 改变状态
        if mapInfo.nextId == #MapConfig + 1 then  -- 如果是最后一个大关卡,则回到初始位置
            mapInfo.currId = 0
            mapInfo.nextId = 1
            mapInfo.totalPrice = 0
        end
        mapInfo.state = 0
        mapInfo.progressData = initProgressBar(deskInfo, mapInfo.nextId) --地图大关卡转完清空进度条
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
    if rtype == 1 then  --小关卡 点击spin按钮 游戏
        if not deskInfo.customData.mapInfo.wheel then
            LOG_ERROR("the Wheel is nil")
            retobj.errMsg = "the Wheel is nil"
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        local result = spinWheelGame(deskInfo)
        retobj.mapInfo = getMapInfo(deskInfo)
        table.merge(retobj, result)
        if retobj.winCoin > 0 then
            cashBaseTool.caulCoin(deskInfo, retobj.winCoin, PDEFINE.ALTERCOINTAG.WIN)
            local results = {
                kind = "bonus",
                desc = "wheel",
            }
            baseRecord.slotsGameLog(deskInfo, 0, retobj.winCoin, results, 0)
        end
    elseif rtype == 2 then --bonus游戏 选择额外次数
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
    elseif rtype == 3 then --bonus 旋转一次
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
	retobj.rtype = rtype
	gameData.set(deskInfo)
	return retobj
end

---------------------------------------------------------------------------------------
--- CMD 43 额外增加的字段
---------------------------------------`------------------------------------------------

local function addSpecicalDeskInfo(deskInfo, simpleDeskData)
    simpleDeskData.needBet = getNeedBet(deskInfo)
    simpleDeskData.freeGameInfo = getFreeGameInfo(deskInfo)
    simpleDeskData.mapInfo = getMapInfo(deskInfo)
    simpleDeskData.bonusGame = getBonusGame(deskInfo)
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
