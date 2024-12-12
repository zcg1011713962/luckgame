local skynet = require "skynet"
require "skynet.manager"
local player_tool = require "base.player_tool"
local DEBUG = skynet.getenv("DEBUG")
local obj = {}
local CMD = {}

local MAX_FRIEND_COUNT = 95 --最大是50个，但已有45个了就不推荐了
local MATCH_COUNT = 100
local autoFuc = nil -- 定时器
local users = {}

local ONLINE_USERS = {} --vip在线，排行榜在线，在线素人
local RANK_UIDS = {} --排行榜的uid

local function setTimeout(ti, f)
    LOG_DEBUG("setTimeout", ti)
    local function t()
        if f then
            f()
        end
    end
    skynet.timeout(ti, t)
    return function() f=nil end
end

function obj.checkSession()
    if autoFuc then
        autoFuc()
        autoFuc = nil
    end
    autoFuc = setTimeout(10*100, obj.load)
end

-------- 开始加载数据 --------
function obj.load(level, excludeFriendsUIDS)
    local sql = "select uid, count(*) count from d_friend group by uid"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local excludeUIDs = {}
    local beginLevel = level or 1
    local startLevel = 0
    local endLevel = beginLevel + 1000
    if nil ~= excludeFriendsUIDS then
        for _, excludeUID in pairs(excludeFriendsUIDS) do
            table.insert(excludeUIDs, excludeUID) --排除掉已经是好友的
        end
    end
    if #rs > 0 then
        for _, row in pairs(rs) do
            if row.count >= MAX_FRIEND_COUNT then
                table.insert(excludeUIDs, row.uid) --排除掉那些已经超过上限的
            end
        end
    end
    local now = os.time()
    local beginLoginTime = now - 90 * 86400
    if table.empty(excludeUIDs) then
        sql = string.format("select uid, level,svip, playername, usericon, isbindfb, from_channel, coin,ourself from d_user where create_time > %d and level >= %d and level <= %d and isrobot=0 order by svip desc, level desc", beginLoginTime, startLevel, endLevel)
    else
        sql = string.format("select uid, level,svip, playername, usericon, isbindfb, from_channel, coin,ourself from d_user where create_time > %d and uid not in (%s) and level >= %d and level <= %d and isrobot=0 order by svip desc, level desc", beginLoginTime, table.concat(excludeUIDs, ','), startLevel, endLevel)
    end
    rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs < 4 then
        beginLoginTime = beginLoginTime - 365 * 86400
        if table.empty(excludeUIDs) then
            sql = string.format("select uid, level,svip, playername, usericon, isbindfb, from_channel, coin,ourself from d_user where create_time > %d and isrobot=0 order by svip desc, level desc", beginLoginTime)
        else
            sql = string.format("select uid, level,svip, playername, usericon, isbindfb, from_channel, coin,ourself from d_user where create_time > %d and uid not in (%s) and isrobot=0 order by svip desc, level desc", beginLoginTime, table.concat(excludeUIDs, ','))
        end
        rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    end
    local tmp_users = {} --最近1月内登陆过的用户
    if #rs > 0 then
        for _, row in pairs(rs) do
            local fb = row.isbindfb or 0
            if row.from_channel == 12 then
                fb = 1
            end
            row.fb = fb
            row.isonline = 0
            table.insert(tmp_users, row)
        end
    end
    -- table.sort(tmp_users, function(a, b)
    --     if a.level < b.level then
    --         return true
    --     elseif a.level > b.level then
    --         return false
    --     else
    --         return a.uid < b.uid
    --     end
    -- end)
    users = tmp_users
    LOG_DEBUG("load users", #users, ' level:', level)
end

-- 记录vip在线，排行榜在线，在线素人
function CMD.online(uid)
    local userInfo = player_tool.getPlayerInfo(uid)
    if userInfo == nil then
        return false
    end
    local inrank = 0
    local score = RANK_UIDS[uid] or 0
    if RANK_UIDS[uid] then
        inrank = 1
    end
    local exsits = false
    for i=#ONLINE_USERS, 1, -1 do
        if ONLINE_USERS[i].uid == uid then
            ONLINE_USERS[i].svip = userInfo.svip
            ONLINE_USERS[i].svipexp = userInfo.svipexp
            ONLINE_USERS[i].inrank = inrank
            ONLINE_USERS[i].rankscore = score
            ONLINE_USERS[i].online = 1
            ONLINE_USERS[i].ourself = userInfo.ourself
            exsits = true
            break
        end
    end
    if not exsits then
        local item = {
            uid = uid,
            svip = userInfo.svip,
            svipexp = userInfo.svipexp,
            inrank = inrank,
            rankscore = score,
            online = 1
        }
        table.insert(ONLINE_USERS, item)
    end
    return true
end

function CMD.offline(uid)
    local userInfo = player_tool.getPlayerInfo(uid)
    if nil == userInfo then
        return false
    end
    for i=#ONLINE_USERS, 1, -1 do
        if ONLINE_USERS[i].uid == uid then
            ONLINE_USERS[i].svip = userInfo.svip
            ONLINE_USERS[i].svipexp = userInfo.svipexp
            ONLINE_USERS[i].online = 0
            break
        end
    end
    return true
end

--获取推荐的用户
function CMD.getRecommends(total, level,  excludeUIDs, random, userData)
    local uids = {}
    -- local sql = "select userid from d_recom_user where status=1"
    local sql = string.format("select userid from d_forbid where recomadd=1 and ((svip ='' and tag = '' and targetuids ='') or (svip like '%%%s,%%' or tag like '%%%s,%%' or targetuids like '%%%s,%%'))", userData.svip, userData.tagid, userData.uid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            if not table.contain(excludeUIDs, row['userid']) then
                table.insert(uids, row['userid'])
            end
        end
    end

    -- local idx = 0
    -- if random then
        -- local datalist = {}
        -- for _, row in ipairs(ONLINE_USERS) do
            -- if not table.contain(excludeUIDs, row.uid) and (nil~=row.ourself and row.ourself==1) then
                -- table.insert(datalist, row.uid)
            -- end
        -- end
        -- table.random(uids)
        -- for _, item in pairs(datalist) do
            -- table.insert(uids, item)
            -- idx = idx + 1
            -- if idx >= total then
                -- break
            -- end
        -- end
    -- else
        -- for _, row in ipairs(ONLINE_USERS) do
            -- if not table.contain(excludeUIDs, row.uid) and (nil~=row.ourself and row.ourself==1) then
                -- table.insert(uids, row.uid)
                -- idx = idx + 1
                -- if idx >= total then
                    -- break
                -- end
            -- end
        -- end
    -- end
    -- LOG_DEBUG("排序uids:", uids)
    -- if #uids == 0 then
        -- LOG_DEBUG("没有找到用户uid, 用老方法")
        -- local matchUsers = CMD.match(level, excludeUIDs)
        -- LOG_DEBUG("没有找到用户uid, 用老方法 matchUsers: ", #matchUsers)
        -- for _, row in pairs(matchUsers) do
            -- table.insert(uids, row.uid)
        -- end
    -- end
    return uids
end

--从列表中找它
local function find_in_list(uid, datalist)
    for _ , row in pairs(datalist) do
        if row.uid == uid then
            return row
        end
    end
end

-- 初始化在线用户的uid池子
local function init_online_users()
    LOG_DEBUG("gen data init_online_users")
    local checkonlinetable = {}
    local user_list = {}

    -- 设置vip在线
    local nowtime = os.time()
    local login_time = nowtime - 30 * 86400
    local sql = string.format("select uid,svip,svipexp,vipendtime from d_user where login_time>%d and vipendtime>%d",
    login_time, nowtime)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            table.insert(checkonlinetable, tonumber(row.uid))
            local item = {
                uid = tonumber(row.uid),
                rankscore = 0,
                inrank = 0,
                svip = tonumber(row.svip),
                svipexp = tonumber(row.svipexp),
                online = 0
            }
            table.insert(user_list, item)
        end
    end

    --设置排行榜在线的uid
    local rank_type = {PDEFINE.RANK_TYPE.TOTALCOIN, PDEFINE.RANK_TYPE.DIAMOND_WEEK, PDEFINE.RANK_TYPE.VIP_WEEK, PDEFINE.RANK_TYPE.CHARM_WEEK, PDEFINE.RANK_TYPE.RP_MONTH}
    for _, rtype in pairs(rank_type) do
        local redis_key = string.format('rank_list:%s', rtype)
        rs = do_redis({"zrevrangebyscore", redis_key, 50, 1})
        for i = 1, #rs, 2 do
            -- 过滤掉零值
            if tonumber(rs[i+1]) == 0 then
                break
            end
            local uid = tonumber(rs[i])
            local score = tonumber(rs[i+1])
            RANK_UIDS[uid] = score
            local user = find_in_list(uid, user_list)
            if not user then
                local item = {
                    uid = uid,
                    rankscore = score,
                    inrank = 1,
                    svip = 0,
                    svipexp = 0,
                    online = 0
                }
                table.insert(user_list, item)
            else
                user.inrank = 1
                user.rankscore = tonumber(rs[i+1])
            end
            table.insert(checkonlinetable, uid)
        end
    end

    local onlinetable = skynet.call(".userCenter","lua","checkOnline", checkonlinetable)
    for _, row in pairs(user_list) do
        if onlinetable[row.uid] ~= nil then
            row.online = 1
        end
    end
    ONLINE_USERS = user_list
    local delay = 7200
    if DEBUG then
        delay = 300
    end
    
    LOG_DEBUG("Next genRanking init_online_users dealy:", delay)
    setTimeout(delay*100, init_online_users)
end

function CMD.match(level, excludeUIDs)
    local matchUsers = {}
    -- LOG_DEBUG("CMD.match level: ", level, " excludeUIDs:", excludeUIDs)
    obj.load(level, excludeUIDs)
    -- LOG_DEBUG("CMD.match get users", #users)
    local matchUIDs = {}
    if #users > 0 then
        local cnt = 0
        for i=#users, 1, -1 do
            local user = users[i]
            if cnt >= MATCH_COUNT then
                break
            end
            table.insert(matchUsers, user)
            table.insert(matchUIDs, user.uid)
            cnt = cnt + 1
        end
    end
    local ok, onlinelist = pcall(skynet.call, ".userCenter", "lua", "checkOnline", matchUIDs)
    if ok then
        for _, row in pairs(matchUsers) do
            if nil ~= onlinelist[row.uid] then
                row.isonline = 1
            end
        end
    end
    return matchUsers
end

function CMD.reload()
    obj.load()
    return PDEFINE.RET.SUCCESS
end

function CMD.start()
    obj.load()
    init_online_users()
    return PDEFINE.RET.SUCCESS
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        if not f then
            LOG_ERROR("invalid cmd: ", cmd)
            return
        end
        skynet.retpack(f(...))
    end)
    skynet.register(".friend")
end)
