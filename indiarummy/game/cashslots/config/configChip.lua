

--- @class ChipConfig
local ChipConfig = {
    titleIdx = nil,  -- 标题图标索引
    weight = nil,  -- 图片的权重
    size = nil,  -- 每张拼图的规格
    freeCnt = nil,  -- 触发的免费次数
    mults = {},  -- 免费次数中中线倍率, 比如{1,2,5} 代表第一次1倍，第二次2倍，第三次5倍
    coinMult = nil,  -- 子节点奖励倍率
    coinIdx = nil,  -- 子节点奖励的位置
}

-- 由于Chip中存放的是多个图片，所以权重不能放在图片配置中
local Prob = {
    [423] = 0.05,  -- 墨西哥帅哥
    [429] = 0.06,  -- 吸烟狗
    [435] = 0.06,  -- 钻石森林
    [439] = 0.05,  -- 熊猫
    [447] = 0.04,  -- 珍宝丛林
    [449] = 0.06,  -- 青蛙王子
    [453] = 0.05,  -- 泰山
    [466] = 0.04,  -- 猛犸象
    [603] = 0.04,  -- 波塞冬
    [622] = 0.05,  -- 熊猫
    [632] = 0.05,  -- 吟游诗人 The Minstrel
    [633] = 0.06,  -- 青蛙王子 The Frog Prince
    [634] = 0.04,  -- 猛犸象
    [638] = 0.05,  -- 宫本武藏 Blade Master Tokugawa
}

local Chip = {
    [423] = {
        --- @type ChipConfig
        [1] = {titleIdx=1, weight=100, size=12, freeCnt=10, mults={1,1,1}, coinMult=1, coinIdx={3,6,9}},
    },
    [429] = {
        --- @type ChipConfig
        [1] = {titleIdx=2, weight=100, size=12, freeCnt=7, mults={1,1,1}, coinMult=1, coinIdx={3,6,9}},
    },
    [435] = {
        --- @type ChipConfig
        [1] = {titleIdx=3, weight=100, size=12, freeCnt=7, mults={1,1,1}, coinMult=1, coinIdx={3,6,9}},
    },
    [439] = {  -- 熊猫游戏，没有免费游戏，这个freeCnt无用
        --- @type ChipConfig
        [1] = {titleIdx=4, weight=100, size=12, freeCnt=10, mults={1,1,1}, coinMult=1, coinIdx={3,6,9}},
    },
    [447] = {
        --- @type ChipConfig
        [1] = {titleIdx=5, weight=100, size=12, freeCnt=15, mults={1,1,1}, coinMult=1, coinIdx={3,6,9}},
    },
    [449] = {
        --- @type ChipConfig
        [1] = {titleIdx=6, weight=100, size=12, freeCnt=6, mults={1,1,1}, coinMult=1, coinIdx={3,6,9}},
    },
    [453] = {
        --- @type ChipConfig
        [1] = {titleIdx=7, weight=100, size=12, freeCnt=10, mults={1,1,1}, coinMult=1, coinIdx={3,6,9}},
    },
    [466] = {
        --- @type ChipConfig
        [1] = {titleIdx=8, weight=100, size=12, freeCnt=15, mults={1,1,1}, coinMult=1, coinIdx={3,6,9}},
    },
    [603] = {
        --- @type ChipConfig
        [1] = {titleIdx=5, weight=100, size=12, freeCnt=15, mults={1,1,1}, coinMult=1, coinIdx={3,6,9}},
    },
    [622] = {  -- 熊猫游戏，没有免费游戏，这个freeCnt无用
        --- @type ChipConfig
        [1] = {titleIdx=4, weight=100, size=12, freeCnt=10, mults={1,1,1}, coinMult=1, coinIdx={3,6,9}},
    },
    [632] = {
        --- @type ChipConfig
        [1] = {titleIdx=1, weight=100, size=12, freeCnt=10, mults={1,1,1}, coinMult=1, coinIdx={3,6,9}},
    },
    [633] = {
        --- @type ChipConfig
        [1] = {titleIdx=6, weight=100, size=12, freeCnt=6, mults={1,1,1}, coinMult=1, coinIdx={3,6,9}},
    },
    [634] = {
        --- @type ChipConfig
        [1] = {titleIdx=8, weight=100, size=12, freeCnt=15, mults={1,1,1}, coinMult=1, coinIdx={3,6,9}},
    },
    [638] = {
        --- @type ChipConfig
        [1] = {titleIdx=7, weight=100, size=12, freeCnt=10, mults={1,1,1}, coinMult=1, coinIdx={3,6,9}},
    },
}


return {
    Chip = Chip,
    Prob = Prob,
}