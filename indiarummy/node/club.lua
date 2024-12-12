local skynet = require "skynet"
local cluster = require "cluster"
local cjson   = require "cjson"
local date = require "date"
local queue = require "skynet.queue"
local player_tool = require "base.player_tool"
local clubCfg = require "config.clubCfg"
local clubDb = require "base.club_db"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local cs = queue()
local club = {}
local handle
local act = "club"

local UID
local CID  -- 俱乐部号


local ApplyListRedisKey = "club:apply:list:"
local ApplySingleRedisKey = "club:apply:uid:"
local ClubSignRedisKey = "club:sign:"
local LastChatTimeRedisKey = "club:chat:last_time:"

local ApplyExpireTime = 7*24*60*60
local SignInScore = 5  -- 签到积分
local CompleteGameScore = 1  -- 完成一局游戏积分
local ChatScore = 5  -- 每天第一次发言
local MaxChatLen = 50 -- 保存的最长聊天条数

--成功返回
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 获取今日过期延迟
local function getTodayExpireTime()
    local now = os.time()
    local expireTime = date.GetTodayZeroTime(now)+24*60*60
    return expireTime-now
end

function club.bind(agent_handle)
	handle = agent_handle
end

function club.initUid(uid)
    UID = uid
end

function club.init(uid)
    UID = uid
    local club = clubDb.getClubByUid(uid)
    if club then
        CID = club.cid
    end
end


local function getClubResp(clubInfo)
    return {
        c_level = clubInfo.level,  -- 玩家在当前俱乐部中的等级
        cid = clubInfo.cid,
        name = clubInfo.name,
        avatar = clubInfo.avatar,
        create_time = clubInfo.create_time,
        detail = clubInfo.detail,
        cap = clubInfo.cap,
        cnt = clubInfo.member_cnt,
        join_type = clubInfo.join_type,
        score = clubInfo.score
    }
end

-- 获取推荐俱乐部
function club.getRecommendList(msg)
    local recvobj   = cjson.decode(msg)
    local limit     = math.floor(recvobj.limit)  -- 获取推荐俱乐部数量
    local name      = recvobj.name  -- 名称关键词
    if name then
        name = string.trim(name)
    end
    if not limit then
        limit = 10
    end
    local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, clubs = {}}
    local clubList = clubDb.getRandClubList(limit, name)
    -- 记录自己申请的俱乐部
    local apply_single_redis_key = string.format("%s%d", ApplySingleRedisKey, UID)
    local applyList = do_redis({"zrange", apply_single_redis_key, 0, -1})
    for _, c in ipairs(clubList) do
        local club = getClubResp(c)
        if table.contain(applyList, tostring(club.cid)) then
            club.is_apply = 1
        else
            club.is_apply = 0
        end
        table.insert(ret.clubs, club)
    end
    return resp(ret)
end

-- 获取当前赛季
local function getCurrSeason()
    local now = os.time()
    for _, season in ipairs(clubCfg.SeasonCfg) do
        if season.begin <= now and season.stop > now then
            return season
        end
    end
    return nil
end

-- 获取俱乐部排名
function club.getRankList(msg)
    local recvobj   = cjson.decode(msg)
    local limit     = math.floor(recvobj.limit)  -- 获取俱乐部数量
    local page      = math.floor(recvobj.page)  -- 获取页数
    if not limit then
        limit = 10
    end
    if not page then
        page = 1
    end
    local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, page=page, limit=limit, clubs = {}}
    local clubList = clubDb.getScoreRank(page, limit)
    for _, c in ipairs(clubList) do
        table.insert(ret.clubs, getClubResp(c))
    end
    -- 获取赛季结束时间
    local redis_key = PDEFINE.REDISKEY.CLUB.SEASON.STOP
    local stop_time = do_redis({"get", redis_key})
    ret.stop = stop_time and tonumber(stop_time) or 0
    return resp(ret)
end

-- 创建一个俱乐部
function club.create(msg)
    local recvobj   = cjson.decode(msg)
    local name      = recvobj.name
    local avatar    = recvobj.avatar or ""
    local detail    = recvobj.detail
    local cap       = math.floor(recvobj.cap)
    local join_type     = math.floor(recvobj.join_type)
    local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, club = nil}
    if join_type ~= clubCfg.ClubType.Apply 
    and join_type ~= clubCfg.ClubType.Forbid 
    and join_type ~= clubCfg.ClubType.Direct then
        ret.spcode = 1
        return resp(ret)
    end
    local cid = skynet.call(".clubidmgr", "lua", "genClubId")
    if not cid then
        ret.spcode = 2
        return resp(ret)
    end
    local result = clubDb.createClub(cid, UID, name, avatar, detail, join_type, cap)
    if not result then
        ret.spcode = 3
        LOG_ERROR("创建俱乐部失败 cid: ", cid)
        return resp(ret)
    end
    -- 自己也需要加入俱乐部
    clubDb.joinClub(cid, UID, clubCfg.ClubMemberLevel.Owner)
    local clubInfo = clubDb.getClubById(cid)
    ret.club = getClubResp(clubInfo)
    ret.c_level = clubCfg.ClubMemberLevel.Owner
    return resp(ret)
end

-- 修改俱乐部
function club.modifyClub(msg)
    local recvobj   = cjson.decode(msg)
    local cid       = math.floor(recvobj.cid)
    local name      = recvobj.name
    local avatar    = recvobj.avatar
    local detail    = recvobj.detail
    local cap       = recvobj.cap
    if cap then
        cap = math.floor(cap)
    end
    local join_type     = recvobj.join_type
    if join_type then
        join_type = math.floor(join_type)
    end
    local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, club = nil}
    local clubInfo = clubDb.getClubById(cid)
    if not clubInfo or table.empty(clubInfo) then
        ret.spcode = 2  -- 找不到该俱乐部
        return resp(ret)
    end
    if cap and clubInfo.member_cnt > cap then
        ret.spcode = 4  -- 俱乐部人数已超过容量
        return resp(ret)
    end
    local result = clubDb.modifyClub(cid, name, avatar, detail, join_type, cap)
    if not result then
        ret.spcode = 3  -- 修改异常
        LOG_ERROR("修改俱乐部失败")
        return resp(ret)
    end
    local clubInfo = clubDb.getClubById(cid)
    ret.club = getClubResp(clubInfo)
    return resp(ret)
end

-- 获取单个俱乐部详情
function club.getInfo(msg)
    local recvobj   = cjson.decode(msg)
    local cid       = math.floor(recvobj.cid)
    local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, club = nil}
    if not cid then
        ret.spcode = 1
        return resp(ret)
    end
    local clubInfo = clubDb.getClubById(cid)
    ret.club = getClubResp(clubInfo)
    local selfClub = clubDb.getClubByUid(UID)
    if selfClub and selfClub.cid == clubInfo.cid then
        ret.club.is_join = 1
        -- 是否签到
        local redisKey = ClubSignRedisKey..UID
        local isSignIn = do_redis({'get', redisKey})
        if isSignIn then
            ret.club.is_sign_in = 1
        else
            ret.club.is_sign_in = 0
        end
    else
        ret.club.is_join = 0
        -- 是否申请
        local apply_single_redis_key = string.format("%s%d", ApplySingleRedisKey, UID)
        local isApply = do_redis({"zscore", apply_single_redis_key, cid})
        if isApply then
            ret.club.is_apply = 1
        else
            ret.club.is_apply = 0
        end
    end
    return resp(ret)
end

-- 申请加入一个俱乐部
-- 申请列表非重要数据，放到redis中
function club.apply(msg)
    local recvobj   = cjson.decode(msg)
    local cid       = math.floor(recvobj.cid)
    local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, spcode = 0, cid=cid}
    local clubInfo = clubDb.getClubById(cid)
    if not clubInfo then
        ret.spcode = 1  -- 找不到该俱乐部
        return resp(ret)
    end
    if clubInfo.member_cnt >= clubInfo.cap then
        ret.spcode = 2  -- 人数已满
        return resp(ret)
    end
    -- 如果可以直接加入
    if clubInfo.join_type == clubCfg.ClubType.Direct then
        clubDb.joinClub(cid, UID, clubCfg.ClubMemberLevel.Common)
        ret.club = getClubResp(clubInfo)  -- 如果直接加入了，则需要返回club信息
        ret.club.c_level = clubCfg.ClubMemberLevel.Common
        return resp(ret)
    end
    -- 如果俱乐部是禁止加入状态
    if clubInfo.join_type == clubCfg.ClubType.Forbid then
        ret.spcode = 3  -- 禁止加入
        return resp(ret)
    end
    -- 如果俱乐部是申请加入状态
    if clubInfo.join_type == clubCfg.ClubType.Apply then
        local apply_list_redis_key = string.format("%s%d", ApplyListRedisKey, cid)
        do_redis({"zadd", apply_list_redis_key, os.time(), UID})
        -- 记录自己申请的俱乐部
        local apply_single_redis_key = string.format("%s%d", ApplySingleRedisKey, UID)
        do_redis({"zadd", apply_single_redis_key, os.time(), cid})

        -- 通知管理员
        local managers = clubDb.getClubManager(clubInfo.cid, clubCfg.ClubMemberLevel.Owner)
        for _, _rs in ipairs(managers) do
            pcall(cluster.send, "master", ".userCenter", "syncLobbyInfo", _rs['uid'])
        end
    end
    return resp(ret)
end

-- 获取申请列表
function club.applyList(msg)
    local recvobj   = cjson.decode(msg)
    local cid       = math.floor(recvobj.cid)
    local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, spcode = 0, cid=cid}
    local clubInfo = clubDb.getClubById(cid)
    if not clubInfo then
        ret.spcode = 1 -- 找不到该俱乐部
        return resp(ret)
    end
    if clubInfo.uid ~= UID then
        ret.spcode = 2 -- 无权限操作
        return resp(ret)
    end
    local apply_list_redis_key = string.format("%s%d", ApplyListRedisKey, cid)
    local src_data = do_redis({"zrevrangebyscore", apply_list_redis_key, -1, 1})
    LOG_DEBUG("zrevrangebyscore: ", apply_list_redis_key, "src_data: ", src_data )
    if #src_data == 0 then
        ret.apply_list = {}
        return resp(ret)
    end
    local apply_list = {}
    for i = 1, #src_data, 2 do
        local uid = tonumber(src_data[i])
        local apply_time = tonumber(src_data[i+1])
        if apply_time + ApplyExpireTime < os.time() then
            do_redis({"zrem", apply_list_redis_key, uid})
        else
            local playerInfo = player_tool.getPlayerInfo(uid)
            table.insert(apply_list, {
                apply_time = tonumber(src_data[i+1]),
                uid  = uid,
                name = playerInfo.playername,
                level = playerInfo.level,
                avatar = playerInfo.usericon,
                avatarframe = playerInfo.avatarframe or 0,
                vip = playerInfo.svip or 0,
            })
        end
    end
    ret.apply_list = apply_list
    return resp(ret)
end

-- 审核申请
function club.handleApply(msg)
    local recvobj   = cjson.decode(msg)
    local cid       = math.floor(recvobj.cid)
    local apply_uid       = math.floor(recvobj.apply_uid)
    local rtype     = math.floor(recvobj.rtype)  -- 是否通过, 0=不通过, 1=通过
    local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, spcode = 0, apply_uid=apply_uid, rtype=rtype}
    local clubInfo = clubDb.getClubById(cid)
    if not clubInfo then
        ret.spcode = 1 -- 找不到该俱乐部
        return resp(ret)
    end
    if clubInfo.uid ~= UID then
        ret.spcode = 2 -- 无权限操作
        return resp(ret)
    end
    local apply_list_redis_key = string.format("%s%d", ApplyListRedisKey, cid)
    local apply_time = do_redis({"zscore", apply_list_redis_key, apply_uid})

    local apply_single_redis_key = string.format("%s%d", ApplySingleRedisKey, apply_uid)
    -- 删除申请记录, 不管失败与否，都要清理掉
    do_redis({"zrem", apply_list_redis_key, apply_uid})
    do_redis({"zrem", apply_single_redis_key, cid})
    -- 同步小红点
    handle.moduleCall('player', 'syncLobbyInfo', UID)
    if not apply_time then
        ret.spcode = 3 -- 该用户没有申请
        return resp(ret)
    end
    apply_time = tonumber(apply_time)
    if apply_time + ApplyExpireTime < os.time() then
        ret.spcode = 4  -- 审核已经过期
        return resp(ret)
    end
    if rtype == 1 then
        -- 检测该用户是否有俱乐部
        local _r = clubDb.getClubByUid(apply_uid)
        if _r and not table.empty(_r) then
            ret.spcode = 5 -- 用户已加入其它俱乐部
            return resp(ret)
        end
        if clubInfo.member_cnt >= clubInfo.cap then
            ret.spcode = 7 -- 俱乐部已满
            return resp(ret)
        end
        -- 开始加入
        local result = clubDb.joinClub(cid, apply_uid, clubCfg.ClubMemberLevel.Common)
        if not result then
            ret.spcode = 6 -- 加入异常
            return resp(ret)
        end
        -- 通知用户
        local notify_retobj = {
            c = PDEFINE.NOTIFY.NOTIFY_CLUB_JOIN,
            code = PDEFINE.RET.SUCCESS,
            uid = apply_uid,
            rtype=rtype,
            club = getClubResp(clubInfo)
        }
        notify_retobj.club.c_level = clubCfg.ClubMemberLevel.Common
        pcall(cluster.send, "master", ".userCenter", "pushInfoByUid", apply_uid, cjson.encode(notify_retobj))
    end

    return resp(ret)
end

-- 剔除一个用户
function club.deleteFromClub(msg)
    local recvobj   = cjson.decode(msg)
    local cid       = math.floor(recvobj.cid)
    local del_uid       = math.floor(recvobj.del_uid)
    local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, spcode = 0, del_uid=del_uid}
    local clubInfo = clubDb.getClubById(cid)
    if not clubInfo then
        ret.spcode = 1 -- 找不到该俱乐部
        return resp(ret)
    end
    if clubInfo.uid ~= UID then
        ret.spcode = 2 -- 无权限操作
        return resp(ret)
    end
    -- 检测该用户是否有俱乐部
    local _r = clubDb.getClubByUid(del_uid)
    if not _r or table.empty(_r) then
        ret.spcode = 3 -- 用户不在俱乐部中
        return resp(ret)
    end
    local result = clubDb.deleteFromClub(cid, del_uid)
    if not result then
        ret.spcode = 4  -- 删除失败
        return resp(ret)
    end
    -- 通知用户
    local notify_retobj = {
        c = PDEFINE.NOTIFY.NOTIFY_CLUB_REMOVE,
        code = PDEFINE.RET.SUCCESS,
        del_uid = del_uid,
        club = getClubResp(clubInfo)
    }
    pcall(cluster.send, "master", ".userCenter", "pushInfoByUid", del_uid, cjson.encode(notify_retobj))
    return resp(ret)
end

-- 获取俱乐部成员列表
function club.fetchMember(msg)
    local recvobj   = cjson.decode(msg)
    local cid       = math.floor(recvobj.cid)
    local page      = math.floor(recvobj.page)
    local limit     = math.floor(recvobj.limit)
    local name      = recvobj.name
    if name then
        name = string.trim(name)
    end
    if not limit then
        limit = 20
    end
    if not page then
        page = 1
    end
    local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, spcode = 0, page=page, limit=limit, members={}}
    local clubInfo = clubDb.getClubById(cid)
    if not clubInfo then
        ret.spcode = 1 -- 找不到该俱乐部
        return resp(ret)
    end
    local members = clubDb.getClubMember(cid, name, page, limit)
    for _, member in ipairs(members) do
        local playerInfo = player_tool.getPlayerInfo(member.uid)
        table.insert(ret.members, {
            c_level = member.level,
            join_time = member.join_time,
            score = member.score,
            uid = member.uid,
            name = playerInfo.playername,
            level = playerInfo.level,
            avatar = playerInfo.usericon,
            avatarframe = playerInfo.avatarframe or 0,
            vip = playerInfo.svip or 0,
        })
    end
    return resp(ret)
end

-- 俱乐部签到
-- 存在redis中
function club.signIn(msg)
    local recvobj   = cjson.decode(msg)
    local cid       = math.floor(recvobj.cid)
    local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, spcode = 0, members={}}
    local clubInfo = clubDb.getClubByUid(UID)
    if not clubInfo or table.empty(clubInfo) then
        ret.spcode = 1 -- 未加入俱乐部
        return resp(ret)
    end
    if clubInfo.cid ~= cid then
        ret.spcode = 2  -- 不是自己的俱乐部
        return resp(ret)
    end
    local redisKey = ClubSignRedisKey..UID
    local isSignIn = do_redis({'get', redisKey})
    if isSignIn then
        ret.spcode = 3 -- 今天已经签到
        return resp(ret)
    end
    local expireTime = getTodayExpireTime()
    do_redis({'setex', redisKey, 1, expireTime})
    clubInfo.score = clubInfo.score + SignInScore
    clubDb.increaseScore(cid, UID, SignInScore)
    ret.club = getClubResp(clubInfo)
    return resp(ret)
end

-- 退出俱乐部
function club.exitClub(msg)
    local recvobj   = cjson.decode(msg)
    local cid       = math.floor(recvobj.cid)
    local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, spcode = 0, members={}}
    local clubInfo = clubDb.getClubByUid(UID)
    if not clubInfo or table.empty(clubInfo) then
        ret.spcode = 1 -- 未加入俱乐部
        return resp(ret)
    end
    if clubInfo.cid ~= cid then
        ret.spcode = 2  -- 不是自己的俱乐部
        return resp(ret)
    end
    if clubInfo.uid == UID then
        local members = clubDb.getClubAllUid(cid)
        local result = clubDb.deleteClub(cid, UID)
        if not result then
            ret.spcode = 3  -- 退出失败
            return resp(ret)
        end
        -- 广播给俱乐部所有人，俱乐部已经解散了
        -- 通知用户
        local notify_retobj = {
            c = PDEFINE.NOTIFY.NOTIFY_CLUB_REMOVE,
            code = PDEFINE.RET.SUCCESS,
            cid = cid,
        }
        local uids = {}
        for _, u in ipairs(members) do
            table.insert(uids, u.uid)
        end
        pcall(cluster.send, "master", ".userCenter", "pushInfoByUids", uids, cjson.encode(notify_retobj))
    else
        local result = clubDb.deleteFromClub(cid, UID)
        if not result then
            ret.spcode = 3  -- 退出失败
            return resp(ret)
        end
    end
    return resp(ret)
end

-- 获取俱乐部房间
function club.getRoomList(msg)
    local recvobj   = cjson.decode(msg)
    local cid       = math.floor(recvobj.cid)
    local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, cid=cid, spcode = 0, rooms={}}
    local clubInfo = clubDb.getClubById(cid)
    local ok, roomList = pcall(cluster.call, "master", ".balclubroommgr", "getRoomList", UID, cid)
    ret.rooms = roomList
    return resp(ret)
end

-- 创建俱乐部房间
function club.createRoom(msg)
    local recvobj   = cjson.decode(msg)
    local ok, res, retobj = pcall(cluster.call, "master", ".balclubroommgr", "createRoom", recvobj)
    if ok and retobj then
        retobj.c = 43
        retobj.code = PDEFINE.RET.SUCCESS
        handle.sendToClient(cjson.encode(retobj))
        return resp(res)
    else
        if res then
            return resp(res)
        else
            local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, spcode = 0}
            ret.spcode = 1 -- 调用错误
            return resp(ret)
        end
    end
end

-- 邀请加入俱乐部游戏
function club.inviteFriend(msg)
    local recvobj   = cjson.decode(msg)
    local ok, res = pcall(cluster.call, "master", ".balclubroommgr", "inviteFriend", recvobj)
    if ok then
        return resp(res)
    else
        local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, spcode = 0}
        ret.spcode = 1 -- 调用错误
        return resp(ret)
    end
end

-- 加入俱乐部房间
function club.joinRoom(msg)
    local recvobj   = cjson.decode(msg)
    local ok, res, retobj = pcall(cluster.call, "master", ".balclubroommgr", "joinRoom", recvobj)
    if ok then
        if retobj then
            handle.sendToClient(cjson.encode(retobj))
        end
        return resp(res)
    else
        return resp(res)
    end
end

-- 获取个人俱乐部信息
function club.findClubByUid(uid)
    local clubInfo = clubDb.getClubByUid(uid)
    if not clubInfo or table.empty(clubInfo) then
        return nil
    end
    local clubRep = getClubResp(clubInfo)
    -- 是否签到
    local redisKey = ClubSignRedisKey..UID
    local isSignIn = do_redis({'get', redisKey})
    if isSignIn then
        clubRep.is_sign_in = 1
    else
        clubRep.is_sign_in = 0
    end
    return clubRep
end

-- 完成一局俱乐部游戏
function club.completeGame(uid)
    local clubInfo = clubDb.getClubByUid(uid)
    clubDb.increaseScore(clubInfo.cid, UID, CompleteGameScore)
    -- 完成一局游戏有积分赠送
end

-- 发送俱乐部聊天消息
function club.chat()
    local redis_key = LastChatTimeRedisKey..UID
    local hasChat = do_redis({'get', redis_key})
    if not hasChat then
        local clubInfo = clubDb.getClubByUid(UID)
        if not clubInfo then
            return nil
        end
        clubDb.increaseScore(clubInfo.cid, UID, ChatScore)
        local expireTime = getTodayExpireTime()
        do_redis({'setex', redis_key, 1, expireTime})
        return ChatScore
    end
    return nil
end

-- 同步红点信息
function club.syncStatus(uid)
    local clubInfo = clubDb.getClubByUid(uid)
    if clubInfo and clubInfo.level == clubCfg.ClubMemberLevel.Owner then
        local apply_list_redis_key = string.format("%s%d", ApplyListRedisKey, clubInfo.cid)
        local cnt = do_redis({"zcard", apply_list_redis_key})
        if cnt > 0 then
            return cnt
        end
    end
    return 0
end

return club