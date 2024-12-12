-- volcano fury
-- 火山的愤怒

--[[
    基础规则
    1. 正常游戏3行5列，线路是50线
    2. 3个scatter触发免费游戏
    3. 卷轴中出现bonus图标，图标上会随机出金币，jackpot，6个图标触发子游戏

    免费规则
    1. 普通游戏3个以上scatter固定触发8次免费游戏
    2. 免费游戏中2个以上的scatter触发固定5次免费游戏
    
    bonus游戏
    1. 5个bonus图标触发小游戏，给予3次spin机会
    2. 每获得一个bonus图标会重置spin次数
    3. 获得一个上升图标，会增加一行，最多6行
    4. 获得扩散图标，会使周围的bonus图标上的金币翻倍，不影响jackpot图标
    5. 最终获得所有bonus图标上的金币
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
    gameid = 694,
    line = 50,
    winTrace = config.LINECONF[50][4],
    mults = config.MULTSCONF[888][1],
    RESULT_CFG = config.CARDCONF[694],
    wilds = {1},
    scatter = 2,
    bonus = 3,
    freeGameConf = {card = 2, min = 3, freeCnt = 8, minInFree=2, extraFreeCnt=5, addMult = 1}, -- 免费游戏配置,extraFreeCnt:免费中免费的次数
    COL_NUM = 5,
    ROW_NUM = 3,
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

-- bonus图标的类型
local BonusType = {
    Normal = 1,  -- 普通bonus图标
    Uplevel = 2,  -- 上升图标
    Spread = 3,  -- 扩散图标
}

-- 配置扩散图标的数量配置
local BonusSpreadConfig = {
    [1] = {cnt=0, weight=200},
    [2] = {cnt=1, weight=100},
    [3] = {cnt=2, weight=200},
    [4] = {cnt=3, weight=300},
    [5] = {cnt=4, weight=100},
    [6] = {cnt=5, weight=50},
}

-- 配置升级图标的数量配置
local BonusUplevelConfig = {
    [1] = {cnt=0, weight=100},
    [2] = {cnt=1, weight=100},
    [3] = {cnt=2, weight=100},
    [4] = {cnt=3, weight=50},
}

-- 配置普通图标的数量, 对应零个上升图标
local BonusCountConfig1 = {
    [1] = {cnt=8, weight=40},
    [2] = {cnt=9, weight=50},
    [3] = {cnt=10, weight=100},
    [4] = {cnt=11, weight=200},
    [5] = {cnt=12, weight=500},
    [6] = {cnt=13, weight=400},
    [7] = {cnt=14, weight=200},
    [8] = {cnt=15, weight=50},
}

-- 配置普通图标的数量, 对应一个上升图标
local BonusCountConfig2 = {
    [1] = {cnt=11, weight=50},
    [2] = {cnt=12, weight=100},
    [3] = {cnt=13, weight=200},
    [4] = {cnt=14, weight=400},
    [5] = {cnt=15, weight=500},
    [6] = {cnt=16, weight=500},
    [7] = {cnt=17, weight=400},
    [8] = {cnt=18, weight=300},
    [9] = {cnt=19, weight=200},
    [10] = {cnt=20, weight=100},
}

-- 配置普通图标的数量, 对应两个上升图标
local BonusCountConfig3 = {
    [1] = {cnt=13, weight=10},
    [2] = {cnt=14, weight=50},
    [3] = {cnt=15, weight=100},
    [4] = {cnt=16, weight=200},
    [5] = {cnt=17, weight=300},
    [6] = {cnt=18, weight=400},
    [7] = {cnt=19, weight=500},
    [8] = {cnt=20, weight=500},
    [9] = {cnt=21, weight=400},
    [10] = {cnt=22, weight=300},
    [11] = {cnt=23, weight=200},
    [12] = {cnt=24, weight=100},
    [13] = {cnt=25, weight=50},
}

-- 配置普通图标的数量, 对应三个上升图标
local BonusCountConfig4 = {
    [1] = {cnt=16, weight=10},
    [2] = {cnt=17, weight=20},
    [3] = {cnt=18, weight=40},
    [4] = {cnt=19, weight=100},
    [5] = {cnt=20, weight=200},
    [6] = {cnt=21, weight=300},
    [7] = {cnt=22, weight=400},
    [8] = {cnt=23, weight=500},
    [9] = {cnt=24, weight=500},
    [10] = {cnt=25, weight=400},
    [11] = {cnt=26, weight=300},
    [12] = {cnt=27, weight=200},
    [13] = {cnt=28, weight=100},
    [14] = {cnt=29, weight=50},
    [15] = {cnt=30, weight=10},
}

-- 进入bonusGame的前提下，bonus图标上的金币大小以及概率
local BonusItemConfig = {
    [1] = {mult=nil, jackpotId=JackPot.Mini, weight=200},
    [2] = {mult=nil, jackpotId=JackPot.Minor, weight=40},
    [3] = {mult=nil, jackpotId=JackPot.Major, weight=2},
    [4] = {mult=nil, jackpotId=JackPot.Grand, weight=0},
    [5] = {mult=0.25, jackpotId=nil, weight=1000},
    [6] = {mult=0.5, jackpotId=nil, weight=1000},
    [7] = {mult=1, jackpotId=nil, weight=800},
    [8] = {mult=2, jackpotId=nil, weight=500},
    [9] = {mult=3, jackpotId=nil, weight=100},
    [10] = {mult=5, jackpotId=nil, weight=50},
}

-- 正常旋转中bonus未进bonus游戏的概率
-- 这个概率可以稍微高一点
local FailBonusItemConfig = {
    [1] = {mult=nil, jackpotId=JackPot.Mini, weight=240},
    [2] = {mult=nil, jackpotId=JackPot.Minor, weight=60},
    [3] = {mult=nil, jackpotId=JackPot.Major, weight=6},
    [4] = {mult=nil, jackpotId=JackPot.Grand, weight=1},
    [5] = {mult=0.25, jackpotId=nil, weight=1000},
    [6] = {mult=0.5, jackpotId=nil, weight=800},
    [7] = {mult=1, jackpotId=nil, weight=600},
    [8] = {mult=2, jackpotId=nil, weight=400},
    [9] = {mult=3, jackpotId=nil, weight=100},
    [10] = {mult=5, jackpotId=nil, weight=100},
    [11] = {mult=10, jackpotId=nil, weight=50},
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
    if isFreeState then
        if #freeCardIdxs >= GAME_CFG.freeGameConf.minInFree then
            ret.freeCnt = GAME_CFG.freeGameConf.extraFreeCnt
            ret.scatterIdx = freeCardIdxs
            ret.scatter = GAME_CFG.freeGameConf.card
            ret.addMult = GAME_CFG.freeGameConf.addMult or 1
        end
    else
        if #freeCardIdxs >= GAME_CFG.freeGameConf.min then
            ret.freeCnt = GAME_CFG.freeGameConf.freeCnt
            ret.scatterIdx = freeCardIdxs
            ret.scatter = GAME_CFG.freeGameConf.card
            ret.addMult = GAME_CFG.freeGameConf.addMult or 1
        end
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
        return true
    end
    return false
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
local function genBonusInfo(deskInfo, cards, triggerBonusGame)
    local randNum = math.random()
    local itemConfigs = nil
    local baseCoin = 0
    -- 触发了bonus游戏和没触发，对应bonus图标上的金币概率不同
    if triggerBonusGame then
        itemConfigs = BonusItemConfig
    else
        itemConfigs = FailBonusItemConfig
    end

    local bonusInfo = {}
    for idx, card in ipairs(cards) do
        if card == GAME_CFG.bonus then
            local _, rs = utils.randByWeight(itemConfigs)
            if rs.jackpotId then
                table.insert(bonusInfo, {idx=idx, jackpot={id=rs.jackpotId}})
            else
                table.insert(bonusInfo, {idx=idx, coin=math.round_coin(deskInfo.totalBet*rs.mult)})
            end
        end
    end
    return bonusInfo
end

-- 初始化bonusGame
local function initBonusGame(deskInfo, bonusItems)
    local bonusGame = {
        items = {},  -- 位置上的bonus图标, 位置是从1-30
        spinCnt = 3,  -- 剩余spin的次数
        row = 3,  -- 当前行数
        jackpotValues = {},  -- 对应的jackpot值
        isEnd = false,  -- 是否结束
        winCoin = 0,  -- 最终赢的钱

        results = {},  -- 每次中的内容
    }
    for _, jp in ipairs({JackPot.Mini, JackPot.Minor, JackPot.Major, JackPot.Grand}) do
        local jackpotValue = getJackpotValue(GAME_CFG.gameid, jp, deskInfo.totalBet)
        bonusGame.jackpotValues[jp] = jackpotValue
    end
    -- 转换已有图标位置
    local exist_idxs = {}
    for _, item in ipairs(bonusItems) do
        local convert_item = {idx=item.idx+15, type=BonusType.Normal, coin=item.coin, jackpot=item.jackpot}
        -- 这里要算出jackpot的面值
        if convert_item.jackpot then
            convert_item.jackpot.value = bonusGame.jackpotValues[convert_item.jackpot.id]
        end
        table.insert(bonusGame.items, convert_item)
        table.insert(exist_idxs, convert_item.idx)
    end
    -- 计算可用位置
    -- 先从16开始
    local ledgal_idxs = {}
    for idx = 16, 30 do
        if not table.contain(exist_idxs, idx) then
            table.insert(ledgal_idxs, idx)
        end
    end
    -- 提前算出多少个升级图标
    local _, uplevel_rs = utils.randByWeight(BonusUplevelConfig)
    -- 根据上升图标，确认最终多少个bonus图标
    local configs
    if uplevel_rs.cnt == 0 then
        configs = table.copy(BonusCountConfig1)
    elseif uplevel_rs.cnt == 1 then
        configs = table.copy(BonusCountConfig2)
    elseif uplevel_rs.cnt == 2 then
        configs = table.copy(BonusCountConfig3)
    else
        configs = table.copy(BonusCountConfig4)
    end
    -- 提前算出多少个扩散图标
    -- 需要根据当前bonus图标数量来控制扩散图标出现的数量
    -- 如果当前bonus图标和上升图标的数量快满了，则减少扩散图标
    local spreadConfig = table.copy(BonusSpreadConfig)
    local alreadyCnt = uplevel_rs.cnt + #bonusGame.items
    local maxCnt = configs[#configs].cnt
    for _, c in ipairs(spreadConfig) do
        -- 确保随机出扩散图标之后，还有空余位置
        if c.cnt + alreadyCnt + 1 >= maxCnt then
            c.weight = 0
        end
    end
    local _, spread_rs = utils.randByWeight(spreadConfig)

    -- 去掉不合理的数量
    for _, cfg in ipairs(configs) do
        if cfg.cnt < uplevel_rs.cnt + spread_rs.cnt + #bonusGame.items then
            cfg.weight = 0
        end
    end
    -- 根据随机情况，生成结果
    local _, cnt_rs = utils.randByWeight(configs)
    local finalCnt = cnt_rs.cnt - #bonusGame.items
    local uplevel_cnt = uplevel_rs.cnt
    local spread_cnt = spread_rs.cnt

    -- 生成bonus图标
    local results = {}

    -- 如果有上升图标，则需要在16-30中塞一个
    utils.shuffle(ledgal_idxs)
    local row = 3
    while uplevel_cnt > 0 do
        local _, mult_rs = utils.randByWeight(BonusItemConfig)
        local idx = table.remove(ledgal_idxs)
        local item = {idx=idx, type=BonusType.Uplevel}
        if mult_rs.jackpotId then
            item.jackpot = {id=mult_rs.jackpotId, value=bonusGame.jackpotValues[mult_rs.jackpotId]}
        else
            item.coin=deskInfo.totalBet*mult_rs.mult
        end
        table.insert(results, item)
        -- 将记录数量减1
        uplevel_cnt = uplevel_cnt - 1
        finalCnt = finalCnt - 1
        -- 往ledgal_idxs中插入新的位置，再随机打乱
        for col = 1, GAME_CFG.COL_NUM do
            local _idx = (row-1)*GAME_CFG.COL_NUM + col
            table.insert(ledgal_idxs, _idx)
        end
        row = row - 1
        utils.shuffle(ledgal_idxs)
    end

    -- 开始随机其他位置的图标
    local randindex = utils.genRandIdxs(#ledgal_idxs, finalCnt)
    local randIdxs = {}
    for _, i in ipairs(randindex) do
        table.insert(randIdxs, ledgal_idxs[i])
    end
    for _, idx in ipairs(randIdxs) do
        local _, mult_rs = utils.randByWeight(BonusItemConfig)
        local item = {idx=idx, type=BonusType.Normal}
        if mult_rs.jackpotId then
            item.jackpot = {id=mult_rs.jackpotId, value=bonusGame.jackpotValues[mult_rs.jackpotId]}
        else
            item.coin=deskInfo.totalBet*mult_rs.mult
        end
        table.insert(results, item)
    end
    -- 打乱位置
    utils.shuffle(results)
    -- 随机特殊图标
    local sp_rand_index = utils.genRandIdxs(finalCnt, spread_rs.cnt)
    for _, i in ipairs(sp_rand_index) do
        results[i].type = BonusType.Spread
    end
    -- 需要将不合理的位置挪动下，比如还没有解锁第一行，但是出现是1-15的位置图标
    local minRow = 3
    local _tmp_results = {}
    local _all_results = {}
    for _, item in ipairs(results) do
        if item.idx <= minRow *GAME_CFG.COL_NUM then
            table.insert(_tmp_results, item)
        else
            table.insert(_all_results, item)
            if item.type == BonusType.Uplevel then
                minRow = minRow - 1
                local _tmp = {}
                for _, _item in ipairs(_tmp_results) do
                    if _item.idx <= minRow *GAME_CFG.COL_NUM then
                        table.insert(_tmp, _item)
                    else
                        table.insert(_all_results, _item)
                    end
                end
                _tmp_results = _tmp
            end
        end
    end
    results = _all_results
    -- 将结果分散到不同步数中
    local randCnt = utils.breakUpResult(#results, #results)
    local spinCnt = 3
    while spinCnt > 0 do
        spinCnt = spinCnt - 1
        local cnt = table.remove(randCnt, 1) or 0
        local _rs = {}
        if cnt > 0 then
            for i = 1, cnt do
                local item = table.remove(results, 1)
                if item then
                    table.insert(_rs, item)
                end
                -- 如果是上升图标，则截断，不和后续的图标一起，防止超框
                -- 如果是扩散图标，也不和其他图标一起，因为会出现特效混乱
                if item.type == BonusType.Uplevel or item.type == BonusType.Spread then
                    spinCnt = 3
                    table.insert(bonusGame.results, _rs)
                    _rs = {}
                end
            end
        end
        if #_rs > 0 then
            spinCnt = 3
        end
        -- 这里防止出现3个连续的空白，造成游戏结束，但是结果还没有完全结束
        if #_rs == 0 and spinCnt == 0 and #results > 0 then
            spinCnt = 1
        else
            table.insert(bonusGame.results, _rs)
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
    return bonusGame
end

-- bonus游戏转动一次
local function spinBonusGame(deskInfo)
    local bonusGame = deskInfo.customData.bonusGame
    local currResult = {}
    
    bonusGame.spinCnt = bonusGame.spinCnt - 1
    -- 从预先的结果中弹出一个结果
    local result = table.remove(bonusGame.results, 1)
    -- 将结果加入卷轴中，并发送给前端
    if result and #result > 0 then
        bonusGame.spinCnt = 3
        for _, item in ipairs(result) do
            -- 提升一行
            if item.type == BonusType.Uplevel then
                bonusGame.row = bonusGame.row + 1
            end
            -- 扩散到周围图标
            if item.type == BonusType.Spread then
                local aroundIdxs = utils.getAroundIdxs(6, 5, item.idx, true)
                -- 需要根据行数，去掉不合理的图标
                local ledgalIdxs = {}
                local minIdx = (6 - bonusGame.row) * GAME_CFG.COL_NUM
                for _, idx in ipairs(aroundIdxs) do
                    if idx > minIdx then
                        table.insert(ledgalIdxs, idx)
                    end
                end
                -- 将周围bonus图标金额翻倍
                item.effectIdxs = {}  -- 影响的位置
                for _, _item in ipairs(bonusGame.items) do
                    if not _item.jackpot and  table.contain(ledgalIdxs, _item.idx) then
                        table.insert(item.effectIdxs, _item.idx)
                        _item.coin = _item.coin * 2
                    end
                    if _item.idx == item.idx then
                        _item.coin = item.coin
                    end
                end
            end
            table.insert(currResult, item)
            local itemCopy = table.copy(item)
            itemCopy.type = BonusType.Normal
            itemCopy.effectIdxs = nil
            table.insert(bonusGame.items, itemCopy)
        end
    end

    -- 如果剩余次数小于0 或者已有位置满了
    local currCnt = #bonusGame.items
    if bonusGame.spinCnt <= 0 or currCnt == bonusGame.row*GAME_CFG.COL_NUM then
        bonusGame.isEnd = true
        bonusGame.spinCnt = 0
        -- 结算
        for _, item in ipairs(bonusGame.items) do
            if item.jackpot then
                bonusGame.winCoin = bonusGame.winCoin + item.jackpot.value
            else
                bonusGame.winCoin = bonusGame.winCoin + item.coin
            end
        end
    end
    return currResult
end


---------------------------------------------------------------------------------------
--- 辣椒图标相关
---------------------------------------------------------------------------------------


local function start_694(deskInfo)
    local isFreeState = checkIsFreeState(deskInfo)
    local result = {}

    --发牌
    result.resultCards = initResultCards(deskInfo)

    --检车是否触发免费
    result.freeResult = checkFreeGame(deskInfo, result.resultCards, GAME_CFG)

    -- 检测是否触发bonus游戏
    local triggerSubGame = checkSubGame(deskInfo, GAME_CFG, result.resultCards)

    -- 触发了bonus游戏和没触发bonus游戏会有不同的权重
    local bonusInfo = genBonusInfo(deskInfo, result.resultCards, triggerSubGame)

    -- 初始化bonus游戏
    if triggerSubGame then
        initBonusGame(deskInfo, bonusInfo)
    end

    -- 计算结果
    result.winCoin, result.zjLuXian, result.scatterResult = getBigGameResult(deskInfo, result.resultCards)

    -- 生成回复协议
    local retobj = cashBaseTool.genRetobjProto(deskInfo, result)

    retobj.bonusGame = getBonusGame(deskInfo)
    retobj.bonusInfo = bonusInfo
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
    if isFreeState then
        deskInfo.control.freeControl.probability = math.min(120, deskInfo.control.freeControl.probability * 8) --免费触发免费的概率
    end
    -- 自己的服务器，免费不能触发免费，防止无限免费
    if DEBUG and isFreeState then
        deskInfo.control.freeControl.probability = 50
    end
    local betCoin = caulBet(deskInfo)

    local retobj = start_694(deskInfo)

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
    if rtype == 1 then	-- bonus游戏
        if not deskInfo.customData.bonusGame then
            retobj.errMsg = "The bonusGame is nil"
            retobj.spcode = PDEFINE_ERRCODE.ERROR.SLOT_ERROR
            return retobj
        end
        retobj.currResult = spinBonusGame(deskInfo)
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
        simpleDeskData.bonusGame = getBonusGame(deskInfo)
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

-- bonus图标的类型
local BonusType = {
    Normal = 1,  -- 普通bonus图标
    Uplevel = 2,  -- 上升图标
    Spread = 3,  -- 扩散图标
}

-- bonus游戏
local bonusGame = {
    items = {},  -- 位置上的bonus图标, 位置是从1-30 {idx=1, coin=1000,type=BonusType, effectIdxs={12,23,12}}
    spinCnt = 3,  -- 剩余spin的次数
    row = 3,  -- 当前行数
    jackpotValues = {},  -- 对应的jackpot值
    isEnd = false,  -- 是否结束
    winCoin = 0,  -- 最终赢的钱

    results = {},  -- 每次中的内容
}


-- 44协议额外字段
retobj.bonusGame = bonusGame  -- bonus游戏信息
retobj.bonusInfo = bonusInfo  -- {idx=1, coin=1000, jackpot={id=1}}

-- 51协议
{rtype=1}  -- bonus游戏

res: {
    currResult = {{idx=1, coin=1000,type=BonusType, effectIdxs={12,23,12}}} -- effectIdxs扩散图标对应扩散的位置
    extraFreeInfo = extraFreeInfo
}

]]