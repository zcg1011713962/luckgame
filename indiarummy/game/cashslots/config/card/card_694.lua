-- 694
local cardMap = {
    -- 火山的愤怒
    [1] = {min = 1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "wild"},
    [2] = {min = 3, mult = {[3] = 600, [4] = 2000, [5] = 10000}, double = {}, comment = "scatter(钱币)"},
    [3] = {min = 1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "bonus(火山)"},
    [4] = {min = 3, mult = {[3] = 2000, [4] = 10000, [5] = 50000}, double = {}, comment = "士兵"},
    [5] = {min = 3, mult = {[3] = 1000, [4] = 6000, [5] = 40000}, double = {}, comment = "头盔"},
    [6] = {min = 3, mult = {[3] = 1000, [4] = 5000, [5] = 30000}, double = {}, comment = "盾牌"},
    [7] = {min = 3, mult = {[3] = 1000, [4] = 5000, [5] = 30000}, double = {}, comment = "葡萄酒"},
    [8] = {min = 3, mult = {[3] = 1000, [4] = 4000, [5] = 20000}, double = {}, comment = "A"},
    [9] = {min = 3, mult = {[3] = 1000, [4] = 3000, [5] = 15000}, double = {}, comment = "K"},
    [10] = {min = 3, mult = {[3] = 1000, [4] = 3000, [5] = 15000}, double = {}, comment = "Q"},
    [11] = {min = 3, mult = {[3] = 500, [4] = 2000, [5] = 10000}, double = {}, comment = "J"},
    [12] = {min = 3, mult = {[3] = 500, [4] = 2000, [5] = 10000}, double = {}, comment = "10"},
}
return cardMap
