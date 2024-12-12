
-- 使用约定：
-- 1、 deskinfo.users 为用户信息 usr.coin 为金币

local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

local timemgr = require "base.timemgr"

local user_proxy = require "base.user_proxy"
local GAME_NAME = skynet.getenv("gamename") or "game"
local player_tool = require "base.player_tool"
local water_pool = require "base.water_pool"
local APP = skynet.getenv("app") or 1

local queue = require "skynet.queue"
local snax = require "snax"
local cs = queue()

local fightagent = {}

local TIMEOUT_FLINE =  "TIMEOUT_FLINE"
local TIMEOUT_ACTION = "TIMEOUT_ACTION"

local table_copy = nil

local ACTION_TIMEOUT = 3 * 60 * 100

local READY_TIMEOUT = 20

local settle = require "settle"
local PUSH_MSG = {
	PUSH_USER_INFO = 100001,
}

-- 上报结果
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

local function send(user, data)
	data.code = 200
	local send_data = cjson.encode(data)
	-- print("send msg to user: ", user.uid, send_data)
	pcall(cluster.call, user.cluster_info.server, user.cluster_info.address, "sendToClient", send_data)
end

local function calUserCoin(user, addcoin, mtype, deskobj)
	mtype = mtype or PDEFINE.ALTERCOINTAG.COMBAT -- 默认为结算
	if user.cluster_info then
		player_tool.calUserCoin(user.uid, addcoin, PDEFINE.GAME_TYPE.POKER_TBNN.."修改金币:"..addcoin, mtype, deskobj)
	end

	local gameid = math.floor(deskobj.gameid)
	if math.floor(APP) == 1 then
		if gameid == PDEFINE.GAME_TYPE.POKER_MALMJ and mtype==PDEFINE.ALTERCOINTAG.COMBAT then
			--人气值
			if addcoin > 0 then
				user.integral = user.integral + addcoin
				if user.cluster_info then
					pcall(cluster.call,user.cluster_info.server, user.cluster_info.address, "clusterModuleCall", "player", "addRenqi", user.uid, addcoin)
				else
					pcall(cluster.call,"ai", ".aiuser", "addRenqi", user.uid, addcoin)
				end
		    end
		end
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
	local ready_timeout = math.max((userInfo.ready_timeout - os.time()), 0)
	userInfo.ready_timeout = ready_timeout
	userInfo.cluster_info = nil
	return userInfo
end

local function get_seatList(deskobj)
	deskobj.seat_list = {}
	for idx=1, deskobj.conf.seat do
		table.insert(deskobj.seat_list, idx)
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
			muser:calUserCoin(userCalCoin, PDEFINE.ALTERCOINTAG.REVENUE, userCalCoin, deskobj)
		end
		if tax > 0 then
		    local sql = string.format("insert into s_tax(uuid, gameid,level,deskid,uid,coin,create_time,isrobot) values('%s',%d,%d,'%s',%d,%f,%d,%d)", deskobj.uuid, deskobj.gameid, deskobj.conf.level, deskobj.deskid, muser.uid, tax, os.time(), isrobot)
	    	skynet.call(".mysqlpool", "lua", "execute", sql)
		end
	end
end

local function loadSessInfo(deskobj, gameid, ssid)
	local ok, rs = pcall(cluster.call, "master", ".sessmgr", "getRow", gameid, ssid)
	if ok then
		-- local revenue  = string.format("%.3f", (rs.revenue)) --茶水费
		local revenue = rs.revenue
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
		deskobj.conf.joinScore = math.floor(rs.mincoin) or 1
		deskobj.conf.leaveScore = math.floor(rs.leftcoin) or 1
		deskobj.conf.seat = math.floor(rs.seat)
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
	local ssid = math.floor(recvobj.ssid)
	local free = recvobj.free or 0 --体验场 free = 1 其他场次 free = 0
	local joinScore = math.floor(recvobj.mincoin) -- 进入房间

	local now = os.time()
	deskobj.deskid = deskid
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

	get_seatList(deskobj)

	local sql = string.format("insert into d_desk(uuid, deskid,gameid,sessionid,owner,typeid,status,seat,curseat,maxround,waittime,stuffy,joinmiddle,rubcard,opengps,betbase,mincoin,leftcoin,round_num_no_pk,pot_current,bet_call_current,curround,watchnum,create_time) values('%s','%s',%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)", deskobj.uuid, deskid, deskobj.gameid, ssid, uid, 1, 0, 4, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, now)
    skynet.call(".mysqlpool", "lua", "execute", sql)

	return deskobj
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
	userInfo.uid = math.floor(recvobj.uid)
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
	userInfo.calUserCoin = function(self, addcoin, stype)
		if deskobj.conf.free == 0 then -- 不为体验场模式
			calUserCoin(self, addcoin, stype, deskobj)
		elseif deskobj.conf.free == 1 then
			self.coin = self.coin + addcoin
		end
	end
	userInfo.cluster_info = cluster_info
	init_user(userInfo)
	return userInfo
end

-- 分配座位号
local function getSeatId(deskobj)
	local deskid = deskobj.deskid
	local seat_list = deskobj.seat_list or {}
	local seatid = table.remove(seat_list, 1)
	-- if seatid then
		-- pcall(cluster.call, "master", ".mgrdesk", "changMatchCurUsers", GAME_NAME, deskobj.gameid, deskid, 1)
		pcall(cluster.call, "master", ".mgrdesk", "syncMatchCurUsers", GAME_NAME, deskobj.gameid, deskobj.deskid, (#deskobj.users + #deskobj.vistor_users), deskobj.ssid)
	-- end
	return seatid
end

local function setSeatId(deskobj, seatid)
	local deskid = deskobj.deskid
	local seat_list = deskobj.seat_list
	if seatid then
		table.insert(seat_list, seatid)
		-- pcall(cluster.call, "master", ".mgrdesk", "changMatchCurUsers", GAME_NAME, deskobj.gameid, deskobj.deskid, -1)
	end
	pcall(cluster.call, "master", ".mgrdesk", "syncMatchCurUsers", GAME_NAME, deskobj.gameid, deskobj.deskid, (#deskobj.users + #deskobj.vistor_users), deskobj.ssid)
end

local function getBrokenTimes(uid, gameid)
	return "broken:" .. uid..":"..gameid
end

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

function fightagent.start(game_hander, game_cmd)

	assert(game_hander.create_deskinfo)
	assert(game_hander.create_userinfo)

	assert(game_hander.get_deskinfo_2c) -- 获取给uid 玩家发的桌子信息
	assert(game_hander.get_userinfo_2c) -- 获得玩家信息
	assert(game_hander.start_game)
	assert(game_hander.get_result)

	local deskobj = nil -- create 时候创建

	local closeServer = false -- 控制关闭服务
	
	local function select_userinfo(uid)
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
	
	-- DEBUG 
	local function print_deskusers(uid)
		local count = 0
		local tbl = {}
		for _, user in pairs(deskobj.users) do
			count = count + 1
			table.insert(tbl, user.uid)
		end
		LOG_DEBUG("PRINT_DESKUSERS !!!! %s, count %s , find uid is %s ", table.concat(tbl, ","), count, uid)
	end

	local function resetDesk()
		if deskobj.conf.seat == #deskobj.seat_list then --房间类没有人
			water_pool.endPoolRound(0, deskobj, PDEFINE.POOL_TYPE.none, deskobj.poolround_id)
			pcall(cluster.call, "game", ".dsmgr", "recycleAgent", skynet.self(), deskobj.deskid, deskobj.gameid)
	    	collectgarbage("collect")
		end
	end

	local function delUserFromDesk(uid)
		cs(function()
			local user, idx = select_userinfo(uid)
			if not user then
				LOG_DEBUG("delUserFromDesk , not find uid %s ", uid)
				return
			end
			user:stop_action()
			if not user.is_vistor then
				table.remove(deskobj.users, idx)
			else
				table.remove(deskobj.vistor_users, idx)
			end
			pcall(cluster.call, user.cluster_info.server, user.cluster_info.address, "deskBack", deskobj.gameid) --释放桌子对象
			setSeatId(deskobj, user.seatid)
			if #deskobj.users == 0 then
				resetDesk()								
			end 
		end)
	end
	
	local function checkDeskUserNum(uid)
		return cs(function()
			local user, idx = select_userinfo(uid)
			if not user then
				LOG_DEBUG("delUserFromDesk , not find uid %s ", uid)
				return
			end
			user:stop_action()
			if not user.is_vistor then
				table.remove(deskobj.users, idx)
			else
				table.remove(deskobj.vistor_users, idx)
			end
			setSeatId(deskobj, user.seatid)
			if #deskobj.users ~= 0 then
				pcall(cluster.call, user.cluster_info.server, user.cluster_info.address, "deskBack", deskobj.gameid) --释放桌子对象
			end
			return #deskobj.users
		end)
	end

	local function auto_kickuser(user)
		if not user.is_ready then
	    	user:stop_action()
			local retobj = {}
		    retobj.code = PDEFINE.RET.SUCCESS
		    retobj.c = PDEFINE.NOTIFY.NOTIFY_KICK
		    retobj.uid = user.uid
		    retobj.seatid = user.seatid 	
		    deskobj:broadcastdesk(retobj)
			delUserFromDesk(user.uid)
		end
	end
	
	local function sysKickUser()

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
			delUserFromDesk(user.uid)
		end
	end

	local function end_game(is_over)
		deskobj.state = 3
		-- 停止一切倒计时和税
		for _, user in ipairs(deskobj.users) do
			user:stop_action()
			revenue(user, deskobj.conf.revenue, deskobj)
		end
		local data = game_hander.get_result(deskobj, is_over)
		for idx, user_result in ipairs(data.users) do
			send_result(deskobj.users[idx], deskobj, user_result.addcoin, deskobj.conf.free)
		end

		data.ready_timeout = READY_TIMEOUT
		deskobj:broadcastdesk(data)
		for _, user in ipairs(deskobj.users) do
			init_user(user)
			user.info = game_hander.create_userinfo()
			user:auto_action('KICK_USER', READY_TIMEOUT, function () 
				auto_kickuser(user)
			end)
			if user.cluster_info then
				pcall(cluster.call, "master", ".vipCenter", "bet", user.uid, deskobj.conf.joinScore, deskobj.gameid)
			end
		end
		table.merge(deskobj, game_hander.create_deskinfo())
		deskobj.state = 0
		if closeServer then
			closeServer = false
			sysKickUser()
		end
	end

	local function get_desk_data()
		local data = table_copy(deskobj)
		for _, userInfo in ipairs(data.users) do
			local ready_timeout = math.max((userInfo.ready_timeout - os.time()), 0)
			userInfo.ready_timeout = ready_timeout
		end
		return data
	end


	local function set_timeout(ti, f)
	 	local function t()
		    if f then 
		      f()
		    end
	  	end
		skynet.timeout(ti, t)
		return function() f=nil end
	end

	local CMD = {}

	-- 查找用户信息
	local function find_userinfo(seatid)
		for _, user in pairs(deskobj.users) do
			if user.seatid == seatid then
				return user
			end
		end
	end

	local function dispatch_ai_msg(data, user)
		LOG_DEBUG("dispatch_ai_msg, data:", data)
    	local c = data.c
    	local cmd = PDEFINE.PROTOFUN[tostring(c)]
    	local cmd = string.gsub(cmd, "cluster.game.dsmgr.", "")
		local f = CMD[cmd]
		if f then
			f(source, data)
		else
			local game_f = game_cmd[cmd]
			if game_f then
				local recvobj = data
				return game_f(deskobj, user, recvobj)
			end
		end
    end
    
	function CMD.create(source, cluster_info, msg, ip, deskid)

		local recvobj  = cjson.decode(msg)
		local uid = math.floor(recvobj.uid)
		local ssid = math.floor(recvobj.ssid)
		local free = recvobj.free or 0 --体验场 free = 1 其他场次 free = 0
		local joinScore = math.floor(recvobj.mincoin) -- 进入房间

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

		deskobj = create_desk(recvobj, ip, deskid)
		table.merge(deskobj, game_hander.create_deskinfo())

		deskobj.broadcastdesk = broadcastdesk
		deskobj.end_game = end_game
		deskobj.select_userinfo = select_userinfo
		deskobj.auto_action = timemgr.auto_desk
        deskobj.stop_action = timemgr.stop_desk

		local user = create_user(deskobj, cluster_info, recvobj, playerInfo, ip)
		user.info = game_hander.create_userinfo() -- game user info
		user:auto_action('KICK_USER', READY_TIMEOUT, function () 
			if not user.is_ready then
				auto_kickuser(user)
			end
		end)
		user_proxy(user, dispatch_ai_msg, deskobj)

		local seatid = getSeatId(deskobj)
		user.seatid = seatid

		-- deskobj.users[seatid] = user
		if deskobj.state == 0 then
			table.insert(deskobj.users, user)
		end

		deskobj.poolround_id = water_pool.startPoolRound(deskobj, 0, PDEFINE.POOL_TYPE.none)

		local data = game_hander.get_deskinfo_2c(get_desk_data(), uid)
		for _, user in ipairs(data.users) do
        	user = game_hander.get_userinfo_2c(user, tonumber(uid) == tonumber(user.uid))
    	end
		return PDEFINE.RET.SUCCESS, data or {}
    end

    function CMD.join(source, cluster_info, msg, ip)

    	local recvobj = cjson.decode(msg)
	    local uid = math.floor(recvobj.uid)
	    local deskid = recvobj.deskid
		local ouser = select_userinfo(uid)
		if ouser then
			return PDEFINE.RET.ERROR.PLAYER_EXISTS_DESK
		end
		local playerInfo = cluster.call(cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid)
		if not playerInfo then
			return PDEFINE.RET.ERROR.SEATID_EXIST
		end
		local deskid = recvobj.deskid
		if deskid ~= deskobj.deskid then
			return PDEFINE.RET.ERROR.DESKID_FAIL
		end
		local gameid = recvobj.gameid
		--判断房费
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

		local seatid = getSeatId(deskobj)
		if not seatid then
			return PDEFINE.RET.ERROR.SEATID_EXIST
		end

		local user = create_user(deskobj, cluster_info, recvobj, playerInfo, ip)
		user.info = game_hander.create_userinfo()
		user_proxy(user, dispatch_ai_msg, deskobj)
		user:auto_action('KICK_USER', READY_TIMEOUT, function () 
			auto_kickuser(user)	
		end)

		user.seatid = seatid

		if deskobj.state == 0 then
			table.insert(deskobj.users, user)
			--按位置排序
		else
			user.is_vistor = true
			table.insert(deskobj.vistor_users, user)
		end

		local desk_data = game_hander.get_deskinfo_2c(get_desk_data(), uid)
		for idx, muser in ipairs(desk_data.users) do
        	muser = game_hander.get_userinfo_2c(muser, tonumber(uid) == tonumber(user.uid))
    	end

		local retobj  = {}
    	retobj.c      = PDEFINE.NOTIFY.join
    	retobj.code   = PDEFINE.RET.SUCCESS
    	retobj.gameid = deskobj.gameid
    	retobj.ssid   = deskobj.ssid
    	retobj.deskid = deskobj.deskid
	    retobj.deskinfo = desk_data

	    local user_data = game_hander.get_userinfo_2c(get_user_data(user), false)
	    local ret = {
	    	c = PDEFINE.NOTIFY.MLMJ_USER_JOIN,
	    	code = PDEFINE.RET.SUCCESS,
	    	userinfo = user_data,
		}
		deskobj:broadcastdesk(ret, user.uid)
    	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)

	end

    local function start_game()
    	if deskobj.state == 1 then
    		return
    	end
    	deskobj.state = 1
    	for _, user in ipairs(deskobj.users) do
    		user:stop_action()
    	end
    	game_hander.start_game(deskobj)
    end

	-- 准备游戏
	function CMD.ready(source, msg)

		local recvobj  = cjson.decode(msg)
		local uid = math.floor(recvobj.uid)
		local user = select_userinfo(uid)

		if deskobj.state ~= 0 then
			return 401
		end

		if user.state == 1 then
	        return 402
	    end
	    
	    local is_ready = recvobj.ready
	    if is_ready == nil then
	    	is_ready = true
	    end
		user.state = 1 -- 准备
		if is_ready then
			if user.coin < deskobj.conf.joinScore then -- 金币不足
				return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
			end
			user:stop_action('KICK_USER') -- 停止T人
		end
	    user.is_ready = is_ready

		local retobj    = {}
	    retobj.code     = PDEFINE.RET.SUCCESS
	    retobj.c        = recvobj.c
	    retobj.uid      = uid
	    retobj.seatid   = user.seatid
	    deskobj:broadcastdesk(retobj, uid)
	    -- FIX 目前是全部准备才能开始，后续可以拓展可以观战的模式
    	local pnum = 0
	    for idx, userReady in pairs(deskobj.users) do
	        if not userReady.is_ready  then
	            break
	        end
	        pnum = pnum + 1
	    end
	    if pnum == deskobj.conf.seat then
		    -- skynet.timeout(1, function ()
		    	-- if pnum == deskobj.conf.seat then
	    	start_game()
		    	-- end
		    -- end)
		end
	    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
	end

	function CMD.auto(source, msg)
		local recvobj  = cjson.decode(msg)
		local uid = math.floor(recvobj.uid)
		local user, idx = select_userinfo(uid)

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

	-- 整个游戏退出
    function CMD.exit()
	    collectgarbage("collect")
	    skynet.exit()
    end
    
    --用户在线离线
	function CMD.ofline(source, ofline, uid)
		local user = select_userinfo(uid)
		if user then
			user.ofline = ofline
			local retobj = {}
			retobj.c = PDEFINE.NOTIFY.NOTIFY_ONLINE
			retobj.code = PDEFINE.RET.SUCCESS
			retobj.ofline = ofline
			retobj.seatid = user.seatid
			deskobj:broadcastdesk(retobj, uid)
			-- TODO 这里是不是需要托管
		end
	end

	function CMD.getDeskInfo(source, msg)
		local recvobj = cjson.decode(msg)
		local uid = math.floor(recvobj.uid)
		local data = game_hander.get_deskinfo_2c(get_desk_data(), uid)
		for _, user in ipairs(data.users) do
        	user = game_hander.get_userinfo_2c(user, tonumber(uid) == tonumber(user.uid))
    	end
		if tonumber(recvobj.c) == 230 then -- 兼容处理
			data.code = PDEFINE.RET.SUCCESS
			return PDEFINE.RET.SUCCESS, cjson.encode(data)
		else
			if game_hander.renter then -- 重新进入
				skynet.timeout(10, function()
					local user = select_userinfo(uid)
					if not user then
						LOG_DEBUG("GetDeskInfo ERROR !!! %s", uid)
						print_deskusers(uid)
						return
					end
					if user then
						game_hander.renter(deskobj, user, recvobj)
					end
				end)
			end
			return data
		end
	end

	--更新玩家的桌子信息
	function CMD.updateUserClusterInfo(source, uid, agent)
	    uid = math.floor(uid)
	    local user = select_userinfo(uid)
	    if not user then
	    	print_deskusers(uid)
	    end

	    if nil ~= user and user.cluster_info then
	        user.cluster_info.address = agent
	    end
	end

	-- 退出房间
	function CMD.exitG(source, msg)

	    local recvobj = cjson.decode(msg)
	    local uid     = math.floor(recvobj.uid)
		local exUser  = select_userinfo(uid)
	    if not exUser then
			print_deskusers(uid)
	    	return PDEFINE.RET.SUCCESS
	    end

        if deskobj.state == 0 then -- 0 未开始
            local retobj = {}
            retobj.c     = PDEFINE.NOTIFY.exit
            retobj.code  = PDEFINE.RET.SUCCESS
            retobj.uid   = uid
            retobj.seatid = exUser.seatid
            deskobj:broadcastdesk(retobj, uid)

        	--delUserFromDesk(uid)

        	local manUserCount = 0
			for _,user in pairs(deskobj.users) do
				if user.cluster_info and user.isExit == 0 then
					manUserCount = manUserCount + 1
				end
			end

			for _,user in pairs(deskobj.vistor_users) do
				if user.cluster_info then
					manUserCount = manUserCount + 1
				end
			end
			if checkDeskUserNum(uid) == 0 then
				-- return PDEFINE.RET.EXIT_RESET,makeDeskBaseInfo(deskobj.gameid,deskobj.deskid)
				makeDeskBaseInfo(deskobj.gameid,deskobj.deskid)
				pcall(cluster.call, exUser.cluster_info.server, exUser.cluster_info.address, "deskBack", deskobj.gameid) --释放桌子对象
				return PDEFINE.RET.SUCCESS
			end
        else
        	exUser = select_userinfo(uid)
        	if exUser.is_vistor then -- 访问者直接退出
	            local retobj = {}
	            retobj.c     = PDEFINE.NOTIFY.exit
	            retobj.code  = PDEFINE.RET.SUCCESS
	            retobj.uid   = uid
	            retobj.seatid = exUser.seatid
	            deskobj:broadcastdesk(retobj,uid)
				if checkDeskUserNum(uid) == 0 then
					makeDeskBaseInfo(deskobj.gameid,deskobj.deskid)
					pcall(cluster.call, exUser.cluster_info.server, exUser.cluster_info.address, "deskBack", deskobj.gameid) --释放桌子对象
					return PDEFINE.RET.SUCCESS
				end
        	end
        end
	    return PDEFINE.RET.SUCCESS
	end

	-- 后台取牌桌信息
	function CMD.apiGetDeskInfo(source,msg)
	    return get_desk_data()
	end

	--后台API 解散房间
	function CMD.apiKickDesk(source)
	    --踢掉
	    local  gameid = deskobj.gameid
	    for _, muser in pairs(deskobj.users) do
	        if muser.cluster_info and muser.isExit == 0 then
	            pcall(cluster.call, muser.cluster_info.server, muser.cluster_info.address, "deskBack", gameid) --释放桌子对象
	            plog("apiKickDesk ", gameid, deskobj.deskid," after changMatchCurUsers deskobj.curseat:", deskobj.curseat)
	        end
	    end
	    local retobj = {c = PDEFINE.NOTIFY.ALL_GET_OUT, code = PDEFINE.RET.SUCCESS}
	    deskobj:broadcastdesk(retobj)
	    for _, user in ipairs(deskobj.users) do
		    delUserFromDesk(user.uid)
		end
	end
	
	-------- API更新桌子里玩家的金币 --------
	function CMD.addCoinInGame(source, uid, coin)
	    local user, _ = select_userinfo(uid)
	    if nil ~= user then 
	        user.coin = user.coin + coin
	    end
	end
	
	--后台API 停服清房
	function CMD.apiCloseServer(source, is_close)
	    --踢掉
	   closeServer = is_close
	   if deskobj.state == 0 and closeServer == true then
	   		closeServer = false
	   		sysKickUser()
	   end
	end

	function CMD.reload()
		-- TODO重新加载控制配置
	end
	
	-- 发送聊天信息
	function CMD.sendChatMsg(source, msg)
	    local recvobj = cjson.decode(msg)
	    local uid     = math.floor(recvobj.uid)
	    local user, idx = select_userinfo(uid)
	    local msg     = recvobj.msg

	    local retobj = {c = PDEFINE.NOTIFY.NOTIFY_ROOM_CHAT, code = PDEFINE.RET.SUCCESS, seatid = user.seatid, msg = msg}
	    deskobj:broadcastdesk(retobj)
	    return PDEFINE.RET.SUCCESS
	end

	skynet.start(function()
		skynet.dispatch("lua", function (_, address, cmd, ...)
			local f = CMD[cmd]
			if f then
				skynet.retpack(f(source, ...))
			else
				local game_f = game_cmd[cmd]
				if game_f then
					local msg = ...
					local recvobj = cjson.decode(msg)
					local uid  =recvobj.uid
					if not uid then
						LOG_WARNING("if user alone agent base , all msg need uid !!")
						return
					end
					local user = select_userinfo(uid)
					skynet.retpack(game_f(deskobj, user, recvobj))
				end
			end
		end)
	end)

	--其他一些API操作
	skynet.info_func(function ()
		-- 房间信息
		return cjson.encode(get_desk_data())
	end)
	
end

return fightagent