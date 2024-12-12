--押注额度
local BET_COIN = {
    1,
    5,
    10,
    20,
    30,
    50,
    100,
    200,
    300,
    500,
    750,
    1000,
    1500,
    2000,
    5000,
}

-- 押注挡位额调节值
local STAKE_ADJUST_RATE = {
    [1] = 1.01,
    [2] = 1.0,
    [3] = 1.0,
    [4] = 1.0,
    [5] = 1.0,
    [6] = 1.0,
    [7] = 1.0,
    [8] = 1.0,
    [9] = 0.99,
    [10] = 0.99,
    [11] = 0.98,
    [12] = 0.98,
    [13] = 0.97,
    [14] = 0.96,
    [15] = 0.95,
}

--押注增加RP值
local ADD_RP_VALUE = {
   [1] = 0,
   [2] = 0,
   [3] = 1,
   [4] = 1,
   [5] = 2,
   [6] = 3,
   [7] = 4,
   [8] = 5,
   [9] = 6,
   [10] = 8,
   [11] = 10,
   [12] = 12,
   [13] = 14,
   [14] = 16,
   [15] = 18,
   [16] = 20,
   [17] = 24,
   [18] = 30,
}

--押注增加RP概率
local ADD_RP_PROBABILITY = 0.25

--押注转化为金猪存量的概率
local BET_MB_PROBABILITY = 0.4

--押注转化为金猪存量的比例
local BET_MB_PROPORTION = 0.12

--赢分转化为联赛积分的比例
--因为rtp约为0.92，因此1w的金币要消耗完，会产生0.92+0.92^2+0.92^3...的赢分，即11.5倍赢分，因此设置转化比率为1/11.5
local WINCOIN_LEAGUESCORE_PROPORTION = 0.087

-- 优化免费触发间隔的游戏ID
-- 不要随便往这个列表里添加游戏，有些游戏的免费触发方式比较特殊，需要验证过后才能添加
-- 603/613/624/628/631/633/637/640/659/668因为特殊机制不适合加入
local AUTO_OPTIMIZE_FREE_TRIGGER_GAME_ID = {
    691, --波斯王子
    692, --弓箭手
    693, --阿里巴巴
    694, --薛西斯
    696, --辛巴达
    697, --埃及艳后
    698, --阿拉丁神灯
    699, --狮身人面像
}

-- 优化BONUS触发间隔的游戏ID

local AUTO_OPTIMIZE_BONUS_TRIGGER_GAME_ID = {
}

return {
    BET_COIN = BET_COIN,
    STAKE_ADJUST_RATE = STAKE_ADJUST_RATE,
    ADD_RP_VALUE = ADD_RP_VALUE,
    ADD_RP_PROBABILITY = ADD_RP_PROBABILITY,
    BET_MB_PROBABILITY = BET_MB_PROBABILITY,
    BET_MB_PROPORTION = BET_MB_PROPORTION,
    WINCOIN_LEAGUESCORE_PROPORTION = WINCOIN_LEAGUESCORE_PROPORTION,
    AUTO_OPTIMIZE_FREE_TRIGGER_GAME_ID = AUTO_OPTIMIZE_FREE_TRIGGER_GAME_ID,
    AUTO_OPTIMIZE_BONUS_TRIGGER_GAME_ID = AUTO_OPTIMIZE_BONUS_TRIGGER_GAME_ID,
}