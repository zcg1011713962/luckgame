require "design.common"

local seed = tonumber(tostring(os.time()):reverse():sub(1, 7))
math.randomseed(seed)

local config = {
    -- 骰子点数
    Cards = {
        1, 2, 3, 4, 5, 6,
    },
    -- 方位数量
    PlaceCount = 3,
    -- 押注方位
    Places = {
        P_2_6 = 1,     --2-6
        P_8_12 = 2,    --8-12
        P_7 = 3        --7
    },
    -- 方位倍数
    Multiples = {2, 2, 5},
}

local PROBABILTY_GOLD_DICE_2_6 = 0.0025 --金骰子概率
local PROBABILTY_GOLD_DICE_7 = 0.0020 --金骰子概率
local PROBABILTY_GOLD_DICE_8_12 = 0.0015 --金骰子概率

local gamelogic = {}

function gamelogic.getResult(deskInfo)
    local cards1 = table.shuffle(config.Cards)
    local cards2 = table.shuffle(config.Cards)
    local result = {
        c1 = cards1[1],
        c2 = cards2[2],
        point = 0,
        res = 0,  --1:"2-6" 2:"8-12" 3:"7"
        gold = 0, --金骰子
    }
    local point = result.c1 + result.c2
    result.point = point
    local probabilty_gold = 0
    if point < 7 then
        result.res = config.Places.P_2_6
        probabilty_gold = PROBABILTY_GOLD_DICE_2_6
    elseif point > 7 then
        result.res = config.Places.P_8_12
        probabilty_gold = PROBABILTY_GOLD_DICE_7
    else
        result.res = config.Places.P_7
        probabilty_gold = PROBABILTY_GOLD_DICE_8_12
    end
    if math.random() < probabilty_gold then
        result.gold = 1
    end
    return result
end

local function test()
    local total = 1000000
    local stat = {}
    table.fill(stat, 0, config.PlaceCount)
    for i = 1, total do
        local result = gamelogic.getResult()
        if result.gold == 1 then
            for _ = 1, config.PlaceCount do
                stat[result.res] = stat[result.res] + 1
            end
        else
            stat[result.res]  = stat[result.res] + 1
        end
    end
    for i = 1, config.PlaceCount do
        PRINT(i, stat[i], total/stat[i], config.Multiples[i])
    end
end

test()