-- 691
local cardMap = {
    [1] = {min = 1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "wild"},
    [2] = {min = 3, mult = {[3] = 20000, [4] = 100000, [5] = 200000}, double = {}, comment = "scatter"},
    [3] = {min = 1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "bonus"},
    [4] = {min = 3, mult = {[3] = 5000, [4] = 10000, [5] = 50000}, double = {}, comment = "美女"},
    [5] = {min = 3, mult = {[3] = 2500, [4] = 8000, [5] = 40000}, double = {}, comment = "鹰"},
    [6] = {min = 3, mult = {[3] = 2000, [4] = 5000, [5] = 25000}, double = {}, comment = "头盔"},
    [7] = {min = 3, mult = {[3] = 1500, [4] = 4000, [5] = 20000}, double = {}, comment = "琴"},
    [8] = {min = 3, mult = {[3] = 1000, [4] = 2000, [5] = 10000}, double = {}, comment = "壶"},
    [9] = {min = 3, mult = {[3] = 500, [4] = 1000, [5] = 5000}, double = {}, comment = "A"},
    [10] = {min = 3, mult = {[3] = 500, [4] = 1000, [5] = 5000}, double = {}, comment = "K"},
    [11] = {min = 3, mult = {[3] = 500, [4] = 1000, [5] = 5000}, double = {}, comment = "Q"},
    [12] = {min = 3, mult = {[3] = 500, [4] = 1000, [5] = 5000}, double = {}, comment = "J"},
    [13] = {min = 3, mult = {[3] = 500, [4] = 1000, [5] = 5000}, double = {}, comment = "10"},
}
return cardMap
