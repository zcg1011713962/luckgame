--[[
    777 小游戏，调用组件获得结果
]]

local function genRandIdxs(total, num)
    if total < num then
        return nil
    end
    local totalIdxs = {}
    for i = 1, total do
        local pos = math.random(i)
        table.insert(totalIdxs, pos, i)
    end
    local randIdxs = {}
    for i = 1, num do
        table.insert(randIdxs, totalIdxs[i])
    end
    return randIdxs
end


local function randByWeight(tbl, num)
    local totalWeight = 0
    for _, value in pairs(tbl) do
        totalWeight = totalWeight + value.weight
    end
    -- 如果权重都为空，则返回nil
    if totalWeight == 0 then
        return nil, nil
    end
    if num then
        local idxs = {}
        local values = {}
        for i = 1, num do
            local currWeight = 0
            local randNum = math.random(totalWeight)
            for idx, value in pairs(tbl) do
                currWeight = currWeight + value.weight
                if randNum <= currWeight then
                    table.insert(idxs, idx)
                    table.insert(values, value)
                    break
                end
            end
        end
        return idxs, values
    else
        local currWeight = 0
        local randNum = math.random(totalWeight)
        for idx, value in pairs(tbl) do
            currWeight = currWeight + value.weight
            if randNum <= currWeight then
                return idx, value
            end
        end
    end
end

local game = {}

game.Type = {
    Diamond = 1,  -- 钻石 2x 3x 5x
    Seven = 2,  -- 红色7 蓝色7
    Bar = 3,  -- bar  1行，2行，3行
}

game.Cards = {
    Diamond5 = 1,  -- 钻石x5
    Diamond3 = 2,  -- 钻石x3
    Diamond2 = 3,  -- 钻石x2
    Red7 = 4,  -- 红色7
    Blue7 = 5,  -- 蓝色7
    Bar3 = 6,  -- 3行bar
    Bar2 = 7,  -- 2行bar
    Bar1 = 8,  -- 1行bar
}

game.Groups = {
    [1] = {cards={game.Cards.Diamond2,game.Cards.Diamond3,game.Cards.Diamond5}, mixed=1, mult=3117, weight=1},
    [2] = {cards={game.Cards.Red7,game.Cards.Red7,game.Cards.Red7}, mixed=0, mult=25, weight=1},
    [3] = {cards={game.Cards.Blue7,game.Cards.Blue7,game.Cards.Blue7}, mixed=0, mult=9, weight=1},
    [4] = {cards={game.Cards.Red7, game.Cards.Blue7}, mixed=1, mult=7.5, weight=1},
    [5] = {cards={game.Cards.Bar3,game.Cards.Bar3,game.Cards.Bar3}, mixed=0, mult=9.4, weight=1},
    [6] = {cards={game.Cards.Bar2,game.Cards.Bar2,game.Cards.Bar2}, mixed=0, mult=7.5, weight=1},
    [7] = {cards={game.Cards.Bar1,game.Cards.Bar1,game.Cards.Bar1}, mixed=0, mult=5, weight=1},
    [8] = {cards={game.Cards.Bar1,game.Cards.Bar2,game.Cards.Bar3}, mixed=1, mult=2.5, weight=1},
}

-- 返回随机到的3个图标，以及相应的赢钱倍数
game.generate = function()
    local _, item = randByWeight(game.Groups)
    local cards = {}
    if item.mixed then
        local randCards = {}
        for i = 1, 2, 1 do
            for _, c in ipairs(item.cards) do
                table.insert(randCards, c)
            end
        end
        local idxs = genRandIdxs(#randCards, 3)
        for _, idx in ipairs(idxs) do
            table.insert(cards, randCards[idx])
        end
    else
        for _, c in ipairs(item.cards) do
            table.insert(cards, c)
        end
    end
    return cards, item.mult
end

local function test()
    math.randomseed(tostring(os.time()):reverse():sub(1, 7))
    local cards, mult = game.generate()
    print(table.concat(cards, " "))
    print(mult)
end

-- test()

return game