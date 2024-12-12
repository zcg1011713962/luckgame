local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local cjson   = require "cjson"
local player_tool = require "base.player_tool"
local date = require "date"
local DEBUG = skynet.getenv("DEBUG")
local VIP_UP_CFG = {} --vip升级配置(用户消耗钻石，vip升级)
local skiptimer = skynet.getenv("skiptimer")
local sysmarquee = require "sysmarquee"

--[[
    排行榜服务
    支持排行榜: 1=财富榜 2=当日收入排行 3=排位分数 4=好友财富排行 5=好友排位赛榜单(实时榜)
]]

cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local LEAGUE_PREFIX_KEY = "AllLeagueList"
local LEADER_BOARD_DAY_KEY = "settleLeaderBoard:day:timestamp"
local LEADER_BOARD_WEEK_KEY = "settleLeaderBoard:week:timestamp"
local LEADER_BOARD_MONTH_KEY = "settleLeaderBoard:month:timestamp"
local LEADER_BOARD_REFER_KEY = "settleLeaderBoard:refer:timestamp"
local MAX_CNT = 100
local CMD = {}

local function initVIPUpCfg()
    if VIP_UP_CFG == nil then
        local row = skynet.call(".configmgr", "lua", "getVipUpCfg")
        VIP_UP_CFG = row
    end
    return VIP_UP_CFG
end

local function set_timeout(ti, f, force)
    -- 服务器可以指定跳过定时器
    if skiptimer and not force then
        LOG_DEBUG("skip this timer")
        return
    end
    local function t()
        if f then 
          f()
        end
    end
    skynet.timeout(ti, t)
    return function() f=nil end
end

local compByCoin = function (a, b)
    if a.coin > b.coin then
        return true
    elseif a.coin == b.coin then
        if a.uid > b.uid then
             return true
        elseif a.uid == b.uid then
            return false
        else
            return false
        end
    end
end

-- 生成缓存key
-- @param rtype 1=财富版 2=当日赢取排行 3=排位分数 4=好友财富排行
local function genCacheKey(rtype)
    return string.format('rank_list:%s', rtype)
end

-- 生成游戏内金币赢取排行榜
local function genCacheKeyForGame(rtype, gameid)
    return string.format('rank_list:%s:%d', rtype, gameid)
end

-- 生成机器人缓存key
-- 目前用于魅力值排行榜存储固定的机器人信息
local function getCharmAiListKey()
    return string.format('rank_list:ailist:charm')
end

-- 机器人数据排行榜，利用key不同，每天
local function genAiRedisDayKey(rtype, getnowtime, gameid)
    local now = os.time()
    if nil ~=getnowtime and getnowtime == 2 then
        now = os.time() - 86400
    end
    local day = os.date("%Y%m%d",now)
    if not gameid then
        gameid = 0
    end
    return string.format('winlist_slot:ai:%s:%s:%s', rtype, day, gameid)
end

-- 获取赛季信息
local function getLeagueInfo()
    local redisKey = PDEFINE.LEAGUE.SEASON_KEY
    local seasonInfo = do_redis({"hgetall", redisKey})
    if not seasonInfo or table.empty(seasonInfo) then
        local stopTime = date.GetNextWeekDayTime(os.time(), 1)
        seasonInfo = {
            id = 1,
            startTime = stopTime-7*24*60*60,
            stopTime = stopTime
        }
        LOG_DEBUG("初始化联赛赛季信息...", seasonInfo)
        do_redis({"hset", redisKey, "id", seasonInfo.id})
        do_redis({"hset", redisKey, "startTime", seasonInfo.startTime})
        do_redis({"hset", redisKey, "stopTime", seasonInfo.stopTime})
    else
        seasonInfo = make_pairs_table_int(seasonInfo)
    end
    return seasonInfo
end

-- 根据类型获取真实的玩家当天的榜单数据
-- @param rtype 1 总赢榜 2总下注榜  3大奖排行榜
-- @param uid 用户uid
-- @return dataList:前20名排名
local function getRankList(rtype, limit, key)
    if not limit or limit == 0 then
        limit = MAX_CNT
    end
    local redis_key = key or genCacheKey(rtype)
    local rs = do_redis({"zrevrangebyscore", redis_key, limit, 1})
    local rsList = {}
    for i = 1, #rs, 2 do
        -- 过滤掉零值
        if tonumber(rs[i+1]) == 0 then
            break
        end
        table.insert(rsList, {uid=tonumber(rs[i]), coin=tonumber(rs[i+1])})
    end
    local dataList = {}
    if rtype == PDEFINE.RANK_TYPE.VIP_WEEK then
        local now = os.time()
        for rankId, player in ipairs(rsList) do
            local fields = {'vipendtime', 'isrobot','svipexp', 'uid'}
            local cacheData = do_redis({ "hmget", "d_user:"..player.uid, table.unpack(fields)})
            cacheData = make_pairs_table(cacheData, fields)
            local vip_end_time = math.floor(cacheData.vipendtime or 0)
            local isrobot = math.floor(cacheData.isrobot or 0)
            local svipexp = tonumber(cacheData.svipexp or 0)
            vip_end_time = math.floor(vip_end_time or 0)
            if (isrobot == 0 and vip_end_time > now) then --真人vip过期的情况处理
                local item = {}
                item["uid"] = math.floor(player.uid)
                item["coin"] = svipexp
                table.insert(dataList, item)
            else
                do_redis({"zrem", redis_key, player.uid})
            end
        end
        LOG_DEBUG("vip datalist:", dataList)
    else
        for rankId, player in ipairs(rsList) do
            local item = {}
            item["uid"] = math.floor(player.uid)
            item["coin"] = math.floor(player.coin)
            dataList[rankId] = item
        end
    end
    return dataList
end

-- 获取游戏内获取金币排行榜信息
local function getRankListForGameWin(_, gameid, limit)
    if not limit then
        limit = 3
    end
    local redis_key = genCacheKeyForGame(PDEFINE.RANK_TYPE.GAME_WINCOIN, gameid)
    local rs = do_redis({"zrevrangebyscore", redis_key, limit, 1})
    if not rs or table.empty(rs) or #rs < 2*limit then
        -- 如果暂时没有人，则放机器人到排行中
        local ok, ai_user_list = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", limit, false)
        if ok then
            for _, aiUser in ipairs(ai_user_list) do
                do_redis({"zadd", redis_key, math.random(20)* 100000, aiUser.uid})
            end
        end
        if not rs or table.empty(rs) then
            local leftTime = getThisPeriodTimeStamp()
            do_redis( {"expire", redis_key, leftTime}) --设置过期时间
        end
        rs = do_redis({"zrevrangebyscore", redis_key, limit, 1})
    end
    local rsList = {}
    for i = 1, #rs, 2 do
        -- 过滤掉零值
        if tonumber(rs[i+1]) == 0 then
            break
        end
        table.insert(rsList, {uid=tonumber(rs[i]), coin=tonumber(rs[i+1])})
    end
    local dataList = {}
    for rankId, player in ipairs(rsList) do
        local item = {}
        item["uid"] = math.floor(player.uid)
        item["coin"] = math.floor(player.coin)
        dataList[rankId] = item
    end
    return dataList
end

-- 获取游戏内排位赛排行榜
local function getRankListForGameLeague(_, gameid, limit)
    if not limit then
        limit = 3
    end
    local redis_key = genCacheKeyForGame(PDEFINE.RANK_TYPE.GAME_LEAGUE, gameid)
    local rs = do_redis({"zrevrangebyscore", redis_key, limit, 1})
    if not rs or table.empty(rs) or #rs < 20 then
        -- 如果暂时没有人，则放机器人到排行中
        local ok, ai_user_list = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", limit, false)
        if ok then
            for _, aiUser in ipairs(ai_user_list) do
                do_redis({"zadd", redis_key, math.random(20)* 100, aiUser.uid})
            end
        end
        rs = do_redis({"zrevrangebyscore", redis_key, limit, 1})
    end
    local rsList = {}
    for i = 1, #rs, 2 do
        -- 过滤掉零值
        if tonumber(rs[i+1]) == 0 then
            break
        end
        table.insert(rsList, {uid=tonumber(rs[i]), coin=tonumber(rs[i+1])})
    end
    local dataList = {}
    for rankId, player in ipairs(rsList) do
        local item = {}
        item["uid"] = math.floor(player.uid)
        item["coin"] = math.floor(player.coin)
        dataList[rankId] = item
    end
    return dataList
end

function CMD.remInVipRank(uid, rtype)
    local cacheKey = PDEFINE.RANK_TYPE.VIP_WEEK
    if rtype == PDEFINE.RANK_TYPE.RP_MONTH then
        cacheKey = PDEFINE.RANK_TYPE.RP_MONTH
    end
    local weekRedisKey = genCacheKey(cacheKey)
    local weekCount = do_redis({"zcard", weekRedisKey})
    if weekCount > 0 then
        do_redis({"zrem", weekRedisKey, uid}) --先删除老的数据
    end
end

function CMD.setVIPRank(uid, cnt)
    local cacheKey = PDEFINE.RANK_TYPE.VIP_WEEK
    local weekRedisKey = genCacheKey(cacheKey)
    -- 如果没有榜单则设置过期时间，并且增加机器人，然后每次随机增加机器人的值
    local weekCount = do_redis({"zcard", weekRedisKey})

    do_redis({"zrem", weekRedisKey, uid}) --先删除老的数据
    do_redis({"zincrby", weekRedisKey, tonumber(cnt), uid})

    -- 设置到下周一凌晨
    if weekCount == 0 then
        local expireTime = date.GetNextWeekDayTime(os.time(), 1)
        do_redis({"expire", weekRedisKey, expireTime})
    end
end

-- 更新钻石消耗值榜单或rp值榜
function CMD.updateDiamondOrRpRank(uid, cnt, rtype)
    local cacheKey = PDEFINE.RANK_TYPE.DIAMOND_WEEK
    if rtype == PDEFINE.RANK_TYPE.RP_MONTH then
        cacheKey = PDEFINE.RANK_TYPE.RP_MONTH
    elseif rtype == PDEFINE.RANK_TYPE.VIP_WEEK then
        cacheKey = PDEFINE.RANK_TYPE.VIP_WEEK
    end
    local weekRedisKey = genCacheKey(cacheKey)
    -- 如果没有榜单则设置过期时间，并且增加机器人，然后每次随机增加机器人的值
    local weekCount = do_redis({"zcard", weekRedisKey})

    -- 如果不存在key则新建一个, 并且设置过期时间
    -- 全部采用全值覆盖的形式进行更新，防止数值不准确的情况
    do_redis({"zincrby", weekRedisKey, tonumber(cnt), uid})

    -- 设置到下周一凌晨
    if weekCount == 0 then
        local expireTime = date.GetNextWeekDayTime(os.time(), 1)
        do_redis({"expire", weekRedisKey, expireTime})
    end
end

-- 更新魅力值榜单
function CMD.updateCharmRank(uid, addCharm, totalCharm)
    local weekRedisKey = genCacheKey(PDEFINE.RANK_TYPE.CHARM_WEEK)
    local monthRedisKey = genCacheKey(PDEFINE.RANK_TYPE.CHARM_MONTH)
    local totalRedisKey = genCacheKey(PDEFINE.RANK_TYPE.CHARM_TOTAL)
    -- 如果没有榜单则设置过期时间，并且增加机器人，然后每次随机增加机器人的值
    local weekCount = do_redis({"zcard", weekRedisKey})
    local monthCount = do_redis({"zcard", monthRedisKey})

    -- 如果不存在key则新建一个, 并且设置过期时间
    -- 全部采用全值覆盖的形式进行更新，防止数值不准确的情况
    do_redis({"zincrby", weekRedisKey, tonumber(addCharm), uid})
    do_redis({"zincrby", monthRedisKey, tonumber(addCharm), uid})
    do_redis({"zadd", totalRedisKey, tonumber(totalCharm), uid})

    -- 设置到下周一凌晨
    if weekCount == 0 then
        local expireTime = date.GetNextWeekDayTime(os.time(), 1)
        if DEBUG then
            expireTime = 10*60
        end
        do_redis({"expire", weekRedisKey, expireTime})
    end

    -- 设置到下个月1日
    if monthCount == 0 then
        local expireTime = date.GetNextMonthZeroTime(os.time())
        if DEBUG then
            expireTime = 60*60
        end
        do_redis({"expire", monthRedisKey, expireTime})
    end
end

-- 构造机器人假排名数据保存到redis中
local function addAiRankList(rtype, maxCoin)
    LOG_DEBUG("addAiRankList rtype:", rtype, ' maxCoin:', maxCoin)
    local max = 100
    local retobj = {}
    local max_coin = maxCoin -1
    if max_coin < 0 then
        max_coin = 0
    end
    LOG_DEBUG("addAiRankList upAiMaxCoin:",' maxCoin:', maxCoin)
    do_redis({"del", genAiRedisDayKey(rtype, 2)}) -- 清理昨天的机器人排名缓存数据
    local redis_key = genAiRedisDayKey(rtype, 1)
    do_redis({"del", redis_key}) -- 清理当前对应的机器人排名缓存数据
    local ok, ai_user_list = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", max, false)
    -- LOG_DEBUG("ai_user_list:", ai_user_list)
    for i = 1, #ai_user_list do
        local uid = ai_user_list[i].uid
        if uid then
            local coin = max_coin
            -- LOG_DEBUG("max_coin:", max_coin, ' uid:', uid)
            retobj[i] = {uid = uid, coin = max_coin, rt=1} -- rt为1 表示机器人
            do_redis({ "zadd", redis_key, coin, uid}) --机器人数据排名
            max_coin = math.floor(max_coin - math.random(1, 2)/30 *max_coin)
        end
    end
    return retobj
end

local function addAiToRedis(redisKey, maxCoin, prop)
    local ok, ai_user_list = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", 100, false)
    -- LOG_DEBUG("ai_user_list:", ai_user_list)
    for i = 1, #ai_user_list do
        local uid = ai_user_list[i].uid
        if uid then
            local coin = maxCoin
            -- LOG_DEBUG("max_coin:", max_coin, ' uid:', uid)
            do_redis({ "zadd", redisKey, coin, uid}) --机器人数据排名
            maxCoin = math.floor(maxCoin - math.random(1, 2)/30 *maxCoin)
            do_redis({"hset", "d_user:"..uid, prop, coin})
        end
    end
end

-- 初始化新的排行榜数据
local function initRankList(rtype)
    local redisKey = genCacheKey(rtype) -- PDEFINE.RANK_TYPE.TOTALCOIN/PDEFINE.RANK_TYPE.VIP_WEEK/PDEFINE.RANK_TYPE.CHARM_TOTAL/RP_MONTH
    local cnt = do_redis({"zcard", redisKey}) or 0
    if cnt > 0 then
        do_redis({"del", redisKey})
    end
    local sql  = string.format( "select uid,coin as coin from d_user where isrobot=0 and coin>0 order by coin desc limit 100")
    if rtype == PDEFINE.RANK_TYPE.VIP_WEEK then
        sql  = string.format( "select uid,svip as coin from d_user where isrobot=0 and svip>1 order by svip desc limit 100")
    elseif rtype == PDEFINE.RANK_TYPE.CHARM_TOTAL then
        sql  = string.format( "select uid,charm as coin from d_user where isrobot=0 and charm>0 order by charm desc limit 100")
    elseif rtype == PDEFINE.RANK_TYPE.RP_MONTH then
        sql  = string.format( "select uid,rp as coin from d_user where isrobot=0 and rp>0 order by rp desc limit 100")
    end
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            do_redis({ "zincrby", redisKey , row.coin, row.uid})
        end
    end
end

-- 初始化(定时)形成输赢榜
local function initWinRankList()
    local limit = 100
    local rtype = PDEFINE.RANK_TYPE.TOTALINCOME
    local rank_cache_key =  "ranklist_time:"..rtype
    local ttl = do_redis({"ttl", rank_cache_key})
    LOG_DEBUG("genRanking initWinRankList rtype:", rtype, ' ttl:', ttl)
    local dataList
    if ttl <= 0 then
        dataList = getRankList(rtype, limit)
        LOG_DEBUG("genRanking rtype:", rtype, ' dataList size:', #dataList)
        if #dataList < limit then
            local ai_redis_key = genAiRedisDayKey(rtype) -- 机器人缓存key
            local aiDataList = getRankList(rtype, limit, ai_redis_key) --获取机器人的排名数据
            LOG_DEBUG("genRanking rtype:", rtype, ' aiDataList size:', #aiDataList, ' ai_redis_key:', ai_redis_key)
            if table.empty(aiDataList) then
                local maxCoin = 0
                if #dataList > 0 then
                    maxCoin = dataList[#dataList].coin
                end
                aiDataList = addAiRankList(rtype, maxCoin) -- 缺少机器人排名数据，就先添加
            else
                for i, v in ipairs(aiDataList) do
                    aiDataList[i].rt = 1 --机器人标记
                end
            end

            for _, v in ipairs(aiDataList) do
                table.insert(dataList, v) --v里字段 uid,coin,rt
                if #dataList >= limit then
                    break
                end
            end
            table.sort(dataList, compByCoin)
        end
        local timeout = 86400
        do_redis({"setnx", rank_cache_key, cjson.encode(dataList), timeout})
    end

    local delay = 86400
    if ttl > 0 then
        delay = delay - ttl - 30 --提前30s
        if delay <= 0 then
            delay = 1
        end
    end
    
    LOG_DEBUG("Next genRanking initWinRankList dealy:", delay)
    set_timeout(delay*100, initWinRankList)
    return dataList
end

-- 获取财富榜排名
local function getTop100CoinList(uid, limitCnt, userscore)
    local dataList = getRankList(PDEFINE.RANK_TYPE.TOTALCOIN, limitCnt)
    if limitCnt == nil then
        for _, row in pairs(dataList) do
            if uid and row.uid == uid then
                if userscore and row.coin ~= userscore then
                    row.coin = userscore
                end
                break
            end
        end
    end
    return dataList
end

-- 获取所有排位分前100名
local function getAllLeagueList(uid, limitCnt, gameid, userscore)
    local redisKey = LEAGUE_PREFIX_KEY .. gameid
    local dataList = getRankList(PDEFINE.RANK_TYPE.TOTALLEAGUE, limitCnt, redisKey)
    if limitCnt == nil then
        for _, row in pairs(dataList) do
            if uid and row.uid == uid then
                if userscore and row.coin ~= userscore then
                    row.coin = userscore
                end
                break
            end
        end
    end
    return dataList
end

-- 好友排位赛或财富榜单
local function getFriendRankList(uid, rtype, limitcnt, gameid)
    local sql = string.format( "select a.uid, a.leaguelevel as lv, a.%s as exp, a.coin from d_user a join d_friend b on a.uid = b.friend_uid where b.uid =%d", "leagueexp", uid)
    if limitcnt then
        sql = string.format( "select a.uid, a.leaguelevel as lv, a.leagueexp as exp, a.coin from d_user a join d_friend b on a.uid = b.friend_uid where b.uid =%d order by a.coin desc limit %d", uid, limitcnt)
    end
    -- LOG_DEBUG('getFriendRankList sql', sql)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local dataList = {}
    if #rs > 0 then
        local leagueList = skynet.call(".cfgleague", "lua", "getAll")
        LOG_DEBUG("leagueList:", leagueList)
        for _, row in pairs(rs) do
            if rtype == PDEFINE.RANK_TYPE.FRIENDCOIN then
                table.insert(dataList, {uid=tonumber(row.uid), coin=tonumber(row.coin)})
            else
                local lv = tonumber(row.lv or 1)
                if lv < 1 then
                    lv = 1
                end
                LOG_DEBUG("row.exp:", row.exp, " uid:", row.uid)
                local exp = row.exp + leagueList[lv].score
                table.insert(dataList, {uid=tonumber(row.uid), coin=tonumber(exp)})
            end
        end
    end
    return dataList
end

-- 根据类型累加数值
-- @param rtype 1=财富榜 2=当日赢取排行 3=排位分数 4=好友财富排行
-- @param uid 用户uid
-- @param coin 此次累加的金币数
function CMD.addRank(uid, tbl)
    uid = math.floor(uid)
    local leftTime = getThisPeriodTimeStamp()
    if not table.empty(tbl) then
        for k, v in pairs(tbl) do
            local redis_key = nil
            if v.rtype == PDEFINE.RANK_TYPE.GAME_WINCOIN then
                redis_key = genCacheKeyForGame(v.rtype, v.gameid)
            elseif v.rtype == PDEFINE.RANK_TYPE.GAME_LEAGUE then
                redis_key = genCacheKeyForGame(v.rtype, v.gameid)
            else
                redis_key = genCacheKey(v.rtype) --按天和类型 先存储到当天的榜单
            end
            local cnt = do_redis({"zcard", redis_key}) or 0
            if cnt == 0 and v.rtype ~= PDEFINE.RANK_TYPE.GAME_LEAGUE then -- 排位赛会在结算的时候清空
                do_redis( {"expire", redis_key, leftTime}) --设置过期时间
            end
            do_redis({ "zincrby", redis_key , v.coin, uid}) --如果member不存在，会自动添加
            -- 如果更新了排位赛，则需要更新排位记录
            if v.rtype == PDEFINE.RANK_TYPE.GAME_LEAGUE then
                local seasonInfo = getLeagueInfo()
                player_tool.updateLeagueRecord(uid, v.gameid, seasonInfo.id)
            end
        end
        return true
    end
    return false
end

-- 获取个人在排行榜中的分数
local function getScoreByUid(uid, rtype, gameid)
    local redis_key
    if rtype == PDEFINE.RANK_TYPE.GAME_WINCOIN or rtype == PDEFINE.RANK_TYPE.GAME_LEAGUE then
        redis_key = genCacheKeyForGame(rtype, gameid)
    else
        redis_key = genCacheKey(rtype)
    end
    local userInfo = player_tool.getPlayerInfo(uid)
    if rtype == PDEFINE.RANK_TYPE.FRIENDCOIN or rtype == PDEFINE.RANK_TYPE.TOTALCOIN  then
        return userInfo.coin
    end
    if rtype == PDEFINE.RANK_TYPE.VIP_WEEK then
        if userInfo.vipendtime <= os.time() then
            return 0
        end
        return userInfo.svipexp
    elseif rtype == PDEFINE.RANK_TYPE.RP_MONTH then
        return userInfo.rp
    end
    
    local score = do_redis({"zscore", redis_key, uid}) --用户在指定类型，当天中的排行榜中的分数
    if score == nil or score == '' then
        score = 0
    end
    return score
end

local function getAiUserData(dataList)
    local aiUserIDs = {}
    local aiUserData = {}
    for k, row in pairs(dataList) do
        table.insert(aiUserIDs, row.uid)
    end
    local ok, aiUsers = pcall(cluster.call, "ai", ".aiuser", "getAiInfoByUid", aiUserIDs)
    for aiuid, row in pairs(aiUsers) do
        if nil == aiUserData[aiuid] then
            aiUserData[aiuid] = row
        end
    end
    return aiUserData
end

function CMD.updateWealthRank(uid, coin, altercoin)
    local redisKey = genCacheKey(PDEFINE.RANK_TYPE.TOTALCOIN)
    do_redis({ "zincrby", redisKey , coin, uid})
    if altercoin > 0 then
        CMD.addRank(uid, {{rtype=2, coin=altercoin}})
    end
end

function CMD.updateLeagueRank(gameid, uid, coin)
    local redisKey = LEAGUE_PREFIX_KEY .. gameid
    LOG_DEBUG("winrankmgr updateLeagueRank k:", redisKey, gameid, uid, coin)
    local rank = do_redis({ "zrank", redisKey, uid})
    if rank then
        do_redis({ "zincrby", redisKey , coin, uid})
    else
        do_redis({ "zadd", redisKey , coin, uid})
    end
end

-- 获取排行榜数据
-- @param rtype 1=财富榜 2=当日赢取排行 3=排位分数 4=好友财富排行
-- @param uid 用户uid
function CMD.getRankList(rtype, uid, gameid)
    local score = getScoreByUid(uid, rtype, gameid)
    -- 获取真实的用户排名数据
    local dataList = nil
    local aiUserData = {}
    if rtype == PDEFINE.RANK_TYPE.FRIENDCOIN or rtype == PDEFINE.RANK_TYPE.FRIENDLEAGUE then
        dataList = getFriendRankList(uid, rtype, 100, gameid)
        table.insert(dataList, {uid=tonumber(uid), coin=score})
        table.sort(dataList, compByCoin)
        aiUserData = getAiUserData(dataList)
        return dataList, score, aiUserData
    elseif rtype == PDEFINE.RANK_TYPE.TOTALINCOME then --每日形成的排行榜
        local cacheData = do_redis({ "get", "ranklist_time:"..rtype})
        local ok, tmpData = pcall(jsondecode, cacheData)
        if ok then
            dataList = tmpData
            aiUserData = getAiUserData(dataList)
            return dataList, score, aiUserData
        else --部充一下
            dataList = initWinRankList()
            dataList = tmpData
            aiUserData = getAiUserData(dataList)
            return dataList, score, aiUserData
        end
    elseif rtype == PDEFINE.RANK_TYPE.TOTALCOIN then
        dataList = getTop100CoinList(uid, MAX_CNT, score)
    elseif rtype == PDEFINE.RANK_TYPE.TOTALLEAGUE then --排位分榜是实时刷新的
        dataList = getAllLeagueList(uid, MAX_CNT, gameid, score)
    elseif rtype == PDEFINE.RANK_TYPE.GAME_WINCOIN then
        dataList = getRankListForGameWin(rtype, gameid, nil)
    else
        local redisKey
        if rtype == PDEFINE.RANK_TYPE.GAME_LEAGUE then
            redisKey = genCacheKeyForGame(rtype, gameid)
        end
        dataList = getRankList(rtype, MAX_CNT, redisKey)
    end

    LOG_DEBUG("user score:", score, ' uid :', uid)
    aiUserData = getAiUserData(dataList)
    return dataList, score, aiUserData
end

local function getRankListTopN(uid, rtype, max)
    local uids = {}
    local dataList = nil
    if rtype == PDEFINE.RANK_TYPE.FRIENDCOIN then
        dataList = getFriendRankList(uid, rtype, 5)
        local score = getScoreByUid(uid, rtype)
        table.insert(dataList, {uid=tonumber(uid), coin=score})
        table.sort(dataList, compByCoin)
    elseif rtype == PDEFINE.RANK_TYPE.TOTALCOIN then --财富榜是实时刷新的
        dataList, _ = getTop100CoinList(uid, max)
    elseif rtype == PDEFINE.RANK_TYPE.TOTALINCOME then --每日形成的排行榜
        local cacheData = do_redis({ "get", "ranklist_time:"..rtype})
        local ok, tmpData = pcall(jsondecode, cacheData)
        if ok then
            dataList = {}
            for i=1, 3 do
                table.insert(dataList, tmpData[i])
            end
        end
    elseif rtype == PDEFINE.RANK_TYPE.TOTALLEAGUE then --排位分榜是实时刷新的
        local score = getScoreByUid(uid, rtype)
        dataList, _ = getAllLeagueList(uid, max, PDEFINE.GAME_TYPE.HAND, score)
    else
        dataList = getRankList(rtype, max)
    end
    if nil ~= dataList then
        for k, row in pairs(dataList) do
            table.insert(uids, row.uid)
        end
    end
    return dataList, uids
end

-- 获取某个榜的前3
function CMD.getRankTop3ByType(uid, rtype, gameid, limit)
    local aiUserData = {}
    local result, aiUserIDs
    if gameid > 0 then
        aiUserIDs = {}
        local dataList = getRankListForGameLeague(rtype, gameid, limit)
        if nil ~= dataList then
            for k, row in pairs(dataList) do
                table.insert(aiUserIDs, row.uid)
            end
        end
        result = dataList
    else
        result, aiUserIDs = getRankListTopN(uid, rtype, 5)
    end
    if #aiUserIDs > 0 then
        local ok, aiUsers = pcall(cluster.call, "ai", ".aiuser", "getAiInfoByUid", aiUserIDs)
        for aiuid, row in pairs(aiUsers) do
            if nil == aiUserData[aiuid] then
                aiUserData[aiuid] = row
            end
        end
    end
    return result, aiUserData
end

-- 获取排行榜的前3 call by player
function CMD.getTopRankList(uid)
    local result = {}
    local max = 3
    local aiUserIDs = {}
    local aiUserData = {}
    for _, rtype in pairs({PDEFINE.RANK_TYPE.TOTALCOIN, PDEFINE.RANK_TYPE.TOTALINCOME, PDEFINE.RANK_TYPE.TOTALLEAGUE, PDEFINE.RANK_TYPE.FRIENDCOIN, PDEFINE.RANK_TYPE.CHARM_TOTAL}) do
        if nil == result[rtype] then
            result[rtype] = {}
        end

        local dataList, randUids = getRankListTopN(uid, rtype, max)
        if nil ~= randUids then
            for _, v in pairs(randUids) do
                table.insert(aiUserIDs, v)
            end
        end
        result[rtype] = dataList
    end
    if #aiUserIDs > 0 then
        local ok, aiUsers = pcall(cluster.call, "ai", ".aiuser", "getAiInfoByUid", aiUserIDs)
        for aiuid, row in pairs(aiUsers) do
            if nil == aiUserData[aiuid] then
                aiUserData[aiuid] = row
            end
        end
    end
    return result, aiUserData
end

local function sendRewards(uid, rtype, ord)
        local userInfo = player_tool.getPlayerInfo(uid)
        if not userInfo or not userInfo.uid then
            return
        end
        local title = ""
        local title_al = ""
        local msg = ""
        local msg_al = ""

        if rtype == PDEFINE.RANK_TYPE.TOTALCOIN then --财富榜
            title = "Fortune Leader board Rewards"
            title_al = "جوائز متصدرين الثروة "
            if ord == 1 then
                msg_al = "تهانينا على فوزك بالمركز الأول في تصنيفات متصدرين الثروة الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامها!"
                msg = "Congratulations on winning the third place in the wealth rankings last week, we will present you an exclusive gift, please collect it!"
            elseif ord == 2 then
                msg_al ="تهانينا على فوزك بالمركز الثاني في تصنيفات متصدرين الثروة الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامها!"
                msg = "Congratulations on winning the second place in the wealth rankings last week, we will present you an exclusive gift, please collect it!"
            elseif ord == 3 then
                msg_al ="تهانينا على فوزك بالمركز الثالث في تصنيفات متصدرين الثروة الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامها!"
                msg = "Congratulations on winning the third place in the wealth rankings last week, we will present you an exclusive gift, please collect it!"
            end
        elseif rtype == PDEFINE.RANK_TYPE.DIAMOND_WEEK then --钻石消耗榜
            title = "Diamond Spending Leader board Rewards"
            title_al = "وائز متصدرين استهلاك الماس"
            if ord == 1 then
                msg_al = "هانينا على فوزك بالمركز الأول في تصنيفات متصدرين استهلاك الماس الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامها!"
                msg = "Congratulations, you won the first place in the diamond consumption list last week. We will present an exclusive gift for you, please collect it!"
            elseif ord == 2 then
                msg_al = "تهانينا على فوزك بالمركز الثاني في تصنيفات متصدرين استهلاك الماس الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامها!"
                msg = "Congratulations, you won the second place in the diamond consumption list last week. We will present an exclusive gift for you, please collect it!"
            elseif ord == 3 then
                msg_al = "هانينا على فوزك بالمركز الثالث في تصنيفات متصدرين استهلاك الماس الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامها!"
                msg = "Congratulations, you won the third place in the diamond consumption list last week. We will present an exclusive gift for you, please collect it!"
            end
        elseif rtype == PDEFINE.RANK_TYPE.VIP_WEEK then --VIP排行榜
            title_al = "VIP مكافآت  متصدرين  مستوى"
            title = "VIP Level Leader board Rewards"
            if ord == 1 then
                msg_al = "نينا على فوزك بالمركز الأول في VIP على مستوى المتصدرين الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامها!"
                msg = "Congratulations, you won the first place in the VIP ranking list last week. We will present an exclusive gift for you, please collect it!"
            elseif ord == 2 then
                msg_al = "نينا على فوزك بالمركز الثاني في VIP على مستوى المتصدرين الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامه"
                msg = "Congratulations, you won the second place in the VIP ranking list last week. We will present an exclusive gift for you, please collect it!"
            elseif ord == 3 then
                msg_al = "نينا على فوزك بالمركز الثالث في VIP على مستوى المتصدرين الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامها!"
                msg = "Congratulations, you won the third place in the VIP ranking list last week. We will present an exclusive gift for you, please collect it!"
            end
        elseif rtype == PDEFINE.RANK_TYPE.RP_MONTH then --RP排行榜
            title_al = "RP مكافآت تصنيف "
            title = "RP Leader board Rewards"
            if ord == 1 then
                msg_al = "انينا على فوزك بالمركز الأول في تصنيف RP الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامه"
                msg = "Congratulations, you won the third place in the RP rankings last week, and an exclusive gift will be given to you, please collect it!"
            elseif ord == 2 then
                msg_al = "هانينا على فوزك بالمركز الثاني في تصنيف RP الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامه"
                msg = "Congratulations, you won the second place in the RP rankings last week, and an exclusive gift will be given to you, please collect it!"
            elseif ord == 3 then
                msg_al = "انينا على فوزك بالمركز الثالث في تصنيف RP الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامه"
                msg = "Congratulations, you won the third place in the RP rankings last week, and an exclusive gift will be given to you, please collect it!"
            end
        elseif rtype == PDEFINE.RANK_TYPE.CHARM_WEEK then --魅力值
            title_al = "مكافآت تصنيف متصدرين الكاريزما"
            title="Charisma Leader board Rewards"
            if ord == 1 then
                msg_al = "تهانينا على فوزك بالمركز الأول في تصنيف متصدرين الكاريزما الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامها!"
                msg = "Congratulations on winning the first place in the Charisma rankings last week, and an exclusive gift for you, please collect it!"
            elseif ord == 2 then
                msg_al = "تهانينا على فوزك بالمركز الثاني في تصنيف متصدرين الكاريزما الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامها!"
                msg = "Congratulations on winning the second place in the Charisma rankings last week, and an exclusive gift for you, please collect it!"
            elseif ord == 3 then
                msg_al = "تهانينا على فوزك بالمركز الثالث في تصنيف متصدرين الكاريزما الأسبوع الماضي ، وحضرنا هدية حصرية لك ، يرجى استلامها!"
                msg = "Congratulations on winning the third place in the Charisma rankings last week, and an exclusive gift for you, please collect it!"
            end
        end
        
        local attach = {}
        local endtime = 7 * 86400
        if ord == 1 then
            table.insert(attach, {type=PDEFINE.PROP_ID.SKIN_FRAME, count=1, img=PDEFINE.SKIN.RANKDIAMOND.TOP1.AVATAR.img, days=7}) 
            table.insert(attach, {type=PDEFINE.PROP_ID.SKIN_EMOJI, count=1, img=PDEFINE.SKIN.RANKDIAMOND.TOP1.EMOJI.img, days=7})
            send_timeout_skin(PDEFINE.SKIN.RANKDIAMOND.TOP1.AVATAR.img, endtime, uid)
            send_timeout_skin(PDEFINE.SKIN.RANKDIAMOND.TOP1.EMOJI.img, endtime, uid)
        elseif ord == 2 then
            table.insert(attach, {type=PDEFINE.PROP_ID.SKIN_FRAME, count=1, img=PDEFINE.SKIN.RANKDIAMOND.TOP2.AVATAR.img, days=7})
            send_timeout_skin(PDEFINE.SKIN.RANKDIAMOND.TOP2.AVATAR.img, endtime, uid)
        elseif ord == 3 then
            table.insert(attach, {type=PDEFINE.PROP_ID.SKIN_FRAME, count=1, img=PDEFINE.SKIN.RANKDIAMOND.TOP3.AVATAR.img, days=7})
            send_timeout_skin(PDEFINE.SKIN.RANKDIAMOND.TOP3.AVATAR.img, endtime, uid)
        end
        local mailid = genMailId()
        local mail_message = {
            mailid = mailid,
            uid = uid,
            fromuid = 0,
            msg  = msg,
            type = PDEFINE.MAIL_TYPE.RANKING,
            title = title,
            attach = cjson.encode(attach),
            sendtime = os.time(),
            received = 0,
            hasread = 0,
            sysMailID= 0,
            title_al = title_al,
            msg_al = msg_al,
        }
        LOG_DEBUG("sendRewards wille send rank mail uid:", uid, ' rtype:', rtype, ' ord:', ord)
        skynet.send(".userCenter", "lua", "addUsersMail", uid, mail_message)
end

--结算财富榜
local function settleWeekWealthRanking()
    local dataList, _ = getTop100CoinList(nil, 3)
    
    if #dataList > 0 then
        sendRewards(dataList[1].uid, PDEFINE.RANK_TYPE.TOTALCOIN, 1)
        if dataList[2] then
            sendRewards(dataList[2].uid, PDEFINE.RANK_TYPE.TOTALCOIN, 2)
        end
        if dataList[3] then
            sendRewards(dataList[3].uid, PDEFINE.RANK_TYPE.TOTALCOIN, 2)
        end

        local preWinner = do_redis({"get", PDEFINE.REDISKEY.RANK_SETTLE.WEATHTOPUID})
        if preWinner then
            preWinner = tonumber(preWinner)
            if preWinner ~= dataList[1].uid then
                pcall(cluster.send, "node", ".pushmsg", "send", preWinner, PDEFINE.PUSHMSG.SEVEN) --榜首被换了
            end
        end
        do_redis({"setnx", PDEFINE.REDISKEY.RANK_SETTLE.WEATHTOPUID, dataList[1].uid, 2 * 86400})
    end

    local delay = 7 * 86400
    local nowTime = os.time()
    do_redis({"set", PDEFINE.REDISKEY.RANK_SETTLE.WEATHTIME, (nowTime + delay)})
    set_timeout(delay*100, settleWeekWealthRanking)
end

--结算钻石消耗榜
local function settleWeekDiamondRanking()
    local dataList, _ = getRankList(PDEFINE.RANK_TYPE.DIAMOND_WEEK, 3)
    if #dataList > 0 then
        sendRewards(dataList[1].uid, PDEFINE.RANK_TYPE.DIAMOND_WEEK, 1)
        if dataList[2] then
            sendRewards(dataList[2].uid, PDEFINE.RANK_TYPE.DIAMOND_WEEK, 2)
        end
        if dataList[3] then
            sendRewards(dataList[3].uid, PDEFINE.RANK_TYPE.DIAMOND_WEEK, 2)
        end
    end
    local delay = 7 * 86400
    set_timeout(delay*100, settleWeekDiamondRanking)
    local redis_key = genCacheKey(PDEFINE.RANK_TYPE.DIAMOND_WEEK)
    LOG_DEBUG("settleWeekDiamondRanking over will del :", redis_key)
    local rs = do_redis({"del", redis_key})
    LOG_DEBUG("settleWeekDiamondRanking del result:", rs)
end

--结算vip榜
local function settleWeekVipRank()
    local dataList, _ = getRankList(PDEFINE.RANK_TYPE.VIP_WEEK, 3)
    if #dataList > 0 then
        sendRewards(dataList[1].uid, PDEFINE.RANK_TYPE.VIP_WEEK, 1)
        if dataList[2] then
            sendRewards(dataList[2].uid, PDEFINE.RANK_TYPE.VIP_WEEK, 2)
        end
        if dataList[3] then
            sendRewards(dataList[3].uid, PDEFINE.RANK_TYPE.VIP_WEEK, 2)
        end
    end
    local delay = 7 * 86400
    set_timeout(delay*100, settleWeekVipRank)
end

--结算魅力值榜
local function settleWeekCharmRank()
    local dataList, _ = getRankList(PDEFINE.RANK_TYPE.CHARM_WEEK, 3)
    if #dataList > 0 then
        sendRewards(dataList[1].uid, PDEFINE.RANK_TYPE.CHARM_WEEK, 1)
        if dataList[2] then
            sendRewards(dataList[2].uid, PDEFINE.RANK_TYPE.CHARM_WEEK, 2)
        end
        if dataList[3] then
            sendRewards(dataList[3].uid, PDEFINE.RANK_TYPE.CHARM_WEEK, 2)
        end
    end
    local delay = 7 * 86400
    set_timeout(delay*100, settleWeekCharmRank)
end

--结算RP值榜
local function settleWeekRPRank()
    local dataList, _ = getRankList(PDEFINE.RANK_TYPE.RP_MONTH, 3)
    if #dataList > 0 then
        sendRewards(dataList[1].uid, PDEFINE.RANK_TYPE.RP_MONTH, 1)
        if dataList[2] then
            sendRewards(dataList[2].uid, PDEFINE.RANK_TYPE.RP_MONTH, 2)
        end
        if dataList[3] then
            sendRewards(dataList[3].uid, PDEFINE.RANK_TYPE.RP_MONTH, 2)
        end
    end
    local delay = 7 * 86400
    set_timeout(delay*100, settleWeekRPRank)
end

-- 按游戏，按赛季结算榜单
local function settleLeagueRankByGame()
    LOG_DEBUG("开始结算排位赛 settleLeagueRankByGame")
    local seasonInfo = getLeagueInfo()
    local gameids = getLeagueGameIds()
    local now = os.time()
    for _, gameid in pairs(gameids) do
        local dataList = getRankListForGameLeague(PDEFINE.RANK_TYPE.GAME_LEAGUE, gameid, nil)
        if #dataList > 0 then
            local i = 0
            for _, item in pairs(dataList) do
                local uid = item.uid
                local leagueexp, leaguelevel = player_tool.getPlayerLeagueInfo(uid, gameid)
                i = i + 1
                if i <= 3 then -- 第1,2,3名 奖励头像
                    local rewards = {{type=PDEFINE.PROP_ID.SKIN_FRAME, count=1, img = PDEFINE.SKIN.LEAGUE["TOP"..i].AVATAR.img, days=7}}
                    rewards = cjson.encode(rewards)
                    local sql = string.format("insert into d_league_record(uid, gameid, seasonid, seasonstart, seasonstop, leagueexp,leaguelevel, rank, create_time, rewards) values (%d, %d, %d, %d, %d, %d,%d, %d,%d, '%s')", uid, gameid, seasonInfo.id, seasonInfo.startTime, seasonInfo.stopTime, leagueexp,leaguelevel, i, now, rewards)
                    LOG_DEBUG("settleLeagueRankByGame: ", sql)
                    skynet.send(".mysqlpool", "lua", "execute", sql)
                end
            end
        end
        local redis_key = genCacheKeyForGame(PDEFINE.RANK_TYPE.GAME_LEAGUE, gameid)
        do_redis({'del', redis_key})
    end
    -- 更新下一个赛季信息
    -- 开始下一个赛季
    seasonInfo.id = seasonInfo.id + 1
    seasonInfo.startTime = os.time()
    seasonInfo.stopTime = date.GetNextWeekDayTime(os.time(), 1)
    -- 防止无限循环
    if seasonInfo.stopTime - os.time() < 5 then
        seasonInfo.stopTime = seasonInfo.stopTime + 7*24*60*60
    end
    do_redis({'hset', PDEFINE.LEAGUE.SEASON_KEY, "id", seasonInfo.id})
    do_redis({'hset', PDEFINE.LEAGUE.SEASON_KEY, "startTime", seasonInfo.startTime})
    do_redis({'hset', PDEFINE.LEAGUE.SEASON_KEY, "stopTime", seasonInfo.stopTime})
    local delay = seasonInfo.stopTime - os.time()
    set_timeout(delay*100, settleLeagueRankByGame)
end

-- 结算排行榜
local function settleLeaderBoard(rtype)
    LOG_DEBUG("开始结算排行榜 rtype", rtype)
    local row = skynet.call(".configmgr", "lua", "get", 'leaderboard')
    local gameidstrs = skynet.call(".configmgr", "lua", "getVal", PDEFINE_REDISKEY.LEADERBOARD.GAMEIDS)

    local ok, cfg = pcall(jsondecode, row.v)
    if ok and tonumber(cfg[rtype].open) == 1 then --只有后台设置了开，才执行
        local rewards = skynet.call(".configmgr", "lua", "getLeaderBoardRewards", rtype)
        -- 获取最新榜单信息, 时间往前推1个小时，方便定位当日日期
        local settle_time = os.time() - 3600
        local redis_key, timeInfo = player_tool.getLeaderBoardInfo(rtype, settle_time)
        local cacheData = player_tool.getLeaderBoardList(rtype, redis_key,
        timeInfo.scan.start, timeInfo.scan.stop, gameidstrs)
        local tpl = skynet.call(".configmgr", "lua", "getMailTPL", PDEFINE.MAIL_TYPE.RANKING)
        for _, reward in ipairs(rewards) do
            for ord = reward.l_ord, reward.r_ord, 1 do
                local item = cacheData[ord]
                if item then
                    local uid = item.uid
                    -- local msg, title
                    -- if rtype == PDEFINE.LEADER_BOARD.TYPE.DAY then
                    --     msg = "Congratulations, here is daily game leader board rewards, please collect it!"
                    --     title = "Daily Game Leader board Rewards"
                    -- elseif rtype == PDEFINE.LEADER_BOARD.TYPE.WEEK then
                    --     msg = "Congratulations, here is weekly game leader board rewards, please collect it!"
                    --     title = "Weekly Game Leader board Rewards"
                    -- elseif rtype == PDEFINE.LEADER_BOARD.TYPE.MONTH then
                    --     msg = "Congratulations, here is monthly game leader board rewards, please collect it!"
                    --     title = "Monthly Game Leader board Rewards"
                    -- elseif rtype == PDEFINE.LEADER_BOARD.TYPE.REFERRALS then
                    --     msg = "Congratulations, here is weekly referrals leader board rewards, please collect it!"
                    --     title = "Weekly Referrals Leader board Rewards"
                    -- end
                    local mailType = PDEFINE.MAIL_TYPE.RANKING
                     if rtype == PDEFINE.LEADER_BOARD.TYPE.DAY then
                        mailType = PDEFINE.MAIL_TYPE.RANKING_DAY
                    elseif rtype == PDEFINE.LEADER_BOARD.TYPE.WEEK then
                        mailType = PDEFINE.MAIL_TYPE.RANKING_WEEK
                    elseif rtype == PDEFINE.LEADER_BOARD.TYPE.MONTH then
                        mailType = PDEFINE.MAIL_TYPE.RANKING_MONTH
                    elseif rtype == PDEFINE.LEADER_BOARD.TYPE.REFERRALS then
                        mailType = PDEFINE.MAIL_TYPE.RANKING_AGENT
                    end

                    local attach = {{type=PDEFINE.PROP_ID.COIN, count=reward.coin}}
                    local mailid = genMailId()
                    local mail_message = {
                        mailid = mailid,
                        uid = uid,
                        fromuid = 0,
                        msg  = tpl.content,
                        type = mailType,
                        title = tpl.title,
                        attach = cjson.encode(attach),
                        sendtime = os.time(),
                        received = 0,
                        hasread = 0,
                        sysMailID= 0,
                        remark='排名:'..ord..',奖金:'..reward.coin,
                    }
                    LOG_DEBUG("settleLeaderBoard send reward mail uid:", uid, ' rtype:', rtype, ' ord:', ord)
                    skynet.send(".userCenter", "lua", "addUsersMail", uid, mail_message)
                    local sql = string.format([[
                        insert into d_lb_reward_log 
                            (rtype, uid, settle_date, ord, coin, score, reward_coin, create_time)
                        values
                            (%d, %d, '%s', %d, %0.2f, %d, %0.2f, %d)
                        ]], rtype, uid, os.date("%d-%m-%Y", settle_time), ord, reward.coin, math.floor(item.score), reward.coin, os.time())
                    LOG_DEBUG("settleLeaderBoard: ", sql)
                    skynet.send(".mysqlpool", "lua", "execute", sql)

                    if rtype <= 3 and ord <= 3 then
                        local playername = do_redis({"hget", "d_user:"..uid, "playername"})
                        local rtypename = {"Daily", "Weekly", "Monthly"}
                        sysmarquee.onLeaderboardRank(playername, rtypename[rtype], ord, reward.coin)
                    end
                end
            end
        end
        -- 单独写记录
        local sql
        local regcnt = 0
        local rewardcnt = 0
        local rewardcoin = 0
        local nowtime = os.time()
        for idx, d in ipairs(cacheData) do
            regcnt = regcnt + 1
            if d.reward_coin > 0 then
                rewardcnt = rewardcnt + 1
                rewardcoin = rewardcoin + d.reward_coin
            end
            if idx == 1 then
                sql = "insert into d_lb_log (uid,playername,usericon,rtype,score,ord,reward_coin,create_time,settle_time) values "
            else
                sql = sql .. ','
            end
            local subSql = string.format([[
                (%d, %s, %s, %d, %d, %d, %0.2f, %d, %d)
            ]], d.uid, d.playername, d.usericon, rtype, math.floor(d.score), idx, d.reward_coin, nowtime, timeInfo.scan.start)
            sql = sql .. subSql
        end
        if regcnt > 0 then
            local stat_sql = string.format([[
                insert d_lb_stat(start_time,rtype,regcnt,rewardcnt,reward_coin,create_time) 
                value(%d,%d,%d,%d,%d,%d)
                ]], timeInfo.scan.start, rtype, regcnt, rewardcnt, rewardcoin, nowtime)
                do_mysql_queue(stat_sql)
        end
        if sql then
            sql = sql .. ';'
            skynet.send(".mysqlpool", "lua", "execute", sql)
        end
    end

    LOG_DEBUG("开启下一次排行榜结算 rtype", rtype)
    local timeInfo = getLeaderBorderRangeTime(os.time())
    local rkey
    if rtype == PDEFINE.LEADER_BOARD.TYPE.DAY then
        rkey = LEADER_BOARD_DAY_KEY
        do_redis({"set", rkey, timeInfo.day.stop+1})
    elseif rtype == PDEFINE.LEADER_BOARD.TYPE.WEEK then
        rkey = LEADER_BOARD_WEEK_KEY
        do_redis({"set", rkey, timeInfo.week.stop+1})
    elseif rtype == PDEFINE.LEADER_BOARD.TYPE.MONTH then
        rkey = LEADER_BOARD_MONTH_KEY
        do_redis({"set", rkey, timeInfo.month.stop+1})
    elseif rtype == PDEFINE.LEADER_BOARD.TYPE.REFERRALS then
        rkey = LEADER_BOARD_REFER_KEY
        do_redis({"set", rkey, timeInfo.week.stop+1})
    end
    roundCheckBytimestamp(rkey, function()
        settleLeaderBoard(rtype)
    end, 60)
end

function CMD.testWealthRank(uid)
    local nowD = os.date("*t")
    local msg = string.format("Congratulations,you are No.1 in Wealth Ranking before %d/%d/%d 12:0:0.The rewards hav been issued to you.", nowD.day, nowD.month, nowD.year)
    local msg_al = string.format("تهانينا ، أنت رقم 1 في تصنيف الثروة قبل %s/%s/%s 12:00: 00 تم إصدار المكافآت لك.تم إصدار المكافآت لك.", nowD.day, nowD.month, nowD.year)
    local attach = {}
    table.insert(attach, {id=PDEFINE.PROP_ID.WEALTH_AVATAR, num=1}) --头像框皇冠
    table.insert(attach, {id=PDEFINE.PROP_ID.WEALTH_EMOTO, num=1}) --表情包
    table.insert(attach, {id=PDEFINE.PROP_ID.WEALTH_KING, num=1}) -- king
    local mailid = genMailId()
    local mail_message = {
        mailid = mailid,
        uid = uid,
        fromuid = 0,
        msg  = msg,
        type = PDEFINE.MAIL_TYPE.RANKING,
        title = "Wealth Ranking Rewards!",
        attach = cjson.encode(attach),
        sendtime = os.time(),
        received = 0,
        hasread = 0,
        sysMailID= 0,
        title_al = 'مكافآت ترتيب الثروة',
        msg_al = msg_al,
    }
    skynet.send(".userCenter", "lua", "addUsersMail", tonumber(uid), mail_message)
    do_redis({"setnx", PDEFINE.REDISKEY.RANK_SETTLE.WEALTHKING..uid, 1, 86400})
end

local function initWork()
    initRankList(PDEFINE.RANK_TYPE.TOTALCOIN)
    initRankList(PDEFINE.RANK_TYPE.VIP_WEEK)
    initRankList(PDEFINE.RANK_TYPE.CHARM_TOTAL)
    initRankList(PDEFINE.RANK_TYPE.RP_MONTH)
    -- initWinRankList()
end

function CMD.start()
    LOG_DEBUG("skiptimer:", skiptimer)
    -- set_timeout(5000, initWork)--ai服还没启动
    initVIPUpCfg()
    -- local nextTime = getWealthRankNextSettleTime()
    -- local delay = nextTime - os.time()
    --------------------------------------------------------------------------------
    -- 测试代码
    -- delay = 300
    --------------------------------------------------------------------------------
    -- set_timeout(30*100, settleWeekWealthRanking)
    -- if DEBUG then
    --     set_timeout(600*100, settleWeekWealthRanking) --TODO:测试结算
    --     set_timeout(600*100, settleWeekDiamondRanking)
    -- else
        -- set_timeout(delay*100, settleWeekWealthRanking)
        -- set_timeout(delay*100, settleWeekDiamondRanking)
    -- end

    -- set_timeout(delay*100, settleWeekVipRank)
    -- set_timeout(delay*100, settleWeekCharmRank)
    -- set_timeout(delay*100, settleWeekRPRank)

    local timeInfo = getLeaderBorderRangeTime(os.time())

    do_redis({"set", LEADER_BOARD_DAY_KEY, timeInfo.day.stop+1})
    do_redis({"set", LEADER_BOARD_WEEK_KEY, timeInfo.week.stop+1})
    do_redis({"set", LEADER_BOARD_MONTH_KEY, timeInfo.month.stop+1})
    do_redis({"set", LEADER_BOARD_REFER_KEY, timeInfo.week.stop+1})

    roundCheckBytimestamp(LEADER_BOARD_DAY_KEY, function()
        settleLeaderBoard(PDEFINE.LEADER_BOARD.TYPE.DAY)
    end, 60)
    roundCheckBytimestamp(LEADER_BOARD_WEEK_KEY, function()
        settleLeaderBoard(PDEFINE.LEADER_BOARD.TYPE.WEEK)
    end, 60)
    roundCheckBytimestamp(LEADER_BOARD_MONTH_KEY, function()
        settleLeaderBoard(PDEFINE.LEADER_BOARD.TYPE.MONTH)
    end, 60)
    roundCheckBytimestamp(LEADER_BOARD_REFER_KEY, function()
        settleLeaderBoard(PDEFINE.LEADER_BOARD.TYPE.REFERRALS)
    end, 60)

    

    -- delay = 60
    

    --排位赛赛季结束倒计时
    -- local curSeasonEndTime = 0
    -- local now = os.time()
    -- for i=#PDEFINE.LEAGUE.SEASON, 1, -1 do
    --     local row = PDEFINE.LEAGUE.SEASON[i]
    --     if row.stop >= now  and row.start <= now then
    --         curSeasonEndTime = row.stop
    --         break
    --     end
    -- end
    local seasonInfo = getLeagueInfo()
    local delay = seasonInfo.stopTime - os.time()
    if delay > 0 then
        set_timeout(delay*100, settleLeagueRankByGame)
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".winrankmgr")
end)