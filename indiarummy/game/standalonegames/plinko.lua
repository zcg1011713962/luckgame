--[[
    Plinko
    玩家选择一个押注额，然后选择发射一个球（有绿黄红三种小球可供选择）
    小球从高处落下，掉落到底下不同的倍数栏里，玩家获得“押注额*倍数”的奖励
]]

local betUtil = require "betgame.betutils"

--配置表
local config = {
    minbet = 1,
    maxbet = 1000,
    pins = {
        [1] = {
            pid = 1,
            num = 12,
            mults = {
                {11, 3.2, 1.6, 1.2, 1.1, 1, 0.5, 1, 1.1, 1.2, 1.6, 3.2, 11}, --绿球
                {25, 8, 3.1, 1.7, 1.2, 0.7, 0.3, 0.7, 1.2, 1.7, 3.1, 8, 25}, --黄球
                {141, 25, 8.1, 2.3, 0.7, 0.2, 0, 0.2, 0.7, 2.3, 8.1, 25, 141}, --红球
            }
        },
        [2] = {
            pid = 2,
            num = 14,
            mults = {
                {18, 3.2, 1.6, 1.3, 1.2, 1.1, 1, 0.5, 1, 1.1, 1.2, 1.3, 1.6, 3.2, 18}, --绿球
                {55, 12, 5.6, 3.2, 1.6, 1, 0.7, 0.2, 0.7, 1, 1.6, 3.2, 5.6, 12, 55}, --黄球
                {353, 49, 14, 5.3, 2.1, 0.5, 0.2, 0, 0.2, 0.5, 2.1, 5.3, 14, 49, 353}, --红球
            }
        },
        [3] = {
            pid = 3,
            num = 16,
            mults = {
                {35, 7.7, 2.5, 1.6, 1.3, 1.2, 1.1, 1, 0.4, 1, 1.1, 1.2, 1.3, 1.6, 2.5, 7.7, 35}, --绿球
                {118, 61, 12, 4.5, 2.3, 1.2, 1, 0.7, 0.2, 0.7, 1, 1.2, 2.3, 4.5, 12, 61, 118}, --黄球
                {555, 122, 26, 8.5, 3.5, 2, 0.5, 0.2, 0, 0.2, 0.5, 2, 3.5, 8.5, 26, 122, 555}, --红球
            }
        },
    }
}
--权重表
local weights = {
    [1] = {
        {15, 50, 120, 180, 250, 500, 1800, 500, 250, 180, 120, 50, 15}, --绿球权重
        {8, 32, 80, 150, 200, 640, 1700, 640, 200, 150, 80, 32, 8}, --黄球权重
        {5, 40, 125, 425, 1000, 2000, 2690, 2000, 1000, 425, 125, 40, 5}, --红球权重
    },
    [2] = {
        {12, 80, 180, 240, 300, 400, 450, 3000, 450, 400, 300, 240, 180, 80, 12}, --绿球权重
        {10, 55, 120, 210, 510, 900, 2200, 5000, 2200, 900, 510, 210, 120, 55, 10}, --黄球权重
        {2, 15, 60, 150, 320, 1500, 2000, 2000, 2000, 1500, 320, 150, 60, 15, 2}, --红球权重
    },
    [3] = {
        {5, 32, 120, 210, 270, 310, 320, 400, 3200, 400, 320, 310, 270, 210, 120, 32, 5}, --绿球权重
        {5, 10, 50, 135, 270, 480, 560, 2000, 5600, 2000, 560, 480, 270, 135, 50, 10, 5}, --黄球权重
        {4, 25, 125, 356, 800, 1400, 5000, 9500, 10000, 9500, 5000, 1400, 800, 356, 125, 25, 4}, --红球权重
    }
}

local gamelogic = {}

function gamelogic.create(gameid)
end

function gamelogic.initDeskInfo(deskInfo)
    deskInfo.config = config
    deskInfo.records = {}
end

function gamelogic.getResult(pid, color)
    local weight = weights[pid][color]
    return betUtil.randomIndex(weight)
end

function gamelogic.tryGetRestrictiveResult(betcoin, pid, color, restriction)
    local result = nil
    for trycnt = 1, 100 do
        result = gamelogic.getResult(pid, color)
        if restriction == 0 then
            break
        end
        local cfg = config.pins[pid]
        local mult = cfg.mults[color][result]
        local wincoin = betcoin * mult
        if (wincoin == betcoin)
         or (restriction < 0 and wincoin < betcoin)
         or (restriction > 0 and wincoin > betcoin) then
            LOG_DEBUG("restriction", deskInfo.gameid, restriction, wincoin, betcoin)
            break
        end
    end
    return result
end

---@param deskInfo any
---@param msg any
---@param delegate StandaloneAgentDelegate
function gamelogic.start(deskInfo, msg, delegate)
    local ret = {code = PDEFINE.RET.SUCCESS, spcode=0, c=msg.c, betcoin=msg.betcoin}
    local betcoin = tonumber(msg.betcoin) or 0
    local pid = msg.pid
    local color = msg.color
    if (betcoin < config.minbet) or (pid~=1 and pid~=2 and pid~=3) or (color~=1 and color~=2 and color~=3) then
        LOG_DEBUG("params error", betcoin, color, pid)
        ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return ret
    end
    local user = deskInfo.user
    if user.coin < betcoin then
        ret.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        return ret
    end
    if not delegate.changeCoin(user, PDEFINE.ALTERCOINTAG.BET, -betcoin, deskInfo) then
        LOG_INFO("user change coin fail", msg.uid, -betcoin)
        ret.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        return ret
    end

    local restriction = delegate.getRestriction()  --0：随机 -1：输 1：赢
    local idx = gamelogic.tryGetRestrictiveResult(betcoin, pid, color, restriction)
    local cfg = config.pins[pid]
    local mult = cfg.mults[color][idx]
    local wincoin = betcoin * mult
    local tax = 0
    if wincoin > 0 then
        tax = delegate.calcTax(betcoin, wincoin)
        wincoin = wincoin - tax
        delegate.changeCoin(user, PDEFINE.ALTERCOINTAG.WIN, wincoin, deskInfo)
        if wincoin > betcoin then
            delegate.notifyLobby(user, wincoin - betcoin)
        end
    end
    --记录结果
    local settle = {mult=mult, color=color, pins=cfg.pins}
    delegate.recordGameLog(deskInfo, betcoin, wincoin, settle, tax)
    --更新策略数据
    if user.cluster_info and user.istest ~= 1 then
        delegate.updateStrategyData(betcoin, wincoin)
    end
    --游戏记录
    local result = {mult=mult, color=color, pid=pid, idx=idx}
    table.insert(deskInfo.records, result)
    if #(deskInfo.records) > 100 then
        table.remove(deskInfo.records, 1)
    end

    ret.result = result
    ret.wincoin = wincoin
    ret.coin = user.coin
    return ret
end

return gamelogic

--[[
--下注范围
    [1, 1000]

--桌子信息
--deskInfo增加字段
    {
        config = {},  --配置表
        records = {
            {mult=27.55, color=1},
            ...
        },   --游戏记录
    }

--交互协议
    --玩家押注(C->S)
    {
        c = 44,
        betcoin = 10,   --押注金额
        pid = 1,     --Pins序号 1:12针 2:14针 3:16针
        color = 1,   --颜色 1:绿 2:黄 3:红
    }
    --返回
    {
        c = 44,
        spcode = 0,     --错误码，0表示正常
        result = {
            pid = 1,
            mult = 1.1,     --倍数
            color = 1,      --颜色
            idx = 5,        --球位置(从左到右第几个栏位)
        }
        wincoin = 0,    --赢分
    }
]]