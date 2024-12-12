-- 桌子
local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local timemgr = require "base.timemgr"
local table_copy = nil
local queue = require "skynet.queue"
local cs = queue()
local GAME_NAME = skynet.getenv("gamename") or "game"

table_copy = function(t)
	local result = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            result[k] = table_copy(v, nometa)
        elseif type(v) == 'function' then
        	result[k] = nil
        else
            result[k] = v
        end
    end
    return result
end

local function resetDesk(deskobj)
    if #deskobj.users == 0 and #deskobj.vistor_users == 0 then --房间里没有人

        pcall(cluster.call, "game", ".dsmgr", "recycleAgent", skynet.self(), deskobj.deskid, deskobj.gameid)
        collectgarbage("collect")
        
    end
end

local function setSeatId(deskobj, seatid)
    local deskid = deskobj.deskid
    local seat_list = deskobj.seat_list
    if seatid then
        table.insert(seat_list, seatid)
        -- pcall(cluster.call, "master", ".mgrdesk", "changMatchCurUsers", GAME_NAME, deskobj.gameid, deskobj.deskid, -1)
    end
    pcall(cluster.call, "master", ".mgrdesk", "syncMatchCurUsers", GAME_NAME, deskobj.gameid, deskobj.deskid, (#deskobj.users + #deskobj.vistor_users))
end

-- 删除桌子里的某个玩家
local function delUserFromDesk(deskobj, uid)
    cs(function()
        local user, idx, type = deskobj:select_userinfo(uid)
        if not user then
            LOG_DEBUG("delUserFromDesk , not find uid %s ", uid)
            return
        end
        user:stop_action()
        if type == 1 then
            table.remove(deskobj.users, idx)
        else
            table.remove(deskobj.vistor_users, idx)
        end
        pcall(cluster.call, user.cluster_info.server, user.cluster_info.address, "deskBack", deskobj.gameid) --释放桌子对象
        local seatid = user.seatid or user.seat
        if seatid then
            setSeatId(deskobj, seatid)
        end
        resetDesk(deskobj)
    end)
end

-- 分配座位
local function get_seatList(deskobj, seatNum)
    deskobj.seat_list = {}
    for idx=1, seatNum do
        table.insert(deskobj.seat_list, idx)
    end
end

-- 分配座位号
local function getSeatId(deskobj)
    local deskid = deskobj.deskid
    local seat_list = deskobj.seat_list or {}
    local seatid = table.remove(seat_list, 1)
    -- if seatid then
        -- pcall(cluster.call, "master", ".mgrdesk", "changMatchCurUsers", GAME_NAME, deskobj.gameid, deskid, 1)
        pcall(cluster.call, "master", ".mgrdesk", "syncMatchCurUsers", GAME_NAME, deskobj.gameid, deskobj.deskid, (#deskobj.users + #deskobj.vistor_users))
    -- end
    return seatid
end

-- 获取特定的位置
local function getSpeSeatID(deskobj, seatid)
    local seat_list = deskobj.seat_list or {}
    for idx, sid in ipairs(seat_list) do
        if tonumber(sid) == tonumber(seatid) then
            table.remove(seat_list, idx)
            return true
        end
    end
    return false
end

local function get_desk_data(deskobj)
    local data = table_copy(deskobj)
    for _, userInfo in ipairs(data.users) do
        local ready_timeout = math.max((userInfo.ready_timeout - os.time()), 0)
        userInfo.ready_timeout = ready_timeout
        userInfo.cluster_info = nil
    end
    for _, userInfo in ipairs(data.vistor_users) do
        -- local ready_timeout = math.max((userInfo.ready_timeout - os.time()), 0)
        -- userInfo.ready_timeout = ready_timeout
        userInfo.cluster_info = nil
        if userInfo.isSitdown then
            table.insert(data.users, userInfo)
        end
    end

    data.conf = nil
    return data
end

local function broadcastdesk(deskobj, data, exclude_uid)
    for idx, muser in ipairs(deskobj.users) do
        if muser.cluster_info and (not exclude_uid or exclude_uid ~= muser.uid)then
            muser:send(data)
        end
    end
end

local function broadcastdeskAll(deskobj, data, exclude_uid)
    broadcastdesk(deskobj, data, exclude_uid)
    for idx, muser in ipairs(deskobj.vistor_users) do 
        if muser.cluster_info and (not exclude_uid or exclude_uid ~= muser.uid)then
            muser:send(data)
        end
    end
end

-- 自动剔除某个玩家
local function autoKickuser(deskobj, user)
    user:stop_action()
    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = PDEFINE.NOTIFY.NOTIFY_STUD_EXIT
    retobj.uid = user.uid
    retobj.seatid = user.seatid
    deskobj:broadcastdesk(retobj)
    deskobj:delUserFromDesk(user.uid)
end

-- 剔除所有玩家
local function sysKickAllUser(deskobj)
    local all_users = {}
    for _, user in ipairs(deskobj.users) do
        table.insert(all_users, user)
    end
    for _, user in ipairs(deskobj.vistor_users) do
        table.insert(all_users, user)
    end

    for i, user in pairs(all_users) do
        local retobj    = {}
        retobj.code     = PDEFINE.RET.SUCCESS
        retobj.c        = PDEFINE.NOTIFY.NOTIFY_SYS_KICK
        retobj.uid      = user.uid
        if user.cluster_info then
            pcall(cluster.call, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(retobj))
            pcall(cluster.call, user.cluster_info.server, user.cluster_info.address, "deskBack", deskobj.gameid) --释放桌子对象
        end
        deskobj:delUserFromDesk(user.uid)
    end
end

local function select_userinfo(deskobj, uid)
    for idx, user in ipairs(deskobj.users) do
        if tonumber(user.uid) == tonumber(uid) then
            return user, idx, 1
        end
    end
    for idx, user in ipairs(deskobj.vistor_users) do
        if tonumber(user.uid) == tonumber(uid) then
            return user, idx, 2
        end
    end
end

local function loadSessInfo(deskobj, gameid, ssid)
    local ok, rs = pcall(cluster.call, "master", ".sessmgr", "getRow", gameid, ssid)
    if ok then
        local revenue = string.format("%.3f", (rs.revenue/100)) --茶水费比例
        -- local revenue = rs.revenue
        deskobj.ssid = ssid
        deskobj.seat = math.floor(rs.seat)

        deskobj.conf.virtualCoin = math.floor(rs.param1) --体验金
        deskobj.conf.basecoin    = math.floor(rs.basecoin)
        deskobj.conf.isRoomCard  = 0
        deskobj.conf.multiple = math.floor(rs.param4) --倍数
        deskobj.conf.free  = math.floor(rs.free) or 0
        deskobj.conf.level = math.floor(rs.level) or 0
        deskobj.conf.revenue = revenue
        deskobj.conf.gameid = gameid
        -- deskobj.conf.joinScore = math.floor(rs.mincoin) or 1
        -- deskobj.conf.leaveScore = math.floor(rs.leftcoin) or 1
        deskobj.conf.seat = math.floor(rs.seat)
    end
end

local function iteration_alluser(deskobj, f)
    for _, user in ipairs(deskobj.users) do
        f(user)
    end
    for _, user in ipairs(deskobj.vistor_users) do
        f(user)
    end
end

local function create_desk(recvobj, ip, deskid)
    local deskobj = {
        users = {}, -- 玩家列表
        vistor_users = {}, --旁观
        state = 0,
        conf = {}, -- 配置信息
    }

    local uid = math.floor(recvobj.uid)
    local ssid = math.floor(recvobj.ssid or 0)
    local free = recvobj.free or 0 --体验场 free = 1 其他场次 free = 0
    local joinScore = math.floor(recvobj.mincoin or 0) -- 进入房间

    local now = os.time()
    deskobj.deskid = deskid
    deskobj.mincoin = joinScore
    deskobj.uuid   = deskid .. now
    deskobj.owner = uid
    deskobj.conf = {}
    deskobj.gameid = recvobj.gameid
    loadSessInfo(deskobj, deskobj.gameid, ssid)
    deskobj.conf.isRoomCard = 0
    deskobj.conf.gameid = recvobj.gameid
    deskobj.gameid = recvobj.gameid
    deskobj.curround = 0
    deskobj.curseat = 1
    deskobj.roomtype = recvobj.roomtype or PDEFINE.ROOM_TYPE.PUBLIC
    get_seatList(deskobj, recvobj.seatNum)

    local sql = string.format("insert into d_desk(uuid, deskid,gameid,sessionid,owner,typeid,status,seat,curseat,maxround,waittime,stuffy,joinmiddle,rubcard,opengps,betbase,mincoin,leftcoin,round_num_no_pk,pot_current,bet_call_current,curround,watchnum,create_time) values('%s','%s',%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)", deskobj.uuid, deskid, deskobj.gameid, ssid, uid, 1, 0, 4, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, now)
    skynet.call(".mysqlpool", "lua", "execute", sql)

    -- 方法区域
    deskobj.broadcastdesk = broadcastdesk
    deskobj.select_userinfo = select_userinfo
    deskobj.auto_action = timemgr.auto_desk
    deskobj.stop_action = timemgr.stop_desk
    deskobj.getSeatId = getSeatId
    deskobj.setSeatId = setSeatId
    deskobj.getSpeSeatID = getSpeSeatID
    deskobj.delUserFromDesk = delUserFromDesk
    deskobj.getdata = get_desk_data
    deskobj.broadcastdeskAll = broadcastdeskAll
    deskobj.broadcastdesk = broadcastdesk
    deskobj.autoKickuser = autoKickuser
    deskobj.sysKickAllUser = sysKickAllUser
    deskobj.roomtype  = recvobj.roomtype or 2
    deskobj.iteration_alluser = iteration_alluser

    return deskobj
end

return create_desk