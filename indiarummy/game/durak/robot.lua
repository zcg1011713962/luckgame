local utils = require "base.utils"

local robot = {}

local MaxCardValue = 0x0E


-- 先出的牌card1
-- 后出的牌card2
robot.compare = function (card1, card2, masterSuit)
    if utils.ScanSuit(card1) == masterSuit then
        return (utils.ScanSuit(card2)==masterSuit) and (card2 > card1)  --如果先出是主牌，需要点数更大
    else
        if utils.ScanSuit(card2) == masterSuit then  --先出的是副牌，后出的是主牌，则大过它
            return true
        elseif utils.ScanSuit(card1) == utils.ScanSuit(card2) then --如果都是副牌，需要花色相同，且点数更大
            return card2 > card1
        end
    end
    return false
end

--是否与桌面上的任意一张牌的点数相同
robot.checkSameValue = function (card, roundCards)
    for _, cards in ipairs(roundCards) do
        for __, c in ipairs(cards) do
            if utils.ScanValue(c) == utils.ScanValue(card) then
                return true
            end
        end
    end
    return false
end


-- 进攻出牌
---@param deskInfo BaseDeskInfo
robot.findAttackCard = function (_selfCards, deskInfo)
    local masterSuit = deskInfo.round.masterSuit
    local leftCards = #deskInfo.round.cards  --剩余牌数
    local selfCards = table.copy(_selfCards)

    --按权重排序，优先出掉小牌
    --排序规则：主牌权重大于副牌；副牌之间比较点数大小
    table.sort(selfCards, function(a, b)
        local sa = utils.ScanSuit(a)
        local sb = utils.ScanSuit(b)
        if sa == masterSuit and sb == masterSuit then
            return a < b
        elseif sa == masterSuit and sb ~= masterSuit then
            return false
        elseif sa ~= masterSuit and sb == masterSuit then
            return true
        else
            return utils.ScanValue(a) < utils.ScanValue(b)
        end
    end)

    if #deskInfo.round.roundCards == 0 then
        -- 桌面上无牌，任意出
        return selfCards[1]
    else
        --桌面上有牌，只能出点数和桌面上点数一样的牌
        for _, card in ipairs(selfCards) do
            --牌没发完，则主牌和A留着，否则打得起就打
            if leftCards <= 0 or (utils.ScanSuit(card) ~= masterSuit and (not utils.IsAce(card))) then
                --和桌面上任意一张牌的点数一样
                if robot.checkSameValue(card, deskInfo.round.roundCards) then
                    return card
                end
            end
        end
    end
    return nil
end

--防守出牌
---@param deskInfo BaseDeskInfo
robot.findDefendCard = function (_selfCards, attackCard, deskInfo)
    local masterSuit = deskInfo.round.masterSuit
    local selfCards = table.copy(_selfCards)
    table.sort(selfCards, function(a, b)
        return utils.ScanValue(a) < utils.ScanValue(b)
    end)

    --先使用副牌
    for _, card in ipairs(selfCards) do
        if utils.ScanSuit(card) == utils.ScanSuit(attackCard) and card > attackCard then
            return card
        end
    end
    --再使用主牌
    for _, card in ipairs(selfCards) do
        if robot.compare(attackCard, card, masterSuit) then
            return card
        end
    end
    return nil
end

--补牌出牌
---@param deskInfo BaseDeskInfo
robot.findAddExtraCard = function(selfCards, deskInfo)
    local masterSuit = deskInfo.round.masterSuit
    local leftCards = #deskInfo.round.cards  --剩余牌数
    for _, card in ipairs(selfCards) do
        --牌没发完，则主牌和A留着，否则打得起就打
        if leftCards <= 0 or (utils.ScanSuit(card) ~= masterSuit and (not utils.IsAce(card))) then
            --和桌面上任意一张牌的点数一样
            if robot.checkSameValue(card, deskInfo.round.roundCards) then
                return card
            end
        end
    end
    return nil
end

return robot