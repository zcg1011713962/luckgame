require "design.common"
local baseUtil = require "game.base.utils"
local betUtil = require "game.betgame.betutils"

local seed = tonumber(tostring(os.time()):reverse():sub(1, 7))
math.randomseed(seed)


-------------------- 游戏配置 --------------------
local config = {
    Cards = {
        1, 2, 3, 4, 5
    },
    -- 方位数量
    PlaceCount = 5,
    -- 押注方位
    Places = {
        Apple = 1,  -- 苹果
        Kiwifruit = 2,-- 猕猴桃
        Grape = 3,  -- 葡萄
        Banana = 4, -- 香蕉
        Orange = 5, -- 橙子
    },
    --中奖结果，分别表示: 苹果2, 葡萄10, 橙子2, 猕猴桃8, 香蕉2, 苹果5, 葡萄2, 橙子50, 猕猴桃2, 香蕉20
    Results = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
    -- 中奖倍数
    Multiples = {2, 10, 2, 8, 2, 5, 2, 50, 2, 20},
    --中奖结果映射中奖区域
    ResultToPlace = {1, 3, 5, 2, 4, 1, 3, 5, 2, 4},
}

local gamelogic = {}

function gamelogic.getResult()
    local result = {
        res = 0,
        winplace = 0,
    }
    result.res = betUtil.getRandomIdxByMultiples(config.Multiples)
    result.winplace = config.ResultToPlace[result.res]
    return result
end

local function test()
    local total = 1000000
    local stat = {}
    local wintotal = 0
    table.fill(stat, 0, config.PlaceCount)
    for i = 1, total do
        local result = gamelogic.getResult()
        local winMult = config.Multiples[result.res]  --赢分倍数
        stat[result.winplace]  = stat[result.winplace] + winMult
        wintotal = wintotal + winMult
    end
    for i = 1, config.PlaceCount do
        PRINT(i, stat[i], wintotal/stat[i], config.PlaceCount)
    end
end


test()