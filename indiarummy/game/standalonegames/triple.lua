--[[
    Triple
    1. 6x6的格子，每个格子有一个水果，一共有三种水果，🍌*27，🍒*6，🍉*3
    2. 10种组合，每种组合有不同的赔率
    3. 一共有三种下注方式，分别是容易，中等，困难，每种下注方式对应的赔率不一样
    4. 选中3个格子开奖，如果对应的组合有奖，则按照对应的赔率进行赔付
]]

local config = {
    minbet = 1,
    maxbet = 1000,
    itemCnt = {27, 6, 3},  -- 对应物品的数量
    ---@field items integer[] @三个物品的id 1:🍌 2:🍒 3:🍉
    ---@field mult integer[] @对应3个难度等级的赔率
    comboInfo = {
        [1]  = {items={1, 1, 1}, mult={0.5, 0,   0}},    -- 🍌🍌🍌
        [2]  = {items={1, 1, 2}, mult={0.8, 0.5, 0}},    -- 🍌🍌🍒
        [3]  = {items={1, 1, 3}, mult={1.2, 1.5, 0.5}},  -- 🍌🍌🍉
        [4]  = {items={1, 2, 3}, mult={1.5, 2.4, 3}},    -- 🍌🍒🍉
        [5]  = {items={1, 2, 2}, mult={2.1, 3,   4.2}},  -- 🍌🍒🍒
        [6]  = {items={1, 3, 3}, mult={3.5, 6.7, 9}},    -- 🍌🍉🍉
        [7]  = {items={2, 2, 3}, mult={4.5, 10,  15}},   -- 🍒🍒🍉
        [8]  = {items={2, 2, 2}, mult={7,   15,  30}},   -- 🍒🍒🍒
        [9]  = {items={2, 3, 3}, mult={15,  30,  60}},   -- 🍒🍉🍉
        [10] = {items={3, 3, 3}, mult={40,  80,  200}},  -- 🍉🍉🍉
    },
}

-- 根据给出的条件，优化结果
---@param allItem integer[] @所有的物品排布
---@param idxs integer[] @选中的物品的下标
---@param risk integer @难度等级 1:容易 2:中等 3:困难
---@param restriction integer @限制条件 -1 输, 0 随机, 1 赢
local function optimizeResult(allItem, idxs, risk, restriction)
    local res = {}
    local mult = 0
    local items = {}
    for _, idx in ipairs(idxs) do
        table.insert(items, allItem[idx])
    end
    table.sort(items)
    for _, combo in ipairs(config.comboInfo) do
        if combo.items[1] == items[1] and combo.items[2] == items[2] and combo.items[3] == items[3] then
            mult = combo.mult[risk]
        end
    end
    -- 是否需要优化
    if mult > 1 and restriction == -1 then
        items = {}
        -- 找出一个mult<1的组合
        local combos = {}
        for _, combo in ipairs(config.comboInfo) do
            if combo.mult[risk] < 1 then
                table.insert(combos, combo)
            end
        end
        -- 随机选一个组合
        local combo = combos[math.random(1, #combos)]
        -- 从allItem中找出对应的下标
        for i, item in ipairs(combo.items) do
            -- 需要替换的坐标
            local replaceIdx = idxs[i]
            -- 选中的坐标
            local targetIdx = nil
            -- 随机一个下标，然后前后辐射找自己需要的下标, 且不能是选中的下标
            local idx = math.random(1, #allItem)
            if item == allItem[idx] and not table.contain(idxs, idx) then
                targetIdx = idx
            else
                local left = idx - 1
                local right = idx + 1
                while left > 0 or right <= #allItem do
                    if left > 0 and item == allItem[left] and not table.contain(idxs, left) then
                        targetIdx = left
                        break
                    end
                    if right <= #allItem and item == allItem[right] and not table.contain(idxs, right) then
                        targetIdx = right
                        break
                    end
                    left = left - 1
                    right = right + 1
                end
            end
            table.insert(items, item)
            allItem[targetIdx] = allItem[replaceIdx]
            allItem[replaceIdx] = item
        end
    end
    res = items
    -- 再算一遍赔率
    for _, combo in ipairs(config.comboInfo) do
        if combo.items[1] == items[1] and combo.items[2] == items[2] and combo.items[3] == items[3] then
            mult = combo.mult[risk]
        end
    end
    return res, mult
end

local gamelogic = {}

function gamelogic.create(gameid)
end

function gamelogic.initDeskInfo(deskInfo)
    deskInfo.config = config
    deskInfo.records = {}
end

function gamelogic.getResult()
    local result = {}
    for item, cnt in ipairs(config.itemCnt) do
        for i = 1, cnt, 1 do
            table.insert(result, item)
        end
    end
    shuffle(result)
    return result
end

function gamelogic.tryGetRestrictiveResult()
end

---@param deskInfo any
---@param msg any
---@param delegate StandaloneAgentDelegate
function gamelogic.start(deskInfo, msg, delegate)
    local ret = {code = PDEFINE.RET.SUCCESS, spcode=0, c=msg.c, betcoin=msg.betcoin}
    local betcoin = msg.betcoin
    local risk = msg.risk or 1 -- 难度等级 1:容易 2:中等 3:困难
    local idxs = msg.idxs
    if not idxs or #idxs ~= 3 then
        ret.code = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return ret
    end 
    if betcoin < config.minbet then
        ret.code = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return ret
    end
    if risk < 1 or risk > 3 then
        ret.code = PDEFINE.RET.ERROR.PARAM_ILLEGAL
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
    local allItem = gamelogic.getResult()
    local restriction = delegate.getRestriction()  --0：随机 -1：输 1：赢
    -- 计算结果和赔率
    local res, mult = optimizeResult(allItem, idxs, risk, restriction)
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
    local settle = {mult=mult, idxs=idxs, res=res}
    delegate.recordGameLog(deskInfo, betcoin, wincoin, settle, tax)
    --更新策略数据
    if user.cluster_info and user.istest ~= 1 then
        delegate.updateStrategyData(betcoin, wincoin)
    end
    --游戏记录
    local result = {mult=mult, idxs=idxs, res=res}
    table.insert(deskInfo.records, result)
    if #(deskInfo.records) > 100 then
        table.remove(deskInfo.records, 1)
    end
    ret.idxs = idxs
    ret.risk = risk
    ret.allItem = allItem
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
        config = {
            minbet = 1,
            maxbet = 1000,
            itemCnt = {27, 6, 3},  -- 对应物品的数量
            ---@field items integer[] @三个物品的id 1:🍌 2:🍒 3:🍉
            ---@field mult integer[] @对应3个难度等级的赔率
            comboInfo = {
                [1]  = {items={1, 1, 1}, mult={0.5, 0,   0}},    -- 🍌🍌🍌
                [2]  = {items={1, 1, 2}, mult={0.8, 0.5, 0}},    -- 🍌🍌🍒
                [3]  = {items={1, 1, 3}, mult={1.2, 1.5, 0.5}},  -- 🍌🍌🍉
                [4]  = {items={1, 2, 3}, mult={1.5, 2.4, 3}},    -- 🍌🍒🍉
                [5]  = {items={1, 2, 2}, mult={2.1, 3,   4.2}},  -- 🍌🍒🍒
                [6]  = {items={1, 3, 3}, mult={3.5, 6.7, 9}},    -- 🍌🍉🍉
                [7]  = {items={2, 2, 3}, mult={4.5, 10,  15}},   -- 🍒🍒🍉
                [8]  = {items={2, 2, 2}, mult={7,   15,  30}},   -- 🍒🍒🍒
                [9]  = {items={2, 3, 3}, mult={15,  30,  60}},   -- 🍒🍉🍉
                [10] = {items={3, 3, 3}, mult={40,  80,  200}},  -- 🍉🍉🍉
            },
        },  --配置表
        records = {
            {mult=27.55, idxs={11,2,12}, result={1,2,3}},
            ...
        },   --游戏记录  idxs是选择的位置, result是开奖结果
    }

--交互协议
    --玩家押注(C->S)
    {
        c = 44,
        betcoin = 10,   --押注金额
        idxs = 1,     -- 选择的位置
        risk = 1,  -- 难度等级 1:容易 2:中等 3:困难
    }
    --返回
    {
        c = 44,
        spcode = 0,     --错误码，0表示正常
        risk = 1, -- 难度等级 1:容易 2:中等 3:困难
        result = {1,2,3},  -- 开奖的3个结果，按照顺序来，跟idxs不对应
        allItem = {}， -- 36格子的结果
        idxs = {11,12,13},     -- 选择的位置
        wincoin = 0,    --赢分
        mult = 1.94,   --倍数
    }
]]