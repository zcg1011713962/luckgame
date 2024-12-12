require "design.common"
local baseUtil = require "game.base.utils"

local seed = tonumber(tostring(os.time()):reverse():sub(1, 7))
math.randomseed(seed)


-------------------- 游戏配置 --------------------
local config = {
    -- 0x4* 为黑桃, 0x3*为红桃，, 0x2*为梅花, 0x1*为方块
    Cards = {
        0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,
        0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,
        0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,
        0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,
    },
    -- 方位数量
    PlaceCount = 10,
    -- 押注方位
    Places = {
        Andar = 1,     --Andar
        Bahar = 2,     --Bahar
        P_1_5 = 3,      --1-5
        P_6_10 = 4,     --6-10
        P_11_15 = 5,
        P_16_25 = 6,
        P_26_30 = 7,
        P_31_35 = 8,
        P_36_40 = 9,
        P_41 = 10,
    },
    -- 方位倍数
    Multiples = {1.9, 2, 3.5, 4.5, 5.5, 4.5, 15, 25, 50, 120},
}

local gamelogic = {}

function gamelogic.getResult()
    local andercards = {}
    local baharcards = {}
    local res = 0
    table.shuffle(config.Cards)
    gamelogic.cards = table.copy(config.Cards)
    local joker = table.remove(gamelogic.cards)
    local jokervalue = baseUtil.ScanValue(joker)
    for i = 1, 52 do
        local card = table.remove(gamelogic.cards)
        if i % 2== 1 then
            table.insert(andercards, card)
            res = config.Places.Andar
        else
            table.insert(baharcards, card)
            res = config.Places.Bahar
        end
        if baseUtil.ScanValue(card) == jokervalue then
            break
        end
    end

    local result = {
        andercards = andercards,
        baharcards = baharcards,
        joker = joker,
        res = res,      --中奖结果
        winplace = {}   --中奖位置
    }
    --直接中奖区域
    table.insert(result.winplace, res)
    --数量中奖区域
    local count = #andercards + #baharcards
    if count <= 5 then
        table.insert(result.winplace, config.Places.P_1_5)
    elseif count <= 10 then
        table.insert(result.winplace, config.Places.P_6_10)
    elseif count <= 15 then
        table.insert(result.winplace, config.Places.P_11_15)
    elseif count <= 25 then
        table.insert(result.winplace, config.Places.P_16_25)
    elseif count <= 30 then
        table.insert(result.winplace, config.Places.P_26_30)
    elseif count <= 35 then
        table.insert(result.winplace, config.Places.P_31_35)
    elseif count <= 40 then
        table.insert(result.winplace, config.Places.P_36_40)
    else
        table.insert(result.winplace, config.Places.P_41)
    end

    return result
end

local function test()
    local total = 1000000
    local stat = {}
    local cardlen = 0
    table.fill(stat, 0, 10)
    for i = 1, total do
        local result = gamelogic.getResult()
        for _, p in ipairs(result.winplace) do
            stat[p] = stat[p] + 1
        end
        cardlen = cardlen + #result.andercards
    end
    PRINT("cardlen", cardlen/total)
    for i = 1, config.PlaceCount do
        PRINT(i, stat[i], total/stat[i], config.Multiples[i])
    end
end

test()