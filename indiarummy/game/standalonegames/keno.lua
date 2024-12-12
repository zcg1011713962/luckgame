--[[
    Keno
    一共36个数字（1~36），玩家从中随机选择最多10个数字，并进行下注
    然后系统开出10个数字，如果玩家选择的数字出现在系统开出的这10个数字里，玩家将获得相应奖励，中奖倍数跟选中的数字的个数有关
]]

--配置表
-- 不同数字个数情况下的中奖赔率

local config = {
    minbet = 1,
    maxbet = 1000,
    multipliers = {
        [1] = {3.49},
        [2] = {1.50, 4.92},
        [3] = {1.00, 2.30, 8.20},
        [4] = {0.50, 1.82, 4.20, 21.0},
        [5] = {0.00, 1.10, 3.75, 15.0, 35.0},
        [6] = {0.00, 0.50, 2.90, 7.60, 18.0, 55.0},
        [7] = {0.00, 0.25, 2.30, 4.10, 10.0, 31.0, 60.0},
        [8] = {0.00, 0.00, 1.40, 2.80, 11.4, 28.0, 40.0, 70.0},
        [9] = {0.00, 0.00, 1.00, 2.20, 6.10, 17.0, 25.0, 55.0, 85.0},
        [10]= {0.00, 0.00, 1.00, 1.50, 3.30, 10.2, 25.0, 40.0, 75.0, 100},
    }
}


local gamelogic = {}

function gamelogic.create(gameid)
    gamelogic.NUMBERS = {}
    for i = 1, 36 do
        table.insert(gamelogic.NUMBERS, i)
    end
end

function gamelogic.initDeskInfo(deskInfo)
    deskInfo.config = config
    deskInfo.records = {}
end

function gamelogic.getResult()
    table.shuffle(gamelogic.NUMBERS)
    local result = {}
    for i = 1, 10 do
        table.insert(result, gamelogic.NUMBERS[i])
    end
    return result
end

function gamelogic.calcWinMult(nums, lottery_nums)
    local size = #nums
    local cnt = 0
    for _, num in ipairs(nums) do
        if table.contain(lottery_nums, num) then
            cnt = cnt + 1
        end
    end
    if cnt > 0 then
       return config.multipliers[size][cnt]
    end
    return 0
end

function gamelogic.tryGetRestrictiveResult(betcoin, nums, restriction)
    local result = nil
    for trycnt = 1, 100 do
        result = gamelogic.getResult()
        if restriction == 0 then
            break
        end
        local mult = gamelogic.calcWinMult(nums, result)
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
    local ret = {code = PDEFINE.RET.SUCCESS, spcode=0, c=msg.c, betcoin=msg.betcoin, nums=msg.nums}
    local betcoin = tonumber(msg.betcoin) or 0
    local nums = msg.nums
    if (betcoin < config.minbet) or (type(nums) ~= "table") or (#nums < 1) or (#nums > 10) then
        LOG_DEBUG("params error", betcoin, nums)
        ret.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return ret
    end
    for i = 1, #nums do
        nums[i] = math.sfloor(nums[i])
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
    local lottery_nums = gamelogic.tryGetRestrictiveResult(betcoin, nums, restriction)
    local mult = gamelogic.calcWinMult(nums, lottery_nums)
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
    local settle = {mult=mult, nums=nums, lottery_nums=lottery_nums}
    delegate.recordGameLog(deskInfo, betcoin, wincoin, settle, tax)
    --更新策略数据
    if user.cluster_info and user.istest ~= 1 then
        delegate.updateStrategyData(betcoin, wincoin)
    end
    --游戏记录
    local result = {mult=mult, lottery_nums=lottery_nums}
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
        nums = {1,12,24,36},     --下注数字
    }
    --返回
    {
        c = 44,
        spcode = 0,     --错误码，0表示正常
        nums = {1,12,...},
        result = {
            lottery_nums = {1,2,3,4,...}, --开奖数字
            mult = 1.2, --中奖倍数
        }
        wincoin = 0,    --赢分
    }
]]