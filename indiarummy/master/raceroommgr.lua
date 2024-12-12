-- vip房 页面操作
local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local queue     = require "skynet.queue"
local player_tool = require "base.player_tool"
local cjson = require "cjson"
local raceCfg = require "conf.raceCfg"
local DEBUG = skynet.getenv("DEBUG")
local cs = queue()
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

--接口
local CMD = {}
local UIDS = {}  -- 进入游戏中的人

local function getAgent(uid)
    return skynet.call(".userCenter", "lua", "getAgent", uid)
end

-- 获取赛事信息, 包括当前时间之后的
function CMD.raceInfo(recvobj)
    local uid = recvobj.uid
    local retobj = {c=recvobj.c, spcode=0, uid=uid, code=PDEFINE.RET.SUCCESS, games={}}
    retobj.games,retobj.restTime = raceCfg.getGameInfo(nil, true)
    retobj.rewards = raceCfg.rewards
    LOG_DEBUG("raceInof", retobj)
    return PDEFINE.RET.SUCCESS, retobj
end

-- 加入赛事, 直接加入房间
function CMD.joinRace(cluster_info, recvobj, ip, newplayercount)
    local uid = recvobj.uid
    local score = recvobj.score  -- 场次金币限制
    local gameid = recvobj.gameid  -- 场次游戏id
    local retobj = {c=recvobj.c, spcode=0, uid=uid, code=PDEFINE.RET.SUCCESS}
    local games = raceCfg.getGameInfo()
    local targetGame = nil
    for _, game in ipairs(games) do
        if game.status == 1 and game.gameid == gameid and game.score == score then
            targetGame = game
        end
    end
    -- 找不到相应的游戏
    if not targetGame then
        retobj.spcode = PDEFINE.RET.ERROR.JOIN_RACE_ERROR
        return PDEFINE.RET.SUCCESS, retobj
    end
    local sesslist = skynet.call(".sessmgr", "lua", "getSessByGameId", gameid)
    local ssid = nil
    for _, cfg in ipairs(sesslist) do
        if cfg.entry == targetGame.basecoin then
            ssid = cfg.ssid
            break
        end
    end
    if not ssid then
        retobj.spcode = PDEFINE.RET.ERROR.JOIN_RACE_ERROR
        return PDEFINE.RET.SUCCESS, retobj
    end
    -- 转发到匹配接口上
    local forwardObj = {
        c = recvobj.c,
        uid = recvobj.uid,
        gameid = recvobj.gameid,
        ssid = ssid,
        race_id = targetGame.id,
        race_type = targetGame.stype,
    }
    local retcode, noticeObj, deskAddr = skynet.call(".mgrdesk", "lua", "matchSess", cluster_info, forwardObj, ip, newplayercount)
    LOG_DEBUG("joinRace: retcode: ", retcode, "deskAddr: ", deskAddr)
    if retcode == PDEFINE.RET.SUCCESS then
        if not UIDS[targetGame.id] then
            UIDS[targetGame.id] = {}
        end
        UIDS[targetGame.id][uid] = 1
        LOG_DEBUG("settle: UIDS", UIDS)
        noticeObj.c = 43
        skynet.timeout(10, function()
            local cluster_info = skynet.call(".userCenter", "lua", "getAgent", uid)
            if cluster_info then
                pcall(cluster.call, cluster_info.server, cluster_info.address, "sendToClient", cjson.encode(noticeObj))
            end
        end)
    else
        retobj.spcode = retcode
    end
    return PDEFINE.RET.SUCCESS, retobj, deskAddr
end

-- 增加比赛分数
function CMD.addRaceScore(uid, race_id, score)
    local gameInfo = raceCfg.getGameInfo(race_id)
    if not gameInfo or gameInfo.status ~= raceCfg.Status.Doing then
        return
    end
    local redisKey = raceCfg.getRedisKey(gameInfo.id)
    local count = do_redis({"zcard", redisKey})
    if count == 0 then
        do_redis({"zadd", redisKey, score, uid})
        -- 设置过期时间
        local expireTime = getThisPeriodTimeStamp()
        do_redis({"expire", redisKey, expireTime})
    else
        do_redis({"zincrby", redisKey, score, uid})
    end
    local score = do_redis({"zscore", redisKey, uid})
    local rankId = do_redis({ "zrevrank", redisKey, uid})
    if rankId then
        rankId = rankId + 1  -- 这里需要+1, 因为排名从1开始
    end
    score = tonumber(score)
    -- 这里有一个默认分数段，少于这个分数，就随机名次，大于这个分数，就取真实名次信息
    rankId = raceCfg.getRankId(gameInfo, score, rankId)
    local notifyObj = {
        c = PDEFINE.NOTIFY.NOTIFY_RACE_UPDATE,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        score = score,
        rankId = rankId,
        restTime = gameInfo.restTime,
        race_id = race_id,
        uid = uid,
    }
    local cluster_info = skynet.call(".userCenter", "lua", "getAgent", uid)
    if cluster_info then
        pcall(cluster.call, cluster_info.server, cluster_info.address, "sendToClient", cjson.encode(notifyObj))
    end
end

local function findNextRace()
    local raceInfo = nil
    local delayTime = 0
    local now = os.time()
    local zeroTime = 1
    local week = tonumber(os.date("%w", now))
    if week == 0 then
        week = 7
    end
    local hour = tonumber(os.date("%H", now))
    local minute = tonumber(os.date("%M", now))
    local second = tonumber(os.date("%S", now))
    local raceInfos = raceCfg.config[week]
    for _, info in ipairs(raceInfos) do
        if hour < info.sHour then
            raceInfo = info
            break
        elseif info.sMin + info.duration > (hour-info.sHour)*60 + minute then
            raceInfo = info
            break
        end
    end
    if raceInfo then
        delayTime = (raceInfo.sHour - hour)*60*60 + (raceInfo.sMin + raceInfo.duration - minute)*60 - second
        return delayTime, raceInfo.id
    end
    week = week + 1
    if week > 7 then
        week = 1
    end
    raceInfo = raceCfg.config[week][1]
    delayTime = 24*60*60 + (raceInfo.sHour - hour)*60*60 + (raceInfo.sMin + raceInfo.duration - minute)*60 - second
    return delayTime, raceInfo.id
end

-- 结算当天赛事信息
function CMD.settle(race_id)
    local cfg = raceCfg.getGameInfo(race_id)
    -- 判断是否已经结束
    -- 未结束，则找到结束时间点，设置定时器
    -- 已结束，则进行结算，并且找到下一个场次的结算时间，设置定时器
    if cfg.status ~= raceCfg.Status.Finish and not DEBUG then
        skynet.timeout(5*60*100, function ()
            CMD.settle(race_id)
        end)
    else
        -- 找到前100名
        local redis_key = raceCfg.getRedisKey(race_id)
        local game_name = PDEFINE_GAME.GAME_NAME[cfg.gameid]
        local levelRewards = raceCfg.rewards[cfg.rewardId]
        local rs = do_redis({"zrevrangebyscore", redis_key, 100, 1})
        local users = {}
        for i = 1, #rs, 2 do
            table.insert(users, {uid=tonumber(rs[i]), coin=tonumber(rs[i+1])})
        end
        -- 如果第一名不存在，则需要虚构一个第一名出来，为了展示用
        local hasFirst = true
        if table.empty(users) then
            hasFirst = false
        end
        -- 存入redis,方便取
        local first_user_redis_key = PDEFINE.REDISKEY.RACE.last_user..race_id
        LOG_DEBUG("settle: ", users)
        local maxScore = 0
        local rewardResult = {}
        for ord, user in ipairs(users) do
            local rankId = raceCfg.getRankId(cfg, user.coin, ord)
            if ord == 1 then
                maxScore = user.coin
                if rankId ~= 1 then
                    hasFirst = false
                else
                    do_redis({"set", first_user_redis_key, user.uid})
                end
            end
            -- 发送邮件
            if rankId <= 100 then
                local attach, rewards
                if rankId == 1 then
                    rewards = levelRewards[1].rewards
                elseif rankId < 11 then
                    rewards = levelRewards[2].rewards
                else
                    rewards = levelRewards[3].rewards
                end
                attach = {}
                for _, reward in ipairs(rewards) do
                    local r = table.copy(reward)
                    table.insert(attach, r)
                end
    
                local msg = string.format("Congratulations, you won the %dth place in the %s Challenge game, and look forward to your better results in the next games.",rankId, game_name.en)
                local msg_al = string.format("تهانينا ، لقد فزت بالمركز %s في لعبة تحدي %s ، ونتطلع إلى نتائج أفضل في المباريات القادمة.", rankId, game_name.al)
                local title_al = "جوائز كأس كوكبة"
                local title = "Constellation Cup Rewards"
                local mailid = genMailId()
                local mail_message = {
                    mailid = mailid,
                    uid = user.uid,
                    fromuid = 0,
                    msg  = msg,
                    type = PDEFINE.MAIL_TYPE.RACE,
                    title = title,
                    attach = cjson.encode(attach),
                    sendtime = os.time(),
                    received = 0,
                    hasread = 0,
                    sysMailID= 0,
                    title_al = title_al,
                    msg_al = msg_al,
                }
                LOG_DEBUG("sendRewards wille race rank mail uid:", user.uid,' rankId:', rankId)
                skynet.send(".userCenter", "lua", "addUsersMail", user.uid, mail_message)
                rewardResult[tonumber(user.uid)] = {ord=rankId, rewards=attach,mailid=mailid}
                local sql = string.format([[
                    insert into s_race_record (id, uid, race_id, game_id, stype, rank_id,score, create_time) 
                    values (null, %d, %d, %d, %d, %d, %d);
                ]], user.uid, race_id, cfg.gameid, cfg.stype, rankId,user.coin, os.time())
                LOG_DEBUG("race settle sql: ", sql)
                skynet.send(".mysqlpool", "lua", "execute", sql)
            end
        end

        if not hasFirst then
            -- 随机找出一个机器人
            local ok, ai_user_list = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", 1, false)
            if ok and not table.empty(ai_user_list) then
                local ai = ai_user_list[1]
                local score = maxScore + math.random(10, 20)
                local sql = string.format([[
                    insert into s_race_record (id, uid, race_id, game_id, stype, rank_id, score, create_time) 
                    values (null, %d, %d, %d, %d, %d, %d, %d);
                ]], ai.uid, race_id, cfg.gameid, cfg.stype, 1, score, os.time())
                LOG_DEBUG("robot race record sql: ", sql)
                skynet.send(".mysqlpool", "lua", "execute", sql)
                do_redis({"set", first_user_redis_key, ai.uid})
            end
        end

        -- 找到下一个结算时间
        local delayTime, next_race_id = findNextRace()
        skynet.timeout(delayTime*100, function ()
            CMD.settle(next_race_id)
        end)

        -- 广播消息给所有人，已经结算了
        if UIDS[race_id] then
            for uid, _ in pairs(UIDS[race_id]) do
                local agent = getAgent(uid)
                if agent then
                    local obj = {uid=uid,race_id=race_id,status=0}
                    if rewardResult[tonumber(uid)] then
                        obj.rewards = rewardResult[tonumber(uid)].rewards
                        obj.ord = rewardResult[tonumber(uid)].ord
                        obj.mailid = rewardResult[tonumber(uid)].mailid
                    end
                    local ok, currCharm = pcall(cluster.call, agent.server, agent.address, "updateRaceStatus", obj)
                end
            end
        end
    end

end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = assert(CMD[cmd])
        skynet.retpack(f(...))
	end)
    skynet.register(".raceroommgr")
    -- 找到下一个结算时间
    local delayTime, next_race_id = findNextRace()
    skynet.timeout(delayTime*100, function()
        CMD.settle(next_race_id)
    end)
    -- skynet.timeout(120*100, function()
    --     CMD.settle(801)
    -- end)
end)