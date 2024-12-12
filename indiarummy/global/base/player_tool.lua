local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
local date = require "date"
local api_service = require "api_service"
local JIANGRONG = false
local APP = tonumber(skynet.getenv("app") or 1)
local DEBUG = skynet.getenv("DEBUG")

--获取玩家信息
local function getPlayerInfo( uid )
    local ok,playerinfo = pcall(cluster.call, "master", ".userCenter", "getPlayerInfo", uid)
    if not ok then
        return nil
    end
    --把playerinfo的小数位限制到2位
    -- playerinfo.coin = math.floor(playerinfo.coin*10000+0.00000001)/10000
    return playerinfo
end

-- 获取玩家信息，只需要read，不需要进行读写
-- 直接从redis中读取
local function getSimplePlayerInfo(uid)
    local fields = {  -- 需要获取的字段
        'avatarframe',
        'playername',
        'chatskin',
        'frontskin',
        'usericon',
        'level',
        'levelexp',
        'svip',
        'svipexp',
        'vipendtime',
        'country',
        'uid',
        'leagueexp',
        'coin',
    }
    local cacheData = do_redis({ "hmget", "d_user:"..uid, table.unpack(fields)})
    cacheData = make_pairs_table(cacheData, fields)
    if cacheData.uid then
        cacheData.uid = cacheData.uid and tonumber(cacheData.uid)
        cacheData.svip = cacheData.svip and tonumber(cacheData.svip)
        cacheData.svipexp = cacheData.svipexp and tonumber(cacheData.svipexp)
        cacheData.level = cacheData.level and tonumber(cacheData.level)
        cacheData.levelexp = cacheData.levelexp and tonumber(cacheData.levelexp)
        cacheData.vipendtime = cacheData.vipendtime and tonumber(cacheData.vipendtime)
        cacheData.leagueexp = cacheData.leagueexp and tonumber(cacheData.leagueexp)
        cacheData.country = cacheData.country and tonumber(cacheData.country)
        cacheData.coin = cacheData.coin and tonumber(cacheData.coin)
    end
    return cacheData
end

-- 获取玩家排位分
local function getPlayerLeagueScore(uid, gameid)
    local redis_key = string.format('rank_list:%s:%d', PDEFINE.RANK_TYPE.GAME_LEAGUE, gameid)
    local score = do_redis({"zscore", redis_key, uid})
    if not score then
        return 0
    else
        return tonumber(score)
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

-- 更新玩家排位赛分数
local function updateLeagueRecord(uid, gameid, seasonid)
    local _, level = getPlayerLeagueInfo(uid, gameid)
    local updateSql
    local nowsql = string.format("select * from d_user_league where uid=%d and gameid=%d and seasonid=%d limit 1", uid, gameid, seasonid)
    local nowrs = skynet.call(".mysqlpool", "lua", "execute", nowsql)
    if not nowrs or #nowrs == 0 then
        updateSql = string.format("insert into d_user_league(uid, gameid, seasonid, level, update_time) values(%d, %d, %d, %d, %d)", uid, gameid, seasonid, level, os.time())
    else
        if nowrs[1]['level'] < level then
            updateSql = string.format("update d_user_league set level=%d, update_time=%d where uid=%d and gameid=%d and seasonid=%d",level, os.time(), uid, gameid, seasonid)
        end
    end
    LOG_DEBUG("updateLeagueRecord", updateSql)
    if updateSql then
        skynet.call(".mysqlpool", "lua", "execute", updateSql)
    end
end

-- 获取当前好友房游戏列表
local function getPlayerGameList(fgameliststr)
    local pinlist = PDEFINE_GAME.PIN_GAME_LIST
    local fgamelist = fgameliststr and string.split_to_number(fgameliststr, ',') or {}
    local cuslist = {}
    for _, gameid in ipairs(fgamelist) do
        if not table.contain(pinlist, gameid) then
            table.insert(cuslist, gameid)
        end
    end
    return pinlist, cuslist
end

local function brodcastcoin2client( uid, altercoin )
    pcall(cluster.send, "master", ".userCenter", "brodcastcoin2client", uid, altercoin)
end

--修改玩家金币
--@param ctype 参考PDEFINE.ALTERCOINTAG
--@param issync 可以不传 默认为false
--@param uid
--@param altercoin
--@param alterlog
--@param gameid
--@param pooltype
--@param subgameid
--@param deskuuid
local function calUserCoin_do( uid, altercoin, alterlog, ctype, gameid, pooltype, deskuuid, subgameid, issync, poolround_id, not2client, extend1)
    local paramlog = concatStr(uid,altercoin,alterlog,ctype,gameid,pooltype,deskuuid,subgameid,issync,poolround_id)
    assert(ctype, "ctypenil "..paramlog)
    assert(ctype >= 1 and ctype <= PDEFINE.ALTERCOINTAG.WINRANKCOIN, "ctypeerr "..paramlog)
    assert(uid, "uidnil "..paramlog)
    assert(altercoin, "altercoinnil "..paramlog)
    assert(alterlog, "alterlognil "..paramlog)
    assert(pooltype, "pooltypenil "..paramlog)
    if gameid == nil then
        gameid = 0
    end
    if subgameid == nil then
        subgameid = 0
    end
    if deskuuid == nil then
        deskuuid = 0
    end
    if issync == nil then
        issync = false
    end

    local altercoin_para={
        alter_coin=altercoin,
        type=ctype,
        alterlog=alterlog,
    }
    local gameinfo_para={
        gameid=gameid,
        subgameid=subgameid,
    }
    local poolround_para = {
        uniid = deskuuid, --唯一id
        pooltype = pooltype, --pooltype  PDEFINE.POOL_TYPE
        poolround_id = poolround_id, --pr的唯一id
    }
    local ok, code, beforecoin, aftercoin, altercoin_id = pcall(cluster.call, "master", ".userCenter", "calUserCoin",
         uid, issync, nil, altercoin_para, gameinfo_para, poolround_para, extend1)
    if not ok then
        LOG_ERROR("calUserCoin callfail", paramlog)
        return false,PDEFINE.RET.ERROR.CALL_FAIL
    end
    if code ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("calUserCoin code", code, paramlog)
        return false,code
    end
    -- 这里需要加入排行榜
    if altercoin > 0 then
        -- rtype RANK_TYPE.GAME_WINCOIN = 9
        pcall(cluster.send, "master", ".winrankmgr", "addRank", uid, {{rtype=9, gameid=gameid, coin=altercoin}})
    end
    if not not2client then -- master有调整，暂时还原
        brodcastcoin2client( uid, altercoin )
    end
    return true, code, altercoin_id, beforecoin, aftercoin
end


--修改玩家金币
--@param ctype 参考PDEFINE.ALTERCOINTAG
--@param issync 可以不传 默认为false
--@param uid
--@param altercoin
--@param alterlog
--@param gameid
local function calUserCoin_nogame( uid, altercoin, alterlog, ctype, gameid, pooltype, issync, not2client, extend1, poolround_id)
    local paramlog = concatStr(uid,altercoin,alterlog,ctype,gameid,pooltype,issync)
    assert(ctype, "ctypenil "..paramlog)
    assert(ctype >= 1 and ctype <= PDEFINE.ALTERCOINTAG.WINRANKCOIN, "ctypeerr "..paramlog)
    assert(uid, "uidnil "..paramlog)
    assert(altercoin, "altercoinnil "..paramlog)
    assert(alterlog, "alterlognil "..paramlog)
    if gameid == nil then
        gameid = 0
    end
    if pooltype == nil then
        pooltype = PDEFINE.POOL_TYPE.none
    end
    if issync == nil then
        issync = false
    end
    local ok,code,altercoin_id, beforecoin, aftercoin = calUserCoin_do(uid, altercoin, alterlog, ctype, gameid, pooltype, uid, 0, issync, poolround_id, not2client, extend1)
    return ok, code, altercoin_id, beforecoin, aftercoin
end

--修改玩家金币 game用的
local function calUserCoin( uid, altercoin, alterlog, ctype, deskInfo, pooltype)
    local paramlog = concatStr(uid,altercoin,alterlog,ctype,deskInfo,pooltype)
    if JIANGRONG then
        if type(deskInfo)=="number" then
            --老接口 第一个参数是gameid
            return true,PDEFINE.RET.SUCCESS
        end
    end
    assert(deskInfo, "deskInfonil "..paramlog)
    local subgameid = 0
    -- if deskInfo.subGame ~= nil then
    --  if deskInfo.subGame.subGameId ~= nil and deskInfo.subGame.subGameId > 0 then
    --      subgameid = deskInfo.subGame.subGameId
    --  end
    -- end
    if pooltype == nil then
        pooltype = PDEFINE.POOL_TYPE.none
    end

    local poolround_id = deskInfo.poolround_id or 0
    if 0 == poolround_id then
        if nil ~= deskInfo.processIdList then
            if nil ~= deskInfo.processIdList.big_poolround_id then
                poolround_id = deskInfo.processIdList.big_poolround_id
            elseif nil ~= deskInfo.processIdList.free_poolround_id then
                poolround_id = deskInfo.processIdList.free_poolround_id
            elseif nil ~= deskInfo.processIdList.sub_poolround_id then
                poolround_id = deskInfo.processIdList.sub_poolround_id
            end
        end
    end

    return calUserCoin_do( uid, altercoin, alterlog, ctype, deskInfo.gameid, pooltype, deskInfo.uuid, subgameid, nil, poolround_id, nil, nil)
end

--功能加金币
--[[
    extend1 入队列的扩展字段
]]
local function funcAddCoin(uid, altercoin, alterlog, ctype, gameid, pooltype, issync, extend1)
    local poolround_para = {
        uniid = uid, --唯一id
        pooltype = pooltype, --pooltype  PDEFINE.POOL_TYPE
    }
    local poolround_id = insertPoolRoundInfo()
    poolround_para["poolround_id"] = poolround_id --pr的唯一id

    local callok,addok,code, altercoin_id, before_coin,after_coin = pcall(
            calUserCoin_nogame, 
            uid, 
            altercoin, 
            alterlog, 
            ctype, 
            gameid, 
            pooltype, 
            issync,
            true,
            extend1,
            poolround_id
        )
    LOG_DEBUG(" calUserCoin_nogame callok:", callok, " addok:", addok, " code:", code, " before_coin:", before_coin, " after_coin:", after_coin, " altercoin_id:", altercoin_id)
    if not callok or not addok or code ~= PDEFINE.RET.SUCCESS then
        return PDEFINE.RET.ERROR.CALL_FAIL
    end

    return code,before_coin,after_coin
end

-- 添加系统邮件
local function addSysMail(mail)
    -- local attach = ""
    -- if mail.attach then
    --     attach = cjson.encode(mail.attach)
    -- end
    local sql = string.format(
        "insert into d_sys_mail (title, msg, attach, timestamp, stype,title_al,msg_al,svip,rate,remark,creator)values('%s', '%s', '%s', %d, %d, '%s', '%s','%s','%s','%s','%s')",
        mysqlEscapeString(mail.title),
        mysqlEscapeString(mail.msg),
        mail.attach,
        mail.timestamp,
        mail.stype,
        mysqlEscapeString(mail.title_al),
        mysqlEscapeString(mail.msg_al),
        mail.svip,
        mail.rate,
        mysqlEscapeString(mail.remark),
        mysqlEscapeString(mail.creator)
    )
	local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if rs.errno ~= nil and tonumber(rs.errno) > 0 then
        LOG_ERROR("addSysMail fail:", cjson.encode(rs))
        return
    end
    if rs and rs.insert_id then
        return rs.insert_id
    end
end

--修改玩家金币 game用的
local function calUserCoinSlot(uid, altercoin, alterlog, ctype, deskInfo, poolround_id)
    local pooltype = PDEFINE.POOL_TYPE.none
    local subgameid = 0
    local extend1 = {["fullbet"]=false, ["totalbet"]= deskInfo.totalBet}
    if altercoin < 0 then
        deskInfo.strategy:onBet(deskInfo, -altercoin)
        if RTP_TOTAL_BET then RTP_TOTAL_BET = RTP_TOTAL_BET + (-altercoin) end
    elseif altercoin > 0 then
        deskInfo.strategy:onWin(deskInfo, altercoin)
        if RTP_TOTAL_WIN then RTP_TOTAL_WIN = RTP_TOTAL_WIN + altercoin end
    end
    if not TEST_RTP then
        return calUserCoin_do(uid, altercoin, alterlog, ctype, deskInfo.gameid, pooltype, deskInfo.uuid, subgameid, nil, poolround_id, nil, extend1)
    end
end

-- 获取玩家能赢的rp值
local function calGameWinRp(gameid)
    local now = os.time()
    local hour = tonumber(os.date("%H", now))
    local week = tonumber(os.date("%w", now))
    if week == 0 then
        week = 7
    end
    local rp_reward = PDEFINE.RP_CONFIG.REWARD[gameid]
    if not rp_reward then
        rp_reward = PDEFINE.RP_CONFIG.REWARD.default
    end
    if not rp_reward then
        return 0
    end
    local rp = rp_reward[math.random(1, #rp_reward)]
    for _, cfg in pairs(PDEFINE.RP_CONFIG.DOUBLE) do
        if table.contain(cfg.week, week) and table.contain(cfg.hour, hour) then
            rp = rp * 2
            break
        end
    end
    return rp
end

-- 是否是排位房
local function getLeagueInfo(roomtype, uid)
    local now = os.time()
    local leagueInfo = {
        isOpen = 0,  -- 是否排位赛时间
        isSign = 0,  -- 是否解锁
        stopTime = nil,  -- 结束时间
    }
    if roomtype ~= PDEFINE.BAL_ROOM_TYPE.MATCH then
        return leagueInfo
    end
    local hour = os.date("%H", now)
    hour = tonumber(hour)
    local zeroTime = date.GetTodayZeroTime(os.time())
    for i=#PDEFINE.LEAGUE.HOUR, 1, -1 do
        if PDEFINE.LEAGUE.HOUR[i].stop > hour and PDEFINE.LEAGUE.HOUR[i].start <= hour then
            leagueInfo.isOpen = 1 --已开始
            leagueInfo.stopTime = (zeroTime+ PDEFINE.LEAGUE.HOUR[i].stop * 3600) - now
            break
        end
    end
    if DEBUG then
        leagueInfo.isOpen = 1
        leagueInfo.stopTime = 3600
    end
    if leagueInfo.isOpen == 1 then
        local cacheKey = PDEFINE.LEAGUE.SIGN_UP_KEY..uid
        local times = do_redis({"get", cacheKey}) --标记
        times = times and tonumber(times) or 0
        if math.floor(times) > 0 then
            leagueInfo.isSign = 1
        end
    end
    return leagueInfo
end

local function isLeagueTime(timestamp)
    timestamp = timestamp or os.time()
    local now = os.date("*t", timestamp)
    for i = #PDEFINE.LEAGUE.HOUR, 1, -1 do
        if PDEFINE.LEAGUE.HOUR[i].stop > now.hour and PDEFINE.LEAGUE.HOUR[i].start <= now.hour then
            return true
        end
    end
    return false
end

-- 获取玩家最近10场历史战绩
local function getRecentGameRecord(uid, limit, gameid)
    if not limit then
        limit = 10
    end
    if not uid then
        return {}
    end
    local sql
    if not gameid then
        sql = string.format([[
            select * from d_desk_user t
            where uid=%d and settle <> ''
            order by id desc 
            limit %d
        ]], uid, limit)
    else
        sql = string.format([[
            select * from d_desk_user t
            where uid=%d and gameid=%d and settle <> ''
            order by id desc 
            limit %d
        ]], uid, gameid, limit)
    end
    local result = {}
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local users = {}  -- 缓存查询用户，重复玩家无需重复查询
    if rs and #rs > 0 then
        for _, r in ipairs(rs) do
            local _, settle = pcall(cjson.decode, r['settle'])
            if settle and settle['coins'] and settle['uids'] then
                -- 获取用户信息
                local players = {}
                for i, ouid in ipairs(settle['uids']) do
                    if ouid == 0 then
                        table.insert(players, {seatid=i})
                    else
                        if not users[ouid] then
                            local userData = do_redis({"hgetall", "d_user:"..ouid, uid})
                            userData = make_pairs_table(userData)
                            users[ouid] = {
                                playername = userData['playername'],
                                avatarframe = userData['avatarframe'],
                                usericon = userData['usericon'],
                                uid = ouid,
                            }
                        end
                        table.insert(players, {
                            seatid = i,
                            playername = users[ouid].playername,
                            avatarframe = users[ouid].avatarframe,
                            usericon = users[ouid].usericon,
                            uid = ouid,
                            coin = settle.coins and settle.coins[i] or 0,
                        })
                    end
                end
                local item = {
                    uid = r['uid'],
                    deskid = r['deskid'],
                    gameid = r['gameid'],
                    players = players,
                    roomtype = r['roomtype'],
                    create_time = r['create_time'],
                    bet = r['bet'],
                    exited = r['exited'],
                    cost_time = r['cost_time']
                }
                table.insert(result, item)
            end
        end
    end
    return result
end

-- 根据不同的游戏折算经验值
local function getAddExpByGame(gameid, addExp)
    if PDEFINE_GAME.TYPE_INFO[APP] and PDEFINE_GAME.TYPE_INFO[APP][1] then
        local gameCfg = PDEFINE_GAME.TYPE_INFO[APP][1][gameid]
        if gameCfg then
            addExp = addExp * gameCfg.EXPRATE
        end
    end
    return math.floor(addExp)
end

-- 经验值加速道具
local function boosterExp(uid, iswin, roomtype, gameid)
    local addexp = 50
    if iswin then
        addexp = 80
    end
    -- 沙龙房，多增加20%的经验
    if roomtype and roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        addexp = addexp * 1.2
    end
    local cacheKey = PDEFINE_REDISKEY.OTHER.booster .. uid
    local result = do_redis({ "hgetall", cacheKey})
    result = make_pairs_table(result)
    -- LOG_DEBUG("boosterExp result:", result,  table.size(result))
    local addtotal = 0
    if table.size(result) > 0 then
        local nowtime = os.time()
        for buffer, endtime in pairs(result) do
            if tonumber(endtime) > nowtime then
                addtotal = addtotal + (tonumber(buffer)/100) * addexp
            else
                do_redis({"hdel", cacheKey, buffer})
            end
        end
    end
    return getAddExpByGame(gameid, (addexp + addtotal))
end

-- 添加钻石明细记录
local function addDiamondLog(rs)
    local uid = rs.uid
    local content = rs.content or ""
    local act = rs.act or ""
    local remark = rs.remark or ""
    content = mysqlEscapeString(content)
    remark = mysqlEscapeString(remark)
    local diamond = rs.diamond or 0
    local afterDiamond = rs.afterDiamond or 0
    local coin = rs.coin or 0
    local level = rs.level or 1
    local levelexp = rs.levelexp or 0
    local svip = rs.svip or 0
    local svipexp = rs.svipexp or 0
    local ticket = rs.ticket or 0
    local leagueexp = rs.leagueexp or 0
    local leaguelevel = rs.leaguelevel or 0
    local sql = string.format("insert into d_diamond_log(uid,diamond,afterdiamond,create_time,act,content,remark, coin,level,levelexp,svip,svipexp,ticket,leagueexp,leaguelevel) values (%d, %d, %d,%d, '%s','%s','%s', %.2f, %d, %d, %d,%d,%d,%d,%d)", uid, diamond, afterDiamond,os.time(), act, content, remark, coin, level, levelexp, svip, svipexp, ticket, leagueexp, leaguelevel)
    do_mysql_queue(sql)
end

-- 获取leaderboard的rediskey和timeinfo
local function getLeaderBoardInfo(rtype, sptime)
    if not sptime then
        sptime = os.time()
    end
    local timeInfo = getLeaderBorderRangeTime(sptime)

    -- 先从redis中读取，如果没有则从数据中心读取
    local redis_key = PDEFINE.REDISKEY.LEADERBOARD.T_REGISTER..rtype..":"
    if rtype == PDEFINE.LEADER_BOARD.TYPE.DAY then
        local todayDate = os.date("%Y%m%d", timeInfo.day.start)
        redis_key = redis_key..todayDate
        timeInfo.scan = timeInfo.day
    elseif rtype == PDEFINE.LEADER_BOARD.TYPE.WEEK or rtype == PDEFINE.LEADER_BOARD.TYPE.REFERRALS then
        local weekDate = os.date("%Y%m%d", timeInfo.week.start)
        redis_key = redis_key..weekDate
        timeInfo.scan = timeInfo.week
    elseif rtype == PDEFINE.LEADER_BOARD.TYPE.MONTH then
        local monthDate = os.date("%Y%m%d", timeInfo.month.start)
        redis_key = redis_key..monthDate
        timeInfo.scan = timeInfo.month
    else
        return nil
    end
    LOG_DEBUG("getLeaderBoardInfo timeInfo", timeInfo)
    return redis_key, timeInfo
end

-- 获取leaderboard排行榜
local function getLeaderBoardList(rtype, redis_key, startTime, stopTime, gameidstrs)
    local cacheData = do_redis({"get", redis_key})
    if cacheData and cacheData ~= "" then
        cacheData = cjson.decode(cacheData)
    else
        cacheData = {}
        local sql
        if rtype == PDEFINE.LEADER_BOARD.TYPE.REFERRALS then
            -- 从数据中读取, 代理榜不需要注册
            -- sql = string.format([[
            --     select 
            --         b.invit_uid as uid, sum(a.bet-a.wincoin) as total, d.playername,d.usericon
            --     from d_desk_user a
            --     left join d_user_invite b on a.uid=b.uid
            --     left join d_user c on a.uid=c.uid
            --     left join d_user d on d.uid=b.invit_uid
            --     where a.create_time between %d and %d
            --     and c.ispayer = 1
            --     and b.invit_uid is not null
            --     and a.settle <> ''
            --     group by b.invit_uid;
            -- ]], startTime, stopTime)
            sql = string.format([[
                select b.uid,b.playername,b.usericon, effbet 
                from d_lb_agent a 
                left join d_user b on a.invit_uid = b.uid 
                where a.create_time>%d and a.create_time<%d 
                order by effbet desc 
                limit 20
            ]], startTime, stopTime)
        else
            -- 从数据中读取
            sql = string.format([[
                select 
                    b.uid, sum(a.bet) as total, c.playername,c.usericon
                from d_desk_user a 
                left join d_user c on a.uid=c.uid
                inner join (
                    select uid, create_time 
                    from d_lb_register 
                    where rtype=%d 
                    and create_time between %d and %d
                ) b on a.uid = b.uid 
                where a.create_time between b.create_time and %d 
                and a.settle <> ''
                group by uid
            ]], rtype, startTime, stopTime, stopTime)
            if not isempty(gameidstrs) then
                sql = string.format([[
                select 
                    b.uid, sum(a.bet) as total, c.playername,c.usericon
                from d_desk_user a 
                left join d_user c on a.uid=c.uid
                inner join (
                    select uid, create_time 
                    from d_lb_register 
                    where rtype=%d 
                    and create_time between %d and %d
                ) b on a.uid = b.uid 
                where a.create_time between b.create_time and %d 
                and a.gameid in (%s)
                and a.flag = 1
                and a.settle <> ''
                group by uid
            ]], rtype, startTime, stopTime, stopTime, gameidstrs)
            end
        end
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        LOG_DEBUG('rs size:', #rs, ' type:', rtype)
        if rs and #rs > 0 then
            for _, r in ipairs(rs) do
                if not r.total or r.total < 0 then
                    r.total = 0
                end
                if rtype == PDEFINE.LEADER_BOARD.TYPE.REFERRALS then
                    table.insert(cacheData, {uid=r.uid, score=r.total/100, playername=r.playername, usericon=r.usericon, reward_coin=0})
                else
                    table.insert(cacheData, {uid=r.uid, score=r.total/100, playername=r.playername, usericon=r.usericon, reward_coin=0})
                end
            end
            -- 排序
            table.sort(cacheData, function(a, b)
                return a.score > b.score
            end)
            local ok, allRewards = pcall(cluster.call, "master", ".configmgr", "getLeaderBoardRewards", rtype)
            if ok then
                for _, reward in ipairs(allRewards) do
                    for ord = reward.l_ord, reward.r_ord, 1 do
                        local item = cacheData[ord]
                        if item then
                            item.reward_coin = reward.coin
                        end
                    end
                end
            end
            -- 将结果写入redis中
            do_redis({"setex", redis_key, cjson.encode(cacheData), 300})
        end
    end
    return cacheData
end

return {
    getPlayerInfo = getPlayerInfo,
    getSimplePlayerInfo = getSimplePlayerInfo,
    calUserCoin = calUserCoin,
    calUserCoin_nogame = calUserCoin_nogame,
    calUserCoin_do = calUserCoin_do,
    funcAddCoin = funcAddCoin,
    brodcastcoin2client = brodcastcoin2client,
    addSysMail = addSysMail,
    getPlayerLeagueScore = getPlayerLeagueScore,
    getPlayerLeagueInfo = getPlayerLeagueInfo,
    getPlayerGameList = getPlayerGameList,
    calUserCoinSlot = calUserCoinSlot,
    calGameWinRp = calGameWinRp,
    getLeagueInfo = getLeagueInfo,
    updateLeagueRecord = updateLeagueRecord,
    isLeagueTime = isLeagueTime,
    getRecentGameRecord = getRecentGameRecord,
    boosterExp = boosterExp,
    addDiamondLog = addDiamondLog,
    getLeaderBoardList = getLeaderBoardList,
    getLeaderBoardInfo = getLeaderBoardInfo,
}