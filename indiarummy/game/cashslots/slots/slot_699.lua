-- 狮身人面像

--[[
    基础规则
    1. 正常游戏3行5列，线路是243线
    2. 3个scatter触发免费游戏，每第10次免费，会增强
    3. 卷轴中出现bonus图标，图标上会随机出免费游戏，金币，jackpot，booster, 并获得相应的奖励

    免费规则
    1. 两种触发模式，一种通过3个scatter, 一种通过bonus图标获得免费游戏
    2. powerUp的booster会增强免费游戏（除了字母图标，还会去掉其他图标）
    3. 免费游戏中没有字母图标(A,K,A,J,10,9)
    4. 免费游戏中，bonus图标出现的概率会增强
    5. 免费游戏能重复触发
    
    bonus游戏
    1. 如果bonus图标上面出现jackpot booster信息，则触发jackpot游戏
    2. 如果触发的时候有power up,则会在游戏中加入jackpot remove图标，点中改图标，会去掉最低的jackpot
    3. 选出三个相同的jackpot图标，会赢取该jackpot奖励

    收集游戏
    1. 收集满整个进度条之后，会出现超级免费游戏，所有的金币奖励会X5
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
    gameid = 699,
    line = 243,
    winTrace = config.LINECONF[243],
    mults = config.MULTSCONF[888][1],
    RESULT_CFG = config.CARDCONF[699],
    wilds = {1},
    scatter = 2,
    bonus = 3,
    freeGameConf = {card = 2, min = 3, freeCnt = {[3]=10, [4]=15, [5]=20}, addMult = 1}, -- 免费游戏配置
    COL_NUM = 5,
    ROW_NUM = 3,
    commonCards = {10,11,12,13,14,15},
    specialBonus = 301,  -- 特殊bonus图标
}

-- 对应的jackpotId
local JackPot = {
    Mini = 1,
    Minor = 2,
    Major = 3,
    Maxi = 4,
    Grand = 5,
}

---------------------------------------------------------------------------------------
--- 参数配置
---------------------------------------------------------------------------------------

-- bonus图标在普通游戏中出现的数量
local BonusCountConfig = {
    [1] = {cnt=0, weight=1600},
    [2] = {cnt=1, weight=10},
    [3] = {cnt=2, weight=20},
    [4] = {cnt=3, weight=40},
    [5] = {cnt=4, weight=50},
    [6] = {cnt=5, weight=20},
    [7] = {cnt=6, weight=10},
    [8] = {cnt=7, weight=5},
    [9] = {cnt=8, weight=1},
}

-- bonus图标在免费游戏中出现的数量
-- 免费游戏中，bonus图标出现的概率会增强(大概50%左右)
local BonusCountConfigInFree = {
    [1] = {cnt=0, weight=300},
    [2] = {cnt=1, weight=10},
    [3] = {cnt=2, weight=30},
    [4] = {cnt=3, weight=80},
    [5] = {cnt=4, weight=80},
    [6] = {cnt=5, weight=40},
    [7] = {cnt=6, weight=10},
    [8] = {cnt=7, weight=5},
    [9] = {cnt=8, weight=1},
}

-- bonus图标在普通游戏中出现内容的概率
local BonusItemConfig = {
    [1] = {mult=0.1, weight=150},
    [2] = {mult=0.25, weight=250},
    [3] = {mult=0.5, weight=500},
    [4] = {mult=0.75, weight=250},
    [5] = {mult=1, weight=500},
    [6] = {mult=1.5, weight=250},
    [7] = {freeCnt=5, weight=7},
    [8] = {freeCnt=10, weight=5},
    [9] = {freeCnt=15, weight=2},
    [10] = {freeCnt=20, weight=1},
    [11] = {jackpotBonus=true, weight=20},  -- jackpot bonus
}

-- bonus图标在免费游戏中出现内容的概率
-- 免费游戏中，出现jackpot的概率会加高, 免费概率去掉
local BonusItemConfigInFree = {
    [1] = {mult=0.1, weight=100},
    [2] = {mult=0.25, weight=250},
    [3] = {mult=0.5, weight=500},
    [4] = {mult=0.75, weight=250},
    [5] = {mult=1, weight=500},
    [6] = {mult=1.5, weight=200},
    [7] = {jackpotBonus=true, weight=50},  -- jackpot bonus
}

-- 出现2个或者2个以上的bonus图标的时候，才有概率出现特殊bonus图标
-- 如果出现多个特殊bonus图标，这几个图标都将变成powerUp
-- 如果出现一个特殊bonus图标，则需要根据配置表随机图标内容
-- 特殊bonus图标不能覆盖 免费图标和jackpot图标
-- 如果出现coin booster类型的图标，则需要保留至少一个金币图标
local SpecialBonusConfig = {
    [1] = {cnt=0, weight=2000},
    [2] = {cnt=1, weight=50},
    [3] = {cnt=2, weight=10},
    [4] = {cnt=3, weight=1},
}

local SpecailBonusType = {
    coinBoost = 1,  -- 金币增加1x
    megaCoinBoost = 2,  -- 金币增加2x
    superCoinBoost = 3,  -- 金币增加3x
    powerUp = 4,  -- powerUp图标
}

-- 特殊bonus图标内容
-- 如果存在jackpotBonus或者免费游戏图标，则特殊bonus图标固定为powerUp
local SpecialBonusItemConfig = {
    [1] = {type=SpecailBonusType.coinBoost, mult=1, weight=100},  -- coin booster
    [2] = {type=SpecailBonusType.megaCoinBoost, mult=2, weight=50},  -- mega coin booster
    [3] = {type=SpecailBonusType.superCoinBoost, mult=3, weight=10},  -- super coin booster
}

-- jackpot游戏中的图标对应
local JackpotGameCards = {
    Mini = 1,
    Minor = 2,
    Major = 3,
    Maxi = 4,
    Grand = 5,
    jackpotBoost = 6,  -- +1
    megaJackpotBoost = 7, -- +2
    superJackpotBoost = 8, -- +3
    removeJackpot = 9,
}

-- jackpot游戏中jackpot的概率
local JackpotGameConfig = {
    [1] = {jackpotId=JackPot.Mini, card=JackpotGameCards.Mini, weight=500},
    [2] = {jackpotId=JackPot.Minor, card=JackpotGameCards.Minor, weight=400},
    [3] = {jackpotId=JackPot.Major, card=JackpotGameCards.Major, weight=300},
    [4] = {jackpotId=JackPot.Maxi, card=JackpotGameCards.Maxi, weight=50},
    [5] = {jackpotId=JackPot.Grand, card=JackpotGameCards.Grand, weight=0},
}

-- jackpotGame中boost图标的概率
-- mult标识将jackpot翻倍的倍数
local JackpotGameBoostConfig = {
    [1] = {
        cards={},
        mult=1,
        weight=5000
    },  -- 不中boost图标
    [2] = {
        cards={
            JackpotGameCards.jackpotBoost
        },
        mult=2,
        weight=1000
    },
    [3] = {
        cards={
            JackpotGameCards.megaJackpotBoost
        },
        mult=3,
        weight=100
    },
    [4] = {
        cards={
            JackpotGameCards.superJackpotBoost
        },
        mult=4,
        weight=50
    },
    [5] = {
        cards={
            JackpotGameCards.jackpotBoost, 
            JackpotGameCards.megaJackpotBoost
        },
        mult=4,
        weight=50
    },
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
--- ultimate bonus 免费游戏收集
---------------------------------------------------------------------------------------

-- 初始化bonus trail 结构
local function initBonusTrail(deskInfo)
    local bonusTrail = {
        state = 0,  -- 状态 0: 收集状态, 1: mega bonus游戏状态, 2: super bonus游戏状态
        count = 0,  -- 记录的免费游戏次数
        megaIdx = {},  -- mega bonus 触发的位置(这个游戏没有)
        superBonus = {10},  -- super bonus 触发的位置
        totalCount = 10,  -- 总共的次数，集满之后从0开始
        startPrize = 0,  -- 记录触发的平均下注额, 防止下注额变动
    }
    deskInfo.customData.bonusTrail = bonusTrail
end

-- 触发免费游戏时，会增加一次记录
local function addBonusTrail(deskInfo)
    local bonusTrail = deskInfo.customData.bonusTrail
    -- 记录当前的数量和下注额，方便计算
    local currTotalBet = deskInfo.totalBet
    local currCount = bonusTrail.count
    -- 增加次数
    bonusTrail.count = bonusTrail.count + 1
    -- 算出新的平均值
    bonusTrail.startPrize = math.floor((bonusTrail.startPrize * currCount + currTotalBet) / bonusTrail.count)
    if table.contain(bonusTrail.megaIdx, bonusTrail.count) then
        bonusTrail.state = 1
    elseif table.contain(bonusTrail.superBonus, bonusTrail.count) then
        bonusTrail.state = 2
    end
end

-- 每局普通游戏开始时会刷新
local function refreshBonusTrail(deskInfo)
    local bonusTrail = deskInfo.customData.bonusTrail
    -- 如果次数到达最大值，则会从0开始
    if bonusTrail.count >= bonusTrail.totalCount then
        bonusTrail.count = 0
    end
    -- 将状态改成收集状态
    bonusTrail.state = 0
end

---------------------------------------------------------------------------------------
--- jackpot 游戏
---------------------------------------------------------------------------------------

-- 初始化jackpot游戏，powerUpCnt象征消除多少个lowerest jackpot
local function initJackpotGame(deskInfo, powerUpCnt)
    local jackpotGame = {
        startPrize = deskInfo.totalBet,
        powerUpCnt = powerUpCnt,  -- 可能获得removeJackpot的数量
        results = {},  -- 提前算好能获得的图标数量和内容
        choiceIdxs = {},  -- 存放前端发送来的位置，用于重连
        jackpotValues = {},  -- 初始jackpot的值列表
        winCoin = 0,  -- 最终获得的金币数量
        jackpot = nil,  -- 最终获得的jackpot, {id=1, value=1000}
        currMult = 1,  -- 当前奖池需要翻倍的倍数, 获得boost会翻倍奖池
        isEnd = false,  -- 是否结束
    }
    -- 如果是超级免费游戏中触发的，则应该使用平均下注额
    if checkIsFreeState(deskInfo) and deskInfo.customData.bonusTrail.state == 2 then
        jackpotGame.startPrize = deskInfo.customData.bonusTrail.startPrize
    end
    -- 算出jackpot的值
    local jackpotList = getJackpotList(deskInfo, GAME_CFG.gameid, jackpotGame.startPrize)
    for _, jp in ipairs({JackPot.Mini, JackPot.Minor, JackPot.Major, JackPot.Maxi, JackPot.Grand}) do
        if not table.contain(jackpotList, jp) then
            jackpotGame.jackpotValues[jp] = jackpotGame.startPrize * config.JACKPOTCONF[GAME_CFG.gameid].MULT[jp]
        else
            jackpotGame.jackpotValues[jp] = getJackpotValue(GAME_CFG.gameid, jp, jackpotGame.startPrize)
        end
    end
    -- 根据概率算出最终中奖结果
    local _, rs1 = utils.randByWeight(JackpotGameConfig)
    local tmpResults = {}
    -- 加入图标
    for _, cfg in ipairs(JackpotGameConfig) do
        table.insert(tmpResults, cfg.card)
        table.insert(tmpResults, cfg.card)
    end
    -- 随机其他图标
    local _, rs2 = utils.randByWeight(JackpotGameBoostConfig)
    if rs2.mult then
        jackpotGame.jackpot = {
            id = rs1.jackpotId,
            value = jackpotGame.jackpotValues[rs1.jackpotId] * rs2.mult
        }
    end
    for _, card in ipairs(rs2.cards) do
        table.insert(tmpResults, card)
    end
    -- 如果中的不是mini, 且有powerUp，则可以加入removejackpot图标
    local addPowerUpCnt = 0
    if rs1.jackpotId == JackPot.Grand or rs1.jackpotId == JackPot.Maxi then
        addPowerUpCnt = powerUpCnt
    elseif rs1.jackpotId == JackPot.Major then
        addPowerUpCnt = powerUpCnt <= 2 and powerUpCnt or 2
    elseif rs1.jackpotId == JackPot.Minor then
        addPowerUpCnt = powerUpCnt <= 1 and powerUpCnt or 1
    end
    -- 加入 removejackpot 图标
    if addPowerUpCnt > 0 then
        for i = 1, addPowerUpCnt do
            table.insert(tmpResults, JackpotGameCards.removeJackpot)
        end
    end
    -- 打乱顺序
    tmpResults = utils.shuffle(tmpResults)
    -- 按照顺序遍历，然后得出最终结果
    local removeJackpotCnt = 0
    local targetJackpotCard = 0
    local finalMult = 1
    for _, card in ipairs(tmpResults) do
        local canContinue = true
        -- 如果前面获得过remove jackpot,则后面就要过滤掉一些jackpot
        if removeJackpotCnt > 0 then
            if card == JackpotGameCards.Mini then
                canContinue = false
            end
            if removeJackpotCnt >= 2 and card == JackpotGameCards.Minor then
                canContinue = false
            end
            if removeJackpotCnt == 3 and card == JackpotGameCards.Major then
                canContinue = false
            end
        end
        -- 此图标是否合理
        if canContinue then
            table.insert(jackpotGame.results, card)
            if card == rs1.card then
                targetJackpotCard = targetJackpotCard + 1
            elseif card == JackpotGameCards.jackpotBoost then
                finalMult = finalMult + 1
            elseif card == JackpotGameCards.megaJackpotBoost then
                finalMult = finalMult + 2
            elseif card == JackpotGameCards.superJackpotBoost then
                finalMult = finalMult + 3
            elseif card == JackpotGameCards.removeJackpot then
                removeJackpotCnt = removeJackpotCnt + 1
            end
        end
        -- 如果预设倍数和两个个jackpot图标都选出了，则加入最后一个图标，结束循环
        if finalMult == rs2.mult and targetJackpotCard == 2 then
            table.insert(jackpotGame.results, rs1.card)
            break
        end
    end
    deskInfo.customData.jackpotGame = jackpotGame
end

-- pickJackpotGame, 选择金币
local function pickJackpotGame(deskInfo, idxs)
    local jackpotGame = deskInfo.customData.jackpotGame
    for _, idx in ipairs(idxs) do
        local card = jackpotGame.results[#jackpotGame.choiceIdxs+1]
        if card == JackpotGameCards.jackpotBoost then
            jackpotGame.currMult = jackpotGame.currMult + 1
        elseif card == JackpotGameCards.megaJackpotBoost then
            jackpotGame.currMult = jackpotGame.currMult + 2
        elseif card == JackpotGameCards.superJackpotBoost then
            jackpotGame.currMult = jackpotGame.currMult + 3
        end
        table.insert(jackpotGame.choiceIdxs, idx)
        if #jackpotGame.results == #jackpotGame.choiceIdxs then
            jackpotGame.isEnd = true
            jackpotGame.winCoin = jackpotGame.jackpot.value
            break
        end
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

-- 去掉scatter图标
local function clearScatterCard(cards)
    local commonCardsLen = #GAME_CFG.commonCards
    for idx = 1, #cards do
        if cards[idx] == GAME_CFG.scatter then
            cards[idx] = GAME_CFG.commonCards[math.random(commonCardsLen)]
        end
    end
    return cards
end

-- 取正常的牌, 跟概率无关
local function getCards(deskInfo)
    local isFreeState = checkIsFreeState(deskInfo)
    local cardmap
    if isFreeState then
        if deskInfo.customData.bonusTrail.state == 2 then
            cardmap = cardProcessor.getCardMap(deskInfo, "superfreemap")
        else
            cardmap = cardProcessor.getCardMap(deskInfo, "freemap")
        end
    else
        cardmap = cardProcessor.getCardMap(deskInfo, "cardmap")
    end
    local cards = cardProcessor.get_cards_1(cardmap, GAME_CFG.COL_NUM, GAME_CFG.ROW_NUM)
    -- 如果免费游戏中，多移除了图标，则需要换成狗图标
    if isFreeState and deskInfo.customData.removeSymbols then
        if #deskInfo.customData.removeSymbols > 6 then
            for idx = 1, #cards do
                if table.contain(deskInfo.customData.removeSymbols, cards[idx]) then
                    cards[idx] = 6
                end
            end
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
    -- 非免费是3个起步，免费是2个起步
    if #freeCardIdxs >= GAME_CFG.freeGameConf.min then
        ret.freeCnt = GAME_CFG.freeGameConf.freeCnt[#freeCardIdxs]
        ret.scatterIdx = freeCardIdxs
        ret.scatter = GAME_CFG.freeGameConf.card
        ret.addMult = GAME_CFG.freeGameConf.addMult or 1
    end
    return ret
end

-- 计算中奖线路
-- 因为是243线的游戏，所以不需要管线路，按照列来算结果就行了
local function checkResult(deskInfo, cards)
    local winResult = {}
    local winCoin = 0
    -- 存放格式{[colValue]={[cardValue] = {count=1, indexes={}, mult=1}}}}
    local colCards = {}
    local wild = GAME_CFG.wilds[1]
    -- 统计每列的牌值
    for idx = 1, #cards do
        -- 如果是零值，或者等于scatter 则忽略
        local card = cards[idx]
        -- 计算余数来判断是哪一列
        local col = math.fmod(idx, GAME_CFG.COL_NUM)
        if col == 0 then
            col = GAME_CFG.COL_NUM
        end
        -- 初始化记录的列信息
        if colCards[col] == nil then
            colCards[col] = {}
        end
        if card ~= GAME_CFG.scatter then
            local mult = 1
            local cardCnt = 1

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
            tempResult[GAME_CFG.scatter] = {mult = 1, indexes = idxs, count = count}
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
                table.insert(winResult, result)
                winCoin = winCoin + result.mult * deskInfo.singleBet * GAME_CFG.RESULT_CFG[k]["mult"][v.count]
            end
        end
    end
    winCoin = math.round_coin(winCoin)
    return winCoin, winResult
end

-- 计算结果
local function getBigGameResult(deskInfo, cards, _)
    -- 计算结果
    local winCoin = 0
    local traceResult = {}
    local scatterResult = {}
    winCoin, traceResult = checkResult(deskInfo, cards)

    -- 如果是超级免费游戏(收集10次免费触发), 则需要使用平均值
    if checkIsFreeState(deskInfo) and deskInfo.customData.bonusTrail.state ~= 0 then
        local ratio = deskInfo.customData.bonusTrail.startPrize / deskInfo.totalBet

        winCoin = math.round_coin(winCoin * ratio)
    end

    return winCoin, traceResult, scatterResult
end

-- 发牌逻辑
local function initResultCards(deskInfo)
    local funcList = {
        getResultCards = getCards,
        checkFreeGame = checkFreeGame,
        getBigGameResult = getBigGameResult,
    }
    local cards = cardProcessor.get_cards_3(deskInfo, GAME_CFG, funcList)

    local design = cashBaseTool.addDesignatedCards(deskInfo)
    if design ~= nil then
        cards = table.copy(design)
    end
    return cards
end

---------------------------------------------------------------------------------------
--- 金币图标相关
---------------------------------------------------------------------------------------

-- 根据配置表生成bonus图标
local function genBonusCards(deskInfo, cards)
    local isFreeState = checkIsFreeState(deskInfo)
    local totalBet = deskInfo.totalBet
    -- 如果是超级免费，则需要取平均值
    local globalMult = 1
    if isFreeState and deskInfo.customData.bonusTrail.state == 2 then
        totalBet = deskInfo.customData.bonusTrail.startPrize
        globalMult = 5
    end
    -- 先计算数量
    local countConfig = isFreeState and BonusCountConfigInFree or BonusCountConfig
    countConfig = table.copy(countConfig)
    local _, countRs = utils.randByWeight(countConfig)
    -- 此轮不出现bonus图标
    if countRs.cnt == 0 then
        return cards, nil
    end
    -- 出现bonus图标，则不会出现scatter图标, 去掉卷轴中的scatter
    clearScatterCard(cards)
    -- 随机bonus图标上的内容和位置
    local bonusIdxs = utils.genRandIdxs(GAME_CFG.ROW_NUM*GAME_CFG.COL_NUM, countRs.cnt)
    local bonusItems = {}
    local specailBonusIdxs = {}  -- 特殊图标位置
    local specailBonusItems = {}  -- 特殊图标内容
    local itemConfig = isFreeState and table.copy(BonusItemConfigInFree) or table.copy(BonusItemConfig)
    itemConfig = table.copy(itemConfig)
    local canSpecialBonus = false -- 是否可以出现特殊bonus图标(需中免费和jackpot的情况下)
    for i = 1, countRs.cnt do
        local _, tmpRs = utils.randByWeight(itemConfig)
        -- 如果中了免费了，则把免费权重置零，只能中一个免费图标
        if tmpRs.freeCnt or tmpRs.jackpotBonus then
            canSpecialBonus = true
            for _, cfg in ipairs(itemConfig) do
                if cfg.freeCnt or cfg.jackpotBonus then
                    cfg.weight = 0
                end
            end
        end
        local item = {
            coin = nil,  -- 中金币
            jackpotBonus = tmpRs.jackpotBonus,  -- 中jackpotBonus
            freeCnt = tmpRs.freeCnt,  -- 中免费游戏
        }
        -- 中了金币，需要直接换成结果
        -- 如果是超级免费，则会翻5倍
        if tmpRs.mult then
            item.coin = math.round_coin(tmpRs.mult * totalBet * globalMult)
        end
        table.insert(bonusItems, item)
    end
    -- 如果可以中特殊bonus图标，则需要单独随机特殊图标
    -- 需要一个以上的bonus图标才能中特殊图标，因为要去掉一个金币图标或者一个(免费图标|jackpot图标)
    if countRs.cnt > 1 then
        local specailConfig = table.copy(SpecialBonusConfig)
        for _, cfg in ipairs(specailConfig) do
            if cfg.cnt > countRs.cnt - 1 then
                cfg.weight = 0
            end
        end
        local _, tmpRs = utils.randByWeight(specailConfig)
        -- 如果是超级免费，则不要出现特殊图标了
        if tmpRs.cnt > 0 and globalMult == 1 then
            -- 如果没有中免费和jackpot，则固定是金币翻倍类型
            if not canSpecialBonus then
                local _, specailRs = utils.randByWeight(SpecialBonusItemConfig)
                local randIndex = math.random(#bonusIdxs)
                local specailBonusIdx = table.remove(bonusIdxs, randIndex)
                table.remove(bonusItems, randIndex)
                specailBonusIdxs = {specailBonusIdx}
                specailBonusItems = {
                    {type=specailRs.type, mult=specailRs.mult}
                }
            else
                -- 其他情况固定特殊图标为powerUp
                for i = 1, tmpRs.cnt do
                    local coinIndexs = {}  -- 存放金币列表序号
                    for i, item in ipairs(bonusItems) do
                        if item.coin then
                            table.insert(coinIndexs, i)
                        end
                    end
                    local randIndex = coinIndexs[math.random(#coinIndexs)]
                    local specailBonusIdx = table.remove(bonusIdxs, randIndex)
                    table.remove(bonusItems, randIndex)
                    table.insert(specailBonusIdxs, specailBonusIdx)
                    table.insert(specailBonusItems, {
                        type=SpecailBonusType.powerUp
                    })
                end
            end
        end
    end
    -- 更改图标
    for _, idx in ipairs(bonusIdxs) do
        cards[idx] = GAME_CFG.bonus
    end
    for _, idx in ipairs(specailBonusIdxs) do
        cards[idx] = GAME_CFG.specialBonus
    end
    local bonusInfo = {
        idxs = bonusIdxs,   -- bonus图标位置
        items = bonusItems,   -- bonus图标内容
        specailIdxs = specailBonusIdxs,   -- 特殊bonus图标位置
        specailItems = specailBonusItems,  -- 特殊bonus图标内容 
        winCoin = 0,  --- 赢取的金币
        freeInfo = nil,  -- 获得免费游戏
        jackpotGame = nil,  -- 获得jackpot游戏
        powerUpCnt = nil,  -- powerUp的数量
    }
    -- 计算金币收益
    local powerUpCnt = 0
    local mult = 1
    for _, item in ipairs(bonusInfo.specailItems) do
        if item.type == SpecailBonusType.powerUp then
            powerUpCnt = powerUpCnt + 1
        else
            mult = mult + item.mult
        end
    end
    bonusInfo.powerUpCnt = powerUpCnt
    for _, item in ipairs(bonusInfo.items) do
        if item.coin then
            bonusInfo.winCoin = bonusInfo.winCoin + mult * item.coin
        elseif item.freeCnt then
            bonusInfo.freeInfo = {
                freeCnt = item.freeCnt,
                powerUpCnt = powerUpCnt,
            }
        elseif item.jackpotBonus then
            bonusInfo.jackpotGame = {
                powerUpCnt = powerUpCnt,
            }
        end
    end
    return cards, bonusInfo
end

local function start_699(deskInfo)
    local isFreeState = checkIsFreeState(deskInfo)
    local result = {}
    --发牌
    result.resultCards = initResultCards(deskInfo)

    --检车是否触发免费
    result.freeResult = checkFreeGame(deskInfo, result.resultCards, GAME_CFG)

    -- 如果触发免费, 进行额外操作
    if not isFreeState and not table.empty(result.freeResult) then
        -- 每触发一次，记录一点能量
        if deskInfo.currmult >= getNeedBet(deskInfo) then
            addBonusTrail(deskInfo)
        end
        -- 记录去掉的图标
        deskInfo.customData.removeSymbols = {10,11,12,13,14,15}
    end

    -- 如果没触发免费游戏，则可以检测是否中bonus图标
    local bonusInfo = nil
    if table.empty(result.freeResult) then
        result.resultCards, bonusInfo = genBonusCards(deskInfo, result.resultCards)
    end

    --计算结果
    result.winCoin, result.zjLuXian, result.scatterResult = getBigGameResult(deskInfo, result.resultCards)

    local retobj = cashBaseTool.genRetobjProto(deskInfo, result)

    -- 如果有bonus图标，则需要计算bonus图标的收益
    if bonusInfo then
        retobj.bonusInfo = bonusInfo
        retobj.wincoin = retobj.wincoin + bonusInfo.winCoin
        if bonusInfo.jackpotGame then
            initJackpotGame(deskInfo, bonusInfo.powerUpCnt)
        end
        if bonusInfo.freeInfo then
            -- 每触发一次，记录一点能量
            if deskInfo.currmult >= getNeedBet(deskInfo) then
                addBonusTrail(deskInfo)
            end
            -- 记录去掉的图标
            deskInfo.customData.removeSymbols = {10,11,12,13,14,15}
            -- 鸟
            if bonusInfo.freeInfo.powerUpCnt >= 1 then
                table.insert(deskInfo.customData.removeSymbols, 9)
            end
            -- 蛇
            if bonusInfo.freeInfo.powerUpCnt >= 2 then
                table.insert(deskInfo.customData.removeSymbols, 8)
            end
            -- 猫
            if bonusInfo.freeInfo.powerUpCnt >= 3 then
                table.insert(deskInfo.customData.removeSymbols, 7)
            end
            retobj.freeResult.freeInfo = {
                freeCnt = bonusInfo.freeInfo.freeCnt
            }
        end
    end
    retobj.removeSymbols = deskInfo.customData.removeSymbols
    retobj.jackpotGame = deskInfo.customData.jackpotGame
    -- 如果是超级免费游戏(收集10次免费触发), 则需要使用平均值
    if checkIsFreeState(deskInfo) and deskInfo.customData.bonusTrail.state ~= 0 then
        retobj.avgBet = deskInfo.customData.bonusTrail.startPrize
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
    if not deskInfo.customData.bonusTrail then
        initBonusTrail(deskInfo)
    end
end

---------------------------------------------------------------------------------------
--- CMD 44 交互
---------------------------------------------------------------------------------------

local function start(deskInfo) --正常游戏
    local isFreeState = checkIsFreeState(deskInfo)
    -- 自己的服务器，免费不能触发免费，防止无限免费
    if DEBUG and isFreeState then
        deskInfo.control.freeControl.probability = 50
    end
    local betCoin = caulBet(deskInfo)

    local retobj = start_699(deskInfo)

    retobj.bonusTrail = table.copy(deskInfo.customData.bonusTrail)  -- 这里需要copy, 不然最后一局状态会异常

    -- 免费游戏结束，需要刷新bonus进度条
    if isFreeState and deskInfo.freeGameData.restFreeCount <= 1 and table.empty(retobj.freeResult.freeInfo) then
        refreshBonusTrail(deskInfo)
        deskInfo.customData.removeSymbols = nil
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
    if rtype == 1 then	-- jackpot game 选择位置
        if not deskInfo.customData.jackpotGame then
            LOG_ERROR("the jackpotGame is nil")
            retobj.errMsg = "the jackpotGame is nil"
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        local choiceIdxs = recvobj.choiceIdxs
        if not choiceIdxs then
            LOG_ERROR("the choiceIdxs is nil")
            retobj.errMsg = "the choiceIdxs is nil"
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        pickJackpotGame(deskInfo, choiceIdxs)
        retobj.jackpotGame = table.copy(deskInfo.customData.jackpotGame)
        if retobj.jackpotGame.isEnd then
            if checkIsFreeState(deskInfo) then
                deskInfo.freeGameData.freeWinCoin = deskInfo.freeGameData.freeWinCoin + retobj.jackpotGame.winCoin
            else
                cashBaseTool.caulCoin(deskInfo, retobj.jackpotGame.winCoin, PDEFINE.ALTERCOINTAG.WIN)
            end
            local result = {
                kind = "bonus",
                desc = "jackpot game",
            }
            baseRecord.slotsGameLog(deskInfo, 0, retobj.jackpotGame.winCoin, result, 0)
            deskInfo.customData.jackpotGame = nil
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
    simpleDeskData.bonusTrail = deskInfo.customData.bonusTrail
    if checkIsFreeState(deskInfo) then
        simpleDeskData.removeSymbols = deskInfo.customData.removeSymbols
    end
    if deskInfo.customData.jackpotGame then
        simpleDeskData.jackpotGame = deskInfo.customData.jackpotGame
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
    Maxi = 4,
    Grand = 5,
}

-- 特殊bonus图标的类型
local SpecailBonusType = {
    coinBoost = 1,  -- 金币增加1x
    megaCoinBoost = 2,  -- 金币增加2x
    superCoinBoost = 3,  -- 金币增加3x
    powerUp = 4,  -- powerUp图标
}

-- jackpot游戏中的图标对应
local JackpotGameCards = {
    Mini = 1,
    Minor = 2,
    Major = 3,
    Maxi = 4,
    Grand = 5,
    jackpotBoost = 6,
    megaJackpotBoost = 7,
    superJackpotBoost = 8,
    removeJackpot = 9,
    removeJackpot = 10,
}

-- 免费游戏收集条，这个游戏没有mega bonus所以没有状态1
local bonusTrail = {
    state = 0,  -- 状态 0: 收集状态, 1: mega bonus游戏状态, 2: super bonus游戏状态
    count = 0,  -- 记录的免费游戏次数
    megaIdx = {},  -- mega bonus 触发的位置(这个游戏没有)
    superBonus = {6},  -- super bonus 触发的位置
    totalCount = 6,  -- 总共的次数，集满之后从0开始
    startPrize = 0,  -- 记录触发的平均下注额, 防止下注额变动
}

-- 进入jackpot子游戏
local jackpotGame = {
    startPrize = deskInfo.totalBet,
    powerUpCnt = powerUpCnt,  -- 可能获得removeJackpot的数量
    results = {},  -- 提前算好能获得的图标数量和内容
    choiceIdxs = {},  -- 存放前端发送来的位置，用于重连
    jackpotValues = {},  -- 初始jackpot的值列表
    winCoin = 0,  -- 最终获得的金币数量
    jackpot = nil,  -- 最终获得的jackpot, {id=1, value=1000}
    currMult = 1,  -- 当前奖池需要翻倍的倍数, 获得boost会翻倍奖池
    isEnd = false,  -- 是否结束
}

-- bonus图标的信息
local bonusInfo = {
    idxs = bonusIdxs,   -- bonus图标位置
    items = bonusItems,   -- bonus图标内容
    specailIdxs = specailBonusIdxs,   -- 特殊bonus图标位置
    specailItems = specailBonusItems,  -- 特殊bonus图标内容 
    winCoin = 0,  --- 赢取的金币
    freeInfo = nil,  -- 获得免费游戏
    jackpotGame = nil,  -- 获得jackpot游戏
    powerUpCnt = nil,  -- powerUp的数量
}


-- 44协议额外字段
retobj.bonusInfo = bonusInfo  -- bonus图标信息，没有则为空
retobj.bonusTrail = bonusTrail  -- 返回进度条信息
retobj.jackpotGame = jackpotGame -- 如果进入jackpot游戏则有这个字段
retobj.removeSymbols = removeSymbols  -- 免费游戏中移除的图标列表

-- 51协议
{rtype=1, choiceIdxs={}}  -- jackpotGame中，传递选择的位置, 结果已提前告知

res: {
    jackpotGame = jackpotGame
}
]]