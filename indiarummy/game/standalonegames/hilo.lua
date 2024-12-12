--[[
    Hilo
    1. 从牌堆中随机抽取一张牌，玩家猜测下一张牌的大小，>= 或 <=
    2. 玩家下注，下注范围[1, 1000]
    3. 可以中途退出，获得奖金
    4. 退出时，如果玩家的下注金额大于0，系统会自动结算
    5. 如果输了，则奖金清零
]]



local config = {
    minbet = 1,  -- 最小下注
    maxbet = 1000,  -- 最大下注
}

local AllCards = {
    0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,
    0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,
    0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,
    0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,
}

-- 牌值对应的奖金赔率列表，奖金赔率列表左边是小于等于，右边是大于等于
local winMult = {
    [2] = {12.61, 1.05},    -- 2
    [3] = {6.3, 1.05},    -- 3
    [4] = {4.2, 1.14},    -- 4
    [5] = {3.15, 1.26},    -- 5
    [6] = {2.52, 1.4},    -- 6
    [7] = {2.1, 1.57},    -- 7
    [8] = {1.8, 1.8},    -- 8
    [9] = {1.57, 2.1},    -- 9
    [10] = {1.4, 2.52},    -- 10
    [11] = {1.26, 3.15},    -- J
    [12] = {1.14, 4.2},    -- Q
    [13] = {1.05, 6.3},    -- K
    [14] = {1.05, 12.61},    -- A
}

-- 获取牌值
local function scanValue(card)
    return card & 0x0f
end

-- 判断是否是A
local function isAce(card)
    return scanValue(card) == 0x0E
end

-- 判断是否是2
local function isTwo(card)
    return scanValue(card) == 0x02
end

local gamelogic = {}

-- 向下取整，保留两位小数点
local function floor(num)
    return math.floor(num * 100) / 100
end

-- 从牌堆中取出一张牌，并且算出赔率
-- 向下取整
local function getCurrMult(mult, card)
    local mults = winMult[scanValue(card)]
    return {floor(mults[1]*mult), floor(mults[2]*mult)}
end

-- 判断两张牌的结果
---@param targetCard number @目标牌
---@param selfCard number @自己的牌
---@param choose number @选择的按钮，0是小，1是大
local function compareCards(targetCard, selfCard, choose)
    if isAce(selfCard) then
        if choose == 0 and not isAce(targetCard) then
            return true
        elseif choose == 1 and isAce(targetCard) then
            return true
        else
            return false
        end
    elseif isTwo(selfCard) then
        if choose == 0 and isTwo(targetCard) then
            return true
        elseif choose == 1 and not isTwo(targetCard) then
            return true
        else
            return false
        end
    else
        -- 两张牌都不是A和2
        -- 目标牌小于自己的牌，选择小，返回true
        -- 目标牌大于自己的牌，选择大，返回true
        if choose == 0 and scanValue(selfCard) >= scanValue(targetCard) then
            return true
        elseif choose == 1 and scanValue(selfCard) <= scanValue(targetCard) then
            return true
        else
            return false
        end
    end
end

-- 初始化牌堆
local function initRoundInfo(user, delegate)
    -- 已经开始的局不能再随机牌堆
    if user.round and user.round.isStart == 1 and user.round.isEnd == 0 then
        return
    end
    local curCard = user.round and user.round.curCard or nil
    ---@class HiloRoundInfo
    local roundInfo = {
        bettime = nil,
        betcoin = nil,
        hisCards = {},  ---@type table<number, number>[] @前一个数代表牌值，后一个代表选择的按钮，0是小，1是大
        curCard = nil,  -- 当前牌
        curMult = {0, 0},  -- 当前牌的赔率
        wincoin = 0,
        winMult = 0,
        isStart = 0,  -- 是否开始
        isEnd = 0,  -- 是否结束
    }
    -- 如果是结束之后随机，则当前牌值不会变
    if curCard then
        roundInfo.curCard = curCard
    else
        roundInfo.curCard = AllCards[math.random(1, #AllCards)]
    end
    user.round = roundInfo
    delegate.redisSet(user.uid, roundInfo)
end

function gamelogic.create(gameid)

end

---@param delegate StandaloneAgentDelegate
function gamelogic.initDeskInfo(deskInfo, delegate)
    deskInfo.config = config
    deskInfo.records = {}
    local user = deskInfo.user
    -- 从redis中获取当局信息
    local roundInfo = delegate.redisGet(user.uid)
    if roundInfo then
        user.round = roundInfo
        deskInfo.issue = user.round.issue
    else
        -- 如果没有局信息，则随机牌堆
        initRoundInfo(user, delegate)
    end
end

function gamelogic.getResult()
    -- 从牌堆中随机出一个牌
    return AllCards[math.random(1, #AllCards)]
end

function gamelogic.tryGetRestrictiveResult()
end

---@param delegate StandaloneAgentDelegate
function gamelogic.start(deskInfo, msg, delegate)
    local ret = {
        c = msg.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        betcoin = msg.betcoin,
    }
    local betcoin = tonumber(msg.betcoin) or 0
    local user = deskInfo.user
    if user.round and user.round.isStart == 1 then  -- 如果上一轮还没有完成，则不能开始新的一轮
        ret.spcode = PDEFINE.RET.ERROR.GAME_ING_ERROR
        return ret
    end
    -- 这里理应会有round，没有就是bug了
    if not user.round then
        ret.spcode = PDEFINE.RET.ERROR.GAME_NOT_OPEN
        return ret
    end
    if user.coin < betcoin then
        ret.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        return ret
    end
    if not delegate.changeCoin(user, PDEFINE.ALTERCOINTAG.BET, -betcoin, deskInfo) then
        LOG_INFO("user change coin fail", msg.uid, -betcoin)
        ret.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        return ret
    end
    user.round.issue = deskInfo.issue
    user.round.bettime = os.time()
    user.round.betcoin = betcoin
    user.round.isStart = 1
    -- 计算当前倍率
    user.round.curMult = winMult[scanValue(user.round.curCard)]
    -- 返回前端当局信息
    ret.round = gamelogic.getRoundInfo(user.round)
    -- 返回当前金币
    ret.coin = user.coin
    -- 存放到redis中，等待客户端选择
    delegate.redisSet(user.uid, user.round)
    return ret
end

-- 额外操作
-- rtype 1 随机牌堆
-- rtype 2 选择大小
-- rtype 3 选择收回金币
function gamelogic.gameLogicCmd(deskInfo, msg, delegate)
    local ret = {
        c = msg.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        rtype = msg.rtype,
    }
    local user = deskInfo.user
    if msg.rtype == 1 then  -- 随机牌堆
        if user.round and user.round.isStart == 0 then
            initRoundInfo(user, delegate)
        else
            ret.spcode = PDEFINE.RET.ERROR.GAME_ING_ERROR
            return ret
        end
        ret.round = gamelogic.getRoundInfo(user.round)
    elseif msg.rtype == 2 then  -- 随机大小
        if not user.round or user.round.isStart == 0 then
            ret.spcode = PDEFINE.RET.ERROR.GAME_NOT_OPEN
            return ret
        end
        ret.choose = msg.choose -- 0是小，1是大
        if ret.choose ~= 0 and ret.choose ~= 1 then
            ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
            return ret
        end
        local isWin = false
        local nextCard
        local restriction = delegate.getRestriction()  --0：随机 -1：输 1：赢
        if restriction == 0 or restriction == 1 then
            nextCard = gamelogic.getResult()
            isWin = compareCards(nextCard, user.round.curCard, ret.choose)
        elseif restriction == -1 then
            local retryCnt = 1000
            nextCard = gamelogic.getResult()
            while retryCnt > 0 do
                isWin = compareCards(nextCard, user.round.curCard, ret.choose)
                if not isWin then
                    break
                end
                if retryCnt == 0 then
                    break
                end
                nextCard = gamelogic.getResult()
                retryCnt = retryCnt - 1
            end
        end
        ret.card = nextCard
        user.round.lastCard = nextCard
        table.insert(user.round.hisCards, {user.round.curCard, ret.choose})
        if isWin then
            -- 增加赢取的金币
            user.round.winMult = user.round.curMult[ret.choose+1]
            user.round.wincoin = math.round_coin(user.round.betcoin * user.round.winMult)
            -- 如果赢了，则将当前牌替换为下一张牌
            user.round.curCard = nextCard
            -- 计算当前倍率
            user.round.curMult = getCurrMult(user.round.winMult, nextCard)
            ret.round = gamelogic.getRoundInfo(user.round)
            -- 存放到redis中，等待客户端选择
            delegate.redisSet(user.uid, user.round)
        else
            -- 如果输了，则结算
            user.round.isEnd = 1
            gamelogic.settleCoin(deskInfo, user, delegate)
            ret.round = gamelogic.getRoundInfo(user.round)
            ret.coin = user.coin
            initRoundInfo(user, delegate)
        end
    elseif msg.rtype == 3 then  -- 选择收回金币
        if not user.round or user.round.isStart == 0 then
            ret.spcode = PDEFINE.RET.ERROR.GAME_NOT_OPEN
            return ret
        end
        -- 如果当前局还没有选择，则不能收回金币
        if #user.round.hisCards == 0 then
            ret.spcode = PDEFINE.RET.ERROR.GAME_ING_ERROR
            return ret
        end
        local wincoin = user.round.betcoin * user.round.winMult
        user.round.wincoin = wincoin
        user.round.isEnd = 1
        gamelogic.settleCoin(deskInfo, user, delegate)
        ret.coin = user.coin
        ret.round = gamelogic.getRoundInfo(user.round)
        initRoundInfo(user, delegate)
    else
        ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
    end
    return ret
end

---@param delegate StandaloneAgentDelegate
function gamelogic.settleCoin(deskInfo, user, delegate)
    local tax = 0
    local wincoin = 0
    user.round.isEnd = 1
    if user.round.wincoin > 0 then
        tax = delegate.calcTax(user.round.betcoin, user.round.wincoin)
        wincoin = user.round.wincoin - tax
        user.round.wincoin = wincoin
        delegate.changeCoin(user, PDEFINE.ALTERCOINTAG.WIN, wincoin, deskInfo)
        if wincoin > user.round.betcoin then
            delegate.notifyLobby(user, wincoin - user.round.betcoin)
        end
    end
    --记录结果
    local settle = {card=user.round.lastCard, result=user.round.lastCard==user.round.curCard and 1 or 0}
    delegate.recordGameLog(deskInfo, user.round.betcoin, wincoin, settle, tax)
    --更新策略数据
    if user.cluster_info and user.istest ~= 1 then
        delegate.updateStrategyData(user.round.betcoin, wincoin)
    end
    --游戏记录
    table.insert(deskInfo.records, user.round)
    if #(deskInfo.records) > 100 then
        table.remove(deskInfo.records, 1)
    end
    return
end

-- 获取当局信息
function gamelogic.getRoundInfo(roundInfo)
    local ret = table.copy(roundInfo)
    return ret
end

-- 返回桌子信息前进行过滤
function gamelogic.filterDeskInfo(deskInfo)
    if deskInfo.user and deskInfo.user.round then
        deskInfo.user.round = gamelogic.getRoundInfo(deskInfo.user.round)
    end
end

return gamelogic

--[[
--下注范围
    [1, 1000]

-- 配置信息
config = {
    minbet = 1,  -- 最小下注
    maxbet = 1000,  -- 最大下注
}

--桌子信息
--deskInfo增加字段
    {
        records = {
            同round的结构
        },   --游戏记录
    }

--交互协议
    --玩家押注(C->S)
    {
        c = 44,
        betcoin = 10,   -- 押注金额
    }
    --返回
    {
        c = 44,
        spcode = 0,     --错误码，0表示正常
        round = {
            bettime = os.time(),  -- 下注时间
            betcoin = betcoin,  -- 下注金额
            hisCards = {{0x12, 0}, },  -- 选择历史 前一个数代表牌值，后一个代表选择的按钮，0是小，curCard = nil,  -- 当前牌
            curCard = 0x12,  -- 当前牌
            curMult = {0, 0},  -- 当前牌的赔率
            wincoin = 0,
            winMult = 0,
            isStart = 0,  -- 是否开始
            isEnd = 0,  -- 是否结束
        }
    }
    -- 玩家选择
    {
        c = 51,
        rtype = 1,  -- 1:随机牌堆, 2:选择大小 3:选择收回金币
        choose = 1,  -- 选择大小 0:小 1:大
    }
    -- 返回
    {
        c = 51,
        spcode = 0,     --错误码，0表示正常
        round = {
            bettime = os.time(),  -- 下注时间
            betcoin = betcoin,  -- 下注金额
            hisCards = {{0x12, 0}, },  -- 选择历史 前一个数代表牌值，后一个代表选择的按钮，0是小，curCard = nil,  -- 当前牌
            curCard = 0x12,  -- 当前牌
            curMult = {0, 0},  -- 当前牌的赔率
            wincoin = 0,
            winMult = 0,
            isStart = 0,  -- 是否开始
            isEnd = 0,  -- 是否结束
        }
    }
]]