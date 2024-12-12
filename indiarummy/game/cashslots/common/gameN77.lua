
--[[
    元素id    元素图片    元素类型
    1    2x    1
    2    3x    1
    3    5x    1
    4    红7   2
    5    蓝7   2
    6    3bar  3
    7    2bar  3
    8    bar   3
    转到3个同类型元素则停止旋转，计算赔率
    赔率
    类型    元素    赔率    权重
    1   123MIXED    3117    1
    2   45MIXED     7.5     400
        444         25      125
        555         9       200
    3   666         9.4     350
        777         7.5     400
        888         5       800
        678MIXED    2.5     1500
]]--

local CLASSIC = { -- 经典转轴
    widls = {type = 1, cards = {1, 2, 3}},        --type1类型的是wild
    cards = { --卡牌定义
        [1] = {pic = "2X", type = 1},
        [2] = {pic = "3X", type = 1},
        [3] = {pic = "5X", type = 1},

        [4] = {pic = "红7", type = 2},
        [5] = {pic = "蓝7", type = 2},

        [6] = {pic = "3bar", type = 3},
        [7] = {pic = "2bar", type = 3},
        [8] = {pic = "bar", type = 3},
    },
    wincards = {
        group = {       
            {1, 2, 3},  --组合， 1/2/3位1号组合取types中1号数据结果
            {4, 5},     --组合， 4/5位1号组合取types中2号数据结果
            {4},
            {5},
            {6},
            {7},
            {8},
            {6, 7, 8}   --组合， 6/7/8位1号组合取types中3号数据结果
        },
        weigth = {0, 400, 125, 200, 350, 400, 800, 1500},
    },
    cardmap = {
        [1] = {1,2,3,4,5,6,7,8,},
        [2] = {1,2,3,4,5,6,7,8,},
        [3] = {1,2,3,4,5,6,7,8,},
    },
    types = {   --根据类型算分 card_0 是否是一样的图片
        [1] = {
            card_0 = 2500, --任意*X同类型元素,
        },
        [2] = {
            card_4 = 25,    --3个红7 
            card_5 = 9,     --3个蓝7
            card_0 = 7.5,   --任意3个7，
        },
        [3] = {
            card_6 = 9.4,   --3个3bar
            card_7 = 7.5,   --2个2bar
            card_8 = 5,     --3个1bar
            card_0 = 2.5,   --任意3个bar
        },
    },
}

--发牌
local function getClassicCards(config)
    local cards = {}
    for i = 1, 3 do
        local idx = math.random(1, #config.cardmap[i])
        local tmp = config.cardmap[i][idx]
        table.insert(cards, tmp)
    end
    return cards
end

--计算
local function caulClassicCards(cards, config)
    --是否是同一类型
    local mult = 0
    local tmp_type = config.cards[cards[1]].type
    local is_same_type = tmp_type
    for i = 2, 3 do
        local t_type =  config.cards[cards[i]].type
        if is_same_type == config.widls.type then
            if  t_type == config.widls.type  then
                is_same_type = 1        --wild的type类型为1
            else
                is_same_type = t_type
            end
        else
            --如果下一张牌不是wild而且和上一张不相等
            if t_type ~= config.widls.type and is_same_type ~= t_type then
                is_same_type = 0
                break
            end
        end
    end

    if is_same_type ~= 0 then
        if is_same_type ~= 1 then
            local tmp_card = cards[1]
            local is_same_card = tmp_card
            for i = 2, 3 do
                local t_card = cards[i]
                if table.contain(CLASSIC.widls.cards, is_same_card) then
                    is_same_card = t_card
                else
                    if not table.contain(CLASSIC.widls.cards, t_card) and t_card ~= is_same_card then
                        is_same_card = 0
                        break
                    end
                end
            end
            if is_same_card > 0 then
                mult = config.types[is_same_type]["card_"..is_same_card]
            else
                mult = config.types[is_same_type].card_0
            end
        else
            mult = config.types[1].card_0
        end
    end

    return mult
end

--直到中奖为止
local function get(cfg)
    local config = nil
    if cfg then
        config = cfg
    else
        config = table.copy(CLASSIC)
    end

    local retobj = {}
    local cardsList = {}

    local lose_cnt = math.random(1, 4)
    for i = 1, 500 do
        local cards = getClassicCards(config)
        local mult = caulClassicCards(cards, config)
        if mult <= 0 then
            table.insert(cardsList, cards)
        end
        if #cardsList >= lose_cnt then
            break
        end
    end

    --找一组必赢的牌
    local idx = lottery(config.wincards.weigth)
    local group = config.wincards.group[idx]
    --任意组合成3个
    local win_cards = {}
    for i = 1, 3 do
        table.insert(win_cards, group[math.random(1, #group)])
    end
    table.insert(cardsList, win_cards)
    local mult = caulClassicCards(win_cards, config)

    retobj.cardsList = cardsList
    retobj.mult = mult
    return retobj
end

return {
    get = get,
}
