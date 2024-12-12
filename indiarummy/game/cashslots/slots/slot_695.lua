-- Beauty and the Beast
-- 美女与野兽
-- 695

--[[
    基础规则
    1. 3个scatter触发免费游戏，10,15,20次
    2. 卷轴中的问号随机替换成其他图标
    3. 如果问号随机到上升图标，则会伸长卷轴，获得更多图标

    免费游戏
    1. 免费游戏中收集美元符号，可以中jackpot, 7 8 9 10对应 min,minor,major,grand

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

local DEBUG = os.getenv("DEBUG")  -- 是否是调试阶段，调试阶段，很多步数会减少

local GAME_CFG = {
    gameid = 695,
    line = 243,
    winTrace = config.LINECONF[243][1],
    mults = config.MULTSCONF[888][1],
    RESULT_CFG = config.CARDCONF[695],
    wilds = {1},
    scatter = 2,
    bonus = 3,
    freeGameConf = {card = 2, min = 5, minInFree=3, freeCnt = {[3]=4, [4]=6, [5]=8}, addMult = 1},
    COL_NUM = 5,
    ROW_NUM = 5,
    zeroCard = 20,  -- 空图标，不会出现在客户端
    commonCards = {4,5,6,7,8,9,10,11,12,13}
}

-- 对应的jackpotId
local JackPot = {
    Mini = 1,
    Minor = 2,
    Major = 3,
    Grand = 4,
}

-- 对应jackpot的图标
local JackpotCard = {
    Mini = 201,
    Minor = 202,
    Major = 203,
    Grand = 204,
}

-- 最大计数
local MaxCardCnt = 21

---------------------------------------------------------------------------------------
--- 参数配置
---------------------------------------------------------------------------------------

-- 超级免费游戏中，倍率列表
local SuperFreeGameMults = {2,3,4,5,8,10}

-- 免费游戏中中jackpot的概率
local JackpotConfig = {
    [1] = {jackpotId=JackPot.Mini, card = JackpotCard.Mini, cnt=3, weight=800},
    [2] = {jackpotId=JackPot.Minor, card = JackpotCard.Minor, cnt=4, weight=600},
    [3] = {jackpotId=JackPot.Major, card = JackpotCard.Major, cnt=5, weight=200},
    [4] = {jackpotId=JackPot.Grand, card = JackpotCard.Grand, cnt=6, weight=50},
}

-- 计算结果时，如果有图标消除了，替换图标的数量的概率
local SymbolCountConfig = {
    [1] = {cnt=1, weight=100},
    [2] = {cnt=2, weight=50},
    [3] = {cnt=3, weight=10},   
}

-- 替换图标出现的概率
local SymbolAppearConfig = {
    [1] = {card=1, weight=1},  -- wild图标将近为0
    [2] = {card=2, weight=10},  -- scatter图标，如果当列有scatter会自动置零
    [3] = {card=3, weight=10},  -- bonus图标概率比较少，因为可以触发jackpot奖励, 会根据当前是否触发jackpot来分配数量
    [4] = {card=4, weight=100},
    [5] = {card=5, weight=100},
    [6] = {card=6, weight=100},
    [7] = {card=7, weight=100},
    [8] = {card=8, weight=100},
    [9] = {card=9, weight=100},
    [10] = {card=10, weight=100},
    [11] = {card=11, weight=100},
    [12] = {card=12, weight=100},
    [13] = {card=13, weight=100},
}
-- 

---------------------------------------------------------------------------------------
--- 公共函数
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

local function initCustomData(deskInfo)
    if deskInfo.customData == nil then
        deskInfo.customData = {}
    end
end

-- 编写一个方法来获取图标，用来消除图标之后继续落下图标
local function genCardForFill(cnt, noScatter, noBonus, moreScatter)
    local cards = {}
    local configs = nil
    if noScatter or noBonus then
        configs = table.copy(SymbolAppearConfig)
        for _, cfg in ipairs(configs) do
            if cfg.card == GAME_CFG.scatter and noScatter then
                cfg.weight = 0
            end
            if cfg.card == GAME_CFG.bonus and noBonus then
                cfg.weight = 0
            end
        end
    elseif moreScatter then
        configs = table.copy(SymbolAppearConfig)
        for _, cfg in ipairs(configs) do
            if cfg.card == GAME_CFG.scatter then
                cfg.weight = 1000
            end
        end
    else
        configs = SymbolAppearConfig
    end
    while cnt > 0 do
        local _, rs = utils.randByWeight(configs)
        local _, cntRs = utils.randByWeight(SymbolCountConfig)
        local _cnt = cntRs.cnt
        if _cnt > cnt then
            _cnt = cnt
        end
        -- scatter 和bonus 只能出现一个
        if rs.card == GAME_CFG.bonus or rs.card == GAME_CFG.scatter then
            _cnt = 1
            rs.weight = 0
        end
        -- 减去数量
        cnt = cnt - _cnt
        -- 生成图标
        for i = 1, _cnt do
            table.insert(cards, rs.card)
        end
    end
    return cards
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

-- 通过计算卷轴中的数量
local function checkResult(deskInfo, cards)
    local winCoin = 0
    local winResult = {}
    local cardIdxs = {}
    local wildIdx = {}
    for idx, card in ipairs(cards) do
        if card == GAME_CFG.wilds[1] then
            table.insert(wildIdx, idx)
        else
            if not cardIdxs[card] then
                cardIdxs[card] = {idx}
            else 
                table.insert(cardIdxs[card], idx)
            end
        end
    end
    for card, idxs in pairs(cardIdxs) do
        local cfg = GAME_CFG.RESULT_CFG[card]
        local finalIdxs = idxs
        for _, idx in ipairs(wildIdx) do
            table.insert(finalIdxs, idx)
        end
        local cnt = #finalIdxs
        if cnt > MaxCardCnt then
            cnt = MaxCardCnt
        end
        if cfg and cfg.min <= cnt then
            local result = {}
            result.mult = 1
            result.card = card
            result.indexs = finalIdxs
            table.insert(winResult, result)
            -- 配置文件中的数值除以100
            winCoin = winCoin + math.round_coin(cfg['mult'][cnt] * deskInfo.totalBet / 100)
        end
    end
    return winCoin, winResult
end

---------------------------------------------------------------------------------------
--- 免费游戏中收集bonus图标
--- 收集指定数量图标，会获得jackpot，获得后重置该颜色的bonus，继续收集
---------------------------------------------------------------------------------------

-- 初始化免费收集结构结构
local function initFreeGameInfo(deskInfo)
    --- @class FreeGameInfo695
    local freeGameInfo = {
        bonusCnt = {
            [JackPot.Mini] = 0,
            [JackPot.Minor] = 0,
            [JackPot.Major] = 0,
            [JackPot.Grand] = 0,
        },
        needCnt = {
            [JackPot.Mini] = 0,
            [JackPot.Minor] = 0,
            [JackPot.Major] = 0,
            [JackPot.Grand] = 0,
        },
        jackpotValues = {},  -- 锁定的jackpot值
        jackpotBonus = nil,  -- jackpot图标的结果
    }

    -- 写入需要的值
    for _, cfg in ipairs(JackpotConfig) do
        freeGameInfo.needCnt[cfg.jackpotId] = cfg.cnt
    end
    
    -- 计算锁定的jackpot值
    for _, jp in ipairs({JackPot.Mini, JackPot.Minor, JackPot.Major, JackPot.Grand}) do
        local jackpotValue = getJackpotValue(GAME_CFG.gameid, jp, deskInfo.totalBet)
        freeGameInfo.jackpotValues[jp] = jackpotValue
    end

    -- 如果是免费游戏，则需要获取bonus的可能性列表
    local jackpotBonus = {}
    -- 提前生成jackpot的bonus图标
    local _, rs = utils.randByWeight(JackpotConfig)
    for _, cfg in ipairs(JackpotConfig) do
        local cnt = cfg.cnt - 1
        if cfg.jackpotId == rs.jackpotId then
            cnt = cfg.cnt*2 - 1
        else
        end
        for i = 1, cnt do
            table.insert(jackpotBonus, cfg.card)
        end
    end
    utils.shuffle(jackpotBonus)
    freeGameInfo.jackpotBonus = jackpotBonus
    deskInfo.customData.freeGameInfo = freeGameInfo
end

-- 收集卷轴中的bonus图标
local function collectBonusCard(deskInfo, cards)
    local freeGameInfo = deskInfo.customData.freeGameInfo
    local jackpot = nil
    for idx = 1, #cards do
        local jp = nil
        if cards[idx] == JackpotCard.Mini then
            jp = JackPot.Mini
        elseif cards[idx] == JackpotCard.Minor then
            jp = JackPot.Minor
        elseif cards[idx] == JackpotCard.Major then
            jp = JackPot.Major
        elseif cards[idx] == JackpotCard.Grand then
            jp = JackPot.Grand
        end
        if jp then
            freeGameInfo.bonusCnt[jp] = freeGameInfo.bonusCnt[jp] + 1
            -- 中了jackpot
            if freeGameInfo.bonusCnt[jp] >= freeGameInfo.needCnt[jp] then
                jackpot = {id=jp, value=freeGameInfo.jackpotValues[jp]}
                freeGameInfo.bonusCnt[jp] = 0
            end
        end
    end
    return jackpot
end

-- 获取当前免费游戏信息
local function getFreeGameInfo(deskInfo)
    if not deskInfo.customData.freeGameInfo then
        return nil
    end
    local freeGameInfo = table.copy(deskInfo.customData.freeGameInfo)
    freeGameInfo.jackpotBonus = nil
    return freeGameInfo
end

---------------------------------------------------------------------------------------
--- bonus收集游戏 每次免费都会增加一次记录
---------------------------------------------------------------------------------------

-- 初始化bonus trail 结构
local function initBonusTrail(deskInfo)
    local bonusTrail = {
        state = 0,  -- 状态 0: 收集状态, 1: mega bonus游戏状态, 2: super bonus游戏状态
        count = 0,  -- 记录的免费游戏次数
        megaIdx = {},  -- mega bonus 触发的位置
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
    local cards = cardProcessor.get_cards_2(deskInfo, GAME_CFG)
    return cards
end

-- 算出结果
-- 如果中奖，则中奖的图标都必须消除，然后消消乐
local function getBigGameResult(deskInfo, cards, gameConf)
    local isFreeState = checkIsFreeState(deskInfo)
    local moreScatter = false
    if math.random() < 0.04 then
        moreScatter = true
    end
    local winCoin = 0
    local results = { -- 每次的中奖信息
        -- {
        --     cards = {},  -- 中奖的卷轴
        --     idxs = {},  -- 中奖的位置
        --     winCoin = 0,  -- 中奖的金额
        -- }
    }

    local jackpotBonus = {}
    -- 获取到免费游戏提前算好的bonus图标
    if isFreeState then
        jackpotBonus = deskInfo.customData.freeGameInfo.jackpotBonus or {}
    end
    -- 改变现有卷轴中的bonus图标
    for idx = 1, #cards do
        if cards[idx] == GAME_CFG.bonus then
            local jp = table.remove(jackpotBonus, 1)
            if jp then
                cards[idx] = jp
            else
                cards[idx] = GAME_CFG.commonCards[math.random(#GAME_CFG.commonCards)]
            end
        end
    end

    local calcCards = table.copy(cards)

    while true do
        local _winCoin, _traceResult = checkResult(deskInfo, calcCards)
        local result = {
            cards = table.copy(calcCards),  -- 中奖的卷轴
            idxs = {},  -- 中奖的位置
            winCoin = _winCoin,  -- 中奖的金额
        }
        if _winCoin > 0 then
            -- 需要生成新的卡牌
            for _, rs in ipairs(_traceResult) do
                for _, idx in ipairs(rs.indexs) do
                    if calcCards[idx] ~= GAME_CFG.zeroCard then
                        table.insert(result.idxs, idx)
                        calcCards[idx] = GAME_CFG.zeroCard
                    end
                end
            end
            -- 根据列，生成新的图标
            local colCards = {}
            for col = 1, GAME_CFG.COL_NUM do
                if not colCards[col] then
                    colCards[col] = {}
                end
                local _cnt = 0  -- 需要新生成的数量
                local noScatter = false  -- 新生成中不包含scatter
                local noBonus = #jackpotBonus == 0 and true or false  -- 新生成中不包含bonus
                for row = 1, GAME_CFG.ROW_NUM do
                    local idx = (row - 1)*GAME_CFG.COL_NUM + col
                    if calcCards[idx] ~= GAME_CFG.zeroCard then
                        table.insert(colCards[col], calcCards[idx])
                        if calcCards[idx] == GAME_CFG.scatter then
                            noScatter = true
                        end
                        if calcCards[idx] == GAME_CFG.bonus then
                            noBonus = true
                        end
                    else
                        _cnt = _cnt + 1
                    end
                end
                -- 如果需要生成新的图标，则随机
                if _cnt > 0 then
                    local _cards = genCardForFill(_cnt, noScatter, noBonus, moreScatter)
                    for _, card in ipairs(_cards) do
                        local _card = card
                        -- 只能生成指定多的bonus图标，超过就用普通图标代替
                        if card == GAME_CFG.bonus then
                            local jp = table.remove(jackpotBonus, 1)
                            if jp then
                                _card = jp
                            else
                                _card = GAME_CFG.commonCards[math.random(#GAME_CFG.commonCards)]
                            end
                        end
                        table.insert(colCards[col],1, _card)
                    end
                end
            end
            -- 生成新的卷轴
            calcCards = {}
            for row = 1, GAME_CFG.ROW_NUM do
                for col = 1, GAME_CFG.COL_NUM do
                    table.insert(calcCards, colCards[col][row])
                end
            end
        end
        table.insert(results, result)
        winCoin = winCoin + _winCoin
        if _winCoin == 0 then
            break
        end
    end

    return winCoin, results, {}
end

--- 检测免费
local function checkFreeGame(deskInfo, cards, gameConf)
    local freeCardIdxs = {}
    for k, v in pairs(cards) do
        if v == GAME_CFG.freeGameConf.card then
            table.insert(freeCardIdxs, k)
        end
    end
    local ret = {}
    local totalCnt = #freeCardIdxs
    if totalCnt > 5 then
        totalCnt = 5
    end
    if checkIsFreeState(deskInfo) then
        if totalCnt >= gameConf.freeGameConf.minInFree then
            ret.freeCnt = gameConf.freeGameConf.freeCnt[totalCnt]
            ret.scatterIdx = freeCardIdxs
            ret.scatter = gameConf.freeGameConf.card
            ret.addMult = gameConf.freeGameConf.addMult or 1
        end
    else
        if totalCnt >= gameConf.freeGameConf.min then
            ret.freeCnt = gameConf.freeGameConf.freeCnt[totalCnt]
            ret.scatterIdx = freeCardIdxs
            ret.scatter = gameConf.freeGameConf.card
            ret.addMult = gameConf.freeGameConf.addMult or 1
        end
    end
    return ret
end


local function start_695(deskInfo)
    local isFreeState = checkIsFreeState(deskInfo)
    local result = {}

    local totalBet = deskInfo.totalBet

    if isFreeState and deskInfo.customData.bonusTrail.state ~= 0 then
        totalBet = deskInfo.customData.bonusTrail.startPrize
    end
    
    --发牌
    result.resultCards = getCards(deskInfo)

    local calcCards = result.resultCards
    result.zjLuXian = {}
    result.scatterResult = {}

    result.winCoin, result.winResults = getBigGameResult(deskInfo, calcCards, GAME_CFG)

    if #result.winResults > 0 then
        calcCards = result.winResults[#result.winResults].cards
        if deskInfo.customData.bonusTrail.state == 2 then
            -- 每次消除都会增加倍数
            for i, subResult in ipairs(result.winResults) do
                subResult.mult = i < #SuperFreeGameMults and SuperFreeGameMults[i] or SuperFreeGameMults[#SuperFreeGameMults]
                result.winCoin = result.winCoin + subResult.winCoin * (subResult.mult-1)
                subResult.winCoin = subResult.winCoin * subResult.mult
            end
        end
    end

    -- 检测是否触发免费, 必须检测最后一个卷轴
    result.freeResult = checkFreeGame(deskInfo, calcCards, GAME_CFG)

    -- 如果触发免费，则需要初始化免费游戏收集信息
    if not table.empty(result.freeResult) and not isFreeState then
        initFreeGameInfo(deskInfo)

        -- 每触发一次，记录一点能量
        if deskInfo.currmult >= getNeedBet(deskInfo) and not isFreeState then
            addBonusTrail(deskInfo)
        end
    end

    local jackpot
    if isFreeState then
        jackpot = collectBonusCard(deskInfo, calcCards)
        if jackpot then
            result.winCoin = result.winCoin + jackpot.value
        end
    end

    -- 打包协议
    local retobj = cashBaseTool.genRetobjProto(deskInfo, result)
    retobj.winResults = result.winResults
    retobj.bonusTrail = deskInfo.customData.bonusTrail
    retobj.freeGameInfo = getFreeGameInfo(deskInfo)
    retobj.jackpot = jackpot
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
    local betCoin = caulBet(deskInfo)
    local retobj = start_695(deskInfo)
    
    -- 免费游戏结束 并清空免费数据
    if isFreeState and table.empty(retobj.freeResult.freeInfo) and deskInfo.freeGameData.restFreeCount <= 1 then
        deskInfo.customData.freeGameInfo = nil
        refreshBonusTrail(deskInfo)
    end

    -- 如果触发了转盘免费，则不需要加金币
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
    retobj.rtype = rtype
    if rtype == 1 then
        
    end
    gameData.set(deskInfo)
    return retobj
end

---------------------------------------------------------------------------------------
--- CMD 43 额外增加的字段
---------------------------------------------------------------------------------------

local function addSpecicalDeskInfo(deskInfo, simpleDeskData)
    simpleDeskData.needBet = getNeedBet(deskInfo)
    simpleDeskData.freeGameInfo = getFreeGameInfo(deskInfo)
    simpleDeskData.bonusTrail = deskInfo.customData.bonusTrail
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
--- 消息结构体注释
---------------------------------------------------------------------------------------

--[[

-- 对应的jackpotId
local JackPot = {
    Mini = 1,
    Minor = 2,
    Major = 3,
    Grand = 4,
}

-- 神秘图标以及滚动卷轴的结果
local secretInfo = {
    idxs = {},  -- 神秘图标的位置
    cards = {},  -- 最终的卷轴图标, 如果有升级，则是5行，如果升两级则是6行
    extraCards = {},  -- 增加的两行图标
    convertCard = nil,  -- 随机到的最终图标，如果有upLevel则中间需要下是一个升级图标
    upLevel = 0,  -- 是否有升级，0=未升级，1=升两行，2=升3行
}

-- 免费游戏中的收集信息
local freeGameInfo = {
    bonusCnt = 0,  -- 特殊 美元图标 收集数量
    nextJackpotId = JackPot.Mini,  -- 下一个jackpot
    currJackpotId = nil,  -- 当前已中的jackpot
    restCnt = 7,  -- 剩余的数量
    jackpotValues = {},  -- 锁定的jackpot值
}

-------------------------------------------------------------------------------------
- 流程
-------------------------------------------------------------------------------------

CMD:43
retobj.freeGameInfo = freeGameInfo

CMD:44
retobj.freeGameInfo = freeGameInfo
retobj.secretInfo = secretInfo
retobj.jackpot = {  -- 免费游戏结束，结算jackpot
    id = 1,
    value = 10000
}
]]