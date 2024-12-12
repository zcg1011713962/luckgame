--[[
    Towers
    玩家首先选择一个难度，难度越高，回报越高
    然后点击开始游戏下注，并开始爬塔
    每层塔玩家点开一个格子，如果格子是√，玩家提升一层塔，相应的奖励倍数增加
    如果格子是×，玩家失败，没有奖励
    玩家中途可以随时cash out，获得当前倍数的奖励；如果到达塔顶，自动cash out
    cash out后，显示所有格子里的内容
    如果还没有开始开格子，玩家可以取消下注
]]

---@class TowersRoundInfo
---@field public difficulty number @难度
---@field public bettime number @开始时间
---@field public betcoin number @当前下注额
---@field public result number[] @此轮结果
---@field public chooseIdxs number[] @每层选择的格子
---@field public issue string @期号

--难度定义
local Difficulty = {
    Easy = 1,
    Medium= 2,
    Hard = 3,
    Extreme = 4,
    Nightmare = 5,
}

local config = {
    minbet = 1,
    maxbet = 1000,
    options = {
        [1] = {
            difficulty = Difficulty.Easy,   --难度
            floors = 9,     --层数
            blocks = 4,     --格子数
            safes = 3,      --安全区数
            mults = {1.26, 1.68, 2.25, 3.01, 4.01, 5.33, 7.11, 9.48, 12.67},    --赔率
        },
        [2] = {
            difficulty = Difficulty.Medium,
            floors = 9,
            blocks = 3,
            safes = 2,
            mults = {1.42, 2.14, 3.2, 4.81, 7.21, 10.8, 16.22, 24.36, 36.5},
        },
        [3] = {
            difficulty = Difficulty.Hard,
            floors = 9,
            blocks = 2,
            safes = 1,
            mults = {1.9, 3.8, 7.59, 15.19, 30.26, 60.69, 121.91, 242.37, 484.44},
        },
        [4] = {
            difficulty = Difficulty.Extreme,
            floors = 6,
            blocks = 3,
            safes = 1,
            mults = {2.85, 8.55, 25.63, 77.01, 229.3, 684.34},
        },
        [5] = {
            difficulty = Difficulty.Nightmare,
            floors = 6,
            blocks = 4,
            safes = 1,
            mults = {3.8, 15.15, 60.51, 242.01, 970.52, 3840.21},
        },
    }
}

local gamelogic = {}

function gamelogic.create(gameid)
end

function gamelogic.initDeskInfo(deskInfo, delegate)
    deskInfo.config = config
    deskInfo.records = {}
    local user = deskInfo.user
    ---@type TowersRoundInfo
    user.round = delegate.redisGet(user.uid)
    if user.round and user.round.issue then
        deskInfo.issue = user.round.issue
    end
end

function gamelogic.filterDeskInfo(deskInfo)
    if deskInfo.user.round then
        deskInfo.user.round.result = nil
    end
end

function gamelogic.getResult(difficulty)
    local option = config.options[difficulty]
    local result = {}
    for i = 1, option.floors do
        local floor = {}
        for j = 1, option.blocks do
            if j <= option.safes then
                table.insert(floor, 1)  --1表示安全
            else
                table.insert(floor, 0)  --0表示不安全
            end
        end
        table.shuffle(floor)
        table.insert(result, floor)
    end
    return result
end

function gamelogic.tryGetRestrictiveResult()
end

---@param deskInfo any
---@param msg any
---@param delegate StandaloneAgentDelegate
function gamelogic.start(deskInfo, msg, delegate)   --开始游戏
    local ret = {c=msg.c, code=PDEFINE.RET.SUCCESS, spcode=0, betcoin=msg.betcoin}
    local betcoin = tonumber(msg.betcoin) or 0
    local difficulty = tonumber(msg.difficulty) or 0
    local user = deskInfo.user
    if user.round then  -- 如果上一轮还没有完成，则不能开始新的一轮
        ret.spcode = PDEFINE.RET.ERROR.GAME_ING_ERROR
        return ret
    end
    if (betcoin < config.minbet) or (not config.options[difficulty]) then
        LOG_DEBUG("params error", betcoin, difficulty)
        ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
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
    ---@type TowersRoundInfo
    user.round = {
        bettime = os.time(),
        betcoin = betcoin,
        difficulty = difficulty,  --难度
        result = gamelogic.getResult(difficulty),
        chooseIdxs = {},  -- 已选择的格子
        mult = 0,   --倍数
        wincoin = 0,    --赢取金额
        issue = deskInfo.issue
    }
    -- 存放到redis中，等待客户端选择
    delegate.redisSet(user.uid, user.round)
    -- 返回前端当局信息
    ret.round = table.copy(user.round)
    ret.round.result = nil
    ret.coin = user.coin
    return ret
end

---@param delegate StandaloneAgentDelegate
function gamelogic.settle(deskInfo, delegate, res)
    local user = deskInfo.user
    -- 从数据库中删除当局信息
    delegate.redisDel(user.uid)
    local tax = 0
    local wincoin = 0
    if res > 0 then
        local option = config.options[user.round.difficulty]
        user.round.mult = option.mults[#user.round.chooseIdxs]
        wincoin = user.round.betcoin * user.round.mult
        tax = delegate.calcTax(user.round.betcoin, wincoin)
        wincoin = wincoin - tax
        user.round.wincoin = wincoin
        delegate.changeCoin(user, PDEFINE.ALTERCOINTAG.WIN, wincoin, deskInfo)
        if wincoin > user.round.betcoin then
            delegate.notifyLobby(user, wincoin - user.round.betcoin)
        end
    end
    --记录结果
    local settle = {mult=user.round.mult, difficulty=user.round.difficulty}
    delegate.recordGameLog(deskInfo, user.round.betcoin, wincoin, settle, tax)
    --更新策略数据
    if user.cluster_info and user.istest ~= 1 then
        delegate.updateStrategyData(user.round.betcoin, wincoin)
    end
    --游戏记录
    table.insert(deskInfo.records, settle)
    if #(deskInfo.records) > 100 then
        table.remove(deskInfo.records, 1)
    end
    return
end

-- 游戏操作
-- rtype 1 选择格子
-- rtype 2 Cash Out
function gamelogic.gameLogicCmd(deskInfo, msg, delegate)
    local ret = {
        c = msg.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        rtype = msg.rtype
    }
    local user = deskInfo.user
    if not user.round then
        ret.spcode = PDEFINE.RET.ERROR.GAME_NOT_OPEN
        return ret
    end
    local option = config.options[user.round.difficulty]
    if msg.rtype == 1 then  -- 选择格子
        local idx = tonumber(msg.idx) or 0
        if idx < 1 or idx > option.blocks then
            ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
            return ret
        end
        table.insert(user.round.chooseIdxs, idx)
        local over = 0
        local floor = #(user.round.chooseIdxs)
        local res = user.round.result[floor][idx]
        local restriction = delegate.getRestriction()  --0：随机 -1：输 1：赢
        if res == 1 and restriction == -1 then  --随机改变结果
            local rand = math.random(1, option.blocks)
            for _ = 1, option.blocks do
                local i = _ + rand
                if i > option.blocks then i = i - option.blocks end
                if i ~= idx and user.round.result[floor][i] == 0 then
                    user.round.result[floor][i] = 1
                    user.round.result[floor][idx] = 0
                    res = 0
                    LOG_DEBUG("restriction", deskInfo.gameid, restriction, 0, user.round.betcoin)
                    break
                end
            end
        end
        -- 如果选择的是x，或者已到达最上层，则结算
        if res == 0 or floor >= option.floors then
            over = 1
            gamelogic.settle(deskInfo, delegate, res)
            ret.round = table.copy(user.round)
            user.round = nil
        else
            -- 存到redis中
            delegate.redisSet(user.uid, user.round)
            ret.round = table.copy(user.round)
            ret.round.result = nil
        end
        ret.res = res
        ret.over = over
        ret.coin = user.coin
    elseif msg.rtype == 2 then  -- 选择收回金币
        -- 如果当前局还没有选择，则不能收回金币
        if #user.round.chooseIdxs == 0 then
            ret.spcode = PDEFINE.RET.ERROR.GAME_ING_ERROR
            return ret
        end
        gamelogic.settle(deskInfo, delegate, 1)
        ret.coin = user.coin
        ret.round = table.copy(user.round)
        user.round = nil
    else
        ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
    end
    return ret
end

return gamelogic


--[[
--桌子信息
--deskInfo增加字段
    {
        config = {},  --配置表
        records = {
            {mult=27.55},
            ...
        },   --游戏记录
        user {
            round = {}
        }
    }

--交互协议
    --开始游戏(C->S)
    {
        c = 44,
        betcoin = 10,   --押注金额
        difficulty = 1, --难度
    }
    --返回
    {
        c = 44,
        spcode = 0,     --错误码，0表示正常
        round = {
            chooseIdxs = {},  -- 已选择的格子
            mult = 1,   -- 当前倍数
            wincoin = 0,    --赢取金额
            result = {0,0,1,0,...}, --棋盘结果 0:表示x 1：表示√ (只有结束才有)
        },
    }

    --选择格子(C->S)
    {
        c = 51,
        rtype = 1,
        idx = 1,    --选择索引， 从左起第几个
    }
    --返回
    {
        c = 51,
        spcode = 0,
        rtype = 1,
        round = {
            chooseIdxs = {},  -- 已选择的格子
            mult = 1,   -- 当前倍数
            wincoin = 0,    --赢取金额
            result = {0,0,1,0,...}, --棋盘结果 0:表示x 1：表示√ (只有结束才有)
        },
        res = 1,    --开出的结果， 0：选错  1：选对
        over = 0,   --是否结束 0:未结束， 1：已结束
        coin = 100, --当前金币
    }

    --Cash Out（C->S）
    {
        c = 51,
        rtype = 2,
    }
    --返回
    {
        c = 51,
        spcode = 0,
        rtype = 2,
        round = {},
        coin = 100, --当前金币
    }
]]