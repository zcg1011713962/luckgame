--[[
    Coins
]]

local betUtil = require "betgame.betutils"

-- 配置表
local config = {
    mults = {1.94, 1.94},
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

function gamelogic.getResult()
    return math.random(1, 2)
end

function gamelogic.tryGetRestrictiveResult()
end

function gamelogic.start(deskInfo, msg, delegate)
    local ret = {code = PDEFINE.RET.SUCCESS, spcode=0, c=msg.c, betcoin=msg.betcoin}
    local betcoin = tonumber(msg.betcoin) or 0
    local choose = msg.choose  -- 选择 1：正 2：反
    if choose ~= 1 and choose ~=2 then
        LOG_DEBUG("params error", betcoin, choose)
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
    local result = gamelogic.getResult()
    local restriction = delegate.getRestriction()  --0：随机 -1：输 1：赢
    if restriction ~= 0 then
        if restriction < 0 then
            result = choose == 1 and 2 or 1
        elseif restriction > 0 then
            result = choose == 2 and 1 or 2
        end
    end
    local isWin = result == choose
    local mult = 0
    if isWin then
        mult = config.mults[choose]
    end
    local wincoin = math.round_coin(betcoin * mult)
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
    local settle = {mult=mult, choose=choose, result=result}
    delegate.recordGameLog(deskInfo, betcoin, wincoin, settle, tax)
    --更新策略数据
    if user.cluster_info and user.istest ~= 1 then
        delegate.updateStrategyData(betcoin, wincoin)
    end
    --游戏记录
    local record = {mult=mult, choose=choose, result=result}
    table.insert(deskInfo.records, record)
    if #(deskInfo.records) > 100 then
        table.remove(deskInfo.records, 1)
    end

    ret.result = record
    ret.wincoin = wincoin
    ret.coin = user.coin
    return ret
end


return gamelogic


--[[

--桌子信息
--deskInfo增加字段
    {
        config = {
            mults = {1.94, 1.94}
        },  --配置表
        records = {
            {mult=27.55, choose=1, result=1},
            ...
        },   --游戏记录
    }

--交互协议
    --玩家押注(C->S)
    {
        c = 44,
        betcoin = 10,   --押注金额
        choose = 1,     -- 选择正反 1：正 2：反
    }
    --返回
    {
        c = 44,
        spcode = 0,     --错误码，0表示正常
        result = 1,  -- 1：正 2：反
        choose = 1,     -- 选择正反 1：正 2：反
        wincoin = 0,    --赢分
        mult = 1.94,   --倍数
    }
]]