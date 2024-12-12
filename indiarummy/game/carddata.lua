--
-- Author: mz
-- Date: 2019-03-11
-- 标准扑克数据

--@param isA_Max A是不是大牌
--@param is2_Max 2是不是大牌
--@param fun_call 扩展或者覆盖的函数
return function(isA_Max, is2_Max, fun_call)
    local carddata = {}
    if fun_call ~= nil then
        setmetatable(carddata, { __index = fun_call })
    end
    --扑克数据(4副)，每副去掉大小王 color:黑 红 梅 方
    local ALL_CARDDATA=
    {
        0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D, --黑桃 A 1 - K(13)
        0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,
        0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,
        0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,
        0x5E,0x5F,--小王 大王
    }
    local KING_CARDDATA=
    {
         0x5E,0x5F,--小王 大王
    }

    --获取牌型的花色
    function carddata.getColor(card)
        return card & 0xF0
    end

    --获取牌型值
    --@card 牌
    --@return  牌面的值 A-9 10 11J 12Q 13K
    function carddata.getValue(card)
        local value = card & 0x0F
        if isA_Max then
            if value == 1 then
                value = 0x0E
            end
        end
        if is2_Max then
            if value == 2 then
                value = 0x0F
            end
        end
        return value
    end

    --移除掉王卡
    function carddata.removeKing()
        for i=#carddata.allcard,1,-1 do
            local card = carddata.allcard[i]
            for j,kingcard in ipairs(KING_CARDDATA) do
                if card == kingcard then
                    table.remove(carddata.allcard, i)
                    break
                end
            end
        end
    end

    --移除掉指定卡牌
    --@param card_table 需要移除的卡牌列表
    function carddata.removeCards( card_table )
        for i=#carddata.allcard,1,-1 do
            local card = carddata.allcard[i]
            for j,tcard in ipairs(card_table) do
                if card == tcard then
                    table.remove(carddata.allcard, i)
                    break
                end
            end
        end
    end

    --初始化数据 初始化的牌是num套牌
    --@param num 指定当前有多少套牌
    function carddata.initCardNum(num)
        carddata.allcard = {}
        if num == nil then
            num = 1 --默认1套牌
        end
        for i=1,num do
            for i,card in ipairs(ALL_CARDDATA) do
                table.insert(carddata.allcard, card)
            end
        end
    end

    return carddata
end