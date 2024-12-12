--[[
-- Author: 
-- Date: 2019-02-13
-- 功能描述:
    -- 金钱相关
]] 

--算分规则
local config = require"cashslots.common.config"

local function getCardValue(card, is_and)
    return is_and and card & 0x0F or card
end

-- 找出不是万能牌的那一张牌
local function getNotWild(wilds, cards, traceRs)
    local tmp = wilds[1]
    for _, idx in pairs(traceRs) do
         if not table.contain(wilds, cards[idx]) then
             tmp = cards[idx]
             return tmp
         end
    end
    return tmp
end


 -- 是否包含万能牌
local function getWildIdxs(wilds, cards, traceRs)
    local wIdxs = {}
   for _, idx in pairs(traceRs) do
        if table.contain(wilds, cards[idx]) then
           table.insert(wIdxs, idx)
        end
   end
   return wIdxs
end

-- 反转一个表 {1, 2, 3, 4, 5} ==>> {5, 4, 3, 2, 1}
local function reverseTable(tbl)
    local ret = {}
    for i = #tbl, 1, -1 do
        table.insert(ret, tbl[i])
    end
    return  ret
end

--取线路赢的那张牌
local function getWinCard(cards, tmpRs, wilds)
    local retCard = wilds[1]
    for _, idx in pairs(tmpRs) do
        local tmpCard = cards[idx]
        if not table.contain(wilds, tmpCard) then
            return cards[idx]
        end
    end
    return retCard
end

-- 过滤scatter 
local function filterScatter(cards, tmpRs, referCard, winCard )
    if referCard == nil or winCard ~= referCard then
        return tmpRs
    end
    if cards[tmpRs[1]] == referCard then
        return {}
    else
        for i = 1, #tmpRs do
            if cards[tmpRs[i]] == referCard then
                for j = #tmpRs, i, -1 do  -- 移除后面的scatter 保留前面的wild
                    table.remove(tmpRs, j)
                end
                return tmpRs
            end
        end
    end
    return tmpRs
end
-- 过滤diamons
local function filterDiamons(cards, tmpRs, referCard, winCard )
    if referCard == nil or winCard ~= referCard then
        return tmpRs
    end
    if cards[tmpRs[1]] == referCard then
        return {}
    else
        for i = 1, #tmpRs do
            if cards[tmpRs[i]] == referCard then
                for j = #tmpRs, i, -1 do  -- 移除后面的scatter 保留前面的wild
                    table.remove(tmpRs, j)
                end
                return tmpRs
            end
        end
    end
    return tmpRs
end

-- 过滤bonus
local function filterBonus(cards, tmpRs, referCard, winCard )
    if referCard == nil or winCard ~= referCard then
        return tmpRs
    end
    if cards[tmpRs[1]] == referCard then
        return {}
    else
        for i = 1, #tmpRs do
            if cards[tmpRs[i]] == referCard then
                for j = #tmpRs, i, -1 do  -- 移除后面的bonus 保留前面的wild
                    table.remove(tmpRs, j)
                end
                return tmpRs
            end
        end
    end
    return tmpRs
end

-- local function filterBonus(cards, tmpRs, referCard, winCard )
--     if referCard == nil or winCard ~= referCard then
--         return tmpRs
--     end
--     if cards[tmpRs[1]] == referCard then
--         for i = 1, #tmpRs do
--             if cards[tmpRs[i]] ~= referCard then
--                 for j = #tmpRs, i, -1 do  -- 移除后面的wilds 保留前面的bonus
--                     table.remove(tmpRs, j)
--                 end
--                 return tmpRs
--             end
--         end
--     else
--         for i = 1, #tmpRs do
--             if cards[tmpRs[i]] == referCard then
--                 for j = #tmpRs, i, -1 do  -- 移除后面的bonus 保留前面的wild
--                     table.remove(tmpRs, j)
--                 end
--                 return tmpRs
--             end
--         end
--     end
--     return tmpRs
-- end


--[[
如果游戏有2张万能牌，
如果该路线上赢牌是万能牌

那么要去掉另外一张万能牌替代的这张万能牌部分。

因为游戏：默认是万能牌不能够相互替换的

]] 
local function filterNoSameWild(cards, tmpRs, wilds, winCard)
    if #wilds <= 1 then
        return tmpRs
    end
    if not table.contain(wilds, winCard) then
        return tmpRs
    end

    local tmpWinCard
    for i, idx in ipairs(tmpRs) do
        if tmpWinCard == nil then
            tmpWinCard = cards[idx]
        elseif tmpWinCard ~= cards[idx] then
            for j = #tmpRs, i, -1 do  -- 移除后面的scatter 保留前面的wild
                table.remove(tmpRs, j)
            end
            return tmpRs
        end
    end
    return tmpRs
end

--[[
计算中奖路线 
]] 
local function caul(trace, cards, gameData, lineNum)
    local tmpRs = {}
    for i = 1, #trace do
        local curCard = cards[trace[i]]
        if table.contain(gameData.wilds, curCard)then
            table.insert(tmpRs, trace[i])
        else
            local canInsert = false
            if #tmpRs == 0 then  --如果是空列表
                canInsert = true
            else
                local tmpWinCard = getWinCard(cards, tmpRs, gameData.wilds)   -- 中奖的牌是万能牌或者和表里的牌一样
                if tmpWinCard == nil or tmpWinCard == curCard or table.contain(gameData.wilds, tmpWinCard) then
                    canInsert = true
                end
            end

            if canInsert  then
                table.insert(tmpRs, trace[i])
            else
                break
            end
        end
    end
    local winCard = getWinCard(cards, tmpRs, gameData.wilds) 
    if not gameData.wildReplaceAllWildB then
        tmpRs = filterNoSameWild(cards, tmpRs, gameData.wilds, winCard)
    end
    tmpRs = filterScatter(cards, tmpRs, gameData.scatter, winCard) 
    tmpRs = filterDiamons(cards, tmpRs, gameData.diamonds, winCard) 
    tmpRs = filterBonus(cards, tmpRs, gameData.bonus, winCard) 
    local tmpCard = getWinCard(cards, tmpRs, gameData.wilds)
    if tmpCard ~= nil and gameData.resultCfg[tmpCard] == nil then
        print("cards:", table.concat(cards, ","))
        print("tmpCard:", tmpCard)
        print("gameData.resultCfg:", gameData.resultCfg)
        assert(false, "tmpCard:"..tmpCard)
    end
    if tmpCard == nil or #tmpRs < gameData.resultCfg[tmpCard].min then
        tmpRs = {}
    end 
    return tmpRs
end
--[[
-- 检查线路中奖奖
函数传入数据格式：
cards = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15}
num = 10,                   -- 选择多少条线路
filterRsult = -1,           -- 是否需要过滤结果,罗宾汉不需要过滤结果, 万能牌也可以中奖，并且取最小万能牌中奖的
gameData = {
    wilds = {1, 2},         - 游戏中的万能牌
    scatter = 1,            -- 游戏中的分散图标，一般是触发小游戏
    bonus = 2,              -- 游戏中的bonus数值 ，一般用于触发子游戏
    trace = {},             -- 路线
    resultCfg = {},         -- 所有牌对应的中奖配置 
    inverseTrace = true,    -- 有反序结果
}
]]
-- 
local function checkResult(cards, num, gameData)
    local winResult = {}
    for i = 1, num do
        local leftRsIdxs, rightRsIdxs = {}, {}
        leftRsIdxs = caul(gameData.trace[i], cards, gameData, i)  -- 计算正向结果
        if gameData.inverseTrace then -- 计算反向结果
            if #leftRsIdxs ~= 5 then
                rightRsIdxs = caul(reverseTable(gameData.trace[i]), cards, gameData)
            end
        end
        if #leftRsIdxs ~= 0 then 
            table.insert(winResult, {xlid = i, indexs = leftRsIdxs})
        end
        if #rightRsIdxs ~= 0 then
            table.insert(winResult, {xlid = i, indexs = rightRsIdxs})
        end
    end
    return winResult
end

--[[
    1. 适用于从左至右，以及从右至左 
    2. 是否可以用wild替代 
]]
local function ContinuousScatter(cards, startRow, gameData)
    local result = {}
    local tmpSub  -- 增减量
    local endRow  -- 结束的列
    if startRow == 1 then
        tmpSub = 1
        endRow = 5
    else
        tmpSub = -1
        endRow = 1
    end
    local scatterInStartRow = false
    for row = startRow, endRow, tmpSub do
        local rowHaveScatter = false
        if row == startRow then
            for _, idx in ipairs({row, row + 5, row + 10}) do
                if cards[idx] == gameData.scatter then
                    scatterInStartRow = true
                    table.insert(result, idx)
                    break
                end
            end
        elseif scatterInStartRow then
            for _, idx in ipairs({row, row + 5, row + 10}) do
                if gameData.wildReplaceAll and table.contain(gameData.wilds, cards[idx]) then
                    rowHaveScatter = true
                    table.insert(result, idx)
                    break
                elseif cards[idx] == gameData.scatter then
                    table.insert(result, idx)
                    rowHaveScatter = true
                    break
                end
            end
            if not rowHaveScatter then
                break
            end
        end
    end
    if #result < gameData.resultCfg[gameData.scatter].min then
        result = {}
    end
    return result 
end

local function checkContinuousScatterAward(cards, gameData)
    local result = {lefttoRight = {}, righttoLeft = {}}
    local startRow = 1
    result.lefttoRight = ContinuousScatter(cards, startRow, gameData)
    if gameData.inverseTrace then
        startRow = 5
        result.righttoLeft = ContinuousScatter(cards, startRow, gameData)
    end
    return result
end

--[[
gameData = {
    scatter = GAME_CFG.scatter,
    wilds = GAME_CFG.wilds, 
    resultCfg = GAME_CFG.RESULT_CFG                --  卡牌定义
    scatterSpSettle = GAME_CFG.scatterSpSettle,    -- scatter按照从左至右或者从右至左算分
    wildReplaceAll = GAME_CFG.wildReplaceAll,      -- 万能牌是否能代替所有的牌， 包括scatter和bonus
    inverseTrace = GAME_CFG.inverseTrace or false  -- 是否反向连续
}
]]
local function scatterAward(cards, gameData)
    if gameData.wildReplaceScartAward then
        local cnt = 0
        local scatterIdxs = {}
        local scatterLines = {}
        local lindexIndexs = config.LINEINDEX[gameData.x][gameData.y]
        for index, lineInfo in pairs(lindexIndexs) do
            for _, key in pairs(lineInfo) do
                if cards[key] == gameData.scatter then
                    table.insert(scatterIdxs,key)
                    table.insert(scatterLines,index)
                    cnt = cnt + 1
                    break
                end
            end
        end

        local syLines = {}
        if #scatterIdxs > 0 then
            for i = 1,5 do
                local isIn = false
                for _, l in pairs(scatterLines) do
                    if l == i then
                        isIn = true
                        break
                    end
                end
                if not isIn then
                    table.insert(syLines,i)
                end
            end
        end

        for i = 1, #syLines do
            local line = syLines[i]
            local singeLine = config.LINEINDEX[gameData.x][gameData.y][line]
            for i = 1, #singeLine do
                if cards[singeLine[i]] == gameData.wilds[1] then
                    table.insert(scatterIdxs,singeLine[i])
                    cnt = cnt + 1
                    break
                end
            end
        end
        return true,cnt,scatterIdxs
        
    end
end

local function checkScatterAward(cards, gameData)
    if gameData.scatter == nil then
        return {indexs = {}, coin = 0}
    end
    if gameData.resultCfg[gameData.scatter] == nil then
        return {indexs = {}, coin = 0}
    end
    local result = {}
    result.indexs = {}
    if not gameData.scatterSpSettle then --单纯按数量算钱
        local cnt = 0
        local rs = {}
        local ret, num, scatterIdxs = scatterAward(cards, gameData)
        if ret then
            rs = scatterIdxs
            cnt = num
        else
            for idx, card in ipairs(cards) do
                if card == gameData.scatter then
                    table.insert(rs, idx)
                    cnt = cnt + 1
                end
            end
        end
        
        cnt = cnt >= 5 and 5 or cnt
        if gameData.state then
            if gameData.scatterFreeMult and gameData.scatterFreeMult[cnt] then
                table.insert(result.indexs, rs)
                return result
            end
        end
        local mult = gameData.resultCfg[gameData.scatter].mult[cnt]
        -- 如果没有奖励，就不需要加入列表了
        if mult ~= nil and mult ~= 0 then
            table.insert(result.indexs, rs)
            return result
        end
    else--必须按照从左到右算分
        local ret = checkContinuousScatterAward(cards, gameData)
        for _, rs in pairs(ret) do
            if #rs > 0 then
                table.insert(result.indexs, rs)
            end
        end
        return result
    end
    return {indexs = {}, coin = 0}
end

--[[
    计算轨迹中奖路线的金币
    gameData = {wilds = {}, rsCfg =  RESULT_CFG, maxMultPerLine = maxMultPerLine}
]]
local function getTraceCoin(traceResult, cards, gameData, singleBet, addMult)
    if not addMult then addMult = 1 end
    local totalMultiple = 0
    local maxMult = gameData.maxMultPerLine   -- 每根线最大的赔率
    for _, rs in pairs(traceResult) do
        local lineAddMult = 1
        local rsCard = getNotWild(gameData.wilds, cards, rs.indexs)
        local mult = gameData.rsCfg[rsCard].mult[#rs.indexs] or 0
        local wildIdxs = getWildIdxs(gameData.wilds, cards, rs.indexs)
        local isDouble = gameData.rsCfg[rsCard].double
        if #wildIdxs > 0 then
            if not table.empty(isDouble) and #rs.indexs >= isDouble.minCnt then
                lineAddMult = isDouble.value
                mult = mult * lineAddMult
            end
            -- if isDouble == 1 then       -- 组合线路中有万能牌, 翻2倍
            --     mult = mult * 2
            -- elseif isDouble == 3 and #rs.indexs >= 3 then  -- 组合线路满足3个以上，有万能牌，翻3倍
            --     mult = mult * 3
            -- end
        end
        mult = mult * addMult
        if maxMult ~= nil and mult > maxMult then
            mult = maxMult
        end 
        totalMultiple = totalMultiple + mult
        rs.mult = lineAddMult
        rs.card = rsCard
        rs.coin = mult*singleBet
    end
    return totalMultiple
end

--[[
    规则： 免费游戏时，如果有万能牌组合，算金币时，倍数按照 2的万能牌个数的幂次计算
    计算轨迹免费游戏中奖路线的金币
    gameData = {wilds = {}, rsCfg =  RESULT_CFG}
]]
local function getFreeDoubleTraceCoin(traceResult, cards, gameData, singleBet, addMult)
    if not addMult then addMult = 1 end
    local totalMultiple = 0
    local maxMult = gameData.maxMultPerLine
    for _, rs in pairs(traceResult) do
        local lineAddMult = 1
        local tmp = getNotWild(gameData.wilds, cards, rs.indexs)
        local rsCard = getCardValue(tmp, true)
        local mult = gameData.rsCfg[rsCard].mult[#rs.indexs]
        local wildIdxs = getWildIdxs(gameData.wilds, cards, rs.indexs)
        local isDouble = gameData.rsCfg[rsCard].double
        if #wildIdxs > 0 then
            lineAddMult = 2^(#wildIdxs)
            mult = mult * lineAddMult
        end
        mult = mult * addMult
        if maxMult ~= nil and mult > maxMult then
            mult = maxMult
        end
        totalMultiple = totalMultiple + mult
        rs.mult = lineAddMult or 1
        rs.card = rsCard
        rs.coin = mult*singleBet    
    end
    return totalMultiple
end
--scatter算分规则
--[[
    计算scatter算分规则
    gameData = {scatter = scatter, rsCfg =  RESULT_CFG}
]]
local function getScatterCoin(result, cards, gameData, singleBet, addMult)
    local rsCfg = gameData.rsCfg or gameData.resultCfg
    if not addMult then addMult = 1 end
    local ret =  {indexs = {}, coin = 0}
    if not table.empty(result.indexs) and #result.indexs[1] >= rsCfg[gameData.scatter].min then
        local lineAddMult = 1
        for _, rs in ipairs(result.indexs) do
            local cnt = #rs
            cnt = cnt > 5 and 5 or cnt
            if cnt > 0 then  --计算分散符号
                local mult = rsCfg[gameData.scatter].mult[cnt]
                local wildIdxs = getWildIdxs(gameData.wilds, cards, rs)
                if #wildIdxs > 0 then
                    local isDouble = rsCfg[gameData.scatter].double
                    if type(isDouble) == "table" then
                        if not table.empty(isDouble) and #rs >= isDouble.minCnt then
                            lineAddMult = isDouble.value
                            mult = mult * lineAddMult
                        end
                    else
                        if isDouble == 1 then
                            lineAddMult = 2
                            mult = mult * lineAddMult
                        end
                        if isDouble == 3 and #rs >= 3 then
                            lineAddMult = 3
                            mult = mult * lineAddMult
                        end
                    end


                end
                mult = mult * addMult
                ret.mult = lineAddMult
                ret.coin = mult*singleBet
                for _, idx in pairs(rs) do
                    if not table.contain(ret.indexs, idx) then
                        table.insert(ret.indexs, idx)
                    end
                end
                
            end
        end
    else
        ret.mult = 0
        ret.coin = 0
        -- 这里注释的原因是，前端不需要scatter的位置信息
        -- for idx, value in ipairs(cards) do
        --     if value == gameData.scatter then
        --         table.insert(ret.indexs, idx)
        --     end
        -- end
    end
    return ret
end

local function getScatterResult(deskInfo, cards, GAME_CFG)
    local resultCards = table.copy(cards)
    local scatterGameData = {
        scatter = GAME_CFG.scatter,
        wilds = GAME_CFG.wilds, 
        resultCfg = GAME_CFG.RESULT_CFG,
        scatterSpSettle = GAME_CFG.scatterSpSettle, 
        wildReplaceAll = GAME_CFG.wildReplaceAll, 
        inverseTrace = GAME_CFG.inverseTrace or false,
        state = deskInfo.state == config.GAME_STATE["FREE"] and true or false,
        scatterFreeMult = GAME_CFG.scatterFreeMult,
        wildReplaceScartAward = GAME_CFG.wildReplaceScartAward,
        x = GAME_CFG.x,
        y = GAME_CFG.y,
    }

    local scatterResult = checkScatterAward(resultCards, scatterGameData)
    scatterResult =  getScatterCoin(scatterResult, resultCards, {wilds = GAME_CFG.wilds, scatter = GAME_CFG.scatter, rsCfg =  GAME_CFG.RESULT_CFG}, deskInfo.singleBet, deskInfo.freeGameData.addMult)
    return scatterResult
end

local function getBigGameResult(deskInfo, cards, GAME_CFG, gamehook)
    local resultCards = table.copy(cards)
    local winCoin = 0
    local gameData = {
        wilds = GAME_CFG.wilds, scatter = GAME_CFG.scatter, bonus = GAME_CFG.bonus, diamonds = GAME_CFG.diamonds,
        trace = GAME_CFG.winTrace, resultCfg = GAME_CFG.RESULT_CFG, inverseTrace = GAME_CFG.inverseTrace or false,
        wildReplaceAllWildB = GAME_CFG.wildReplaceAllWildB,
    }

    local traceResult = {}
    local line = GAME_CFG.line and GAME_CFG.line or deskInfo.line
    traceResult = checkResult(resultCards, line, gameData)
    local winTraceMult
    if GAME_CFG.traceMultSameExp or (deskInfo.state == config.GAME_STATE["FREE"] and GAME_CFG.freeTraceMultSameExp) then -- 免费游戏倍数成wild的指数增长105 135
        local addMult = (GAME_CFG.traceMultSameExp and deskInfo.freeGameData.addMult == 0) and 1 or deskInfo.freeGameData.addMult
        winTraceMult = getFreeDoubleTraceCoin( traceResult, resultCards, {wilds = GAME_CFG.wilds, rsCfg = GAME_CFG.RESULT_CFG, maxMultPerLine = GAME_CFG.maxPerLineMult}, deskInfo.singleBet, addMult)
    elseif deskInfo.state == config.GAME_STATE["FREE"] and gamehook and gamehook.getFreeDoubleTraceCoin then
        --ps: 新增了deskInfo字段
        winTraceMult = gamehook.getFreeDoubleTraceCoin(deskInfo, traceResult, resultCards, {wilds = GAME_CFG.wilds, rsCfg = GAME_CFG.RESULT_CFG, maxMultPerLine = GAME_CFG.maxPerLineMult}, deskInfo.singleBet)
    else
        winTraceMult = getTraceCoin(traceResult, resultCards, {wilds = GAME_CFG.wilds, rsCfg = GAME_CFG.RESULT_CFG, maxMultPerLine = GAME_CFG.maxPerLineMult}, deskInfo.singleBet, deskInfo.freeGameData.addMult)
    end
    winCoin = winTraceMult * deskInfo.singleBet

    local scatterResult =  getScatterResult(deskInfo, cards, GAME_CFG)
    winCoin = winCoin + scatterResult.coin

    return math.round_coin(winCoin), traceResult, scatterResult
end


local function getCardIdxs(resultCards, card)
    local idxs = {}
    for k, v in pairs(resultCards) do
        if v == card then 
            table.insert(idxs, k)
        end
    end
    return idxs
end

local function getBonusResult(resultCards, gameConf, betCoin)
    local result = {}
    if gameConf.bonus then
        local bonusIndexs = getCardIdxs(resultCards, gameConf.bonus)
        local winCoin = 0
        local bonusCnt = #bonusIndexs > 5 and 5 or #bonusIndexs
        local mult = gameConf.RESULT_CFG[gameConf.bonus].mult[bonusCnt]
        if mult ~= nil then
            winCoin = mult * betCoin
        else
            bonusIndexs = {}
        end
        result.mult = 1
        result.indexs = bonusIndexs
        result.winCoin = winCoin
    end
    return result
end

--============没有具体线路的=============================
local function getColCards(cards, col, COLMAX, ROWMAX)
    local colIdxs = {}
    for row = 1, ROWMAX do
        table.insert(colIdxs, col + (row - 1)*COLMAX)
    end
    local colCards ={}
    for row = 1, ROWMAX do
        table.insert(colCards, cards[colIdxs[row]])
    end
    return colCards, colIdxs
end

local function caulNoTrace(deskInfo,cards, gameData)
    local colInfo = {}
    local coin = 0
    --整理出每列的卡牌以及对应的idx
    for col = 1, gameData.colMax do
        colInfo[col] = {}
        local colCards, colIdxs = getColCards(cards, col, gameData.colMax, gameData.rowMax)
        for k, v in ipairs(colCards) do
            colInfo[col][v] = colInfo[col][v] or {}
            table.insert(colInfo[col][v], colIdxs[k])
        end
    end
    local traceRs = {}
    for value, info in pairs(gameData.resultCfg) do
        --最小个数小于5个的参与此计算方式
        if  info.min <= gameData.colMax then
            local result = {xlid = value, indexs = {}, coin = 0}
            local idxList = {}
            --统计每列该元素以及wild的个数信息
            local mInfo = {}
            local nInfo = {}
            for col = 1, gameData.colMax do
                --wild的个数
                for _, wild in ipairs(gameData.wilds) do
                    nInfo[col] = colInfo[col][wild] and #colInfo[col][wild] or 0
                end
                --普通元素+wild
                mInfo[col] = (colInfo[col][value] and #colInfo[col][value] or 0) + nInfo[col]
            end
            --[[
                5个， m1*m2*m3*m4*m5 - n1*n2*n3*n4*n5
                4个， m1*m2*m3*m4 - n1*n2*n3*n4
                3个， m1*m2*m3 - n1*n2*n3
                2个， m1*m2 - n1*n2
                1个， m1 - n1
            ]]
            --找出图标对应的最大数
            local total, max = 0, 0
            for col = gameData.colMax, 1, -1 do
                local a, b = mInfo[col], nInfo[col]
                for i = col-1, 1, -1 do
                    a = a*mInfo[i]
                    b= b*nInfo[i]
                end
                if a ~= 0 then
                    total = a - b
                    max = col
                    break
                end
            end
            --把结果计算在总结果上
            if max ~= 0 and max >= gameData.resultCfg[value].min then
                local indexs = {}
                for k = 1, max do
                    for _, wild in ipairs(gameData.wilds) do
                        if colInfo[k][wild] then
                            for _, idx in ipairs(colInfo[k][wild]) do
                                if not table.contain(indexs, idx)then
                                    table.insert(indexs, idx)
                                end
                            end
                        end
                    end
                    if colInfo[k][value] then
                        for _, idx in ipairs(colInfo[k][value]) do
                            if not table.contain(indexs, idx) then
                                table.insert(indexs, idx)
                            end
                        end
                    end
                end
                table.sort(indexs)
                local num = max > gameData.colMax and gameData.colMax or max
                local addMult = deskInfo.freeGameData.addMult
                if not addMult then
                    addMult = 1
                end
                local win = gameData.resultCfg[value].mult[max]*deskInfo.singleBet*total*addMult
                coin = coin + win
                result.card = value
                result.coin = win
                result.indexs = indexs
                table.insert(traceRs, result)
            end

        end
    end
    coin = math.round_coin(coin)
    return coin, traceRs
end

local function getBigGameResult_2(deskInfo, cards, GAME_CFG)
    local resultCards = table.copy(cards)
    local winCoin = 0
    local traceResult = {}
    local gameData = {wilds = GAME_CFG.wilds, scatter = GAME_CFG.scatter, resultCfg = GAME_CFG.RESULT_CFG, rowMax = GAME_CFG.ROW_NUM, colMax = GAME_CFG.COL_NUM}    
    winCoin, traceResult = caulNoTrace(deskInfo,cards, gameData)
    local scatterResult =  getScatterResult(deskInfo, cards, GAME_CFG)
    winCoin = winCoin + scatterResult.coin
    return winCoin, traceResult, scatterResult
end

return {
    getBigGameResult = getBigGameResult,        --固定线路计算方式
    getBigGameResult_2 = getBigGameResult_2,    --无固定线路计算方式
    getCardIdxs = getCardIdxs,
    getBonusResult = getBonusResult,            --获取不能被wild替代，也不算线的bonus图标的结果
    getScatterResult = getScatterResult,
    checkResult = checkResult,
    getTraceCoin = getTraceCoin,
}



