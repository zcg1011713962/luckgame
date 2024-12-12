--
-- Author: mz
-- Date: 2019-03-11
-- 扑克工具

return function()
    local cardtool = {carddata = {}}
    --设置当前的实例有多少卡牌
    function cardtool.setcarddata( carddata )
        cardtool.carddata = carddata
    end

    --判断是否同花 5張牌同花，花色相同
    --@param card_table 牌的组合
    --@return true 同花  false 非同花
    function cardtool.isTonghua( card_table )
        local lastcolor
        for k,card in pairs(card_table) do
            local color = cardtool.carddata.getColor(card)
            if lastcolor == nil then
                lastcolor = color
            end
            if lastcolor ~= color then
                return false
            end
            lastcolor = color
        end
        return true
    end

    --判断是否是同花顺 5張連續的牌，並且同花色
    --@param card_table 牌的组合
    --@return true  false 
    function cardtool.isTonghuashun( card_table )
        if cardtool.isTonghua(card_table) and cardtool.isShunzi(card_table) then
            return true
        end
        return false
    end

    --判断是否是葫芦3张点数相同的加2张点数相同的
    --@param card_table 牌的组合
    --@return true 葫芦  false 非葫芦
    function cardtool.isHulu( card_table )
        local cv_table = {}
        for i,card in ipairs(card_table) do
            table.insert(cv_table, cardtool.carddata.getValue(card))
        end
        table.sort(cv_table) --小到大
        if cv_table[2] == cv_table[3] then
            if cv_table[1] == cv_table[2] and cv_table[1] ~= cv_table[4] and cv_table[4] == cv_table[5] then
                return true
            end
        else
            if cv_table[1] == cv_table[2] and cv_table[3] == cv_table[4] and cv_table[4] == cv_table[5] then
                return true
            end
        end
        return false
    end

    --是不是顺子
    --@param card_table 一组牌
    --@return true 顺子  false 非顺子
    function cardtool.isShunzi(card_table)
        local cv_table = {}
        for i,card in ipairs(card_table) do
            table.insert(cv_table, cardtool.carddata.getValue(card))
        end
        table.sort(cv_table) --小到大
        for i,v in ipairs(cv_table) do
            if i == #cv_table then
                break
            end
            if cv_table[i] + 1 ~= cv_table[i + 1] then
                return false
            end
        end
        return true
    end

    --判断是否有对子
    --@param card_table 牌的组合
    --@return true 有对子  false 没有对子
    function cardtool.isDuizi( card_table )
        local valuetable = {}
        for k,card in pairs(card_table) do
            local c_value =  cardtool.carddata.getValue(card)
            if valuetable[c_value] ~= nil then
                -- LOG_DEBUG("isDuizi:", card_table, "true")
                return true
            end
            valuetable[c_value] = 1
        end
        -- LOG_DEBUG("isDuizi:", card_table, "false")
        return false
    end

    --比较2张牌的大小
    --@param card1
    --@param card2
    --@return rs(1card1大/0平局/-1card2大)
    function cardtool.compareCard( card1, card2 )
        local c_v1 = cardtool.carddata.getValue(card1)
        local c_v2 = cardtool.carddata.getValue(card2)
        if c_v1 > c_v2 then
            return 1
        elseif c_v1 < c_v2 then
            return -1
        else
             return 0
        end
    end

    --获取这组牌中最大的那张牌
    --@param card_table
    --@return 最大的牌,最大牌的下标
    function cardtool.getMaxPos(card_table)
        local maxcard
        local maxindex
        for i,card in ipairs(card_table) do
            if maxcard == nil then
                maxcard = card
                maxindex = i
            else
                local rs = cardtool.compareCard( card, maxcard )
                if rs == 1 then
                    maxcard = card
                    maxindex = i
                end
            end
        end
        return maxcard,maxindex
    end

    --比较2组牌的大小，不看类型 只看点数
    --@param card_table1
    --@param card_table2
    --@return rs(1card_table1大/0平局/-1card_table2大)
    function cardtool.comparePoint( card_table1, card_table2 )
        if card_table1 == nil and card_table2 == nil then
            return 0
        end
        if card_table1 == nil then
            return -1
        end
        if card_table2 == nil then
            return 1
        end
        local cardtemp1 = table.copy(card_table1)
        local cardtemp2 = table.copy(card_table2)
        while #cardtemp1 > 0 do
            local maxcard1,maxindex1 = cardtool.getMaxPos(cardtemp1)
            local maxcard2,maxindex2 = cardtool.getMaxPos(cardtemp2)
            local rs = cardtool.compareCard( maxcard1, maxcard2 )
            if rs == 1 then
                return 1
            elseif rs == -1 then
                return -1
            else
                --平局
                table.remove(cardtemp1, maxindex1)
                table.remove(cardtemp2, maxindex2)
            end
        end
        
        return 0
    end

    -- 洗牌,会保证前面6手牌有一个稍微大点的牌 保证不会换牌的时候换不出牌
    --@param filterCards 需要过滤掉的牌
    --@return 已经洗好的牌
    function cardtool.RandCardList(filterCards)
        LOG_DEBUG("cardtool.RandCardListcardtool.RandCardList card:", #cardtool.carddata.allcard)
        --要过滤掉指定牌
        local cards = table.copy(cardtool.carddata.allcard)
        if nil ~= filterCards then
            for i=#filterCards, 1, -1 do
                for index, card in pairs(cards) do
                    local f = filterCards[i]
                    if ((f & 0x0F) == (card & 0x0F)) and ((f & 0xF0) == (card & 0xF0)) then
                        table.remove(cards, index)
                        break
                    end
                end
            end
            for i = 1,#cards do
                local ranOne = math.random(1,#cards+1-i)
                cards[ranOne], cards[#cards+1-i] = cards[#cards+1-i],cards[ranOne]
            end
        else
            for i = 1,#cards do
                local ranOne = math.random(1,#cards+1-i)
                cards[ranOne], cards[#cards+1-i] = cards[#cards+1-i],cards[ranOne]
            end
        end
        
        return cards
    end

    return cardtool
end