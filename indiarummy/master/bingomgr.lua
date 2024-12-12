local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local cjson   = require "cjson"
local skiptimer = skynet.getenv("skiptimer")

cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local CMD = {}

local RewardLimit = 10

--- @class BingoCfg
local bingoCfg = {
    level = nil,  -- 解锁等级
    maxBall = nil,  -- 能拥有的球数量
    startDay = nil,  -- 开始时间(周几)
    endDay = nil,  -- 结束时间(周几)
    startTime = nil,  -- 当前赛季开始时间
    endTime = nil,  -- 当前赛季结束时间
    rewards = {},  --存放bingo的奖励
}

local BingoRewardType = {
    Section = 1,  -- 关卡奖励
    Round = 2,  -- 轮次通关奖励
    Ranking = 3,  -- 排名奖励
}

-- 定时器
local autoSettleFunc

-- 获取排行榜redisKey, 后面接时间戳用于区分每个周期
local function getRankingKey()
    return PDEFINE.REDISKEY.SUBGAME.BINGO.."ranking"
end

-- 获取机器人redisKey
local function getAiRedisKey()
    return PDEFINE.REDISKEY.SUBGAME.BINGO.."aiList"
end

-- 玩家增加分数
function CMD.addScore(uid, score)
    local redisKey = getRankingKey()
    do_redis({"zincrby", redisKey , score, uid})
end

-- 获取排行榜，并解析
local function getRanking(limit)
    local redisKey = getRankingKey()
    local rs = do_redis({"zrevrangebyscore", redisKey, limit, 1})

    local rsList = {}
    for i = 1, #rs, 2 do
        table.insert(rsList, {uid=tonumber(rs[i]), score=tonumber(rs[i+1])})
    end

    local aiRedisKey = getAiRedisKey()
    local aiPlayerInfos = do_redis({"get", aiRedisKey})
    if aiPlayerInfos then
        aiPlayerInfos = cjson.decode(aiPlayerInfos)
    else
        aiPlayerInfos = {}
    end
    local dataList = {}
    for rankId, player in ipairs(rsList) do
        local item = {}
        item.rankId = rankId
        item.uid = math.floor(player.uid)
        item.score = math.floor(player.score)
        local uid_str = tostring(player.uid)
        if aiPlayerInfos[uid_str] then
            item.usericon = aiPlayerInfos[uid_str].usericon
            item.playername = aiPlayerInfos[uid_str].playername
            item.sex = aiPlayerInfos[uid_str].sex
        end
        table.insert(dataList, item)
    end
    return dataList
end

-- 刷新机器人分数
-- 1个小时刷新一次
-- 每次选3-8个机器人增加一个关卡的分数
local function refreshAiPlayer()
    if bingoCfg and bingoCfg.startTime then
        -- 如果未到开始时间，则忽略
        if os.time() >= bingoCfg.startTime and os.time() < bingoCfg.endTime then
            local redisKey = getAiRedisKey()
            local aiPlayerInfos = do_redis({"get", redisKey})
            if aiPlayerInfos then
                -- ai玩家的map
                aiPlayerInfos = cjson.decode(aiPlayerInfos)
                local aiUserList = {}  -- ai玩家列表
                for uid, playerInfo in pairs(aiPlayerInfos) do
                    table.insert(aiUserList, playerInfo)
                end
                shuffle(aiUserList)
                local changeCount = math.random(3, 8)
                for i = 1, changeCount do
                    local aiPlayer = table.remove(aiUserList)
                    if aiPlayer then
                        CMD.addScore(aiPlayer.uid, 1)
                    end
                end
            end
        end
    end
    skynet.timeout(1*60*60*100, refreshAiPlayer)
end

-- 初始化排行榜，设置机器人
local function initAiPlayerInfo(force)
    LOG_DEBUG("调用initAiPlayerInfo , force=", force)
    local redisKey = getAiRedisKey()
    -- 如果redis中已经有数据了，则不覆盖
    local oldData = do_redis({"get", redisKey})
    -- 如果有老数据了，但是这个方法是进程启动调用的，则也需要调用下定时器
    if oldData then
        -- 有老数据，不是强制更换机器人信息，则不刷新机器人，防止老排行榜找不到机器人信息
        if not force then
            skynet.timeout(10*100, refreshAiPlayer)
            return
        end
    end
    local ok, aiUserList = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", 50, false)
    if ok then
        LOG_DEBUG("初始化机器人...")
        local aiPlayerInfos = {}
        for _, playerInfo in ipairs(aiUserList) do
            aiPlayerInfos[playerInfo.uid] = playerInfo
        end
        do_redis({"set", redisKey, cjson.encode(aiPlayerInfos)})
        -- 只有启动时候才会启动这个定时器，新赛季不会重新启用这个定时器
        if not force then
            skynet.timeout(10*100, refreshAiPlayer)
        end
    end
end

-- 获取分数排行榜
-- 还需要返回自己的排名
function CMD.getRankingList(uid, limit)
    local redisKey = getRankingKey()
    local dataList = getRanking(limit)
    local selfInfo = {
        uid = uid,
        score = 0,
        rankId = 9999,
    }
    local score = do_redis({"zscore", redisKey, uid})
    if score then
        selfInfo.score = score
    end
    local rankId = do_redis({ "zrevrank", redisKey, uid})
    if rankId then
        selfInfo.rankId = rankId + 1  -- 这里需要+1, 因为排名从1开始
    end
    return {dataList=dataList, selfInfo=selfInfo}
end

-- 结算排行榜
-- 结算完成之后，删除排行榜
local function settleRanking()
    -- 先获取前10名玩家
    local dataList = getRanking(RewardLimit)
    local redisKey = getAiRedisKey()
    local aiPlayerInfos = do_redis({"get", redisKey})
    if aiPlayerInfos then
        -- ai玩家的map
        aiPlayerInfos = cjson.decode(aiPlayerInfos)
    end
    for rankId, player in ipairs(dataList) do
        if not aiPlayerInfos or not aiPlayerInfos[tostring(player.uid)] then
            local msg = string.format("Congratulations! During this activity,you are NO.%d in Fortune Bingo Ranking!", rankId)
            -- body
            local uid = math.floor(player.uid)
            local attach = {}
            --- @type BingoReward reward
            for _, reward in ipairs(bingoCfg.rewards) do
                if reward.type == BingoRewardType.Ranking then
                    if reward.lRank<= rankId and reward.rRank >= rankId then
                        for _, _reward in ipairs(reward.rewards) do
                            table.insert(attach, {id=_reward.type, num=_reward.count})
                        end
                        break
                    end
                end
            end
    
            local mailid = genMailId()
            local mail_message = {
                mailid = mailid,
                uid = uid,
                fromuid = 0,
                msg  = msg,
                type = PDEFINE.MAIL_TYPE.BINGO,
                title = "Bingo Rangking Rewards",
                attach = cjson.encode(attach),
                sendtime = os.time(),
                received = 0,
                hasread = 0,
                sysMailID= 0,
            }
    
            skynet.send(".userCenter", "lua", "addUsersMail", uid, mail_message)
        end
    end

    -- 删除排行榜
    local redisKey = getRankingKey()
    do_redis({"del", redisKey})

    -- 重新生成机器人
    if skiptimer then
        initAiPlayerInfo()
    else
        initAiPlayerInfo(true)
    end

    -- 设置下一个结算周期
    CMD.setNextAutoSettle()
end


-- 重新从库里加载配置到游戏
local function loadFromDb()
    local cfgs = {}
    local sql = string.format("select * from s_bingo")
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        bingoCfg.level = rs[1]["level"]
        bingoCfg.maxBall = rs[1]["max_ball"]
        bingoCfg.startDay = rs[1]["start_day"]
        bingoCfg.endDay = rs[1]["end_day"]
    else
        LOG_ERROR("加载bingo的数据库失败")
    end

    local rewardSql = string.format("select * from s_bingo_reward")
    local rewardRs = skynet.call(".mysqlpool", "lua", "execute", rewardSql)
    if #rewardRs > 0 then
        local rewards = {}
        for _, row in ipairs(rewardRs) do
            --- @class BingoReward
            local reward = {  -- 具体奖励
                type = nil,  -- 类型
                sectionId = nil,  -- 大关卡id
                orderId = nil,  -- 小关卡id
                score = nil,  -- 小关卡奖励分数
                roundId = nil,  -- 当前轮次
                lRank = nil,  -- 排名奖励左区间
                rRank = nil,  -- 排名奖励右区间
                rewards = nil,  -- 实际奖励
            }
            reward.type = row["type"]
            reward.sectionId = row["section_id"]
            reward.orderId = row["order_id"]
            reward.score = row["score"]
            reward.roundId = row["round_id"]
            reward.lRank = row["l_rank"]
            reward.rRank = row["r_rank"]
            reward.rewards = decodeRewards(row["rewards"])  -- 实际奖励
            table.insert(rewards, reward)
        end
        bingoCfg.rewards = rewards
    else
        LOG_ERROR("加载bingo_reward的数据库失败")
    end
end

-- 设置结算定时器
function CMD.setNextAutoSettle()
    -- 新需求，活动改成循环机制，一周一次，一个接一个
    if bingoCfg then
        local nowD = os.date("*t")
        local zeroTime = os.time({year=nowD.year, month=nowD.month, day=nowD.day, hour=0, min =0, sec = 00}) --今日开始时间戳
        local wday = tonumber(os.date("%w", zeroTime)) -- 0表示周日 1表示周1
        if wday == 0 then
            wday = 7
        end
        local delayTime = 0
        -- 这里不考虑结束日比开始日还低的情况，比如周五开始，周一结束
        if wday < bingoCfg.endDay then
            bingoCfg.endTime = (bingoCfg.endDay - wday + 1)*24*60*60 + zeroTime
            delayTime = bingoCfg.endTime - os.time()
            if wday > bingoCfg.startDay then
                bingoCfg.startTime = zeroTime - (wday - bingoCfg.startDay)*24*60*60
            else
                bingoCfg.startTime = zeroTime + (bingoCfg.startDay - wday)*24*60*60
            end
        else
            bingoCfg.endTime = (7 - wday + bingoCfg.endDay + 1)*24*60*60 + zeroTime
            delayTime = bingoCfg.endTime - os.time()
            bingoCfg.startTime = zeroTime + (7 - wday + bingoCfg.startDay)*24*60*60
        end

        ---------------------------------------------------------------------------------------
        -- 本地测试代码, 10分钟一个轮回
        -- bingoCfg.startTime = os.time()
        -- local delayTime = 600
        -- bingoCfg.endTime = os.time() + delayTime
        ---------------------------------------------------------------------------------------

        LOG_DEBUG("已设置Bingo排行榜定时结算，delayTime:", delayTime)
        autoSettleFunc = skynet.timeout(delayTime*100, settleRanking)
    end
end

-- 获取bingo游戏配置
function CMD.getBingoCfg()
    return bingoCfg
end

-- 初始化机器人
function CMD.initAiPlayerInfo()
    initAiPlayerInfo()
end

function CMD.start()
    loadFromDb()
    CMD.setNextAutoSettle()
    LOG_DEBUG("skiptimer:", skiptimer)
    return PDEFINE.RET.SUCCESS
end

function CMD.reload()
    loadFromDb()
    return PDEFINE.RET.SUCCESS
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)

    skynet.register(".bingomgr")
end)
