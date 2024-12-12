local skynet = require "skynet"
local player_tool = require "base.player_tool"
local DEBUG = skynet.getenv("DEBUG")
local PROP_ID = PDEFINE.PROP_ID

local Status = {
    Wait = 0,  -- 等待开始
    Doing = 1,  -- 正在进行
    Finish = 2,  -- 已结束
}

local config = {
    -- [week] = {begin给前端显示的时间，sHour=开始小时, sMin=开始分钟, duration=持续时间, level=赛事等级, gameid=游戏id, score=入场费限制}
    [1] = {
        {id=101,week=1, begin="14:00", sHour=14, sMin=0, duration=30, level=2,rewardId=2, gameid=PDEFINE.GAME_TYPE.DOMINO, stype=PDEFINE.RACE_TYPE.DOMINO_WIN_COUNT, score=10000},
        {id=102,week=1, begin="20:00", sHour=20, sMin=0, duration=45, level=1,rewardId=1, gameid=PDEFINE.GAME_TYPE.DOMINO, stype=PDEFINE.RACE_TYPE.DOMINO_WIN_COUNT, score=50000},
    },
    [2] = {
        {id=201,week=2, begin="14:00", sHour=14, sMin=0, duration=30, level=2,rewardId=2, gameid=PDEFINE.GAME_TYPE.TEENPATTI, stype=PDEFINE.RACE_TYPE.PAIR_CARD_COUNT, score=10000},
        {id=202,week=2, begin="20:00", sHour=20, sMin=0, duration=45, level=1,rewardId=1, gameid=PDEFINE.GAME_TYPE.TEENPATTI, stype=PDEFINE.RACE_TYPE.PAIR_CARD_COUNT, score=50000},
    },
    [3] = {
        {id=301,week=3, begin="14:00", sHour=14, sMin=0, duration=30, level=2,rewardId=2, gameid=PDEFINE.GAME_TYPE.DOMINO, stype=PDEFINE.RACE_TYPE.ROUND_WIN_COUNT, score=10000},
        {id=302,week=3, begin="20:00", sHour=20, sMin=0, duration=45, level=1,rewardId=1, gameid=PDEFINE.GAME_TYPE.DOMINO, stype=PDEFINE.RACE_TYPE.ROUND_WIN_COUNT, score=50000},
    },
    [4] = {
        {id=401,week=4, begin="13:00", sHour=14, sMin=0, duration=30, level=2,rewardId=2, gameid=PDEFINE.GAME_TYPE.DOMINO, stype=PDEFINE.RACE_TYPE.DOMINO_WIN_COUNT, score=10000},
        {id=402,week=4, begin="20:00", sHour=20, sMin=0, duration=45, level=1,rewardId=1, gameid=PDEFINE.GAME_TYPE.DOMINO, stype=PDEFINE.RACE_TYPE.DOMINO_WIN_COUNT, score=50000},
    },
    [5] = {
        {id=501,week=5, begin="14:00", sHour=14, sMin=0, duration=30, level=2,rewardId=2, gameid=PDEFINE.GAME_TYPE.DOMINO, stype=PDEFINE.RACE_TYPE.ROUND_WIN_COUNT, score=10000},
        {id=502,week=5, begin="20:00", sHour=20, sMin=0, duration=45, level=1,rewardId=1, gameid=PDEFINE.GAME_TYPE.DOMINO, stype=PDEFINE.RACE_TYPE.ROUND_WIN_COUNT, score=50000},
    },
    [6] = {
        {id=601,week=6, begin="14:00", sHour=14, sMin=0, duration=30, level=2,rewardId=2, gameid=PDEFINE.GAME_TYPE.TEENPATTI, stype=PDEFINE.RACE_TYPE.ROUND_WIN_COUNT, score=10000},
        {id=602,week=6, begin="20:00", sHour=20, sMin=0, duration=45, level=1,rewardId=1, gameid=PDEFINE.GAME_TYPE.TEENPATTI, stype=PDEFINE.RACE_TYPE.ROUND_WIN_COUNT, score=50000},
    },
    [7] = {
        {id=701,week=7, begin="14:00", sHour=14, sMin=0, duration=30, level=2,rewardId=2, gameid=PDEFINE.GAME_TYPE.DOMINO, stype=PDEFINE.RACE_TYPE.DOMINO_WIN_COUNT, score=10000},
        {id=702,week=7, begin="20:00", sHour=20, sMin=0, duration=45, level=1,rewardId=1, gameid=PDEFINE.GAME_TYPE.DOMINO, stype=PDEFINE.RACE_TYPE.DOMINO_WIN_COUNT, score=50000},
    },
}

local rewards = {
    [1] = {
        [1] = {lrank=1, rrank=1, rewards = {
            {type=PROP_ID.DIAMOND, count=500}, 
            {type=PROP_ID.SKIN_CHARM, count=20, img="gift_5"}, 
            {type=PROP_ID.SKIN_CHARM, count=3, img="gift_tea"},
            {type=PROP_ID.SKIN_EXP, count=1, img="exp_25"},
            {type=PROP_ID.SKIN_TABLE, count=1, img='desk_006', days=3},
            {type=PROP_ID.SKIN_FRAME, count=1, img='avatarframe_2003', days=3},
            {type=PROP_ID.SKIN_CHAT, count=1, img='chat_008', days=3},
        }},
        [2] = {lrank=2, rrank=10, rewards = {
            {type=PROP_ID.DIAMOND, count=120}, 
            {type=PROP_ID.SKIN_CHARM, count=10, img="gift_5"}, 
            {type=PROP_ID.SKIN_CHARM, count=1, img="gift_tea"},
            {type=PROP_ID.SKIN_TABLE, count=1, img='desk_006', days=3},
        }},
        [3] = {lrank=11, rrank=100, rewards = {
            {type=PROP_ID.DIAMOND, count=40},
        }},
    },
    [2] = {
        [1] = {lrank=1, rrank=1, rewards = {
            {type=PROP_ID.DIAMOND, count=100}, 
            {type=PROP_ID.SKIN_CHARM, count=5, img="gift_1"}, 
            {type=PROP_ID.SKIN_CHARM, count=5, img="gift_2"},
            {type=PROP_ID.SKIN_CHARM, count=1, img="gift_cake"},
            {type=PROP_ID.SKIN_TABLE, count=1, img='desk_008', days=3},
        }},
        [2] = {lrank=2, rrank=10, rewards = {
            {type=PROP_ID.DIAMOND, count=40}, 
            {type=PROP_ID.SKIN_CHARM, count=3, img="gift_1"}, 
            {type=PROP_ID.SKIN_CHARM, count=1, img="gift_tea"},
            {type=PROP_ID.SKIN_TABLE, count=1, img='desk_008', days=1},
        }},
        [3] = {lrank=11, rrank=100, rewards = {
            {type=PROP_ID.DIAMOND, count=10},
        }},
    },
}

-- 存放游戏对应名次的大概阈值
-- [rewardId] = {[gameid] = {race_type={1名,2-10名,11-100名}}}
local rankConfig = {
    [1] = {
        [PDEFINE.GAME_TYPE.DOMINO] = {
            [PDEFINE.RACE_TYPE.DOMINO_WIN_COUNT] = {80,60,40},
            [PDEFINE.RACE_TYPE.ROUND_WIN_COUNT] = {26,18,15}
        },
        [PDEFINE.GAME_TYPE.TEENPATTI] = {
            [PDEFINE.RACE_TYPE.PAIR_CARD_COUNT] = {15,10,1},
            [PDEFINE.RACE_TYPE.ROUND_WIN_COUNT] = {25,15,5},
        },
        [PDEFINE.GAME_TYPE.TEXAS_HOLDEM] = {
            [PDEFINE.RACE_TYPE.ROUND_WIN_COUNT] = {20,12,5},
        },
    },
    [2] = {
        [PDEFINE.GAME_TYPE.DOMINO] = {
            [PDEFINE.RACE_TYPE.DOMINO_WIN_COUNT] = {55,40,25},
            [PDEFINE.RACE_TYPE.ROUND_WIN_COUNT] = {18,12,9}
        },
        [PDEFINE.GAME_TYPE.TEENPATTI] = {
            [PDEFINE.RACE_TYPE.PAIR_CARD_COUNT] = {15,10,1},
            [PDEFINE.RACE_TYPE.ROUND_WIN_COUNT] = {25,15,5},
        },
        [PDEFINE.GAME_TYPE.TEXAS_HOLDEM] = {
            [PDEFINE.RACE_TYPE.ROUND_WIN_COUNT] = {20,12,5},
        },
    }
}

local function getGameInfo(raceid, get_user)
    local now = os.time()
    local zeroTime = 1
    local week = tonumber(os.date("%w", now))
    local hour = tonumber(os.date("%H", now))
    local minute = tonumber(os.date("%M", now))
    local second = tonumber(os.date("%S", now))
    if week == 0 then
        week = 7
    end
    local allGames = {}
    local restTime = nil
    for i = 0, 6, 1 do
        local fweek = i + week
        if fweek > 7 then
            fweek = fweek - 7
        end
        local games = table.copy(config[fweek])
        for _, game in ipairs(games) do
            if get_user then
                local lastUserUid = do_redis({"get", PDEFINE.REDISKEY.RACE.last_user..game.id})
                if lastUserUid then
                    local lastUser = player_tool.getSimplePlayerInfo(tonumber(lastUserUid))
                    if lastUser then
                        game.firstUser = {uid=lastUser.uid, usericon=lastUser.usericon, playername=lastUser.playername, avatarframe=lastUser.avatarframe}
                    end
                end
            end
            if i == 0 then
                if hour < game.sHour or (hour == game.sHour and game.sMin > minute) then
                    game.status = Status.Wait
                    game.restTime = (game.sMin - minute + (game.sHour-hour)*60)*60 - second
                    if not restTime then
                        restTime = game.restTime
                    end
                elseif (hour > game.sHour or game.sMin <= minute) and game.sMin + game.duration > (hour-game.sHour)*60 + minute then
                    game.status = Status.Doing
                    game.restTime = (game.sMin + game.duration - (hour-game.sHour)*60 - minute)*60 - second
                    if not restTime then
                        restTime = game.restTime
                    end
                else
                    game.status = Status.Finish
                end
                if raceid and raceid == game.id then
                    return game
                end
            else
                if fweek < week then
                    game.status = Status.Finish
                else
                    game.status = Status.Wait
                end
            end
            table.insert(allGames, game)
        end
    end
    if raceid then
        return nil
    end
    return allGames, restTime
end

local function getRedisKey(race_id)
    local day = os.date("%Y%m%d", os.time())
    return "race:record:"..day..race_id
end

-- 根据分数模拟出当前名次，如果模拟的名次比现有名次高，则取现有名次
local function getRankId(gameInfo, score, rankId)
    if not rankId then
        return 0
    end
    local scoreLimit = rankConfig[gameInfo.rewardId][gameInfo.gameid][gameInfo.stype]
    local rewardCfg = rewards[gameInfo.rewardId]
    local section = nil -- 所处区间
    if score >= scoreLimit[1] then
        return rankId
    elseif score >= scoreLimit[2] then
        local tmpRankId = (score - scoreLimit[2]) / (scoreLimit[1] - scoreLimit[2]) * (rewardCfg[2].rrank -rewardCfg[2].lrank)
        tmpRankId = rewardCfg[2].rrank - math.floor(tmpRankId)
        if tmpRankId < rankId then
            return rankId
        else
            return tmpRankId
        end
    elseif score >= scoreLimit[3] then
        local tmpRankId = (score - scoreLimit[3]) / (scoreLimit[2] - scoreLimit[3]) * (rewardCfg[3].rrank -rewardCfg[3].lrank)
        tmpRankId = rewardCfg[3].rrank - math.floor(tmpRankId)
        if tmpRankId < rankId then
            return rankId
        else
            return tmpRankId
        end
    else
        local tmpRankId = (scoreLimit[3] - score) / scoreLimit[3] * 200
        tmpRankId = math.floor(tmpRankId) + 100
        if tmpRankId < rankId then
            return rankId
        else
            return tmpRankId
        end
    end
end

return {
    config = config,
    getGameInfo=getGameInfo,
    rewards = rewards,
    Status=Status,
    getRedisKey=getRedisKey,
    getRankId = getRankId,
}