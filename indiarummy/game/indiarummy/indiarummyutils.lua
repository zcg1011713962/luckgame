--Rummy算法

local CardType =
{
    Invalid = 1,--非法牌
    Pts = 2,    --单牌
    Set = 3,    --刻子
    Seq = 4,    --顺子
    PureSeq = 5,--纯顺子
}

local utils = {}

utils.CardType = CardType

-- 算出牌值
utils.ScanValue = function (value)
    return value & 0x0F
end

-- 算出花色
utils.ScanSuit = function (value)
    return (value & 0xF0) // 16
end

-- 是否癞子
utils.IsWild = function(card, wild)
    return card==0x51 or card == 0x52 or utils.ScanValue(card) == utils.ScanValue(wild)
end

-- 是否大小王
utils.IsJoker = function (value)
    return value == 0x51 or value == 0x52
end

-- 是否A
utils.IsAce = function (value)
    return (value & 0x0F) == 0x0E
end

-- A的小值
utils.GetAceMinValue = function (value)
    return utils.ScanSuit(value) * 16 + 1
end

--计算点数
utils.GetCardPoint = function(card)
    local val = utils.ScanValue(card)
    if val > 10  then  --10以上都算作10点
        return 10
    end
    return val
end

--计算牌组分数
utils.getCardsScore = function(cards, wild)
    local score = 0
    for _, c in ipairs(cards) do
        if not utils.IsWild(c, wild) then  --癞子不算分
            score = score + utils.GetCardPoint(c)
        end
    end
    return score
end

-- 是否顺子
-- 3个或以上同花色的连续牌，癞子可以代替任意牌
-- 顺子优先级高于刻子，如 A,大王，小王的牌型算作顺子而不是刻子
utils.IsSequence = function(cards, wild)
    if #cards < 3 then return false end
    local wildcnt = 0
    local normals = {}
    for _, c in ipairs(cards) do
        if utils.IsWild(c, wild) then
            wildcnt = wildcnt + 1
        else
            table.insert(normals, c)
        end
    end
    local l = #normals
    if l <= 0 then return true end
    -- 判断普通牌是否同花色
    local color = utils.ScanSuit(normals[1])
    for i = 2, l do
        if utils.ScanSuit(normals[i]) ~= color then
            return false
        end
    end
    -- 判断组成顺子需要的万能牌数量
    table.sort(normals)
    local s = 0
    for i = 2, l do
        if normals[i] == normals[i-1] then  --顺子里不能有相同牌
            return false
        end
        s = s + normals[i] - normals[i-1] - 1
    end
    if  s <= wildcnt then
        return true
    end
    --如果有A，需要把A当作1点再算一次
    if utils.IsAce(normals[l]) then
        local c = utils.GetAceMinValue(normals[l])
        s = normals[1]-c-1
        for i = 2, l-1 do
            s = s + normals[i] - normals[i-1] - 1
        end
        if s <= wildcnt then
            return true
        end
    end
    return false
end

-- 是否纯顺子
utils.IsPureSequence = function(cards)
    if #cards < 3 then return false end
    table.sort(cards)
    --A可以放2前面，也可以放K后面
    if utils.IsAce(cards[#cards]) then
        --先把A当1算，再把A当14算
        if cards[1] == utils.GetAceMinValue(cards[#cards]) + 1 then
            local res = true
            for i = 2, #cards - 1 do
                if cards[i] ~= cards[i-1]+1 then
                    res = false
                    break
                end
            end
            if res then return true end
        end
    end
    --正常纯顺子
    for i = 2, #cards do
        if cards[i] ~= cards[i-1]+1 then
            return false
        end
    end
    return true
end

-- 是否刻子
-- 刻子由3张或4张数值相同花色不同的牌组成，癞子可以代替任意牌
utils.IsSet = function(cards, wild)
    if #cards < 3 or #cards > 4 then return false end

    local wildcnt = 0
    local normals = {}
    for _, c in ipairs(cards) do
        if utils.IsWild(c, wild) then
            wildcnt = wildcnt + 1
        else
            table.insert(normals, c)
        end
    end

    local l = #normals
    for i = 1, l-1 do
        for j = i+1, l do
            local c1 = normals[i]
            local c2 = normals[j]
            -- 是否同值
            if utils.ScanValue(c1) ~= utils.ScanValue(c2) then
                return false
            end
            -- 是否不同花色
            if utils.ScanSuit(c1) == utils.ScanSuit(c2) then
                return false
            end
        end
    end

    return true
end

--计算手牌总分数
utils.GetTotalScore = function(groupcards, wild)
    local groupscores = {}
    local grouptypes = {}
    local pureSeqNum = 0
    local seqNum = 0
    for _, group in ipairs(groupcards) do
        local cardtype = CardType.Invalid
        if utils.IsPureSequence(group) then
            cardtype = CardType.PureSeq
            pureSeqNum = pureSeqNum + 1
        elseif utils.IsSequence(group, wild) then
            cardtype = CardType.Seq
            seqNum = seqNum + 1
        elseif utils.IsSet(group, wild) then
            cardtype = CardType.Set
        elseif #group == 1 then
            cardtype = CardType.Pts
        end
        local cardscore = utils.getCardsScore(group, wild)
        table.insert(grouptypes, cardtype)
        table.insert(groupscores, cardscore)
    end

    local totalScore = 0
    for i = 1, #groupcards do
        local score = groupscores[i]
        if grouptypes[i] == CardType.PureSeq then  --纯顺子不算分
            score = 0
        else
            -- 如果满足至少两条顺子，且有一个纯顺子，则成型的牌不算分
            if pureSeqNum > 0 and pureSeqNum + seqNum >= 2 and grouptypes[i] ~= CardType.Invalid and grouptypes[i] ~= CardType.Pts then
                score = 0
            end
        end
        totalScore = totalScore + score
    end

    return math.min(totalScore, 80)
end

--按花色自动分组
utils.GroupCards = function(cards)
    local groups = {}
    for suit = 1, 5 do
        local cs = {}
        for _, card in ipairs(cards) do
            if utils.ScanSuit(card) == suit then
                table.insert(cs, card)
            end
        end
        if #cs > 0 then
            table.insert(groups, cs)
        end
    end
    return groups
end

--比较两手牌是否相等
utils.EqulCards = function (cards1, cards2)
    if #cards1 ~= #cards2 then return false end
    table.sort(cards1)
    table.sort(cards2)
    for i = 1, #cards1 do
        if cards1[i] ~= cards2[i] then
            return false
        end
    end
    return true
end

--检查牌组是否合法（与手牌比对）
utils.CheckGroups = function(groupcards, cards)
    if not groupcards or type(groupcards) ~= "table" then
        return PDEFINE.RET.ERROR.PARAMS_ERROR
    end
    if #groupcards > 6 then
        return PDEFINE.RET.ERROR.PARAMS_ERROR
    end
    --检查牌数量
    local handcards = {}
    for _, group in ipairs(groupcards) do
        if type(group) ~= "table" then
            return PDEFINE.RET.ERROR.PARAMS_ERROR
        end
        for _, card in ipairs(group) do
            table.insert(handcards, card)
        end
    end
    if not utils.EqulCards(handcards, cards) then
        return PDEFINE.RET.ERROR.HAND_CARDS_ERROR
    end
    return 0
end

--洗牌
utils.RandomCards = function(cards)
    for i = #cards, 2, -1 do
        local j = math.random(i)
        cards[i], cards[j] = cards[j], cards[i]
    end
    return cards
end


return utils