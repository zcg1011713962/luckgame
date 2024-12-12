local config = {}

config.SPORT_MODE_DAILY = 1    -- 日常赛
config.SPORT_MODE_FINAL = 2    -- 总决赛

config.SPORT_STATUS_END = 0     -- 结束
config.SPORT_STATUS_INIT = 1    -- 未开始
config.SPORT_STATUS_GOING = 2   -- 进行中

config.DAILY_SPORT_BEGIN_HOUR = 8   -- 日常赛首场时间
config.DAILY_SPORT_END_HOUR = 3    -- 日常赛末场时间（第二天3点）
config.DAILY_SPORT_CHAMPIONS_REDIS_KEY = "daily_sport_champions"

config.FINAL_SPORT_BEGIN_WDAY = 6   -- 总决赛开始星期五(星期天为1)
config.FINAL_SPORT_BEGIN_HOUR = 20  -- 总决赛开始小时
config.FINAL_SPORT_ROUND_DURATION = 20*60   -- 总决赛初赛持续时间

config.MAX_GAME_COUNT = 5  -- 每轮比赛最多进行的游戏次数

config.DAILY_SPORT_COIN_THRESHOLD = 300000 --日常赛需要的金币
config.FINAL_SPORT_COIN_THRESHOLD = 1000000 --总决赛需要的金币

config.SPORT_ID_REDIS_KEY = "d_sport:sport_id"

-- 日常赛房间参数
config.DAILY_SPORT_ROOM_PARAM = {
    gameid = 252,
    ssid = 2,
}

-- 日常赛排名奖励
config.DAILY_SPORT_RANK_REWARD = {
    [1] = 100000,
    [2] = 90000,
    [3] = 80000,
    [4] = 70000,
    [5] = 60000,
}

-- 总决赛房间参数
config.FINAL_SPORT_ROOM_PARAM = {
    gameid = 252,
    ssid = 2
}

-- 总决赛排名奖励
config.FINAL_SPORT_RANK_REWARD = {
    [1] = 500000,
    [2] = 450000,
    [3] = 400000,
    [4] = 350000,
    [5] = 300000,
    [6] = 250000,
    [7] = 200000,
    [8] = 150000,
    [9] = 100000,
    [10] = 50000,
}

config.FINAL_SPORT_FINAL_PLAYER_COUNT = 20  --总决赛二轮人数

config.MAX_RANK_COUNT = 100      -- 排行榜保存的最大排名数



return config