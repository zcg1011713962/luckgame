--押注类百人游戏工具

local EXTEND_MULT = 100000 -- 扩大10万倍

local function getRandomIdxByMultiples(mults)
    local weights = {}
    local total = 0
    for _, mult in ipairs(mults) do
        local weight = math.floor(1.0 / mult * EXTEND_MULT + 0.5)
        table.insert(weights, weight)
        total = total + weight
    end
    local rand = math.random(1, total)
    local currWeight = 0
    for idx, weight in pairs(weights) do
        currWeight = currWeight + weight
        if currWeight >= rand then
            return idx
        end
    end
    return 1
end

local function getRandomIdxByMultiplesWithCnt(mults, cnt)
    local weights = {}
    local total = 0
    for _, mult in ipairs(mults) do
        -- 这里要判断下，是否有零值，零值代表不能中
        local weight = mult == 0 and 0 or math.floor(1.0 / mult * EXTEND_MULT + 0.5)
        table.insert(weights, weight)
        total = total + weight
    end
    if not cnt or cnt == 1 then
        local rand = math.random(1, total)
        local currWeight = 0
        for idx, weight in pairs(weights) do
            currWeight = currWeight + weight
            if currWeight >= rand then
                return idx
            end
        end
        return 1
    else
        local res = {}
        for i = 1, cnt, 1 do
            local rand = math.random(1, total)
            local currWeight = 0
            for idx, weight in pairs(weights) do
                currWeight = currWeight + weight
                if currWeight >= rand then
                    table.insert(res, idx)
                    total = total - weight
                    weights[idx] = 0
                    break
                end
            end
        end
        return res
    end
end

local function randomIndex(tbl)
    local total = 0
    for _, value in ipairs(tbl) do
        total = total + value
    end
    -- 如果权重都为空，则返回nil
    if total == 0 then
        return 0
    end

    local curr = 0
    local rand = math.random(total)
    for idx, value in ipairs(tbl) do
        curr = curr + value
        if rand <= curr then
            return idx
        end
    end
end

-- 随机获取num个数，范围是[1, total]
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

local function calcTax(betcoin, wincoin, taxrate)
    taxrate = math.max(0, taxrate)
    if wincoin > betcoin then
        return math.round_coin(taxrate * (wincoin - betcoin))
    end
    return 0
end

return {
    getRandomIdxByMultiples = getRandomIdxByMultiples,
    getRandomIdxByMultiplesWithCnt = getRandomIdxByMultiplesWithCnt,
    randomIndex = randomIndex,
    calcTax = calcTax,
    genRandIdxs = genRandIdxs,
}