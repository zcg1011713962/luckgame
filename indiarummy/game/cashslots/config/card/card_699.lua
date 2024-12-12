-- 652
local cardMap = {
    [1] = {min=1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "wild"},
    [2] = {min=1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "scatter"},
    [3] = {min=1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "bonus"},
    [4] = {min=3, mult = {[3] = 2000, [4] = 5000, [5] = 10000}, double = {}, comment = "法老"},
    [5] = {min=3, mult = {[3] = 1000, [4] = 2000, [5] = 4000}, double = {}, comment = "牛"},
    [6] = {min=3, mult = {[3] = 800, [4] = 1600, [5] = 3500}, double = {}, comment = "狗"},
    [7] = {min=3, mult = {[3] = 700, [4] = 1400, [5] = 3000}, double = {}, comment = "猫"},
    [8] = {min=3, mult = {[3] = 600, [4] = 1200, [5] = 2500}, double = {}, comment = "蛇"},
    [9] = {min=3, mult = {[3] = 500, [4] = 1000, [5] = 2000}, double = {}, comment = "鸟"},
    [10] = {min=3, mult = {[3] = 300, [4] = 600, [5] = 1500}, double = {}, comment = "A"},
    [11] = {min=3, mult = {[3] = 300, [4] = 600, [5] = 1500}, double = {}, comment = "K"},
    [12] = {min=3, mult = {[3] = 300, [4] = 600, [5] = 1500}, double = {}, comment = "Q"},
    [13] = {min=3, mult = {[3] = 300, [4] = 600, [5] = 1500}, double = {}, comment = "J"},
    [14] = {min=3, mult = {[3] = 300, [4] = 600, [5] = 1500}, double = {}, comment = "10"},
    [15] = {min=3, mult = {[3] = 300, [4] = 600, [5] = 1500}, double = {}, comment = "9"},

    [301] = {min=1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "特殊bonus图标"},
}
return cardMap
