require "design.common"
local baseUtil = require "game.base.utils"

local seed = tonumber(tostring(os.time()):reverse():sub(1, 7))
math.randomseed(seed)


-------------------- 游戏配置 --------------------
local config = {
    Cards = {
        1, 2, 3, 4, 5, 6
    },
    -- 方位数量
    PlaceCount = 6,
    -- 押注方位
    Places = {
        Diamond = 1,-- 方块
        Club = 2,   -- 梅花
        Flag = 3,   -- 旗帜
        Crown = 4,  -- 皇冠
        Heart = 5,  -- 红心
        Spade = 6,  -- 黑桃
    },
    -- 中奖倍数
    Multiples = {
        [0] = 0,
        [1] = 0,
        [2] = 2.5,
        [3] = 5,
        [4] = 10,
        [5] = 20,
        [6] = 100,
    },
}

local gamelogic = {}

function gamelogic.getResult(deskInfo)
    local result = {
        cards = {},                 --中奖牌型
        res = {0, 0, 0, 0, 0, 0},   --各区域牌数量
        mults = {0, 0, 0, 0, 0, 0}, --各区域中奖倍数
    }
    --产生6张牌
    for i = 1, 6 do
        local cards = table.shuffle(config.Cards)
        local card = cards[1]
        table.insert(result.cards, card)
        result.res[card] = result.res[card] + 1
        result.mults[card] = config.Multiples[result.res[card]]
    end
    return result
end

local function test()
    local total = 1000000
    local stat = {}
    local totalmult = 0
    table.fill(stat, 0, 10)
    for i = 1, total do
        local result = gamelogic.getResult()
        for j, mult in ipairs(result.mults) do
            stat[j] = stat[j] + mult
            totalmult = totalmult + mult
        end
    end
    for i = 1, config.PlaceCount do
        PRINT(i, stat[i], totalmult/stat[i], config.PlaceCount)
    end
end

test()