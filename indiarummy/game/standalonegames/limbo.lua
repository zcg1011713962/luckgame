--[[
    Limbo
    玩家设置一个倍数，范围[1.01, 1000]，并下注[1,1000]
    系统生成一个随机数，如果玩家设置的倍数小于随机数，则玩家获得“下注额*倍数”的奖励

]]
local commonUtils = require "cashslots.common.utils"

local PAYBACK_RATE = 0.98

--倍数权重表
--from,to为左闭右开空间[),数值放大了100倍，实际使用时from和to除以100
local weights = {
    {from=100, to=102, weight=196},
    {from=102, to=104, weight=189},
    {from=104, to=106, weight=181},
    {from=106, to=108, weight=175},
    {from=108, to=110, weight=168},
    {from=110, to=112, weight=162},
    {from=112, to=114, weight=157},
    {from=114, to=116, weight=151},
    {from=116, to=118, weight=146},
    {from=118, to=120, weight=141},
    {from=120, to=125, weight=333},
    {from=125, to=130, weight=308},
    {from=130, to=135, weight=285},
    {from=135, to=140, weight=265},
    {from=140, to=145, weight=246},
    {from=145, to=150, weight=230},
    {from=150, to=155, weight=215},
    {from=155, to=160, weight=202},
    {from=160, to=165, weight=189},
    {from=165, to=170, weight=178},
    {from=170, to=180, weight=327},
    {from=180, to=190, weight=292},
    {from=190, to=200, weight=263},
    {from=200, to=210, weight=238},
    {from=210, to=220, weight=216},
    {from=220, to=230, weight=217},
    {from=230, to=240, weight=218},
    {from=240, to=260, weight=321},
    {from=260, to=280, weight=275},
    {from=280, to=300, weight=238},
    {from=300, to=320, weight=208},
    {from=320, to=340, weight=184},
    {from=340, to=360, weight=163},
    {from=360, to=380, weight=146},
    {from=380, to=400, weight=132},
    {from=400, to=450, weight=278},
    {from=450, to=500, weight=222},
    {from=500, to=550, weight=182},
    {from=550, to=600, weight=152},
    {from=600, to=700, weight=238},
    {from=700, to=800, weight=179},
    {from=800, to=900, weight=139},
    {from=900, to=1000, weight=111},
    {from=1000, to=1100, weight=91},
    {from=1100, to=1200, weight=76},
    {from=1200, to=1300, weight=64},
    {from=1300, to=1400, weight=54},
    {from=1400, to=1500, weight=48},
    {from=1500, to=1600, weight=42},
    {from=1600, to=1700, weight=37},
    {from=1700, to=1800, weight=33},
    {from=1800, to=1900, weight=29},
    {from=1900, to=2000, weight=26},
    {from=2000, to=2200, weight=45},
    {from=2200, to=2400, weight=38},
    {from=2400, to=2600, weight=32},
    {from=2600, to=2800, weight=30},
    {from=2800, to=3000, weight=24},
    {from=3000, to=3500, weight=48},
    {from=3500, to=4000, weight=36},
    {from=4000, to=4500, weight=28},
    {from=4500, to=5000, weight=22},
    {from=5000, to=6000, weight=33},
    {from=6000, to=7000, weight=24},
    {from=7000, to=8000, weight=18},
    {from=8000, to=9000, weight=14},
    {from=9000, to=10000, weight=11},
    {from=10000, to=15000, weight=33},
    {from=15000, to=20000, weight=17},
    {from=20000, to=30000, weight=17},
    {from=30000, to=40000, weight=8},
    {from=40000, to=50000, weight=5},
    {from=50000, to=60000, weight=3},
    {from=60000, to=70000, weight=2},
    {from=70000, to=84000, weight=2},
    {from=84000, to=100000, weight=2},
}

local config = {
    minbet = 1,
    maxbet = 1000,
}

local gamelogic = {}

function gamelogic.create(gameid)
end

function gamelogic.initDeskInfo(deskInfo)
    deskInfo.config = config
    deskInfo.records = {}
end

--根据权重分布生成给定范围(左闭右开)的随机数
function gamelogic.random(op, multiplier)
    local m = math.floor(multiplier*100)--放大100倍
    local probs = {}
    for _, item in ipairs(weights) do
        if (op=='<' and item.to <= m) or (op=='>' and item.from>=m) then
            table.insert(probs, item)
        end
    end
    local _, res = commonUtils.randByWeight(probs)
    if res then
        local rand = math.random(res.from, res.to) / 100
        if op == '<' and rand >= multiplier then
            rand = multiplier - 0.01
        end
        if op == '>' and rand <= multiplier then
            rand = multiplier + 0.01
        end
        return rand
    end
    return 1
end

function gamelogic.calcWinCoin(mult, betcoin, multiplier)
    local wincoin = 0
    if multiplier < mult then   --如果玩家设置倍数小于结果倍数，则获得奖励
        wincoin = betcoin * multiplier
    end
    return wincoin
end

--获取策略控制结果
function gamelogic.tryGetRestrictiveResult(betcoin, multiplier, restriction)
    if restriction < 0 then
        LOG_DEBUG("restriction", deskInfo.gameid, restriction, 0, betcoin)
    end
    if math.random() < PAYBACK_RATE/multiplier and restriction >= 0 then
        return gamelogic.random('>', multiplier)
    else
        return gamelogic.random('<', multiplier)
    end
end

---@param deskInfo any
---@param msg any
---@param delegate StandaloneAgentDelegate
function gamelogic.start(deskInfo, msg, delegate)
    local ret = {code = PDEFINE.RET.SUCCESS, spcode=0, c=msg.c, betcoin=msg.betcoin}
    local betcoin = tonumber(msg.betcoin) or 0
    local multiplier = tonumber(msg.multiplier) or 0
    multiplier = math.floor(multiplier * 100) / 100 --保留两位小数

    if (betcoin < 1) or (multiplier < 1.01 or multiplier > 1000) then
        LOG_DEBUG("params error", betcoin, multiplier)
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
    local mult = gamelogic.tryGetRestrictiveResult(betcoin, multiplier, restriction)
    local wincoin = gamelogic.calcWinCoin(mult, betcoin, multiplier)
    local res = (wincoin>0) and 1 or 0
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
    local settle = {multiplier=multiplier, mult=mult, res=res}
    delegate.recordGameLog(deskInfo, betcoin, wincoin, settle, tax)
    --更新策略数据
    if user.cluster_info and user.istest ~= 1 then
        delegate.updateStrategyData(betcoin, wincoin)
    end
    --游戏记录
    local result = {mult=mult, res=res}
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
--倍率范围
    [1.01, 1000]

--桌子信息
--deskInfo增加字段
    {
        config = {
            minbet = 1,
            maxbet = 1000,
        },
        records = {
            {mult=17.5, res=1},
            ...
        },   --游戏记录
    }

--交互协议
    --玩家押注(C->S)
    {
        c = 44,
        betcoin = 10,   --押注金额
        multiplier = 1.1,   --押注倍数
    }
    --返回
    {
        c = 44,
        spcode = 0,     --错误码，0表示正常
        result = {
            mult = 3.55,    --结果倍数
            res = 0,        --游戏结果：0：未猜中 1，猜中
        }
        wincoin = 0,    --赢分
    }
]]