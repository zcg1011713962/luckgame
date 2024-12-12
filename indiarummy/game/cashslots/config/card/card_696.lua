-- 696
local cardMap = {
    -- 航海宝藏(经游戏内验算，这里实际赔率是帮助页面上的2.5倍)
    [1] = {min = 1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "wild"},
    [2] = {min = 3, mult = {[3] = 50000, [4] = 80000, [5] = 200000}, double = {}, comment = "scatter(指南针)"},
    [3] = {min = 1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "bonus(钱币)"},
    [4] = {min = 3, mult = {[3] = 2500, [4] = 12500, [5] = 62500}, double = {}, comment = "海盗"},
    [5] = {min = 3, mult = {[3] = 2000, [4] = 10000, [5] = 37500}, double = {}, comment = "猴子"},
    [6] = {min = 3, mult = {[3] = 2000, [4] = 7500, [5] = 37500}, double = {}, comment = "鹦鹉"},
    [7] = {min = 3, mult = {[3] = 1750, [4] = 7500, [5] = 25000}, double = {}, comment = "地图"},
    [8] = {min = 3, mult = {[3] = 1750, [4] = 6250, [5] = 25000}, double = {}, comment = "锚"},
    [9] = {min = 3, mult = {[3] = 1250, [4] = 5000, [5] = 10000}, double = {}, comment = "A"},
    [10] = {min = 3, mult = {[3] = 1250, [4] = 5000, [5] = 8750}, double = {}, comment = "K"},
    [11] = {min = 3, mult = {[3] = 1000, [4] = 3750, [5] = 7500}, double = {}, comment = "Q"},
    [12] = {min = 3, mult = {[3] = 1000, [4] = 3750, [5] = 7500}, double = {}, comment = "J"},
    [13] = {min = 3, mult = {[3] = 1000, [4] = 2500, [5] = 6250}, double = {}, comment = "10"},
    [14] = {min = 3, mult = {[3] = 1000, [4] = 2500, [5] = 6250}, double = {}, comment = "9"},
}
return cardMap
