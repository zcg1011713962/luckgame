--[[
    龙的传说 The Legend of Dragon
    1.收集元宝
        1.1 spin的时候有概率获得元宝，平均每把出元宝个数30
        1.2 元宝在商店升级神龙

    2. 免费游戏：
        2.1 触发形式：1. 三个scatter触发，奖励8次
        2.2 免费卷轴中不出现scatter和“龙珠”图标
        2.3 免费游戏和基础游戏的中奖倍数不一样

    3. 免费小游戏
        3.1 免费游戏第5列可以得到freespin+1的奖励
        3.2 免费游戏第5列可以转到multipure奖励

    4. Pick Game 抽卡游戏
        4.1 旋转到“龙珠”图标时触发
        4.2 20张卡牌供抽选
        4.3 抽到对应奖池的卡，对应奖池的进度+1，进度达到后玩家获得该奖池中的奖励

    5. Collect Game 收集游戏
        5.1 收集商店有6条不同的神龙，神龙可升级，最高5级，有3条神龙直接开启，这三条神龙分别对应一个未解锁的新神龙，当神龙达到5级可解锁新的神龙
        5.2 每条神龙有等级和对应的5个道具（道具spin随机获得），道具影响开宝箱的奖励效果
        5.3 用"元宝"开启宝箱提升神龙等级，所有9个宝箱全部开启后，神龙等级提升1级，并重置宝箱
        5.4 宝箱分3个等级，神龙等级1，2，3时解锁，宝箱开启后获得神龙经验和奖励（免费游戏，小游戏，金币）
        5.5 道具效果
            5.5.1 打开箱子获得的奖金翻倍
            5.5.2 抽到的免费游戏免费次数+3
            5.5.3 免费游戏中增加100个WILD（WILD几率提高）
            5.5.4 抽到的小游戏中去掉MINI奖池
            5.5.5 购买宝箱减少200个元宝

    6. Bonus Game 随机小游戏
        6.1 基础游戏spin时有概率触发
        6.2 不和免费游戏以及其他小游戏一起触发
        6.3 触发后再卷轴停止前进行一次随机抽奖，获得一下3种奖励之一
            6.3.1 Random Wilds 在卷轴上随机生成多个wild
            6.3.2 Symbol Exchange 此次spin的不同的龙图标全部变成相同的一个
            6.3.3 Multipler 此次spin的将此乘以一个倍数（2~20倍）
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
local utils = require "cashslots.common.utils"
local baseRecord = require "base.record"
local updateFreeData = freeTool.updateFreeData
local isFreeState = freeTool.isFreeState
local gameData = recordTool.gameData
local record = recordTool.pushLog
local caulBet = cashBaseTool.caulBetandLastBetCoin

local GAME_CFG = {
    gameid = 635,
    line = 50,
    wilds = {1},
    scatter = 11,
    bonus = 12,
    winTrace = config.LINECONF[50][2],
    mults = config.MULTSCONF[888][1],
    RESULT_CFG = config.CARDCONF[635]["base"],

    freeGameConf = {card = 11, min = 3, freeCnt = 8, addMult = 1},  -- 免费游戏配置
    COL_NUM = 5,
    ROW_NUM = 4,
    mustWinFreeCoin = true,
}

local SYMBOL_WILD = 1
local SYMBOL_DRAGON_BALL = 12   --龙珠
local SYMBOL_DRAGONS = {3,4,5,6}  --龙
local SYMBOL_SPIN_FREE = 13     --Free Spin + 1
local SYMBOL_MULTIPLER = 14     --奖励翻倍

local COLLECT_UNLOCK_BET_IDX = 5 --收集游戏解锁的押注等级

--道具定义
local ITEM_2X_PRIZE = 1     -- 开箱2倍奖励
local ITEM_INC_FREE_TIMES = 2   -- 增加3次免费次数
local ITEM_INC_WILD = 3     -- 免费游戏中增加WILD
local ITEM_REMOVE_MINI = 4  -- 移除抽卡游戏中的 MINI JACKPOT
local ITEM_DEC_INGOT = 5    -- 箱子价格减200元宝

local JackPot = {
    Mini = 1,
    Minor = 2,
    Major = 3,
    Maxi = 4,
    Grand = 5,
}

local JACKPOT = config.JACKPOTCONF[GAME_CFG.gameid]
local function getJackpot(deskInfo, type)
    if TEST_RTP then
        return JACKPOT.MULT[type] * deskInfo.totalBet
    else
        return math.round_coin(JACKPOT.MULT[type] * deskInfo.totalBet * (0.95 + math.random()*0.1))
    end
end

-- 免费加倍数权重表
local FREE_ADD_MULTIPLE = {
    [1] = {weight=20, mul=1},
    [2] = {weight=10, mul=2},
    [3] = {weight=2, mul=3},
    [4] = {weight=1, mul=5},
}

--==================Pick Game 抽卡游戏==================
local PICK_AWARD = {
    [1] = {weight=1200, jp=1},
    [2] = {weight=1800, jp=2},
    [3] = {weight=20, jp=3},
    [4] = {weight=5, jp=4},
    [5] = {weight=0, jp=5},
}
local PICK_AWARD_WITHOUT_MINI = {  --移除mini的奖励
    [1] = {weight=0, jp=1},
    [2] = {weight=1500, jp=2},
    [3] = {weight=15, jp=3},
    [4] = {weight=5, jp=4},
    [5] = {weight=0, jp=5},
}
local PICK_JP_COUNT = {3,3,4,4,6}  --需要的卡牌张数：1:mini 2:minor 3:major 4:maxi 5:grand

-- 抽卡数据初始化
local function pick_init(deskInfo)
    if deskInfo.pick == nil then
        deskInfo.pick = {state = 0}
    end
end

-- 创建一次新的抽卡
local function pick_start(deskInfo, basebet, remove_mini)
    deskInfo.pick = {
        state = 1,              -- 开启
        basebet = basebet,      -- 基础押注
        remove_mini = remove_mini,
        progs = {0,0,0,0,0},    --进度
        cards = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}   --0表示未开启 1:mini 2:minor 3:major 4:maxi 5:grand
    }
    local pick_award = PICK_AWARD
    if remove_mini then
        pick_award = PICK_AWARD_WITHOUT_MINI
    end
    local _,award = utils.randByWeight(pick_award)
    local jp = award.jp -- 游戏结果
    local leftcards = {}
    -- 构造结果需要的牌
    for c, cnt in ipairs(PICK_JP_COUNT) do
        if c ~= jp then
            cnt = cnt - 1  -- 保证不会触发
        end
        for i = 1, cnt do
            table.insert(leftcards, c)
        end
    end
    -- 打乱顺序
    leftcards = table.random(leftcards)
    -- 补满牌
    for c = 1, 5 do
        if c ~= jp then
            table.insert(leftcards, c)
        end
    end
    -- 处理mini
    local real_leftcards = {}
    for i, v in ipairs(leftcards) do
        if remove_mini and v == JackPot.Mini then  --mini要移除
            deskInfo.pick.cards[i] = JackPot.Mini  --开出来
        else
            table.insert(real_leftcards, v)
        end
    end

    deskInfo.pick.leftcards = real_leftcards

    return deskInfo.pick
end

-- 是否触发抽卡游戏
local function pick_check(resultCards)
    return table.contain(resultCards, SYMBOL_DRAGON_BALL)
end

-- 重置抽卡数据
local function pick_clear(deskInfo)
    deskInfo.pick = {state = 0}
end

-- 抽取一张卡
local function pick_pick(deskInfo, idx)
    if deskInfo.pick.state ~= 1 then return {spcode=1} end
    if deskInfo.pick.cards[idx] ~= 0 then return {spcode=2} end
    local leftcards = deskInfo.pick.leftcards    -- 剩余的牌
    local card = table.remove(leftcards, 1)
    deskInfo.pick.cards[idx] = card
    deskInfo.pick.progs[card] = deskInfo.pick.progs[card] + 1

    local ret = {}  -- 返回给客户端
    ret.spcode = 0
    ret.idx = idx
    ret.prog = deskInfo.pick.progs[card]
    ret.card = card
    ret.wincoin = 0
    if deskInfo.pick.progs[card] >= PICK_JP_COUNT[card] then  -- 游戏结束
        -- 计算赢得金币
        ret.wincoin = getJackpot(deskInfo, card)
        local ratio = deskInfo.pick.basebet / deskInfo.totalBet
        ret.wincoin = math.round_coin(ret.wincoin * ratio)
        ret.leftcards = leftcards
        -- 重置数据
        pick_clear(deskInfo)
        -- 加金币
        cashBaseTool.caulCoin(deskInfo, ret.wincoin, PDEFINE.ALTERCOINTAG.WIN)
        local result = {
            kind = "bonus",
            desc = "pick card",
        }
        baseRecord.slotsGameLog(deskInfo, 0, ret.wincoin, result, 0)
    end

    return ret
end

--==================Bonus Game 随机小游戏==================
local BONUS_AWARD = {
    [1] = {weight=45, min_cnt=3, max_cnt=6},    -- Random Wilds
    [2] = {weight=30},                          -- Symbol Exchange
    [3] = {weight=25, muls={2,3,3,3,4,4,4,5,5,5,6,6,8,8,9,9,10,12,14,16,20}},   -- Multipler
}

local ALL_POS = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20}

-- 获取随机位置
local function get_random_pos(cnt)
    -- 打乱表
    table.random(ALL_POS)
    -- 取前cnt个位置
    local pos = {}
    for i = 1, cnt do
        table.insert(pos, ALL_POS[i])
    end
    return pos
end

-- 触发小游戏
local function bonus_trigger(deskInfo)
    local bonusProb = 20
    if deskInfo.control and deskInfo.control.bonusControl then
        bonusProb = deskInfo.control.bonusControl.probability * 3
        bonusProb = math.max(5, bonusProb)
        bonusProb = math.min(100, bonusProb)
    end
    if math.random(0, 1000) < bonusProb then    -- 触发小游戏
        local idx, cfg = utils.randByWeight(BONUS_AWARD)
        local ret = {}
        ret.idx = idx
        if idx == 1 then    -- 变WILD
            local cnt = math.random(cfg.min_cnt, cfg.max_cnt)
            ret.pos = get_random_pos(cnt)
            ret.card = SYMBOL_WILD
        elseif idx == 2 then    -- 变成同一种龙
            ret.card = SYMBOL_DRAGONS[math.random(1, #SYMBOL_DRAGONS)]
        elseif idx == 3 then    -- 奖励翻倍
            ret.mul = cfg.muls[math.random(1, #cfg.muls)]
        end
        return ret
    end
    return nil
end
-- 小游戏换牌
local function bonus_change_cards(bonus, cards)
    if bonus.idx == 1 then
        for _, p in ipairs(bonus.pos) do
            cards[p] = SYMBOL_WILD
        end
    elseif bonus.idx == 2 then
        for i, c in ipairs(cards) do
            if table.contain(SYMBOL_DRAGONS, c) then
                cards[i] = bonus.card
            end
        end
    end
    return cards
end

--==================Collect Game 收集元宝游戏==================
-- 箱子价格
local CHEST_PRICE = {
    [1] = {1800,2000,3000,2000,2200,3000,2500,2500,3000,3000,3000,3000,3200,3200,3600}, -- 绿龙
    [2] = {1800,2000,3000,2000,2200,3000,2500,2500,3000,3000,3000,3000,3200,3200,3600}, -- 蓝龙
    [3] = {2000,2400,3300,2000,2400,3300,3000,3000,3300,3300,3300,3300,4000,4000,4000}, -- 紫龙
    [4] = {2000,2400,3300,2000,2400,3300,3000,3000,3300,3300,3300,3300,4000,4000,4000}, -- 粉龙
    [5] = {2000,2500,3800,2500,2700,3800,3300,3300,3800,3800,3800,3800,4500,4500,4500}, -- 红龙
    [6] = {2000,2500,3800,2500,2700,3800,3300,3300,3800,3800,3800,3800,4500,4500,4500}, -- 金龙
}
-- 箱子奖励
local CHEST_AWARD = {
    [1] = {weight=70},      -- 金币
    [2] = {weight=15, cnt=8},  -- 免费游戏
    [3] = {weight=15},      -- pick小游戏
}
-- 箱子金币奖励
local CHEST_AWARD_COIN = {
    [1] = {mul=1,  weight=100},
    [2] = {mul=2,  weight=50},
    [3] = {mul=3,  weight=20},
    [4] = {mul=4,  weight=10},
    [5] = {mul=5,  weight=5},
    [6] = {mul=8,  weight=4},
    [7] = {mul=10, weight=3},
    [8] = {mul=20, weight=1},
}

-- 道具产出概率
local COLLECT_ITEM_DROP_RATIO = 0.008

local function collect_get_needbet(deskInfo)
    return deskInfo.needbet or COLLECT_UNLOCK_BET_IDX
end

-- 获取元宝 (期望: 0.3*30 + 0.15*80 + 0.05*130 = 27.5)
local function collect_get_ingot()
    local r = math.random()
    if r <= 0.5 then
        return 0
    elseif r <= 0.8 then
        return math.random(1, 5)
    elseif r <= 0.95 then
        return math.random(6, 10)
    else
        return math.random(11, 15)
    end
    return 0
end
-- 获取价格
local function collect_get_price(dragonIdx, dragonLv, chestIdx)
    local row = math.ceil(chestIdx/3)
    local idx = (dragonLv-1)*3 + row
    return CHEST_PRICE[dragonIdx][idx]
end
-- 创建宝箱
local function collect_create_chest(dragonIdx, chestIdx)
    local chest = {}
    chest.tp = 0    --0:未开启 1:金币 2:免费游戏 3:pick小游戏
    chest.coin = 0  --赢得的金币
    chest.price = collect_get_price(dragonIdx, 1, chestIdx)
    return chest
end
-- 创建龙
local function collect_create_dragon(idx)
    local dragon = {}
    dragon.lv = 1           -- 等级
    dragon.lock = 0         -- 锁定
    if idx > 3 then
        dragon.lock = 1
    end
    dragon.items = {}       -- 道具
    dragon.chests = {}       -- 宝箱
    for i = 1, 9 do
        local chest = collect_create_chest(idx, i)
        table.insert(dragon.chests, chest)
    end
    return dragon
end
-- 能否解锁龙
local function dragon_can_unlock(deskInfo, idx)
    for i=1, idx-1 do
        if deskInfo.collect.dragons[i].lv < 5 then  -- 前面的龙都达到5级
            return false
        end
    end
    return true
end
-- 收集游戏初始化
local function collect_init(deskInfo)
    if deskInfo.collect == nil then
        deskInfo.collect = {
            basebet = 0,    -- 基础押注额
            num = 0,    --元宝数量
            didx = 1,   -- 当前选择的龙
            inc_wild = false,
            in_free = false,
        }
        deskInfo.collect.dragons = {}
        for i=1,6 do -- 6条龙
            local dragon = collect_create_dragon(i)
            table.insert(deskInfo.collect.dragons, dragon)
        end
    end
    deskInfo.collect.unlockidx =  collect_get_needbet(deskInfo)
end
-- 道具掉落
local function collect_drop_item(deskInfo)
    local didx = deskInfo.collect.didx
    local dragon = deskInfo.collect.dragons[didx]
    local leftitems = {}
    for id = 1, 5 do
        if not table.contain(dragon.items, id) then
            table.insert(leftitems, id)
            break
        end
    end
    if #leftitems > 0 then
        local itemid = leftitems[math.random(1,#leftitems)]
        table.insert(dragon.items, itemid)
        return {id=itemid, didx=didx}
    end
end
-- 箱子产出金币数量
local function collect_get_chest_coin(deskInfo)
    local idx, cfg = utils.randByWeight(CHEST_AWARD_COIN)
    local wincoin = cfg.mul * deskInfo.collect.basebet
    return math.floor(wincoin)
end
-- 箱子是否被锁定
local function collect_chest_locked(dragonLv, cidx)
    if dragonLv>=4 then return false end
    if dragonLv>=2 then return cidx>6 end
    return cidx>3
end
-- 是否拥有道具
local function collect_dragon_has_item(dragon, itemid)
    if (dragon) then return table.contain(dragon.items, itemid) end
    return false
end
-- 是否拥有道具
local function collect_has_item(deskInfo, didx, itemid)
    return collect_dragon_has_item(deskInfo.collect.dragons[didx], itemid)
end

-- 购买宝箱
local function collect_buy_chest(deskInfo, didx, cidx)
    local dragon = deskInfo.collect.dragons[didx]
    if not dragon then
        return {spcode=1}   -- 龙不存在
    end
    if dragon.lock == 1 then
        return {spcode=2}   -- 龙未解锁
    end
    local chest = dragon.chests[cidx]
    if not chest or chest.tp ~= 0 then
        return {spcode=2}   -- 宝箱不存在或已打开
    end
    if collect_chest_locked(dragon.lv, cidx) then
        return {spcode=4}  -- 箱子未解锁
    end

    local ret = {spcode=0, didx=didx, cidx=cidx}
    local price = chest.price
    if collect_dragon_has_item(dragon, ITEM_DEC_INGOT) then  -- 道具：价格-200
        price = chest.price - 200
        ret.dec_ingot = true
    end
    if deskInfo.collect.num < price then
        return {spcode=3}   -- 元宝不够
    end

    local idx, cfg = utils.randByWeight(CHEST_AWARD)
    chest.tp = idx
    if chest.tp == 1 then       --金币
        chest.coin = collect_get_chest_coin(deskInfo)
        if collect_dragon_has_item(dragon, ITEM_2X_PRIZE) then  -- 道具：奖金翻倍
            chest.coin = chest.coin * 2
            ret.prize_x2 = true
        end
        -- 玩家加金币
        cashBaseTool.caulCoin(deskInfo, chest.coin, PDEFINE.ALTERCOINTAG.WIN)
        local result = {
            kind = "bonus",
            desc = "coin box",
        }
        baseRecord.slotsGameLog(deskInfo, 0, chest.coin, result, 0)
    elseif chest.tp == 2 then   --免费
        local freeCnt = 8
        if collect_dragon_has_item(dragon, ITEM_INC_FREE_TIMES) then
            freeCnt = freeCnt + 3
        end
        deskInfo.collect.in_free = true
        deskInfo.collect.inc_wild = false
        if collect_has_item(deskInfo, deskInfo.collect.didx, ITEM_INC_WILD) then  --道具，增加wild
            deskInfo.collect.inc_wild = true
        end
        ret.free = {cnt=freeCnt, inc_wild=deskInfo.collect.inc_wild}
        updateFreeData(deskInfo, 1, freeCnt, 1, 0)
    elseif chest.tp == 3 then   --抽卡
        local remove_mini = collect_dragon_has_item(dragon, ITEM_REMOVE_MINI)   -- 道具：移除mini
        ret.pick = pick_start(deskInfo, deskInfo.collect.basebet, remove_mini)
    end

    deskInfo.collect.num = deskInfo.collect.num - price
    ret.num = deskInfo.collect.num
    ret.chest = {tp=chest.tp, coin=chest.coin}

    --所有未锁定宝箱开启后，重置宝箱，并将神龙等级提升1级
    local opened_chest = 0
    for _, cst in ipairs(dragon.chests) do
        if cst.tp ~= 0 then     -- 有一个未开启
            opened_chest = opened_chest + 1
        end
    end
    local reset = false
    if (dragon.lv >= 4) then  --4级解锁9个箱子
        reset = (opened_chest>=9)
    elseif (dragon.lv >= 2) then  --2级解锁6个箱子
        reset = (opened_chest>=6)
    else
        reset = (opened_chest>=3)
    end
    local unlock_didx = 0
    if reset then
        if dragon.lv < 5 then   -- 神龙升级
            dragon.lv = dragon.lv + 1
            if dragon.lv >= 5 then  -- 能否解锁新的龙
                for next_didx = 4, 6 do
                    if deskInfo.collect.dragons[next_didx].lock ~= 0 and dragon_can_unlock(deskInfo, next_didx) then
                        deskInfo.collect.dragons[next_didx].lock = 0    -- 解锁
                        unlock_didx = next_didx
                        break
                    end
                end
            end
        else
            dragon.items = {}   --道具重置
        end
        for i, cst in ipairs(dragon.chests) do
            -- 宝箱重置
            cst.tp = 0
            cst.coin = 0
            cst.price = collect_get_price(didx, dragon.lv, i)
        end
        ret.items = dragon.items
        ret.chests = dragon.chests
    end

    ret.lv = dragon.lv
    ret.reset = reset
    ret.unlock_didx = unlock_didx

    return ret
end
-- 增加免费游戏次数
local function free_add_cnt(deskInfo, cnt)
	deskInfo.freeGameData.allFreeCount = deskInfo.freeGameData.allFreeCount + cnt
	deskInfo.freeGameData.restFreeCount = deskInfo.freeGameData.restFreeCount + cnt
end
-- 增加免费游戏倍率
local function free_add_mul(deskInfo)
    -- 1 -> 2 -> 3 -> 5 -> 10
    local mult = deskInfo.freeGameData.addMult
    if mult <= 1 then
        mult = 2
    elseif mult <= 2 then
        mult = 3
    elseif mult <= 3 then
        mult = 5
    else
        mult = 10
    end
    deskInfo.freeGameData.addMult = mult
end


--================正常游戏逻辑=================
local function getLine()
    return GAME_CFG.line
end

local function getInitMult()
    return GAME_CFG.defaultInitMult
end

local function create(deskInfo, uid)
    -- 抽卡游戏
    pick_init(deskInfo)
    -- 收集元宝游戏
    collect_init(deskInfo)
end

--取正常的牌
local function getCards(deskInfo)
    return cardProcessor.get_cards_2(deskInfo, GAME_CFG)
end

local function getBigGameResult(deskInfo, resultCards, GAME_CFG)
    if isFreeState(deskInfo) then
        GAME_CFG.RESULT_CFG = config.CARDCONF[635]["free"]
    else
        GAME_CFG.RESULT_CFG = config.CARDCONF[635]["base"]
    end
    return settleTool.getBigGameResult(deskInfo, resultCards, GAME_CFG)
end

local function checkSubGame(deskInfo, GAME_CFG, cards)
    return pick_check(cards)
end

local function initResultCards(deskInfo)
    if isFreeState(deskInfo) and deskInfo.collect.in_free then
        local cardmap = cardProcessor.getCardMap(deskInfo, "collectmap")
        return cardProcessor.get_cards_1(cardmap, GAME_CFG.COL_NUM, GAME_CFG.ROW_NUM)
    else
        local funcList = {
            getResultCards = getCards,
            checkSubGame = checkSubGame,
            getBigGameResult = getBigGameResult,
        }
        return cardProcessor.get_cards_3(deskInfo, GAME_CFG, funcList)
    end
end

local function start_635(deskInfo)
    local result = {}

    --免费的卷轴中没有Scatter和Dragon Ball图标
    if isFreeState(deskInfo) then
        deskInfo.control.freeControl.probability = 0
        deskInfo.control.bonusControl.probability = 0
    end

    --发牌
    result.resultCards = initResultCards(deskInfo)
    local caulCards = table.copy(result.resultCards)

    --检测是否触发免费
    result.freeResult = freeTool.checkFreeGame(caulCards, GAME_CFG.freeGameConf)
    if not table.empty(result.freeResult) then  -- 普通触发的免费关闭增加wild功能
        deskInfo.collect.in_free = false
        deskInfo.collect.inc_wild = false
    end
    local isFreeState = isFreeState(deskInfo)
    -- 是否触发free+1或multipler
    local free = nil
    if isFreeState then
        if deskInfo.collect.inc_wild then  --增加wild
            local cnt = math.random(3,4)
            local wildCnt = table.count(caulCards, SYMBOL_WILD)
            cnt = cnt - wildCnt
            for _ = 1, cnt do
                local idx = math.random(1, #caulCards)
                caulCards[idx] = SYMBOL_WILD
            end
        end
        if table.contain(caulCards, SYMBOL_SPIN_FREE) then
            free = {}
            free_add_cnt(deskInfo, 1)
            free.total_cnt = deskInfo.freeGameData.allFreeCount
        end
        if table.contain(caulCards, SYMBOL_MULTIPLER) then
            free = free or {}
            free_add_mul(deskInfo)
            free.total_mul = deskInfo.freeGameData.addMult
        end
    end

    -- 是否触发抽卡游戏
    local pick = nil
    if not isFreeState and table.empty(result.freeResult) then
        if pick_check(caulCards) then
            --local remove_mini = collect_has_item(deskInfo, deskInfo.collect.didx, ITEM_REMOVE_MINI)  -- 道具，移除mini
            local remove_mini = false  -- 外面不触发道具功能
            pick = pick_start(deskInfo, deskInfo.totalBet, remove_mini)
        end
    end

    -- 触发随机小游戏
    local bonus = nil
    if not isFreeState and table.empty(result.freeResult) and not pick then
        bonus = bonus_trigger(deskInfo)
        if bonus then
            caulCards = bonus_change_cards(bonus, caulCards)
        end
    end
    -- 随机小游戏变换后的牌
    -- result.caulCards = caulCards
    result.resultCards = caulCards

    --计算结果
    result.winCoin, result.zjLuXian, result.scatterResult, result.bonusResult = getBigGameResult(deskInfo, caulCards, GAME_CFG)
    if bonus and bonus.idx == 3 then  -- 获得奖励翻倍
        result.winCoin = result.winCoin * bonus.mul
    end
    if isFreeState and deskInfo.collect.in_free then
        local ratio = deskInfo.collect.basebet / deskInfo.totalBet
        for _, rs in pairs(result.zjLuXian) do
            rs.coin = math.round_coin(rs.coin * ratio)
        end
        result.winCoin = math.round_coin(result.winCoin * ratio)

        -- 重置收集免费
        if deskInfo.freeGameData.restFreeCount <= 0 then
            deskInfo.collect.in_free = false
            deskInfo.collect.inc_wild = false
        end
    end

    -- 元宝收集
    local collect = nil
    local item = nil
    if not free and not pick and not bonus and deskInfo.currmult >= collect_get_needbet(deskInfo) then
        -- 产出元宝
        local ingot = collect_get_ingot()
        if ingot > 0 then
            local num = ingot*10
            local total_num = deskInfo.collect.num
            local basebet = deskInfo.collect.basebet
            deskInfo.collect.basebet = (total_num*basebet + num*deskInfo.totalBet)/(total_num+num)
            deskInfo.collect.num = deskInfo.collect.num + num

            collect = {}
            collect.num = deskInfo.collect.num
            collect.pos = get_random_pos(ingot)
        end
        -- 产出道具
        if math.random() < COLLECT_ITEM_DROP_RATIO then
            item = collect_drop_item(deskInfo)
        end
    end

    -- 生成结果
    local retobj = cashBaseTool.genRetobjProto(deskInfo, result)
    retobj.bonus = bonus        -- 随机小游戏数据
    retobj.pick = pick          -- 抽卡游戏数据
    retobj.collect = collect    -- 元宝收集数据
    retobj.item = item          -- 道具掉落数据
    retobj.spFree = free        -- 免费特殊玩法

    return retobj
end

local function start(deskInfo) --正常游戏
    local betCoin = caulBet(deskInfo)
    local retobj = start_635(deskInfo)

    cashBaseTool.settle(deskInfo, betCoin, retobj)
    return retobj
end

local function addSpecicalDeskInfo(deskInfo, simpleDeskData)
    -- 抽卡数据
    simpleDeskData.pick = table.copy(deskInfo.pick)
    simpleDeskData.pick.leftcards = nil  -- 屏蔽剩余牌
    -- 收集数据
    simpleDeskData.collect = deskInfo.collect
    return simpleDeskData
end

local function gameLogicCmd(deskInfo, recvobj)
    local retobj = {}
    local rtype = recvobj.rtype
    if rtype == 1 then  -- 抽卡
        retobj = pick_pick(deskInfo, recvobj.idx)
    elseif rtype == 2 then  -- 元宝买宝箱
        retobj = collect_buy_chest(deskInfo, recvobj.didx, recvobj.cidx)
    elseif rtype == 3 then  -- 选择神龙
        if recvobj.didx >=1 and recvobj.didx<=6 then
            deskInfo.collect.didx = recvobj.didx
            retobj = {didx=recvobj.didx}
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
deskInfo.pick = {
    "state":1  --0关闭 1开启
    "remove_mini":true  -- 移除mini
    "progs":{1,1,1,1,1} -- 进度
    "cards":{1,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0} --0表示未开启 1:mini 2:minor 3:major 4:grand 5:maxi
}
deskInfo.collect = {
    "num":0,    --元宝数量
    "didx":1,   -- 当前选择的龙
    "unlockidx":3,
    "dragons":{
        [1] = {
            "lv":1,
            "lock":0,
            "items":{1,2,3}
            "chests":{
                [1] = {
                    "tp":1,
                    "coin":500000,
                    "price":3000
                },
                [2] = {...},
                ...,
                [9] = {...}
            } 
        },
        [2] = {...},
        ...,
        [6] = {...}
    }
}

44中新增返回
0. 随机小游戏
    "bonus":{
        "idx":1,  -- 1:Random Wilds 2:Symbol Exchange 3:Multipler
        "pos":{1, 2, 3, 4},  -- 随机wilds/符号变换 的位置
        "card":4,        -- 变换的符号ID
        "mul":3,    -- 奖励倍数
    }

1.元宝收集数据(免费游戏状态不下发)
    "collect":{
        "num":100,   --当前元宝个数
        "pos":{1, 2}  -- 元宝位置
    }

2.触发抽卡游戏
    "pick":{
        state:1  --0关闭 1开启
        "progs":{0,0,0,0,0} -- 进度
        "cards":{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0} --0表示未开启 1:mini 2:minor 3:major 4:maxi 5:grand
    }

3.道具掉落
    "item":{
        id: 1,  --道具id
        didx:1, --龙索引
    }

4.免费特殊玩法
    "spfree":{
        "total_cnt": 1  --当前总次数
        "total_mul": 2  --当前倍数
    }


--2：51 
2.1 抽卡小游戏
    c : {c: 51, uid:*, gameid:*, data:{rtype:1， idx:1}} --idx:位置索引 1~20
    返回数据格式：
    {
        "data":{
            "rtype":1,
            "idx":1,        -- 位置索引
            "prog":2        -- 进度
            "card":1,        -- 牌
            "wincoin":1000,    --赢分 wincoin大于0表示游戏结束
        },
        "uid":102176,"c":51,"code":200
    }

2.2 收集商店购买宝箱
    c : {c: 51, uid:*, gameid:*, data:{rtype:2, didx:1, cidx:1}}  --idx:宝箱索引
    返回数据格式：
    {"data":{
        "rtype":2,
        "didx":1, --上行的didx
        "cidx":1, --上行的cidx
        "spcode":0
        "num": 5720,-- 当前元宝数量
        "lv": 2, -- 龙等级
        "reset":true, -- 是否重置宝箱
        "unlock_didx":3,-- 解锁的龙
        "chest":{ --选择位置对应的结果
            "tp":1,    --1:金币 2:免费游戏 3:pick小游戏
            "coin":10000, --赢得金币
        },
        "chests":{}, -- 新的箱子列表（如果重置）
        "pick":{} -- 触发抽卡的数据
        "free":{} -- 触发免费的数据
        "dec_ingot":true  --减元宝
        "prize_x2":true   --奖励翻倍
    },
    "uid":102201,"c":51,"code":200}

3.3 选择龙
    c : {c: 51, uid:*, gameid:*, data:{rtype:3, didx:11}}  --didx:龙索引
    返回数据格式：
    {
        "data":{
            "rtype":3,
            "didx":1,        -- 位置索引
        },
        "uid":102176,"c":51,"code":200
    }
]]

