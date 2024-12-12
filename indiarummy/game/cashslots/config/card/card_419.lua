-- 419
local cardMap = {
    --老虎
    [1] = {min = 1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "wild太乙真人"},
    [2] = {min = 3, mult = {[3] = 10000, [4] = 75000, [5] = 500000}, double = {}, comment = "scatter八卦阵"},
    
    [3] = {min = 2, mult = {[2] = 200, [3] = 1000, [4] = 5000, [5] = 15000}, double = {}, comment = "金光殿"},
    [4] = {min = 3, mult = {[3] = 500, [4] = 3000, [5] = 10000}, double = {}, comment = "船"},
    [5] = {min = 3, mult = {[3] = 500, [4] = 2500, [5] = 10000}, double = {}, comment = "伞"},
    [6] = {min = 3, mult = {[3] = 500, [4] = 2500, [5] = 10000}, double = {}, comment = "莲花"},
    [7] = {min = 3, mult = {[3] = 500, [4] = 2000, [5] = 7500}, double = {}, comment = "A"},
    [8] = {min = 3, mult = {[3] = 500, [4] = 1000, [5] = 5000}, double = {}, comment = "K"},
    [9] = {min = 3, mult = {[3] = 500, [4] = 1000, [5] = 5000}, double = {}, comment = "Q"},
    [10] = {min = 3, mult = {[3] = 500, [4] = 1000, [5] = 5000}, double = {}, comment = "J"},
    [11] = {min = 3, mult = {[3] = 500, [4] = 1000, [5] = 5000}, double = {}, comment = "10"},
    --特殊的卡牌
    [12] = {min = 1000, mult = {[3] = 0, [4] = 0, [5] = 0}, double = {}, comment = "金币"},
}
return cardMap
