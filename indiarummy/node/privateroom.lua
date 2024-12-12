local skynet = require "skynet"
local cluster = require "cluster"
local cjson   = require "cjson"
local player_tool = require "base.player_tool"

cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local handle
local UID
local CMD = {}

--成功返回
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

function CMD.bind(agent_handle)
	handle = agent_handle
end

function CMD.initUid(uid)
    UID = uid
end

function CMD.init(uid)
    UID = uid
end

-- 创建私人房
function CMD.createRoom(msg)
    local recvobj   = cjson.decode(msg)
    handle.addStatistics(UID, 'entergame', 'salon', recvobj.gameid)
    local ok, res, retobj = pcall(cluster.call, "master", ".balprivateroommgr", "createRoom", recvobj)
    if ok then  -- 不需要发送43协议，因为房主不需要加入房间
        skynet.timeout(50, function ()
            handle.moduleCall("player", "syncLobbyInfo", UID)
        end)
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

-- 加入私人房
function CMD.joinRoom(msg)
    local recvobj   = cjson.decode(msg)
    local gameid = recvobj.gameid
    handle.addStatistics(UID, 'entergame', 'salon', gameid)
    local ok, res, retobj, deskAddr = pcall(cluster.call, "master", ".balprivateroommgr", "joinRoom", recvobj)
    if ok then
        if retobj then
            handle.sendToClient(cjson.encode(retobj))
        end
        return PDEFINE.RET.SUCCESS, cjson.encode(res),deskAddr
    else
        return PDEFINE.RET.SUCCESS, cjson.encode(res),deskAddr
    end
end

-- 查询私人房对应的游戏id
function CMD.queryGame(msg)
    local recvobj   = cjson.decode(msg)
    local ok, res = pcall(cluster.call, "master", ".balprivateroommgr", "queryGameByRoomid", recvobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(res)
end

--! 快速坐下
function CMD.seatRoom(msg)
    local recvobj   = cjson.decode(msg)
    local uid = math.floor(recvobj.uid or 0)
    local gameid = math.floor(recvobj.gameid or 0)
    handle.addStatistics(UID, 'entergame', 'salon', gameid)
    local ok, res, retobj,deskAddr = pcall(cluster.call, "master", ".balprivateroommgr", "seatRoom", recvobj)
    if ok and retobj then
        handle.addStatistics(uid, 'quickstart', '0')
        handle.sendToClient(cjson.encode(retobj))
        return PDEFINE.RET.SUCCESS, cjson.encode(res),deskAddr
    else
        if res then
            handle.addStatistics(uid, 'quickstart', '2')
            return resp(res)
        else
            handle.addStatistics(uid, 'quickstart', '1')
            local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, spcode = 0}
            ret.spcode = 1 -- 调用错误
            return resp(ret)
        end
    end
end

-- 邀请好友
function CMD.inviteFriend(msg)
    local recvobj   = cjson.decode(msg)
    local ok, res = pcall(cluster.call, "master", ".balprivateroommgr", "inviteFriend", recvobj)
    if ok then
        return resp(res)
    else
        local ret = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, spcode = 0}
        ret.spcode = 1 -- 调用错误
        return resp(ret)
    end
end

-- 解散房间
function CMD.dismissRoom(msg)
    local recvobj   = cjson.decode(msg)
    local deskid = recvobj.deskid
    local gameid = recvobj.gameid
    local uid = math.floor(recvobj.uid)
    local retobj = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, spcode = 0, deskid=deskid, gameid=gameid}
    if not deskid or not gameid then
        retobj.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return resp(retobj)
    end
    local ok, errCode = pcall(cluster.call, "master", ".balprivateroommgr", "dismissRoom", deskid, gameid, uid)
    if ok then
        if errCode == PDEFINE.RET.SUCCESS then
            local cacheKey = string.format('invite:%d:%d', gameid, deskid)
            do_redis({"del", cacheKey})
            return resp(retobj)
        else
            retobj.spcode = errCode
            return resp(retobj)
        end
    else
        retobj.spcode = PDEFINE.RET.ERROR.CALL_FAIL
        return resp(retobj)
    end
end

-- 获取用户房间收益记录表
function CMD.incomeRecode(msg)
    local recvobj   = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local retobj = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, spcode = 0, data={}, income={}}
    local limit = recvobj.limit and math.floor(recvobj.limit) or 50
    local sql = string.format("select * from d_private_room_income where owner=%d order by id desc limit %d", uid, limit)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if rs and #rs > 0 then
        for _, result in ipairs(rs) do
            table.insert(retobj.data, {
                result['deskid'],
                result['gameid'],
                result['income'],
                result['exp'],
                result['create_time'],
            })
        end
    end
    -- 总览情况
    local redisKey = PDEFINE.REDISKEY.OTHER.private_room_reward..uid
    local rewardInfo = do_redis({"hgetall", redisKey})
    if not rewardInfo or table.empty(rewardInfo) then
        rewardInfo = {coin=0, round=0, exp=0}
    else
        rewardInfo = make_pairs_table_int(rewardInfo)
    end
    retobj.income = {
        coin = rewardInfo.coin,
        round = rewardInfo.round,
        exp = rewardInfo.exp or 0
    }
    return resp(retobj)
end

--! 手动获取收益
function CMD.getIncome(msg)
    local recvobj   = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local retobj = {c=recvobj.c, code = PDEFINE.RET.SUCCESS, spcode = 0}
    -- 总览情况
    local redisKey = PDEFINE.REDISKEY.OTHER.private_room_reward..uid
    local rewardInfo = do_redis({"hgetall", redisKey})
    if not rewardInfo or table.empty(rewardInfo) then
        rewardInfo = {coin=0, round=0, exp=0}
    else
        rewardInfo = make_pairs_table_int(rewardInfo)
    end
    retobj.rewards = {}
    if rewardInfo.coin > 0 then
        do_redis({"hset", redisKey, "coin", 0})
        table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN, count=rewardInfo.coin})
        do_redis({"hgetall", redisKey})
        local code, _, _ = player_tool.funcAddCoin(uid, rewardInfo.coin, "房间抽成", PDEFINE.ALTERCOINTAG.PRIVATE_ROOM_COIN, PDEFINE.GAME_TYPE.SPECIAL.PRIVATE_ROOM_COIN, PDEFINE.POOL_TYPE.none, nil, nil)
        if code ~= PDEFINE.RET.SUCCESS then
            LOG_ERROR("房间抽水失败: insertSql uid:", uid, ' coin:', rewardInfo.coin)
        end

        local orderid = os.date("%Y%m%d%H%M%S", os.time()) .. payId()
        local title = "沙龙房税收:" .. rewardInfo.coin
        handle.moduleCall("player","addBonusLog", orderid, title, rewardInfo.coin, os.time(), PDEFINE.TYPE.SOURCE.Salon, uid, 0)

        local playerInfo = player_tool.getPlayerInfo(uid)
        handle.notifyCoinChanged(playerInfo.coin, playerInfo.diamond, rewardInfo.coin, 0)

        handle.moduleCall("player","syncLobbyInfo", UID)
    end
    if rewardInfo.exp > 0 then
        do_redis({"hset", redisKey, "exp", 0})
        do_redis({"hset", redisKey, "round", 0})
        handle.moduleCall("upgrade", "bet", 0, rewardInfo.exp, nil)
    end
    return resp(retobj)
end

-- 获取可领取的红点
function CMD.getIncomeDot(uid)
    local redisKey = PDEFINE.REDISKEY.OTHER.private_room_reward..uid
    local rewardInfo = do_redis({"hgetall", redisKey})
    if not rewardInfo or table.empty(rewardInfo) then
        return 0
    else
        rewardInfo = make_pairs_table_int(rewardInfo)
        if rewardInfo.coin > 0 then
            return 1
        end
    end
    return 0
end

return CMD