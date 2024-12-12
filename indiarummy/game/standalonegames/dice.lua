--[[
    Dice
    系统给定一个范围在[0.01, 100]的数字
    玩家猜测这个数字小于（under）或者大于(over)某个数
    如果猜对了，获得相应倍数
]]

local DIVIDEND = 97 --划分因子，影响回报率

local config = {
    minbet = 1,
    maxbet = 1000,
}

local gamelogic = {}

function gamelogic.create(gameid)
end

function gamelogic.initDeskInfo(deskInfo)
    deskInfo.dividend = DIVIDEND
    deskInfo.config = config
    deskInfo.records = {}
end

function gamelogic.getResult()
    return math.random(1,9999)/100
end

function gamelogic.calcWinCoin(num, betcoin, payout, roll)
    local wincoin = 0
    local under = math.round((DIVIDEND / payout), 2)
    local over = 99.99 - under
    if roll == 1 then   --roll under
        if num < under then
            wincoin = betcoin * payout
        end
    elseif roll == 2 then  --roll over
        if num > over then
            wincoin = betcoin * payout
        end
    end
    return wincoin
end

--获取策略控制结果
function gamelogic.tryGetRestrictiveResult(betcoin, payout, roll, restriction)
    local result = nil
    for trycnt = 1, 100 do
        result = gamelogic.getResult()
        if restriction == 0 then
            break
        end
        local wincoin = gamelogic.calcWinCoin(result, betcoin, payout, roll)
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
    local payout = tonumber(msg.payout) or 0
    payout = math.floor(payout * 100) / 100 --保留两位小数
    local roll = msg.roll
    if (betcoin < config.minbet) or (payout < 1.1 or payout > 970) or (roll~=1 and roll~=2) then
        LOG_DEBUG("params error", betcoin, payout, roll)
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
    local num = gamelogic.tryGetRestrictiveResult(betcoin, payout, roll, restriction)
    local wincoin = gamelogic.calcWinCoin(num, betcoin, payout, roll)
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
    local settle = {payout=payout, num=num, roll=roll, res=res}
    delegate.recordGameLog(deskInfo, betcoin, wincoin, settle, tax)
    --更新策略数据
    if user.cluster_info and user.istest ~= 1 then
        delegate.updateStrategyData(betcoin, wincoin)
    end
    --游戏记录
    local result = {num=num, res=res}
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
--赔率范围
    [1.1, 970]

--桌子信息
--deskInfo增加字段
    {
        config = {
            minbet = 1,
            maxbet = 1000,
        },
        records = {
            {num = 27.55, res=1},
            ...
        },   --游戏记录
    }

--交互协议
    --玩家押注(C->S)
    {
        c = 44,
        betcoin = 10,   --押注金额
        payout = 1.1,   --赔率
        roll = 1,       --押注方式 1:Roll Under, 2:Roll Over
    }
    --返回
    {
        c = 44,
        spcode = 0,     --错误码，0表示正常
        result = {
            num = 43.55,    --结果数字
            res = 0,        --游戏结果：0：未猜中 1，猜中
        }
        wincoin = 0,    --赢分
    }
]]