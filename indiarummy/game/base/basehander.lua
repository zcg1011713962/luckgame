-- 房间里面通用消息的处理
local baseHander = {}

local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local roomfactory = require "base.roomfactory"
local create_user = roomfactory.create_user
local getBrokenTimes = roomfactory.getBrokenTimes
local create_desk = roomfactory.create_desk

function baseHander.create(cluster_info, recvobj, ip, deskid, create)
    LOG_INFO("----------创建房间：------------", recvobj)
    local uid = math.floor(recvobj.uid)
    local ssid = math.floor(recvobj.ssid or 0)
    local free = recvobj.free or 0 --体验场 free = 1 其他场次 free = 0
    local joinScore = math.floor(recvobj.mincoin or 0) -- 进入房间
    --计算够不够进房间门槛
    local playerInfo = cluster.call(cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid)
    if not playerInfo then
        return PDEFINE.RET.ERROR.SEATID_EXIST
    end
    local gameid = recvobj.gameid
    if free == 0 then
        local cachekey = getBrokenTimes(uid, gameid)
        local brokentimes = do_redis({"get", cachekey})
        if brokentimes then
            local mincoin = joinScore * tonumber(brokentimes) * 2
            if playerInfo.coin < mincoin then
                --破产次数过多，门槛金币 =   初始门槛金币 * 破产次数 * 10
                local retobj = {times=brokentimes, mincoin=mincoin}
                return PDEFINE.RET.ERROR.ERROR_BROKEN_TIMES, retobj
            end
        else
            if playerInfo.coin < joinScore then
                return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
            end
        end
    end
    local deskobj = create_desk(recvobj, ip, deskid)
    deskobj.conf.free = free --是否是免费场次
    deskobj.conf.joinScore = joinScore --门槛金币
    local user = create_user(deskobj, cluster_info, recvobj, playerInfo, ip)

    return PDEFINE.RET.SUCCESS, deskobj, user
end

function baseHander.join(deskobj, cluster_info, recvobj, ip)
    local uid = math.floor(recvobj.uid)
    local deskid = recvobj.deskid
    local ouser =  deskobj:select_userinfo(uid)
    if ouser then
         return PDEFINE.RET.ERROR.PLAYER_EXISTS_DESK
    end
    local playerInfo = cluster.call(cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid)
    if not playerInfo then
        return PDEFINE.RET.ERROR.SEATID_EXIST
    end
    local deskid = recvobj.deskid
    
    if tonumber(deskid) ~= tonumber(deskobj.deskid) then
        return PDEFINE.RET.ERROR.DESKID_FAIL
    end
    
    local gameid = recvobj.gameid or 0
    --判断房费
    -- print("-----------玩家加入房间-----------:", uid,  deskobj)
    LOG_DEBUG("玩家金币:",playerInfo.coin, " VS 加入门槛：", deskobj.conf.joinScore)
    if deskobj.conf.free == 0 then
        local cachekey    = getBrokenTimes(uid, gameid)
        local brokentimes = do_redis({"get", cachekey})
        if brokentimes then
            local mincoin = deskobj.conf.joinScore * tonumber(brokentimes) * 10
            if playerInfo.coin < mincoin then
                --破产次数过多，门槛金币 =   厨师门槛金币 * 破产次数 * 10
                local retobj = {times=brokentimes, mincoin=mincoin}
                return PDEFINE.RET.ERROR.ERROR_BROKEN_TIMES, retobj
            end
        else
            if playerInfo.coin < deskobj.conf.joinScore then
                return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
            end
        end
    end
    local user = create_user(deskobj, cluster_info, recvobj, playerInfo, ip)

    return PDEFINE.RET.SUCCESS, user
end

-- 准备游戏
function baseHander.ready(deskobj, recvobj)
    local uid = math.floor(recvobj.uid)
    local user =  deskobj:select_userinfo(uid)
    if not user.isSitdown then
        return 401 -- 玩家需要坐下
    end
    if deskobj.state ~= 0 then
        return 402
    end
    if user.state == 1 then -- 重复准备
        return 922
    end
    local is_ready = recvobj.ready
    if is_ready == nil then
        is_ready = true
    end
    user.state = 1 -- 准备
    if is_ready then
        if user.coin < deskobj.mincoin then -- 金币不足
            return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        end
        user:stop_action('KICK_USER') -- 停止T人
        user:stop_action('READY_USER')
    end
    user.is_ready = is_ready
    local retobj    = {}
    retobj.code     = PDEFINE.RET.SUCCESS
    retobj.c        = recvobj.c
    retobj.uid      = uid
    recvobj.ready   = is_ready
    -- retobj.seatid   = user.seatid
    deskobj:broadcastdesk(retobj, uid)
    return PDEFINE.RET.SUCCESS, retobj
end

function baseHander.auto(deskobj, recvobj)
    local uid = math.floor(recvobj.uid)
    local user, idx =  deskobj:select_userinfo(uid)
    local is_auto = recvobj.is_auto
    if is_auto ~= user.is_auto then
        user.is_auto = is_auto
        if is_auto then
            if user.auto_fun then
                user:auto_action('AUTO_SELECT', 0.5, function()
                    local fun = user.auto_fun
                    user.auto_fun = nil
                    if fun then fun() end
                end)
            end
        else
            user:stop_action('AUTO_SELECT')
        end
        local retobj = {
            c = PDEFINE.NOTIFY.MLMJ_AUTO,
            uid = user.uid,
            is_auto = is_auto,
        }
        deskobj:broadcastdesk(retobj)--
    end
    return PDEFINE.RET.SUCCESS
end

function baseHander.exitG(deskobj, recvobj)
    local uid     = math.floor(recvobj.uid)
    local exUser  =  deskobj:select_userinfo(uid)
    if not exUser then
        return PDEFINE.RET.SUCCESS
    end

    local retobj = {}
    retobj.c     = PDEFINE.NOTIFY.exit
    retobj.code  = PDEFINE.RET.SUCCESS
    retobj.uid   = uid
    retobj.seatid = exUser.seatid
    deskobj:broadcastdesk(retobj, uid)
    deskobj:delUserFromDesk(uid)
    return PDEFINE.RET.SUCCESS
end

return baseHander