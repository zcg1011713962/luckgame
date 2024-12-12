require "design.common"
local baseUtil = require "game.base.utils"
local betUtil = require "game.betgame.betutils"

local seed = tonumber(tostring(os.time()):reverse():sub(1, 7))
math.randomseed(seed)

local config = {
    -- 1~6，共6匹马
    Cards = {
        1,2,3,4,5,6
    },
    -- 方位数量
    PlaceCount = 6,
}

-- 每把开始都生成几率
local function randomOdds()
    local odds = {} --赔率表
    local total = math.random(380, 450)
    --有一个30~45的数, 一个40~59的数， 一个90~120的数，其他在60~90之间随机
    --其他的随意
    table.insert(odds, math.random(30, 45))
    while true do
        local rand = math.random(40, 59)
        if not table.contain(odds, rand) then
            table.insert(odds, rand)
            break
        end
    end
    table.insert(odds, math.random(90, 120))
    for i = 1, 2 do
        while true do
            local rand = math.random(60, 90)
            if not table.contain(odds, rand) then
                table.insert(odds, rand)
                break
            end
        end
    end
    local s = table.sum(odds)
    local last = total-s
    if last <= 20 then
        for i = 1, #odds do
            odds[i] = odds[i] - 5
            last = last + 5
        end
    end
    table.insert(odds, last)
    table.shuffle(odds)
    for i = 1, #odds do
        odds[i] = odds[i]/10
    end
    return odds
end

local gamelogic = {}

function gamelogic.getResult(deskInfo)
    local result = {}
    result.res = betUtil.getRandomIdxByMultiples(deskInfo.round.odds)
    return result
end

local function test()
    local total = 1000000
    local stat = {}
    local wintotal = 0
    table.fill(stat, 0, config.PlaceCount)
    local deskInfo = {round = {}}
    for i = 1, total do
        deskInfo.round.odds = randomOdds()
        local result = gamelogic.getResult(deskInfo)
        local winMult = deskInfo.round.odds[result.res]  --赢分倍数
        stat[result.res]  = stat[result.res] + winMult
        wintotal = wintotal + winMult
    end
    for i = 1, config.PlaceCount do
        PRINT(i, stat[i], wintotal/stat[i], config.PlaceCount)
    end
end

test()