local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local date = require "date"
local snax = require "snax"
local cjson = require "cjson"
local player_tool = require "base.player_tool"
local skiptimer = skynet.getenv("skiptimer")

local CMD = {}
local iid = 0
local aiUserList = {}
local LEAGUE_LIST = {}
local LEVEL_LIST ={}
local autoChangeRobotLevel = nil

local function loadData()
    local temp_config_list = {}
    local sql = "select * from d_user where isrobot=1"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            do_redis({"hmset", "d_user:" .. row.uid, row})
            table.insert(temp_config_list, row)
        end
    end
    aiUserList = temp_config_list
end

local function initLevelList()
    local ok, data = pcall(cluster.call, "master", ".cfglevel", "getAll")
    if ok then
        LEVEL_LIST = data
    end
end

local function initOtherInfo()
    local ok, leagueArr = pcall(cluster.call, "master", ".cfgleague", "getAll")
    if ok then
        LEAGUE_LIST = leagueArr
    end
end

-- 获取玩家排位分和等级
local function getPlayerLeagueInfo(uid, gameid)
    -- 如果没有指定gameid,则取最高的那个
    local gameids = getLeagueGameIds()
    if gameid then
        gameids = {gameid}
    end
    local maxScore = 0
    for _, id in ipairs(gameids) do
        local redis_key = string.format('rank_list:%s:%d', PDEFINE.RANK_TYPE.GAME_LEAGUE, id)
        local score = do_redis({"zscore", redis_key, uid})
        if not score then
            score = 0
        else
            score = tonumber(score)
        end
        if maxScore < score then
            maxScore = score
        end
    end
    -- 根据分数算出排位分
    local ok, level = pcall(cluster.call, "master", ".cfgleague", "getCurLevel", maxScore)
    if not ok then
        level = 1
    end
    return maxScore, level
end

-- 生产排位赛统计数据
local function getAiLeagueStat(uid, level, leaguelevel, leagueexp)
    local aiKey = "ai_user_"..  uid ..'_league'
    local cache = do_redis({ "hgetall", aiKey}) --玩家缓存的转盘领取数据
    cache = make_pairs_table(cache)
    local tbl = {
        current = {
            leagueexp = 0,
            win = 0,
            total = 0,
        },
        last = {
            leagueexp = 0,
            win = 0,
            total = 0,
        },
        high = {
            leagueexp = 0,
            win = 0,
            total = 0,
        },
    }
    if cache and table.size(cache) > 0 then
        tbl['current'].leagueexp  = tonumber(cache.leagueexp_curr or 0)
        tbl['current'].win = tonumber(cache.win_curr or 0)
        tbl['current'].total = tonumber(cache.total_curr or 0)

        tbl['last'].leagueexp  = tonumber(cache.leagueexp_last or 0)
        tbl['last'].win = tonumber(cache.win_last or 0)
        tbl['last'].total = tonumber(cache.total_last or 0)

        tbl['high'].leagueexp  = tbl['last'].leagueexp or 0
        tbl['high'].win = tbl['last'].win_last or 0
        tbl['high'].total = tbl['last'].total_last or 0
    else
        local leagueexp_curr = leagueexp
        local win_curr = math.random(12, 50)
        local total_curr = math.random(win_curr, 100)

        local leagueexp_last = math.random(100, 3000)
        local win_last = math.random(1, 20)
        local total_last = math.random(win_last, 100)
        local set2 = {
            leagueexp_curr = leagueexp_curr,
            win_curr = win_curr,
            total_curr  = total_curr,
            win_last = win_last,
            leagueexp_last = leagueexp_last, --逃跑
            total_last = total_last
        }
        do_redis({"hmset", aiKey, set2})
        tbl = {
            current = {
                leagueexp = leagueexp_curr or 0,
                win = win_curr,
                total = total_curr,
            },
            last = {
                leagueexp = leagueexp_last or 0,
                win = win_last,
                total = total_last,
            },
            high = {
                leagueexp = leagueexp_last or 0,
                win = win_last,
                total = total_last,
            },
        }
    end
    if tbl['high'].leagueexp < tbl['current'].leagueexp then
        tbl['high'].leagueexp = tbl['current'].leagueexp
    end
    if tbl['high'].win < tbl['current'].win then
        tbl['high'].win = tbl['current'].win
    end
    if tbl['high'].total < tbl['current'].total then
        tbl['high'].total = tbl['current'].total
    end
    return tbl
end

-- 生成在线统计数据
local function getAiOnlineStat(uid, level)
    local aiKey = "ai_user_"..  uid ..'_online'
    local cache = do_redis({ "hgetall", aiKey}) --玩家缓存的转盘领取数据
    cache = make_pairs_table(cache)
    local tbl = {
        playedtime = 0,
        total = 0,
        win  = 0,
        win_rate = 0,
        abandom = 0, --逃跑
    }
    if cache and table.size(cache) > 0 then
        tbl['playedtime'] = tonumber(cache.playedtime)
        tbl['total'] = tonumber(cache.total)
        tbl['win'] = tonumber(cache.win)
        tbl['win_rate'] = cache.win_rate
        tbl['abandom'] = cache.abandom
    else
        local online_played = math.random(60, 600)
        local online_times = math.random(10,20)
        local online_wintimes = math.random(8,15)
        local abandomRate = 0
        if level >= 15 then
            online_played = math.random(300, 3600)
            online_times = math.random(20 ,50)
            online_wintimes = math.random(10, 30)
            abandomRate = string.format("%.2f", math.random(3,10)/online_times * 100)
        end
        local winRate =  string.format("%.2f", online_wintimes/online_times * 100)
        tbl = {
            playedtime = online_played,
            total = online_times,
            win  = online_wintimes,
            win_rate = winRate,
            abandom = abandomRate, --逃跑
        }
        do_redis({"hmset", aiKey, tbl})
    end
    return tbl
end


-- ai
local function getAiInfo(user)
    local aiKey = "d_user:" .. user.uid
    -- local aiKey = "ai_user_"..user.uid
    -- local cache = do_redis({ "hgetall", aiKey}) --玩家缓存的转盘领取数据
    -- cache = make_pairs_table(cache)
    local cache = player_tool.getPlayerInfo(user.uid)
    if table.size(cache) > 0 then
        table.merge(user, cache)
        if cache['coin'] then
            user.coin = math.floor(cache['coin'])
        end
        if cache['charm'] then
            user.charm = math.floor(cache['charm'])
        end
        if cache['level'] then
            user.level = math.floor(cache['level'])
        end
        user.stat = {
            online = getAiOnlineStat(user.uid, user.level),
            league = getAiLeagueStat(user.uid, user.level, user.leaguelevel, user.leagueexp) --排位数据
        }
        return user
    end
    if table.empty(LEAGUE_LIST) then
        initOtherInfo()
    end
    if table.empty(LEVEL_LIST) then
        initLevelList()
    end

    user.leagueexp, user.leaguelevel = getPlayerLeagueInfo(user.uid)

    user.stat = {
        online = getAiOnlineStat(user.uid, user.level),
        league = getAiLeagueStat(user.uid, user.level, user.leaguelevel, user.leagueexp) --排位数据
    }
    do_redis({"hmset", aiKey, user})
    return user
end

-- 获取当前等级
local function getCurrLevel(curLevel, levelexp)
    for i=#LEVEL_LIST, curLevel, -1 do
        if levelexp >= LEVEL_LIST[i].exp then
            return i
        end
    end
end

-- 设置排位标识位
local function setLeagueSign(uid)
    -- if math.random() < 0.66 then
    --     return
    -- end
    -- local cacheKey = PDEFINE.LEAGUE.SIGN_UP_KEY.. uid
    -- local expire_time = date.GetTodayZeroTime(os.time()) + 24*60*60 - os.time()
    -- do_redis({"setex", cacheKey, 1, expire_time})
end

-- 获取机器人用户信息
function CMD.getAiInfo(session, coin, gameid, deskid)
    --重排
    shuffle(aiUserList)

    local aiPlayerInfo = {}
    local aiCount = 0
    for _, ai in pairs(aiUserList) do
        aiPlayerInfo.usericon = ai.usericon
        aiPlayerInfo.playername = ai.playername
        aiPlayerInfo.memo = ai.memo
        aiPlayerInfo.state = -1
        aiPlayerInfo.coin = coin
        aiPlayerInfo.integral = ai.integral or 0
        aiPlayerInfo.sex = ai.sex
        aiPlayerInfo.uid = ai.uid
        aiPlayerInfo.gameid = gameid
        aiPlayerInfo.rp = ai.rp
        --机器人初始携带的金币
        ai.gameid = gameid
        break
    end

    if table.empty(aiPlayerInfo) then
        LOG_DEBUG(os.date("%Y-%m-%d %H:%M:%S", os.time()),"--结束获取机器人-aiCount:",aiCount, gameid, " 没有获取到机器人")
    else
        LOG_DEBUG(gameid, "获取到一个机器人:",aiPlayerInfo.playername)
    end
    return aiPlayerInfo
end




-- 回收机器人
-- playername: 机器人昵称,
-- gameid: 上一把游戏id,
-- cooltime 上一把游戏冷却截止时间
-- deskid 上一把游戏的桌子id
function CMD.recycleAi(uid, coin, cooltime, deskid)
	iid = iid - 1
	for _, ai in pairs(aiUserList) do
		if ai.uid == uid and ai.curstate then
            --LOG_DEBUG("回收成功机器人uid:", uid)
			ai.curstate = nil
            ai.lastgameid = ai.gameid
            ai.jointime = 0
            --if nil ~= cooltime then
            --    ai.cooltime = cooltime
            --end

            --if nil ~= deskid then
            --    ai.deskid = deskid
            --end
			break
		end
	end
end

-- 获取N个机器人用户信息
function CMD.getAiListByNum(num, lock)
    --重排
    -- rearrange(100)
    -- LOG_DEBUG("aiUserList size:", table.size(aiUserList))
    shuffle(aiUserList)

    local userList = {}
    local aiCount = 0
    local nowtime = os.time()
    for _, ai in pairs(aiUserList) do
        if ai.curstate == nil or ai.curstate == false then
            if lock then
                ai.curstate = true
                -- 随机设置排位标记
                setLeagueSign(ai.uid)
            end
            ai.jointime = nowtime
            table.insert(userList, ai)
            aiCount = aiCount + 1
            if aiCount >= num then
                break
            end
        end
    end
    if #userList < num then --机器人全出去了,没有了
        local leftCnt = num - #userList
        table.sort(aiUserList, function (a, b)
            if a.jointime < b.jointime then
                return true
            end
            return false 
        end)
        for _, ai in pairs(aiUserList) do
            if aiCount >= num then
                if ai.jointime < os.time() - 2*3600 then
                    ai.curstate = false
                end
            else
                ai.curstate = true
                ai.jointime = nowtime
                table.insert(userList, ai)
                aiCount = aiCount + 1
            end
        end
    end
    return userList
end

-- 根据机器人UID，返回机器人信息
function CMD.getAiInfoByUid(tbl)
    local ret = {}
    for i=1, #tbl do
        for _, ai in pairs(aiUserList) do
            if tbl[i] == ai.uid then
                ret[ai.uid] = {
                    ['uid'] = ai.uid,
                    ["usericon"] = ai.usericon,
                    ["playername"] = ai.playername,
                    ["rp"] = ai.rp or 0,
                    ['charm'] = ai.charm or 0,
                    ['level'] = ai.level or 1,
                    ['levelexp'] = ai.levelexp or 0,
                    ['coin'] = ai.coin,
                }
                getAiInfo(ret[ai.uid])
                break
            end
        end
    end
    return ret
end

-- 更新机器人的属性
function CMD.updateAiInfo(users)
    local userMap = {}
    for _, user in ipairs(users) do
        userMap[user.uid] = user
    end
    local updateAis = {}
    for _, ai in pairs(aiUserList) do
        if userMap[ai.uid] then
            LOG_DEBUG("updateAiInfo:", ai)
            local user = userMap[ai.uid]
            if user.coin then
                ai.coin = user.coin
            end
            if user.rp then
                ai.rp = user.rp
            end
            if user.levelexp then
                ai.levelexp = user.levelexp
                ai.level = getCurrLevel(ai.level, ai.levelexp)
            end
            if user.leagueexp and user.gameid then
                pcall(cluster.send, "master", ".winrankmgr", "addRank", ai.uid, {{rtype=PDEFINE.RANK_TYPE.GAME_LEAGUE, gameid=user.gameid, coin=user.leagueexp}})
            end
            table.insert(updateAis, ai)
        end
    end
    -- 更新数据库和redis
    for _, ai in ipairs(updateAis) do
        local sql = string.format([[
            update d_user set level=%d, levelexp=%d, rp=%d, coin=%d
            where isrobot=1 and uid=%d
        ]], ai.level, ai.levelexp, ai.rp, ai.coin, ai.uid)
        skynet.send(".mysqlpool", "lua", "execute", sql)
        do_redis({"hmset", "d_user:"..ai.uid, {level=ai.level, levelexp=ai.levelexp, rp=ai.rp, coin=ai.coin}})
    end
end

-- 每天增加一定等级
-- 查找出最近7天登录玩家平均等级，上下浮动30%，计算出每个机器人的随机等级
-- 只能向上调整，不能向下调整
-- 2:4:2的分布进行等级调整
local function changeAiLevelExp()
    LOG_DEBUG("changeAiLevelExp")
    local maxMinLevelSql = string.format([[
        select max(level) as maxLevel,min(level) as minLevel
        from d_user where login_time>'%s' and isrobot is null or isrobot<>1
    ]], os.date("%Y-%m-%d", os.time() - 7 * 24 * 3600))
    local result = skynet.call(".mysqlpool", "lua", "execute", maxMinLevelSql)
    if not result or #result == 0 then
        LOG_DEBUG("changeAiLevelExp: no maxMinLevel")
        return
    end
    local maxLevel = result[1].maxLevel
    local minLevel = result[1].minLevel
    LOG_DEBUG(string.format("changeAiLevelExp: maxLevel:%d, minLevel:%d", maxLevel, minLevel))
    local recentUserSql = string.format([[
        select avg(level) as avgLevel from d_user
        where login_time > '%s'
        and (isrobot is null or isrobot<>1)
        and level <> %d
        and level <> %d
    ]], os.date("%Y-%m-%d", os.time() - 7 * 24 * 3600), minLevel, maxLevel)
    local result = skynet.call(".mysqlpool", "lua", "execute", recentUserSql)
    if not result or #result == 0 then
        LOG_DEBUG("changeAiLevelExp: no average level")
        return
    end
    local avgLevel = result[1].avgLevel
    if not avgLevel then
        LOG_DEBUG("changeAiLevelExp: no avgLevel")
        return
    end
    avgLevel = math.floor(avgLevel*1.5)
    -- 已有机器人按照等级排序
    table.sort(aiUserList, function(a, b)
        return a.level < b.level
    end)
    -- 前面25%的机器人等级调整为avgLevel - 30% --> avgLevel - 10% 
    -- 中间50%的机器人等级调整为avgLevel - 10% --> avgLevel + 10%
    -- 后面25%的机器人等级调整为avgLevel + 10% --> avgLevel + 30%
    local range1,range2,range3,range4 = avgLevel-math.floor(avgLevel*0.3),avgLevel-math.floor(avgLevel*0.1),avgLevel+math.floor(avgLevel*0.1),avgLevel+math.floor(avgLevel*0.3)
    LOG_DEBUG(string.format("changeAiLevelExp: range1:%d, range2:%d, range3:%d, range4:%d", range1, range2, range3, range4))
    -- 求出平均等级之后，调整机器人的等级
    local aiLen = #aiUserList
    for idx, robot in ipairs(aiUserList) do
        local randLevel
        if idx <= math.floor(aiLen*0.25) then
            randLevel = math.random(range1,range2)
        elseif idx <= math.floor(aiLen*0.75) then
            randLevel = math.random(range2,range3)
        else
            randLevel = math.random(range3,range4)
        end
        if robot.level < randLevel then
            robot.level = randLevel
            do_redis({"hset", "d_user:" .. robot.uid, "level", randLevel})
            local sql = string.format([[
                update d_user set level=%d where uid=%d
            ]], randLevel, robot.uid)
            skynet.call(".mysqlpool", "lua", "execute", sql)
        end
    end
    LOG_DEBUG("changeAiLevelExp: change ai level complete")
end

function CMD.start()
    LOG_DEBUG("skiptimer:", skiptimer)
    loadData()
    initOtherInfo()
    initLevelList()
    --打乱
    shuffle(aiUserList)
    --[[
    autoChangeRobotLevel = function ()
        changeAiLevelExp()
        skynet.timeout(24 * 3600 * 100, function ()
            if autoChangeRobotLevel then
                autoChangeRobotLevel()
            end
        end)
    end
    -- 算出凌晨时间
    local now = os.time()
    local delayTime = date.GetTodayZeroTime() + 24*60*60 - now
    if not skiptimer then
        skynet.timeout(delayTime * 100, autoChangeRobotLevel)
    end
    ]]--
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
		skynet.retpack(f(...))
	end)
	skynet.register(".aiuser")
end)
