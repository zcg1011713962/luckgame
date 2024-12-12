local skynet = require "skynet"
local cluster = require "cluster"
local cjson   = require "cjson"
local mailbox = require "mailbox"
local player_tool = require "base.player_tool"
local md5     = require "md5"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local cmd = {}
local handle

local MAX_FRIEND_COUNT = 100
local NOT_FOUND_TIMES = 20 --通过id找好友，最大找不到次数
local defaultLevel = 1
local RECOMMEND_MAX = 8 --最大推荐数
local defaultPlayerName = "Guest"
local defaultUserIcon = "https://download.mensaplay.net/head/sys/1.png"
local CACHE_KEY_NOT_FOUND = "not_found:"
local CACHE_KEY_SEND_PREFIX = 'send_coin:'
local CACHE_KEY_TODAY_SEND = 'dot_friend_send:'
local CACHE_KEY_LUCKY = 'dot_friend_lucky:'
local UID 

--我中了jackpot，给好友发奖励，在userCenter中presentJackpot完成

function cmd.bind(agent_handle)
	handle = agent_handle
end

local function timeout(outtime, func, uid)
    local function t()
        if func then
            func(uid)
        end
    end
    skynet.timeout(outtime, t)
    return function() func = nil end
end

-- 将好友关系绑定到redis中
local function import2Cache()
    local sql= string.format("select uid, friend_uid from d_friend where uid=%d", UID)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs >0 then
        for _, row in pairs(rs) do
            do_redis({"sadd", "friends_uid:".. UID, row['friend_uid']})
            do_redis({"sadd", "friends_uid:".. row['friend_uid'], UID})
        end
    end
    LOG_DEBUG("import2Cache over")
end

function cmd.initUid(uid)
    UID = uid
end

function cmd.init(uid)
    UID = uid
    skynet.timeout(250, import2Cache)
end

local function getMaxCnt(uid)
    local cnt = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.FRIENDSMAX)
    if cnt == nil or cnt <= 0 then
        cnt = MAX_FRIEND_COUNT
    end
    return cnt
end

local function getCacheLeftTime(redis_key)
    local leftTime = do_redis({"get", redis_key}) or 0 --是否可以赠送
    leftTime = math.floor(leftTime)
    return leftTime
end

local function setCache(redis_key, val)
    local left_time = getThisPeriodTimeStamp() --距离当前周期结束的时间戳
    local redis_val = left_time --截止时间当做value
    if nil ~= val then
        redis_val = val
    end
    do_redis({"setex", redis_key , redis_val, left_time})
    return true
end

-- 添加好友的sql
local function addFriendSql(uid, frienduid)
    LOG_DEBUG("addFriendSql uid:", uid, " friend:", frienduid)
    local succ = true
    local sql = string.format("insert into d_friend (uid, friend_uid, present_time, hastake) values (%d, %d, %d, %d)", uid, frienduid, 0, 1) --默认为不能领
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs or not rs.insert_id then
        succ = false
    end

    sql = string.format("insert into d_friend (uid, friend_uid, present_time, hastake) values (%d, %d, %d, %d)", frienduid, uid, 0, 1)
    rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs or not rs.insert_id then
        succ = false
    end
    return succ
end

local function timeoutSendAddFriends(frienduid)
    local json_str = cjson.encode({c=270, uid= frienduid})
    local ok, json_notify = cmd.getList(json_str)
    pcall(cluster.call, "master", ".userCenter", "pushInfoByUid", frienduid, json_notify) --刷新好友的好友列表
end



-- 对方是否我好友，能否加对方为好友
function cmd.canAddFriend(uid, frienduid)
    local can_send = 0 --是否可以赠送金币 0:否 1是
    local can_add = 0 --不是好友，可以添加对方为好友
    if not uid or not frienduid or 0 == frienduid then
        return can_add, can_send
    end
    local friends_cnt = do_redis({"scard", "friends_uid:".. uid})
    if friends_cnt >= getMaxCnt(uid) then
        can_add = 1 --不能添加好友，自己好友超过了
    end

    local had_friends = do_redis({"sismember", "friends_uid:".. uid, frienduid})
    if had_friends then
        can_add = 2 --不能添加好友，对方已是好友
        local redis_key = CACHE_KEY_SEND_PREFIX .. uid ..":"..frienduid
        local leftTime = getCacheLeftTime(redis_key)
        if leftTime <= 0 then
            can_send = 1 --已是好友，且今天还未送过金币
        end
    end
    local his_friends_cnt = do_redis({"scard", "friends_uid:".. frienduid})
    if his_friends_cnt >= getMaxCnt(frienduid) then
        can_add = 3 --不能添加好友，对方好友超过了
    end
    return can_add, can_send
end

-- 添加好友
function cmd.addFriend(msg)
	local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local mobile = recvobj.mobile
    local frienduid = recvobj.frienduid
    local actfind   = recvobj.act or 0 --是否通过输入uid查好友
    local iscache = recvobj.cache --是否缓存请求
    actfind = math.floor(actfind)

    if not iscache then
        if actfind == 1 then --打点
            handle.addStatistics(uid, 'add_friend_bymobile', mobile) --主动输入uid，添加好友
        else
            handle.addStatistics(uid, 'add_friend_bymobile', 0) --添加推荐好友
        end
    end
    
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, friend={mobile=mobile, uid=nil}, spcode=0} --spcode 为错误提示码
    
    if not mobile and not frienduid then
        retobj.spcode = PDEFINE.RET.ERROR.PARAM_IS_EMPTY
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    local issys = 1 -- 系统推荐
    -- 通过mobile找到好友uid
    if not frienduid then
        issys = 0
        local fsql = string.format("select uid from d_user_bind where unionid='%s'", mobile)
        local frs = skynet.call(".mysqlpool", "lua", "execute", fsql)
        if frs and #frs > 0 then
            frienduid = frs[1].uid
        end
    end
    if not frienduid then
        retobj.spcode = PDEFINE.RET.ERROR.FRIEND_NOT_EXISTS
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    retobj.friend.uid = frienduid

    if tonumber(frienduid) == tonumber(uid) then
        retobj.spcode = PDEFINE.RET.ERROR.FRIEND_ADD_SELF
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    --好友上限判断
    local friends_cnt = do_redis({"scard", "friends_uid:".. uid})
    if nil ~= friends_cnt and friends_cnt >= getMaxCnt(uid)  then
        retobj.spcode = PDEFINE.RET.ERROR.FRIEND_SELF_MAXNUM
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    local his_friends_cnt = do_redis({"scard", "friends_uid:".. frienduid})
    if nil ~= his_friends_cnt and his_friends_cnt >= getMaxCnt(frienduid)  then
        retobj.spcode = PDEFINE.RET.ERROR.FRIEND_FRIENDSHIP_MAXNUM
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    --是否已经是好友
    local had_friends = do_redis({"sismember", "friends_uid:".. uid, frienduid})
    if had_friends then
        retobj.spcode = PDEFINE.RET.ERROR.FRIEND_SELF_EXISTS
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    LOG_DEBUG("friend.addFriend frienduid:", frienduid, ' type:', type(frienduid))
    local ret = string.find(frienduid,"^%d+$")
    if nil == ret then
        retobj.spcode = PDEFINE.RET.ERROR.FRIEND_NOT_EXISTS
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    frienduid = math.floor(frienduid)

    -- 通过id 加好友，有错误次数限制
    if actfind == 1 then
        local cache_key = CACHE_KEY_NOT_FOUND .. uid
        local times = do_redis({"get", cache_key}) or 0 --错误的次数
        times = math.floor(times)
        if times >= NOT_FOUND_TIMES then
            retobj.spcode = PDEFINE.RET.ERROR.FRIEND_NOT_EXISTS_TIMES
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end
    end

    -- 查看自己是否绑定手机号
    if issys == 0 then
        local myPlayerInfo = handle.moduleCall("player", "getPlayerInfo", uid)
        if not myPlayerInfo or not myPlayerInfo.isbindphone or myPlayerInfo.isbindphone == 0 then
            retobj.spcode = PDEFINE.RET.ERROR.NEED_BIND_MOBILE
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end
    end

    -- 对应的好友id不存在
    local playerInfo = handle.moduleCall("player", "getPlayerInfo", frienduid)
    if not playerInfo.uid then
        local cache_key = CACHE_KEY_NOT_FOUND .. uid
        local times = do_redis({"get", cache_key}) or 0 --错误的次数
        times = math.floor(times)
        if times <= 0 then
            setCache(cache_key, 1)
        else
            do_redis({ "incr", cache_key })
        end
        if tonumber(frienduid) >= 99999999 then
            retobj.spcode = PDEFINE.RET.ERROR.FRIEND_NOT_EXISTS
        end
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj) --加机器人，不返回错误信息，
    end
    local sql= string.format("select forbidadd from d_forbid where userid = %d and status=1", UID)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 and rs[1].forbidadd == 1 then
        retobj.spcode = PDEFINE.RET.ERROR.FRIEND_ADD_FORBID
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    if playerInfo.verifyfriend ~= nil and playerInfo.verifyfriend == 1 then
        local sql= string.format("select * from d_friend_request where uid = %d and frienduid=%d ", UID, frienduid)
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs <= 0 then
            sql = string.format("insert into d_friend_request(uid, frienduid, create_time) value(%d,%d,%d)", UID, frienduid, os.time())
            skynet.call(".mysqlpool", "lua", "execute", sql)
    
            pcall(cluster.call, "master", ".userCenter", "syncLobbyInfo", frienduid)
        end
    else
        do_redis({"sadd", "friends_uid:".. uid, frienduid})
        do_redis({"sadd", "friends_uid:".. frienduid, uid})
        local sql= string.format("delete from d_friend_request where uid = %d and frienduid=%d ", frienduid, UID)
        skynet.call(".mysqlpool", "lua", "execute", sql)
        addFriendSql(uid, frienduid)
        
        local isonline = 0
        local ok , online_list = pcall(cluster.call, "master", ".userCenter", "checkOnline", {frienduid})
        if ok and online_list[frienduid] ~= nil then
            isonline = 1
        end
        retobj.friend = {
            uid = frienduid,
            coin = 0, --赠送的金币,
            present_time = 0,
            send = 0, --默认未赠送
            present_count = 0,
            levelexp = playerInfo.levelexp or 0,
            playername = playerInfo.playername or defaultPlayerName,
            usericon = playerInfo.usericon or defaultUserIcon,
            usercoin = playerInfo.coin,
            isonline = isonline,
        }
        local json_str = cjson.encode({c=270, uid= UID}) --自己也推一下270协议
        local ok, json_notify = cmd.getList(json_str)
        handle.sendToClient(json_notify)

        if isonline == 1 then
            timeout(100, timeoutSendAddFriends, frienduid) --好友在线的话，给好友推270协议
        end

    end

    -- 更新主线任务
    -- local updateMainObjs = {
    --     {kind=PDEFINE.MAIN_TASK.KIND.AddFriend, count=1},
    -- }
    -- handle.moduleCall("maintask", "updateTask", uid, updateMainObjs)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 根据uid获取推荐的好友列表
local function getRecommendsData(uid, random)
    local data = {}
    if nil == uid then
        return data
    end

    local rs = do_redis({"smembers", "friends_uid:".. uid})
    local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)
    if playerInfo.uid then
        local excludeUIDs = {uid}
        for _, friend_uid in pairs(rs) do
            friend_uid = math.floor(friend_uid)
            table.insert(excludeUIDs, friend_uid)
        end
        local sql = string.format("select frienduid from d_friend_request where uid = %d", uid)
        local res = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #res > 0 then
            for _, row in pairs(res) do
                table.insert(excludeUIDs, row.frienduid)
            end
        end
        -- LOG_DEBUG("get user excludeUIDs:", excludeUIDs)
        local userdata = {
            svip = playerInfo.svip,
            tagid = playerInfo.tagid,
            uid = uid
        }
        local ok, mathUids = pcall(cluster.call, "master", ".friend", "getRecommends", RECOMMEND_MAX, playerInfo.level, excludeUIDs, random, userdata)
        LOG_DEBUG("get user count:", #mathUids)
        if ok and mathUids and #mathUids > 0 then
            local _, onlinelist = pcall(cluster.call, "master", ".userCenter", "checkOnline", mathUids)
            for _, muid in pairs(mathUids) do
                local muser = player_tool.getPlayerInfo(muid)
                if muser then
                    local item = {
                        uid = muser.uid,
                        level = muser.level,
                        playername = muser.playername,
                        usericon = muser.usericon,
                        fb = muser.fb,
                        usercoin = muser.coin,
                        svip = muser.svip or 0,
                        avatarframe = muser.avatarframe,
                        leagueexp = muser.leagueexp,
                        re = 0, --推荐好友
                        isonline = 0,
                    }
                    if nil ~= onlinelist[item.uid] then
                        item.isonline = 1
                    end
                    table.insert(data, item)
                end
            end
        end
    end
    return data
end

local function getRequestList()
    local sql= string.format("select uid from d_friend_request where frienduid=%d and status=0 order by id desc limit 5", UID)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local datalist = {}
    local testUids = {}
    if #rs > 0 then
        for _, row in pairs(rs) do
            table.insert(testUids, row.uid)
        end

        local _, onlinelist = pcall(cluster.call, "master", ".userCenter", "checkOnline", testUids)
        for _, row in pairs(rs) do
            local playerInfo = handle.moduleCall("player","getPlayerInfo", row.uid)
            row.playername = playerInfo.playername
            row.usericon = playerInfo.usericon
            row.svip = playerInfo.svip or 0
            row.levelexp = playerInfo.levelexp or 0
            row.country = playerInfo.country or 0
            row.avatarframe = playerInfo.avatarframe
            row.re = 1 --是需要审核的好友, 0:是推荐的好友
            row.fb = playerInfo.isbindfb or 0
            row.leagueexp = playerInfo.leagueexp or 0
            row.isonline = 0
            if nil ~= onlinelist[row.uid] then
                row.isonline = 1
            end
            table.insert(datalist, row)
        end
    end
    return datalist
end

--! 获取推荐列表, 单独获取推荐的好友列表
function cmd.getRecommends(msg)
    local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local recommendItems = getRequestList()
    if #recommendItems < 4 then
        local reclist = getRecommendsData(uid, true) --需要每次调用都随机
        if #reclist > 0 then
            for _, row in pairs(reclist) do
                table.insert(recommendItems, row)
                if #recommendItems > 4 then
                    break
                end
            end
        end
    end
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, recommendItems = recommendItems, spcode=0}
	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

local function getTag(uid, rtype)
    local cache_key = CACHE_KEY_TODAY_SEND..uid
    if nil ~= rtype then
        cache_key = CACHE_KEY_LUCKY..uid
    end

    local tag = do_redis({"get", cache_key})
    -- LOG_DEBUG("gettag:", tag, " cache_key", cache_key)
    if tag then
        return true
    end
    return false
end

-- 获取这个用户是否可以领取的标记, 内部接口使用
function cmd.getLuckTag(uid)
    return getTag(uid, 'lucky')
end

--! 获取好友列表
-- @param recommends 1表示携带推荐 0不带推荐
function cmd.getList(msg)
	local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local curPage   = math.floor(recvobj.curPage or 1)
    local recommends = math.floor(recvobj.recommends or 0)
    if curPage < 1 then
        curPage = 1
    end

    local sql = string.format("select a.friend_uid uid, b.level, b.playername, b.usericon,b.isbindfb, b.from_channel, b.leaguelevel, b.leagueexp,b.avatarframe,b.coin,b.svip,b.vipendtime from d_friend as a left join d_user b on a.friend_uid = b.uid where a.uid = %d order by present_time desc, a.uid asc limit %d", uid, getMaxCnt(uid))
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local items = {}
    local hadFriends = #rs --已有好友数
    if #rs > 0 then
        local now = os.time()
        local ok, leagueArr = pcall(cluster.call, "master", ".cfgleague", "getAll")
        local UIDs = {}
        for _, _item in pairs(rs) do
           table.insert(UIDs, _item.uid)
        end
        local _, onlinelist = pcall(cluster.call, "master", ".userCenter", "checkOnline", UIDs)
        for _, _item in pairs(rs) do
            if nil == _item.level then
                _item.level = 1
            end
            local fbuser = _item.isbindfb or 0
            if _item.from_channel == 12 then
                fbuser = 1
            end
            local badge = _item.svip or 0
            if _item.vipendtime and _item.vipendtime < now then
                badge = 0
            end
            if _item.playername == nil or _item.playername == "" then
                local tmpUserInfo = player_tool.getPlayerInfo(_item.uid)
                if tmpUserInfo then
                    _item.playername = tmpUserInfo.playername
                    _item.level = tmpUserInfo.level
                    _item.usericon = tmpUserInfo.usericon
                    _item.leagueexp = tmpUserInfo.leagueexp
                    _item.leaguelevel = tmpUserInfo.leaguelevel
                    _item.coin = tmpUserInfo.coin
                    _item.avatarframe = tmpUserInfo.avatarframe
                end
            end
            _item.leagueexp = _item.leagueexp or 0
            local item = {
                uid = _item.uid,
                level = _item.level or defaultLevel,
                playername = _item.playername or defaultPlayerName,
                usericon = _item.usericon or defaultUserIcon,
                fb = fbuser,
                isonline = 0,
                score = _item.leagueexp,
                avatarframe = _item.avatarframe or 0, --头像框 
                coin = _item.coin or 0,
                badge = tonumber(badge), --会员勋章
                gstatus = 0, --0可以邀请 1在等待进入游戏状态
            }
            if leagueArr then
                local leaguelv = _item.leaguelevel or 1
                if leaguelv < 1 then
                    leaguelv = 1
                end
                LOG_DEBUG("leaguelv: ", leaguelv, ' leagueexp:', _item.leagueexp)
                item.score = leagueArr[leaguelv].score + _item.leagueexp
            end
            if nil ~= onlinelist and nil ~= onlinelist[_item.uid] then
                item.isonline = 1
                local agent = onlinelist[_item.uid]
                local ok, gstatus = pcall(cluster.call, agent.server, agent.address, "getGstatus")
                LOG_DEBUG("ok,", ok, ' gstatus:', gstatus)
                if ok then
                    item.gstatus = gstatus
                end
            end
 
            table.insert(items, item)
        end
    end

    table.sort(items, function(a, b)
        if a.badge > b.badge then
            return true
        elseif a.badge < b.badge then
            return false
        else
            if a.coin > b.coin then
                return true
            elseif a.coin < b.coin then
                return false
            else
                return a.uid < b.uid
            end
        end
    end)
    local maxFriends = getMaxCnt(uid)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, curPage = curPage, hasNextPage = false, items = items, maxFriends=maxFriends, hadFriends=hadFriends, spcode=0}
    retobj.recommendItems = {}
    if 1 == recommends then
        retobj.recommendItems = getRecommendsData(uid)
    end

	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! collect all 通过fb分享再次获取金币
function cmd.getFbShare(msg)
    local recvobj   = cjson.decode(msg)
	local uid       = math.floor(recvobj.uid)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, coin=0, uid = uid}
    local key = "friends_fbshare:".. uid
    local coin = do_redis({"get", key})
    if coin ~= nil then
        do_redis({"del", key})
        coin = tonumber(coin)
        handle.addProp(PDEFINE.PROP_ID.COIN, coin, "takeFriendJackpotFbShare")
        retobj.coin = coin
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 根据搜搜id，自动搜索列表
function cmd.getLikeUIDs(msg)
    local recvobj = cjson.decode(msg)
    local mobile = recvobj.mobile
    local uid = recvobj.uid
    local frienduid = recvobj.frienduid
    local search = recvobj.searchuid or ""
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, mobile=mobile, spcode=0, list={}}
    -- if search == "" then
    --     return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    -- end
    -- local flag = true
    -- if flag then
    --     return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    -- end
    -- 通过mobile找到好友uid
    if mobile then
        local fsql = string.format("select uid from d_user_bind where unionid='%s'", mobile)
        local frs = skynet.call(".mysqlpool", "lua", "execute", fsql)
        LOG_DEBUG("getLikeUIDs",fsql)
        if frs and #frs > 0 then
            frienduid = frs[1].uid
        end
    end
    if not frienduid then
        retobj.spcode = PDEFINE.RET.ERROR.FRIEND_NOT_EXISTS
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    -- local friends = do_redis({"smembers", "friends_uid:".. UID})
    -- local excludeUIDs = {}
    -- table.insert(excludeUIDs, uid)
    -- if friends ~= nil then
    --     for _, fuid in pairs(friends) do
    --         table.insert(excludeUIDs, fuid)
    --     end
    -- end
    -- search = mysqlEscapeString(search)
    -- local sql = "select uid from d_user where uid not in ("..table.concat(excludeUIDs, ',')..") and (uid like '"..search.."%' or playername like '".. search .."%') limit 10"
    -- local sql = "select uid,playername,usericon,country,levelexp,svip,avatarframe,leagueexp,leaguelevel from d_user where uid not in ("..table.concat(excludeUIDs, ',')..") and playername = '".. search .."' limit 10"
    local sql = string.format([[
        select a.uid,a.playername,a.usericon,a.country,a.levelexp,a.svip,a.avatarframe,a.leagueexp,a.leaguelevel
        from d_user a where a.uid=%d;
    ]], frienduid)
    LOG_DEBUG("Search sql:"..sql)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        local ok, leagueArr = pcall(cluster.call, "master", ".cfgleague", "getAll")
        local reqUids = {}
        local sql2= string.format("select * from d_friend_request where frienduid=%d or uid=%d order by id desc", UID, UID)
        local rs2 = skynet.call(".mysqlpool", "lua", "execute", sql2)
        for _, row in pairs(rs2) do
            if row.frienduid == UID then
                reqUids[row.uid] = 1 --别人加我
            else 
                reqUids[row.frienduid] = 1 --我加别人
            end
        end
        for key, row in pairs(rs) do
            -- local playerInfo = handle.moduleCall("player","getPlayerInfo", row.uid)
            local muser = {}
            muser.uid = row.uid
            muser.playername = row.playername
            muser.usericon = row.usericon
            muser.country = row.country or 0
            muser.levelexp = row.levelexp or 0
            muser.mobile = mobile
            muser.vip = row.svip or 0
            muser.avatarframe = row.avatarframe or 0
            muser.isfriend = cmd.canAddFriend(uid, row.uid)
            muser.isreq = 0
            muser.score = row.leagueexp
            if leagueArr[row.leaguelevel] then
                muser.score =  muser.score + leagueArr[row.leaguelevel].score
            end
            if #reqUids > 0 and nil ~= reqUids[row.uid] then
                muser.isreq = 1
            end
            table.insert(retobj['list'], muser)
        end
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 跟我一起玩游戏的玩家列表
--TODO:等待删除
function cmd.getGameUsers(msg)
    local recvobj   = cjson.decode(msg)
    local uid = recvobj.uid

    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, list={}}
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    
    -- local sql ="select * from d_desk_user where uid="..uid.." and (gameid > 255 and gameid < 400) order by id desc limit 20"
    -- local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    -- local reqUids = {}
    -- if #rs > 0 then
    --     local sql2= string.format("select * from d_friend_request where frienduid=%d or uid=%d order by id desc", UID, UID)
    --     local rs2 = skynet.call(".mysqlpool", "lua", "execute", sql2)
    --     for _, row in pairs(rs2) do
    --         if row.frienduid == UID then
    --             reqUids[row.uid] = 1 --别人加我
    --         else 
    --             reqUids[row.frienduid] = 1 --我加别人
    --         end
    --     end
    -- end
    -- local friends = do_redis({"smembers", "friends_uid:".. UID})
    -- local excludeUIDs = {}
    -- excludeUIDs[UID] = true
    -- if friends ~= nil then
    --     for _, fuid in pairs(friends) do
    --         excludeUIDs[tonumber(fuid)] = true
    --     end
    -- end

    -- local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, list={}}
    -- local ok, leagueArr = pcall(cluster.call, "master", ".cfgleague", "getAll")
    -- for _, row in pairs(rs) do
    --     local ok, settle = pcall(jsondecode, row.settle)
        
    --     if ok and type(settle) == 'table' then
    --         for _, item in pairs(settle) do
    --             if item ~= nil and type(item) == 'table' and item['users'] ~=nil then
    --                 for _, user in pairs(item['users']) do
    --                     LOG_DEBUG("user.uid:", user)
    --                     if excludeUIDs[user.uid] == nil then --多游戏记录中可能有重复uid
    --                         local muser = user
    --                         local playerInfo = handle.moduleCall("player","getPlayerInfo", user.uid)
    --                         LOG_DEBUG("getGameUsers playerInfo info:", playerInfo)
    --                         if not playerInfo.uid then
    --                             local ok, ai_user_list = pcall(cluster.call, "ai", ".aiuser", "getAiInfoByUid", {user.uid})
    --                             LOG_DEBUG("ai_user_list:", ai_user_list)
    --                             if ok then
    --                                 for key, item in pairs(ai_user_list) do
    --                                     playerInfo = {
    --                                         ["uid"] = key,
    --                                         ["playername"] = item.playername,
    --                                         ["usericon"] = item.usericon,
    --                                         ["svip"] = 0,
    --                                         ["level"] = item.level,
    --                                         ["isonline"] = 0,
    --                                     }
    --                                     break
    --                                 end
    --                             end
    --                         end

    --                         muser.playername = playerInfo.playername or muser.playername
    --                         muser.usericon = playerInfo.usericon
    --                         muser.country = playerInfo.country or 0
    --                         muser.levelexp = playerInfo.levelexp or 0
    --                         muser.vip = playerInfo.svip or 0
    --                         muser.avatarframe = playerInfo.avatarframe or 0
    --                         muser.isfriend = cmd.canAddFriend(uid, user.uid)
    --                         muser.isreq = 0
    --                         muser.score = playerInfo.leagueexp
    --                         if leagueArr[playerInfo.leaguelevel] then
    --                             muser.score =  muser.score + leagueArr[playerInfo.leaguelevel].score
    --                         end
    --                         if #reqUids > 0 and nil ~= reqUids[user.uid] then
    --                             muser.isreq = 1
    --                         end
    --                         table.insert(retobj['list'], muser)
    --                         excludeUIDs[muser.uid] = true
    --                     end
    --                 end
    --             end
    --         end
    --     end
    -- end
    -- return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end


local function getRecentChats(uid, cmd)
    local retobj = {c = cmd, code = PDEFINE.RET.SUCCESS, datalist={}}
    local data = {}
    local beginTime = os.time() - 60 * 86400
    local sql = string.format("select a.* from d_chat_user a join (select max(id) as id from d_chat_user where (uid1=%d and del1=0) or (uid2=%d and del2=0) and create_time>%d group by md5) b on b.id = a.id order by a.create_time desc limit 100", uid, uid, beginTime)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)

    local checkUids = {}
    for _, row in pairs(rs) do
        if row.uid1 == uid then
            table.insert(checkUids, row.uid2)
        else
            table.insert(checkUids, row.uid1)
        end
    end
    local blocked_uid = {}
    local playerInfo = handle.moduleCall("player","getPlayerInfo", uid)
    local ok, blockedlist = pcall(jsondecode, playerInfo.blockuids)
    if ok and blockedlist then --已经屏蔽了好友，不能再给它发消息了
        for _, buid in pairs(blockedlist) do
            blocked_uid[buid] = true
        end
    end
    local _, onlinelist = pcall(cluster.call, "master", ".userCenter", "checkOnline", checkUids)
    for _, row in pairs(rs) do
        local friend_uid = row.uid1
        if row.uid1 == uid then
            friend_uid = row.uid2
        end
        
        if not blocked_uid[friend_uid] then
            local playerInfo = handle.moduleCall("player","getPlayerInfo", friend_uid)
            row.uid = friend_uid
            row.usericon = playerInfo.usericon
            row.playername = playerInfo.playername
            row.country = playerInfo.country
            row.levelexp = playerInfo.levelexp or 0
            row.vip = playerInfo.svip
            row.avatarframe = playerInfo.avatarframe
            row.chatskin=playerInfo.chatskin
            row.frontskin = playerInfo.frontskin
            row.online = 0
            if nil ~= onlinelist and nil ~= onlinelist[row.uid] then
                row.online = 1
            end
            local msgobj = cjson.decode(row.content)
            row.type = msgobj.type
            row.msg = msgobj.msg
            row.uid1 = nil
            row.uid2 = nil
            table.insert(data, row)
        end
    end
    retobj.datalist = data
    return retobj
end

--! 删除私聊信息
function cmd.delChat(msg)
    local recvobj   = cjson.decode(msg)
    local uid = math.floor(recvobj.uid or 0) --我
    local friendids = recvobj.frienduids or ""
    local frienduids = string.split(friendids, ",")
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode = 0, frienduids = {}}
    if table.size(frienduids) == 0 then 
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end
    local nowtime = os.time()
    local fuids = {}
    for _, fuid in pairs(frienduids) do
        fuid = tonumber(fuid)
        table.insert(fuids, fuid)
        --我主动发出去的
        local sql = string.format("update d_chat_user set del1=%d where uid1=%d and uid2=%d and del1=0", nowtime, uid, fuid)
        skynet.call(".mysqlpool", "lua", "execute", sql)

        --别人发给我的
        sql = string.format("update d_chat_user set del2=%d where uid1=%d and uid2=%d and del1=0", nowtime, fuid, uid)
        skynet.call(".mysqlpool", "lua", "execute", sql)
    end
    retobj.frienduids = fuids
    return PDEFINE.RET.SUCCESS,cjson.encode(retobj)
end

--! 关闭私聊界面同步红点
function cmd.closeChat(msg)
    local recvobj   = cjson.decode(msg)
    local uid = math.floor(recvobj.uid or 0)
    local frienduid = math.floor(recvobj.frienduid or 0)
    local sql= string.format("update d_chat_user set unread=0 where uid2=%d", uid)
    if frienduid > 0 then
        sql= string.format("update d_chat_user set unread=0 where uid1=%d and uid2=%d", frienduid, uid)
    end
    skynet.call(".mysqlpool", "lua", "execute", sql)
    handle.moduleCall("player","syncLobbyInfo",uid)
    return PDEFINE.RET.SUCCESS
end

--! 好友之间私聊
function cmd.chat(msg)
    local recvobj   = cjson.decode(msg)
    local frienduid = recvobj.touid
    local uid = recvobj.uid
    local content = recvobj.msg or ""
    local rtype = recvobj.type or 1
    local iscache = recvobj.cache --是否缓存请求
    local replyid = math.floor(recvobj.replyid or 0) --回复的哪一条
    local now = os.time()

    if not iscache then
       handle.addStatistics(uid, 'friend_chat', frienduid)
    end
    local item = cjson.encode({type=rtype, msg=content})
    local md5key = ""
    if tonumber(frienduid) < tonumber(UID) then
        md5key = md5.sumhexa(frienduid ..'|'..UID)
    else
        md5key = md5.sumhexa(UID ..'|'.. frienduid)
    end
    local playerInfo = handle.moduleCall("player","getPlayerInfo", UID)
    local ok, blockedlist = pcall(jsondecode, playerInfo.blockuids)
    if ok and blockedlist then --已经屏蔽了好友，不能再给它发消息了
        if table.contain(blockedlist, frienduid) then
            return PDEFINE.RET.SUCCESS
        end
    end

    local friendInfo = player_tool.getPlayerInfo(frienduid)
    local blocked = 0
    if friendInfo then
        local ok, blockedlist = pcall(jsondecode, friendInfo.blockuids)
        if ok and blockedlist then
            if table.contain(blockedlist, UID) then
                blocked = 1
            end
        end
    end
    local replyContent = ""
    if replyid > 0 then --可能是回复别人的信息
        local sql1 = string.format("select * from d_chat_user where id=%d and uid2=%d", replyid, UID)
        local chatItemRes = skynet.call(".mysqlpool", "lua", "execute", sql1)
        if chatItemRes[1] then
            replyContent = cjson.encode({
                uid = chatItemRes[1]['uid1'],
                content = cjson.decode(chatItemRes[1]['content']),
                create_time = chatItemRes[1]['create_time'],
            })
        end
    end

    local questSql = string.format("select count(distinct `md5`) as t from d_chat_user where uid1=%d or uid2=%d", UID, UID)
    local rs = skynet.call(".mysqlpool", "lua", "execute", questSql)
    if rs[1].t < 5 then
        handle.moduleCall("quest", 'updateQuest', UID, PDEFINE.QUEST_TYPE.NEWER, PDEFINE.QUESTID.NEW.REDEMPOTION, 1)
    end

    item = mysqlEscapeString(item)
    local sql = string.format("insert into d_chat_user(md5,uid1,uid2,content,create_time,blocked,reply) values ('%s',%d, %d, '%s', %d, %d, '%s')", md5key, UID, frienduid, item, now, blocked, replyContent)
    -- LOG_DEBUG("friend.chat sql:", sql)
    skynet.call(".mysqlpool", "lua", "execute", sql)
    local notify = {c=PDEFINE.NOTIFY.NOTIFY_FRIEND_CHAT, code=200}
    notify.data = {
        type = rtype,
        msg = content,
        uid = UID,
        create_time = now,
        playername = playerInfo.playername,
        usericon = playerInfo.usericon,
        avatarframe = playerInfo.avatarframe,
        levelexp = playerInfo.levelexp or 0,
        vip = playerInfo.svip,
        chatskin=playerInfo.chatskin,
        frontskin = playerInfo.frontskin
    }
    LOG_DEBUG("friend chat notify:", notify)
    if blocked == 0 then
        pcall(cluster.call, "master", ".userCenter", "syncLobbyInfo", frienduid, cjson.encode(notify))
    end
    if replyid > 0 then
        local reply = {}
        local friendInfo = handle.moduleCall("player","getPlayerInfo", frienduid)
        reply.playername = friendInfo.playername
        reply.usericon = friendInfo.usericon
        reply.levelexp = friendInfo.levelexp
        reply.vip = friendInfo.svip
        reply.avatarframe = friendInfo.avatarframe
        local replymsg = cjson.decode(replyContent)
        reply.type = replymsg.content.type
        reply.content = replymsg.content.msg
        reply.uid = replymsg.uid
        notify.data.reply = reply
    end
    pcall(cluster.call, "master", ".userCenter", "pushInfoByUid", UID, cjson.encode(notify))

    local notifyRecentChats = getRecentChats(UID, 452)
    handle.sendToClient(cjson.encode(notifyRecentChats))

    if blocked == 0 then
        local ok, onlinelist = pcall(cluster.call, "master", ".userCenter", "checkOnline", {frienduid})
        if ok and nil ~= onlinelist and nil ~= onlinelist[frienduid] then
            notifyRecentChats = getRecentChats(frienduid, 452)
            pcall(cluster.call, "master", ".userCenter", "pushInfoByUid", frienduid, cjson.encode(notifyRecentChats))
        else
            pcall(skynet.send, ".pushmsg", "lua", "send", frienduid, PDEFINE.PUSHMSG.THREE)
        end
    end

    return PDEFINE.RET.SUCCESS
end


--! 最近好友之间的聊天列表
function cmd.chatlist(msg)
    local recvobj   = cjson.decode(msg)
    local retobj = getRecentChats(UID, math.floor(recvobj.c))
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 好友私聊汇聚到一起
function cmd.allchatlist(msg)
    local recvobj   = cjson.decode(msg)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, datalist={}}
    local data = {}
    local beginTime = os.time() - 60 * 86400
    local uid = UID
    local sql = string.format("select * from d_chat_user where uid1=%d or uid2=%d and create_time>%d limit 300", uid, uid, beginTime)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)

    local update_sql = string.format("update d_chat_user set unread=0 where uid2=%d", uid)
    skynet.call(".mysqlpool", "lua", "execute", update_sql)
    handle.moduleCall("player","syncLobbyInfo", uid)

    local checkUids = {}
    for _, row in pairs(rs) do
        if row.uid1 == uid then
            table.insert(checkUids, row.uid2)
        else
            table.insert(checkUids, row.uid1)
        end
    end
    local blocked_uid = {}
    local playerInfo = handle.moduleCall("player","getPlayerInfo", uid)
    local ok, blockedlist = pcall(jsondecode, playerInfo.blockuids)
    if ok and blockedlist then --已经屏蔽了好友，不能再给它发消息了
        for _, buid in pairs(blockedlist) do
            blocked_uid[buid] = true
        end
    end
    local _, onlinelist = pcall(cluster.call, "master", ".userCenter", "checkOnline", checkUids)
    for _, row in pairs(rs) do
        local friend_uid = row.uid1
        if not blocked_uid[friend_uid] then
            local playerInfo = handle.moduleCall("player","getPlayerInfo", friend_uid)
            row.uid = row.uid1
            row.usericon = playerInfo.usericon
            row.playername = playerInfo.playername
            row.country = playerInfo.country
            row.levelexp = playerInfo.levelexp
            row.vip = playerInfo.svip
            row.avatarframe = playerInfo.avatarframe
            row.chatskin=playerInfo.chatskin
            row.frontskin = playerInfo.frontskin
            row.online = 0
            if nil ~= onlinelist and nil ~= onlinelist[row.uid] then
                row.online = 1
            end
            local msgobj = cjson.decode(row.content)
            row.type = msgobj.type
            row.content = msgobj.msg
            if row.uid1 == uid then
                local reply = {}
                local friendInfo = handle.moduleCall("player","getPlayerInfo", row.uid2)
                reply.uid = row.uid2
                reply.playername = friendInfo.playername
                reply.usericon = friendInfo.usericon
                reply.levelexp = friendInfo.levelexp
                reply.vip = friendInfo.svip
                reply.avatarframe = friendInfo.avatarframe
                local ok, replymsg = pcall(jsondecode, row.reply)
                if ok then
                    reply.type = replymsg.content.type
                    reply.content = replymsg.content.msg
                end
                row.reply = reply
            else
                row.reply = nil
            end
            row.uid1 = nil
            row.uid2 = nil
            table.insert(data, row)
        end
    end
    retobj.datalist = data

    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 删除好友
function cmd.removeFriend(msg)
	local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local frienduids= recvobj.frienduids
    local iscache = recvobj.cache --是否缓存请求

    if not iscache then
        handle.addStatistics(uid, 'remove_friend', 0)
    end

    for _, frienduid in pairs(frienduids) do
        if type(frienduid) == 'number' then --防止客户端乱传
            do_redis({"srem", "friends_uid:".. uid, frienduid})
            do_redis({"srem", "friends_uid:".. frienduid, uid})

            local sql = string.format("delete from d_friend where uid = %d and friend_uid = %d", uid, frienduid) --删除好友关系
            skynet.call(".mysqlpool", "lua", "execute", sql)
            sql = string.format("delete from d_friend where uid = %d and friend_uid = %d", frienduid, uid)
            skynet.call(".mysqlpool", "lua", "execute", sql)
            sql = string.format("delete from d_chat_user where uid1 = %d and uid2 = %d", frienduid, uid) --删除聊天记录
            skynet.call(".mysqlpool", "lua", "execute", sql)
            sql = string.format("delete from d_chat_user where uid1 = %d and uid2 = %d", uid, frienduid)
            skynet.call(".mysqlpool", "lua", "execute", sql)

            local notify_msg = {c = PDEFINE.NOTIFY.FRIEND_ADDED, code=PDEFINE.RET.SUCCESS, uid = UID, act= 2}
            pcall(cluster.call, "master", ".userCenter", "syncLobbyInfo", frienduid, cjson.encode(notify_msg))
        end
    end

	local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, frienduids = frienduids, spcode=0}
	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 好友间，单个聊天记录
function cmd.sigleChatList(msg)
    local recvobj   = cjson.decode(msg)
    local frienduid = math.floor(recvobj.touid or 0)

    local sql= string.format("select * from d_chat_user where (uid1=%d and uid2=%d and del1=0) or (uid1=%d and uid2=%d and blocked=0 and del2=0) order by id desc limit 100", UID, frienduid, frienduid, UID)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, datalist={}}
    local userInfo = handle.moduleCall("player","getPlayerInfo", frienduid)
    retobj.friend = {
        uid = frienduid,
        playername = userInfo.playername,
        usericon = userInfo.usericon,
        avatarframe = userInfo.avatarframe,
        chatskin = userInfo.chatskin,
        frontskin = userInfo.frontskin,
        level = userInfo.level,
        vip = userInfo.svip,
        memo = userInfo.memo,
    }
    
    local playerInfo = handle.moduleCall("player","getPlayerInfo", UID)
    local data = {}
    local updateLists = {}
    for _, row in pairs(rs) do
        local content = cjson.decode(row.content)
        row.msg = content.msg
        row.type = content.type
        row.uid = row.uid1
        if row.uid2 == UID then
            table.insert(updateLists, row.id)
        end
        if tonumber(row.uid) == frienduid then
            row.playername = userInfo.playername
            row.usericon = userInfo.usericon
            row.avatarframe = userInfo.avatarframe
            row.levelexp = userInfo.levelexp or 0
            row.vip = userInfo.svip
            row.memo = userInfo.memo
            row.chatskin = userInfo.chatskin
            row.frontskin = userInfo.frontskin
        else
            row.playername = playerInfo.playername
            row.usericon = playerInfo.usericon
            row.avatarframe = playerInfo.avatarframe
            row.levelexp = playerInfo.levelexp or 0
            row.vip = playerInfo.svip
            row.memo = playerInfo.memo
            row.chatskin = playerInfo.chatskin
            row.frontskin = playerInfo.frontskin
        end
        row.uid2 = nil
        row.uid1 = nil
        row.content = nil
        row.md5 = nil
        table.insert(data, row)
    end
    retobj.datalist = data
    if #updateLists > 0 then
        local sql= string.format("update d_chat_user set unread=0 where id in (%s)", table.concat(updateLists, ", "))
        skynet.call(".mysqlpool", "lua", "execute", sql)
        handle.moduleCall("player","syncLobbyInfo", UID)
    end
    
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 加我为好友的请求列表
function cmd.addRequestList(msg)
    local recvobj   = cjson.decode(msg)
    local sql= string.format("select * from d_friend_request where frienduid=%d order by id desc", UID)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, datalist={}}
    local data = {}
    for _, row in pairs(rs) do
        local playerInfo = handle.moduleCall("player","getPlayerInfo", row.uid)
        row.playername = playerInfo.playername
        row.usericon = playerInfo.usericon
        row.vip = playerInfo.svip
        row.levelexp = playerInfo.levelexp or 0
        row.country = playerInfo.country
        row.avatarframe = playerInfo.avatarframe
        row.frienduid = row.uid
        table.insert(data, row)
    end
    retobj.datalist = data
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 审核通过加我为好友的请求
function cmd.procRequest(msg)
    local recvobj   = cjson.decode(msg)
    local frienduid = math.floor(recvobj.frienduid)
    local stype = math.floor(recvobj.type or 1) -- 1通过 2拒绝
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS}

    local sql= string.format("delete from d_friend_request where uid=%d and frienduid=%d", frienduid, UID)
    skynet.call(".mysqlpool", "lua", "execute", sql)

    
    if stype == 1 then
        do_redis({"sadd", "friends_uid:".. UID, frienduid})
        do_redis({"sadd", "friends_uid:".. frienduid, UID})
        addFriendSql(UID, frienduid)
        local isonline = 0
        local ok , online_list = pcall(cluster.call, "master", ".userCenter", "checkOnline", {frienduid})
        if ok and online_list[frienduid] ~= nil then
            isonline = 1
        end
        local userInfo = handle.moduleCall("player","getPlayerInfo", UID)
        local playerInfo = handle.moduleCall("player","getPlayerInfo", frienduid)
        retobj.friend = {
            uid = frienduid,
            coin = 0, --赠送的金币,
            present_time = 0,
            send = 0, --默认未赠送
            present_count = 0,
            levelexp = playerInfo.levelexp or 0,
            playername = playerInfo.playername or defaultPlayerName,
            usericon = playerInfo.usericon or defaultUserIcon,
            usercoin = playerInfo.coin,
            isonline = isonline,
        }
        if isonline == 1 then
            timeout(100, timeoutSendAddFriends, frienduid)
        end

        local ok, onlinelist = pcall(cluster.call, "master", ".userCenter", "checkOnline", {frienduid})
        if ok and nil ~= onlinelist and nil == onlinelist[frienduid] then
            skynet.send(".pushmsg", "lua", "send", frienduid, PDEFINE.PUSHMSG.FIVE, userInfo.playername)
        end
    else
        retobj.friend = {
            uid = frienduid,
        }
    end
    handle.moduleCall('player', 'syncLobbyInfo', UID)

    local notifyFunc = function ()
        local json_str = cjson.encode({c=270, uid= UID})
        local ok, json_notify = cmd.getList(json_str)
        handle.sendToClient(json_notify)
    end
    skynet.timeout(100, notifyFunc)
	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! vip修改最大好友数
function cmd.changeMaxCnt(total)
    handle.dcCall("user_data_dc","set_common_value", UID, PDEFINE.USERDATA.COMMON.FRIENDSMAX, total)
    MAX_FRIEND_COUNT = total
end
return cmd