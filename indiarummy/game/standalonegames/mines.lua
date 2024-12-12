--[[
    Mines
    5X5的格子，每个格子有💎或者💣，获得💎则可获得金币上升一个等级，获得💣则游戏结束
    中途可以选择停止游戏，获得当前等级的金币
    或者继续游戏，获取更多金币，但是如果获得💣则游戏结束
]]

local betUtil = require "betgame.betutils"
local cjson = require "cjson"

---@class RoundInfo
---@field public bettime number @开始时间
---@field public betcoin number @当前下注额
---@field public result number[] @此轮结果
---@field public wincoin number  @当前获得金币
---@field public mineCnt number @💣数量
---@field public chooseIdxs number[] @已选择的下标

local MAX_WIN_MULT = 10000  --最大赢取倍数
local MAX_WIN_COIN = 1000000   --最大获得金币

-- 配置表
local config = {
    minbet = 1,  -- 最小下注
    maxbet = 1000,  -- 最大下注
    -- 格子数量
    gridCnt = 25,
    -- 格子类型
    gridType = {
        -- 掩盖
        cover = 0,
        -- 💎
        diamond = 1,
        -- 💣
        bomb = 2,
    },
    -- 最小💣数量
    minMineCnt = 2,
    -- 最大💣数量
    maxMineCnt = 24,
    -- 索引为💣数量，值索引为💎数量，值为获得金币的比例
    winMult = {
        [2] = {1.03, 1.13, 1.23, 1.36, 1.5, 1.67, 1.86, 2.1, 2.38, 2.71, 3.13, 3.65, 4.32, 5.18, 6.33, 7.92, 10.18, 13.57, 19, 28.5, 47.5, 95, 285},
        [3] = {1.08, 1.23, 1.42, 1.64, 1.92, 2.25, 2.68, 3.21, 3.9, 4.8, 6, 7.64, 9.93, 13.24, 18.21, 26.01, 39.02, 62.43, 109.25, 218.5, 546.25, 2190},
        [4] = {1.13, 1.36, 1.64, 2.01, 2.48, 3.1, 3.93, 5.05, 6.6, 8.8, 12.01, 16.81, 24.28, 36.42, 57.23, 95.38, 171.68, 343.36, 801.17, 2400, 12020},
        [5] = {1.19, 1.5, 1.92, 2.48, 3.26, 4.34, 5.89, 8.16, 11.56, 16.81, 25.21, 39.22, 63.73, 109.25, 200.29, 400.58, 901.31, 2400, 8410, 50470},
        [6] = {1.25, 1.67, 2.25, 3.1, 4.34, 6.2, 9.06, 13.59, 21.01, 33.62, 56.03, 98.04, 182.08, 364.17, 801.17, 2000, 6010, 24040, 168250},
        [7] = {1.32, 1.86, 2.68, 3.93, 5.89, 9.06, 14.35, 23.48, 39.92, 70.97, 133.06, 266.12, 576.6, 1380, 3810, 12690, 57080, 456670},
        [8] = {1.4, 2.1, 3.21, 5.05, 8.16, 13.59, 23.48, 42.27, 79.84, 159.67, 342.16, 798.37, 2080, 6230, 22830, 144170, 1030000},
        [9] = {1.48, 2.38, 3.9, 6.6, 11.56, 21.01, 39.92, 79.84, 169.65, 387.78, 969.44, 2710, 8820, 35290, 194080, 1940000},
        [10] = {1.58, 2.71, 4.8, 8.8, 16.81, 33.62, 70.97, 159.67, 387.78, 1030, 3100, 10860, 47050, 282300, 3110000},
        [11] = {1.7, 3.13, 6, 12.01, 25.21, 56.03, 133.06, 342.16, 969.44, 3100, 11630, 54290, 352880, 4230000},
        [12] = {1.83, 3.65, 7.64, 16.81, 39.22, 98.04, 266.12, 798.37, 2710, 10860, 54290, 380020, 4940000},
        [13] = {1.98, 4.32, 9.93, 24.28, 63.73, 182.08, 576.6, 2080, 8820, 47050, 352880, 4940000},
        [14] = {2.16, 5.18, 13.24, 36.42, 109.25, 364.17, 1380, 6230, 35290, 282300, 4230000},
        [15] = {2.38, 6.33, 18.21, 57.23, 200.29, 801.17, 3810, 22830, 194080, 3110000},
        [16] = {2.64, 7.92, 26.01, 95.38, 400.58, 2000, 12690, 114170, 1940000},
        [17] = {2.97, 10.18, 39.02, 171.68, 901.31, 6010, 57080, 1030000},
        [18] = {3.39, 13.57, 62.43, 343.36, 2400, 24040, 456670},
        [19] = {3.96, 19, 109.25, 801.17, 8410, 168250},
        [20] = {4.75, 28.5, 218.5, 2400, 50470},
        [21] = {5.94, 47.5, 546.25, 12020},
        [22] = {7.92, 95, 2190},
        [23] = {11.88, 285},
        [24] = {23.75},
    }
    
}

local gamelogic = {}

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
    end
end

function gamelogic.getResult(mineCnt)
    local result = {}
    -- 先填入💎
    for i = 1, config.gridCnt, 1 do
        table.insert(result, config.gridType.diamond)
    end
    -- 随机选出mineCnt个位置，填入💣
    local minePos = betUtil.genRandIdxs(config.gridCnt, mineCnt)
    for _, idx in ipairs(minePos) do
        result[idx] = config.gridType.bomb
    end
    return result
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
        isauto = msg.isauto,  -- 是否自动续投,一次性出结果
    }
    local betcoin = tonumber(msg.betcoin) or 0
    local user = deskInfo.user
    if user.round then  -- 如果上一轮还没有完成，则不能开始新的一轮
        ret.spcode = PDEFINE.RET.ERROR.GAME_ING_ERROR
        return ret
    end
    if msg.mineCnt < config.minMineCnt or msg.mineCnt > config.maxMineCnt then
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
    ---@type RoundInfo
    user.round = {
        bettime = os.time(),
        betcoin = betcoin,
        result = gamelogic.getResult(),
        chooseIdxs = {},  -- 选择的格子
        wincoin = 0,
        winMult = 0,
        mineCnt = msg.mineCnt,
        isEnd = 0,  -- 是否结束
        issue = deskInfo.issue
    }
    -- 如果是自动投注，则根据设置的参数，直接结算
    if msg.isauto then
        ret.idxs = msg.idxs
        local isWin = true
        for _, idx in ipairs(ret.idxs) do
            if user.round.result[idx] == config.gridType.bomb then
                isWin = false
                break
            end
        end
        -- 如果是赢了，则计算赢的金币
        if isWin then
            user.round.winMult = config.winMult[user.round.mineCnt][#ret.idxs]
            user.round.wincoin = math.round_coin(betcoin * user.round.winMult)
            gamelogic.settleCoin(deskInfo, user, delegate)
        end
        ret.round = gamelogic.getRoundInfo(user.round)
        ret.coin = user.coin
    else
        ret.coin = user.coin
        -- 返回前端当局信息
        ret.round = gamelogic.getRoundInfo(user.round)
        -- 存放到redis中，等待客户端选择
        delegate.redisSet(user.uid, user.round)
    end
    return ret
end

---@param delegate StandaloneAgentDelegate
function gamelogic.settleCoin(deskInfo, user, delegate)
    -- 从数据库中删除当局信息
    delegate.redisDel(user.uid)
    local tax = 0
    local wincoin = 0
    user.round.isEnd = 1
    if user.round.wincoin > 0 then
        tax = delegate.calcTax(user.round.betcoin, user.round.wincoin)
        wincoin = math.round_coin(user.round.wincoin - tax)
        user.round.wincoin = wincoin
        delegate.changeCoin(user, PDEFINE.ALTERCOINTAG.WIN, wincoin, deskInfo)
        if wincoin > user.round.betcoin then
            delegate.notifyLobby(user, wincoin - user.round.betcoin)
        end
    end
    --记录结果
    local settle = {}
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

-- 额外操作
-- rtype 1 选择格子
-- rtype 2 选择收回金币
function gamelogic.gameLogicCmd(deskInfo, msg, delegate)
    local ret = {
        c = msg.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
    }
    local user = deskInfo.user
    if msg.rtype == 1 then  -- 选择格子
        if not user.round then
            ret.spcode = PDEFINE.RET.ERROR.GAME_NOT_OPEN
            return ret
        end
        local idx = tonumber(msg.idx or 0)
        if idx < 1 or idx > config.gridCnt then
            ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
            return ret
        end
        -- 如果当前位置已经选择了，则不能再选择
        if table.contain(user.round.chooseIdxs, idx) then
            ret.spcode = PDEFINE.RET.ERROR.GAME_ING_ERROR
            return ret
        end
        table.insert(user.round.chooseIdxs, idx)
        local isWin = false
        local nextBox = user.round.result[idx]
        local restriction = delegate.getRestriction()  --0：随机 -1：输 1：赢
        local winMult = config.winMult[user.round.mineCnt][#user.round.chooseIdxs]
        if restriction == -1 or winMult > MAX_WIN_MULT or winMult * user.round.betcoin > MAX_WIN_COIN then
            -- 如果下一个是💎，则换成💣
            if nextBox == config.gridType.diamond then
                for _idx, val in ipairs(user.round.result) do
                    if val == config.gridType.bomb and not table.contain(user.round.chooseIdxs, idx) then
                        user.round.result[_idx] = config.gridType.diamond
                        user.round.result[idx] = config.gridType.bomb
                        break
                    end
                end
            end
        end
        -- 如果选择的是地雷，则结算
        if user.round.result[idx] == config.gridType.bomb then
            gamelogic.settleCoin(deskInfo, user, delegate)
            ret.round = gamelogic.getRoundInfo(user.round)
            ret.coin = user.coin
            user.round = nil
        else
            -- 如果选择的不是地雷，则返回当前局信息
            ret.round = gamelogic.getRoundInfo(user.round)
            -- 存放到redis中，等待客户端选择
            delegate.redisSet(user.uid, user.round)
        end
    elseif msg.rtype == 2 then  -- 选择收回金币
        if not user.round then
            ret.spcode = PDEFINE.RET.ERROR.GAME_NOT_OPEN
            return ret
        end
        -- 如果当前局还没有选择，则不能收回金币
        if #user.round.chooseIdxs == 0 then
            ret.spcode = PDEFINE.RET.ERROR.GAME_ING_ERROR
            return ret
        end
        user.round.winMult = config.winMult[user.round.mineCnt][#user.round.chooseIdxs]
        local wincoin = math.round_coin(user.round.betcoin * user.round.winMult)
        user.round.wincoin = wincoin
        gamelogic.settleCoin(deskInfo, user, delegate)
        ret.coin = user.coin
        ret.round = gamelogic.getRoundInfo(user.round)
        user.round = nil
    else
        ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
    end
    return ret
end

-- 获取当局信息
function gamelogic.getRoundInfo(roundInfo)
    local ret = table.copy(roundInfo)
    -- 隐藏结果
    ret.result = {}
    for i = 1, config.gridCnt, 1 do
        table.insert(ret.result, config.gridType.cover)
    end
    for _, idx in ipairs(roundInfo.chooseIdxs) do
        ret.result[idx] = roundInfo.result[idx]
    end
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
    -- 格子数量
    gridCnt = 25,
    -- 格子类型
    gridType = {
        -- 掩盖
        cover = 0,
        -- 💎
        diamond = 1,
        -- 💣
        bomb = 2,
    },
    -- 最小💣数量
    minMineCnt = 2,
    -- 最大💣数量
    maxMineCnt = 24,
    -- 索引为💣数量，值索引为💎数量，值为获得金币的比例
    winMult = {
        [2] =  {1.04,1.08,1.12,1.15,1.18,1.21,1.23,1.26,1.28,1.30,1.32,1.34,1.36,1.38,1.39,1.41,1.43,1.44,1.45,1.47,1.48,1.49,1.50},
        [3] =  {1.04,1.08,1.12,1.15,1.19,1.21,1.24,1.27,1.29,1.31,1.33,1.35,1.37,1.39,1.41,1.42,1.44,1.45,1.46,1.48,1.49,1.50},
        [4] =  {1.05,1.09,1.12,1.16,1.19,1.22,1.25,1.28,1.30,1.32,1.34,1.36,1.38,1.40,1.42,1.43,1.45,1.46,1.48,1.49,1.50},
        [5] =  {1.05,1.09,1.13,1.17,1.20,1.23,1.26,1.29,1.31,1.33,1.35,1.38,1.39,1.41,1.43,1.44,1.46,1.47,1.49,1.50},
        [6] =  {1.05,1.10,1.14,1.17,1.21,1.24,1.27,1.30,1.32,1.34,1.37,1.39,1.41,1.42,1.44,1.46,1.47,1.49,1.50},
        [7] =  {1.05,1.10,1.14,1.18,1.22,1.25,1.28,1.31,1.33,1.36,1.38,1.40,1.42,1.44,1.45,1.47,1.49,1.50},
        [8] =  {1.06,1.11,1.15,1.19,1.23,1.26,1.29,1.32,1.35,1.37,1.39,1.41,1.43,1.45,1.47,1.48,1.50},
        [9] =  {1.06,1.11,1.16,1.20,1.24,1.27,1.30,1.33,1.36,1.38,1.41,1.43,1.45,1.47,1.48,1.50},
        [10] = {1.06,1.12,1.17,1.21,1.25,1.29,1.32,1.35,1.38,1.40,1.42,1.44,1.46,1.48,1.50},
        [11] = {1.07,1.12,1.18,1.22,1.26,1.30,1.33,1.36,1.39,1.42,1.44,1.46,1.48,1.50},
        [12] = {1.07,1.13,1.19,1.24,1.28,1.32,1.35,1.38,1.41,1.43,1.46,1.48,1.50},
        [13] = {1.08,1.14,1.20,1.25,1.29,1.33,1.37,1.40,1.43,1.45,1.48,1.50},
        [14] = {1.08,1.15,1.21,1.27,1.31,1.35,1.39,1.42,1.45,1.48,1.50},
        [15] = {1.09,1.17,1.23,1.29,1.33,1.38,1.41,1.44,1.47,1.50},
        [16] = {1.10,1.18,1.25,1.31,1.36,1.40,1.44,1.47,1.50},
        [17] = {1.11,1.20,1.27,1.33,1.38,1.43,1.47,1.50},
        [18] = {1.12,1.22,1.30,1.36,1.42,1.46,1.50},
        [19] = {1.14,1.25,1.33,1.40,1.45,1.50},
        [20] = {1.17,1.29,1.38,1.44,1.50},
        [21] = {1.20,1.33,1.43,1.50},
        [22] = {1.25,1.40,1.50},
        [23] = {1.33,1.50},
        [24] = {1.50},
    }
    
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
        mineCnt = 1,   -- 地雷个数
        isauto = 1,     -- 是否自动押注 0:否 1:是
        idxs = {1, 2, 3},   -- 选择的位置, 如果是自动押注，则需要传
    }
    --返回
    {
        c = 44,
        spcode = 0,     --错误码，0表示正常
        round = {
            bettime = os.time(),  -- 下注时间
            betcoin = betcoin,  -- 下注金额
            result = {0,0,0,0,0,1},  -- 对应25个格子的结果
            chooseIdxs = {},  -- 选择的格子
            wincoin = 0,  -- 当前能获得的金币
            winMult = 0,  -- 当前倍数
            mineCnt = msg.mineCnt,  -- 地雷个数
            isEnd = 0,  -- 是否结束 0:否 1:是
        }
    }
    -- 玩家选择
    {
        c = 51,
        rtype = 1,  -- 1:选择格子 2:选择收回金币
        idx = 1,  -- 选择的格子
    }
    -- 返回
    {
        c = 51,
        spcode = 0,     --错误码，0表示正常
        round = {
            bettime = os.time(),  -- 下注时间
            betcoin = betcoin,  -- 下注金额
            result = {0,0,0,0,0,1},  -- 对应25个格子的结果
            chooseIdxs = {},  -- 选择的格子
            wincoin = 0,  -- 当前能获得的金币
            winMult = 0,  -- 当前倍数
            mineCnt = msg.mineCnt,  -- 地雷个数
            isEnd = 0,  -- 是否结束 0:否 1:是
        }
    }
]]