--[[
    Crypto
    玩家下注
    系统随机生成5颗宝石，如果宝石的类型个数组合符合特定组合，则获得相应奖励
]]

--宝石类型
local GemType = {
    LightBlue = 1,  --浅蓝锥钻
    Green = 2,      --绿色锥钻
    DarkBlue = 3,   --深蓝方钻
    Red = 4,        --红色椭钻
    Yellow = 5,     --黄色泪钻
    Pink = 6,       --粉红心钻
    Purple = 7,     --紫色柱钻
    Orange = 8,     --橙色圆钻
}

--所有宝石
local Gems = {1, 2, 3, 4, 5, 6, 7, 8}

local config = {
    minbet = 1,
    maxbet = 1000,
    combs = {
        [1] = {-- 5个不同宝石
            comb = {1,1,1,1,1}, ctype = 1, mult = 0,   chance = 20.507
        },
        [2] = {-- 1对宝石
            comb = {2,1,1,1},   ctype = 2, mult = 0.1, chance = 51.269
        },
        [3] = {-- 2对宝石
            comb = {2,2,1},     ctype = 3, mult = 2.5, chance = 15.38
        },
        [4] = {-- 3个相同宝石
            comb = {3,1,1},     ctype = 4, mult = 3.5, chance = 10.253
        },
        [5] = {-- 3个相同+1对宝石
            comb = {3,2},       ctype = 5, mult = 6,   chance = 1.7089
        },
        [6] = {-- 4个相同宝石
            comb = {4,1},       ctype = 6, mult = 7,    chance = 0.8544
        },
        [7] = {-- 5个相同宝石
            comb = {5},         ctype = 7, mult = 60,   chance = 0.0244
        },
    }
}

local gamelogic = {}

function gamelogic.create(gameid)
end

function gamelogic.initDeskInfo(deskInfo)
    deskInfo.config = config
    deskInfo.records = {}
end

function gamelogic.getResult()
    local result = {}
    for _ = 1, 5 do
        local gem = Gems[math.random(#Gems)]
        table.insert(result, gem)
    end
    return result
end

local function compare(a, b)
    return a > b
end

function gamelogic.calcWinMult(gems)
    local counts = {0, 0, 0, 0, 0, 0, 0, 0}
    for _, gem in ipairs(gems) do
        counts[gem] = counts[gem] + 1
    end
    table.sort(counts, compare)
    local comb = {}
    for _, cnt in ipairs(counts) do
        if cnt > 0 then
            table.insert(comb, cnt)
        end
    end
    for _, cfg in ipairs(config.combs) do
        if table.equal(comb, cfg.comb) then
            return cfg.mult, cfg.ctype
        end
    end
    return 0, 0
end

function gamelogic.tryGetRestrictiveResult(betcoin, restriction)
    local result = nil
    for trycnt = 1, 100 do
        result = gamelogic.getResult()
        if restriction == 0 then
            break
        end
        local mult = gamelogic.calcWinMult(result)
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

function gamelogic.start(deskInfo, msg, delegate)
    local ret = {code = PDEFINE.RET.SUCCESS, spcode=0, c=msg.c, betcoin=msg.betcoin}
    local betcoin = tonumber(msg.betcoin) or 0
    if betcoin < config.minbet then
        LOG_DEBUG("params error", betcoin)
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
    local gems = gamelogic.tryGetRestrictiveResult(betcoin, restriction)
    local mult, ctype = gamelogic.calcWinMult(gems)
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
    local settle = {mult=mult, gems=gems}
    delegate.recordGameLog(deskInfo, betcoin, wincoin, settle, tax)
    --更新策略数据
    if user.cluster_info and user.istest ~= 1 then
        delegate.updateStrategyData(betcoin, wincoin)
    end
    --游戏记录
    local result = {mult=mult, gems=gems, ctype=ctype}
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
--桌子信息
--deskInfo增加字段
    {
        config = {},  --配置表
        records = {
            {mult=27.55},
            ...
        },   --游戏记录
    }

--交互协议
    --玩家押注(C->S)
    {
        c = 44,
        betcoin = 10,   --押注金额
    }
    --返回
    {
        c = 44,
        spcode = 0,     --错误码，0表示正常
        result = {
            gems = {1,1,3,4,5},--开出宝石
            ctype = 2, --中奖组合类型
            mult = 0.1, --中奖倍数
        }
        wincoin = 10,    --赢分
    }
]]