local controltool = {
    [419] = { --老虎
        freeControl = {probability = 17,},
        bonusControl = {probability = 9,},
        threshold = {common = 80, free = 100},
    },
    [541] = { -- 克拉肯之力 Power Of The Kraken
        freeControl = {probability = 9},
        bonusControl = {probability = 9},
        jackpotControl = {probability = 6},
        threshold = {common = 80, free = 100},
    },
    [635] = { -- 龙的传说 The Legend of Dragon
        freeControl = {probability = 11,},
        bonusControl = {probability = 8,},
        threshold = {common = 80, free = 100},
    },
    [691] = { -- 波斯王子  Father of scientific method
        freeControl = {probability = 12},
        bonusControl = {probability = 8},
        threshold = {common = 80, free = 100},
    },
    [692] = { -- 弓箭手 Apollo
        freeControl = {probability = 12},
        bonusControl = {probability = 9},
        threshold = {common = 80, free = 100},
    },
    [693] = { -- 阿里巴巴四十大盗 Indian
        freeControl = {probability = 11},
        bonusControl = {probability = 8},
        threshold = {common = 80, free = 100},
    },
    [694] = { -- 薛西斯  Hephaestus
        freeControl = {probability = 12},
        bonusControl = {probability = 8},
        threshold = {common = 80, free = 100},
    },
    [695] = { -- 尼布甲尼撒二世和空中花园 Hera
        threshold = {common = 80, free = 100},
    },
    [696] = { -- 辛巴达航海冒险  Little Red Riding Hood
        freeControl = {probability = 11},
        bonusControl = {probability = 8},
        threshold = {common = 80, free = 100},
    },
    [697] = {-- 绚丽的埃及艳后  Gorgeous Cleopatra
        freeControl = {probability = 10,},
        bonusControl = {probability = 10,},
        threshold = {common = 80, free = 100},
    },
    [698] = { -- 阿拉丁神灯 Lamp of Aladdin
        freeControl = {probability = 13,},
        threshold = {common = 80, free = 100},
    },
    [699] = { -- 狮身人面像 Sphinx
        freeControl = {probability = 12}, --免费游戏中有较高概率触发小游戏，因此这个概率不宜过高
        threshold = {common = 80, free = 100},
    },
}

return controltool