

--------累计概率随机触发方法 begin------

--修正系数表(根据统计得到)
local CF_TBL = {
    {r=1, f=1.0215},
    {r=3, f=1.0270},
    {r=5, f=1.0300},
    {r=8, f=1.0326},
    {r=10, f=1.0343},
    {r=12, f=1.0356},
    {r=18, f=1.0416},
    {r=20, f=1.0442},
    {r=30, f=1.0530},
    {r=50, f=1.0656},
    {r=75, f=1.0828},
    {r=100, f=1.096},
    {r=150, f=1.1201},
    {r=200, f=1.1860},
}

--按线性插值方法得到修正值
local function getCorrectionFactor(ratio)
    if ratio < 1 then
        return CF_TBL[1].f
    end
    local size = #CF_TBL
    if ratio >= CF_TBL[size].r then
        return CF_TBL[size].f
    end
    for i = 1, #CF_TBL do
        local v1 = CF_TBL[i]
        local v2 = CF_TBL[i+1]
        if ratio >= v1.r and ratio < v2.r then
            local p = (ratio-v1.r)/(v2.r - ratio)
            return v1.f*(1-p) + v2.f*p
        end
    end
end

--根据基础概率和累计增幅得到触发概率
local function getTriggerFreq(baseRatio, consecutiveNonTriggeringCount)
    if true then
        return baseRatio
    end
    if baseRatio <= 0 or baseRatio > 200 then
        return baseRatio
    end
    local ratio = baseRatio
    local factor = getCorrectionFactor(baseRatio)
    local averageTriggerCount = 1000/baseRatio
    if consecutiveNonTriggeringCount > averageTriggerCount then
        ratio = ratio * (consecutiveNonTriggeringCount/averageTriggerCount)
    elseif consecutiveNonTriggeringCount < averageTriggerCount * 0.25 then
        ratio = ratio * (consecutiveNonTriggeringCount/averageTriggerCount) * 2
    end
    return ratio * factor
end

--------累计概率随机触发方法 end------



-- 取加权绝对值最大的概率值
local function getRateByAbsolutelyWeight(rates, weights)
    local maxValue = 0
    local maxIndex = 1
    for i = 1, #rates do
        local value = math.abs((rates[i]-1)*weights[i])
        if maxValue < value then
            maxValue = value
            maxIndex = i
        end
    end
    return rates[maxIndex]
end

-- 取不超过大小范围的值
local function checkValue(value, min, max)
    if min <= max then
        return math.min(math.max(value, min), max)
    else
        return math.min(math.max(value, max), min)
    end
end

-- 获取范围随机值
local function randomRange(center, radius)
    return center + (math.random()*2-1) * radius
end

local function pow(x, y)
    if math.pow then
        return math.pow(x, y)
    else
        return  x^y
    end
end

return {
    getRateByAbsolutelyWeight = getRateByAbsolutelyWeight,
    getTriggerFreq = getTriggerFreq,
    checkValue = checkValue,
    randomRange = randomRange,
    pow = pow,
}