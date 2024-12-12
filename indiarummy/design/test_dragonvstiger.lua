require "design.common"
local baseUtil = require "game.base.utils"

local seed = tonumber(tostring(os.time()):reverse():sub(1, 7))
math.randomseed(seed)


local config = {
    -- 0x4* 为黑桃, 0x3*为红桃，, 0x2*为梅花, 0x1*为方块
    Cards = {
        0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,
        0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,
        0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,
        0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,
    },
    -- 方位数量
    PlaceCount = 3,
    -- 押注方位
    Places = {
        Dragon = 1,     --龙
        Tiger = 2,      --虎
        Tie = 3         --和
    },
    -- 方位倍数
    Multiples = {2, 2, 9},
}

local gamelogic = {}

function gamelogic.getResult()
    local cards = table.shuffle(config.Cards)
    local result = {
        c1 = cards[1],
        c2 = cards[2],
        res = config.Places.Tie,  --1:Dragon赢 2:Tiger赢 3:平局 
    }
    local v1 = baseUtil.ScanValue(result.c1)
    if baseUtil.IsAce(result.c1) then
        v1 = 1
    end
    local v2 = baseUtil.ScanValue(result.c2)
    if baseUtil.IsAce(result.c2) then
        v2 = 1
    end
    if v1 > v2 then
        result.res = config.Places.Dragon
    elseif v1 < v2 then
        result.res = config.Places.Tiger
    end
    return result
end

local function test()
    local total = 1000000
    local stat = {}
    table.fill(stat, 0, config.PlaceCount)
    for i = 1, total do
        local result = gamelogic.getResult()
        stat[result.res]  = stat[result.res] + 1
    end
    for i = 1, config.PlaceCount do
        PRINT(i, stat[i], total/stat[i], config.Multiples[i])
    end
end

test()