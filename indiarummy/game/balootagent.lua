local skynet    = require "skynet"
local cluster   = require "cluster"
local cjson     = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local queue     = require "skynet.queue"
local snax = require "snax"
local date = require "date"
local player_tool = require "base.player_tool"
local balootutil = require "baloot.util"
local balcfg = require "baloot.config"
local cs = queue()
local GAME_NAME = skynet.getenv("gamename") or "game"
local DEBUG = skynet.getenv("DEBUG")
local CMD = {}
local closeServer = false
local usersAutoFuc= {} --玩家定时器
local aiAutoFuc --自动加机器人倒计时函数
local timeout = 600
local firstDelay = false  -- 是否第一次倒计时,用来防止第一次倒计时太短
local dismiss = nil  -- 解散房间相关信息
local agentState = true --agent使用中
local WINSCORE = 152
local LASTWINKEY = 0 --上一把赢的一方
local AutoDelayTime = 50  -- 托管命令和其他命令的隔开时间
local AutoReadyTimeout = 11  -- 自动准备时间，需要加上大结算播放特效时间
local GAME_ID = PDEFINE.GAME_TYPE.BALOOT
local ITEM_ALL_FIRST = {balcfg.TYPE.HOKOM, balcfg.TYPE.SUN, balcfg.TYPE.ASHKAL, balcfg.TYPE.PASS}
local autoStartInfo = {
    func = nil,
    startTime = nil,
}  -- 自动开始倒计时
-- 自动解散房间
local autoRecycleInfo = {
    func = nil,
    resetTime = nil,
}

-- 自动踢人函数
local autoKickOutInfo = {
    func = nil,
    resetTime = nil,
}
local localFunc = {}

local SEATID_LIST = {4,3,2,1}
local deskInfo = {
    gameid = GAME_ID,
    users   = {}, --4个玩家
	views   = {},  -- 观战玩家
    state   = 1,  --房间当前游戏状态
    bet     = 0, --底注
    curround = 0, --第N轮
	panel = { --左上角面板
		['prize'] = 0,
		['score'] = {0,0},
		['roundscore'] = {0, 0}, --轮分
		['gametype'] = 0,
		['suit'] = -1,
		['uid'] = 0
	},
	preWinners = {},  -- 上一把赢的人
}

local CURRENT_CARD_LIB --当前轮扑克牌

local function initSettleData()
	return {
		{ --小轮结算面板字段
			['roundscore'] = 0,
			['floor'] = 0,
			['projects'] = 0,
			['projectslist'] = {},
			['points'] = 0,
			['score'] = 0
		},
		{ --小轮结算面板字段
			['roundscore'] = 0,
			['floor'] = 0,
			['projects'] = 0,
			['projectslist'] = {},
			['points'] = 0,
			['score'] = 0
		},
	}
end

local function resp(retobj)
    return PDEFINE.RET.SUCCESS, retobj
end

local function getTeamId(seatid)
	local teamid, other = 1, 2
	if seatid == 2 or seatid == 4 then
		teamid = 2
		other = 1
	end
	return teamid, other
end

local function debug_log(...)
	LOG_DEBUG(deskInfo.uuid , ' => ', deskInfo.deskid, ...)
end

local function isJoinAI()
	if not PDEFINE_GAME.AUTO_JOIN_ROBOT then
        return false
    end
	if deskInfo.conf.roomtype ~= PDEFINE.BAL_ROOM_TYPE.PRIVATE then
		return false
	end
    if not deskInfo.conf.pwd or deskInfo.conf.pwd == "" then
        return true
    end
    return false
end

-- 广播给旁观者
local function broadcastView(retobj)
    for _, muser in ipairs(deskInfo.views) do
        if muser.cluster_info then
            pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", retobj)
        end
    end
end

-- 广播给房间里的所有人
local function broadcastDesk(retobj, uid)
	if not uid then
	    for _, muser in pairs(deskInfo.users) do
	    	if  muser.cluster_info and muser.isexit == 0 then
	        	pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", retobj)
	        end
	    end
	else
		for _, muser in pairs(deskInfo.users) do
			if muser.uid ~= uid then
				if  muser.cluster_info and muser.isexit == 0 then
	        		pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", retobj)
	        	end
	        end
	    end
	end
	broadcastView(retobj)
end

--广播 生成用户进入自动或取消自动的消息
local function brodcastUserAutoMsg(user, auto)
	if auto == 1 then
        if not user.autoStartTime then
            user.autoStartTime = os.time()
        end
    else
        if user.autoStartTime then
            user.autoTotalTime = user.autoTotalTime + os.time() - user.autoStartTime
            user.autoStartTime = nil
        end
    end
	local retobj = { c=PDEFINE.NOTIFY.BALOOT_USER_AUTO, code = PDEFINE.RET.SUCCESS, uid = user.uid, seatid = user.seatid, auto=auto }
    broadcastDesk(cjson.encode(retobj))
	pcall(cluster.send, "master", ".balprivateroommgr", "syncUserState2DeskCache", deskInfo.gameid, deskInfo.deskid, user.uid, auto)
end


local function user_set_timeout(ti, f,parme)
    local function t()
        if f then
            f(parme)
        end
    end
    skynet.timeout(ti, t)
    return function(parme) f=nil end
end

-- 设置定时器
local function setTimer(uid, delayTime, f, params)
    local function t()
        if f then
            f(params)
        end
    end
    skynet.timeout(delayTime*100, t)
    usersAutoFuc[uid] = {
        -- 存储取消函数
        cancel = function(params) f=nil end,
        -- 存储过期时间，方便取消和恢复
        expireTime = delayTime + os.time(),
        -- 存储计算函数
        runFunc = f,
        -- 存储计算参数
        runParams = params
    }
end

-- 暂停定时器
local function pauseTimer()
    for _, user in ipairs(deskInfo.users) do
        local timer = usersAutoFuc[user.uid]
        if timer then
            if timer.cancel then
                timer.cancel()
                timer.cancel = nil
            end
            if timer.expireTime >= os.time() then
                timer.leftTime = timer.expireTime - os.time() + 1
            else
                timer.leftTime = nil
            end
        end
    end
end

-- 恢复定时器
local function recoverTimer()
    local autoTime = 0
    for _, user in ipairs(deskInfo.users) do
        local timer = usersAutoFuc[user.uid]
        if timer then
            if timer.leftTime and timer.leftTime > 0 then
                setTimer(user.uid, timer.leftTime, timer.runFunc, timer.runParams)
                autoTime = timer.leftTime
                timer.leftTime = nil
            end
        end
    end
    deskInfo.round.autoExpireTime = os.time() + autoTime
end

-- 机器人回收
local function RecycleAi(user)
	if not user.cluster_info then
		pcall(cluster.send, "ai", ".aiuser", "recycleAi",user.uid, user.score, os.time()+10, deskInfo.deskid)
	end
end

-- 房间内是否还有真人
local function hasRealPlayer()
    local hasPlayer = false
    for _, u in ipairs(deskInfo.users) do
        if u.cluster_info then
            hasPlayer = true
        end
		-- 特殊房间，只要房主在，不管是不是真人
        if deskInfo.conf.spcial == 1 and u.uid == deskInfo.owner then
            hasPlayer = true
        end
    end
    return hasPlayer
end

local function initAiCoin()
    local coin = math.random(100000,999999)
    -- 如果是好友房，则是底注的100-200倍
    -- 如果是匹配房，则是最高注的一半到最高注，如果是最高房，则是底注的100-200倍
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        coin = deskInfo.bet * math.random(100, 200)
    elseif deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        local cfg = PDEFINE_GAME.SESS.match[deskInfo.gameid][deskInfo.ssid]
        if cfg.section[2] < 0 then
            coin = deskInfo.bet * math.random(100, 200)
        else
            coin = math.floor(cfg.section[2]*math.random(50, 100)/100)
        end
    end
    return coin
end

-- 检测金币是否已经达到危险值
local function checkDangerCoin(user)
    if not user.cluster_info or user.isexit == 1 then
        return
    end
    local dangerUids = {}
    -- 好友房和匹配房踢人的门槛不同，所以分开判断
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        local bet = PDEFINE_GAME.SESS['match'][deskInfo.gameid][user.ssid].entry
        if user.coin - PDEFINE_GAME.SESS['match'][deskInfo.gameid][user.ssid].section[1] < (PDEFINE_GAME.DANGER_BET_MULT-1)*bet then
            table.insert(dangerUids, user.uid)
        end
    else
        if user.coin < PDEFINE_GAME.DANGER_BET_MULT*deskInfo.bet then
            table.insert(dangerUids, user.uid)
        end
    end
    if #dangerUids > 0 then
        local notify_object = {}
        notify_object.c = PDEFINE.NOTIFY.PLAYER_DANGER_COIN
        notify_object.code = PDEFINE.RET.SUCCESS
        notify_object.dangerUids = dangerUids
		if user.isexit == 0 then
			pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(notify_object))
		end
    end
end


-- 清除玩家定时器
local function clearAutoFunc(uid)
    local timer = usersAutoFuc[uid]
    if timer and timer.cancel then
        timer.cancel()
    end
    usersAutoFuc[uid] = nil
    deskInfo.round.autoExpireTime = nil
end

-- 回收桌子
local function resetDesk(isDismiss)
	cs(function()
		for _,user in pairs(deskInfo.users) do
			RecycleAi(user)
		end
		if not isDismiss then
			agentState = false
			skynet.call(".dsmgr", "lua", "recycleAgent", skynet.self(), deskInfo.deskid, deskInfo.gameid, deskInfo.ssid, deskInfo.maxRound)
			pcall(cluster.send, "master", ".userCenter", "updateRoomStatusInChat", deskInfo.deskid, deskInfo.gameid, deskInfo.cid)
		end
		local uids = {}
		for _, user in ipairs(deskInfo.users) do
			if user.cluster_info then
				table.insert(uids, user.uid)
			end
		end
		pcall(cluster.send, "master", ".mgrdesk", "unlockPlayer", deskInfo.deskid, uids, deskInfo.gameid, deskInfo.conf.roomtype)
		if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE and not isDismiss then
            pcall(cluster.send, "master", ".balprivateroommgr", "removeRoom", deskInfo.deskid, deskInfo.gameid)
        end
		if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE and isDismiss then
			localFunc.prepareNewTrun(true)
            LOG_DEBUG("不需要解散房间, 继续游戏:", deskInfo.deskid)
		else
			deskInfo.users = {}
			deskInfo.views = {}
		end
	end)
end

-- recycle desk 没人自动回收房间
local function autoRecycleDesk()
    if autoRecycleInfo.func then
        autoRecycleInfo.func()
    end
    local delayTime = PDEFINE_GAME.AUTO_DISMISS_TIME
	-- 如果是特殊房间，则10分钟才解散
    if deskInfo.conf.spcial and deskInfo.conf.spcial == 1 then
        delayTime = delayTime + 5*60
    end
    autoRecycleInfo.func = user_set_timeout(delayTime*100, function()
		local notify_retobj = { c=PDEFINE.NOTIFY.GAME_DISMISS_ROOM, code = PDEFINE.RET.SUCCESS, deskid=deskInfo.deskid }
        broadcastDesk(cjson.encode(notify_retobj))
        resetDesk()
    end)
    autoRecycleInfo.resetTime = os.time() + delayTime
end

-- 有人加入的时候暂停回收房间
local function stopAutoRecycleDesk()
    if autoRecycleInfo.func then
        autoRecycleInfo.func()
        autoRecycleInfo = {}
    end
end

-- 分配座位号
local function getSeatId()
	deskInfo.curseat = deskInfo.curseat + 1
	return table.remove(SEATID_LIST)
end

--玩家金币变化
local function localUserCalCoinFunc(user, ctype, changeCoin)
	user.coin = user.coin + changeCoin
	debug_log("localUserCalCoinFunc user.uid:", user.uid, ' changeCoin:', changeCoin)
    if user.cluster_info then
        player_tool.calUserCoin(user.uid, changeCoin, deskInfo.gameid .." baloot修改金币:"..changeCoin, ctype, deskInfo)
    end
end

-- 播放走马灯
local function winNotifyLobby(coin, uid, gameid)
    -- 如果赢取的金币大于20W则需要全服广播
    if coin > 20*10000 then
        pcall(cluster.send, "master", ".userCenter", "winCoinNotice", uid, gameid, coin)
    end
end

-- 寻找下一个座位号
local function findNextSeat(seatid)
	local tryCnt = deskInfo.seat
    while tryCnt > 0 do
        seatid = seatid + 1
        if seatid > deskInfo.seat then seatid = 1 end
        for _,user in pairs(deskInfo.users) do
            if user.seatid == seatid then
                return user.seatid
            end
        end
        tryCnt = tryCnt - 1
    end
    return -1
end


local function updateDataToDB(status)
	local sql = string.format( "update d_desk_game set `status`=2 where uuid='%s'", deskInfo.uuid)
	if status == 1 then
		local users = {}
		for _, muser in pairs(deskInfo.users) do 
			table.insert(users, {
				['uid'] = muser.uid,
				['seatid'] = muser.seatid,
			})
		end
		sql = string.format( "update d_desk_game set users='%s', `status`=%d where uuid='%s'", cjson.encode(users), status, deskInfo.uuid)
	end
	debug_log("updateDataToDB sql:", sql)
	skynet.call(".mysqlpool", "lua", "execute", sql)
end

-- 记录解散
---@param type number PDEFINE.GAME.DISMISS_RESULT_TYPE
local function recodeDismissInfo(status, uid)
    local sql = nil
    if status == PDEFINE.GAME.DISMISS_STATUS.Waiting then
        sql = string.format([[
            insert into d_desk_dismiss
                (deskid,uuid,gameid,uid,status,create_time,update_time)
            values
                (    %d,  %s,    %d, %d,    %d,         %d,         %d);
        ]], deskInfo.deskid, deskInfo.uuid, deskInfo.gameid, uid, status, os.time(), os.time())
    else
        sql = string.format([[
            update d_desk_dismiss set status=%d,update_time=%d where gameid=%d and uuid=%s and uid=%d order by id desc limit 1;
        ]], status, os.time(), deskInfo.gameid, deskInfo.uuid, uid)
    end
    debug_log("recodeDismissInfo sql:", sql)
    skynet.call(".mysqlpool", "lua", "execute", sql)
end

-- 查找用户信息
local function queryUserInfo(value, tag)
    -- 如果已经回收了，则返回空
    if not agentState then
        return nil
    end
    if nil == tag then
        tag = 'uid'
    end
	if tag == "uid" then
		for _, user in pairs(deskInfo.users) do
			if user.uid == value then
				return user
			end
		end
	elseif tag == "seatid" then
		for _, user in pairs(deskInfo.users) do
			if user.seatid == value then
				return user
			end
		end
	end
	return nil
end

-- 获取观战对象
local function findViewUser(uid)
    -- 如果已经回收了，则返回空
    if not agentState then
        return nil
    end
    for _, user in pairs(deskInfo.views) do
        if user.uid == uid then
            return user
        end
    end
    return nil
end

-- 检查是否可以开始
local function checkCanStart()
    if deskInfo.conf.roomtype ~= PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        return 0
    end
    local can_start = 1  -- 是否可以开始
    for _, muser in ipairs(deskInfo.users) do
        if muser.state ~= balcfg.UserState.Ready then
            can_start = 0
            break
        end
    end
    -- 如果人数少于最小人数，或者没有最小人数这个参数，则不能开始
    if not deskInfo.minSeat or #deskInfo.users < deskInfo.minSeat then
        can_start = 0
    end
    return can_start
end

--把玩家放入桌子列表中
local function pushUserToUserList(userInfo)
	-- 如果没有分配到座位号，则不能加入
    if not userInfo.seatid then
        if userInfo.cluster_info then
            pcall(cluster.send, userInfo.cluster_info.server, userInfo.cluster_info.address, "deskBack", deskInfo.gameid) --释放桌子对象
        end
        return
    end
	table.insert(deskInfo.users, userInfo)
	-- 好友房,如果有玩家进入，需要取消开始倒计时
	if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
		stopAutoRecycleDesk()
		if #deskInfo.users == deskInfo.conf.seat then
			LOG_DEBUG("pushUserToUserList setAutoKickOut")
            localFunc.setAutoKickOut()
        end
	end
	pcall(cluster.send, "master", ".mgrdesk", "syncMatchCurUsers", GAME_NAME, deskInfo.gameid, deskInfo.deskid, #deskInfo.users)

	-- 检测金币不足
    skynet.timeout(50, function()
        checkDangerCoin(userInfo)
    end)
end

--------加载场次信息 ---------
local function loadSessInfo(uid, recobj, seatid)
	LOG_DEBUG("loadSessInfo conf:", recobj)
	-- deskInfo.gameid = PDEFINE.GAME_TYPE.BALOOT
	local conf = recobj.conf or {}
	deskInfo.conf = conf
	deskInfo.panel.roundscore = {0, 0}
	-- deskInfo.panel.score = {0, 0}
	deskInfo.panel.gametype = 0
	deskInfo.panel.suit = -1
	deskInfo.panel.uid = 0
	deskInfo.panel.gahwa = 0 --是否1把定输赢
	deskInfo.panel.open = 0
	deskInfo.panel.multiple = 0
	deskInfo.bet = conf.bet or 0 -- 押注
	deskInfo.ssid = recobj.ssid
	deskInfo.maxRound = recobj.maxRound
	deskInfo.panel.prize  = 0 -- 当前场次奖金
	deskInfo.seat         = 4
	deskInfo.in_settle    = false
	deskInfo.state        = PDEFINE.DESK_STATE.READY
    deskInfo.curseat      = 0
    deskInfo.curround     = 0
	deskInfo.round = {}
    deskInfo.round.putNextSeat = 0 --下1个出牌的位置
    deskInfo.round.showCard = {} --当前轮出的4张手牌
	deskInfo.round.showCardUsers = {} --出牌人的对应关系
	deskInfo.round.discardCards = {}  -- 已经出过的牌
	deskInfo.round.lastSeatid = nil  -- 上轮最后一个出牌的人
	deskInfo.round.selecttimes = 0 --这轮选择玩法的次数 如果2次都是pass循环，则重新轮庄发牌
	deskInfo.round.settle = initSettleData() -- 1和3；2和4
	deskInfo.round.choose = {} --每轮选择
	deskInfo.round.hokomer = {uid = 0,seatid = 0,}
	deskInfo.round.multiple = 1 --房间倍数
	deskInfo.round.passtimes = 0 --当sun翻倍的时候，需要2人都pass了才能开始
	deskInfo.round.sundouble = {}
	deskInfo.round.nextuids = {} --下一步操作的uids
	deskInfo.round.actuid = 0 --中间定玩法的人
	deskInfo.round.actgametype = 0 --中间定的玩法

	deskInfo.maxView      = PDEFINE_GAME.MAX_VIEW_NUM  -- 观战人数
	if seatid then
        deskInfo.round.dealer = { ----此把的庄家(庄家的下家选牌型和出牌)
            ['uid'] = uid,
            ['seatid'] = seatid
        }
    end
	if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
		deskInfo.panel.prize = PDEFINE_GAME.SESS.match[deskInfo.gameid][deskInfo.ssid].reward
		deskInfo.bet = PDEFINE_GAME.SESS.match[deskInfo.gameid][deskInfo.ssid].entry
	elseif deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
		deskInfo.bet = deskInfo.conf.entry
		deskInfo.panel.prize = math.floor((deskInfo.bet * deskInfo.seat) / 2 * 0.9)
	end

	if conf and conf.minSeat then
        deskInfo.minSeat = tonumber(conf.minSeat)
	else
		deskInfo.minSeat = 4
    end

	firstDelay = true
end

local function initUser(seatid, tbl, cluster_info)
	local nextSeatId = seatid + 1
	if nextSeatId > 4 then
		nextSeatId = 1
	end
	local userObj        = {}
	if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
		userObj.prize        = PDEFINE_GAME.SESS.match[deskInfo.gameid][tbl.ssid].reward
	else
		userObj.prize = deskInfo.panel.prize
	end
	userObj.ssid         = tbl.ssid --用户选择的场次信息
	userObj.settlewin    = tbl.settlewin or 0 --输赢次数
	userObj.wincoin      = 0 --输赢金币(真实)
	userObj.wincoinshow  = 0 --输赢金币(显示用)
	userObj.uid          = tbl.uid
	userObj.playername   = tbl.nick
	userObj.usericon     = tbl.icon
	userObj.level        = tbl.level or 1
	userObj.avatarframe  = tbl.avatarframe or PDEFINE.SKIN.DEFAULT.AVATAR.img
	userObj.levelexp     = tbl.levelexp or 0
	userObj.token        = tbl.token or ''
	userObj.leagueexp    = tbl.leagueexp or 0
	userObj.leaguelevel  = tbl.leaguelevel or 0
	userObj.chatskin   = tbl.chatskin or PDEFINE.SKIN.DEFAULT.CHAT.img
	userObj.seatid       = seatid --符合条件的才有座位
	userObj.nextseatid   = nextSeatId
	userObj.svipexp      = tbl.svipexp
	userObj.svip         = tbl.svip
	userObj.offline      = 0 --是否掉线 1是 0否
	userObj.auto         = 0 --是否自动状态
	userObj.isexit       = 0 --是否已退出
	userObj.mic          = 0 -- 麦克风状态 1是 0否
	userObj.race_id      = 0 -- 是否是赛事用户
	userObj.race_type    = 0 -- 计分类型
	userObj.coin         = tbl.coin
	userObj.diamond      = tbl.diamond or 0
	userObj.rp           = tbl.rp or 0
	userObj.leavetime   = tbl.leavetime or 0 --停留时间(单位s)
	userObj.score        = 0 --这1局的score 分数
	userObj.winTimes = 0 --赢牌次数
	userObj.state       = balcfg.UserState.Wait -- 玩家状态
	userObj.autoStartTime = nil -- 托管开始时间
	userObj.autoTotalTime = 0 -- 当局游戏处于托管的时间
	userObj.round = {}
	userObj.round.roundscore = 0 --轮分
	userObj.round.floor = 0 -- 底分
	userObj.round.projects = 0 --projects 分数
	userObj.round.points = 0 --points = roundscore + floor + projects
	userObj.round.projectslist = {} -- projects明细
	userObj.round.cards = {} --刚发的8张手牌
	userObj.round.handInCards = {} --手牌
	userObj.round.outCards = {} --出牌
	if cluster_info then
		userObj.cluster_info = cluster_info
	end
	return userObj
end

-- 玩家准备阶段退出房间，
local function userExit(uid, seatid, spcode)
    local currUser
	-- 清理身上的定时器
    clearAutoFunc(uid)
	local exitNotifyMsg = { c=PDEFINE.NOTIFY.PLAYER_EXIT_ROOM, code = PDEFINE.RET.SUCCESS, uid = uid, seatid = seatid, spcode = spcode}

	broadcastDesk(cjson.encode(exitNotifyMsg))
    for i=#deskInfo.users, 1, -1 do
        if deskInfo.users[i].uid == uid then
            currUser = deskInfo.users[i]
            if not table.contain(SEATID_LIST, deskInfo.users[i].seatid) then
                table.insert(SEATID_LIST, deskInfo.users[i].seatid)
            end
            table.remove(deskInfo.users, i)
			deskInfo.curseat = deskInfo.curseat - 1
			-- 如果是庄家，则将庄家置空
			if deskInfo.round.dealer and currUser.uid == deskInfo.round.dealer.uid then
				-- deskInfo.round.dealer = nil
				if #deskInfo.users > 0 then
					local maxcnt = #deskInfo.users
					local dealer = deskInfo.users[math.random(1, maxcnt)]
					deskInfo.round.dealer = { ----此把的庄家(庄家的下家选牌型和出牌)
						['uid'] = dealer.uid,
						['seatid'] = dealer.seatid
					}
				end
			end
            break
        end
    end
	-- 广播麦克风状态
	localFunc.updateMicStatus()
	-- 回收机器人
    if currUser and not currUser.cluster_info then
        RecycleAi(currUser)
    end

	if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
		pcall(cluster.send, "master", ".balprivateroommgr", "exitRoom", deskInfo.deskid, deskInfo.gameid, uid)
		-- 加机器人的房间，退出房间在另外一个地方判断
        if not isJoinAI() then
            -- 判断下房间人数，如果符合最低要求则直接开始
            local can_start = checkCanStart()
            if can_start == 1 then
                localFunc.startGame()
            end
		else
			localFunc.autoStartGame()
        end
		-- 房间没人则开启倒计时解散
		if #deskInfo.users == 0 then
			autoRecycleDesk()
		end
	end
end

-- recycle desk 没人自动回收房间
local function setAutoKickOut()
    if autoKickOutInfo.func then
        autoKickOutInfo.func()
    end
    local delayTime = PDEFINE_GAME.AUTO_KICK_OUT_TIME
    autoKickOutInfo.func = user_set_timeout(delayTime*100, function()
        if deskInfo.state == PDEFINE.DESK_STATE.MATCH or deskInfo.state == PDEFINE.DESK_STATE.READY then
			local tmpUsers = {}
            for _, u in ipairs(deskInfo.users) do
                table.insert(tmpUsers, u)
            end
            for _, u in ipairs(tmpUsers) do
                if (deskInfo.state == PDEFINE.DESK_STATE.MATCH or deskInfo.state == PDEFINE.DESK_STATE.READY) and u.state ~= PDEFINE.PLAYER_STATE.Ready then
                    userExit(u.uid, u.seatid, PDEFINE.RET.ERROR.TIMEOUT_KICK_OUT)
                    if u and u.cluster_info then
                        local ok = pcall(cluster.call, u.cluster_info.server, u.cluster_info.address, "deskBack", deskInfo.gameid) --释放桌子对象
						if not ok then
                            pcall(cluster.send, "master", ".agentdesk", "removeDesk", u.uid, deskInfo.deskid)
                        end
                    end
                end
            end
        end
    end)
    autoKickOutInfo.resetTime = os.time() + delayTime
end

-- 有人加入的时候暂停回收房间
local function stopAutoKickOut()
    if autoKickOutInfo.func then
        autoKickOutInfo.func()
        autoKickOutInfo = {}
    end
end

-- 删除某位观战人员
local function removeViewUser(uid)
    local idx = nil
    for i, u in ipairs(deskInfo.views) do
        if u.uid == uid then
            idx = i
            break
        end
    end
    if idx then
        table.remove(deskInfo.views, idx)
		pcall(cluster.send, "master", ".balprivateroommgr", "exitView", deskInfo.deskid, {uid}, deskInfo.gameid, true)
    end
end

-- 处理观战人退出
local function viewExit(uid)
    local user
    for i, u in ipairs(deskInfo.views) do
        if u.uid == uid then
            user = u
            table.remove(deskInfo.views, i)
            break
        end
    end
	if user then
        -- 回收座位号
        if user.seatid > 0 and not table.contain(SEATID_LIST, user.seatid) then
            table.insert(SEATID_LIST, user.seatid)
        end
        local exitNotifyMsg = { c=PDEFINE.NOTIFY.PLAYER_VIEWER_EXIT_ROOM, code = PDEFINE.RET.SUCCESS, uid = uid, seatid = user.seatid, spcode = 0}
        broadcastDesk(cjson.encode(exitNotifyMsg))
		pcall(cluster.send, "master", ".balprivateroommgr", "exitView", deskInfo.deskid, {uid}, deskInfo.gameid, false)
    end
end

-- 添加可以出ace提示的标记
local function addAceTipsFlag(user)
	user.round.ace_flag = 0
	if deskInfo.panel.gametype == balcfg.TYPE.HOKOM then
		for _, card in pairs(user.round.cards) do
			if getCardColor(card) ~= deskInfo.panel.suit then
				local val = getCardValue(card)
				if val == 10 or val == 14 then
					user.round.ace_flag = 1
					break
				end
			end
		end
	end
end

-- 自动选择花色
local function autoChooseSuit(uid)
	LOG_DEBUG("user will autoChooseSuit:", uid, ' nextgametype:', deskInfo.round.nexgametype)
		clearAutoFunc(uid)

		local user = queryUserInfo(uid, 'uid')
		local delayTime = 1
        if user.cluster_info and user.auto == 0 then
            user.auto = 1
            delayTime = AutoDelayTime
            brodcastUserAutoMsg(user, 1)
        end
        -- 如果是进入托管，则延后一点操作
		skynet.timeout(delayTime, function()
			local msg = {
				['c'] = 25607,
				['uid'] = uid,
				['color'] = 0,
			}
			local selectItems = deskInfo.round.nexgametype
			local item = selectItems[math.random(1, #selectItems)]
			local user = queryUserInfo(uid, 'uid')
			if not user.cluster_info then
				local maxColor, _  = balootutil.calColorCnt(user.round.cards)
				if table.contain(selectItems, maxColor) then
					item = maxColor
				end
			end
			msg['color'] = item
			return CMD.chooseSuit(_, msg)
		end)
end

-- 自动选择玩法
local function autoChooseGameType(uid)
	clearAutoFunc(uid)
	LOG_DEBUG("user will autochoosegametype:", uid, ' nextgametype:', deskInfo.round.nexgametype)
	local msg = {
		['c'] = 25601,
		['uid'] = uid,
		['gametype'] = balcfg.TYPE.PASS,
	}
	local user = queryUserInfo(uid, 'uid')
	local selectItems = deskInfo.round.nexgametype
	local item = selectItems[math.random(1, #selectItems)]
	LOG_DEBUG("user will autochoosegametype:", uid, ' nextgametype:', deskInfo.round.nexgametype, ' user.cluster_info:', user.cluster_info)
	if user.cluster_info then
		msg['gametype'] = item
		
		local delayTime = 1
		if user.auto == 0 then
			user.auto = 1 --用户进入自动状态
			delayTime = AutoDelayTime
			brodcastUserAutoMsg(user, 1)
		end
		debug_log("用户进入自动选择牌型状态 uid:".. uid, ' selectItems:', selectItems, ' delayTime:', delayTime)
		skynet.timeout(delayTime, function()
			if table.contain(selectItems, balcfg.TYPE.OPEN) then --open/lock
				local item = selectItems[math.random(1, #selectItems)]
				msg = {
					['c'] = 25604,
					['uid'] = uid,
					['item'] = item,
					['gametype'] = balcfg.TYPE.PASS,
				}
				return CMD.actLockOrOpen(_, msg)
			end

			if table.contain(selectItems, balcfg.TYPE.PASS) then
				msg['gametype'] = balcfg.TYPE.PASS
				return CMD.chooseGameType(nil, msg)
			end
			local item = selectItems[math.random(1, #selectItems)]
			msg['gametype'] = item
			return CMD.chooseGameType(_, msg)
		end)
		return
	else
		if table.contain(selectItems, balcfg.TYPE.OPEN) then --open/lock
			local item = selectItems[math.random(1, #selectItems)]
			msg = {
				['c'] = 25604,
				['uid'] = uid,
				['item'] = item,
			}
			return CMD.actLockOrOpen(_, msg)
		end

		if deskInfo.conf.isLucky then
			if table.contain(selectItems, balcfg.TYPE.PASS) then
				msg['gametype'] = balcfg.TYPE.PASS
				return CMD.chooseGameType(_, msg)
			end
		end

		if DEBUG then
			if table.contain(selectItems, balcfg.TYPE.SUN) then --sun玩法选择
				local goodCnt = balootutil.calATenCount(user.round.cards)
				if goodCnt >= 5 and math.random(1, 1000) <= 800  then
					msg['gametype'] = balcfg.TYPE.SUN
					return CMD.chooseGameType(_, msg)
				end
			end

			local _, maxCnt = balootutil.calColorCnt(user.round.cards)
			if maxCnt >= 5 and math.random(1, 1000) <= 800  then
				if table.contain(selectItems, balcfg.TYPE.HOKOM) then -- hokom玩法选择
					msg['gametype'] = balcfg.TYPE.HOKOM
					return CMD.chooseGameType(_, msg)
				end
				if table.contain(selectItems, balcfg.TYPE.SECOND) then -- hokom玩法选择
					msg['gametype'] = balcfg.TYPE.SECOND
					return CMD.chooseGameType(_, msg)
				end
				if table.contain(selectItems, balcfg.TYPE.CONFIRM) then -- hokom玩法选择
					msg['gametype'] = balcfg.TYPE.CONFIRM
					return CMD.chooseGameType(_, msg)
				end
			end
		end

		if table.contain(selectItems, balcfg.TYPE.PASS) then
			msg['gametype'] = balcfg.TYPE.PASS
			return CMD.chooseGameType(_, msg)
		end
		msg['gametype'] = item
		return CMD.chooseGameType(_, msg)
	end
end

local EMOJI_SEND_TIME = {}
local function isParter(uid, toUid)
	local a = queryUserInfo(uid, 'uid')
	local b = queryUserInfo(toUid, 'uid')
	if (a.seatid == 1 and b.seatid ==3) or (a.seatid==3 and b.seatid==1) or (a.seatid==2 and b.seatid==4) or (a.seatid==4 and b.seatid==3) then
		return true
	end
	return false
end

local function aiSendTextChat()
    local aiUids = {}
    for _, muser in pairs(deskInfo.users) do
        if not muser.cluster_info then
            table.insert(aiUids, muser.uid)
        end
    end
    if #aiUids == 0 then
        return
    end
    local auid = aiUids[math.random(#aiUids)]
    local userInfo = queryUserInfo(auid, 'uid')
    local retobj = buildChatMsg(userInfo, math.random(0, 6))
    broadcastDesk(cjson.encode(retobj))
end

local function aiSendEmoji()
	if math.random() < PDEFINE.EMOJI.PROB then --控制自动赠送的百分比
		-- 如果没发emoji, 则判断是否发文字消息
        if math.random() > PDEFINE.EMOJI.TEXT then
			aiSendTextChat()
        end
		return
	end
	local aiUids = {}
	for _, muser in pairs(deskInfo.users) do
		if not muser.cluster_info then
			table.insert(aiUids, muser.uid)
		end
	end
	if #aiUids == 0 then
        return
    end
	local auid = aiUids[math.random(1, #aiUids)]

	local nowtime = os.time()
	if nil ~= EMOJI_SEND_TIME[auid] then
		if (nowtime - EMOJI_SEND_TIME[auid]) < 15 then --每个人间隔最少xs
			return
		end
	end
	EMOJI_SEND_TIME[auid] = nowtime
	
	local friendEmoji = PDEFINE.EMOJI.FRIEND -- 给队友的
	local otherEmoji = PDEFINE.EMOJI.RIVAL
	local emojiId = math.random(1, #PDEFINE.EMOJI.ALL)
	local userInfo = queryUserInfo(auid, 'uid')
	local playeruids = {}
	for _, muser in pairs(deskInfo.users) do
		if muser.uid ~= auid then
			table.insert(playeruids, muser.uid)
		end
	end
	local idx = math.random(1,#playeruids)
	local toUid = playeruids[idx]

	if math.random(1, 1000) < 700 then
		if isParter(auid, toUid) then
			emojiId = friendEmoji[math.random(1, #friendEmoji)]
		else
			emojiId = friendEmoji[math.random(1, #otherEmoji)]
		end
	end
	-- 需要扣掉相应的金币
	if PDEFINE.EXPRESSION[emojiId] then
		if userInfo.coin < PDEFINE.EXPRESSION[emojiId].count then
			return
		end
		userInfo.coin = userInfo.coin - PDEFINE.EXPRESSION[emojiId].count
	end
	local retobj = buildEmojiMsg(userInfo, emojiId, toUid)
	broadcastDesk(cjson.encode(retobj))
	-- broadcastView(cjson.encode(retobj))
end

-- 取消解散操作
-- 如果遇到大结算，则会取消解散操作
local function cancelDismiss()
    if deskInfo.dismiss then
        -- 记录到数据库
        recodeDismissInfo(PDEFINE.GAME.DISMISS_STATUS.Refuse, deskInfo.dismiss.uid)
        -- 不同意
        deskInfo.dismiss._autoFunc()
        deskInfo.dismiss = nil
    
        -- 恢复用户身上的定时器
        recoverTimer()
        local retobj = { c=PDEFINE.NOTIFY.GAME_DISMISS_CANCEL, code = PDEFINE.RET.SUCCESS, deskid=deskInfo.deskid }
        broadcastDesk(cjson.encode(retobj))
    end
end

-- 自动出牌
local function autoPutCard(uid)
		debug_log("用户自动出牌 uid:".. uid)
		clearAutoFunc(uid)

		local user = queryUserInfo(uid, 'uid')
		if deskInfo.round.putNextSeat ~= user.seatid then
			debug_log("不是她出牌呀：uid:", uid, ' seatid:', user.seatid, " nextSeatId:", deskInfo.round.putNextSeat)
			return
		end
		local delayTime = 1
		if user.cluster_info then
			delayTime = AutoDelayTime
			user.auto = 1
			brodcastUserAutoMsg(user, 1)
		end
		debug_log("uid:", uid, ' 随机自动出牌 after brodcastUserAutoMsg delayTime:', delayTime)
		skynet.timeout(delayTime, function()
			local outCard = balootutil.aiPutCard(user, deskInfo)
			debug_log("uid:", uid, ' 随机自动出牌 outCard:', outCard)
			local msg = {
				['c'] = 25602,
				['uid'] = uid,
				['card'] = outCard,
				['is_auto'] = 1
			}
			return CMD.putCard(nil, msg)
		end)
end

-- 自动准备
local function autoReady(uid)
        debug_log("自动准备 uid:".. uid)
        clearAutoFunc(uid)

        local user = queryUserInfo(uid, 'uid')
        if not user and user.state == balcfg.UserState.Ready then
            return 
        end

        local msg = {
            ['c'] = 25708,
            ['uid'] = uid,
        }
        CMD.ready(nil, msg)
end

-- 删除手牌
local function delHandCards(user, ocard)
	cs(function()
		for i= #user.round.handInCards, 1, -1 do
			if user.round.handInCards[i] == ocard then
				table.remove(user.round.handInCards, i)
				break
			end
		end
	end)
end


--! agent退出
function CMD.exit()
	if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.VIP then
		pcall(cluster.send, "master", ".balviproommgr", "syncVipRoomData", deskInfo.gameid, deskInfo.deskid, deskInfo.users, deskInfo.panel.score)
	end
	
	collectgarbage("collect")
	skynet.exit()
end

-------- 更改房间阶段状态(0游戏未开始  1开始发牌 2开始下注 3停止下注结算中) --------
local function changeDeskState(state)
    deskInfo.state = state
    pcall(cluster.send, "master", ".mgrdesk", "changeMatchDeskStatus", GAME_NAME, deskInfo.gameid, deskInfo.deskid, deskInfo.state)
end

local function genCardLIB()
    CURRENT_CARD_LIB = table.copy(balcfg.CARDS);
    for i = 1,#CURRENT_CARD_LIB do
        local ranOne = math.random(1,#CURRENT_CARD_LIB+1-i)
        CURRENT_CARD_LIB[ranOne], CURRENT_CARD_LIB[#CURRENT_CARD_LIB+1-i] = CURRENT_CARD_LIB[#CURRENT_CARD_LIB+1-i],CURRENT_CARD_LIB[ranOne]
    end
end

-- 生成sun 或 ashkal 的发牌顺序, 庄家的下家开始发牌
local function getDealCardSeatIdList(nextSeatId)
	local rangeSeatId = {1,2,3,4} -- 最下方是1, 逆时针1,2,3,4
	local seatidList = {} --发牌的位置顺序
	for seatid in ipairs(rangeSeatId) do
		if seatid >= nextSeatId then
			table.insert(seatidList, seatid)
		end
	end
	for seatid in ipairs(rangeSeatId) do
		if seatid < nextSeatId then
			table.insert(seatidList, seatid)
		end
	end
	return seatidList
end

local function getParterSeatid(user)
	local seatIdList = {1,3}
	if user.seatid % 2 == 0 then
		seatIdList = {2, 4}
	end
	for _, seatid in pairs(seatIdList) do
		if seatid ~= user.seatid then
			return seatid
		end
	end
end

-- 选定了玩法，发剩余牌，开始游戏
local function endChooseGameTypeRunGame(uid, stype)
	debug_log("endChooseGameTypeRunGame uid:", uid , ' stype:', stype)
    deskInfo.state = PDEFINE.DESK_STATE.PLAY

	for _, muser in pairs(deskInfo.users) do
		clearAutoFunc(muser.uid)
	end

	deskInfo.panel.gametype = stype
	deskInfo.panel.uid = uid
	if stype ~= balcfg.TYPE.HOKOM then
		deskInfo.panel.suit = -1
	else
		deskInfo.panel.uid = deskInfo.round.hokomer['uid']
	end
	deskInfo.round.choose = {}
	deskInfo.round.multipler = 0
	deskInfo.round.tmpgametype = 0
	deskInfo.round.road = 0
	deskInfo.round.nextuids = {}

	if deskInfo.round.multiple > 1 then
		deskInfo.panel.multiple = deskInfo.round.multiple
	end

	local user = queryUserInfo(uid, 'uid')
	local showCard = table.remove(CURRENT_CARD_LIB) --倒数第1张为第21张牌
	local round = 2
	local showUid = 0
	if stype == balcfg.TYPE.SUN or stype == balcfg.TYPE.HOKOM then
		table.insert(user.round.handInCards, showCard) --第1张牌给叫sun或hokom的人
		showUid = user.uid
	else
		local parterSeatId = getParterSeatid(user) --ashkal玩法，亮的牌给对门
		local parter = queryUserInfo(parterSeatId, 'seatid')
		table.insert(parter.round.handInCards, showCard)
		showUid = parter.uid
	end

	local nextSeatId = findNextSeat(deskInfo.round.dealer['seatid'])
	local nextUser = queryUserInfo(nextSeatId, 'seatid')
	deskInfo.round.putNextSeat = nextSeatId--庄家的下家开始出牌
	local seatIdList = getDealCardSeatIdList(nextSeatId) --发剩余牌，从庄家下家开始逆时针发

	local viewRetobj = nil
	for _, seatid in ipairs(seatIdList) do
		local tmpCard = {}
		local muser = queryUserInfo(seatid, 'seatid')
		debug_log("endChooseGameTypeRunGame 发牌: uid:", muser.uid, " seatid:", seatid, ' user:', muser)
		if muser.uid == showUid then
			table.insert(tmpCard, showCard)
		end
		for i=#CURRENT_CARD_LIB, 1, -1 do
			local acard = table.remove(CURRENT_CARD_LIB)
			table.insert(muser.round.handInCards, acard)
			table.insert(tmpCard, acard)
			if #muser.round.handInCards == 8 then
				muser.round.cards = table.copy(muser.round.handInCards)
				addAceTipsFlag(muser)
				local sira = 0
				local tbl = balootutil.calSequence(muser.round.handInCards, deskInfo.panel.gametype, deskInfo.panel.suit)
				local siraselect
				if #tbl > 0 then
					siraselect = {}
					for _, val in pairs(tbl) do
						if val['score'] == 50 then
							table.insert(siraselect, 2)
						elseif val['score'] == 100 then
							table.insert(siraselect, 3)
						elseif val['score'] == 200 then
							table.insert(siraselect, 4)
						elseif val['score'] == 20 then
							if val['stype'] == 0 then
								muser.round.projects = muser.round.projects + val['score']
								table.insert(muser.round.projectslist, val)
							else
								table.insert(siraselect, 1)
							end
						end
					end
					if #siraselect > 0 then
						sira = 1
					end
				end
				local retobj = {c=PDEFINE.NOTIFY.BALOOT_CARD, code = PDEFINE.RET.SUCCESS, uid = muser.uid, seatid = muser.seatid, handcards=tmpCard, round=round, sira=sira, siradata = siraselect, deskid=deskInfo.deskid}
				retobj.panel = {
					['gametype'] = deskInfo.panel.gametype,
					['suit'] = deskInfo.panel.suit,
					['uid'] = deskInfo.panel.uid,
					['multiple'] = deskInfo.panel.multiple,
					['open'] = deskInfo.panel.open,
				}
				viewRetobj = retobj
				if muser.cluster_info and muser.isexit == 0 then
					pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", cjson.encode(retobj))
				end
				break
			end
		end
	end
	if viewRetobj then
		viewRetobj.handcards = {}
		viewRetobj.uid = nil
		broadcastView(cjson.encode(viewRetobj))
	end

	deskInfo.round.isfirst = true
	if nextUser.cluster_info then
		debug_log("bidding结束，开始自动出牌 uid:", nextUser.uid, ' timeout:', timeout)
		CMD.userSetAutoState('autoPutCard', timeout, nextUser.uid)
	else
		local randomTime = math.random(200, timeout)
		debug_log("bidding结束，开始自动出牌 机器人 uid:", nextUser.uid, ' timeout:', randomTime)
		CMD.userSetAutoState('autoAiPutCard', randomTime, nextUser.uid)
	end

	local retobj    = {}
	retobj.code     = PDEFINE.RET.SUCCESS
	retobj.c        = PDEFINE.NOTIFY.BALOOT_GAME_START
	retobj.seatid   = nextSeatId
	retobj.uid      = nextUser.uid
	retobj.timeout  = timeout // 100
	broadcastDesk(cjson.encode(retobj))
end



-- 开始发牌，选择玩法
-- 每个人逆时针发3张，再每个人发2张，然后亮1张牌，待选定玩法
local function beginChooseGameType()
	updateDataToDB(1)
	debug_log("================================beginChooseGameType=====================================")
    deskInfo.state = PDEFINE.DESK_STATE.BIDDING

    genCardLIB() --给桌子放打乱的牌
	local protect = false --保护策略
	if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH and deskInfo.ssid >2 then
		protect = (math.random(1, 1000) <= 400) and true or false --高场次保护系统策略
		if protect then
			local allTrueUser = true --都是真实用户
			for _, user in pairs(deskInfo.users) do
				if not user.cluster_info then
					allTrueUser = false
					break
				end
			end
			if allTrueUser then
				protect = false --如果都是真人，就关闭系统保护策略
			end
		end
	end
	if deskInfo.conf.isLucky then --保护新人策略
		protect = true
	end
	local userCard = {}
	-- local spUser = nil
	-- local spUids = {}
	-- local spUidStrs = do_redis({"smembers", "balootSpUid"})
	-- if spUidStrs then
	-- 	for _, spUid in pairs(spUidStrs) do
	-- 		table.insert(spUids, tonumber(spUid))
	-- 	end
	-- end
	-- for _, u in ipairs(deskInfo.users) do
	-- 	if table.contain(spUids, u.uid) then
	-- 		spUser = u
	-- 	end
	-- end
	-- if spUser and spUser.seatid == 1 then
	-- 	local spCards = {0x1E, 0x2E, 0x3E, 0x4E, 0x1D, 0x2D, 0x3D,0x4D, 0x1A, 0x2A, 0x3A, 0x4A}
	-- 	local randIdxs = genRandIdxs(#spCards, 5)
	-- 	for _, idx in ipairs(randIdxs) do
	-- 		table.insert(userCard, spCards[idx])
	-- 	end
	-- 	for i=#CURRENT_CARD_LIB, 1, -1 do
	-- 		if table.contain(userCard, CURRENT_CARD_LIB[i]) then
	-- 			table.remove(CURRENT_CARD_LIB, i)
	-- 		end
	-- 	end

	-- 	for i=1, #userCard do
	-- 		table.insert(CURRENT_CARD_LIB, table.remove(userCard))
	-- 	end
	-- elseif protect then
	if protect then
		local cards = {
			{0x1E, 0x2E, 0x3E, 0x3D, 0x3C}, 
			{0x1E, 0x3E, 0x3D, 0x3C, 0x3B}, 
			{0x1E, 0x1D, 0x1C, 0x1B, 0x3E}, 
			{0x1E, 0x1D, 0x2C, 0x2D, 0x2E},
			{0x4E, 0x4D, 0x4C, 0x2E, 0x2D},
			{0x4E, 0x4D, 0x4C, 0x1E, 0x3E},
			{0x2E, 0x2D, 0x2C, 0x3E, 0x4E},
			{0x3E, 0x3D, 0x3C, 0x1E, 0x4E},
			{0x2E, 0x2D, 0x3D, 0x1E, 0x3E},
			{0x4E, 0x4D, 0x1E, 0x1D, 0x2E},
			{0x4E, 0x4D, 0x3D, 0x3E, 0x1E},
			{0x4E, 0x4A, 0x1E, 0x1A, 0x2A},
			{0x4C, 0x4D, 0x1E, 0x1A, 0x2E},
			{0x3E, 0x3A, 0x2D, 0x2A, 0x2E},
			{0x2E, 0x2A, 0x1E, 0x1D, 0x1C},
			{0x1E, 0x1A, 0x1D, 0x1C, 0x2E},
			{0x4E, 0x4D, 0x4C, 0x4A, 0x1A},
		}
		local index = math.random(1, #cards)
		userCard = cards[index]
		for i=#CURRENT_CARD_LIB, 1, -1 do
			if table.contain(userCard, CURRENT_CARD_LIB[i]) then
				table.remove(CURRENT_CARD_LIB, i)
			end
		end

		if deskInfo.conf.isLucky then --如果创建者(座位1)是新人
			for i=1, #userCard do
				table.insert(CURRENT_CARD_LIB, table.remove(userCard))
			end
		end
	end
	deskInfo.show = CURRENT_CARD_LIB[12] --倒数第21张亮牌
    deskInfo.curround = deskInfo.curround + 1
    for _, user in pairs(deskInfo.users) do --发牌
		user.round.handInCards = {}
		if #userCard > 0 and not user.cluster_info then --保护系统策略生效
			user.round.handInCards = table.copy(userCard)
			userCard = {}
		else
			for i=#CURRENT_CARD_LIB, 1, -1 do
				table.insert(user.round.handInCards, table.remove(CURRENT_CARD_LIB))
				if #user.round.handInCards == 5 then
					break
				end
			end
		end
	end
	local viewRetobj = nil
    for i =1, #deskInfo.users do
        local user = deskInfo.users[i]
		local retobj = {c= PDEFINE.NOTIFY.BALOOT_CARD, code=PDEFINE.RET.SUCCESS, dealerid=deskInfo.round.dealer['uid'], uid = user.uid, seatid = user.seatid, handcards=user.round.handInCards, publicCard=deskInfo.show, round=1}
		viewRetobj = retobj
        if user.cluster_info and user.isexit==0 then  --直接发5张牌的通知
			pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(retobj))
        end
    end
	if viewRetobj then
		viewRetobj.handcards = {}
		viewRetobj.uid = nil
		broadcastView(cjson.encode(viewRetobj))
	end

	local seatid    = findNextSeat(deskInfo.round.dealer['seatid']) --下家出牌和选牌型
	local nextUser  = queryUserInfo(seatid, 'seatid')
	local retobj    = {}
	retobj.code     = PDEFINE.RET.SUCCESS
	retobj.c        = PDEFINE.NOTIFY.BALOOT_SELECT_START
	retobj.nextseat = seatid
	retobj.nextuid  = nextUser.uid
	retobj.timeout  =  math.floor(timeout/100)
	retobj.nextgametype = {balcfg.TYPE.HOKOM, balcfg.TYPE.SUN, balcfg.TYPE.PASS}
	broadcastDesk(cjson.encode(retobj)) --广播开始选玩法
	deskInfo.round.putNextSeat = seatid

	deskInfo.round.multiple = 1
	deskInfo.round.selecttimes = 1
	deskInfo.round.nexgametype = retobj.nextgametype
	deskInfo.round.hokomer = {uid=0, seatid=0} --开始默认值
	deskInfo.round.nextuids = {nextUser.uid}
	if not nextUser.cluster_info then --下一个是机器人
		local randomTime = math.random(200, timeout)
		debug_log("autoChooseGameType autoTime 真人:", randomTime, ' nextUser:', nextUser.uid)
		CMD.userSetAutoState("autoChooseGameType", randomTime, nextUser.uid)
	else
		debug_log("autoChooseGameType autoTime:", timeout, ' nextUser:', nextUser.uid)
		CMD.userSetAutoState("autoChooseGameType", timeout, nextUser.uid)
	end
end

-- 创建房间后第1次开始游戏
---@param delayTime integer 用于指定发牌前的延迟时间
local function startGame(delayTime)
	if deskInfo.state ~= PDEFINE.DESK_STATE.MATCH and deskInfo.state ~= PDEFINE.DESK_STATE.READY then
        return
    end
	-- 停止踢人定时器
	localFunc.stopAutoKickOut()
	-- 这里需要先切了，防止有人退出
	changeDeskState(PDEFINE.DESK_STATE.PLAY)
	debug_log('startGame ')
	-- if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
	-- 	localFunc.updateMicStatus(true)
	-- end
	if aiAutoFuc then aiAutoFuc() end
	local uids = {}  -- 所有用户uid
	local settle = {
		{ --1和3
			['users'] = {},
			['score'] = 0,
			['prize'] = 0, --奖励
			['xp'] = 50, --经验值
		},
		{ --2和4
			['users'] = {},
			['score'] = 0,
			['prize'] = 0, --奖励
			['xp'] = 50, --经验值
		}
	}
	deskInfo.roundstime = os.time()
	-- 随机庄家
	local dealer
	if deskInfo.round.dealer then
		dealer = queryUserInfo(deskInfo.round.dealer['uid'], 'uid')
	end
	if not dealer then
		dealer = deskInfo.users[math.random(#deskInfo.users)]
		deskInfo.round.dealer = { ----此把的庄家(庄家的下家选牌型和出牌)
			['uid'] = dealer.uid,
			['seatid'] = dealer.seatid
		}
	end
	if deskInfo.conf.isLucky and deskInfo.curround == 0 then
		deskInfo.round.dealer = {
			['uid'] = deskInfo.users[1].uid,
			['seatid'] = deskInfo.users[1].seatid
		}
	end
	for _, user in pairs(deskInfo.users) do
		local k = 1
		if table.contain({2,4}, user.seatid) then
			k = 2
		end
		table.insert(settle[k]['users'], {
			['uid'] = user.uid,
			['playername'] = user.playername,
			['icon'] = user.icon,
		})
		-- 储存所有人的uid
		if user.cluster_info then
			table.insert(uids, user.uid)
		end
	end

	-- 通知聊天室，房间已经开始
    for _, user in ipairs(deskInfo.users) do
        if user.cluster_info then
			do_redis({"zincrby", PDEFINE.REDISKEY.GAME.favorite..user.uid, 1, deskInfo.gameid})
            debug_log("startGame roomStart", user.uid, deskInfo.deskid, deskInfo.gameid)
            pcall(
                cluster.send,
                user.cluster_info.server,
                user.cluster_info.address,
                "clusterModuleCall",
                "player",
                "roomStart",
                user.uid,
                deskInfo.deskid,
                deskInfo.gameid
            )
            break
        end
    end

	-- 需要通知master服，新的一轮开始了
	pcall(cluster.send, "master", ".mgrdesk", "lockPlayer", deskInfo.deskid, uids, deskInfo.gameid, deskInfo.conf.roomtype)

	for _,user in pairs(deskInfo.users) do
		local bet = deskInfo.bet
		local prize = deskInfo.panel.prize
		if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
			bet = PDEFINE_GAME.SESS['match'][deskInfo.gameid][user.ssid].entry --扣的是自己选择的场次的金币值
			prize = PDEFINE_GAME.SESS['match'][deskInfo.gameid][user.ssid].reward
		end
		if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH or deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
			localUserCalCoinFunc(user, PDEFINE.ALTERCOINTAG.BET, -bet)
		end
		-- 检查是否是排位赛
        local leagueInfo = player_tool.getLeagueInfo(deskInfo.conf.roomtype,user.uid)
        local is_league = leagueInfo.isSign
		local sql = string.format("insert into d_desk_user(gameid,deskid,uuid,uid,roomtype,create_time,settle,cost_time,win,exited,bet,prize,league) values(%d,%d,'%s',%d,%d,%d,'%s',%d,%d,%d,%d,%d,%d)", 
							deskInfo.gameid, deskInfo.deskid,deskInfo.uuid, user.uid, deskInfo.conf.roomtype, deskInfo.conf.create_time, "", 0, 0, 0, bet, prize,is_league)
		skynet.call(".mysqlpool", "lua", "execute", sql)
	end
	if delayTime then
        delayTime = delayTime * 100
    else
        delayTime = 30
    end
    skynet.timeout(delayTime, function()
		beginChooseGameType()
    end)
end

local function aiJoin(aiUser)
	local nowtime = os.time()
	if nil ~= aiUser then
		local seatid = getSeatId()
		local userObj = {
			uid=aiUser.uid, 
			nick=aiUser.playername, 
			icon = aiUser.usericon,
			coin = initAiCoin(),
			level = aiUser.level or 1,
			levelexp = aiUser.levelexp or 200,
			avatarframe = aiUser.avatarframe or PDEFINE.SKIN.DEFAULT.AVATAR.img,
			chatskin = aiUser.chatskin or PDEFINE.SKIN.DEFAULT.CHAT.img,
			leaguelevel = aiUser.leaguelevel or 1,
			leagueexp = aiUser.leagueexp or 0,
			svip = aiUser.svip or 0,
			svipexp = aiUser.svipexp or 0,
			ssid = deskInfo.ssid,
			settlewin = 0,
			rp = aiUser.rp or 0,
			leavetime = (nowtime + math.random(PDEFINE.ROBOT.REMAINTIME[1], PDEFINE.ROBOT.REMAINTIME[2])), --离开时刻
		}
		if userObj.coin < deskInfo.bet then
			userObj.coin = math.random(15, 50) *  deskInfo.bet
		end
		userObj.leagueexp, userObj.leaguelevel = player_tool.getPlayerLeagueInfo(aiUser.uid, deskInfo.gameid)

		local userInfo = initUser(seatid, userObj)
		pushUserToUserList(userInfo)

		local retobj  = {}
        retobj.c      = PDEFINE.NOTIFY.PLAYER_ENTER_ROOM --有用户加入了
        retobj.code   = PDEFINE.RET.SUCCESS
        local tmp = table.copy(userInfo)
        tmp.round = nil
        retobj.user = tmp
        skynet.timeout(30, function()
            broadcastDesk(cjson.encode(retobj), userInfo.uid)
        end)

        -- 私人房需要告诉master
        if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
            -- aiSeat
            pcall(cluster.send, "master", ".balprivateroommgr", "aiSeat", deskInfo.deskid, deskInfo.gameid, {
                uid = userInfo.uid,
                playername = userInfo.playername,
                usericon = userInfo.usericon,
                seatid = userInfo.seatid
            })
        end
		pcall(cluster.send, "node", ".chat", "changeDeskInfoUsers", deskInfo.deskid, deskInfo.gameid, deskInfo.users, deskInfo.cid)
		return PDEFINE.RET.SUCCESS, 1
	end
	
	local num = deskInfo.seat - #deskInfo.users
	local ok, aiUserList = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", num, true)
	debug_log("加入机器人个数：", num, aiUserList)
	if ok and not table.empty(aiUserList) then
		for _, ai in pairs(aiUserList) do
			if #deskInfo.users == deskInfo.seat then
				RecycleAi(ai)
				break
			end
			-- 防止加入重复的机器人
			local exist_user = queryUserInfo(ai.uid, 'uid')
			if not exist_user then
				local seatid = getSeatId()
				if not seatid then
					RecycleAi(ai)
					break
				end

				local userObj = {
					uid=ai.uid,
					nick=ai.playername,
					icon=ai.usericon,
					coin=initAiCoin(),
					level = ai.level or 1,
					levelexp = ai.levelexp or 200,
					avatarframe = ai.avatarframe or PDEFINE.SKIN.DEFAULT.AVATAR.img,
					chatskin = ai.chatskin or PDEFINE.SKIN.DEFAULT.CHAT.img,
					leaguelevel = ai.leaguelevel or 1,
					leagueexp = ai.leagueexp or 0,
					svip = ai.svip or 0,
					svipexp = ai.svipexp or 0,
					ssid = deskInfo.ssid,
					settlewin = 0,
					rp = ai.rp or 0,
					leavetime = (nowtime + math.random(PDEFINE.ROBOT.REMAINTIME[1], PDEFINE.ROBOT.REMAINTIME[2])), --离开时刻
				}
				userObj.leagueexp, userObj.leaguelevel = player_tool.getPlayerLeagueInfo(ai.uid, deskInfo.gameid)
				local userInfo = initUser(seatid, userObj)
				pushUserToUserList(userInfo)
				debug_log("加入1个机器人了后ai.uid：", ai.uid)
				local retobj  = {}
				retobj.c      = PDEFINE.NOTIFY.PLAYER_ENTER_ROOM --有用户加入了
				retobj.code   = PDEFINE.RET.SUCCESS
				local tmp = table.copy(userInfo)
				tmp.round = nil
				retobj.user = tmp
				skynet.timeout(math.random(10,300), function()
					broadcastDesk(cjson.encode(retobj), ai.uid)
				end)
			end
		end
		debug_log("加入机器人deskInfo.seat", deskInfo.seat)
	end
	-- 判断下，如果房间没真人，则不需要继续匹配机器人了，直接重置
    if not hasRealPlayer() then
        resetDesk()
        return
    end
	if deskInfo.seat == #deskInfo.users then
		-- 判断下状态，防止重复调用
        if deskInfo.state == PDEFINE.DESK_STATE.MATCH or deskInfo.state == PDEFINE.DESK_STATE.READY then
            startGame(3)
        end
    else
        skynet.timeout(100, function ()
            aiJoin()
        end)
    end
	pcall(cluster.send, "node", ".chat", "changeDeskInfoUsers", deskInfo.deskid, deskInfo.gameid, deskInfo.users, deskInfo.cid)
	return PDEFINE.RET.SUCCESS, num
end

-- 加入单个机器人
local function aiSingleJoin()
    if aiAutoFuc then
        aiAutoFuc()
        aiAutoFuc = nil
    end
    if (deskInfo.state ~= PDEFINE.DESK_STATE.MATCH and deskInfo.state ~= PDEFINE.DESK_STATE.READY) or #deskInfo.users >= deskInfo.minSeat then
        return
    end
    if not hasRealPlayer() then
        local users = {}
        for _, u in ipairs(deskInfo.users) do
            if not u.cluster_info then
                table.insert(users, u)
            end
        end
        for _, u in ipairs(users) do
            userExit(u.uid, u.seatid)
        end
		return
    end
    local ok, aiUserList = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", 1, true)
    if ok and #aiUserList > 0 then
        for _, ai in pairs(aiUserList) do
			-- 防止加入重复的机器人
			local exist_user = queryUserInfo(ai.uid, 'uid')
			if exist_user then
				break
			end
			-- 防止超额，这里还要再判断下
            if #deskInfo.users >= deskInfo.seat then
                break
            end
            aiJoin(ai)
        end
    end
    -- 将没有准备的人准备
    skynet.timeout(100, function()
        for _, u in ipairs(deskInfo.users) do
            if u.state ~= PDEFINE.PLAYER_STATE.Ready then
                if deskInfo.conf.autoStart == 1 or not u.cluster_info then
                    CMD.ready(nil, {uid=u.uid})
                end
            end
        end
        -- 如果还没有开始，则继续添加机器人，第二个机器人开始，就只要5-10秒了
        if (deskInfo.state == PDEFINE.DESK_STATE.MATCH or deskInfo.state == PDEFINE.DESK_STATE.READY) and #deskInfo.users < deskInfo.minSeat then
            -- 每过5-60秒，会随即添加一个机器人
            aiAutoFuc = user_set_timeout(math.random(500,1000), function()
                aiSingleJoin()
            end)
        end
    end)
end

-- 房间自动开启
local function autoStartGame()
    if aiAutoFuc then
       aiAutoFuc() 
    end
    -- 每过5-30秒，会随即添加一个机器人
    aiAutoFuc = user_set_timeout(math.random(500,3000), function()
        aiSingleJoin()
    end)
end

-- 广播用户信息给其他玩家
local function broadcastPlayerInfo(user)
    -- 广播消息给其他玩家
    local notify_object = {}
    notify_object.c = PDEFINE.NOTIFY.PLAYER_UPDATE_INFO
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.uid = user.uid
    notify_object.svip = user.svip
    notify_object.svipexp = user.svipexp
    notify_object.rp = user.rp
    notify_object.level = user.level
    notify_object.levelexp = user.levelexp
    notify_object.coin = user.coin
    notify_object.playername = user.playername
    notify_object.usericon = user.usericon
    notify_object.charm = user.charm
    notify_object.avatarframe = user.avatarframe
    notify_object.chatskin = user.chatskin
    notify_object.tableskin = user.tableskin
    notify_object.pokerskin = user.pokerskin
    notify_object.frontskin = user.frontskin
    notify_object.emojiskin = user.emojiskin
    notify_object.faceskin = user.faceskin
    broadcastDesk(cjson.encode(notify_object), user.uid)
end

-- 需要清理房间信息，方便进行下一局
local function prepareNewTrun(isDismiss)
	-- print('prepareNewTrun')
	local nextSeatId = findNextSeat(deskInfo.round.dealer['seatid'])
	local nextUser = queryUserInfo(nextSeatId, 'seatid')
    local now = os.time()
    deskInfo.uuid   = deskInfo.deskid..now  -- 更改uuid
	deskInfo.conf.create_time = now
	local sql = string.format("insert into d_desk_game(deskid,gameid,uuid,owner,roomtype,bet,prize,conf,create_time) values(%d,%d,'%s',%d,%d,%d,%d,'%s',%d)", 
								deskInfo.deskid, deskInfo.gameid, deskInfo.uuid, deskInfo.owner, deskInfo.conf.roomtype, deskInfo.bet, deskInfo.panel.prize, cjson.encode(deskInfo.conf), now)
	skynet.call(".mysqlpool", "lua", "execute", sql)
	-- print('loadSessInfo prepareNewTrun')
    loadSessInfo(nextUser.uid, {conf=deskInfo.conf, maxRound=deskInfo.maxRound, ssid=deskInfo.ssid}, nextSeatId)
	-- deskInfo.curround = 0
	deskInfo.panel.score = {0, 0}
	local exitedUsers = {}
	local killUsers = {}  -- 需要踢掉的人
	local offlineUsers = {}  -- 离线的人
	local dismissUsers = {}  -- 解散踢人
    local uids = {}
    for _, user in ipairs(deskInfo.users) do
		-- 游戏大局结束之后，解禁所有玩家，可以加入其它房间
        table.insert(uids, user.uid)
		if not user.cluster_info and (now > user.leavetime) then
			user.isexit = 1
		end
		-- 好友房，判断金币是否够
		if isDismiss then
            table.insert(dismissUsers, {uid=user.uid, seatid=user.seatid})
		elseif user.offline == 1 then
            table.insert(offlineUsers, {uid=user.uid, seatid=user.seatid})
        elseif user.coin < deskInfo.bet then
            table.insert(killUsers, {uid=user.uid, seatid=user.seatid})
        elseif user.isexit == 1 then
            table.insert(exitedUsers, {uid=user.uid, seatid=user.seatid})
        else
			user.state = 0
			user.round.roundscore = 0 --轮分
			user.round.floor = 0 -- 底分
			user.round.projects = 0 --projects 分数
			user.round.points = 0 --points = roundscore + floor + projects
			user.round.projectslist = {} -- projects明细
			user.round.cards = {} --刚发的8张手牌
			user.round.handInCards = {} --手牌
			user.round.outCards = {} --出牌
			user.autoStartTime     = nil -- 托管开始时间
			if user.auto == 1 then
				user.autoStartTime = os.time()
			end
			user.autoTotalTime     = 0 -- 当局游戏处于托管的时间
		end
    end

	-- 将已经退出的玩家删除，并且广播
    for _, user in ipairs(exitedUsers) do
        userExit(user.uid, user.seatid)
    end

	-- 解散踢人
    for _, user in ipairs(dismissUsers) do
        pcall(cluster.send, "master", ".balprivateroommgr", "exitRoom", deskInfo.deskid, deskInfo.gameid, user.uid)
        for _, u in ipairs(deskInfo.users) do
            if u.uid == user.uid and u.cluster_info then
                pcall(cluster.send, u.cluster_info.server, u.cluster_info.address, "deskBack", deskInfo.gameid)
            end
        end
        pcall(cluster.send, "master", ".agentdesk", "removeDesk", user.uid, deskInfo.deskid)
        userExit(user.uid, user.seatid, PDEFINE.RET.ERROR.GAME_ALREADY_DELTE)
    end

	-- 踢出观战玩家
    if isDismiss then
        for _, viewer in ipairs(deskInfo.views) do
            viewExit(viewer.uid)
            pcall(cluster.send, viewer.cluster_info.server, viewer.cluster_info.address, "deskBack", deskInfo.gameid) --释放桌子对象
        end
    end

	-- 将需要剔除的玩家退出房间，并且广播
    for _, user in ipairs(killUsers) do
        local duser = queryUserInfo(user.uid, 'uid')
        if duser and duser.cluster_info and duser.isexit == 0 then
            pcall(cluster.send, duser.cluster_info.server, duser.cluster_info.address, "deskBack", deskInfo.gameid) --释放桌子对象
        end
        userExit(user.uid, user.seatid, PDEFINE.RET.ERROR.COIN_NOT_ENOUGH)
    end

	-- 离线的玩家，从桌子信息中删除用户
    for _, user in ipairs(offlineUsers) do
        pcall(cluster.send, "master", ".agentdesk", "removeDesk", user.uid, deskInfo.deskid)
        userExit(user.uid, user.seatid, PDEFINE.RET.ERROR.USER_OFFLINE)
    end

    -- 将坐下的观战玩家拉入牌局中
    local newViews = {}
    for _, user in ipairs(deskInfo.views) do
        if user.seatid > 0 then
            table.insert(deskInfo.users, user)
        else
            table.insert(newViews, user)
        end
    end
    deskInfo.views = newViews

	skynet.timeout(AutoReadyTimeout*100, function ()
		-- 匹配方倒计时开始下一轮游戏
		if hasRealPlayer() then
			for _, u in ipairs(deskInfo.users) do
				if u.state ~= PDEFINE.PLAYER_STATE.Ready then
					if deskInfo.conf.autoStart == 1 or not u.cluster_info then
                        CMD.ready(nil, {uid=u.uid})
                    end
				end
			end
			-- 桌子是满的，则开启踢人倒计时
			if #deskInfo.users == deskInfo.seat then
				LOG_DEBUG("prepareNewTrun setAutoKickOut")
				localFunc.setAutoKickOut()
			end
			-- 如果还没有开始，则继续添加机器人，第二个机器人开始，就只要5-10秒了
			if isJoinAI() and deskInfo.state == PDEFINE.DESK_STATE.MATCH or deskInfo.state == PDEFINE.DESK_STATE.READY then
				autoStartGame()
			end
		else
			local users = {}
			for _, u in ipairs(deskInfo.users) do
				table.insert(users, u)
			end
			for _, u in ipairs(users) do
				userExit(u.uid, u.seatid)
			end
		end
	end)
	-- if deskInfo.conf.autoStart == 1 then
	-- else
	-- 	-- 设置每个人的自动准备
	-- 	for _, user in ipairs(deskInfo.users) do
	-- 		LOG_DEBUG("set autoReady ", user.uid)
	-- 		CMD.userSetAutoState('autoReady', 500, user.uid)
	-- 	end
	-- end
end

local function sysKickUser()
	--释放该用户的桌子对象
	for i, user in pairs(deskInfo.users) do
		clearAutoFunc(user.uid)
		local retobj    = {}
		retobj.code     = PDEFINE.RET.SUCCESS
		retobj.c        = PDEFINE.NOTIFY.NOTIFY_SYS_KICK
		retobj.uid      = uid
		if user.cluster_info and user.isexit==0 then
			debug_log("sysKickUser user uid:", user.uid)
			pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(retobj))
			pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", PDEFINE.GAME_TYPE.POKER_LM) --释放桌子对象
		end
	end
	resetDesk()
end

-- 此轮结束，开始下一轮
local function restUserRound()
	debug_log("================================restUserRound=====================================")
	if closeServer then
		sysKickUser()
		return PDEFINE.RET.SUCCESS
	end

	loadSessInfo(deskInfo.round.dealer['uid'], {conf=deskInfo.conf, maxRound=deskInfo.maxRound, ssid=deskInfo.ssid}, deskInfo.round.dealer['seatid'])
	-- 不要切换状态， 防止用户退出
	deskInfo.state = PDEFINE.DESK_STATE.PLAY
	local viewRetobj = nil
	for _,user in pairs(deskInfo.users) do
		clearAutoFunc(user.uid)
		user.round.handInCards = {}
		user.round.cards = {}
		user.round.roundscore = 0
		user.round.floor = 0
		user.round.projects = 0
		user.round.projectslist ={}
		user.state = 0
		user.auto  = 0
		user.winTimes = 0
		local retobj    = {}
		retobj.code     = PDEFINE.RET.SUCCESS
		retobj.c        = PDEFINE.NOTIFY.BALOOT_ROUND_START
		retobj.uid = user.uid
		retobj.time = math.floor(timeout/100)
		viewRetobj = retobj
		if user.cluster_info and user.isexit == 0 then
			pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(retobj))
		end
	end
	if viewRetobj then
		viewRetobj.uid = nil
		broadcastView(cjson.encode(viewRetobj))
	end

	local nextDealerId = findNextSeat(deskInfo.round.dealer['seatid'])
	local nextDealer = queryUserInfo(nextDealerId, 'seatid')
	
	local putNextSeat = findNextSeat(nextDealer.seatid)
	deskInfo.round.putNextSeat = putNextSeat
	deskInfo.round.showCard = {}
	deskInfo.round.showCardUsers = {}
	deskInfo.round.settle = initSettleData()
	deskInfo.round.floorseat = 0
	deskInfo.panel.roundscore = {0, 0}
	deskInfo.roundstime = os.time() --本小局开始时间
	--重置桌子当局信息当局信息
	-- changeDeskInfo(PDEFINE.DESK_STATE.READY)

	skynet.timeout(300, beginChooseGameType)
end

-- 一大局打完，新开一局
local function startNextRound(delayTime)
	local nextSeatId = findNextSeat(deskInfo.round.dealer['seatid'])
	local nextUser = queryUserInfo(nextSeatId, 'seatid')
    local now = os.time()
    deskInfo.uuid   = deskInfo.deskid..now  -- 更改uuid
	deskInfo.conf.create_time = now
	deskInfo.panel.score = {0, 0}
	local sql = string.format("insert into d_desk_game(deskid,gameid,uuid,owner,roomtype,bet,prize,conf,create_time) values(%d,%d,'%s',%d,%d,%d,%d,'%s',%d)", 
								deskInfo.deskid, deskInfo.gameid, deskInfo.uuid, deskInfo.owner, deskInfo.conf.roomtype, deskInfo.bet, deskInfo.panel.prize, cjson.encode(deskInfo.conf), now)
	skynet.call(".mysqlpool", "lua", "execute", sql)
	-- print('loadSessInfo prepareNewTrun')
    loadSessInfo(nextUser.uid, {conf=deskInfo.conf, maxRound=deskInfo.maxRound, ssid=deskInfo.ssid}, nextSeatId)
	-- deskInfo.curround = 0
	deskInfo.panel.score = {0, 0}
	local exitedUsers = {}
	local killUsers = {}
	local offlineUsers = {}  -- 离线的人
	local uids = {}
    for _, user in ipairs(deskInfo.users) do
		table.insert(uids, user.uid)
		-- 每个人的下注额都有可能不同
		if not user.cluster_info and (now > user.leavetime) then
			user.isexit = 1
		end
        local minCoin = PDEFINE_GAME.SESS.match[deskInfo.gameid][user.ssid].section[1]
		if user.offline == 1 then
            table.insert(offlineUsers, {uid=user.uid, seatid=user.seatid})
		elseif user.coin < minCoin then
            table.insert(killUsers, {uid=user.uid, seatid=user.seatid})
        elseif user.isexit == 1 then
            table.insert(exitedUsers, {uid=user.uid, seatid=user.seatid})
        else
			user.state = balcfg.UserState.Wait -- 玩家状态
			user.round = {}
			user.round.roundscore = 0 --轮分
			user.round.floor = 0 -- 底分
			user.round.projects = 0 --projects 分数
			user.round.points = 0 --points = roundscore + floor + projects
			user.round.projectslist = {} -- projects明细
			user.round.cards = {} --刚发的8张手牌
			user.round.handInCards = {} --手牌
			user.round.outCards = {} --出牌
			user.round.ace_flag = 0
			user.round.handCardCount = 0
			user.autoStartTime     = nil -- 托管开始时间
			if user.auto == 1 then
				user.autoStartTime = os.time()
			end
			user.autoTotalTime     = 0 -- 当局游戏处于托管的时间
		end
    end

	debug_log("startNextRound exitedUsers:", exitedUsers)

	-- 将已经退出的玩家删除，并且广播
	if #exitedUsers > 0 then
		for _, user in ipairs(exitedUsers) do
			userExit(user.uid, user.seatid)
		end
	end

	-- 将需要剔除的玩家退出房间，并且广播
	local nowtime = os.time()
    for _, user in ipairs(killUsers) do
        local duser = queryUserInfo(user.uid, 'uid')
        if duser and duser.cluster_info and duser.isexit==0 then
            pcall(cluster.send, duser.cluster_info.server, duser.cluster_info.address, "deskBack", deskInfo.gameid) --释放桌子对象
			local sql = string.format("insert into d_desk_bankrupt(uid,gameid,uuid,deskid,roomtype,bet,create_time) values(%d,%d,'%s',%d,%d,%d,%d)", 
								user.uid,deskInfo.gameid,deskInfo.uuid,deskInfo.deskid, deskInfo.conf.roomtype, deskInfo.bet, nowtime)
			skynet.call(".mysqlpool", "lua", "execute", sql)
        end
        userExit(user.uid, user.seatid, PDEFINE.RET.ERROR.COIN_NOT_ENOUGH)
    end

	-- 离线的玩家，从桌子信息中删除用户
    for _, user in ipairs(offlineUsers) do
        pcall(cluster.send, "master", ".agentdesk", "removeDesk", user.uid, deskInfo.deskid)
        userExit(user.uid, user.seatid, PDEFINE.RET.ERROR.USER_OFFLINE)
    end

	skynet.timeout(delayTime, function()
		if hasRealPlayer() then
			if #deskInfo.users < deskInfo.seat then
				aiJoin()
			else
				startGame(nil)
			end
		else
			debug_log("startNextRound resetDesk:", ' users:', #deskInfo.users, ' deskInfo.seat:',deskInfo.seat)
			resetDesk()
		end
	end)
end

local function genWinTimesKey(uid, istotal, today)
    if istotal then
        return string.format(PDEFINE_REDISKEY.SHARE.TYPE.TOTAL, today, uid)
    end
    return string.format(PDEFINE_REDISKEY.SHARE.TYPE.CONT, today, uid, deskInfo.gameid, deskInfo.deskid)
end

local function calWinTimesFBShare(totalwins, contwins, today, uid, gameid)
    local item = {}
    for i=#PDEFINE.SHARE.WINTIMES.TOTAL.KEYS, 1, -1 do
        local times = PDEFINE.SHARE.WINTIMES.TOTAL.KEYS[i]
        if totalwins == times then
            item['type'] = PDEFINE.SHARE.TYPE.TOTAL --累计分享 类型
            item['times'] = PDEFINE.SHARE.WINTIMES.TOTAL.TIMES[i] --累计分享 倍数
            break
        end
    end

    local getTimes = do_redis({"get", string.format(PDEFINE_REDISKEY.SHARE.TYPE.CONTGET, today, uid, gameid)})
    if not getTimes then
        for i=#PDEFINE.SHARE.WINTIMES.CONT.KEYS, 1, -1 do
            local times = PDEFINE.SHARE.WINTIMES.CONT.KEYS[i]
            if contwins >= (times+1) then
                if nil == item['times'] then
                    item['type'] = PDEFINE.SHARE.TYPE.CONT --连胜分享
                    item['times'] = PDEFINE.SHARE.WINTIMES.CONT.TIMES[i] --倍数
                else
                    if item['times'] == times then
                        item['type'] = PDEFINE.SHARE.TYPE.CONT --如果是同样的倍数，就直接显示连胜的分享
                    end
                end
                break
            end
        end
    end
    return item
end

-- 累计获胜或连胜记录, 可能触发分享条件
local function recordWinTimes(winUidsAndCoin)
    LOG_DEBUG("DeskInfo:recordWinTimes:", winUidsAndCoin)
    local fbshare = {}
    if nil==winUidsAndCoin or table.empty(winUidsAndCoin) then
        return fbshare
    end
    local leftTime = getThisPeriodTimeStamp()
    local winuids = {}
    local today = os.date("%Y%m%d",os.time()) 
    for _, user in pairs(deskInfo.users) do
        if user.cluster_info then
            local times1, times2 = 0, 0
            if winUidsAndCoin[user.uid] then
                local cumuTimesKey = genWinTimesKey(user.uid, true, today) --累计赢
                do_redis({"hincrby", cumuTimesKey, deskInfo.gameid, 1})
                times1 = do_redis({"hget", cumuTimesKey, deskInfo.gameid})
                times1 = tonumber(times1 or 0)
                if times1 == 1 then
                    do_redis( {"expire", cumuTimesKey, leftTime}) 
                end
                table.insert(winuids, user.uid)

				local contTimesKey = genWinTimesKey(user.uid, false, today)
				if table.contain(deskInfo.preWinners, user.uid) then --连赢
					do_redis({ "incrby", contTimesKey, 1})
					times2 = do_redis({"get", contTimesKey})
					times2 = tonumber(times2 or 0)
					if times2 == 1 then
						do_redis( {"expire", contTimesKey, leftTime}) 
					end
				else
					do_redis({"del", contTimesKey})
				end
				LOG_DEBUG('recordWinTimes: uid:', user.uid, ' times1:', times1, ' times2:',times2)
				if times1 > 0 or times2 > 0 then
					local item = calWinTimesFBShare(times1, times2, today, user.uid, deskInfo.gameid)
					if not table.empty(item) then
						fbshare[user.uid] = item
						do_redis({"set", string.format(PDEFINE_REDISKEY.SHARE.COINKEY, user.uid, deskInfo.gameid), winUidsAndCoin[user.uid]*item.times}) --保存起来
					end
				end
            end
            
        end
    end
    deskInfo.preWinners = winuids
    return fbshare
end

-- 游戏结束
-- @lastWinKey 最后1局哪1方赢了
local function gameover(isDismiss)
	deskInfo.state = PDEFINE.DESK_STATE.SETTLE
	-- 是否在结算中
    if deskInfo.in_settle then
        return
    end
    deskInfo.in_settle = true
	if not isDismiss then
        localFunc.cancelDismiss()
    end
	updateDataToDB(2)
	-- 如果是特殊房间，则去掉, 只打一局
    if deskInfo.conf.spcial == 1 then
        deskInfo.conf.spcial = nil
    end
	local retobj = {}
	retobj.c = PDEFINE.NOTIFY.BALOOT_GAME_OVER
	retobj.code   = PDEFINE.RET.SUCCESS
	retobj.timeout = math.floor(timeout/100) + 6
	retobj.settle = {
		{ --1和3
			['users'] = {},
			['score'] = 0,
			['prize'] = 0, --奖励
			['xp'] = 50, --经验值
		},
		{ --2和4
			['users'] = {},
			['score'] = 0,
			['prize'] = 0, --奖励
			['xp'] = 50, --经验值
		}
	}
	local dangerUids = {}  -- 快要破产的人
	if deskInfo.state == PDEFINE.DESK_STATE.MATCH then
        resetDesk()
        return
    end

	-- 做下处理用于记录战绩信息
    local settle = {
        uids = {},  -- uids
        league = {},  -- 排位经验
        coins = {}, -- 结算的金币
        scores = {}, -- 获得的分数
        levelexps = {}, -- 经验值
        rps = {},  -- rp 值
        fcoins = {},  -- 最终的金币
    }
    for i = 1, deskInfo.seat do
        local u = queryUserInfo(i, 'seatid')
        if u then
            table.insert(settle.uids, u.uid)
        else
            table.insert(settle.uids, 0)
        end
        table.insert(settle.league, 0)
        table.insert(settle.coins, 0)
        table.insert(settle.scores, 0)
        table.insert(settle.levelexps, 0)
        table.insert(settle.rps, 0)
        table.insert(settle.fcoins, 0)
    end

	local uids = {}
	for _, user in ipairs(deskInfo.users) do
		if user.cluster_info then
			table.insert(uids, user.uid)
		end
	end
	-- 需要将玩家解禁，可以退出后加入其它房间
    pcall(cluster.send, "master", ".mgrdesk", "unlockPlayer", deskInfo.deskid, uids, deskInfo.gameid, deskInfo.conf.roomtype)

	
	deskInfo.state = PDEFINE.DESK_STATE.SETTLE
	local winKey = 2
	if deskInfo.panel.score[1] > deskInfo.panel.score[2] then
		winKey = 1
	elseif deskInfo.panel.score[1] == deskInfo.panel.score[2] then
		winKey = LASTWINKEY
	end

	for k, score in pairs(deskInfo.panel.score) do
		if k == winKey then
			retobj.settle[k]['prize'] = deskInfo.panel.prize
			retobj.settle[k]['xp'] = 80 --经验值
		else
			retobj.settle[k]['prize'] = -deskInfo.panel.prize
		end
		retobj.settle[k]['score'] = score
	end

	local time = os.time() - deskInfo.conf.create_time

	-- 记录总赢金币数量
	local totalWinCoin = 0
	for _, user in pairs(deskInfo.users) do
		local k = 1
		if user.seatid % 2 == 0 then
			k = 2
		end
		local item = {
			['uid'] = user.uid,
			['playername'] = user.playername,
			['icon'] = user.icon,
		}
		local leagueInfo = player_tool.getLeagueInfo(deskInfo.conf.roomtype, user.uid)
		if leagueInfo.isSign == 1 then
			item.prize = 0
			item.rp = 0
			local winCoin = deskInfo.panel.prize
			local bet = deskInfo.bet
			if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
				winCoin = PDEFINE_GAME.SESS.match[deskInfo.gameid][user.ssid].reward
				bet = PDEFINE_GAME.SESS.match[deskInfo.gameid][user.ssid].entry
				-- 开启了排位，金币加倍奖励
				if leagueInfo.isSign == 1 then
					-- winCoin = winCoin *2 - bet
				end
			end
			if winKey == k then
				local ok, leagueExp = pcall(cluster.call, "master", ".cfgleague", "getLeagueExp", winCoin, user.leaguelevel)
				if ok then
					item.prize = leagueExp
					user.leagueexp = user.leagueexp + leagueExp
					settle.league[user.seatid] = leagueExp
				end
			end
		end
		if winKey == k and not isDismiss then
			local rp = player_tool.calGameWinRp(deskInfo.gameid)
			user.rp = user.rp + rp
			item.rp = rp
			if user.cluster_info and user.isexit==0 then
				pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "addRp", rp)
			end
			settle.rps[user.seatid] = rp
		end
		table.insert(retobj.settle[k]['users'],item)
	end
	
	for _, user in pairs(deskInfo.users) do
		local leagueInfo = player_tool.getLeagueInfo(deskInfo.conf.roomtype,user.uid)
		--乱匹配，输赢金币显示
		local winCoin = deskInfo.panel.prize
		local bet = deskInfo.bet
		if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
			winCoin = PDEFINE_GAME.SESS.match[deskInfo.gameid][user.ssid].reward
			bet = PDEFINE_GAME.SESS.match[deskInfo.gameid][user.ssid].entry
			-- 开启了排位，金币加倍奖励
			if leagueInfo.isSign == 1 then
				-- winCoin = winCoin *2 - bet
				-- user.settlewin = user.settlewin + 0.9
			end
		end
		local placeid = 1
		if user.seatid %2 == 0 then
			placeid = 2
		end
		if placeid == winKey then
			user.wincoin = user.wincoin + winCoin
			user.settlewin = user.settlewin + 1
			settle.coins[user.seatid] = winCoin
			totalWinCoin = totalWinCoin + winCoin
		else
			user.wincoin = user.wincoin - winCoin
			user.settlewin = user.settlewin - 1
			settle.coins[user.seatid] = -1 * winCoin
		end
		local win = 0
		if winKey == placeid  then
			win = 1
		end
		local addExp = player_tool.boosterExp(user.uid, (winKey == placeid), deskInfo.conf.roomtype, deskInfo.gameid)
		if isDismiss then
			addExp = 0
		end
		settle.levelexps[user.seatid] = addExp
		user.levelexp = user.levelexp + addExp
		if win == 1 then
			localUserCalCoinFunc(user, PDEFINE.ALTERCOINTAG.COMBAT, winCoin)
		end
		if user.cluster_info then
			if win == 1 then --这个玩家赢了
				if leagueInfo.isSign == 1 then
					debug_log("gameover league addleagueExp uid:", user.uid, ' coin:', winCoin)
					pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "clusterModuleCall", "upgrade", "bet",  deskInfo.gameid, winCoin,'league', deskInfo.conf.roomtype)
				end
				winNotifyLobby(winCoin, user.uid, deskInfo.gameid)
			end

			-- 更新主线任务
			local updateMainObjs = {
				-- 游戏次数
				{kind=PDEFINE.MAIN_TASK.KIND.GameTimes, count=1},
			}
			-- 赢取金币
			if winCoin > 0 then
				table.insert(
					updateMainObjs, 
					{kind=PDEFINE.MAIN_TASK.KIND.WinCoin, count=winCoin}
				)
				-- 赢取游戏的次数
				table.insert(
					updateMainObjs, 
					{kind=PDEFINE.MAIN_TASK.KIND.WinGameTimes, count=1}
				)
			end
			-- 获取rp值
			if settle.rps[user.seatid] > 0 then
				table.insert(
					updateMainObjs, 
					{kind=PDEFINE.MAIN_TASK.KIND.RP, count=settle.rps[user.seatid]}
				)
			end
			if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
                -- 好友房游戏次数
                table.insert(
                    updateMainObjs, 
                    {kind=PDEFINE.MAIN_TASK.KIND.SalonGames, count=1}
                )
            end
			-- 排位赛
            if settle.league[user.seatid] > 0 then
                table.insert(updateMainObjs, {kind=PDEFINE.MAIN_TASK.KIND.LeagueLevelCnt, count=1})
            end
			pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "clusterModuleCall", "maintask", "updateTask", user.uid, updateMainObjs)

			local result = {
				["uid"] = user.uid,
				['deskid'] = deskInfo.deskid,
				["roomtype"] = deskInfo.conf.roomtype,
				["create_time"] = deskInfo.conf.create_time,
				["settle"] = retobj.settle,
				["win"] = win,
				["exited"] = user.isexit,
				['cost_time'] = time,
				['entry'] = deskInfo.conf.entry,
				['gameid'] = deskInfo.gameid,
				['isDismiss'] = isDismiss,
				['owner'] = deskInfo.owner or 0,
				['isSign'] = leagueInfo.isSign or 0,
				['winCoin'] = winCoin,
    		}
			skynet.send(".gamepostmgr","lua", "addGameResult", result)

			if not isDismiss then
				if user.isexit == 0 then
					pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "clusterModuleCall", "upgrade", "bet", deskInfo.gameid, addExp, 'level', deskInfo.conf.roomtype)
				end
			end

		end
		-- 好友房和匹配房踢人的门槛不同，所以分开判断
		if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
			if user.coin - PDEFINE_GAME.SESS['match'][deskInfo.gameid][user.ssid].section[1] < (PDEFINE_GAME.DANGER_BET_MULT-1)*bet then
				table.insert(dangerUids, user.uid)
			end
		else
			if user.coin < PDEFINE_GAME.DANGER_BET_MULT*bet then
				table.insert(dangerUids, user.uid)
			end
		end
		settle.fcoins[user.seatid] = user.coin
	end
	retobj.fcoins = settle.fcoins

	local winUidsAndCoin = {} --赢的uid=>金币数
    for _, user in ipairs(deskInfo.users) do
        if settle.coins[user.seatid] > 0 then
            winUidsAndCoin[user.uid] = settle.coins[user.seatid]
        end
    end

    retobj.fbshare = recordWinTimes(winUidsAndCoin)

	local updateAiUsers = {}
	for _, user in ipairs(deskInfo.users) do
		local placeid = 1
		if user.seatid % 2 == 0 then
			placeid = 2
		end
		local win = 0
		if placeid == winKey then
			win = 1
		end
		-- 检查是否是排位赛
        local leagueInfo = player_tool.getLeagueInfo(deskInfo.conf.roomtype,user.uid)
        local is_league = leagueInfo.isSign
		-- 记录托管时间
        if user.autoStartTime then
            user.autoTotalTime = user.autoTotalTime + os.time() - user.autoStartTime
            user.autoStartTime = os.time()
        end
		local sql = string.format( "update d_desk_user set win=%d,cost_time=%d,auto_time=%d,is_auto=%d, exited=%d,settle='%s',league=%d where uid=%d and uuid='%s'", win, time, user.autoTotalTime, user.auto, user.isexit, cjson.encode(settle), is_league, user.uid, deskInfo.uuid)
		LOG_DEBUG("d_desk_user:", sql)
		skynet.call(".mysqlpool", "lua", "execute", sql)
		-- 更新机器人
        if not user.cluster_info then
            table.insert(updateAiUsers, {uid=user.uid, coin=user.coin, rp=user.rp, levelexp=user.levelexp, leagueexp=settle.league[user.seatid], gameid=deskInfo.gameid})
        end
	end
	pcall(cluster.send, "ai", ".aiuser", "updateAiInfo", updateAiUsers)


	-- 给房主分金币
	if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
		-- 私人房需要给房主分成
		pcall(cluster.send, "master", ".balprivateroommgr", "gameOver", deskInfo.deskid, deskInfo.owner, totalWinCoin, deskInfo.bet)
	end

	retobj.isDismiss = isDismiss and 1 or 0  -- 是否解散

	if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
		-- 如果是解散结算的，则要去掉房间
        if isDismiss then
            local notify_retobj = { c=PDEFINE.NOTIFY.GAME_DISMISS_ROOM, code = PDEFINE.RET.SUCCESS, deskid=deskInfo.deskid }
            skynet.timeout(30, function()
                broadcastDesk(cjson.encode(notify_retobj))
				resetDesk(true)
            end)
		else
			skynet.timeout(20, function()
                prepareNewTrun()
            end)
        end
	end

	if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
		for _, userInfo in pairs(deskInfo.users) do
			if  userInfo.cluster_info and userInfo.isexit == 0 then
				local prize = PDEFINE_GAME.SESS.match[deskInfo.gameid][userInfo.ssid].reward
				local bet = PDEFINE_GAME.SESS.match[deskInfo.gameid][userInfo.ssid].entry
				retobj.wincoins = {}
				for _, muser in pairs(deskInfo.users) do
					local wincoinshow = muser.settlewin * prize
					if muser.settlewin < 0 then
						wincoinshow = muser.settlewin * bet
					end
					table.insert(retobj.wincoins, {
						uid = muser.uid,
						wincoinshow = wincoinshow
					})
				end
				
				retobj.settle[winKey].prize = prize
				local otheridx = 2
				if winKey == 2 then
					otheridx = 1
				end
				retobj.settle[otheridx].prize = -1 * prize
				if userInfo.isexit == 0 then
					pcall(cluster.send, userInfo.cluster_info.server, userInfo.cluster_info.address, "sendToClient", cjson.encode(retobj))
				end
			end
		end
		if isDismiss then
			local notify_retobj = { c=PDEFINE.NOTIFY.GAME_DISMISS_ROOM, code = PDEFINE.RET.SUCCESS, deskid=deskInfo.deskid }
            skynet.timeout(60, function()
                broadcastDesk(cjson.encode(notify_retobj))
				resetDesk()
            end)
		else
			LOG_DEBUG("startNextRound func will exec in " , retobj.timeout , ' s')
			-- 将延迟放入函数中，便于踢人操作
			skynet.timeout(20, function()
				startNextRound(timeout + 1000)
			end)
		end
	else
		broadcastDesk(cjson.encode(retobj))
	end

	-- 广播快破产的人
    if #dangerUids > 0 then
        local notify_object = {}
        notify_object.c = PDEFINE.NOTIFY.PLAYER_DANGER_COIN
        notify_object.code = PDEFINE.RET.SUCCESS
        notify_object.dangerUids = dangerUids
        broadcastDesk(cjson.encode(notify_object))
    end
end

local function changeDealer()
	local nextSeat = findNextSeat(deskInfo.round.dealer['seatid'])
	local nextDealer = queryUserInfo(nextSeat, 'seatid')
	deskInfo.round.dealer = {
		['uid'] = nextDealer.uid,
		['seatid'] = nextSeat
	}
end

-- 此轮游戏结束 小结算面板  1 表示奇数位  2表示偶数位
local function roundOver()
	local floorSeatId = deskInfo.round.floorseat
	local retobj = {}
	retobj.c = PDEFINE.NOTIFY.BALOOT_ROUND_OVER
	retobj.code   = PDEFINE.RET.SUCCESS
	retobj.timeout = math.floor(timeout/100)
	retobj.settle = table.copy(deskInfo.round.settle)
	if floorSeatId%2 == 0 then --底分10分
		retobj.settle[2]['floor'] = retobj.settle[2]['floor'] + 10
	else
		retobj.settle[1]['floor'] = retobj.settle[1]['floor'] + 10
	end
	for _,user in pairs(deskInfo.users) do
		clearAutoFunc(user.uid)
		local key = 1
		if table.contain({2, 4}, user.seatid) then
			key = 2
		end
		retobj.settle[key]['roundscore'] = retobj.settle[key]['roundscore'] + user.round.roundscore
		retobj.settle[key]['floor'] = retobj.settle[key]['floor'] + user.round.floor
		retobj.settle[key]['projects'] = retobj.settle[key]['projects'] + user.round.projects
		for _, row in pairs(user.round.projectslist) do
			table.insert(retobj.settle[key]['projectslist'], row)
		end
	end

	if deskInfo.conf.isLucky then
		local hasBuffer = useLuckyBuffer(deskInfo.users[1].uid, PDEFINE_GAME.GAME_TYPE.BALOOT)
		if not hasBuffer then
			deskInfo.conf.isLucky = false
		end
	end

	for _, item in pairs(retobj.settle) do
		item['xpoints'] = item['roundscore'] + item['floor']
		item['points'] = item['xpoints'] + item['projects']
	end
	if retobj.settle[1]['roundscore'] == 0 then -- 1方被通杀，对方奖励90分
		retobj.settle[2]['xpoints'] = retobj.settle[2]['xpoints'] + retobj.settle[2]['projects'] + 90
	elseif retobj.settle[2]['roundscore'] == 0 then
		retobj.settle[1]['xpoints'] = retobj.settle[1]['xpoints'] + retobj.settle[1]['projects'] + 90
	else
		LOG_DEBUG("roundOver11 settle:",deskInfo.panel.gametype, ' deskid:', deskInfo.deskid, ' settle:',retobj.settle)
		local muser = queryUserInfo(deskInfo.panel.uid, 'uid')
		local buyerTeam = (muser.seatid % 2 == 0 and 2 or 1) --买牌方，也称叫牌方
		local otherTeam = (buyerTeam == 1 and 2 or 1)
		
		if deskInfo.panel.gametype == balcfg.TYPE.HOKOM then
			local flag = 81
			if retobj.settle[buyerTeam]['xpoints'] == flag then
				retobj.settle[otherTeam]['xpoints'] = retobj.settle[buyerTeam]['xpoints']
			elseif retobj.settle[buyerTeam]['xpoints'] < flag then
				retobj.settle[otherTeam]['xpoints'] = retobj.settle[buyerTeam]['xpoints'] + retobj.settle[otherTeam]['xpoints'] + retobj.settle[buyerTeam]['projects']
				retobj.settle[buyerTeam]['xpoints'] = 0
			end
		else
			local flag = 66
			if retobj.settle[buyerTeam]['xpoints'] < flag then
				retobj.settle[otherTeam]['xpoints'] = retobj.settle[buyerTeam]['xpoints'] + retobj.settle[otherTeam]['xpoints'] + retobj.settle[buyerTeam]['projects']
				retobj.settle[buyerTeam]['xpoints'] = 0
			end
		end
	end
	local shouldSettle = false --是否要结算这把
	local multiple = 2
	if deskInfo.panel.gametype == balcfg.TYPE.HOKOM then
		multiple = 1
		if deskInfo.round.multiple > 1 then
			multiple = deskInfo.round.multiple
		end
	elseif deskInfo.panel.gametype == balcfg.TYPE.SUN then
		if deskInfo.round.multiple > 1 then
			multiple = multiple * deskInfo.round.multiple
		end
	end
	for k, item in pairs(retobj.settle) do
		if item['xpoints'] > 0 then
			item['xpoints'] = item['xpoints'] + item['projects']
		end
		item['score'] = math.floor((item['xpoints']/10) + 0.5) * multiple
		deskInfo.panel.score[k] = deskInfo.panel.score[k] + item['score'] --双方的总分
		if deskInfo.panel.score[k] >= WINSCORE then
			shouldSettle = true
		end
		retobj.settle[k]['totalscore'] = deskInfo.panel.score[k]
	end
	for _, user in pairs(deskInfo.users) do
		local key = 1
		if table.contain({2, 4}, user.seatid) then
			key = 2
		end
		if user.race_id > 0 and user.race_type == PDEFINE.RACE_TYPE.ROUND_SCORE then
			pcall(cluster.send, "master", ".raceroommgr", "addRaceScore", user.uid, user.race_id, retobj.settle[key]['score'])
		end
	end
	LOG_DEBUG("roundOver22 settle:",deskInfo.panel.gametype, ' deskid:', deskInfo.deskid, ' settle:',retobj.settle)
	local winKey = 1 --此局赢的一方
	if retobj.settle[1]['xpoints'] < retobj.settle[2]['xpoints'] then
		winKey = 2
	elseif retobj.settle[1]['xpoints'] == retobj.settle[2]['xpoints'] then
		if retobj.settle[1]['floor'] < retobj.settle[2]['floor'] then
			winKey = 2
		end
	end
	if deskInfo.panel.gahwa > 0 then
		retobj.settle[winKey]['score'] = retobj.settle[winKey]['score'] + WINSCORE
		retobj.settle[winKey]['totalscore'] = retobj.settle[winKey]['totalscore'] + WINSCORE
		deskInfo.panel.score[winKey] = deskInfo.panel.score[winKey] + WINSCORE
		shouldSettle = true
	end
	-- 判断是否维护
	local isDismiss = false
	if isMaintain() then
		shouldSettle = true
		isDismiss = true
	end

	-- 判断是否是 baloot fast, 非平局的情况下，一局结束游戏
	if deskInfo.gameid == PDEFINE_GAME.GAME_TYPE.BALOOT_FAST then
		if deskInfo.panel.score[1] ~= deskInfo.panel.score[2] then
			shouldSettle = true
		end
	end

	broadcastDesk(cjson.encode(retobj)) --本轮小结算
	deskInfo.panel.roundscore  = {0, 0}
	local score = 0
	local allCards = {}
	for _, muser in pairs(deskInfo.users) do
		table.insert(allCards, {
			uid = muser.uid,
			cards = muser.round.cards
		})
	end
	if shouldSettle then
		score = table.maxn(deskInfo.panel.score)
	end
	local cost_time = 0
	if deskInfo.roundstime then
		cost_time = os.time() - deskInfo.roundstime
	end
	local sql = string.format("insert into d_desk_game_record(gameid,deskid,uuid,score,win,settle,cards,create_time,decider,gahwa,multiple,suit,gametype,dealer,multipler,roomtype,cost_time) values(%d,%d,'%s',%d,%d,'%s','%s',%d,%d,%d,%d,%d,%d,%d,%d,%d,%d)", 
								deskInfo.gameid,deskInfo.deskid,deskInfo.uuid, score, winKey, cjson.encode(retobj.settle), cjson.encode(allCards), os.time(), deskInfo.panel.uid, deskInfo.panel.gahwa, deskInfo.round.multiple, deskInfo.panel.suit,deskInfo.panel.gametype,deskInfo.round.dealer['uid'], deskInfo.round.multipler, deskInfo.conf.roomtype,cost_time)
	skynet.call(".mysqlpool", "lua", "execute", sql)

	if not shouldSettle then
		changeDealer()
	end
	deskInfo.round.preItem = nil
	deskInfo.round.preUid = nil
	
	LOG_DEBUG("shouldSettle:", shouldSettle, " desk maxRound:", deskInfo.maxRound)
	if shouldSettle then
		LASTWINKEY = winKey
		return gameover(isDismiss) --本局结束
	else
		skynet.timeout(timeout, restUserRound)
	end
	
	return PDEFINE.RET.SUCCESS
end

-------- 设定玩家定时器 --------
function CMD.userSetAutoState(type,autoTime,uid)
    clearAutoFunc(uid)

	local delayTime = autoTime//100
	delayTime = delayTime + 1 -- 前后端延迟1秒
	deskInfo.round.autoExpireTime = os.time() + delayTime

	local user  = queryUserInfo(uid, "uid")
	if type ~= 'autoChooseGameType' then
		if not user.cluster_info then
			delayTime = math.random(1, 3) --机器人随机
		else
			if type ~= "autoReady" and user.auto == 1 then --托管就是快速
				delayTime = math.random(1,3)
			end
		end
		-- 选花色可以多加7秒，防止开局动画比较慢
		if firstDelay then
			delayTime = delayTime + 5
			firstDelay = false
		end
	end

	
	debug_log("CMD.userSetAutoState type:", type, ' timeout:', delayTime, ' uid:', uid)
    if type == "autoChooseGameType" then
		setTimer(uid, delayTime, autoChooseGameType, uid)
    end
	if type == "autoChooseSuit" then
		setTimer(uid, delayTime, autoChooseSuit, uid)
	end
	if type == "autoPutCard" then
		setTimer(uid, delayTime, autoPutCard, uid)
		aiSendEmoji()
    end
	if type == "autoAiPutCard" then
		setTimer(uid, delayTime, autoPutCard, uid)
		aiSendEmoji()
    end
	if type == "autoReady" then
		setTimer(uid, delayTime, autoReady, uid)
    end

	if type == 'roundOver' then
		setTimer(uid, delayTime, roundOver, uid)
	end
end

--! 自动加入机器人
function CMD.aiJoin(source, aiUser)
	return aiJoin(aiUser)
end

--! 退出房间
function CMD.exitG(source, recvobj)
    local uid     = math.floor(recvobj.uid)
	local ret = {c=recvobj.c, uid=recvobj.uid, code=PDEFINE.RET.SUCCESS}
    local user  = queryUserInfo(uid, "uid")
    if user then  --玩家离开 必须存在房间中
		if deskInfo.state == PDEFINE.DESK_STATE.READY or deskInfo.state == PDEFINE.DESK_STATE.MATCH then
			local seatid = user.seatid
			-- 退出房间
            userExit(uid, seatid)
			-- 停止踢人定时器
            stopAutoKickOut()
		-- elseif deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        --     -- 私人房，已经开始游戏，则不能退出房间
        --     ret.spcode = 1
        --     return PDEFINE.RET.SUCCESS, ret
		else
			user.isexit = 1
			user.auto = 1
		end
		user.auto = 1
		pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "deskBack", deskInfo.gameid) --释放桌子对象

		if deskInfo.state ~= PDEFINE.DESK_STATE.READY then
			brodcastUserAutoMsg(user, 1)
		end

		-- 除了私人房，其他房间会自动解散
		-- if deskInfo.conf.roomtype ~= PDEFINE.BAL_ROOM_TYPE.PRIVATE then --房间进入托管打牌状态
		-- 	local autocnt = 0
		-- 	for _, user in pairs(deskInfo.users) do
		-- 		if user.auto == 1 then
		-- 			autocnt = autocnt + 1
		-- 		end
		-- 	end
		-- 	if autocnt >= #deskInfo.users then
		-- 		resetDesk()
		-- 	end
		-- end

    end
	-- 旁观者退出
    local viewer = findViewUser(uid)
    if viewer then
        viewExit(uid)
        pcall(cluster.send, viewer.cluster_info.server, viewer.cluster_info.address, "deskBack", deskInfo.gameid) --释放桌子对象
    end
    return PDEFINE.RET.SUCCESS, ret
end

-- 发起解散
function CMD.applyDismiss(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local user = queryUserInfo(uid, 'uid')

    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.code   = PDEFINE.RET.SUCCESS

    -- 已经不在房间中
    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.NOT_IN_ROOM
        return resp(retobj)
    end

	-- 如果还没有开局，则不需要解散
    if deskInfo.state == PDEFINE.DESK_STATE.MATCH 
    or deskInfo.state == PDEFINE.DESK_STATE.SETTLE 
    or deskInfo.state == PDEFINE.DESK_STATE.READY then
        retobj.spcode = PDEFINE.RET.ERROR.GAME_NOT_SART
        return resp(retobj)
    end

    -- 如果已经有人发起解散，则这个解散无效
    if dismiss then
        retobj.spcode = PDEFINE.RET.ERROR.GAME_ALREADY_DELTE
        return resp(retobj)
    end

    dismiss = {
        uid = uid,  -- 发起人
        users = {},  -- 其他人信息以及是否同意
        expireTime = os.time()+PDEFINE.GAME.DISMISS_DELAY_TIME,  -- 解散倒计时时长
        _autoFunc = nil,
    }

    for _, user in ipairs(deskInfo.users) do
        if user.uid ~= uid then
            table.insert(dismiss.users, {uid=user.uid, status=0})
        else
            table.insert(dismiss.users, {uid=user.uid, status=1})
        end
    end

    dismiss._autoFunc = user_set_timeout(PDEFINE.GAME.DISMISS_DELAY_TIME*100, function()
		-- 记录到数据库
		recodeDismissInfo(PDEFINE.GAME.DISMISS_STATUS.Timeout, uid)
		-- gameover(true)
		local notify_object = {
			c = PDEFINE.NOTIFY.GAME_DISMISS_TIMEOUT,
            code = PDEFINE.RET.SUCCESS,
            dismiss = {
				uid = dismiss.uid,  -- 发起人
                users = dismiss.users,  -- 其他人信息以及是否同意
                delayTime = 0  -- 解散时间
            },
        }
        broadcastDesk(cjson.encode(notify_object))
        -- 超时
        if dismiss then
            dismiss._autoFunc()
        end
        dismiss = nil
		
        -- 恢复用户身上的定时器
        recoverTimer()
		
	end)

	-- 机器人自动同意
    skynet.timeout(100, function ()
        for _, u in ipairs(deskInfo.users) do
            if not u.cluster_info then
                CMD.replyDismiss(nil, {uid=u.uid,rtype=1})
            end
        end
    end)

	-- 取消用户身上的定时器
    pauseTimer()

	-- 记录到数据库
    recodeDismissInfo(PDEFINE.GAME.DISMISS_STATUS.Waiting, uid)

    retobj.dismiss = {
        uid = uid,  -- 发起人
        users = dismiss.users,  -- 其他人信息以及是否同意
        delayTime = dismiss.expireTime-os.time(),  -- 解散时间
    }

    -- 广播消息给其他玩家
    local notify_object = {
        c = PDEFINE.NOTIFY.PLAYER_APPLY_DISMISS,
        code = PDEFINE.RET.SUCCESS,
        dismiss = retobj.dismiss
    }
    broadcastDesk(cjson.encode(notify_object), uid)

    return resp(retobj)
end

-- 同意/拒绝 解散房间
function CMD.replyDismiss(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local rtype = math.floor(recvobj.rtype or 2)  -- 默认不同意, 1: 同意，2: 不同意
    local user = queryUserInfo(uid, 'uid')

    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.code   = PDEFINE.RET.SUCCESS

    -- 已经不在房间中
    if not user then
        retobj.spcode = 1
        return resp(retobj)
    end

    -- 没人发起解散
    if not dismiss then
        retobj.spcode = 2
        return resp(retobj)
    end
    local allAgree = true
    for _, user in ipairs(dismiss.users) do
        if user.uid == uid then
            user.status = rtype
        end
        -- 只要有一个人还没有选择，则就不能解散房间
        if user.status ~= 1 then
            allAgree = false
        end
    end

    local notify_object = {
        c = PDEFINE.NOTIFY.PLAYER_REPLY_DISMISS,
        code = PDEFINE.RET.SUCCESS,
        uid = uid,
        rtype = rtype,
        dismiss = {
            uid = dismiss.uid,  -- 发起人
            users = dismiss.users,  -- 其他人信息以及是否同意
            delayTime = dismiss.expireTime-os.time()  -- 解散时间
        },
    }
    broadcastDesk(cjson.encode(notify_object))

    if rtype == 1 then
        -- 同意， 判断所有人是否同意，同意则解散房间
        if allAgree then
			-- 记录到数据库
            recodeDismissInfo(PDEFINE.GAME.DISMISS_STATUS.Agree, dismiss.uid)
            dismiss._autoFunc()
            dismiss = nil
            gameover(true)
        end
    else
		-- 记录到数据库
		recodeDismissInfo(PDEFINE.GAME.DISMISS_STATUS.Refuse, dismiss.uid)
        -- 不同意
        dismiss._autoFunc()
        dismiss = nil

		-- 恢复用户身上的定时器
        recoverTimer()
    end
    return resp(retobj)
end

--! 当手上有同花顺或者4个相同牌的时候
function CMD.sira(source, msg)
	local recvobj  = msg
	local uid = math.floor(recvobj.uid)
	local rtype = math.floor(recvobj.rtype or 0) --加的分数 1:400, 2:100, 3:50, 4:sira
	if nil == deskInfo.round.sira then
		deskInfo.round.sira = {}
	end

	if deskInfo.round.sira[uid] then
		debug_log("CMD.sira 已经sira过了 uid:", uid)
		return PDEFINE.RET.SUCCESS
	end

	local user = queryUserInfo(uid, 'uid')
	local tbl = balootutil.calSequence(user.round.cards, deskInfo.panel.gametype)
	if table.empty(tbl) then
		debug_log("CMD.sira uid", uid, " 没有4张或者顺子")
		return PDEFINE.RET.ERROR.PUT_CARD_ERROR --没有4张或者顺子
	end
	-- clearAutoFunc(uid) --这里不用去掉定时器,方便用户继续往下操作

	local key = 1
	if user.seatid % 2 == 0 then
		key = 2
	end

	local retobj  = {}
	retobj.c      = PDEFINE.NOTIFY.BALOOT_GAME_SIRA_ACT
	retobj.code   = PDEFINE.RET.SUCCESS
	retobj.seat   = user.seatid
	retobj.uid    = uid
	retobj.rtype  = rtype
	retobj.score  = 0

	local notify = {
		c = PDEFINE.NOTIFY.BALOOT_GAME_SIRA_RESULT,
		code   = PDEFINE.RET.SUCCESS,
		seat   = user.seatid,
		uid    = uid,
		rtype  = rtype,
		score  = 0,
		cards  = {},
		now = true --标记是不是要跳过一把
	}
	if user.auto == 1 then
		notify.now = false --服务器托管状态，出完牌才请求的sira操作，不需要再跳过1把
	end	
	for _, item in pairs(tbl) do
		retobj.score = retobj.score + item['score'] --显示分数
		table.insert(notify.cards, item['cards'])
		deskInfo.round.settle[key]["projects"] = deskInfo.round.settle[key]["projects"] + item['ps'] --实际加的分数
		table.insert(deskInfo.round.settle[key]["projectslist"], item)
	end
	broadcastDesk(cjson.encode(retobj))
	notify.score = retobj.score
	
	deskInfo.round.sira[uid] = notify --先存起来，待他第2轮出牌时候广播
	debug_log("CMD.sira data uid:", uid, 'notify:', notify)

	if table.size(deskInfo.round.sira) > 1 then --两方同时可以sira的时候，小的一方不能sira
		local battle = {{mscore = 0}, {mscore =0}}
		local seats = {}
		for uid, row in pairs(deskInfo.round.sira) do
			if row ~= nil then
				local key = 1
				if row.seat % 2 == 0 then
					key = 2
				end
				if nil == seats[key] then
					seats[key] = {}
				end
				table.insert(seats[key], uid)
				if row.rtype and battle[key].mscore < row.rtype  then
					battle[key].mscore = row.rtype
				end
			end
		end
		if battle[1].mscore ~= battle[2].mscore then
			local key = 1
			if battle[1].mscore > battle[2].mscore then
				key = 2
			end

			for _, deluid in pairs(seats[key]) do
				deskInfo.round.sira[deluid] = nil
			end
		end
	end
	
	return PDEFINE.RET.SUCCESS
end

--! 用户sawa
function CMD.sawa(source, msg)
	local recvobj  = msg
	local uid = math.floor(recvobj.uid)
	local user = queryUserInfo(uid, 'uid')
	local resp = {c = recvobj.cmd, code= PDEFINE.RET.SUCCESS, spcode=0}
	if user.seatid ~= deskInfo.round.putNextSeat then
		resp['spcode'] = 1
		return PDEFINE.RET.SUCCESS, resp
	end

	clearAutoFunc(uid)

	if #user.round.handInCards > 5 then
		resp['spcode'] = 2
		return PDEFINE.RET.SUCCESS, resp
	end

	local otherCards = {}
	for _, muser in pairs(deskInfo.users) do
		if muser.uid ~= uid then
			otherCards[muser.seatid] = muser.round.handInCards
		end
	end

	local ok, score = balootutil.canSawa(user.round.handInCards, otherCards, deskInfo.panel.gametype, deskInfo.panel.suit)
	if not ok then
		resp['spcode'] = 3
		return PDEFINE.RET.SUCCESS, resp
	end
	otherCards[user.seatid] = user.round.handInCards
	local retobj  = {}
	retobj.c      = PDEFINE.NOTIFY.BALOOT_SAWA
	retobj.code   = PDEFINE.RET.SUCCESS
	retobj.score   = score
	retobj.uid    = uid
	retobj.handCardCount  = 0
	retobj.showCards  = otherCards
	user.round.roundscore = user.round.roundscore + score
	for _, muser in pairs(deskInfo.users) do
		muser.round.handInCards = {}
		muser.round.handCardCount = 0
	end
	broadcastDesk(cjson.encode(retobj))

	deskInfo.round.floorseat = user.seatid
	skynet.timeout(200, roundOver)

	return PDEFINE.RET.SUCCESS
end

-- hokom玩法中出ace 或 baloot提示
local function checkTips(user, outCard)
	local tips = 0 
	if deskInfo.panel.gametype == balcfg.TYPE.HOKOM then
		-- ACE
		-- 1、玩Hokom玩法（第一轮玩Hokom，第二轮再叫 XX Hokom）
		-- 2、打牌中，当打完非主花色的A后，第一个出牌且出的是非主花色非A的该花色最大的牌，系统会对出牌玩家叫A【ACE】
		local firtColor = getCardColor(outCard)
		local value = getCardValue(outCard)
		LOG_DEBUG("checkTips uid:", user.uid, ' outCards color:', firtColor, ' deskInfo.panel.suit:',deskInfo.panel.suit, ' val:', value)
		if #deskInfo.round.showCard == 1 and (firtColor ~= deskInfo.panel.suit) and value~=14 then --副牌，第1个出牌
			local allColorCards = {}
			local hadA = false
			for _, muser in pairs(deskInfo.users) do
				for _, card in pairs(muser.round.handInCards) do
					if getCardColor(card) == firtColor then
						table.insert(allColorCards, card)
						local val = getCardValue(card)
						if val == 14 then
							hadA = true
						end
					end
				end
			end
			LOG_DEBUG("balootutil.checkTips hadA:", hadA)
			if not hadA then
				local maxcard = balootutil.getSunMaxCard(allColorCards, firtColor)
       	 		LOG_DEBUG("balootutil.cardIsMax maxcard:", getCardColor(maxcard), ' val:', getCardValue(maxcard))
			    local ret = balootutil.compairCard(outCard, maxcard, 2, false)
			    if ret then 
					tips = 1
				end
			end
		end

		--baloot是 当你有主花色的Qk时，出第一张Q或K不宣布Baloot，当您打出第二张Q或K时宣布Baloot
		
		if firtColor == deskInfo.panel.suit and (value == 12 or value == 13) then
			if balootutil.canBaloot(deskInfo.panel.suit, user, value) then
				tips = 2
			end
		end
	end
	return tips
end

local function notifySiraCards(uid)
	debug_log("notifySiraCards uid:", uid, " begin:")
	if nil~=deskInfo.round.sira and nil ~= deskInfo.round.sira[uid] then
		if deskInfo.round.sira[uid].now then
			deskInfo.round.sira[uid].now = false
			return
		end
		debug_log("notifySiraCards uid:", uid, " notify:", deskInfo.round.sira[uid])
		broadcastDesk(cjson.encode(deskInfo.round.sira[uid]))
		deskInfo.round.sira[uid] = nil
	end
end

-- 最后一轮自动亮牌，所有人都亮
local function autoShowCards(uid)
    local firstUser = queryUserInfo(uid, 'uid')
    local currUser = firstUser
    while true do
        -- 加入到弃牌堆
        local card = table.remove(currUser.round.handInCards)
        table.insert(deskInfo.round.showCard, card)
		deskInfo.round.showCardUsers[currUser.uid] = card
		currUser.round.handCardCount = 0
		local nextseat = findNextSeat(currUser.seatid) --下一个出牌的位置
		deskInfo.round.putNextSeat = nextseat
		currUser = queryUserInfo(nextseat, 'seatid')
        if currUser.uid == firstUser.uid then
            break
        end
    end

    -- 判断大小
	local score, maxUserId
	if deskInfo.panel.gametype == balcfg.TYPE.SUN or deskInfo.panel.gametype == balcfg.TYPE.ASHKAL then
		score, maxUserId = balootutil.calCardScoreInSun(deskInfo.round.showCard[1], deskInfo.round.showCardUsers)
	else
		score, maxUserId = balootutil.calCardScoreInHokom(deskInfo.round.showCard[1], deskInfo.round.showCardUsers, deskInfo.panel.suit)
	end
	local maxUser = queryUserInfo(maxUserId, 'uid')
	maxUser.winTimes = maxUser.winTimes + 1
	maxUser.round.roundscore = maxUser.round.roundscore + score --他的牌最大，他得分
	local key = 1
	if maxUser.seatid % 2 == 0 then
		key = 2
	end
	if maxUser.race_id > 0 and maxUser.race_type == PDEFINE.RACE_TYPE.BALOOT_COMPARE_WIN then
		pcall(cluster.send, "master", ".raceroommgr", "addRaceScore", maxUser.uid, maxUser.race_id, 1)
	end
	deskInfo.panel.roundscore[key] = deskInfo.panel.roundscore[key] + score
	deskInfo.round.putNextSeat = maxUser.seatid

    -- 广播给房间里的所有人
    local notify_object = {}
    notify_object.c  = PDEFINE.NOTIFY.PLAYER_AUTO_DISCARD_CARD
    notify_object.code = PDEFINE.RET.SUCCESS
    notify_object.startSeatid = firstUser.seatid
    notify_object.cards   = table.copy(deskInfo.round.showCard)
    notify_object.winSeatid = maxUser.seatid
    notify_object.roundCards = table.copy(deskInfo.round.showCard)
	notify_object.score = score

	for _, muser in pairs(deskInfo.users) do
		if muser.cluster_info and muser.isexit == 0 then
			pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", cjson.encode(notify_object)) --广播玩家
		end
	end

	broadcastView(cjson.encode(notify_object))

	deskInfo.round.showCard = {}
	deskInfo.round.showCardUsers = {}
	deskInfo.round.floorseat = maxUser.seatid

    skynet.timeout(100, function()
		roundOver()
    end)
end

--! 出牌
function CMD.putCard(source, msg)
	local recvobj  = msg
	local uid = math.floor(recvobj.uid)
	local outCard = math.floor(recvobj.card or 0) --出的牌
	debug_log("putCard  uid:", uid, ' outCard:', outCard)
	local resp = {c = recvobj.cmd, code= PDEFINE.RET.SUCCESS, spcode=0}
	if outCard == 0  then --1次只能出1张,且必须是1张
		debug_log("你出个空气呀, uid:", uid)
		resp.spcode = PDEFINE.RET.ERROR.PUT_CARD_ERROR
		return PDEFINE.RET.SUCCESS, resp
	end
	local user = queryUserInfo(uid,"uid")
	if user.seatid and deskInfo.round.putNextSeat ~= user.seatid then --是不是轮到他出牌
		debug_log("不是你出牌呀 下一个出牌座位:", deskInfo.round.putNextSeat, ' 你的座位:', user.seatid)
		resp.spcode = PDEFINE.RET.ERROR.PUT_CARD_ERROR
		return PDEFINE.RET.SUCCESS, resp
	end

	clearAutoFunc(user.uid)

	--校验手牌
	if not table.contain(user.round.handInCards, outCard) then
		debug_log("你都没有这张牌呀 card:", outCard, ' user.round.handInCards:', user.round.handInCards)
		resp.spcode = PDEFINE.RET.ERROR.PUT_CARD_ERROR
		return PDEFINE.RET.SUCCESS, resp
	end
	if #deskInfo.round.showCard > 0 then
		local firtCard = deskInfo.round.showCard[1]
		local color = getCardColor(firtCard) --第1张牌的花色
		if getCardColor(outCard) ~= color then --手牌里有相同花色的话，必须优先出此花色
			for _, card in pairs(user.round.handInCards) do
				if getCardColor(card) == color then
					debug_log("user uid:", user.uid, ' cards:', user.round.handInCards, ' card:', card)
					debug_log("必须先出同花色, card:", card)
					resp.spcode = PDEFINE.RET.ERROR.PUT_CARD_ERROR
					return PDEFINE.RET.SUCCESS, resp
				end
			end
		end
	end

	if nil ~= deskInfo.round.showCardUsers[uid] then
		debug_log("这轮已经出过牌了...uid:", uid, ' card:', deskInfo.round.showCardUsers[uid])
		resp.spcode = PDEFINE.RET.ERROR.PUT_CARD_ERROR
		return PDEFINE.RET.SUCCESS, resp
	end

	local voice = 0
	-- local allCards = {}
	-- local color = getCardColor(outCard)
	-- for _, user in pairs(deskInfo.users) do
	-- 	for _, card in pairs(user.round.handInCards) do
	-- 		if getCardColor(card) == color then
	-- 			table.insert(allCards, card) --加上用户们的手牌
	-- 		end
	-- 	end
	-- end
	-- if balootutil.cardIsMax(outCard, allCards, deskInfo.panel.gametype, deskInfo.panel.suit, deskInfo.round.showCard) then
	-- 	voice = 1 --是最大的，就说话
	-- end
	table.insert(deskInfo.round.discardCards, outCard)
	table.insert(deskInfo.round.showCard, outCard)
	deskInfo.round.showCardUsers[uid] = outCard
	delHandCards(user,outCard) --删除手牌

	user.round.handCardCount = #user.round.handInCards

	local retobj    = {}
    retobj.code     = PDEFINE.RET.SUCCESS
    retobj.c        = PDEFINE.NOTIFY.BALOOT_PUT_CARD
	retobj.uid      = uid
	retobj.score    = 0 --本次出牌要加的分数
	retobj.nextseat = 0 --下1个出牌的位置
	retobj.handCardCount = #user.round.handInCards
	retobj.showCards = deskInfo.round.showCard
    retobj.timeout = math.floor(timeout/100)
    retobj.outCard = outCard --出的牌
	retobj.tips = checkTips(user, outCard) -- 0无， 1ace， 2baloot
	retobj.voice = voice --它是不是最大的牌

	deskInfo.round.preUid = uid

	if #deskInfo.round.showCard ~= 4 then
		retobj.nextseat = findNextSeat(user.seatid) --下一个出牌的位置
		deskInfo.round.putNextSeat = retobj.nextseat
		local nextUser = queryUserInfo(retobj.nextseat, 'seatid')
		if nextUser.cluster_info then
			local mytimeout = timeout
			if nextUser.auto == 1 then
				mytimeout = 20
			end
			debug_log("设置用户:".. nextUser.uid .. ' 自动出牌 timeout:'.. mytimeout)
			CMD.userSetAutoState('autoPutCard', mytimeout, nextUser.uid)
		else
			local mytimeout = math.random(100, timeout)
			CMD.userSetAutoState('autoAiPutCard', mytimeout, nextUser.uid)
		end
		for _, muser in pairs(deskInfo.users) do
			if muser.cluster_info and muser.isexit == 0 then
				if user.uid == muser.uid and recvobj.is_auto then
					retobj.is_auto = 1
				else
					retobj.is_auto = nil
				end
				pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", cjson.encode(retobj))
			end
	    end
		broadcastView(cjson.encode(retobj))
		notifySiraCards(uid)
	else
		local score, maxUserId
		if deskInfo.panel.gametype == balcfg.TYPE.SUN or deskInfo.panel.gametype == balcfg.TYPE.ASHKAL then
			score, maxUserId = balootutil.calCardScoreInSun(deskInfo.round.showCard[1], deskInfo.round.showCardUsers)
		else
			score, maxUserId = balootutil.calCardScoreInHokom(deskInfo.round.showCard[1], deskInfo.round.showCardUsers, deskInfo.panel.suit)
		end
		local maxUser = queryUserInfo(maxUserId, 'uid')
		maxUser.winTimes = maxUser.winTimes + 1
		maxUser.round.roundscore = maxUser.round.roundscore + score --他的牌最大，他得分
		local key = 1
		if maxUser.seatid % 2 == 0 then
			key = 2
		end
		if maxUser.race_id > 0 and maxUser.race_type == PDEFINE.RACE_TYPE.BALOOT_COMPARE_WIN then
			pcall(cluster.send, "master", ".raceroommgr", "addRaceScore", maxUser.uid, maxUser.race_id, 1)
		end
		deskInfo.panel.roundscore[key] = deskInfo.panel.roundscore[key] + score
		deskInfo.round.putNextSeat = maxUser.seatid
		deskInfo.round.showCardUsers = {}
		deskInfo.round.showCard = {}
		deskInfo.round.lastSeatid = user.seatid

		retobj.nextseat = maxUser.seatid --下一个出牌的位置
		retobj.score = score --此次牌的得分
		if #maxUser.round.handInCards == 1 then --最后一轮出牌人只有1张的时候，机器人不用读秒
			retobj.timeout = 0
			skynet.timeout(30, function()
                autoShowCards(maxUser.uid)
            end)
		else
			if maxUser.cluster_info then
				local mytimeout = timeout
				CMD.userSetAutoState('autoPutCard', mytimeout, maxUser.uid)
			else
				CMD.userSetAutoState('autoAiPutCard', math.random(200, timeout), maxUser.uid)
			end
		end
		retobj.sawa = 0
		retobj.sawascore = 0
		if 1 < user.round.handCardCount and user.round.handCardCount <= 5 then
			local otherCards = {}
			for _, muser in pairs(deskInfo.users) do
				if muser.uid ~= maxUserId then
					otherCards[muser.seatid] = muser.round.handInCards
				end
			end

			local sawa, score = balootutil.canSawa(maxUser.round.handInCards, otherCards, deskInfo.panel.gametype, deskInfo.panel.suit)
			if sawa then
				retobj.sawa, retobj.sawascore = 1, score
			end
		end

		for _, muser in pairs(deskInfo.users) do
			if muser.cluster_info and muser.isexit == 0 then
				if user.uid == muser.uid and recvobj.is_auto then
					retobj.is_auto = 1
				else
					retobj.is_auto = nil
				end
				pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", cjson.encode(retobj)) --广播玩家
			end
		end
		broadcastView(cjson.encode(retobj))
		notifySiraCards(uid)

		if user.round.handCardCount == 0 then --手上的牌都出完了, 小结算
			deskInfo.round.floorseat = maxUser.seatid
			roundOver()
		end
	end
	return PDEFINE.RET.SUCCESS
end

function CMD.enterAuto(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local user = queryUserInfo(uid,"uid")

    local retobj = {c = recvobj.c, code= PDEFINE.RET.SUCCESS, spcode=0}

    if user.auto == 1 then
        return resp(retobj)
    end

    user.auto = 1 -- 进入托管

    brodcastUserAutoMsg(user, 1)
    
    return resp(retobj)
end

--! 出牌过程中 取消托管
function CMD.cancelAuto(source, msg)
	local recvobj  = msg
	LOG_DEBUG('cancelAuto, msg:', recvobj)
	local uid = math.floor(recvobj.uid)
	local user = queryUserInfo(uid,"uid")

	local resp = {c = recvobj.c, code= PDEFINE.RET.SUCCESS, spcode=0}
	if user.auto == 0 then
		return PDEFINE.RET.SUCCESS, resp
	end
	
	clearAutoFunc(uid)
	user.auto = 0 --关闭自动
	
	brodcastUserAutoMsg(user, 0)
	
	if deskInfo.round.putNextSeat == user.seatid and deskInfo.state == PDEFINE.DESK_STATE.PLAY then
		local leftTime = timeout
		CMD.userSetAutoState('autoPutCard', leftTime, user.uid)
	end

	if deskInfo.state == PDEFINE.DESK_STATE.BIDDING then
		if deskInfo.round.nextuids and table.contain(deskInfo.round.nextuids, uid) then
			if deskInfo.round.road == 304 and deskInfo.round.tmpgametype == balcfg.TYPE.CONFIRM then
				CMD.userSetAutoState("autoChooseSuit", timeout, user.uid)
			else
				CMD.userSetAutoState("autoChooseGameType", timeout, user.uid)
			end
		end
	end
	
	return PDEFINE.RET.SUCCESS, resp
end

--! 更新玩家的桌子信息
function CMD.updateUserClusterInfo(source, uid, agent)
	debug_log("updateUserClusterInfo set user agent uid:", uid, " agent:", agent)
    local user = queryUserInfo(uid,"uid")
    if not user then
        user = findViewUser(uid)
    end
    if nil ~= user and user.cluster_info then
        user.cluster_info.address = agent
		debug_log("updateUserClusterInfo  user new cluster_info:", user.cluster_info)
    end
end

-- 广播选择的结果
local function broacastResult(uid, stype, obj, exclude, cmd)
	debug_log("broacastResult 开始广播 现在操作人uid：", uid, " stype:", stype,  " obj:", obj, ' exclude:', exclude, ' cmd:',cmd)
	if nil == obj then
		obj = {0,0} --uid,seatid
	end

	deskInfo.round.preUid = uid --断线重连使用
	deskInfo.round.preItem = stype
	if obj[2] > 0 then
		deskInfo.round.putNextSeat = obj[2]
	end

	local retobj    = {}
	retobj.code     = PDEFINE.RET.SUCCESS
	retobj.c        = cmd or PDEFINE.NOTIFY.BALOOT_SELECT_RESULT
	retobj.uid      = uid
	retobj.gametype = stype
	retobj.round    = deskInfo.round.selecttimes
	retobj.nextuid  = obj[1]
	retobj.nextseat = obj[2]
	retobj.otheruids = {}  --下一步操作的人的uid（多个)
	if nil ~= obj[4] then
		retobj.otheruids = obj[4]
	end
	retobj.timeout = math.floor(timeout/100)
	if deskInfo.round.showsuit ~= nil then
		retobj.showsuit = deskInfo.round.showsuit
	end
	if obj[1] > 0 then
		retobj.nextgametype = deskInfo.round.nexgametype
		if obj[3] ~= nil then
			retobj.nextgametype = obj[3]
		end
	else
		retobj.nextgametype = {}
	end
	
	debug_log("开始广播 现在操作人：", uid, " 我选择的是:", stype,  " 下一步谁操作:", retobj.nextuid)
	if exclude then
		broadcastDesk(cjson.encode(retobj), uid) --广播结果，排除自己
	else
		broadcastDesk(cjson.encode(retobj)) --广播结果
	end

	debug_log("round:", retobj.round, ' 下1个操作人:', retobj.nextuid, ' retobj:', retobj)
	if obj[4] ~= nil then
		debug_log("广播给nextuids赋值:", table.concat(deskInfo.round.nextuids, ','))
		for _, actuid in pairs(obj[4]) do
			local user = queryUserInfo(actuid, 'uid')
			if user then
				local random_time = timeout
				if not user.cluster_info then
					random_time = math.random(200, timeout)
				end				
				CMD.userSetAutoState("autoChooseGameType", random_time, actuid)
			end
		end
	else
		if obj[1] > 0 then
			if #deskInfo.round.nextuids > 0 then
				debug_log("obj[1] 广播给nextuids赋值:", table.concat(deskInfo.round.nextuids, ','))
			end
			
			debug_log("obj:", obj, ' nextgametype:', deskInfo.round.nexgametype)
			local user = queryUserInfo(obj[1], 'uid')
			if user then
				local random_time = timeout
				if not user.cluster_info then
					random_time = math.random(200, timeout)
				end	
				CMD.userSetAutoState("autoChooseGameType", random_time, user.uid)
			end
		end
	end
end

--! 最后1名用户选择GAHWA 或者pass TODO: 判断流程
function CMD.GAHWAOrPass(source, msg)
	local recvobj  = msg
	local uid = math.floor(recvobj.uid)
	local stype = math.floor(recvobj.item or 0) --8:GAHWA, 4:pass

	local resp = {c = recvobj.cmd, code= PDEFINE.RET.SUCCESS, spcode=0}

    local user = queryUserInfo(uid) --当前操作用户
	debug_log("user GAHWAOrPass. uid:", uid, ' game_type:', stype, ' user.seatid:', user.seatid , ' 现在操作的位置:', deskInfo.round.putNextSeat)
	if not table.contain(deskInfo.round.nextuids, user.uid) then
		resp['spcode'] = 1 --不是他开始
		return PDEFINE.RET.SUCCESS, resp
	end

	if deskInfo.state ~= PDEFINE.DESK_STATE.BIDDING or deskInfo.round.road ~= 309 then
		resp['spcode'] = 2 --不是第2轮，不让操作
		return PDEFINE.RET.SUCCESS, resp
	end
	clearAutoFunc(user.uid)

	debug_log("user GAHWAOrPass. uid:", uid, ' game_type:', stype)

	deskInfo.round.choose = {}
	deskInfo.panel.gametype = balcfg.TYPE.HOKOM

	if stype == balcfg.TYPE.GAHWA then --我hokom,对方4倍后, 我一把定输赢
		debug_log("我hokom,对方4倍后, 我一把定输赢:", uid)
		deskInfo.round.gametype = balcfg.TYPE.HOKOM
		deskInfo.round.preUid = uid --断线重连使用
		deskInfo.round.preItem = stype
		deskInfo.round.nextuids = {}
		deskInfo.round.multiple = 8
		deskInfo.panel.gahwa = 1
		deskInfo.round.hokomer['uid'] = user.uid
		deskInfo.round.hokomer['seatid'] = user.seatid
	else --我hokom后，对方4倍，我pass
		deskInfo.round.multiple = 4
		deskInfo.round.hokomer['uid'] = deskInfo.round.preUid
		local hokomer = queryUserInfo(deskInfo.round.hokomer['uid'], 'uid')
		deskInfo.round.hokomer['seatid'] = hokomer.seatid
	end
	broacastResult(uid, stype, nil, true)
	endChooseGameTypeRunGame(deskInfo.round.hokomer['uid'], balcfg.TYPE.HOKOM)
	return PDEFINE.RET.SUCCESS
end

--! 锁住或者open
function CMD.actLockOrOpen(source, msg)
	local recvobj  = msg
	local uid = math.floor(recvobj.uid)
	local stype = math.floor(recvobj.item or 0) --加的分数 9:lock, 10:open

	local resp = {c = recvobj.cmd, code= PDEFINE.RET.SUCCESS, spcode=0}

    local user = queryUserInfo(uid) --当前操作用户
	debug_log("user actLockOrOpen. uid:", uid, ' game_type:', stype, ' user.seatid:', user.seatid , ' deskInfo.round.putNextSeat:', deskInfo.round.putNextSeat)
	debug_log("user actLockOrOpen road:", deskInfo.round.road, " deskInfo.round.nextuids:", table.concat(deskInfo.round.nextuids, ','), ' state:', deskInfo.state)
	
	if deskInfo.state ~= PDEFINE.DESK_STATE.BIDDING then
		resp['spcode'] = 2 --不是第2轮，不让锁
		return PDEFINE.RET.SUCCESS, resp
	end
	if not table.contain(deskInfo.round.nextuids, uid) then
		resp['spcode'] = 1 --不是他开始
		return PDEFINE.RET.SUCCESS, resp
	end
	clearAutoFunc(user.uid)
	deskInfo.panel.open = stype

	if deskInfo.round.road == 305 then --我2倍后 open/lock
		deskInfo.round.road = 306  --TODO:断线重连
		deskInfo.round.nextuids = {deskInfo.round.hokomer['uid']}
		deskInfo.round.nexgametype = {balcfg.TYPE.THREE,  balcfg.TYPE.PASS}

		debug_log("user actLockOrOpen uid:", uid, ' next road:', deskInfo.round.road, ' nextuids:', table.concat(deskInfo.round.nextuids, ','))
		debug_log("user actLockOrOpen uid:", uid, ' next road:', deskInfo.round.road,' nexgametype:', deskInfo.round.nexgametype)

	 	broacastResult(uid, stype, {deskInfo.round.hokomer['uid'], deskInfo.round.hokomer['seatid'], nil})

		return PDEFINE.RET.SUCCESS
	end

	if deskInfo.round.road == 308 then --我hokom，对方4倍后，open/locak
		deskInfo.round.road = 309 --TODO:断线重连
		deskInfo.round.nextuids = {deskInfo.round.hokomer['uid']}
		deskInfo.round.nexgametype = {balcfg.TYPE.GAHWA,  balcfg.TYPE.PASS}
		debug_log("user actLockOrOpen uid:", uid, ' next road:', deskInfo.round.road, ' nextuids:', table.concat(deskInfo.round.nextuids, ','))
		debug_log("user actLockOrOpen uid:", uid, ' next road:', deskInfo.round.road,' nexgametype:', deskInfo.round.nexgametype)
	 	broacastResult(uid, stype, {deskInfo.round.hokomer['uid'], deskInfo.round.hokomer['seatid']})
		return PDEFINE.RET.SUCCESS
	end


	return PDEFINE.RET.SUCCESS
end

local function canAshkal(user)
	if not user then
		debug_log("filterAshKal canAshkal nil nextUser:", user)
		return false
	end
	if 14 == getCardValue(deskInfo.show) then
		return false
	end
	if user.uid == deskInfo.round.dealer['uid'] then --自己是庄
		return true
	end

	if user.nextseatid == deskInfo.round.dealer['seatid'] then --下家是庄
		return true
	end

	return false
end

local function filterAshKal(user, items)
	if nil == user then
		return {}
	end
	debug_log("filterAshKal self nextUser uid:", user.uid)
	if not canAshkal(user) then
		local tmp = table.copy(items)
		for i=#tmp, 1, -1 do
			if tmp[i] == balcfg.TYPE.ASHKAL then
				table.remove(tmp, i)
				break
			end
		end
		return tmp
	end
	return items
end

--! 选花色 second hokom
function CMD.chooseSuit(source, msg)
	local recvobj  = msg
	local uid = math.floor(recvobj.uid)
	local color = math.floor(recvobj.color or 0) --黑红梅花方: 64,48,32,16
	local resp = {c = recvobj.cmd, code= PDEFINE.RET.SUCCESS, spcode=0}
	if deskInfo.round.gametype ~= balcfg.TYPE.HOKOM then
		return PDEFINE.RET.SUCCESS, resp
	end

    local user = queryUserInfo(uid) --当前操作用户
	debug_log("user chooseSuit. uid:", uid, ' game_type:', deskInfo.round.gametype, ' user.seatid:', user.seatid , ' deskInfo.round.putNextSeat:', deskInfo.round.putNextSeat)
	
	if not table.contain(deskInfo.round.nextuids, uid) then
		resp['spcode'] = 1 --不是他开始
		return PDEFINE.RET.SUCCESS, resp
	end

	if not table.contain({16,32,48,64}, color) then
		resp['spcode'] = 2 --不是第2轮，不让锁
		return PDEFINE.RET.SUCCESS, resp
	end
	if deskInfo.state ~= PDEFINE.DESK_STATE.BIDDING then
		resp['spcode'] = 4 
		return PDEFINE.RET.SUCCESS, resp
	end
	
	local showColor = getCardColor(deskInfo.show)
	if showColor == color then
		resp['spcode'] = 3 --此花色不让选
		return PDEFINE.RET.SUCCESS, resp
	end
	clearAutoFunc(user.uid)
	if deskInfo.round.road == 304 then
		deskInfo.round.road = 311 --TODO:断线重连
		deskInfo.panel.suit = color
		local nextUser = queryUserInfo(user.nextseatid, 'seatid') --我的下家
		local parterSeatId = getParterSeatid(nextUser)
		local parter = queryUserInfo(parterSeatId, 'seatid') --下家的队友(我的上家)
		deskInfo.round.nexgametype = {balcfg.TYPE.TWO, balcfg.TYPE.PASS}
		deskInfo.round.nextuids = {nextUser.uid, parter.uid}
	
		deskInfo.round.preUid = uid
		deskInfo.round.preItem = color

		debug_log("我选花色 uid：", uid, " 花色是:", color,  " 下一步上下家2人同时选double:", table.concat(deskInfo.round.nextuids, ','))
		local retobj    = {}
		retobj.code     = PDEFINE.RET.SUCCESS
		retobj.c        = PDEFINE.NOTIFY.BALOOT_SUIT_SELECTED
		retobj.uid      = uid
		retobj.gametype = color
		retobj.round    = deskInfo.round.selecttimes
		retobj.otheruids = deskInfo.round.nextuids --下一步操作的人的uid（多个)
		retobj.timeout = math.floor(timeout/100)
		retobj.nextgametype = deskInfo.round.nexgametype
		if deskInfo.round.showsuit ~= nil then
			retobj.showsuit = deskInfo.round.showsuit
		end
		for _, muser in pairs(deskInfo.users) do
			if table.contain(deskInfo.round.nextuids, muser.uid) then
				deskInfo.round.putNextSeat = muser.seatid
				retobj.nextuid  = muser.uid
				retobj.nextseat = muser.seatid
				debug_log("选择second hokom 我选花色 uid：", uid, " 下一家定时 选double/pass uid:", muser.uid)
				
				local random_time = timeout
				if not muser.cluster_info then
					random_time = math.random(200, timeout)
				end
				CMD.userSetAutoState("autoChooseGameType", random_time, muser.uid)
				if muser.cluster_info and muser.isexit==0 then
					pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", cjson.encode(retobj))
				end
			else
				retobj.nextuid = 0
				retobj.nextseat = 0
				if muser.cluster_info and muser.isexit == 0 then
					pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", cjson.encode(retobj))
				end
			end
		end
	end

	return PDEFINE.RET.SUCCESS, resp
end

--sun玩法翻倍的特殊规则
local SUN_DOUBLE = 100
local function doubleInSun(uid, seatid, stype, nextUser)
	local myTeamId, otherTeamId = getTeamId(seatid)
	if deskInfo.panel.score[myTeamId] >= SUN_DOUBLE and deskInfo.panel.score[otherTeamId] < SUN_DOUBLE then
		deskInfo.round.nexgametype = {balcfg.TYPE.TWO, balcfg.TYPE.PASS} --如果我方超过了100分，对方方低于100分
		deskInfo.round.road = 101
		deskInfo.round.passtimes = 0 --需要两边的人都pass才能开始
		local parterSeatId = getParterSeatid(nextUser)
		local parter = queryUserInfo(parterSeatId, 'seatid')
		deskInfo.round.nextuids = {nextUser.uid, parter.uid}

		debug_log("我选sun 符合double uid：", uid, " 广播上下家选double uid:", nextUser.uid, parter.uid)

		deskInfo.round.preUid = uid
		deskInfo.round.preItem = stype
		deskInfo.round.sundouble = {['uid']=uid, ['item']=stype}
		debug_log("我选sun 符合double现在操作人：", uid, " 我选择的是:", stype,  " 下一步2人同时选double:", table.concat(deskInfo.round.nextuids, ','))
		local retobj    = {}
		retobj.code     = PDEFINE.RET.SUCCESS
		retobj.c        = PDEFINE.NOTIFY.BALOOT_SELECT_RESULT
		retobj.uid      = uid
		retobj.gametype = stype
		retobj.round    = deskInfo.round.selecttimes
		retobj.otheruids = deskInfo.round.nextuids --下一步操作的人的uid（多个)
		retobj.timeout = math.floor(timeout/100)
		retobj.nextgametype = deskInfo.round.nexgametype
		if deskInfo.round.showsuit ~= nil then
			retobj.showsuit = deskInfo.round.showsuit
		end
		for _, muser in pairs(deskInfo.users) do
			if table.contain(deskInfo.round.nextuids, muser.uid) then
				deskInfo.round.putNextSeat = muser.seatid
				retobj.nextuid  = muser.uid
				retobj.nextseat = muser.seatid
				local random_time = timeout
				if not muser.cluster_info then
					random_time = math.random(200, timeout)
				end
				CMD.userSetAutoState("autoChooseGameType", random_time, muser.uid)
				if muser.cluster_info and muser.isexit==0  then
					pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", cjson.encode(retobj))
				end
			else
				retobj.nextuid = 0
				retobj.nextseat = 0
				if muser.cluster_info and muser.isexit == 0 then
					pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", cjson.encode(retobj))
				end
			end
		end
		return true
	end
	return false
end

--! 选择玩法
--[[
	['HOKOM'] = 1,
    ['SUN'] = 2,
    ['ASHKAL'] = 3,
    ['PASS'] = 4,
	['TWO'] = 5, --2倍
	['THREE'] = 6, --3倍
	['FOUR'] =7, --4倍
	['GAHWA'] = 8, --一把定输赢
	['LOCK'] = 9, --锁住
	['OPEN'] = 10, --打开
	['SECOND'] = 11, --SECOND HOKOM 
	['CONFIRM'] = 12, --confirm hokom
	['NEITHER'] = 13, --neither
]]
function CMD.chooseGameType(source, msg)
    local recvobj = msg
	local cmd 	  = math.floor(recvobj.c)
    local uid     = math.floor(recvobj.uid)
    local stype   = math.floor(recvobj.gametype)
	
	local resp = {c = cmd, code= PDEFINE.RET.SUCCESS, spcode=0}
    local user = queryUserInfo(uid) --当前操作用户
	debug_log("user choose game type. uid:", uid, ' game_type:', stype, " deskInfo.state:", deskInfo.state)
    debug_log("deskInfo.round.road:", deskInfo.round.road, ' nextuids:', table.concat(deskInfo.round.nextuids, ','))
	if deskInfo.state ~= PDEFINE.DESK_STATE.BIDDING then
		resp['spcode'] = 2 --不是bidding流程了
		return PDEFINE.RET.SUCCESS, resp
	end

	if deskInfo.round.road == 305 or deskInfo.round.road == 308 then
		debug_log("user222.uid:", user.uid, ' not vs stype:', stype, deskInfo.round.road)
		resp['spcode'] = 3 --协议错误
		return PDEFINE.RET.SUCCESS, resp
	end
	if table.contain({balcfg.TYPE.OPEN, balcfg.TYPE.LOCK}, stype) then
		debug_log("user.uid:", user.uid, ' not vs stype:', stype)
		resp['spcode'] = 3 --协议错误
		return PDEFINE.RET.SUCCESS, resp
	end

	if not table.contain(deskInfo.round.nextuids, user.uid) then
		resp['spcode'] = 1 --不是他开始
		debug_log("user.uid:", user.uid, ' not vs next:', table.concat(deskInfo.round.nextuids, ','))
		return PDEFINE.RET.SUCCESS, resp
	end
	if not table.contain(deskInfo.round.nexgametype, stype) then
		resp['spcode'] = 2 --操作类型错误
		debug_log("user.uid:", user.uid, ' not vs next:', table.concat(deskInfo.round.nexgametype, ','), ' stype:',stype)
		return PDEFINE.RET.SUCCESS, resp
	end
	local roads = {300, 0, 304,311, 101}
	if table.contain(roads, deskInfo.round.road) then
		debug_log("clear user 定时器 uid:", uid)
		clearAutoFunc(uid)
		if deskInfo.round.road == 101 and stype == balcfg.TYPE.TWO then
			for _, actuid in pairs(deskInfo.round.nextuids) do
				clearAutoFunc(actuid) --可能有多个人同时被通知，定时器都要清理掉
			end
		end
	else
		debug_log("clear all next users 定时器: uids:", table.concat(deskInfo.round.nextuids, ','))
		for _, actuid in pairs(deskInfo.round.nextuids) do
			clearAutoFunc(actuid) --可能有多个人同时被通知，定时器都要清理掉
		end
	end

	-- if (deskInfo.round.road == 305 and stype == balcfg.TYPE.TWO) or (deskInfo.round.road == 308 and stype == balcfg.TYPE.FOUR)  then
	-- 	debug_log("clear user 定时器 uid:", uid)
	-- 	for i=#deskInfo.round.nextuids, 1, -1 do 
	-- 		if deskInfo.round.nextuids[i] ~= uid then
	-- 			table.remove(deskInfo.round.nextuids, i)
	-- 		end
	-- 	end
	-- else
		for i=#deskInfo.round.nextuids, 1, -1 do 
			if deskInfo.round.nextuids[i] == uid then
				debug_log("remove self from nextuids:", uid)
				table.remove(deskInfo.round.nextuids, i)
				break
			end
		end
	-- end

	table.insert(deskInfo.round.choose, stype)

	--选了sun
	if stype == balcfg.TYPE.SUN then
		local nextUser = queryUserInfo(user.nextseatid, 'seatid')
		deskInfo.round.road = 100

		if doubleInSun(uid, user.seatid, stype, nextUser) then
			return PDEFINE.RET.SUCCESS, resp
		end
		broacastResult(uid, stype)
		debug_log("直接选sun 或 ashkal 开始游戏 uid:",uid, ' stype:', stype)
		endChooseGameTypeRunGame(uid, stype)
		return PDEFINE.RET.SUCCESS
	end
	
	--选了ashkal
	if stype == balcfg.TYPE.ASHKAL then
		debug_log("我选ashkal  uid:",uid, ' stype:', stype)
		deskInfo.round.road = 200
		deskInfo.round.nexgametype = {balcfg.TYPE.SUN, balcfg.TYPE.PASS}
		local parterSeatId = getParterSeatid(user)
		local parter = queryUserInfo(parterSeatId, 'seatid')
		local preUser = queryUserInfo(parter.nextseatid, 'seatid') --我的上家
		deskInfo.round.actuid = user.uid
		deskInfo.round.actgametype = stype
		deskInfo.round.nextuids = {preUser.uid}
		debug_log("我选ashkal  uid:",uid, ' 上家开始sun/pass uid:', preUser.uid)
		broacastResult(uid, stype, {preUser.uid, preUser.seatid})
		return PDEFINE.RET.SUCCESS, resp
	end

	if stype == balcfg.TYPE.TWO then
		if deskInfo.round.road == 101 then --sun翻倍规则中选2倍 TODO:2倍计算结果
			deskInfo.round.multiple = 2
			debug_log("sun double规则 road:", deskInfo.round.road,  " 我选2倍 uid:",uid, " seatid:", user.seatid, ' stype:', stype)
			broacastResult(uid, stype)
			-- broacastResult(deskInfo.round.sundouble['uid'], deskInfo.round.sundouble['item'])
			debug_log("sun double规则 road:", deskInfo.round.road," 选double开局 uid:",deskInfo.round.preUid, ' stype:', deskInfo.round.preItem)
			endChooseGameTypeRunGame(uid, balcfg.TYPE.SUN)
			return PDEFINE.RET.SUCCESS
		end

		if deskInfo.round.road == 311 or deskInfo.round.road == 304 then --second hokom 后选了double
			debug_log("second hokom 后选了double uid：", uid, " 我选择的是:", stype,  "")
			deskInfo.round.road = 305 --TODO:断线重连处理
			deskInfo.round.multiple = 2
			deskInfo.round.nexgametype = {balcfg.TYPE.OPEN, balcfg.TYPE.LOCK}
			deskInfo.round.nextuids = {uid}
			broacastResult(uid, stype, {uid, user.seatid})
			return PDEFINE.RET.SUCCESS, resp
		end
	end

	if stype == balcfg.TYPE.PASS or stype == balcfg.TYPE.NEITHER then
		if deskInfo.round.road == 101 then --sun翻倍规则中选pass
			debug_log("sun double规则 road:", deskInfo.round.road,  " 我选pass uid:",uid, " seatid:", user.seatid, ' stype:', stype)
			broacastResult(uid, stype)
			deskInfo.round.passtimes = deskInfo.round.passtimes + 1
			if deskInfo.round.passtimes == 2 then
				local preUid = deskInfo.round.sundouble['uid']
				local preItem = deskInfo.round.sundouble['item']
				broacastResult(preUid, preItem)
				debug_log("sun double规则 road:", deskInfo.round.road," 选pass开局 uid:", preUid, ' stype:', preItem)
				endChooseGameTypeRunGame(preUid, balcfg.TYPE.SUN)
			end
			return PDEFINE.RET.SUCCESS
		end

		if deskInfo.round.road == 200 then --叫ashkal的人的上家选了pass
			debug_log("ashkal的上家pass road:", deskInfo.round.road,  " 我选pass uid:",uid, " seatid:", user.seatid, ' stype:', stype)
			
			local ashkalUser = queryUserInfo(deskInfo.round.actuid)
			local nextUser = queryUserInfo(ashkalUser.nextseatid, 'seatid')
			if doubleInSun(ashkalUser.uid, ashkalUser.seatid, balcfg.TYPE.ASHKAL, nextUser) then --叫ashkal的人的角度去看是否触发sun翻倍
				return PDEFINE.RET.SUCCESS, resp
			end

			broacastResult(uid, stype) --pass通知
			broacastResult(deskInfo.round.actuid, deskInfo.round.actgametype) -- 叫ashkal的人
			debug_log("ashkal的上家pass 开始游戏 uid:",deskInfo.round.actuid, ' stype:', deskInfo.round.actgametype)
			endChooseGameTypeRunGame(deskInfo.round.actuid, deskInfo.round.actgametype)
			return PDEFINE.RET.SUCCESS
		end

		if deskInfo.round.road == 300 then --选了hokom后的pass
			if #deskInfo.round.choose == 4 then --我选了hokom，后续3个pass
				deskInfo.round.road = 301
				deskInfo.round.nexgametype = {balcfg.TYPE.CONFIRM, balcfg.TYPE.SUN}
				if deskInfo.round.tmpgametype == balcfg.TYPE.PASS then
					deskInfo.round.nexgametype = {balcfg.TYPE.CONFIRM, balcfg.TYPE.SUN}
					deskInfo.round.tmpgametype = balcfg.TYPE.CONFIRM
				end
				deskInfo.round.showsuit = 1
				deskInfo.round.nextuids = {deskInfo.round.hokomer['uid']}
				debug_log("我hokom后，3个pass 凑齐了 uid:", deskInfo.round.hokomer['uid'])
				broacastResult(uid, stype, {deskInfo.round.hokomer['uid'], deskInfo.round.hokomer['seatid']})
				return PDEFINE.RET.SUCCESS, resp
			else
				debug_log("他选了hokom uid:",deskInfo.round.hokomer['uid'], ' 我选pass:', stype, ' uid:', uid)
				broacastResult(uid, stype) --我选hokom后，第1轮 有人选了pass
				return PDEFINE.RET.SUCCESS
			end
		end

		if deskInfo.round.road == 311 or deskInfo.round.road == 304 then --我定完hokom，选完花色，上下家有人pass, 开局
			debug_log("确定hokom后 pass 我叫pass uid:", uid, ' hokom uid:',deskInfo.round.hokomer['uid'], ' road:', deskInfo.round.road, ' nextuids:', deskInfo.round.nextuids)
			broacastResult(uid, stype) -- 叫pass的人
			if #deskInfo.round.nextuids == 0 then --两人都选择了pass
				debug_log("确定hokom后 pass 开始游戏 uid:", uid, ' hokom uid:',deskInfo.round.hokomer['uid'])
				endChooseGameTypeRunGame(deskInfo.round.hokomer['uid'], balcfg.TYPE.HOKOM)
			end
			return PDEFINE.RET.SUCCESS
		end

		if deskInfo.round.road == 307 then --我hokom，3倍后，对方4倍/pass, 选择了pass
			broacastResult(uid, stype)
			endChooseGameTypeRunGame(deskInfo.round.hokomer['uid'], balcfg.TYPE.HOKOM)
			return PDEFINE.RET.SUCCESS
		end

		if deskInfo.round.road == 306 or deskInfo.round.road == 309 then --我hokom,对方4倍后, 我pass
			if deskInfo.round.road == 306 then --我叫hokom, 对方double, 我pass
				deskInfo.round.multiple = 2
				debug_log("我叫hokom, 对方double, 我pass uid:", uid, ' 当前hokomer:',deskInfo.round.hokomer['uid'])
			else
				deskInfo.round.multiple = 4
				debug_log("我叫hokom, 对方4倍后, 我pass uid:", uid, ' 当前hokomer:',deskInfo.round.hokomer['uid'])
			end
			deskInfo.round.hokomer['uid'] = deskInfo.round.preUid
			local preUser = queryUserInfo(deskInfo.round.preUid, 'uid')
			deskInfo.round.hokomer['seatid'] = preUser.seatid
			broacastResult(uid, stype) -- 叫pass的人

			debug_log("我叫hokom, 对方2/4倍后, 我pass uid:", uid, ' hokom uid改为:',deskInfo.round.hokomer['uid'])
			endChooseGameTypeRunGame(deskInfo.round.hokomer['uid'], balcfg.TYPE.HOKOM)
			return PDEFINE.RET.SUCCESS
		end

		--第1轮4个pass
		if #deskInfo.round.choose == 4 then
			if table.count(deskInfo.round.choose, balcfg.TYPE.PASS) == 4 then
				deskInfo.round.road = 400 
				local nextItems = {balcfg.TYPE.SECOND, balcfg.TYPE.SUN, balcfg.TYPE.ASHKAL, balcfg.TYPE.NEITHER} --第1轮全pass后， 第2轮开始 neither
				local nextUser = queryUserInfo(user.nextseatid, 'seatid')
				nextItems = filterAshKal(nextUser, nextItems)
				debug_log("第一轮全pass, 重新开始叫牌, nextUser:", nextUser.uid)
				deskInfo.round.nexgametype = nextItems
				deskInfo.round.choose      = {}
				deskInfo.round.nextuids = {nextUser.uid}
				broacastResult(uid, stype, {nextUser.uid, nextUser.seatid})
				deskInfo.round.tmpgametype = balcfg.TYPE.PASS
				return PDEFINE.RET.SUCCESS, resp
			end

			if deskInfo.round.tmpgametype == balcfg.TYPE.PASS and table.count(deskInfo.round.choose, balcfg.TYPE.NEITHER) == 4 then --特殊规则：第1轮全pass后，第2轮接着全pass时, 重新轮庄，开始下一把
				local seatid = findNextSeat(deskInfo.round.dealer['seatid'])
				local nextDealer = queryUserInfo(seatid, 'seatid')
				deskInfo.round.dealer = {
					['uid'] = nextDealer.uid,
					['seatid'] = seatid
				} --移庄
				deskInfo.round.putNextSeat = seatid
				deskInfo.round.choose = {}
				deskInfo.round.road = 0
				deskInfo.round.tmpgametype = 0
				deskInfo.round.multiple = 1
				local retobj    = {}
				retobj.code     = PDEFINE.RET.SUCCESS
				retobj.c        = PDEFINE.NOTIFY.BALOOT_ROUND_START
				broadcastDesk(cjson.encode(retobj))
				skynet.timeout(200, beginChooseGameType)
				return PDEFINE.RET.SUCCESS, resp
			end
		end

		if #deskInfo.round.choose < 4 then
			local nextItems = ITEM_ALL_FIRST
			if deskInfo.round.tmpgametype == balcfg.TYPE.PASS then
				nextItems = {balcfg.TYPE.SECOND, balcfg.TYPE.SUN, balcfg.TYPE.ASHKAL, balcfg.TYPE.NEITHER}
			end
			local nextUser = queryUserInfo(user.nextseatid, 'seatid')
			-- print("before11 filterAshKal nextUser:", nextUser)
			nextItems = filterAshKal(nextUser, nextItems)
			deskInfo.round.nexgametype = nextItems
			deskInfo.round.nextuids = {nextUser.uid}
			debug_log(" 我pass, uid:", uid, " pass deskInfo.round:", deskInfo.round.nextuids)
			broacastResult(uid, stype, {nextUser.uid, nextUser.seatid})
			return PDEFINE.RET.SUCCESS, resp
		end
	end

	--第1轮全pass，第2轮选sencond 相当于 第1轮里选hokom
	if stype == balcfg.TYPE.HOKOM or (stype == balcfg.TYPE.SECOND and deskInfo.round.road == 400) then --有人选了hokom
		deskInfo.round.choose = {}
		table.insert(deskInfo.round.choose, stype)
		deskInfo.round.road = 300
		deskInfo.round.hokomer = {uid = uid, seatid = user.seatid} --第1轮选hokom的人
		deskInfo.round.preuid = uid
		deskInfo.round.preItem = stype
		deskInfo.panel.gametype    = balcfg.TYPE.HOKOM
		deskInfo.panel.suit        = getCardColor(deskInfo.show)
		deskInfo.round.nextuids = {}
		local nextItems = {balcfg.TYPE.SUN, balcfg.TYPE.ASHKAL, balcfg.TYPE.PASS}
		for _, muser in pairs(deskInfo.users) do
			if tonumber(muser.uid) ~= uid then
				table.insert(deskInfo.round.nextuids, muser.uid)
			end
		end
		debug_log("我先选择hokom 现在操作人：", uid, " 我选择的是:", stype,  "  广播其他3家:", table.concat(deskInfo.round.nextuids, ','))
		debug_log("我先选择hokom广播 uid：", uid, " 庄家是:", deskInfo.round.dealer['uid'])
		local retobj    = {}
		retobj.code     = PDEFINE.RET.SUCCESS
		retobj.c        = PDEFINE.NOTIFY.BALOOT_SELECT_RESULT
		retobj.uid      = uid
		retobj.gametype = stype
		retobj.otheruids = deskInfo.round.nextuids
		retobj.timeout = math.floor(timeout/100)
		if deskInfo.round.showsuit ~= nil then
			retobj.showsuit = deskInfo.round.showsuit
		end
		
		deskInfo.round.nexgametype = nextItems
		for _, muser in pairs(deskInfo.users) do
			local items = filterAshKal(muser, nextItems)
			retobj.nextgametype = items
			if muser.uid ~= uid then
				retobj.nextuid  = muser.uid
				retobj.nextseat = muser.seatid
			end
			debug_log("我先选择hokom广播 现在操作人：", uid, " 下一步谁操作:", retobj.nextuid)
			if  muser.cluster_info and muser.isexit == 0 then
				pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", cjson.encode(retobj))
			end
			if muser.uid ~= uid then
				local random_time = timeout
				if not muser.cluster_info then
					random_time = math.random(200, timeout)
				end
				CMD.userSetAutoState("autoChooseGameType", random_time, muser.uid)
			end
		end
		return PDEFINE.RET.SUCCESS
	end

	if stype == balcfg.TYPE.SECOND or stype == balcfg.TYPE.CONFIRM then --确认hokom
		if deskInfo.round.road == 301 then
			deskInfo.round.road = 304
			deskInfo.round.preuid = uid
			deskInfo.round.preItem = stype

			if deskInfo.round.tmpgametype == balcfg.TYPE.CONFIRM then
				debug_log("选择second hokom uid：", uid, " 我选择的是:", stype,  "")
				deskInfo.round.selecttimes = 2
				broacastResult(uid, stype)
				--自己选花色
				local items = {16, 32, 48, 64}
				local color = getCardColor(deskInfo.show)
				for i=#items, 1, -1 do
					if items[i] == color then
						table.remove(items, i) --亮牌的花色不能选
						break
					end
				end
				deskInfo.round.gametype = balcfg.TYPE.HOKOM
				deskInfo.round.preUid = uid --断线重连使用
				deskInfo.round.preItem = stype
				deskInfo.round.nextuids = {uid}
				deskInfo.round.nexgametype = items

				if user.cluster_info then
					local retobj    = {}
					retobj.code     = PDEFINE.RET.SUCCESS
					retobj.c        = PDEFINE.NOTIFY.BALOOT_CHOOSE_SUIT
					retobj.uid      = uid
					retobj.gametype = stype
					retobj.round    = deskInfo.round.selecttimes
					retobj.nextuid  = uid
					retobj.timeout  = math.floor(timeout/100)
					retobj.nextseat = user.seatid
					retobj.nextgametype = items
					for _, muser in pairs(deskInfo.users) do
						if muser.cluster_info and muser.isexit == 0 then
							pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", cjson.encode(retobj))
						end
					end
				end
				local random_time = timeout
				if not user.cluster_info then
					random_time = math.random(200, timeout)
				end
				CMD.userSetAutoState("autoChooseSuit", random_time, user.uid)
			else
				local nextUser = queryUserInfo(user.nextseatid, 'seatid') --我的下家
				local parterSeatId = getParterSeatid(nextUser)
				local parter = queryUserInfo(parterSeatId, 'seatid') --下家的队友(我的上家)
				deskInfo.round.nexgametype = {balcfg.TYPE.TWO, balcfg.TYPE.PASS}
				deskInfo.round.nextuids = {nextUser.uid, parter.uid}
				debug_log("选择second hokom 我选花色 uid：", uid, " 广播上下家选double uid:", nextUser.uid, parter.uid)

				deskInfo.round.preUid = uid
				deskInfo.round.preItem = stype

				debug_log("开始广播 现在操作人：", uid, " 我选择的是:", stype,  " 下一步2人同时选double:", table.concat(deskInfo.round.nextuids, ','))
				local retobj    = {}
				retobj.code     = PDEFINE.RET.SUCCESS
				retobj.c        = PDEFINE.NOTIFY.BALOOT_SELECT_RESULT
				retobj.uid      = uid
				retobj.gametype = stype
				retobj.round    = deskInfo.round.selecttimes
				retobj.otheruids = deskInfo.round.nextuids --下一步操作的人的uid（多个)
				retobj.timeout = math.floor(timeout/100)
				retobj.nextgametype = deskInfo.round.nexgametype
				if deskInfo.round.showsuit ~= nil then
					retobj.showsuit = deskInfo.round.showsuit
				end
				for _, muser in pairs(deskInfo.users) do
					if table.contain(deskInfo.round.nextuids, muser.uid) then
						deskInfo.round.putNextSeat = muser.seatid
						retobj.nextuid  = muser.uid
						retobj.nextseat = muser.seatid
						local random_time = timeout
						if not muser.cluster_info then
							random_time = math.random(200, timeout)
						end
						CMD.userSetAutoState("autoChooseGameType", random_time, muser.uid)
						if muser.cluster_info and muser.isexit==0 then
							pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", cjson.encode(retobj))
						end
					else
						retobj.nextuid = 0
						retobj.nextseat = 0
						if muser.cluster_info and muser.isexit==0 then
							pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "sendToClient", cjson.encode(retobj))
						end
					end
				end
			end
			
			return PDEFINE.RET.SUCCESS, resp
		end
	end

	if stype == balcfg.TYPE.THREE then
		deskInfo.round.road = 307 --TODO:断线重连处理
		deskInfo.round.multiple = 3
		deskInfo.round.nexgametype = {balcfg.TYPE.FOUR, balcfg.TYPE.PASS}
		deskInfo.round.nextuids = {deskInfo.round.preUid}
		local nextUser = queryUserInfo(deskInfo.round.preUid, 'uid')
		broacastResult(uid, stype, {nextUser.uid, nextUser.seatid})
		return PDEFINE.RET.SUCCESS, resp
	end

	if stype == balcfg.TYPE.FOUR then
		deskInfo.round.road = 308 --TODO:断线重连处理
		deskInfo.round.multiple = 4
		deskInfo.round.nexgametype = {balcfg.TYPE.OPEN, balcfg.TYPE.LOCK}
		deskInfo.round.nextuids = {uid}
		broacastResult(uid, stype, {uid, user.seatid})
		return PDEFINE.RET.SUCCESS, resp
	end

    return PDEFINE.RET.SUCCESS, resp
end

--! 用户离线获取牌桌信息
function CMD.getDeskInfo(source, msg)
	debug_log("getDeskInfo msg:", msg)
	local uid = msg.uid
    local tmp = table.copy(deskInfo)
	tmp.round = nil
	debug_log("getDeskInfo", deskInfo)
	tmp.showCard = deskInfo.round.showCard or {}
	tmp.discardCards = deskInfo.round.discardCards or {}
	tmp.lastSeatid = deskInfo.round.lastSeatid
	tmp.double = nil
	tmp.suit = nil
	tmp.uuid = nil
	tmp.multiple = nil
	if deskInfo.round.dealer then
        tmp.dealer = deskInfo.round.dealer['uid'] --庄家
    end

	local userInfo = queryUserInfo(uid, 'uid')
	local roundscore = {0, 0}
	for _, muser in pairs(tmp.users) do
		muser.handCardCount = #muser.round.handInCards
		if muser.uid ~= uid then
			muser.handInCards = {}
		else
			muser.handInCards = muser.round.handInCards
			-- 判断是否是排位房
			tmp.leagueInfo = player_tool.getLeagueInfo(deskInfo.conf.roomtype, muser.uid)
		end
		if muser.seatid %2 == 0 then
			roundscore[2] = roundscore[2] + muser.round.roundscore
		else
			roundscore[1] = roundscore[1] + muser.round.roundscore
		end
		muser.round = nil
		muser.cluster_info = nil
		
		if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
			local prize
			if userInfo then
				prize = PDEFINE_GAME.SESS.match[deskInfo.gameid][userInfo.ssid].reward
			else
				prize = PDEFINE_GAME.SESS.match[deskInfo.gameid][deskInfo.ssid].reward
			end
			muser.wincoinshow = 0
			if muser.uid ~= uid then
				muser.wincoinshow = muser.settlewin * prize
			else
				muser.wincoinshow = muser.settlewin * prize
			end
		end
	end

	if userInfo and table.size(deskInfo.round.nextuids) > 0 then
		if deskInfo.state == PDEFINE.DESK_STATE.BIDDING and table.contain(deskInfo.round.nextuids, userInfo.uid) then
			local leftTime =  deskInfo.round.autoExpireTime - os.time()
			LOG_DEBUG('getDeskInfo leftTime:', leftTime, ' uid:', userInfo.uid)
			if deskInfo.round.road == 304 then
				local notifyMsg = function()
					local retobj    = {}
					retobj.code     = PDEFINE.RET.SUCCESS
					retobj.c        = PDEFINE.NOTIFY.BALOOT_CHOOSE_SUIT --选花色
					retobj.uid      = uid
					retobj.gametype = deskInfo.round.preItem
					retobj.round    = deskInfo.round.selecttimes
					retobj.nextuid  = uid
					retobj.timeout  = leftTime
					retobj.nextseat = userInfo.seatid
					retobj.nextgametype = deskInfo.round.nexgametype
					local ok = cluster.call(userInfo.cluster_info.server, userInfo.cluster_info.address, "sendToClient", cjson.encode(retobj))
					debug_log("ok:",ok )
				end
				debug_log(" 1s后执行 通知选择 notifyMsg")
				skynet.timeout(100, notifyMsg)
			else
				if leftTime > 0 and table.contain(deskInfo.round.nextuids, userInfo.uid) then
					local notifyMsg = function()
						local retobj = {c=PDEFINE.NOTIFY.BALOOT_SELECT_RESULT, code=PDEFINE.RET.SUCCESS}
						retobj.uid = deskInfo.round.preUid
						retobj.gametype = deskInfo.round.preItem
						retobj.round    = deskInfo.round.selecttimes
						retobj.nextseat = userInfo.seatid
						retobj.nextuid  = userInfo.uid
						retobj.nextgametype = deskInfo.round.nexgametype
						retobj.otheruids = deskInfo.round.nextuids
						retobj.timeout = leftTime
						debug_log("notify msg111:", retobj)
						local ok = cluster.call(userInfo.cluster_info.server, userInfo.cluster_info.address, "sendToClient", cjson.encode(retobj))
						debug_log("ok:",ok )
					end
					debug_log(" 1s后执行 通知选择 notifyMsg")
					skynet.timeout(100, notifyMsg)
				end
			end
		end
	end

	if deskInfo.state == PDEFINE.DESK_STATE.PLAY then
		tmp.roundinfo = {
			uid = deskInfo.round.preUid,
			nextSeat = deskInfo.round.putNextSeat,
			timeout = math.floor(timeout/100)
		}
	end

	-- 解散倒计时时长
	if dismiss then
        tmp.dismiss = {
            uid = dismiss.uid,  -- 发起人
            users = dismiss.users,  -- 其他人信息以及是否同意
            delayTime = dismiss.expireTime-os.time(),  -- 解散时间
        }
    end

    -- if autoStartInfo and autoStartInfo.startTime and autoStartInfo.startTime > os.time() then
    --     tmp.autoStart = {
    --         delayTime = autoStartInfo.startTime - os.time()
    --     }
    -- end

	-- 自动托管倒计时
	if deskInfo.round.autoExpireTime then
		tmp.delayTime = deskInfo.round.autoExpireTime - os.time()
		if tmp.delayTime < 0 then
			tmp.delayTime = 0
		end
	end

    -- 是否是观战
    local view = findViewUser(uid)
    if view then
        tmp.isViewer = 1
    else
        tmp.isViewer = 0
    end

	return tmp
end

--! 用户在线离线
function CMD.offline(source, offline, uid)
	LOG_INFO("CMD.offline", "offline:", offline, "uid:", uid)
	local user = queryUserInfo(uid, 'uid')
	if user then
		local retobj = {}
		retobj.c = PDEFINE.NOTIFY.NOTIFY_ONLINE
		retobj.code = PDEFINE.RET.SUCCESS
		retobj.offline = offline --2:离线 1:在线
		retobj.uid = uid
		retobj.seatid = user.seatid
		broadcastDesk(cjson.encode(retobj),uid)

		if offline == 2 then
			user.offline = 1
			user.auto = 1
			user.mic = 0
			brodcastUserAutoMsg(user, 1) 
		else
			user.offline = 0
		end
		localFunc.updateMicStatus()
	end
end

-- 用户更改状态
function CMD.updateUserMic(source, msg)
    local uid = msg.uid
    local mic = msg.mic  -- 0 关, 1 开
    local user = queryUserInfo(uid, 'uid')
    local retobj = {c=msg.c, code=PDEFINE.RET.SUCCESS, spcode=0, uid=uid, mic=mic}
    if not user then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return resp(retobj)
    end
    if mic ~= 0 and mic ~= 1 then
        retobj.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return resp(retobj)
    end
    user.mic = mic
    localFunc.updateMicStatus()
    return resp(retobj)
end

-- 更新是否加入语聊室和麦克风状态
-- 逻辑: 
-- 如果有两个或者以上真人，且有人开麦，则需要将大家加入语聊
-- 如果有两个或者以上真人，且没人开麦，则不需要加入语聊室
-- 如果没有两个真人，则机器人不会开麦，真人也不需要加入语聊室
local function updateMicStatus()
    -- 判断真人数量
    local userCnt = 0
    local micCnt = 0
    local openChat = false
    for _, u in ipairs(deskInfo.users) do
        if u.cluster_info then
            userCnt = userCnt + 1
            if u.mic ~= 0 then
                micCnt = micCnt + 1
            end
        end
    end
    local notifyObj = {
        c=PDEFINE.NOTIFY.PLAYER_MIC_STATUS,
        code=PDEFINE.RET.SUCCESS,
        spcode=0,
        users={},
    }
    if userCnt > 1 and micCnt > 0 then
        openChat = true
    end
    for _, u in ipairs(deskInfo.users) do
        if u.cluster_info and openChat then
            u.joinChat = 1
        else
            u.joinChat = 0
        end
        local item = {uid=u.uid, mic=u.mic, joinChat=u.joinChat}
        table.insert(notifyObj.users, item)
    end
    broadcastDesk(cjson.encode(notifyObj))
end

-- 通知用户比赛结束
function CMD.updateRaceStatus(source, msg)
    local uid = msg.uid
    local race_id = msg.race_id
    local status = msg.status
    local user = queryUserInfo(uid, 'uid')
    if not user or user.race_id ~= race_id then
        return PDEFINE.RET.SUCCESS
    end
    local notifyObj = {c=PDEFINE.NOTIFY.NOTIFY_RACE_END, code=PDEFINE.RET.SUCCESS, uid=uid,spcode=0}
    pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(notifyObj))
    user.race_id = 0
    user.race_type = nil
    return PDEFINE.RET.SUCCESS
end

local function returnDeskInfo(user)
	local tmpDeskInfo = table.copy(deskInfo)
	for i=1, #tmpDeskInfo.users do
		tmpDeskInfo.users[i].cluster_info = nil
		tmpDeskInfo.users[i].round = nil
		tmpDeskInfo.users[i].nextseatid = nil
	end
	
	tmpDeskInfo.round = nil
	tmpDeskInfo.state = nil
	tmpDeskInfo.double = nil
	tmpDeskInfo.uuid = nil
	tmpDeskInfo.gameid = deskInfo.gameid
	tmpDeskInfo.leagueInfo = user and player_tool.getLeagueInfo(deskInfo.conf.roomtype, user.uid) or nil
	return tmpDeskInfo
end

local function createAgoraToken(user, deskid)
	local ok, code, token = pcall(skynet.call, ".agora", "lua", "getToken", user.uid, deskid)
	user.token = ""
	if ok and code == PDEFINE.RET.SUCCESS then
		user.token = token
	end
end

local function buildUserObj(playerInfo, ssid)
	if nil == ssid then
		ssid = deskInfo.ssid
	end
	local userObj = {
		uid=playerInfo.uid, 
		nick=playerInfo.playername,
		icon=playerInfo.usericon,
		coin=playerInfo.coin,
		level = playerInfo.level or 1,
		avatarframe = playerInfo.avatarframe,
		levelexp = playerInfo.levelexp or 0 ,
		leaguelevel = playerInfo.leaguelevel or 1,
		diamond = playerInfo.diamond or 0,
		leagueexp = 0,
		chatskin = playerInfo.chatskin,
		svip = playerInfo.svip or 0,
		svipexp = playerInfo.svipexp or 0,
		ssid = ssid,
		rp = playerInfo.rp or 0,
	}

	userObj.leagueexp, userObj.leaguelevel = player_tool.getPlayerLeagueInfo(playerInfo.uid, deskInfo.gameid)

	LOG_DEBUG("buildUserObj return userObj:", userObj)
	return userObj
end

local function ai_set_timeout(ti, f)
    local function t()
        if f then
            f()
        end
    end
    skynet.timeout(ti, t)
    return function() f=nil end
end

local function sendStartTime(uid, delayTime)
	local user = queryUserInfo(uid, 'uid')
	if user and user.cluster_info and user.isexit == 0 then
		if not delayTime then
			delayTime = deskInfo.conf.create_time - os.time()
		end
		local notify_retobj = {
			c = PDEFINE.NOTIFY.GAME_AUTO_START_BEGIN,
			code = PDEFINE.RET.SUCCESS,
			delayTime = delayTime,
		}
		pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "sendToClient", cjson.encode(notify_retobj))
	end
end

-- 观战期间坐下
function CMD.seatDown(source, msg)
    local recvobj  = msg
    local uid = math.floor(recvobj.uid)
    local seatid = math.floor(recvobj.seatid)
    local retobj  = {}
    retobj.c      = recvobj.c
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.seatid = seatid
    retobj.spcode = 0
    local viewer = findViewUser(uid)
    if not viewer then
        retobj.spcode = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return resp(retobj)
    end
	-- 判断金币是否足够
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE or deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        local betCoin = deskInfo.bet
        if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
            betCoin = PDEFINE_GAME.SESS.match[deskInfo.gameid][recvobj.ssid].entry
        end
        LOG_DEBUG("cmd.seatDown betCoin:", betCoin, ' player.coin:', viewer.coin)
        if viewer.coin < deskInfo.bet then --判断门槛
            retobj.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
            return resp(retobj)
        end
    end
	-- 不能重复坐下
    if viewer.seatid > 0 then
        retobj.spcode = PDEFINE.RET.ERROR.ALREADY_SEAT_DOWN
        return resp(retobj)
    end
    if not table.contain(SEATID_LIST, seatid) then
        retobj.spcode = PDEFINE.RET.ERROR.ERROR_SEAT_EXISTS_USER
        return resp(retobj)
    end
    -- 锁定当前位置
    for k, sid in pairs(SEATID_LIST) do
        if sid == seatid then
            table.remove(SEATID_LIST, k)
            break
        end
    end
    -- 如果是匹配阶段，则直接坐下
    -- 否则锁定座位号到观战者身上
    viewer.seatid = seatid
	viewer.nextseatid = seatid + 1
	if viewer.nextseatid > 4 then
		viewer.nextseatid = 1
	end

    if deskInfo.state == PDEFINE.DESK_STATE.MATCH or deskInfo.state == PDEFINE.DESK_STATE.READY then
        removeViewUser(uid)
        pushUserToUserList(viewer)
		skynet.timeout(50, function()
            CMD.ready(nil, {uid=uid})
			if isJoinAI() then
				autoStartGame()
			end
        end)
    end
	-- 这里放到后面，不然会被删除
	pcall(cluster.send, "master", ".balprivateroommgr", "viewerSeat", deskInfo.deskid, deskInfo.gameid, {
        uid = uid,
        playername=viewer.playername,
        usericon = viewer.usericon,
        seatid = viewer.seatid
    })
	local notify_object = {}
    notify_object.c = PDEFINE.NOTIFY.PLAYER_SEAT_DOWN
    notify_object.uid = uid
    notify_object.seatid = seatid
    notify_object.code = PDEFINE.RET.SUCCESS
    broadcastDesk(cjson.encode(notify_object))
    return resp(retobj)
end


function CMD.chatIcon(source, msg)
    local uid = math.floor(msg.uid)
    local flag = msg.flag or 1 -- 1:开启 2:关闭
    local user = queryUserInfo(uid, 'uid')
    local notifyMsg  = {code = PDEFINE.RET.SUCCESS, c = PDEFINE.NOTIFY.PLAYER_CHOOSE_CHATICON, uid=msg.uid, flag=flag, seatid=user.seatid}
	broadcastDesk(cjson.encode(notifyMsg))
    return PDEFINE.RET.SUCCESS
end

--! 创建房间
function CMD.create(source, cluster_info, msg, ip, deskid, newplayercount, gameid)
    local recvobj    = msg
    local uid        = math.floor(recvobj.uid)
	local cid = recvobj.cid  -- 俱乐部id
    if cid then
        cid = math.floor(cid)
        deskInfo.cid = cid
    end
	agentState = true
	if gameid then
        GAME_ID    = gameid
        deskInfo.gameid = gameid
    end
	if isMaintain() then
        return PDEFINE.RET.ERROR.ERROR_GAME_FIXING
    end
    debug_log("创建桌子", deskInfo.gameid, "玩家", uid, " 创建新房间:", deskid, msg)

    loadSessInfo(uid, recvobj)
    local playerInfo = nil
    if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
		local ok
		if not cluster_info then
			ok, playerInfo = pcall(cluster.call, "master", ".userCenter", "getPlayerInfo", uid)
		else
			ok, playerInfo = pcall(cluster.call, cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid)
		end
		local bet = deskInfo.bet
		if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
			bet = PDEFINE_GAME.SESS.match[deskInfo.gameid][recvobj.ssid].section[1] 
		end
        if playerInfo.coin < bet then
            return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
        end
	end
	
    local now = os.time()
    deskInfo.uuid   = deskid .. now
    deskInfo.deskid = deskid
	deskInfo.owner  = uid
	deskInfo.state = PDEFINE.DESK_STATE.MATCH
	deskInfo.conf.create_time = now
	deskInfo.conf.league_type = 1 --单排
	deskInfo.conf.isLucky = false --创房者的buffer
	if hasLuckyBuffer(uid, deskInfo.gameid) and deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
		deskInfo.conf.isLucky = true
	end
	LOG_DEBUG('user createdesk uid:', uid, ' hasLuckyBuffer:', deskInfo.conf.isLucky)
	local userInfo
	if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
		local seatid = getSeatId()
		if not seatid then
			return PDEFINE.RET.ERROR.SEATID_EXIST
		end
		local userObj = buildUserObj(playerInfo, recvobj.ssid)
		createAgoraToken(userObj, deskid)
		userInfo = initUser(seatid, userObj, cluster_info)
		userInfo.race_id = recvobj.race_id and recvobj.race_id or 0
		userInfo.race_type = recvobj.race_type and recvobj.race_type or 0
		pushUserToUserList(userInfo)
		LOG_DEBUG("PDEFINE_GAME.SESS.match[deskInfo.gameid]:", PDEFINE_GAME.SESS.match[deskInfo.gameid])
		aiAutoFuc = ai_set_timeout(math.random(100,300),aiJoin)

		sendStartTime(uid, 5)
	end

	local sql = string.format("insert into d_desk_game(deskid,gameid,uuid,owner,roomtype,bet,prize,conf,create_time) values(%d,%d,'%s',%d,%d,%d,%d,'%s',%d)", 
								deskInfo.deskid, deskInfo.gameid, deskInfo.uuid, deskInfo.owner, deskInfo.conf.roomtype, deskInfo.bet, deskInfo.panel.prize, cjson.encode(deskInfo.conf), deskInfo.conf.create_time)
	skynet.call(".mysqlpool", "lua", "execute", sql)

    local tmpDeskInfo = returnDeskInfo(userInfo)
	if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE and #deskInfo.users == 0 then
		-- 如果是特殊房间，则加入一个机器人
        if deskInfo.conf.spcial == 1 then
            local ok, aiUserList = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", 1, true)
            if ok then
                aiJoin(aiUserList[1])
				CMD.ready(nil, {uid=aiUserList[1].uid})
            end
        end
        autoRecycleDesk()
    end
    return PDEFINE.RET.SUCCESS, tmpDeskInfo
end

local function syncUserInfo(exist_user, playerInfo)
	exist_user.svip = playerInfo.svip or 1
	exist_user.svipexp = playerInfo.svipexp or 0
	exist_user.rp = playerInfo.rp or 0
	exist_user.level = playerInfo.level or 1
	exist_user.levelexp = playerInfo.levelexp or 0
	exist_user.coin = playerInfo.coin or 0
	exist_user.diamond = playerInfo.diamond or 0
	exist_user.playername = playerInfo.playername
	exist_user.usericon     = playerInfo.usericon
	exist_user.charm = playerInfo.charm or 0
	exist_user.avatarframe = playerInfo.avatarframe
	exist_user.chatskin = playerInfo.chatskin
	exist_user.tableskin = playerInfo.tableskin
	exist_user.pokerskin = playerInfo.pokerskin
	exist_user.frontskin = playerInfo.frontskin
	exist_user.emojiskin = playerInfo.emojiskin
	exist_user.faceskin = playerInfo.faceskin
end

function CMD.setPlayerExit(source, uid)
    local user = queryUserInfo(uid, 'uid')
    if user then
        user.isexit = 1
    else
        user = findViewUser(uid)
        if user then
            viewExit(uid)
        end
    end
    return PDEFINE.RET.SUCCESS
end

--! 加入房间
function CMD.join(source, cluster_info, msg, ip)
    return cs(function()
		local recvobj   = msg
	    local uid       = math.floor(recvobj.uid)
		LOG_DEBUG("cmd.join, uid:", uid, ' msg:', msg)
	    local deskid    = recvobj.deskid
	    if not agentState then
            return PDEFINE.RET.ERROR.DESKID_FAIL -- 此agent已经在回收流程中，直接不让匹配
	    end

        if tonumber(deskid) ~= tonumber(deskInfo.deskid) then
            return PDEFINE.RET.ERROR.DESKID_FAIL
        end

        local ok, playerInfo
		if not cluster_info then
			ok, playerInfo = pcall(cluster.call, "master", ".userCenter", "getPlayerInfo", uid)
		else
			ok, playerInfo = pcall(cluster.call, cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid)
		end
        if not ok or not playerInfo then
            return PDEFINE.RET.ERROR.PLAYER_EXISTS_DESK
        end
        local exist_user = queryUserInfo(uid, 'uid')

		-- 判断是否已经在游戏中
        -- 重新加入房间
		if exist_user then
			exist_user.cluster_info = cluster_info
			syncUserInfo(exist_user, playerInfo)
			exist_user.auto = 0
			exist_user.isexit = 0
			exist_user.race_id = recvobj.race_id and recvobj.race_id or 0
			exist_user.race_type = recvobj.race_type and recvobj.race_type or 0
			-- 重新生成token
			createAgoraToken(exist_user, deskid)
			local retobj  = {}
			retobj.code = PDEFINE.RET.SUCCESS
			retobj.c = math.floor(recvobj.c)
			retobj.gameid = deskInfo.gameid
			retobj.deskinfo  = CMD.getDeskInfo(nil, {uid=uid})
			if retobj.deskinfo then
				retobj.deskinfo.deskFlag = 1
			end
			-- 取消托管状态
			brodcastUserAutoMsg(exist_user, 0)
			-- 广播消息给其他玩家
            broadcastPlayerInfo(exist_user)
            skynet.timeout(20, function()
				-- 检测金币不足
                checkDangerCoin(exist_user)
				-- 广播语聊状态
				localFunc.updateMicStatus()
            end)
			return resp(retobj)
		end

        -- 是否是观战
        if deskInfo.state ~= PDEFINE.DESK_STATE.MATCH and deskInfo.state ~= PDEFINE.DESK_STATE.READY then
            if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
                if #deskInfo.views >= deskInfo.maxView then
                    return PDEFINE.RET.ERROR.ERROR_MORETHAN_SEAT
                end
                local userObj = buildUserObj(playerInfo, recvobj.ssid)
                createAgoraToken(userObj, deskid)
                local userInfo = initUser(-1, userObj, cluster_info)
				local viewer = findViewUser(uid)
				if not viewer then
				    table.insert(deskInfo.views, userInfo)
					pcall(cluster.send, "master", ".balprivateroommgr", "enterView", deskInfo.deskid, {uid}, deskInfo.gameid)
				else
					syncUserInfo(viewer, playerInfo)
				    viewer.cluster_info = userInfo.cluster_info
				end
                local retobj  = {}
				retobj.c = math.floor(recvobj.c)
                retobj.code = PDEFINE.RET.SUCCESS
                retobj.gameid = deskInfo.gameid
                retobj.deskinfo  = CMD.getDeskInfo(nil, {uid=uid})
                retobj.isViewer = 1
                if retobj.deskinfo then
                    retobj.deskinfo.deskFlag = 1
                end
				if not viewer then
                    local otherRetobj = {}
                    otherRetobj.c = PDEFINE.NOTIFY.PLAYER_VIEWER_ENTER_ROOM
                    otherRetobj.code = PDEFINE.RET.SUCCESS
                    otherRetobj.user = userInfo
                    broadcastDesk(cjson.encode(otherRetobj), uid)
				else
					-- 广播消息给其他玩家
                    broadcastPlayerInfo(userInfo)
                end
                return resp(retobj)
            end
            return PDEFINE.RET.ERROR.GAME_NO_ALLOW_JOIN
         end

		-- 进入门槛
		if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH or deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
			local betCoin = deskInfo.bet
			if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
				betCoin = PDEFINE_GAME.SESS.match[deskInfo.gameid][recvobj.ssid].section[1]
			end
			LOG_DEBUG("cmd.join betCoin:", betCoin, ' player.coin:', playerInfo.coin)
			if playerInfo.coin < betCoin then
				return PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
			end
		end

		--判断房间是否满员， 座位判断 防着中途有初房主的用户退出 所以需要遍历位置
		local seatid = 0
		if recvobj.seatid and recvobj.seatid > 0 then
			for k, sid in pairs(SEATID_LIST) do
				if sid == recvobj.seatid then
					seatid = table.remove(SEATID_LIST, k)
					deskInfo.curseat = deskInfo.curseat + 1
					break
				end
			end
			deskInfo.conf.league_type = 2 --双排
		else
			seatid = getSeatId()
		end
		if not seatid then
			return PDEFINE.RET.ERROR.SEATID_EXIST
		end
		local userObj = buildUserObj(playerInfo, recvobj.ssid)
		createAgoraToken(userObj, deskid)
		local userInfo = initUser(seatid, userObj, cluster_info)
		userInfo.race_id = recvobj.race_id and recvobj.race_id or 0
		userInfo.race_type = recvobj.race_type and recvobj.race_type or 0
		pushUserToUserList(userInfo)

		-- 广播语聊状态
		skynet.timeout(20, function()
			localFunc.updateMicStatus()
		end)

		local retobj  = {}
		retobj.code = PDEFINE.RET.SUCCESS
		retobj.c = math.floor(recvobj.c)
	    retobj.gameid = deskInfo.gameid
	    
		if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE or deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
            -- 如果是私人房，则需要准备才能开始
            local resp = {}
            resp.c = PDEFINE.NOTIFY.PLAYER_ENTER_ROOM
            resp.gameid= deskInfo.gameid
            resp.code = PDEFINE.RET.SUCCESS
            resp.deskinfo = deskInfo
			-- 广播给其他人，自己则直接返回，不需要广播
            broadcastDesk(cjson.encode(resp), uid)
			if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH and #deskInfo.users == deskInfo.seat then
				if aiAutoFuc then aiAutoFuc() end
				startGame(3)
			elseif deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
                -- 如果是好友房，则在加入真人之后，需要开启定时器，增加机器人
                if deskInfo.conf.autoStart == 1 then
                    skynet.timeout(100, function ()
                        -- 延迟一秒之后，自动准备，准备倒计时加机器人
                        CMD.ready(nil, {uid=uid})
                    end)
                end
				if isJoinAI() then
                    autoStartGame()
                end
			end
		end

		pcall(cluster.send, "node", ".chat", "changeDeskInfoUsers", deskInfo.deskid, deskInfo.gameid, deskInfo.users, deskInfo.cid)
		local tmpDeskInfo = returnDeskInfo(userInfo)
	    retobj.deskinfo  = tmpDeskInfo
		return PDEFINE.RET.SUCCESS, retobj
	end)
end

-- 剔除一个观战玩家
function CMD.removeViewer(srouce, uid)
    LOG_DEBUG("removeViewer", uid)
    local viewer = findViewUser(uid)
    if viewer then
        viewExit(uid)
        pcall(cluster.send, viewer.cluster_info.server, viewer.cluster_info.address, "deskBack", deskInfo.gameid) --释放桌子对象
    end
end

-- 准备，如果是私人房，则有这个阶段
function CMD.ready(source, msg)
    local recvobj = msg
    local uid     = math.floor(recvobj.uid)
	-- 先检测桌子状态
	if deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
		if deskInfo.state ~= PDEFINE.DESK_STATE.READY and deskInfo.state ~= PDEFINE.DESK_STATE.MATCH then
			return PDEFINE.RET.SUCCESS
		end
	end
	
    local user    = queryUserInfo(uid,"uid")
	clearAutoFunc(user.uid)
	if user.state == balcfg.UserState.Ready then
		return PDEFINE.RET.SUCCESS
	end
    user.state = balcfg.UserState.Ready
    local can_start = 1  -- 是否可以开始
    for _, muser in ipairs(deskInfo.users) do
        if muser.state ~= balcfg.UserState.Ready then
            can_start = 0
            break
        end
    end
    -- 如果人数少于最小人数，或者没有最小人数这个参数，则不能开始
    if not deskInfo.minSeat or #deskInfo.users < deskInfo.minSeat then
        can_start = 0
    end
    local retobj = {
        c = PDEFINE.NOTIFY.PLAYER_READY,
        code = PDEFINE.RET.SUCCESS,
        uid=uid,
        seatid = user.seatid,
        can_start = can_start,
    }
    broadcastDesk(cjson.encode(retobj))
    -- 如果都准备了，那就开始(匹配房不需要主动开始)
    if can_start == 1 and deskInfo.conf.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
		startGame(nil)
    end
    return PDEFINE.RET.SUCCESS
end



-- 发送聊天信息
function CMD.sendChat(source, msg)
    local recvobj = msg
    local uid     = math.floor(recvobj.uid)
    local user    = queryUserInfo(uid,"uid")
	-- 没有则找观战玩家
    if not user then
        user = findViewUser(uid)
    end
	if user then
		-- clearAutoFunc(user.uid)
		local retobj = {c = PDEFINE.NOTIFY.NOTIFY_ROOM_CHAT, code = PDEFINE.RET.SUCCESS, uid=uid, seatid = user.seatid, msg = recvobj.msg}
		broadcastDesk(cjson.encode(retobj))
	end
    return PDEFINE.RET.SUCCESS
end

-- 房主解散房间
function CMD.dismissRoom(source)
    -- 如果还没有开局，则直接
    if deskInfo.state == PDEFINE.DESK_STATE.MATCH 
    or deskInfo.state == PDEFINE.DESK_STATE.SETTLE 
    or deskInfo.state == PDEFINE.DESK_STATE.READY then
        local retobj = { c=PDEFINE.NOTIFY.GAME_DISMISS_ROOM, code = PDEFINE.RET.SUCCESS, deskid=deskInfo.deskid }
        broadcastDesk(cjson.encode(retobj))
        resetDesk()
		return PDEFINE.RET.SUCCESS
    else
        return PDEFINE.RET.ERROR.GAME_IS_RUNNING
    end
end

-- 更新玩家信息
function CMD.updateUserInfo(source, uid)
    LOG_DEBUG("updateUserInfo", "uid:", uid)
    local exist_user = queryUserInfo(uid, 'uid')
    if exist_user and exist_user.cluster_info then
        local ok, playerInfo = pcall(cluster.call, exist_user.cluster_info.server, exist_user.cluster_info.address, "clusterModuleCall", "player", "getPlayerInfo", uid)
        if ok and playerInfo then
            syncUserInfo(exist_user, playerInfo)
            broadcastPlayerInfo(exist_user)
        end
    end
end

-------- API更新桌子里玩家的金币 --------
function CMD.addCoinInGame(source, uid, coin, diamond)
    local user = queryUserInfo(uid, 'uid')
	if not user then
        user = findViewUser(uid)
    end
    if user then
		if coin then
        	user.coin = user.coin + coin
		end
		if diamond and user.diamond then
			user.diamond = user.diamond + diamond
		end
    end
end

------ api取牌桌信息 ------
function CMD.apiGetDeskInfo(source,msg)
    return deskInfo
end

------ api停服清房 ------
function CMD.apiCloseServer(source,csflag)
    closeServer = csflag
end

------ api解散房间 ------
function CMD.apiKickDesk(source)
    for _, muser in pairs(deskInfo.users) do
        if muser.cluster_info and muser.isexit == 0 then
            pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "deskBack", deskInfo.gameid) --释放桌子对象
            pcall(cluster.send, "master", ".mgrdesk", "syncMatchCurUsers", GAME_NAME, deskInfo.gameid, deskInfo.deskid, (#deskInfo.users))
        end
    end

	for _, muser in pairs(deskInfo.views) do
        if muser.cluster_info then
            pcall(cluster.send, muser.cluster_info.server, muser.cluster_info.address, "deskBack", deskInfo.gameid) --释放桌子对象
        end
    end

    local retobj = {c = PDEFINE.NOTIFY.ALL_GET_OUT, code = PDEFINE.RET.SUCCESS}
    broadcastDesk(cjson.encode(retobj))
    resetDesk()
end

-- 设置函数，方便调用
localFunc.startGame = startGame
localFunc.autoStartGame = autoStartGame
localFunc.setAutoKickOut = setAutoKickOut
localFunc.stopAutoKickOut = stopAutoKickOut
localFunc.prepareNewTrun = prepareNewTrun
localFunc.cancelDismiss = cancelDismiss
localFunc.updateMicStatus = updateMicStatus

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        local f = assert(CMD[command])
        skynet.retpack(f(source, ...))
    end)

    collectgarbage("collect")
end)