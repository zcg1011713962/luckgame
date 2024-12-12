--奖池配置
local POOLLIST = {
    [419] = { --老虎| regaltiger                 
        DEF = {NONE = 0, MINI = 1, MINOR = 2, MAJOR = 3, GRAND = 4},
        MULT = {10,50,200,5000},
        UNLOCK = {1,1,1,1},
    },
    [541] = { -- 克拉肯之力 Power Of The Kraken
        DEF = {NONE = 0, MINI = 1, MINOR = 2, MAJOR = 3, GRAND = 4},
        MULT = {5,10,50,1000},
        UNLOCK = {1,1,1,1},
    },
    [635] = {  -- 龙的传说 The Legend of Dragon
        DEF = {NONE = 0, MINI = 1, MINOR = 2, MAJOR = 3, MAXI = 4, GRAND = 5},
        MULT = {10,20,100,200,2000},
        UNLOCK = {1,1,1,1,1},
    },
    [691] = { -- 波斯王子  Father of scientific method
        DEF = {NONE = 0, MINI = 1, MINOR = 2, MAJOR = 3, GRAND=4},
        MULT = {5,10,50,200},
        UNLOCK = {1,1,1,1},
    },
    [692] = { -- 弓箭手 Apollo
        DEF = {NONE = 0, MINI = 1, MINOR = 2, MAJOR = 3, GRAND = 4},
        MULT = {10,20,200,2000},
        UNLOCK = {1,3,5,7},
    },
    [693] = { -- 阿里巴巴四十大盗 Indian
        DEF = {NONE = 0, MINI = 1, MINOR = 2, MAJOR = 3, GRAND=4},
        MULT = {10,30,100,1000},
        UNLOCK = {1,1,1,1},
    },
    [694] = { -- 薛西斯  Hephaestus
        DEF = {NONE = 0, MINI = 1, MINOR = 2, MAJOR = 3, GRAND=4},
        MULT = {10,50,500,2000},
        UNLOCK = {1,1,1,1},
    },
    [695] = { -- 尼布甲尼撒二世和空中花园 Hera
        DEF = {NONE = 0, MINI = 1, MINOR = 2, MAJOR = 3, GRAND=4},
        MULT = {5,20,100,500},
        UNLOCK = {1,1,1,1},
    },
    [696] = { -- 辛巴达航海冒险  Little Red Riding Hood
        DEF = {
            NONE = 0, JP5 = 1, JP6 = 2, JP7 = 3, JP8 = 4, JP9 = 5, 
            JP10 = 6, JP11 = 7, JP12 = 8,JP13 = 9, JP14 = 10
        },
        MULT = {5,10,15,20,30,50,100,150,200,300},
        UNLOCK = {1,1,1,1,1,1,1,1,1,1},
    },
    [697] = {   -- 绚丽的埃及艳后  Gorgeous Cleopatra
        DEF = {NONE = 0, MINI = 1, MINOR = 2, MAJOR = 3, MEGA = 4, GRAND = 5},
        MULT = {10,20,200,1000,5000},
        UNLOCK = {1,3,5,7,9},
    },
    [698] = {  -- 阿拉丁神灯 Lamp of Aladdin
        DEF = {NONE = 0, MINI = 1, MINOR = 2, MAJOR = 3, MEGA = 4, ULTRA = 5, GRAND = 6},
        MULT = {5,10,20,50,500,5000},
        UNLOCK = {1,1,1,1,1,1},
    },
    [699] = { -- 狮身人面像 Sphinx
        DEF = {NONE = 0, MINI = 1, MINOR = 2, MAJOR = 3, MAXI = 4, GRAND = 5},
        MULT = {5,10,25,100,1000},
        UNLOCK = {1,3,5,7,9},
    },
}

return POOLLIST
