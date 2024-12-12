-- 通用方法

-------------------------------------------------------------------
-- 将一个列表随机打乱
-- eg: tbl = {1, 2, 3, 4, 5}
-------------------------------------------------------------------
local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end

-------------------------------------------------------------------
-- 根据weight来计算出随机结果
-- 只要在子对象中设有weight字段，就可以使用该函数来随机出一个子项
-- eg: tbl = {
--    {id=1, weight=5},
--    {id=2, weight=6},
--    {id=3, weight=7},
-- }
-------------------------------------------------------------------

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

-------------------------------------------------------------------
-- 从指定序号中，随机出指定数量的随机数
-- eg: genRandIdxs(10, 3) = {3, 10, 4}
-------------------------------------------------------------------
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

-------------------------------------------------------------------
-- 传入行列，和图标位置，获取四周的位置
-- 如果传入full, 则代表取四周，否则取上下左右
-- eg: getAroundIdxs(4, 5, 11, true) = {6, 7, 12，16，17}
-------------------------------------------------------------------
local function getAroundIdxs(maxRow, maxCol, idx, full)
    local aroundIdxs = {}  -- 四周的位置
    local currCol = math.fmod(idx, maxCol)
    if currCol == 0 then
        currCol = maxCol
    end
    local currRow = math.ceil(idx/maxCol)
    if currCol < maxCol then
        table.insert(aroundIdxs, idx + 1)
        if currRow > 1 and full then
            table.insert(aroundIdxs, idx - maxCol + 1)
        end
        if currRow < maxRow and full then
            table.insert(aroundIdxs, idx + maxCol + 1)
        end
    end
    if currCol > 1 then
        table.insert(aroundIdxs, idx - 1)
        if currRow > 1 and full then
            table.insert(aroundIdxs, idx - maxCol - 1)
        end
        if currRow < maxRow and full then
            table.insert(aroundIdxs, idx + maxCol - 1)
        end
    end
    if currRow > 1 then
        table.insert(aroundIdxs, idx - maxCol)
    end
    if currRow < maxRow then
        table.insert(aroundIdxs, idx + maxCol)
    end
    return aroundIdxs
end

-------------------------------------------------------------------
-- 此函数主要用于事先知道结果，然后逆推每次中的数量
-- 比如结果需要中10个bonus图标，然后分6次中，那需要将次数分摊到每一次
-- 打散原理，将两个不同的值(1,2)分别代表中图标和结束中图标，放到一个列表，然后打散
-- 然后轮询取值，碰到1，代表此次中的图标+1, 碰到2代表此次中图标结束，进行新的一轮spin
-- eg: breakUpResult(10, 6) = {1, 5, 3, 0, 0, 1}
-------------------------------------------------------------------
local function breakUpResult(ResultCnt, spinCnt)
    local finalResult = {}
    local totalItems = {}
    local ItemType = {
        HitResult = 1,  -- 中图标
        NewTurn = 2,  -- 新的一轮
    }
    for i = 1, ResultCnt do
        table.insert(totalItems, ItemType.HitResult)
    end
    for i = 1, spinCnt-1 do
        table.insert(totalItems, ItemType.NewTurn)
    end
    -- 打散结果
    shuffle(totalItems)
    -- 取出最终结果
    local currResult = 0
    for _, item in ipairs(totalItems) do
        if item == ItemType.HitResult then
            currResult = currResult + 1
        elseif item == ItemType.NewTurn then
            -- 插入次轮结果
            table.insert(finalResult, currResult)
            currResult = 0
        end
    end
    table.insert(finalResult, currResult)
    return finalResult
end

-------------------------------------------------------------------
-- 此函数主要用地图游戏，中间列wild随机m, n之间的倍数
-- 由于高倍数的概率一定要低，所以需要用函数来随机一个值
-- 比如随机5-100之间的倍数，那么分布在前面的要多，后面的要少
-- 函数参数，需要传递最小值min, 最大值nax, 一个中间点middle, 一个方差值
-- eg: breakUpResult(3, 100, 5, 10) = 9
-------------------------------------------------------------------
local function randGaussNum(min, max, middle, space)
    local x
    repeat
       x = math.ceil(math.log(1/math.random())^.5*math.cos(math.pi*math.random())*space+middle)
    until x >= min and x <= max
    return x
end

--生成正态分布的随机变量
--中心极限定理取值范围[-6,6]
local function randomNormal()
    local s = 0
    for _ = 1, 12 do
        s = s + math.random()
    end
    return s-6
end


return {
    shuffle = shuffle,
    randByWeight = randByWeight,
    genRandIdxs = genRandIdxs,
    getAroundIdxs = getAroundIdxs,
    breakUpResult = breakUpResult,
    randGaussNum = randGaussNum,
    randomNormal = randomNormal,
}
