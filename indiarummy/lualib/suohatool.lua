local suohatool = {}

local CardData28=
{
    0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,   --黑桃 2 - A(14)  
    0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,   --红桃 2 - A  
    0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,   --樱花 2 - A  
    0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,   --方块 2 - A  
}

local CardData32=
{
    0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,   --黑桃 2 - A(14)
    0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,   --红桃 2 - A
    0x27,0x28,0x29,0x2A,0x2B,0x2C,0x2D,0x2E,   --樱花 2 - A
    0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,   --方块 2 - A
}

local CardType =
{
    UNDEFINE  = 0,      --散牌 或 高牌
    DAN_DUI   = 1,      --单对
    LIANG_DUI = 2,      --二对
    SAN_TIAO  = 3,      --3条
    SHUN_ZI   = 4,      --顺子
    TONG_HUA  = 5,      --同花
    HU_LU     = 6,      --葫芦
    SI_TIAO   = 7,      --4条 或铁支
    TONG_HUA_SHUN = 8,  --同花顺
}

--发牌
function suohatool.RandCardList(cardCount)
    math.randomseed(os.time())
    local cardBuffer = {}

    if cardCount == 28 then
        --洗牌
        for i = 1,#CardData28 do
            local ranOne = math.random(1,#CardData28+1-i)
            CardData28[ranOne], CardData28[#CardData28+1-i] = CardData28[#CardData28+1-i],CardData28[ranOne]
        end

        cardBuffer = table.copy(CardData28);
    else
        --洗牌
        for i = 1,#CardData32 do
            local ranOne = math.random(1,#CardData32+1-i)
            CardData32[ranOne], CardData32[#CardData32+1-i] = CardData32[#CardData32+1-i],CardData32[ranOne]
        end
        cardBuffer = table.copy(CardData32);
    end

    return cardBuffer;
end

--展示用 测试
function suohatool.getCardNamebyCard(Card)
    local string=""
    if Card.color ==0 then
        string=string.."黑桃"
    elseif Card.color ==16 then
        string=string.."红桃"
    elseif Card.color ==32 then
        string=string.."梅花"
    elseif Card.color ==48 then
        string=string.."方块"
    else
        string="ERROR"
    end

    if Card.value==14 then
        string=string.."A"
    elseif Card.value==13 then
        string=string.."K"
    elseif Card.value==12 then
        string=string.."Q"
    elseif Card.value==11 then
        string=string.."J"
    else
        string=string..Card.value
    end
    return string
end

--展示用 测试
function suohatool.getCardNamebyCards(Cards)
    local string=""
    for i = 1,#Cards do
        string=string..suohatool.getCardNamebyCard(Cards[i]) .." "
    end
    return string
end

--从大到小 排列
local function compByCardsValue(a, b)
    if b.value < a.value then
        return true
    elseif b.value > a.value then
        return false
    else
        if a.color < b.color then
            return true
        else
            return false
        end
    end
end

function suohatool.sortByCardsValue(cards)
    table.sort(cards, compByCardsValue);
end

--同花顺：即满足同花又满足顺子的牌型
function suohatool.isTongHuaShun(cards)
    if suohatool.isTongHua(cards) and suohatool.isShunZi(cards) then
        return true
    end
    return false
end

--4条 K8888 88884 (排序后的牌)
function suohatool.isSiTiao(cards)
    if cards[1].value == cards[2].value and  cards[1].value == cards[3].value and cards[1].value == cards[4].value then
        return true
    end

    if cards[2].value == cards[3].value and  cards[4].value == cards[2].value and cards[5].value == cards[2].value then
        return true
    end

    return false
end

-- 葫芦 88844 KK888 (排序后的牌)
function suohatool.isHuLu(cards)
    if cards[1].value == cards[2].value and cards[2].value == cards[3].value and cards[4].value==cards[5].value then
        return true
    end

    if cards[1].value == cards[2].value and cards[3].value == cards[4].value and cards[3].value==cards[5].value then
        return true
    end

    return false
end

-- 同花：花色相同
function suohatool.isTongHua(cards)
    for i = 1, (#cards-1) do
        if cards[i].color ~= cards[i+1].color then
            return false
        end
    end
    return true
end

--顺子：依次递增1 （参数为已经排序过的 大的在前）
function suohatool.isShunZi(cards, typeid)
    if typeid == 1 then
        --最小牌为8的模式下， A、8、9、10、J也为顺子(特殊牌型)
        if cards[1].value == 14 and cards[2].value ==11 and cards[3].value==10 and cards[4].value==9 and cards[5].value == 8 then
            return true
        end
    end

    for i = 1, (#cards-1) do
        if cards[i].value ~= cards[i+1].value + 1 then
            return false
        end
    end
    return true
end

--3条 KKK85 K9993 KJ888
function suohatool.isSanTiao(cards)
    for i = 1, #cards - 2 do
        if cards[i].value == cards[i + 1].value and cards[i].value == cards[i + 2].value then
            return true
        end
    end
    return false
end

--2对 k7755 77544 66554
function suohatool.isLiangDui(cards)
    local duishu = 0
    for i = 1, #cards - 1 do
        if cards[i].value == cards[i+1].value then
            duishu = duishu + 1
        end
    end

    if duishu == 2 then
        return true
    end

    return false
end

--1对 77543 k7754 98554 98544
function suohatool.isDanDui(cards)
    local duishu = 0
    for i = 1, #cards - 1 do
        if cards[i].value == cards[i+1].value then
            duishu = duishu + 1
        end
    end

    if duishu == 1 then
        return true
    end

    return false
end

------------------------ 出牌流程中，判断玩家手上明牌 能组成的牌型 Start-------------
--4条 8888 最多4张明牌
function suohatool.isSiTiaoTmp(cards)
    if #cards < 4 then
        return false
    end

    if cards[1].value == cards[2].value and  cards[1].value == cards[3].value and cards[1].value == cards[4].value then
        return true
    end

    return false
end

--3条 KKK (最多4张明牌)
function suohatool.isSanTiaoTmp(cards)
    if #cards < 3 then
        return false
    end

    for i = 1, #cards - 2 do
        if cards[i].value == cards[i + 1].value and cards[i].value == cards[i + 2].value then
            return true
        end
    end
    return false
end

--2对 k7755 77544 66554 (最多4张明牌)
function suohatool.isLiangDuiTmp(cards)
    if #cards < 2 then
        return false
    end

    local duishu = 0
    for i = 1, #cards - 1 do
        if cards[i].value == cards[i+1].value then
            duishu = duishu + 1
        end
    end

    if duishu == 2 then
        return true
    end

    return false
end

--1对 77543 k7754 98554 98544
function suohatool.isDanDuiTmp(cards)
    if #cards < 2 then
        return false;
    end

    local duishu = 0
    for i = 1, #cards - 1 do
        if cards[i].value == cards[i+1].value then
            duishu = duishu + 1
        end
    end

    if duishu == 1 then
        return true
    end

    return false
end

--封装每次出牌的时候对应的牌型，第1张牌不参与(2-4张牌)
function suohatool.getCardTypeTmp(cards, typeid)
    suohatool.sortByCardsValue(cards)

    local ret
    if (cards) then

        --《4条
        ret = suohatool.isSiTiaoTmp(cards)
        if ret == true then
            return CardType.SI_TIAO
        end

        --《3条
        ret = suohatool.isSanTiaoTmp(cards)
        if ret == true then
            return CardType.SAN_TIAO;
        end

        --《2对
        ret = suohatool.isLiangDuiTmp(cards)
        if ret == true then
            return CardType.LIANG_DUI;
        end

        -- 《单对
        ret = suohatool.isDanDuiTmp(cards)
        if ret == true then
            return CardType.DAN_DUI
        end
    end
    return CardType.UNDEFINE --散排
end

---------------------------- End --------------------------

--封装获取牌型函数
function suohatool.getCardType(cards, typeid)
    suohatool.sortByCardsValue(cards)

    local ret
    if (cards) then
        --《同花顺
        ret = suohatool.isTongHuaShun(cards)
        if (ret == true) then
            return CardType.TONG_HUA_SHUN;
        end

        --《4条
        ret = suohatool.isSiTiao(cards)
        if ret == true then
            return CardType.SI_TIAO
        end

        --《葫芦
        ret = suohatool.isHuLu(cards)
        if ret == true then
            return CardType.HU_LU;
        end

        --《同花
        ret = suohatool.isTongHua(cards)
        if ret == true then
            return CardType.TONG_HUA;
        end

        --《顺子
        ret = suohatool.isShunZi(cards,typeid)
        if ret == true then
            return CardType.SHUN_ZI;
        end

        --《3条
        ret = suohatool.isSanTiao(cards)
        if ret == true then
            return CardType.SAN_TIAO;
        end

        --《2对
        ret = suohatool.isLiangDui(cards)
        if ret == true then
            return CardType.LIANG_DUI;
        end

        -- 《单对
        ret = suohatool.isDanDui(cards)
        if ret == true then
            return CardType.DAN_DUI
        end
    end
    return CardType.UNDEFINE --散排
end

--获取展示牌型 测试用
function suohatool.getCardTypeNamebyType(cardtype)
    if cardtype == CardType.UNDEFINE then
        return "散牌"
    elseif cardtype == CardType.DAN_DUI then
        return "单对"
    elseif cardtype == CardType.LIANG_DUI then
        return "二对"
    elseif cardtype == CardType.SAN_TIAO then
        return "三条"
    elseif cardtype == CardType.SHUN_ZI then
        return "顺子"
    elseif cardtype == CardType.TONG_HUA then
        return "同花"
    elseif cardtype == CardType.HU_LU then
        return "葫芦"
    elseif cardtype == CardType.SI_TIAO then
        return "四条"
    elseif cardtype == CardType.TONG_HUA_SHUN then
        return "同花顺"
    else
        return "异常牌型"
    end
end


--牌按大到小排列，花色越小越大
local function CardTypeSame( my_Cards, next_Cards, my_Cards_Type )

    --同花顺 待考虑 拥有五张连续性同花色的顺子。以A为首的同花顺最大
    --顺子         以A为首的顺子最大，如果大家都是顺子，比最大的一张牌，如果大小还一样就比这张牌的花色。
    if  my_Cards_Type == CardType.TONG_HUA_SHUN or my_Cards_Type == CardType.SHUN_ZI then

        if my_Cards[1].value > next_Cards[1].value then
            return true
        elseif my_Cards[1].value < next_Cards[1].value then
            return false
        else
            if my_Cards[1].color < next_Cards[1].color then
                return true
            else
                return false
            end
        end
    end

    --同花 先比数字最大的单张，如相同再比第二张、以此类推。
    if my_Cards_Type == CardType.TONG_HUA then
        if my_Cards[1].value > next_Cards[1].value then
            return true
        end
        if my_Cards[1].value < next_Cards[1].value then
            return false
        end
        --比第2张大小
        if my_Cards[2].value > next_Cards[2].value then
            return true
        end
        if my_Cards[2].value < next_Cards[2].value then
            return false
        end
        --比第3张大小
        if my_Cards[3].value > next_Cards[3].value then
            return true
        end
        if my_Cards[3].value < next_Cards[3].value then
            return false
        end
        --比第4张大小
        if my_Cards[4].value > next_Cards[4].value then
            return true
        end
        if my_Cards[4].value < next_Cards[4].value then
            return false
        end
        --比第5张大小
        if my_Cards[5].value > next_Cards[5].value then
            return true
        end
        if my_Cards[5].value < next_Cards[5].value then
            return false
        end
        --醉了, 5张数字都一样 那比第1张的花色
        if my_Cards[1].color < next_Cards[1].color then
            return true
        else
            return false
        end
    end

    --4条(铁支) 3条 葫芦
    --比4条或3条的数字大小
    if  my_Cards_Type==CardType.SI_TIAO or my_Cards_Type==CardType.SAN_TIAO or my_Cards_Type==CardType.HU_LU then
        if my_Cards[3].value > next_Cards[3].value then --第3张牌一定是组成的那张牌
            return true
        end
        return false
    end

    --2对 若遇相同则先比这副牌中最大的一对，如又相同再比第二对，如果还是一样，比大对子中的最大花式  
    if my_Cards_Type == CardType.LIANG_DUI then
        local my_Duizi = {}
        local next_Duizi = {}
        for i = 1, #my_Cards - 1 do
            if my_Cards[i].value == my_Cards[i+1].value then
                my_Duizi[#my_Duizi + 1] = {my_Cards[i], my_Cards[i+1]}
            end
        end
        for i = 1, #next_Cards - 1 do
            if next_Cards[i].value == next_Cards[i+1].value then
                next_Duizi[#next_Duizi + 1] = {next_Cards[i], next_Cards[i+1]}
            end
        end

        --第1个对子
        if my_Duizi[1][1].value > next_Duizi[1][1].value then
            return true
        end
        if my_Duizi[1][1].value < next_Duizi[1][1].value then
            return false
        end

        --第2个对子
        if my_Duizi[2][1].value > next_Duizi[2][1].value then
            return true
        end
        if my_Duizi[2][1].value < next_Duizi[2][1].value then
            return false
        end

        --2对子数字还一样,那就比第1对的花色
        if my_Duizi[1][1].color < next_Duizi[1][1].color then
            return true
        else
            return false
        end
    end

    --单对 由两张相同的牌加上三张单张所组成。如果大家都是对子，比对子的大小，如果对子也一样，比这个对子中的最大花色
    if  my_Cards_Type == CardType.DAN_DUI then
        local my_Duizi = {}
        local next_Duizi = {}
        for i = 1, #my_Cards - 1 do
            if my_Cards[i].value == my_Cards[i+1].value then
                my_Duizi[#my_Duizi + 1] = {my_Cards[i], my_Cards[i+1]}
            end
        end
        for i = 1, #next_Cards - 1 do
            if next_Cards[i].value == next_Cards[i+1].value then
                next_Duizi[#next_Duizi + 1] = {next_Cards[i], next_Cards[i+1]}
            end
        end

        --第1个对子
        if my_Duizi[1][1].value > next_Duizi[1][1].value then
            return true
        end
        if my_Duizi[1][1].value < next_Duizi[1][1].value then
            return false
        end

        --对子数字一样,那就比第1对的花色
        if my_Duizi[1][1].color < next_Duizi[1][1].color then
            return true
        else
            return false
        end
    end

    -- 散牌 单一型态的五张散牌所组成，先比最大一张牌的大小，如果大小一样，比这张牌的花色
    if  my_Cards_Type == CardType.UNDEFINE then
        if my_Cards[1].value > next_Cards[1].value then
            return true
        elseif my_Cards[1].value < next_Cards[1].value then
            return false
        else
            if my_Cards[1].color < next_Cards[1].color then
                return true
            else
                return false
            end
        end
    end
end

--@比牌接口函数  
--@ my_Cards, 本家牌,  
--@ pre_Cards,下家牌,
--@ typeid, 模式，如果最小为8 就传入此值
--@ ret true/false  
function suohatool.isOvercomePrev(my_Cards, next_Cards, typeid)
    --获取各自牌形  
    local my_Cards_Type   = suohatool.getCardType(my_Cards, typeid)
    local next_Cards_Type = suohatool.getCardType(next_Cards, typeid)

    if my_Cards_Type > next_Cards_Type then
        return true
    elseif my_Cards_Type < next_Cards_Type then
        return false
    else
        return CardTypeSame(my_Cards, next_Cards, my_Cards_Type)
    end
end


return suohatool