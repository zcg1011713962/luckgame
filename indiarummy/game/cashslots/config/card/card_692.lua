-- 692
local cardMap = {
    ["base"] = {
        [1] = {min=1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "wild"},
        [2] = {min=3, mult = {[3] = 12000, [4] = 15000, [5] = 20000}, double = {}, comment = "scatter"},
        [3] = {min=1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "bonus"},
        [4] = {min=2, mult = {[2] = 200, [3] = 1000, [4] = 5000, [5] = 15000}, double = {}, comment = "魔法师"},
        [5] = {min=3, mult = {[3] = 500, [4] = 3000, [5] = 10000}, double = {}, comment = "猫"},
        [6] = {min=3, mult = {[3] = 500, [4] = 2500, [5] = 10000}, double = {}, comment = "乌鸦"},
        [7] = {min=3, mult = {[3] = 500, [4] = 2000, [5] = 10000}, double = {}, comment = "青蛙"},
        [8] = {min=3, mult = {[3] = 500, [4] = 1500, [5] = 7500}, double = {}, comment = "魔法瓶"},
        [9] = {min=3, mult = {[3] = 500, [4] = 1000, [5] = 5000}, double = {}, comment = "A"},
        [10] = {min=3, mult = {[3] = 500, [4] = 1000, [5] = 5000}, double = {}, comment = "K"},
        [11] = {min=3, mult = {[3] = 500, [4] = 1000, [5] = 5000}, double = {}, comment = "Q"},
        [12] = {min=3, mult = {[3] = 500, [4] = 1000, [5] = 5000}, double = {}, comment = "J"},
        [13] = {min=3, mult = {[3] = 500, [4] = 1000, [5] = 5000}, double = {}, comment = "10"},
    },
    ["free"] = {
        [1] = {min=1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "wild"},
        [2] = {min=3, mult = {[3] = 12000, [4] = 15000, [5] = 20000}, double = {}, comment = "scatter"},
        [3] = {min=1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "bonus"},
        [4] = {min=4, mult = {[4] = 1000, [5] = 10000}, double = {}, comment = "魔法师"},
        [5] = {min=4, mult = {[4] = 1000, [5] = 5000}, double = {}, comment = "猫"},
        [6] = {min=4, mult = {[4] = 1000, [5] = 5000}, double = {}, comment = "乌鸦"},
        [7] = {min=4, mult = {[4] = 1000, [5] = 5000}, double = {}, comment = "青蛙"},
        [8] = {min=4, mult = {[4] = 1000, [5] = 2500}, double = {}, comment = "魔法瓶"},
        [9] = {min=4, mult = {[4] = 500, [5] = 1500}, double = {}, comment = "A"},
        [10] = {min=4, mult = {[4] = 500, [5] = 1500}, double = {}, comment = "K"},
        [11] = {min=4, mult = {[4] = 500, [5] = 1500}, double = {}, comment = "Q"},
        [12] = {min=4, mult = {[4] = 500, [5] = 1500}, double = {}, comment = "J"},
        [13] = {min=4, mult = {[4] = 500, [5] = 1500}, double = {}, comment = "10"},
    }
}
return cardMap
