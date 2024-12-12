--rummy机器人打牌逻辑

local baseUtils = require "base.utils"
local utils = require "indiarummy.indiarummyutils"

local function formatCard(card)
    return string.format("%0x", card)
end

local function formatCards(cards)
    local str = ""
    for _, card in ipairs(cards) do
        if _==1 then
            str = str..formatCard(card)
        else
            str = str..","..formatCard(card)
        end
    end
    return "["..str.."]"
end

local function formatGroupCards(groupcards)
    local str = ""
    for _, cards in ipairs(groupcards) do
        if _==1 then
            str = str..formatCards(cards)
        else
            str = str..","..formatCards(cards)
        end
    end
    return "["..str.."]"
end

local function printCards(mark, cards)
    print(mark, formatCards(cards))
end

--比牌
local function compareCardValue(card1, card2)
    local v1 = utils.ScanValue(card1)
    local v2 = utils.ScanValue(card2)
    if v1 == v2 then
        return card1 < card2
    else
        return v1 < v2
    end
end

--按牌值排序
local function sortCardsByValue(cards)
    table.sort(cards, compareCardValue)
end

--是否能组顺子
local function isPureSeq(c1, c2, c3)
    return (c1+1 == c2 and c2+1 == c3) or (c1-1 == c2 and c2-1 == c3)
end

--是否能组刻子
local function isSet(c1, c2, c3)
    return (baseUtils.ScanValue(c1) == baseUtils.ScanValue(c2))
         and (baseUtils.ScanValue(c1) == baseUtils.ScanValue(c3))
         and (baseUtils.ScanSuit(c1) ~= baseUtils.ScanSuit(c2))
         and (baseUtils.ScanSuit(c1) ~= baseUtils.ScanSuit(c3))
         and (baseUtils.ScanSuit(c2) ~= baseUtils.ScanSuit(c3))
end

--检测是否有组成顺子或刻子的潜力
local function checkCardValue(cards, card)
    for _, c in ipairs(cards) do
        if baseUtils.ScanValue(c) == baseUtils.ScanValue(card) and baseUtils.ScanSuit(c) ~= baseUtils.ScanSuit(card) then
            return true
        end
        if c == card + 1 or c == card-1 then
            return true
        end
    end
    return false
end

--是否可以组队
local function checkMatchCard(handcards, card)
    --如果能组成顺子
    table.sort(handcards)
    local l = #handcards
    for i = 1, l-1 do
        if isPureSeq(handcards[i], handcards[i+1], card)
            or isPureSeq(handcards[i], card, handcards[i+1])
            or isPureSeq(card, handcards[i], handcards[i+1]) then
            return true
        end
    end
    --如果能组成刻子
    sortCardsByValue(handcards)
    for i=1, l-1 do
        if isSet(handcards[i], handcards[i+1], card) then
            return true
        end
    end
    return false
end

--检查卡牌优先级，返回值越大，优先级越高
local function checkCardPriority(handcards, card, wildCard)
    --如果是王或者癞子，则可要
    if utils.IsWild(card, wildCard) then
        return 4
    end
    --重复牌不要
    if table.contain(handcards, card) then
        return 0
    end
    --如果可以配对
    if checkMatchCard(handcards, card) then
        return 3
    end
    local cardvalue = baseUtils.ScanValue(card)
    --如果有组队的潜力且牌值较小，可以要
    if checkCardValue(handcards, card) and cardvalue <= 6 then
        return 2
    end
    return 1
end

--确定要摸的牌
--card1发牌堆的牌
--card2弃牌堆的牌
local function checkDrawCard(handcards, card1, card2, wildCard)
    local priority1 = checkCardPriority(handcards, card1, wildCard)
    local priority2 = checkCardPriority(handcards, card2, wildCard)
    --取优先级高的
    if priority1 >= priority2 then
        return 1
    else
        return 2
    end
end

--确定是否要弃牌
local function checkDropCard(handcards_, wildCard)
    --如果总点数小于40点，那么无需弃牌
    if utils.getCardsScore(handcards_, wildCard) <= 40 then
        return false
    end

    local handcards = table.copy(handcards_)
    --积分制
    local integral = 0
    for _, card in ipairs(handcards) do
        if utils.IsWild(card, wildCard) then
            integral = integral + 4  --癞子积4分
        end
    end
    table.sort(handcards)
    local l = #handcards
    for i = 2, l do
        if handcards[i]==handcards[i-1]+1 then  --顺子积2分
            integral = integral + 2
        end
    end
    sortCardsByValue(handcards)
    for i = 2, l do
        if baseUtils.ScanValue(handcards[i])==baseUtils.ScanValue(handcards[i-1])
            and baseUtils.ScanSuit(handcards[i])~=baseUtils.ScanSuit(handcards[i-1])
        then
            integral = integral + 1 --刻子积1分
        end
    end
    if integral < 1 then
        if math.random() < 0.3 then
            return true
        end
    elseif integral < 3 then
        if math.random() < 0.2 then
            return true
        end
    elseif integral < 5 then
        if math.random() < 0.1 then
            return true
        end
    end
    return false
end

local function removeCardsFromCards(handcards, removeCards)
    for _, card in ipairs(removeCards) do
        baseUtils.RemoveCard(handcards, card)
    end
end

local function addCardsFromCards(handcards, addCards)
    for _, card in ipairs(addCards) do
        table.insert(handcards, card)
    end
end

--找到牌对应的索引
local function findCardIdx(handcard, card, fromIdx)
    local l = #handcard
    for i = fromIdx, l do
        if handcard[i] == card then
            return i
        end
    end
    return -1
end

--获取所有癞子
local function getWildCards(handcards, wildCard)
    local wilds = {}
    for _, c in ipairs(handcards) do
        if utils.IsWild(c, wildCard) then
            table.insert(wilds, c)
        end
    end
    return wilds
end

--获取不重复的牌
local function getNonredundantCards(handcards)
    local normals = {}
    for _, c in ipairs(handcards) do
        if not table.contain(normals, c) then
            table.insert(normals, c)
        end
    end
    return normals
end

--获取所有不重复的牌(不包括癞子)
local function getNoredundantCardsWithoutWild(handcards, wildCard)
    local normals = {}
    for _, c in ipairs(handcards) do
        if (not utils.IsWild(c, wildCard)) and (not table.contain(normals, c)) then
            table.insert(normals, c)
        end
    end
    return normals
end

--整理手牌
--先找出满足基本条件的牌型，再把剩余的牌尽可能的加入到基本牌型中
local function arrangeCards(handcards_, wildCard)
    local handcards = table.copy(handcards_)
    local groups = {}
    local types = {}
    table.sort(handcards)

    --先找出所有纯顺子
    while true do
        local findout = false
        local l = #handcards
        for i1 = 1, l-2 do
            local i2 = findCardIdx(handcards, handcards[i1]+1, i1+1)
            local i3 = findCardIdx(handcards, handcards[i1]+2, i1+2)
            if i2>0 and i3>0 then
                local pureSeq = {handcards[i1], handcards[i2], handcards[i3]}
                table.insert(groups, pureSeq)
                table.insert(types, utils.CardType.PureSeq)
                removeCardsFromCards(handcards, pureSeq)
                findout = true
                break
            end
        end
        if not findout then
            break
        end
    end

    --找出所有普通顺子
    local normals = {}
    local wilds = {}
    for _, c in ipairs(handcards) do
        if utils.IsWild(c, wildCard) then
            table.insert(wilds, c)
        else
            table.insert(normals, c)
        end
    end
    while true do
        local findout = false
        local l = #normals
        --a*cd 和 ab*d形式
        for i = 1, l-2 do
            local d1 = normals[i+1]-normals[i]-1
            local d2 = normals[i+2]-normals[i+1]-1
            if d1>=0 and d2>=0 and d1+d2 <= 1 and #wilds>=1 then
                local seq
                if d1 == 0 then
                    seq = {normals[i], normals[i+1], table.remove(wilds), normals[i+2]}
                else
                    seq = {normals[i], table.remove(wilds), normals[i+1], normals[i+2]}
                end
                table.insert(groups, seq)
                table.insert(types, utils.CardType.Seq)
                removeCardsFromCards(handcards, seq)
                removeCardsFromCards(normals, seq)
                findout = true
                break
            end
        end
        --ab*形式
        l = #normals
        for i = 1, l-1 do
            if normals[i+1]==normals[i]+1 and #wilds>=1 then
                local seq = {normals[i], normals[i+1], table.remove(wilds)}
                table.insert(groups, seq)
                table.insert(types, utils.CardType.Seq)
                removeCardsFromCards(handcards, seq)
                removeCardsFromCards(normals, seq)
                findout = true
                break
            end
        end
        --a*c形式
        l = #normals
        for i = 1, l-1 do
            if normals[i+1]==normals[i]+2 and #wilds>=1 then
                local seq = {normals[i], table.remove(wilds), normals[i+1]}
                table.insert(groups, seq)
                table.insert(types, utils.CardType.Seq)
                removeCardsFromCards(handcards, seq)
                removeCardsFromCards(normals, seq)
                findout = true
                break
            end
        end
        if not findout then
            break
        end
    end

    sortCardsByValue(handcards) --按牌值排序
    --找出所有真刻子
    normals = getNonredundantCards(handcards)
    while true do
        local findout = false
        local l = #normals
        for i = 1, l-2 do
            if baseUtils.ScanValue(normals[i]) == baseUtils.ScanValue(normals[i+1]) and baseUtils.ScanValue(normals[i]) == baseUtils.ScanValue(normals[i+2]) then
                local set = {normals[i], normals[i+1], normals[i+2]}
                if i+3<=l and baseUtils.ScanValue(normals[i]) == baseUtils.ScanValue(normals[i+3]) then
                    table.insert(set, normals[i+3])
                end
                table.insert(groups, set)
                table.insert(types, utils.CardType.Set)
                removeCardsFromCards(handcards, set)
                removeCardsFromCards(normals, set)
                findout = true
                break
            end
        end
        if not findout then
            break
        end
        normals = getNonredundantCards(handcards)
    end
    --找出所有假刻子
    wilds = getWildCards(handcards, wildCard)
    normals = getNoredundantCardsWithoutWild(handcards, wildCard)
    while true do
        local findout = false
        local l = #normals
        for i = 1, l-1 do
            if (baseUtils.ScanValue(normals[i]) == baseUtils.ScanValue(normals[i+1])) and (#wilds>=1) then
                local set = {normals[i], normals[i+1]}
                table.insert(set, table.remove(wilds))
                removeCardsFromCards(handcards, set)
                removeCardsFromCards(normals, set)
                table.insert(groups, set)
                table.insert(types, utils.CardType.Set)
                findout = true
                break
            end
        end
        if not findout then
            break
        end
        normals = getNoredundantCardsWithoutWild(handcards, wildCard)
    end
    --剩余牌处理
    for i = #handcards, 1, -1 do
        if utils.IsWild(handcards[i], wildCard) then
            --如果剩余癞子，则可以归入普通顺子和刻子
            for idx, group in ipairs(groups) do
                if (types[idx] == utils.CardType.Seq) or (types[idx] == utils.CardType.Set and #group < 4) then
                    table.insert(group, handcards[i])
                    table.remove(handcards, i)
                    break
                end
            end
        else
            --看是否能归入顺子
            for idx, group in ipairs(groups) do
                if (types[idx] == utils.CardType.PureSeq or types[idx] == utils.CardType.Seq) and group[#group]+1 == handcards[i] then
                    table.insert(group, handcards[i])
                    table.remove(handcards, i)
                    break
                end
            end
        end
    end
    --把剩下的牌归入最后一堆
    if #handcards > 0 then
        table.insert(groups, handcards)
        if #handcards == 1 then
            table.insert(types, utils.CardType.Pts)
        else
            table.insert(types, utils.CardType.Invalid)
        end
    end
    return groups, types
end

--确定要打的牌
local function checkDiscardCard(handcards, wildCard)
    --先确定能不能胡牌
    local _handcards = table.copy(handcards)
    for _, discard in ipairs(handcards) do
        --先移除
        baseUtils.RemoveCard(_handcards, discard)
        local groups = arrangeCards(_handcards, wildCard)
        --再加回去
        table.insert(_handcards, discard)

        local score = utils.GetTotalScore(groups, wildCard)
        if score == 0 then
            return true, discard, groups
        end
    end

    --如果invalid牌数大于1张，则打出值最大的牌
    local groups, types = arrangeCards(handcards, wildCard)
    local invalidCards = {}
    for i = 1, #types do
        if types[i] == utils.CardType.Invalid or types[i] == utils.CardType.Pts then
            local group = groups[i]
            for _, card in ipairs(group) do
                if not utils.IsWild(card, wildCard) then
                    table.insert(invalidCards, card)
                end
            end
        end
    end
    if #invalidCards > 0 then
        if #invalidCards > 2 then
            local usefulCards = {}
            table.sort(invalidCards)
            local l = #invalidCards
            --如果有重复牌，直接打出
            for i=1, l-1 do
                if invalidCards[i] == invalidCards[i+1] then
                    return false, invalidCards[i+1]
                end
            end
            --保留相邻牌
            for i=1, l-1 do
                if invalidCards[i]+1 == invalidCards[i+1] then --相邻牌
                    table.insert(usefulCards, invalidCards[i])
                    table.insert(usefulCards, invalidCards[i+1])
                end
            end
            --保留值同牌
            sortCardsByValue(invalidCards)
            if #invalidCards - #usefulCards > 2 then
                for i=1, l-1 do
                    if baseUtils.ScanValue(invalidCards[i]) == baseUtils.ScanValue(invalidCards[i+1])
                    and baseUtils.ScanSuit(invalidCards[i]) ~= baseUtils.ScanSuit(invalidCards[i+1]) then
                        table.insert(usefulCards, invalidCards[i])
                        table.insert(usefulCards, invalidCards[i+1])
                    end
                end
            end
            --打出值大牌
            for i = #invalidCards, 1, -1 do
                if not table.contain(usefulCards, invalidCards[i]) then
                    return false, invalidCards[i]
                end
            end
        end

        sortCardsByValue(invalidCards)
        return false, invalidCards[#invalidCards]
    end

    --遍历可以打出的牌，确定可以打出哪张
    local discardCards = {}
    for _, card in ipairs(handcards) do
        if not utils.IsWild(card, wildCard) then
            if not table.contain(discardCards, card) then
                table.insert(discardCards, card)
            end
        end
    end
    if #discardCards == 0 then
        return false, handcards[#handcards]
    end
    sortCardsByValue(discardCards)
    return false, discardCards[#discardCards]
end

--定牌（排出点数最小的牌型）
--confirm和arrange逻辑略有不同。arrange在于找到任意一种成牌的方案；confirm在于使最终点数最小
local function confirmCards(handcards_, wildCard)
    local handcards = table.copy(handcards_)
    local pureSeqs = {}
    local sets = {}
    local fakeSeqs = {} --假顺子
    local fakeSets = {}  --假刻子

    table.sort(handcards)

    --先找出所有纯顺子
    while true do
        local findout = false
        local l = #handcards
        for i1 = 1, l-2 do
            local i2 = findCardIdx(handcards, handcards[i1]+1, i1+1)
            local i3 = findCardIdx(handcards, handcards[i1]+2, i1+2)
            if i2>0 and i3>0 then
                local pureseq = {handcards[i1], handcards[i2], handcards[i3]}
                table.insert(pureSeqs, pureseq)
                removeCardsFromCards(handcards, pureseq)
                findout = true
                break
            end
        end
        if not findout then
            break
        end
    end

    --找出所有普通顺子
    local normals = {}
    for _, c in ipairs(handcards) do
        if not utils.IsWild(c, wildCard) then
            table.insert(normals, c)
        end
    end
    while true do
        local findout = false
        local l = #normals
        --a*cd 和 ab*d形式
        for i = 1, l-2 do
            local d1 = normals[i+1]-normals[i]-1
            local d2 = normals[i+2]-normals[i+1]-1
            if d1>=0 and d2>=0 and d1+d2 <= 1 then
                local fakeseq
                if d1 == 0 then
                    fakeseq = {normals[i], normals[i+1], normals[i+2]}
                else
                    fakeseq = {normals[i], normals[i+1], normals[i+2]}
                end
                table.insert(fakeSeqs, fakeseq)
                removeCardsFromCards(handcards, fakeseq)
                removeCardsFromCards(normals, fakeseq)
                findout = true
                break
            end
        end
        --ab*形式
        l = #normals
        for i = 1, l-1 do
            if normals[i+1]==normals[i]+1 then
                local fakeseq = {normals[i], normals[i+1]}
                table.insert(fakeSeqs, fakeseq)
                removeCardsFromCards(handcards, fakeseq)
                removeCardsFromCards(normals, fakeseq)
                findout = true
                break
            end
        end
        --a*c形式
        l = #normals
        for i = 1, l-1 do
            if normals[i+1]==normals[i]+2 then
                local fakeseq = {normals[i], normals[i+1]}
                table.insert(fakeSeqs, fakeseq)
                removeCardsFromCards(handcards, fakeseq)
                removeCardsFromCards(normals, fakeseq)
                findout = true
                break
            end
        end
        if not findout then
            break
        end
    end

    sortCardsByValue(handcards) --按牌值排序
    --找出所有真刻子
    normals = getNonredundantCards(handcards)
    while true do
        local findout = false
        local l = #normals
        for i = 1, l-2 do
            if baseUtils.ScanValue(normals[i]) == baseUtils.ScanValue(normals[i+1]) and baseUtils.ScanValue(normals[i]) == baseUtils.ScanValue(normals[i+2]) then
                local set = {normals[i], normals[i+1], normals[i+2]}
                if i+3<=l and baseUtils.ScanValue(normals[i]) == baseUtils.ScanValue(normals[i+3]) then
                    table.insert(set, normals[i+3])
                end
                table.insert(sets, set)
                removeCardsFromCards(handcards, set)
                removeCardsFromCards(normals, set)
                findout = true
                break
            end
        end
        if not findout then
            break
        end
        normals = getNonredundantCards(handcards)
    end
    --找出所有假刻子
    normals = getNoredundantCardsWithoutWild(handcards, wildCard)
    while true do
        local findout = false
        local l = #normals
        for i = 1, l-1 do
            if (baseUtils.ScanValue(normals[i]) == baseUtils.ScanValue(normals[i+1])) then
                local fakeset = {normals[i], normals[i+1]}
                removeCardsFromCards(handcards, fakeset)
                removeCardsFromCards(normals, fakeset)
                table.insert(fakeSets, fakeset)
                findout = true
                break
            end
        end
        if not findout then
            break
        end
        normals = getNoredundantCardsWithoutWild(handcards, wildCard)
    end
    --剩余牌处理
    for i = #handcards, 1, -1 do
        if not utils.IsWild(handcards[i], wildCard) then
            --看是否能归入顺子
            for _, pureseq in ipairs(pureSeqs) do
                if pureseq[#pureseq]+1 == handcards[i] then
                    table.insert(pureseq, handcards[i])
                    table.remove(handcards, i)
                    break
                end
            end
        end
    end

    --纯顺子和真刻子先放入结果
    local groups = {}
    local types = {}
    for _, pureseq in ipairs(pureSeqs) do
        table.insert(groups, pureseq)
        table.insert(types, utils.CardType.PureSeq)
    end
    for _, set in ipairs(sets) do
        table.insert(groups, set)
        table.insert(types, utils.CardType.Set)
    end

    --所有假顺子刻子放一起排序
    local FAKE_SEQ = utils.CardType.Seq
    local FAKE_SET = utils.CardType.Set
    local sortfakes = {}
    for _, fakeseq in ipairs(fakeSeqs) do
        table.insert(sortfakes, {
            cards = fakeseq,
            tp = FAKE_SEQ,
            weight = utils.getCardsScore(fakeseq, wildCard),
            used = 0
        })
    end
    for _, set in ipairs(fakeSets) do
        table.insert(sortfakes, {
            cards = set,
            tp = FAKE_SET,
            weight = utils.getCardsScore(set, wildCard),
            used = 0
        })
    end

    table.sort(sortfakes, function(a, b)
        return a.weight > b.weight
    end)

    local wilds = getWildCards(handcards, wildCard)
    --顺子数小于2
    if #pureSeqs < 2 then
        if #fakeSeqs > 0 then
             --如果有假顺子，则先补充一个顺子
            for _, fake in ipairs(sortfakes) do
                if fake.tp == FAKE_SEQ and #wilds>0 then
                    local cards = fake.cards
                    local wild = table.remove(wilds)
                    table.insert(cards, wild)
                    table.insert(groups, cards)
                    table.insert(types, fake.tp)
                    baseUtils.RemoveCard(handcards, wild)
                    fake.used = 1
                    --找到最大的顺子，加入后退出
                    break
                end
            end
        else
            --如果没有假顺子，看能否造一个
            if #wilds >= 2 and #handcards > 0 then
                local set = {}
                for i = #handcards, 1, -1 do
                    if not utils.IsWild(handcards[i], wildCard) then
                        table.insert(set, handcards[i])
                        table.remove(handcards, i)
                        break
                    end
                end
                if #set > 0 then
                    local wild1 = table.remove(wilds)
                    local wild2 = table.remove(wilds)
                    table.insert(set, wild1)
                    table.insert(set, wild2)
                    table.insert(groups, set)
                    table.insert(types, utils.CardType.Seq)
                    removeCardsFromCards(handcards, {wild1, wild2})
                end
            end
        end
    end
    --再按排序补充其他的
    for _, fake in ipairs(sortfakes) do
        if fake.used == 0 and #wilds>0 then
            local cards = fake.cards
            local wild = table.remove(wilds)
            table.insert(cards, wild)
            table.insert(groups, cards)
            table.insert(types, fake.tp)
            baseUtils.RemoveCard(handcards, wild)
            fake.used = 1
        end
    end
    --剩余的全部归到一起
    for _, fake in ipairs(sortfakes) do
        if fake.used == 0 then
            if #groups < 5 then  --如果能够增加堆数
                table.insert(groups, fake.cards)
                table.insert(types, utils.CardType.Invalid)
            else    --否则全部并入最后一堆
                for _, c in ipairs(fake.cards) do
                    table.insert(handcards, c)
                end
            end
        end
    end

    if #handcards > 0 then
        table.insert(groups, handcards)
        if #handcards == 1 then
            table.insert(types, utils.CardType.Pts)
        else
            table.insert(types, utils.CardType.Invalid)
        end
    end

    return groups, types
end

local function fixCards(user, CardDeck, wild)
    local pureSeqNum = 0
    local seqNum = 0
    local setNum = 0
    local invalidCards = {}  --散排
    local setCards = {} --刻子牌
    for _, group in ipairs(user.round.groupcards) do
        if utils.IsPureSequence(group) then
            pureSeqNum = pureSeqNum + 1
        elseif utils.IsSequence(group, wild) then
            seqNum = seqNum + 1
        elseif utils.IsSet(group, wild) then
            setNum = setNum + 1
            for _, card in ipairs(group) do
                if not utils.IsWild(card, wild) then
                    table.insert(setCards, card)
                end
            end
        else
            for _, card in ipairs(group) do
                if not utils.IsWild(card, wild) then
                    table.insert(invalidCards, card)
                end
            end
        end
    end

    local addCards = {}
    local remCards = {}
    local carddeck = table.copy(CardDeck)
    table.remove(carddeck, 1)  --第一张牌已经明了，不能交换
    if pureSeqNum <= 0 then  --没有纯顺子
        if #invalidCards < 3 then  --如果少于3张，把刻子拆了
            addCardsFromCards(invalidCards, setCards)
        end
        if #invalidCards < 3 then return end

        --补充纯顺子
        local done = false
        table.sort(invalidCards)
        --补一张
        local l = #invalidCards
        for i = 1, l-1 do
            local addcard = -1
            local seq = {}
            if invalidCards[i]+1 == invalidCards[i+1] then
                addcard = invalidCards[i]+2
                seq = {invalidCards[i], invalidCards[i+1]}
            elseif invalidCards[i]+2 == invalidCards[i+1] then
                addcard = invalidCards[i]+1
                seq = {invalidCards[i], invalidCards[i+1]}
            end
            if table.contain(carddeck, addcard) then
                table.insert(addCards, addcard)
                for j = l, 1, -1 do
                    local remcard = invalidCards[j]
                    if not table.contain(seq, remcard) then
                        table.insert(remCards, remcard)
                        break
                    end
                end
                done = true
                break
            end
        end
        --补两张
        if not done then
            local offset = {{1,2}, {-1,1}, {-1,-2}}
            for i = 1, l do
                local seq = {invalidCards[i]}
                for j = 1, #offset do
                    local addcard1 = invalidCards[i] + offset[j][1]
                    local addcard2 = invalidCards[i] + offset[j][2]
                    if table.contain(carddeck, addcard1) and table.contain(carddeck, addcard2) then
                        table.insert(addCards, addcard1)
                        table.insert(addCards, addcard2)
                        for k = l, 1, -1 do
                            local remcard = invalidCards[k]
                            if not table.contain(seq, remcard) then
                                table.insert(remCards, remcard)
                            end
                            if #remCards >= 2 then
                                break
                            end
                        end
                        done = true
                        break
                    end
                end
                if done then break end
            end
        end
    elseif pureSeqNum + seqNum < 2 then  --顺子数小于2
        --补充一个wild
        local done = false
        table.shuffle(invalidCards)
        for _, remcard in ipairs(invalidCards) do
            if not utils.IsWild(remcard, wild) then
                for _, addcard in ipairs(carddeck) do
                    if utils.IsWild(addcard, wild) then
                        table.insert(addCards, addcard)
                        table.insert(remCards, remcard)
                        done = true
                        break
                    end
                end
                if done then break end
            end
        end
    else
        --补充一个刻子
        if #invalidCards >= 3 then
            sortCardsByValue(invalidCards)
            local l = #invalidCards
            local done = false
            for i = 1, l-1 do
                if utils.ScanValue(invalidCards[i]) == utils.ScanValue(invalidCards[i+1]) then
                    for _, addcard in ipairs(carddeck) do
                        if isSet(invalidCards[i], invalidCards[i+1], addcard) then
                            table.insert(addCards, addcard)
                            local remcard = invalidCards[#invalidCards]
                            if i+1 == #invalidCards then
                                remcard = invalidCards[i-1]
                            end
                            table.insert(remCards, remcard)
                            done = true
                            break
                        end
                    end
                    if done then break end
                end
            end
        end
    end

    if #addCards>0 and #addCards==#remCards then
        removeCardsFromCards(user.round.cards, remCards)
        addCardsFromCards(carddeck, remCards)

        removeCardsFromCards(carddeck, addCards)
        addCardsFromCards(user.round.cards, addCards)

        user.round.groupcards = confirmCards(user.round.cards, wild)
    end
end

--稀释玩家手牌
local function diluteUserCards(cards, CardDeck, wildCard)
    table.sort(cards)
    for i = 1, #cards-2 do
        if cards[i]+1 == cards[i+1] and cards[i+1]+1 == cards[i+2] then
            local k = math.random(i, i+2)
            for j = #CardDeck, 2, -1 do
                if not utils.IsWild(CardDeck[j], wildCard) and CardDeck[j] ~= cards[k] then
                    LOG_DEBUG("dilute change_card", formatCard(cards[k]).." => "..formatCard(CardDeck[j]))
                    cards[k], CardDeck[j] = CardDeck[j], cards[k]
                    break
                end
            end
        end
    end
end

--需要的牌
local function checkNeedCards(handcards_, wildCard)
    local handcards = table.copy(handcards_)
    table.sort(handcards)
    local l = #handcards
    for i = 1, l-2 do
        if handcards[i]+1 == handcards[i+1] and handcards[i+1]+1 == handcards[i+2] then
            return {}
        end
    end
    local cards = {}
    for i = 1, l-1 do
        if handcards[i]+1 == handcards[i+1] then
            table.insert(cards, handcards[i]-1)
            table.insert(cards, handcards[i+1]+1)
        elseif handcards[i]+2 == handcards[i+1] then
            table.insert(cards, handcards[i]+1)
        end
    end
    return cards
end

return {
    formatCard = formatCard,
    formatCards = formatCards,
    formatGroupCards = formatGroupCards,
    checkCardPriority = checkCardPriority, --确定卡牌优先级
    checkDrawCard = checkDrawCard,      --确定要摸的牌
    arrangeCards = arrangeCards,        --整理手牌
    checkDiscardCard = checkDiscardCard,--确定要打的牌
    checkDropCard = checkDropCard,      --确定是否要弃牌
    confirmCards = confirmCards,      --定牌
    fixCards = fixCards,                --修牌
    diluteUserCards = diluteUserCards, --稀释手牌
    checkNeedCards = checkNeedCards,   --需要的手牌
}