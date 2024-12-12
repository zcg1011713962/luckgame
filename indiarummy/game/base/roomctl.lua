
local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local CMD = {}

function CMD.apiKickDesk(deskobj)

    --踢掉
    local  gameid = deskobj.gameid
    for _, muser in pairs(deskobj.users) do
        if muser.cluster_info and muser.isExit == 0 then
            pcall(cluster.call, muser.cluster_info.server, muser.cluster_info.address, "deskBack", gameid) --释放桌子对象
        end
    end
    for _, vuser in pairs(deskobj.vistor_users) do
        if vuser.cluster_info and vuser.isExit == 0 then
            pcall(cluster.call, vuser.cluster_info.server, vuser.cluster_info.address, "deskBack", gameid) --释放桌子对象
        end
    end

    local retobj = {c = PDEFINE.NOTIFY.ALL_GET_OUT, code = PDEFINE.RET.SUCCESS, roomtype = deskobj.roomtype}
    deskobj:broadcastdeskAll(retobj)
    for _, user in ipairs(deskobj.users) do
        deskobj:delUserFromDesk(user.uid)
    end
    for _, user in ipairs(deskobj.vistor_users) do
        deskobj:delUserFromDesk(user.uid)
    end

end

-------- API更新桌子里玩家的金币 --------
function CMD.addCoinInGame(deskobj, uid, coin)
    local user, _ = deskobj:select_userinfo(uid)
    if nil ~= user then 
        user.coin = user.coin + coin
    end
end

function CMD.broadcastCoinDeskAll(deskobj, uid, deskid, count, coin)
    local retobj  = {}
    retobj.c      = PDEFINE.NOTIFY.coin
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.uid    = uid
    retobj.deskid = deskid
    retobj.count  = count
    retobj.coin   = pcoin
    retobj.type   = 1
    deskobj:broadcastdeskAll(retobj)

    return PDEFINE.RET.SUCCESS
end

--用户在线离线
function CMD.ofline(deskobj, ofline, uid)
    local user = deskobj:select_userinfo(uid)
    if user then
        user.ofline = ofline
        if ofline == 1 and user.of_count then
            user.of_count = 0
            -- print("---off user:", user)
        end
        local retobj = {}
        retobj.c = PDEFINE.NOTIFY.NOTIFY_ONLINE
        retobj.code = PDEFINE.RET.SUCCESS
        retobj.ofline = ofline
        retobj.seatid = user.seatid
        deskobj:broadcastdesk(retobj, uid)
        -- TODO 这里是不是需要托管
    end
end

--更新玩家的桌子信息
function CMD.updateUserClusterInfo(deskobj, uid, agent)
    uid = math.floor(uid)
    local user = deskobj:select_userinfo(uid)
    if not user then
        LOG_WARNING("updateUserClusterInfo error !!!! not find user", uid)
        return
    end
    if nil ~= user and user.cluster_info then
        user.cluster_info.address = agent
    end
end

-- 后台取牌桌信息
function CMD.apiGetDeskInfo(deskobj,msg)
    return deskobj:getdata()
end

--后台API 停服清房
function CMD.apiCloseServer(deskobj, is_close)
    --踢掉
   deskobj.closeServer = is_close
   if deskobj.state == 0 and deskobj.closeServer == true then
        deskobj.closeServer = false
        deskobj:sysKickUser()
   end
end

function CMD.reload()
    -- TODO重新加载控制配置
end

local chatNeed = {10,50,100}
-- 发送聊天信息
function CMD.sendChatMsg(deskobj, msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local user, idx = deskobj:select_userinfo(uid)
    local msg     = recvobj.msg

    local msgType  = math.floor(recvobj.msgType) or -1
    local msgStr   = recvobj.msgStr or ""

    if msgType > 0 then
        local needCoin = chatNeed[msgType]

        
        user.coin = user.coin - needCoin


    end

    local retobj = {c = PDEFINE.NOTIFY.NOTIFY_ROOM_CHAT, code = PDEFINE.RET.SUCCESS, seatid = user.seatid, msg = msg , msgType = msgType, msgStr = msgStr}
    deskobj:broadcastdeskAll(retobj)
    return PDEFINE.RET.SUCCESS
end

--广播跑马灯
function CMD.apiSendDeskNotice(deskobj, msg)
    deskobj:broadcastdeskAll(msg)
    return PDEFINE.RET.SUCCESS
end

function CMD.exit()
    collectgarbage("collect")
    skynet.exit()
end

return CMD