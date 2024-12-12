-- 分享转盘奖励配置
local wheelCfg = {
    [1] = {
        rewards = {
            {type=PDEFINE.PROP_ID.COIN, count=1},
        },
        weight=60,
    },
    [2] = {
        rewards = {
            {type=PDEFINE.PROP_ID.COIN, count=5},
        },
        weight=30,
    },
    [3] = {
        rewards = {
            {type=PDEFINE.PROP_ID.COIN, count=10},
        },
        weight=5,
    },
    [4] = {
        rewards = {
            {type=PDEFINE.PROP_ID.COIN, count=15},
        },
        weight=3,
    },
    [5] = {
        rewards = {
            {type=PDEFINE.PROP_ID.COIN, count=20},
        },
        weight=1,
    },
    [6] = {
        rewards = {
            {type=PDEFINE.PROP_ID.COIN, count=50},
        },
        weight=1,
    },
}

return wheelCfg