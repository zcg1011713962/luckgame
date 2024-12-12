local studtool = {}

local function getCardValue(card)
    return card & 0x0F
end

local function getCardColor(card)
    return card & 0xF0
end

--判断该牌是佛存在A
local function isAcard(cards)
    for i,card in pairs(cards) do
        if getCardValue(card) == 1 then
            return true
        end
    end
    return false
end

--判断是否为顺子
local function shunzi(cards)
    local index_c = 0
    local tmp_cards = table.copy(cards)
    table.sort(tmp_cards,function(a,b) return getCardValue(a) > getCardValue(b) end)
    for i = 1,#tmp_cards do
        if i ~= #tmp_cards then 
            if getCardValue(tmp_cards[i]) - getCardValue(tmp_cards[i+1]) == 1 then
                index_c  = index_c + 1
            else
                index_c = 0
            end
        end
    end
    if index_c < 4 then
        local ret = isAcard(tmp_cards)
        if ret then
            index_c = 0
            table.sort(tmp_cards,function(a,b) return getCardValue(a) > getCardValue(b) end)
            for i = 1,#tmp_cards do
                if i ~= #tmp_cards then 
                    if getCardValue(tmp_cards[i]) - getCardValue(tmp_cards[i+1]) == 1 then
                        index_c = index_c + 1
                    else
                        index_c = 0
                    end
                end
            end
            if index_c > 3 then
                return index_c
            else
                return false
            end
        end
    elseif index_c > 3 then
        return index_c
    end
  
end

--判断是否是相同颜色
local function getColorNum(cards)
    for _,card in pairs(cards) do
        for j = 1,#cards do
            if getCardColor(card) ~= getCardColor(cards[j]) then                      
                return nil
            end
        end
    end
    return true
end


-- 统计相同牌的值
function getXtCardVluse(cards)
    local valurNum = {}
    for _,card in pairs(cards) do
        local value = getCardValue(card)
        if not valurNum[value] then
            valurNum[value] = 0
        end
    end
    --可能不是有序的重新排序
    local tmp_cards1 = {}
    local tmpCards = table.copy(cards)
    for _,card in pairs(tmpCards) do
        local value = getCardValue(card)
        table.insert(tmp_cards1,card)
    end
    local tmp_cards = table.copy(tmp_cards1)
    for i = 1,#tmp_cards do         
         for j = 1,#tmp_cards1 do
            if getCardValue(tmp_cards[i]) == getCardValue(tmp_cards1[j]) then
                tmp_cards[i] = 0
                local value = getCardValue(tmp_cards1[i])          
                valurNum[value] = valurNum[value] + 1
            end
         end
    end
    return valurNum
end

local CARD_TYPE = {
    ["TONGHUA_S"] = 9, -- 同花顺
    ["SI_T"] = 8,-- 四条
    ["HU_L"] = 7,-- 葫芦
    ["TONG_H"] = 6,-- 同花
    ["SHUN_Z"] = 5,-- 顺子
    ["SAN_T"] = 4,-- 三条
    ["LIANG_D"] = 3,-- 两对
    ["YI_D"] = 2,-- 一对
    ["SAN_P"] = 1,-- 散牌
    ["QIPAI"] = 0, --弃牌
}


studtool.STUD_ACTION = 
{
    ["PASS"] = 1, --不加
    ["FILL"] = 2, --加注
    ["FOLLOW"] = 3, --跟注
    ["ALLIN"] = 4, -- 全押
    ["GIVEUP"] =  5, --弃牌
}

--检测牌型
function studtool.checkCardType(dcards)
    local cards = table.copy(dcards)
    local ret = -1
    local valurNum = {}
    for _,card in pairs(cards) do
        local value = getCardValue(card)
        if not valurNum[value] then
            valurNum[value] = 0
        end
    end

    local tmp_cards = table.copy(cards)
    for i = 1,#tmp_cards do         
        for j = 1,#cards do
                if getCardValue(tmp_cards[i]) == getCardValue(cards[j]) then
                        tmp_cards[i] = 0     
                        local value =  getCardValue(cards[i])                          
                        valurNum[value] = valurNum[value] + 1
                end
        end
    end

    local duizi = 0
    local tiaozi = 0
    local zhadan = 0
    for _,count in pairs(valurNum) do
        if count == 2 then
            duizi = duizi + 1
        end
        if count == 3 then
            tiaozi = tiaozi + 1
        end
        if count == 4 then
            zhadan = zhadan + 1
        end
    end
    if duizi > 0 and tiaozi > 0 then
        --5张牌 判断葫芦
        ret = CARD_TYPE.HU_L -- 葫芦
    else
        if duizi > 0 then
            if duizi == 1 then
                ret = CARD_TYPE.YI_D --一对
            elseif duizi == 2 then
                ret = CARD_TYPE.LIANG_D -- 二对
            end
        end

        if tiaozi > 0 then
            ret = CARD_TYPE.SAN_T --3条
        end

        if zhadan > 0 then
            ret = CARD_TYPE.SI_T -- 炸弹
        end

        if duizi == 0 and tiaozi == 0 and zhadan ==0 then
            ret = CARD_TYPE.SAN_P -- 散牌
        end
    end

    if ret == CARD_TYPE.SAN_P and #cards == 5 then
        if shunzi(cards) then
            if getColorNum(cards) then --同花顺
                ret = CARD_TYPE.TONGHUA_S
            else
                ret = CARD_TYPE.SHUN_Z  --顺子
            end
        else
            if getColorNum(cards) then --同花
                ret = CARD_TYPE.TONG_H
            else
                ret = CARD_TYPE.SAN_P
            end
        end
    end

    return ret
end

--比大小
function studtool.comPareCardType(dcards1,dcards2)
    local cards1 = table.copy(dcards1)
    local cards2 = table.copy(dcards2)
    local ty1 = studtool.checkCardType(cards1)
    local ty2 = studtool.checkCardType(cards2)

    local ret = isAcard(cards1)
    if ret then
        for i,card in pairs(cards1) do
            if getCardValue(card) == 1 then
                cards1[i] = cards1[i] + 13 
            end
        end
    end

    local ret = isAcard(cards2)
    if ret then
        for i,card in pairs(cards2) do
            if getCardValue(card) == 1 then
                cards2[i] = cards2[i] + 13
            end
        end
    end

    if ty1 == ty2 then
        --同花顺 顺子 散牌 直接比最大的那张牌
        if ty1 == CARD_TYPE.TONGHUA_S or ty1 == CARD_TYPE.SHUN_Z or ty1 == CARD_TYPE.SAN_P then
            table.sort(cards1,function(a,b) return getCardValue(a) > getCardValue(b) end)
            table.sort(cards2,function(a,b) return getCardValue(a) > getCardValue(b) end)
           
            if getCardValue(cards1[1]) > getCardValue(cards2[1]) then
                return true
            elseif getCardValue(cards1[1]) < getCardValue(cards2[1]) then
                return false
            elseif getCardValue(cards1[1]) == getCardValue(cards2[1]) then
                for i = 1, #cards1 do
                    if getCardValue(cards1[i]) - getCardValue(cards2[i]) > 0 then
                        return true
                    end
                    if getCardValue(cards1[i]) - getCardValue(cards2[i]) < 0 then
                        return false
                    end
                end
                --比较花色
                if getCardColor(cards1[1]) - getCardColor(cards2[1]) > 0 then
                    return true
                end
                if getCardColor(cards1[1]) - getCardColor(cards2[1]) < 0 then
                    return false
                end
            end
        end

        --一对,二队,三条,葫芦,炸弹
        local valurNum1 = getXtCardVluse(cards1)
        local valurNum2 = getXtCardVluse(cards2)
        local value1 = 0
        local value2 = 0
        local color1 = 0
        local color2 = 0
        local sanValue1 = {}
        local sanValue2 = {}
        if ty1 == CARD_TYPE.YI_D then --一对
            for value ,count in pairs(valurNum1) do
                if count == 2 then
                    value1 = value
                    break
                end
            end
            for value ,count in pairs(valurNum2) do
                if count == 2 then
                    value2 = value
                    break
                end
            end

            if value1 > value2 then
                return true
            elseif value1 < value2 then
                return false
            elseif value1 == value2 then
                for _,card in pairs(cards1) do
                    if getCardValue(card) ~= value1 then
                        table.insert(sanValue1,card)
                    end
                end

                for _,card in pairs(cards2) do
                    if getCardValue(card) ~= value2 then
                        table.insert(sanValue2,card)
                    end
                end
                table.sort(sanValue1,function(a,b) return getCardValue(a) > getCardValue(b) end)
                table.sort(sanValue2,function(a,b) return getCardValue(a) > getCardValue(b) end)
                if #cards1 == 3 then
                    if getCardValue(sanValue1[1]) > getCardValue(sanValue2[1]) then
                        return true
                    elseif getCardValue(sanValue1[1]) < getCardValue(sanValue2[1]) then
                        return false
                    elseif getCardValue(sanValue1[1]) == getCardValue(sanValue2[1]) then
                        if getCardColor(sanValue1[1]) > getCardColor(sanValue2[1]) then
                            return true
                        else
                            return false
                        end
                    end 
                elseif #cards1 == 5 then
                    for i = 1, 3 do
                        if getCardValue(sanValue1[i]) > getCardValue(sanValue2[i]) then
                            return true
                        elseif getCardValue(sanValue1[i]) < getCardValue(sanValue2[i]) then
                            return false
                        elseif getCardValue(sanValue1[i]) == getCardValue(sanValue2[i]) then
                            if i ==  3 then
                                if getCardColor(sanValue1[1]) > getCardColor(sanValue2[1]) then
                                    return true
                                else
                                    return false
                                end
                            end
                        end 
                    end
                end
            end
        elseif ty1 == CARD_TYPE.LIANG_D then --2对
            local value_min1 = 0
            local value_min2 = 0
            value1 = 0
            value2 = 0
            for value ,count in pairs(valurNum1) do
                if count == 2 then
                    if value1 == 0 then
                        value1 = value
                    else
                        if value > value1 then
                            value_min1 = value1
                            value1 = value
                        else
                            value_min1 = value
                        end
                    end
                end
            end
            
            for value ,count in pairs(valurNum2) do
                if count == 2 then
                    if value2 == 0 then
                        value2 = value
                    else
                        if value > value2 then
                            value_min2 = value2
                            value2 = value
                        else
                            value_min2 = value
                        end
                    end
                end
            end
            if value1 > value2 then
                return true
            elseif value1 < value2 then
                return false
            elseif value1 == value2 then
                local dan_card1
                local dan_card2
                for _,card in pairs(cards1) do
                    if getCardValue(card) ~= value1 and getCardValue(card) ~= value_min1 then
                        dan_card1 = card
                        break
                    end
                end

                for _,card in pairs(cards2) do
                    if getCardValue(card) ~= value1 and getCardValue(card) ~= value_min1 then
                        dan_card2 = card
                        break
                    end
                end

                if value_min1 > value_min2 then
                    return true
                elseif  value_min1 < value_min2 then
                    return false
                elseif value_min1 == value_min2 then
                    if getCardValue(dan_card1) > getCardValue(dan_card2) then
                        return true
                    elseif getCardValue(dan_card1) < getCardValue(dan_card2) then
                        return false
                    elseif getCardValue(dan_card1) == getCardValue(dan_card2) then
                        if getCardColor(dan_card1) > getCardColor(dan_card2) then
                            return true
                        else
                            return false
                        end
                    end
                end
            end
        elseif ty1 == 4 or ty1 == 7 then --三条或者葫芦
            for value ,count in pairs(valurNum1) do
                if count == 3 then
                    value1 = value
                    break
                end
            end
            for value ,count in pairs(valurNum2) do
                if count == 3 then
                    value2 = value
                    break
                end
            end

            if value1 > value2 then
                return true
            else
                return false
            end
        elseif ty1 == 8 then --炸弹
            for value ,count in pairs(valurNum1) do
                if count == 4 then
                    value1 = value
                    break
                end
            end
            for value ,count in pairs(valurNum2) do
                if count == 4 then
                    value2 = value
                    break
                end
            end

            if value1 > value2 then
                return true
            else
                return false
            end
        end
    else
        if ty1 > ty2 then
            return true
        else
            return false
        end
    end
end

return studtool