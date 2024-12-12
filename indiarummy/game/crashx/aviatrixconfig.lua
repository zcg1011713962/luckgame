local config = {
    --筹码
    Chips = {1, 10, 50, 100, 500, 1000, 5000},
    --游戏状态
    State = {
        --Free = 1,   --空闲阶段
        Betting = 2,  --押注阶段
        Play = 3,     --游戏阶段
    },
    --状态时长（秒）
    Times = {
        BettingTime = 6,--押注阶段时长
        WaitTime = 3,   --游戏结束后等待下一局开始的时间
    },
    --飞行二次函数系数(时间与倍数关系)  mult = a*t*t + b*t + c
    Quad = {
        a = 0.008,
        b = 0.045,
        c = 1
    },
    -- 结果权重
    MultWeight = {
        {min=100, max=150, weight=390},
        {min=151, max=200, weight=200},
        {min=201, max=300, weight=125},
        {min=301, max=400, weight=90},
        {min=401, max=600, weight=75},
        {min=601, max=900, weight=56},
        {min=901, max=1200, weight=36},
        {min=1201, max=1600, weight=16},
        {min=1601, max=2000, weight=8},
        {min=2001, max=2500, weight=4},
    },
}

return config
