
local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local timemgr = require "base.timemgr"

local READY_TIMEOUT = 20
local table_copy = nil
local new_desk = require "base.create_desk"
local player_tool = require "base.player_tool"

local APP = skynet.getenv("app") or 1
APP = tonumber(APP)

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
local function send_result(user, deskInfo, bet_coin, addcoin, prize_result, free)
    bet_coin = 0
    free = free or 0

    if true then
        local sql = string.format("insert into d_user_combat(uuid, deskid, round, uid, gameid, playername, usericon, cards, cardtype, betbase, addcoin, endtime, isrobot, tax, free, bet) values('%s','%s',%d,%d,%d,'%s','%s','%s','%s',%d,%f,%d,%d, %f,%d,'%s')", 
            deskInfo.uuid, 
            deskInfo.deskid, 
            deskInfo.curround, 
            user.uid,
            deskInfo.gameid,
            user.playername, 
            user.coin,
            cjson.encode(prize_result),
             0,
             0, 
             addcoin, 
             os.time(),
             0, 
             0,
             free, 
             tostring(bet_coin))
        skynet.call(".mysqlpool", "lua", "execute", sql)
        settle.addWinlist(user.uid, addcoin, free)
    end
end

local function send(user, data, showlog)
    if showlog == nil then showlog = true end
    if not showlog then
        showlog = true
    end
    if showlog then
        -- print("send message to ", user.uid, data)
    end
    data.code = data.code or 200
    local send_data = cjson.encode(data)
    pcall(cluster.call, user.cluster_info.server, user.cluster_info.address, "sendToClient", send_data)
end

local function calUserCoin(user, addcoin, mtype, deskobj)
	mtype = mtype or PDEFINE.ALTERCOINTAG.COMBAT -- 默认为结算
	if user.cluster_info then
		player_tool.calUserCoin(user.uid, addcoin, "Game:"..tonumber(deskobj.gameid).."修改金币:"..addcoin, mtype, deskobj)
	end
	user.coin = user.coin + addcoin
end

local function broadcastdesk(deskobj, data, exclude_uid)
    for idx, muser in ipairs(deskobj.users) do
        -- print("idx, uid ", idx, muser.uid)
        if muser.cluster_info and (not exclude_uid or exclude_uid ~= muser.uid)then
            muser:send(data)
        end
    end
end

local function get_user_data(user)
    local userInfo = table_copy(user)
    if userInfo.ready_timeout then
        local ready_timeout = math.max((userInfo.ready_timeout - os.time()), 0)
        userInfo.ready_timeout = ready_timeout
    end
    userInfo.cluster_info = nil
    return userInfo
end

local function select_userinfo(deskobj, uid)
    for idx, user in ipairs(deskobj.users) do
        if tonumber(user.uid) == tonumber(uid) then
            return user, idx
        end
    end
    for idx, user in ipairs(deskobj.vistor_users) do
        if tonumber(user.uid) == tonumber(uid) then
            return user, idx
        end
    end
end

-- 按照座逆时针排序 seat_编码约定从小到大
local function sort_users(users_list)
    table.sort(users_list, function(a, b) 
        return a.seatid < b.seatid
    end)
end

-- 税收
local function revenue(muser, revenue_value, deskobj)
    local tax = revenue_value or 0
    tax = tonumber(tax)
    if muser.coin <  tax then
        tax = muser.coin
    end
    local userCalCoin = -tax
    if deskobj.conf.free == 0 then 
        local isrobot = 1
        if muser.cluster_info and muser.isExit == 0 then
            isrobot = 0
            muser:calUserCoin(userCalCoin, userCalCoin, PDEFINE.FLOW_TYPE.REVENUE, deskobj)
        end
        if tax > 0 then
            local sql = string.format("insert into s_tax(uuid, gameid,level,deskid,uid,coin,create_time,isrobot) values('%s',%d,%d,'%s',%d,%f,%d,%d)", deskobj.uuid, deskobj.gameid, deskobj.conf.level, deskobj.deskid, muser.uid, tax, os.time(), isrobot)
            skynet.call(".mysqlpool", "lua", "execute", sql)
        end
    end
end

local function init_user(userInfo)
    userInfo.state = 0
    userInfo.is_ready = false
    userInfo.is_auto = false
    userInfo.ready_timeout = os.time() + READY_TIMEOUT
end

local function create_user(deskobj, cluster_info, recvobj, playerInfo, ip)

    local userInfo = {}
 
    userInfo.isExit = 0
    userInfo.uid = recvobj.uid
    userInfo.ip = ip
    userInfo.playername = playerInfo.playername
    userInfo.sex = playerInfo.sex
    userInfo.usericon = playerInfo.usericon
    userInfo.memo = playerInfo.memo
    userInfo.integral = playerInfo.integral or 0 -- 段位信息
    userInfo.headframe= playerInfo.headframe or 0

    userInfo.state = 0
    userInfo.is_vistor = false -- 是否旁观者
    userInfo.coin = playerInfo.coin
    userInfo.is_ready = false
    userInfo.is_auto = false
    userInfo.ofline = 1
    userInfo.of_count = 0;
    userInfo.of_count_total = 0;
    userInfo.gj_count = 0;
    userInfo.gj_count_total = 0;

    local free = deskobj.free

    if deskobj.conf.free == 0 then
        userInfo.coin = playerInfo.coin
    elseif deskobj.conf.free == 1 then
        userInfo.coin = deskobj.conf.virtualCoin
    end

    userInfo.send = function (user, data)
        send(user, data)
    end

    userInfo.auto_action = timemgr.auto_user
    userInfo.stop_action = timemgr.stop_user
    userInfo.calUserCoin = function(self, addcoin, type)

        if tonumber(deskobj.conf.free) == 0 then -- 不为体验场模式
            calUserCoin(self, addcoin, type, deskobj)
        elseif deskobj.conf.free == 1 then
            self.coin = self.coin + addcoin
        end
    end
    userInfo.cluster_info = cluster_info
    init_user(userInfo)
    userInfo.getdata = get_user_data
    userInfo.init = init_user
    return userInfo
end

local function getBrokenTimes(uid, gameid)
    return "broken:" .. uid..":"..gameid
end

local function create_desk(recvobj, ip, deskid)
    return new_desk(recvobj, ip, deskid)
end

return {
    create_user = create_user,
    create_desk = create_desk,
    send_result = send_result,
    revenue = revenue,
    getBrokenTimes = getBrokenTimes,
}