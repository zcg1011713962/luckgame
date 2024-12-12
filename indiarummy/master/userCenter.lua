local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local cjson   = require "cjson"
local date = require "date"
local snax = require "snax"
local queue = require "skynet.queue"
local queuemgr = require "queuemgr"
local api_service = require "api_service"
local player_tool = require "base.player_tool"
local sysmarquee = require "sysmarquee"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local cs = queue()

local APP = tonumber(skynet.getenv("app")) or 1

--聊天信息或 订单定时处理
local CMD = {}
local loginshutdownFlag = false --登录服关闭状态 true维护中；维护状态不让发广播
local node_notify_table = {} --node上的数据是否通知到usercenter了 在node启动的时候会让node通知一下

local last_check_sec, last_check_min, last_check_hour

local user_coin_data = {} --玩家 金币数据

-- 各聊天频道存放的是agent地址
local world_channel = {}  --用户在线
local hall_channel  = {}  --大厅用户uid

local online_user_data = {} -- 在线服务，临时维护在线玩家的基础数据
local rebate_gamelist = {} --返利游戏配置

-------- 改变登录服维护状态 --------
function CMD.changeLoginState(state)
	if math.floor(state) == 2 then
		loginshutdownFlag = true
	else
		loginshutdownFlag = false
	end
end

--获取用户cluster_info
function CMD.getAgent(uid)
	return world_channel[uid]
end

--获取所有在线用户
function CMD.getAllAgent()
	return world_channel
end

function CMD.joinPlayer(cluster_info, data)
    local uid = data.uid
    if uid ~= nil then 
	    -- 全局队列
        LOG_DEBUG("userCenter joinPlayer:", uid)
        world_channel[uid] = cluster_info
        pcall(skynet.send, ".friend", "lua", "online", uid)
        CMD.joinHall(uid)
    else
        LOG_INFO("world_channel uid  is nil", cluster_info, data)
    end
end

function CMD.removePlayer(data)
	local uid = data.uid
    if nil ~= world_channel[uid] then
        world_channel[uid] = nil
        pcall(skynet.send, ".friend", "lua", "offline", uid)
        CMD.removeHall(uid)
    end
    CMD.removeOnlineData(uid)
    pcall(skynet.call, ".levelgiftmgr", "lua", "clearTimeout", uid)
    pcall(skynet.call, ".balviproommgr", "lua", "exitRoomList", {['uid']=uid})
end

--玩家加入大厅
function CMD.joinHall(uid)
    uid = math.floor(uid)
    local exists = false
    for _, muid in pairs(hall_channel) do
        if muid == uid then
            exists = true
        end
    end
    if not exists then
        table.insert(hall_channel, uid)
    end
end

function CMD.removeHall(uid)
	for k, muid in pairs(hall_channel) do
		if muid == uid then
			table.remove(hall_channel, k)
		end
	end
end

-- 添加在线用户的信息
function CMD.addOnlineData(uid, data)
    online_user_data[uid] = data
end

-- 随机获取几个在线玩家
-- 采用水塘抽样的方式
function CMD.getRankOnlineUser(uid, limit)
    local uids = {}  -- 获取到的链接信息
    local result = {}  -- 获取到的用户信息列表
    local currIdx = 0
    for _uid, agent in pairs(world_channel) do
        if _uid and _uid ~= uid and not table.contain(uids, _uid) then
            currIdx = currIdx + 1
            if currIdx <= limit then
                table.insert(uids, _uid)
            else
                local rand = math.random(currIdx)
                if rand <= limit then
                    uids[rand] = _uid
                end
            end
        end
    end
    -- 通过获取的agent去获取信息
    for _, uid in ipairs(uids) do
        local userInfo = CMD.getPlayerInfo(uid)
        if userInfo then
            table.insert(result, {
                playername = userInfo.playername,
                avatarframe = userInfo.avatarframe,
                uid = userInfo.uid,
                usericon = userInfo.usericon,
                coin = userInfo.coin
            })
        end
    end
    return result
end

-- 获取
function CMD.getOnlineData(uid)
    if nil ~= online_user_data[uid] then
        return online_user_data[uid]
    end
end

-- 删除在线用户的信息
function CMD.removeOnlineData(uid)
    if nil ~= online_user_data[uid] then
        online_user_data[uid] = nil
    end
end

local function sendChat(cluster_info, msg)
	pcall(cluster.call, cluster_info.server, cluster_info.address, "sendToClient", msg)
end

--全服发通知
local function pushMsg(msg)
	for _,cluster_info in pairs(world_channel) do
		sendChat(cluster_info, msg)
	end
end

function CMD.pushHallUsers(msg)
    for _, cluster_info in pairs(hall_channel) do
        pcall(cluster.call, cluster_info.server, cluster_info.address, "sendToClient", msg)
    end
end

--根据uid推送消息
function CMD.pushInfoByUid(uid, msg)
    local agent = world_channel[uid]
	if nil ~= agent then
        --在线
        pcall(cluster.call, agent.server, agent.address, "sendToClient", msg)
    else
        LOG_DEBUG("用户不在线 uid:", uid)
	end
end

-- 推送多个人
function CMD.pushInfoByUids(uids, msg)
    for _, uid in ipairs(uids) do
        local agent = world_channel[uid]
        if nil ~= agent then
            --在线
            pcall(cluster.call, agent.server, agent.address, "sendToClient", msg)
        else
            LOG_DEBUG("用户不在线 uid:", uid)
        end
    end
end

-- 获取好友在开始排位前的邀请列表
function CMD.leagueAct(uid, act, paramstb)
    LOG_DEBUG("CMD.leagueAct uid:", uid, ' act:', act, ' paramstb:', paramstb)
    local agent = world_channel[uid]
	if nil ~= agent then
        local ok, league_info = pcall(cluster.call, agent.server, agent.address, act, paramstb)
        LOG_DEBUG("CMD.leagueAct uid:", uid, ' call user agent ok:',ok, ' league_info', league_info)
        return league_info
	end
    return {}
end

function CMD.leagueResume(uids)
    for _, uid in pairs(uids) do
        local agent = world_channel[uid]
        if nil ~= agent then
            local ok, league_info = pcall(cluster.call, agent.server, agent.address, "leagueResume")
            return league_info
        end
    end
    skynet.send(".invitemgr", "lua", "leave", uids)
end

-- 计算UID对应的弹窗
function CMD.getPoPList(uid)
    local agent = world_channel[uid]
	if nil ~= agent then
        --在线
        local ok, poplist, welcome_gift, onetimeleft = pcall(cluster.call, agent.server, agent.address, "clusterModuleCall", "player", "getPoPList", uid)
        if ok then
            return poplist, welcome_gift, onetimeleft
        end
    end
    return {}, 0, 0
end

--广播大厅跑马灯, 默认每2分钟1趟推送
local function get_msg(msgid,type,count)
    local retobj = { c = PDEFINE.NOTIFY.MARQUEE_ALL, code = PDEFINE.RET.SUCCESS}

    if nil ~= msgid then
		local msg   = do_redis({"hget", "push_notice:" .. msgid, "memo"}, nil) --消息内容
		local level = do_redis({"hget", "push_notice:" .. msgid, "level"}, nil) --消息优先级
		local count = do_redis({"hget", "push_notice:" .. msgid, "count"}, nil) --消息次数
		retobj.notices = {
			msg = msg,
			levle = level,
			count = count
		}
    else
        local rs = do_redis({ "zrevrange", "pushnotices" , 0, 1 }, nil)
        if #rs > 0 then
            for _, noticeid in pairs(rs) do
				local msg   = do_redis({"hget", "push_notice:" .. noticeid, "memo"}, nil) --消息内容
				local count = do_redis({"hget", "push_notice:" .. noticeid, "count"}, nil) --消息速度
				local level = do_redis({"hget", "push_notice:" .. noticeid, "level"}, nil) --消息次数
				retobj.notices = {
					msg = msg,
					levle = level,
					count = count
				}
                break
            end
        end
    end

    if nil ~= retobj.notices then
        pushMsg(cjson.encode(retobj))
    end

    return PDEFINE.RET.SUCCESS
end

--全服推送信息
function CMD.pushInfo(msg)
    for _, cluster_info in pairs(world_channel) do
        pcall(cluster.call, cluster_info.server, cluster_info.address, "sendToClient", msg)
    end
end

-- 我中了jackpot大奖，记录最近20条，好友系统展示用
local function presentJackpot(uid, gameid, coin)
    local cachKey = 'JACKPOTLIST:' .. uid
    local total = do_redis({"zcard", cachKey})
    local now = os.time()
    if total >= 20 then
        local maxscore = now - 5 * 86400
        local delCnt = do_redis({"zremrangebyscore", cachKey, 0, maxscore}) --将5天前的数据删除
        LOG_DEBUG("presentJackpot uid:", uid, " delCnt:", delCnt)
    end
    do_redis({"zadd", cachKey, now, string.format( "%s|%s", gameid, coin)})
end

local function triggerSendMail(uid, ctype, coin, msg, chanName)
    LOG_DEBUG('triggerSendMail:', uid, ctype, coin)
    local tpl = skynet.call(".configmgr", "lua", "getMailTPL", ctype)
    if tpl then
        local mailid = genMailId()
        local mailobj = {
            mailid = mailid,
            uid = uid,
            fromuid = 0,
            title = tpl.title,
            msg  = tpl.content,
            type = ctype,
            attach = cjson.encode({}),
            sendtime = os.time(),
            received = 0,
            hasread = 0,
            sysMailID= 0,
            rate =tpl.rate,
            svip = tpl.svip,
        }
        if ctype == PDEFINE.MAIL_TYPE.WINSERIES or ctype == PDEFINE.MAIL_TYPE.WINMORETHAN then
            local content = string.gsub(tpl.content, "XXX", "%%s")
            content = string.format(content, tpl.param1)
            mailobj.msg = content
        elseif ctype == PDEFINE.MAIL_TYPE.SHOP or ctype == PDEFINE.MAIL_TYPE.DRAWSUCC then --充值、提现到账
            local content = string.gsub(tpl.content, "XXX", "%%s")
            content = string.format(content, uid, coin)
            mailobj.msg = content
        elseif ctype == PDEFINE.MAIL_TYPE.DRAWFAIL then --提现失败
            local content = string.gsub(tpl.content, "XXX", "%%s")
            msg = msg or ''
            content = string.format(content, uid, coin, msg)
            mailobj.msg = content
        elseif ctype == PDEFINE.MAIL_TYPE.KYCBANKFAIL or ctype == PDEFINE.MAIL_TYPE.KYCPANFAIL then --提现失败
            local content = string.gsub(tpl.content, "XXX", "%%s")
            msg = msg or ''
            content = string.format(content, msg)
            mailobj.msg = content
        elseif ctype == PDEFINE.MAIL_TYPE.RECHARGEFAIL then
            local content = string.gsub(tpl.content, "AAA", "%%s")
            content = string.gsub(content, "BBB", "%%s")
            content = string.gsub(content, "CCC", "%%s")
            content = string.gsub(content, "XXX", "%%s")
            
            chanName = chanName or ''
            msg = msg or ''
            content = string.format(content, uid,coin ,chanName, msg)
            LOG_DEBUG('mailtpl:', content)
            mailobj.msg = content
        end
        if tpl.coin ~= nil and tpl.coin > 0 then
            mailobj.attach = cjson.encode({{type=PDEFINE.PROP_ID.COIN, count=tpl.coin}})
        end
        CMD.addUsersMail(uid, mailobj)
    end
end

--[[
更改玩家任务状态
]]
function CMD.updateQuest(uid, questid, count)
	local agent = world_channel[uid]
	if nil ~= agent then
		--在线
		cluster.call(agent.server, agent.address, "clusterModuleCall", "quest", "updateQuest", uid, 1, questid, count)
	else
		--不在线
		OFFLINE_CMD(uid, "updateQuest", {questid, count}, true)
	end
end

-- 更改累赢金币数
function CMD.updateWinCoin(uid, winCoin)
	local agent = world_channel[uid]
	if nil ~= agent then
		--在线
		cluster.call(agent.server, agent.address, "clusterModuleCall", "player", "updateWinCoin", uid, winCoin)
	else
		--不在线
        LOG_DEBUG('updateWinCoin:', uid , ' wincoin:', winCoin)
        local totalWinCoin = do_redis({ "hget", "d_user:" .. uid, 'wincoin'})
        totalWinCoin = tonumber(totalWinCoin or 0)
        totalWinCoin = totalWinCoin + winCoin
        local sql = string.format("update d_user set wincoin =wincoin + %d where uid = %d ",winCoin,uid)
        skynet.call(".mysqlpool", "lua", "execute", sql)
        do_redis({ "hset", "d_user:" .. uid, 'wincoin', totalWinCoin})
	end
end

-- 完成同类型批量任务
function CMD.updateBatchQuest(uid, questidDict, count)
	local agent = world_channel[uid]
	if nil ~= agent then
		--在线
		cluster.call(agent.server, agent.address, "clusterModuleCall", "quest", "updateBatchQuest", 1, questidDict, count)
	else
		--不在线
        for i=1, #questidDict do
            OFFLINE_CMD(uid, "updateQuest", {questidDict[i], count}, true)
        end
	end
end

function CMD.syncLobbyInfo(uid, msg)
    local agent = world_channel[uid]
	if nil ~= agent then
        pcall(cluster.call, agent.server, agent.address,
                        "clusterModuleCall", "player", "syncLobbyInfo", uid)
        if msg ~= nil then
            pcall(cluster.call, agent.server, agent.address, "sendToClient", msg)
        end
	end
end

-- 设置免费大转盘接口
function CMD.setTurnTableData(uid, type)
    local agent = world_channel[uid]
    if nil ~= agent then
        if type == 2 then
            cluster.call(agent.server, agent.address, "clusterModuleCall", "player", "setTurnTableBuyData", uid)
        else
            cluster.call(agent.server, agent.address, "clusterModuleCall", "player", "setTurnTableData", uid, 1)
        end
        
    end
end

--api接口 或 定时器接口，重置所有人的任务
function CMD.apiResetMainTask()
    local sql = string.format("update d_main_task set state=1,count=0")
    skynet.call(".mysqlpool", "lua", "execute", sql)

    local allagents = CMD.getAllAgent()
    for uid, agent in pairs(allagents) do
        pcall(cluster.send, agent.server, agent.address, "resetMaintask", uid)
    end
    return  PDEFINE.RET.SUCCESS
end

--自己通过kyc审核，更新上级的奖励次数
local function updateParentTurntableTimes(sunuid)
    local parentid = do_redis({ "hget", "d_user:" .. sunuid, "invit_uid"})
    parentid = tonumber(parentid or 0)
    LOG_DEBUG('updateParentTurntableTimes parentid uid:', parentid )
    if parentid > 0 then
        local agent = world_channel[parentid]
        if nil ~= agent then
            --在线
            LOG_DEBUG('updateParentTurntableTimes online uid:', parentid )
            cluster.send(agent.server, agent.address, "clusterModuleCall", "player", "updateTurntableTimes", parentid)
        else
            --不在线
            LOG_DEBUG("updateParentTurntableTimes. user not online uid:", parentid)

            --增加有效下级输
            local cacheKey = string.format("d_user_common_data:%d:%d", parentid, PDEFINE.USERDATA.COMMON.KYC_OF_SUN)
            local suns = do_redis({ "hget", cacheKey, 'value'})
            suns = tonumber(suns or 0)
            suns = suns + 1
            if suns == 1 then
                local sql = string.format("insert into d_user_common_data(uid,datatype,value) value(%d,%d,%d)", parentid, PDEFINE.USERDATA.COMMON.KYC_OF_SUN, 1)
                skynet.call(".mysqlpool", "lua", "execute", sql)
                local tbl = {
                    uid = parentid,
                    datatype = PDEFINE.USERDATA.COMMON.KYC_OF_SUN,
                    value = 1
                }
                do_redis({"hmset", cacheKey , tbl})
            else
                local sql = string.format("update d_user_common_data set `value`=`value`+1 where uid=%d and datatype=%d ", parentid, PDEFINE.USERDATA.COMMON.KYC_OF_SUN)
                skynet.call(".mysqlpool", "lua", "execute", sql)
                do_redis({"hincrby", cacheKey , 'value', 1})
            end
            local remainder = suns % 5
            if remainder == 0 then  -- 奖励转盘次数
                local cache2 = string.format("d_user_common_data:%d:%d", parentid, PDEFINE.USERDATA.COMMON.TIMES_OF_TURNTABLE)
                local times = do_redis({ "hget", cache2, 'value'})
                if nil == times then
                    local sql = string.format("insert into d_user_common_data(uid,datatype,value) value(%d,%d,%d)", parentid, PDEFINE.USERDATA.COMMON.TIMES_OF_TURNTABLE, 1)
                    skynet.call(".mysqlpool", "lua", "execute", sql)
                    local tbl = {
                        uid = parentid,
                        datatype = PDEFINE.USERDATA.COMMON.TIMES_OF_TURNTABLE,
                        value = 1
                    }
                    do_redis({"hmset", cache2 , tbl})
                else
                    local sql = string.format("update d_user_common_data set `value`=`value`+1 where uid=%d and datatype=%d ", parentid, PDEFINE.USERDATA.COMMON.TIMES_OF_TURNTABLE)
                    skynet.call(".mysqlpool", "lua", "execute", sql)
                    do_redis({"hincrby", cache2 , 'value', 1})
                end
                do_redis({"set", PDEFINE_REDISKEY.QUEUE.bonus_wheel_step .. parentid, 5})
            else
                do_redis({"set", PDEFINE_REDISKEY.QUEUE.bonus_wheel_step .. parentid, remainder})
            end
            do_redis({"hset", "data_change:" .. parentid, 'd_user_common_data', 1})
        end  
    end
    return PDEFINE.RET.SUCCESS
end

function CMD.apiUpdateBindInfo(uid, field)
    local agent = world_channel[uid]
    LOG_DEBUG('apiUpdateBindInfo uid:', uid , ' field:', field)
    local field_type = {'bindbank','bindusdt','bindupi','isbindphone','kyc'}
    if table.contain(field_type, field) then
        if field == 'isbindphone' then
            triggerSendMail(uid, PDEFINE.MAIL_TYPE.KYCMOBILE)
        end
 
        if nil ~= agent then
            --在线
            LOG_DEBUG('apiUpdateBindInfo online uid:', uid , ' field:', field)
            pcall( cluster.call, agent.server, agent.address, "apiUpdateBindInfo", uid, field)
        else
            --不在线
            LOG_ERROR("apiUpdateBindInfo. user not online uid:", uid, ' field:', field)
            local sql = string.format("select uid, bindbank,bindupi,isbindphone,kyc,bindusdt from d_user where uid=%d ", uid)
            local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
            if #rs > 0 then
                local sql2 = string.format("update d_user set %s=1 where uid=%d", field, uid)
                skynet.call(".mysqlpool", "lua", "execute", sql2)
                do_redis({ "hset", "d_user:" .. uid, field, 1})
            end
        end
        if field == 'kyc' then
            updateParentTurntableTimes(uid)
        end
    end
	
    return  PDEFINE.RET.SUCCESS
end

--api接口
function CMD.apiPayCallBack(orderid, amount, agentno)
    local sql = string.format("select * from s_shop_order where orderid='%s' limit 1", orderid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs == 0 then
        return PDEFINE_ERRCODE.ERROR.ORDER_PAID_ORDER_NOT_FOUND
    end
    local uid = rs[1].uid
    local agent = world_channel[uid]
    if nil ~= agent then
        --在线
        local ok, code, ret = pcall( cluster.call, agent.server, agent.address, "payCallBack", orderid, amount, agentno)
        LOG_DEBUG('支付订单异步通知 orderid:', orderid, ' amount:', amount, ' agentno:', agentno, ' ok:', ok, ' code:', code, ' ret:', ret)
        return code
    else
        --不在线
        LOG_ERROR("apiPayCallBack user not online:", uid)
        OFFLINE_CMD(uid, "payCallBack", {uid, orderid, amount, agentno}, true)
    end  
    return  PDEFINE.RET.SUCCESS
end

--api接口，添加用户属性值
function CMD.apiAddUserProperty(uid, type, num)
    local agent = world_channel[uid]
	if nil ~= agent then
        --在线
        pcall( cluster.call, agent.server, agent.address, "apiAddUserProperty", type, num)
        return PDEFINE.RET.SUCCESS
	else
        --不在线
        LOG_ERROR("upgrade err.code. user not online")
        local sql = string.format("select uid, diamond,points,rp,coin,level,levelexp,svip,svipexp,ticket,leagueexp,leaguelevel from d_user where uid=%d ", uid)
        local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs > 0 then
            if type == 'points' then
                local points = rs[1].points
                points = points + num
                local sql2 = string.format("update d_user set points=%d where uid=%d", points, uid)
                skynet.call(".mysqlpool", "lua", "execute", sql2)
                do_redis({ "hset", "d_user:" .. uid, 'points', points})
            elseif type =='rp' then
                local rp = rs[1].rp
                rp = rp + num
                local sql2 = string.format("update d_user set rp=%d where uid=%d", rp, uid)
                skynet.call(".mysqlpool", "lua", "execute", sql2)
                do_redis({ "hset", "d_user:" .. uid, 'rp', rp})
            elseif type =='diamond' then
                local diamond = rs[1].diamond
                diamond = diamond + num
                local sql2 = string.format("update d_user set diamond=%d where uid=%d", diamond, uid)
                skynet.call(".mysqlpool", "lua", "execute", sql2)
                do_redis({ "hset", "d_user:" .. uid, 'diamond', diamond})

                local rs = {
                    ['uid'] = uid,
                    ['content'] = "admin_recharge",
                    ['act'] = "admin",
                    ['remark'] = "",
                    ['diamond'] = num,
                    ['afterDiamond'] = diamond,
                    ['coin'] = rs[1].coin or 0,
                    ['level'] = rs[1].level or 1,
                    ['levelexp'] = rs[1].levelexp or 0,
                    ['svip'] = rs[1].svip or 0,
                    ['svipexp'] = rs[1].svipexp or 0,
                    ['ticket'] = rs[1].ticket or 0,
                    ['leagueexp'] = rs[1].leagueexp or 0,
                    ['leaguelevel'] = rs[1].leaguelevel or 0,
                }
                player_tool.addDiamondLog(rs)
            else
                LOG_ERROR("apiAddUserProperty err.code. type:", type, ' uid:',uid)
            end
            do_redis({"hset", "data_change:" .. uid, 'd_user', 1})
        end
    end
    return  PDEFINE.RET.SUCCESS
end

--更新玩家经验值和vip经验值, 往金猪里加的币
function CMD.updateUserLevelInfo(uid, update_data)
    local agent = world_channel[uid]
    if nil~=update_data["addcoin"] and update_data["addcoin"] > 0 then
        --升级奖励
        local code,beforecoin, aftercoin = player_tool.funcAddCoin(uid, update_data["addcoin"], "升级奖励", PDEFINE.ALTERCOINTAG.UPGRADEAWARD, PDEFINE.GAME_TYPE.SPECIAL.UPGRADEAWARD, PDEFINE.POOL_TYPE.none, nil, nil)
        if code ~= PDEFINE.RET.SUCCESS then
            LOG_ERROR("upgrade err.code", code, " uid", uid, 'cointype', PDEFINE.ALTERCOINTAG.UPGRADEAWARD)
            return false
        end
        CMD.addSendCoinLog(uid, update_data["addcoin"], "levelup")
    end
    update_data["addcoin"] = nil --去掉coin
	if nil ~= agent then
        --在线
        cluster.call(agent.server, agent.address, "clusterModuleCall", "player", "setPersonalExp", uid, update_data)
	else
        --不在线
        LOG_ERROR("upgrade err.code. user not online")
    end
    return true
end

-- 更新玩家经验值
function CMD.updateUserExp(uid, exp)
    local agent = world_channel[uid]
    if agent ~= nil then
        cluster.call(agent.server, agent.address, "clusterModuleCall", "upgrade", "bet", 0, exp, nil)
    else
        -- 不在线
        LOG_DEBUG("updateUserExp offline: ", uid, exp)
        OFFLINE_CMD(uid, "updateUserExp", {uid, exp}, true)
    end
end

--[[
    到期重置用户的league信息
    update_data = {
        leaguelevel = 1,
        leagueexp = 200,
    }
]]
function CMD.resetLeagueInfo(uid, update_data)
    local agent = world_channel[uid]
    if nil ~= agent then
        cluster.call(agent.server, agent.address, "clusterModuleCall", "player", "setPersonalExp", uid, update_data)
	else
        --不在线
        OFFLINE_CMD(uid, "resetLeagueInfo", {uid, cjson.encode(update_data)}, true)
        LOG_ERROR("upgrade err.code. user not online")
    end
    return true
end

--更新玩家累计消耗值和输赢金币
function CMD.updateUserWinCoin(uid, update_data)
    local agent = world_channel[uid]
	if nil ~= agent then
        --在线
        LOG_DEBUG("user :", uid, " isonline update_data:", update_data)
        cluster.call(agent.server, agent.address, "clusterModuleCall", "player", "setPersonalWinCoin", uid, update_data)
	else
        --不在线
        LOG_ERROR("upgrade err.code. user not online")
    end
    return true
end

--更新好友的魅力值
function CMD.updateFriendCharm(uid, charm)
    LOG_DEBUG("updateFriendCharm uid:", uid, ' charm:', charm)
    local agent = world_channel[uid]
	if nil ~= agent then
        --在线
        local ok, currCharm = pcall(cluster.call, agent.server, agent.address, "updateCharm", charm)
        if not ok then
            LOG_DEBUG("updateFriendCharm failed uid:", uid, ' charm:', charm)
        end
        skynet.send(".winrankmgr","lua","updateCharmRank",uid, charm, currCharm)
	else
        --不在线
        local playerInfo = CMD.getPlayerInfo(uid)
        local prevCharm = playerInfo.charm or 0
        local currCharm = tonumber(prevCharm or 0) + tonumber(charm)
        if prevCharm then  -- 如果redis中不存在这个字段，则不会更改
            do_redis({"hset", "d_user:"..uid, 'charm', currCharm}, uid)
        end
        local sql = string.format("update d_user set charm=%d where uid=%d", currCharm, uid)
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        -- 更新排行榜
        skynet.send(".winrankmgr","lua","updateCharmRank",uid, charm, currCharm)
    end
    return true
end

--[[
后台 赠送金币接口
addType: 红包 red_envelope； 其他普通用户 nil
]]
function CMD.apiAddCoin(uid, coin, ipaddr, addType, extend1)
	LOG_INFO("后台接口给玩家添加金币", uid, coin, ipaddr, addType, extend1)

    local gameid = PDEFINE.GAME_TYPE.SPECIAL.UP_COIN
    local cointype = PDEFINE.ALTERCOINTAG.UP
    if 'red_envelope' == addType then
    	cointype = PDEFINE.ALTERCOINTAG.REDENVELOPE
    elseif 'TOUP_REDUCE' == addType then 
    	cointype = PDEFINE.ALTERCOINTAG.TOUP_REDUCE
    elseif 'TOUP_ADD' == addType then
    	cointype = PDEFINE.ALTERCOINTAG.TOUP_ADD
    elseif 'TODOWN_REDUCE' == addType then
    	cointype = PDEFINE.ALTERCOINTAG.TODOWN_REDUCE
    elseif 'TODOWN_ADD' == addType then
    	cointype = PDEFINE.ALTERCOINTAG.TODOWN_ADD
    elseif 'PROFIT_TRANSFER' == addType then 
        cointype = PDEFINE.ALTERCOINTAG.PROFIT_TRANSFER
    elseif 'FRIEND_SEND' == addType then
        cointype = PDEFINE.ALTERCOINTAG.SEND
    elseif 'WITHDRAW_REFUND' == addType then
        cointype = PDEFINE.ALTERCOINTAG.WITHDRAW_BACK
    end
    local isonline = false
    if coin < 0 then
        gameid = PDEFINE.GAME_TYPE.SPECIAL.DOWN_COIN
        if nil == addType then 
        	cointype = PDEFINE.ALTERCOINTAG.DOWN
    	end
        --是不是在游戏内
        local desk = skynet.call(".agentdesk", "lua", "getDesk", uid)
        if desk ~= nil and not table.empty(desk) then
            --在游戏内
            LOG_ERROR("apiAddCoin gaming uid", uid, ' deskid:', desk)
            return PDEFINE.RET.ERROR.GAME_ING_ERROR
        end

        --后台下分加此配置
        if cointype == PDEFINE.ALTERCOINTAG.DOWN then 
            --下分
            local agent = world_channel[uid]
            if nil ~= agent then
                --在线不能下分
				LOG_ERROR("玩家下分 apiAddCoin isonline uid", uid)
                isonline = true
                return PDEFINE.RET.ERROR.GAME_ING_ERROR
            end
        end
    end

    local sql = string.format("select uid from d_user where uid=%d ", uid)
    local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        --都按游戏模式来进行
        extend1 = extend1 or '上下分'
        local code,before_coin,after_coin = player_tool.funcAddCoin(uid, coin, extend1, cointype, gameid, PDEFINE.POOL_TYPE.none, nil, extend1)
        if code ~= PDEFINE.RET.SUCCESS then
            LOG_ERROR("apiAddCoin err.code", code, " uid", uid, 'cointype', cointype)
            return PDEFINE.RET.ERROR.CALL_FAIL
        end
        local cluster_info = CMD.getAgent(uid)
        if cluster_info ~= nil then
            pcall( cluster.call, cluster_info.server, cluster_info.address, "brodcastcoin", coin )
        end
        CMD.brodcastcoin2client(uid, coin)
        return code
    end
    return PDEFINE.RET.ERROR.REGISTER_NOT
end

-- 让玩家掉线
function CMD.ApiOfflineUser(uidstr)
    local uidarr = string.split(uidstr, ',')
    for i,uid in ipairs(uidarr) do
        uid = math.floor(uid)
        local agent = CMD.getAgent(uid)
        LOG_DEBUG("ApiOfflineUser:", agent, "uid:", uid)
		if nil == agent then
			LOG_DEBUG("ApiOfflineUser agent is nil")
			pcall(cluster.call, "master", ".agentdesk", "removeDeskByUid", uid) --清理agentdesk
		else
			local retobj = { c = PDEFINE.NOTIFY.NOTIFY_SYS_KICK, code = PDEFINE.RET.SUCCESS}
            pcall(cluster.send, agent.server, agent.address, "sendToClient", cjson.encode(retobj))

			-- local ret= cluster.call(agent.server, agent.address,  "stdesk")
			-- if ret then
			-- 	-- 玩家在某个游戏中，就要从桌子里退出，具体退出规则根据具体游戏走
			-- 	local cluster_desk = cluster.call(agent.server, agent.address,  "getClusterDesk")
			-- 	if not table.empty(cluster_desk) then
			-- 		pcall(cluster.send, cluster_desk.server, cluster_desk.address, "apiKickUser", uid)
			-- 	else
			-- 		CMD.removePlayer({uid=uid})
			-- 		pcall(cluster.send, "master", ".agentdesk", "removeDeskByUid", uid) --清理agentdesk
			-- 	end
			-- else
				CMD.removePlayer({uid=uid})
				pcall(cluster.send, "master", ".agentdesk", "removeDeskByUid", uid) --清理agentdesk
			-- end

            pcall(cluster.send, agent.server, agent.address, "logout")
		end
    end
	
	local retobj = { c = PDEFINE.NOTIFY.NOTIFY_SYS_KICK, code = PDEFINE.RET.SUCCESS}
	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--删除账号(运维专用)
function CMD.apiDelAccount(uid)
	local sql = string.format("select * from d_account where id=%d limit 1", uid)
	local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
	if #rs > 0 then
		--玩家在线
		local agent = world_channel[uid]
		if nil ~= agent then

            local ok ,ret = pcall(cluster.call, agent.server, agent.address, "stdesk")
			LOG_INFO(" cluster.call return:", ret, 'ok:', ok)
			if not ok or ret == 1 then
				return 'fail'
			end
            pcall(cluster.send, agent.server, agent.address, "logout")
		end
		cluster.call('login', '.accountdata', "apiReleaseAccount", uid, rs[1].pid)
	end
end

function CMD.checkOnline( uidtable )
    local onlinetable = {}
    for _, uid in pairs(uidtable) do
        if world_channel[uid] ~= nil then
            onlinetable[uid] = world_channel[uid]
        end
    end
    return onlinetable
end

--判断玩家是否在线
function CMD.apiUserOnline(uidstr)
    local uidarr = string.split(uidstr, ',')
    local onlinestr = nil
    for _, id in pairs(uidarr) do
        local uid = tonumber(id)
        if world_channel[uid] ~= nil then
            if onlinestr == nil then
                onlinestr = tostring(id)
            else
                onlinestr = onlinestr .. ","..id
            end
        end
    end
    if onlinestr == nil then
        onlinestr = ""
    end
    return PDEFINE.RET.SUCCESS, onlinestr
end

--判断玩家是否在游戏中
function CMD.apiUserInGame(uidstr)
    local uidarr = string.split(uidstr, ',')
    local res = {
        ['online'] = {},
        ['game'] = {},
    }
    for _, id in pairs(uidarr) do
        local uid = tonumber(id)
        if world_channel[uid] ~= nil then
            table.insert(res['online'], uid)
            local agent = world_channel[uid]
            local ok, deskInfo = pcall(cluster.call, agent.server, agent.address, "getClusterDesk")
            if ok and deskInfo then
                res['game'][uid] = deskInfo.gameid
            end
        end
    end
    return PDEFINE.RET.SUCCESS, res
end

--获取在线人数
function CMD.getonlinenum( )
    local onlinenum = 0
    local onlineUids = {}
    for uid, agent in pairs(world_channel) do
        if agent ~= nil then
            onlinenum = onlinenum + 1
            table.insert(onlineUids, uid)
        end
    end
    return onlinenum, onlineUids
end

function CMD.apiControlSys(data)
	local ctrlInfo = {}
	if data.gameid == PDEFINE.GAME_TYPE.POKER_BENZ then
		ctrlInfo = {}
		ctrlInfo.gameid = data.gameid
		ctrlInfo.placeId = data.placeId
		ctrlInfo.count = data.count
		ctrlInfo.objid = data.objid
		if not table.empty(ctrlInfo) then
			do_redis({ "hmset", "dkpoint_" .. data.gameid, ctrlInfo, true })
		end
	end
end

--同时在线
function CMD.apiGetUserList(gameid)
	local userList = {}
	for uid, agent in pairs(world_channel) do
		if nil ~= agent then
            local ok, ret, userinfo = pcall(cluster.call, agent.server, agent.address, "apiUserInfo")
			if ok and ret == PDEFINE.RET.SUCCESS then
				if nil ~= gameid and gameid>0 then
					if userinfo.gameid == gameid then
						local tmp = {}
						tmp["uid"]         = userinfo.uid
						tmp["playername"]  = userinfo.playername
						tmp["coin"]        = userinfo.coin
						tmp["gameid"]      = userinfo.gameid
						tmp["deskid"]      = userinfo.deskid
						tmp["create_time"] = userinfo.create_time
						tmp["usericon"]    = userinfo.usericon
						table.insert(userList, tmp)
					end
				else
					local tmp = {}
					tmp["uid"]         = userinfo.uid
					tmp["playername"]  = userinfo.playername
					tmp["coin"]        = userinfo.coin
					tmp["gameid"]      = userinfo.gameid
					tmp["deskid"]      = userinfo.deskid
					tmp["create_time"] = userinfo.create_time
					tmp["usericon"]    = userinfo.usericon
					table.insert(userList, tmp)
				end
			end
		end
	end
	return PDEFINE.RET.SUCCESS, cjson.encode(userList)
end

--后台修改用户属性以及控制玩家游戏中玩牌流程
function CMD.apiControl(data)
	--不管是否在不在房间以及是否离线 直接存放 redis 目前只存放水浒传的字段---TODO 其它游戏往里面写自己需要的字段
	local ctrlInfo = {}
	if data.gameid == PDEFINE.GAME_TYPE.POKER_ELI then
		ctrlInfo = {}
		ctrlInfo.uid = data.uid
		ctrlInfo.gameid = data.gameid
		ctrlInfo.mult = data.mult
		ctrlInfo.count = data.count
		ctrlInfo.objid = data.objid
		if not table.empty(ctrlInfo) then
			do_redis({ "hmset", "dk_" .. data.gameid .. "_"..data.uid, ctrlInfo, true }, data.uid)
		end
	elseif data.gameid==PDEFINE.GAME_TYPE.POKER_REDBLACKWAR or data.gameid==PDEFINE.GAME_TYPE.POKER_TIGER or data.gameid==PDEFINE.GAME_TYPE.POKER_HUNDRED then
		--百人牛牛、红黑大战、龙虎斗
		ctrlInfo = {}
		ctrlInfo.uid = data.uid
		ctrlInfo.uid2 = data.uid2
		ctrlInfo.gameid = data.gameid
		ctrlInfo.count = data.count
		ctrlInfo.cardtype = data.cardtype
		ctrlInfo.cardtype2 = data.cardtype2
		ctrlInfo.objid = data.objid
		LOG_INFO("设置游戏控制信息：", ctrlInfo)
		if not table.empty(ctrlInfo) then
			do_redis({ "hmset", "dk_" .. data.gameid, ctrlInfo, true })
		end
	end
end
local waitUserAgentList = {}


function CMD.insetUserAgent(server,address)
    local cluster_info = {}
    cluster_info.server = server
    cluster_info.address = address
    table.insert(waitUserAgentList,cluster_info)
end

--获取正在等待关闭的useragent
--@param num返回多少个 如果不填参数则全部返回
--@return 总数量，指定的待返回个数的table
function CMD.getWaitExitUserAgent(num)
    local waitnum = #waitUserAgentList
    if num == nil or waitnum <= num then
        return waitnum,waitUserAgentList
    end

    local list = {}
    for i, cluster_info in pairs(waitUserAgentList) do
        table.insert(list, cluster_info)
    end
    return waitnum,list
end

-- 定时执行循环
local function waitExitUserAgent()
    if #waitUserAgentList > 0 then
        for i, cluster_info in pairs(waitUserAgentList) do
            local ok, deskAdrss = pcall(cluster.call, cluster_info.server, cluster_info.address, "getClusterDesk")
            if nil == deskAdrss or table.empty(deskAdrss) then
				LOG_INFO("waitUserAgent", cluster_info)
				pcall(cluster.call, cluster_info.server, cluster_info.address, "exit")
				waitUserAgentList[i] = nil
                --table.remove(waitUserAgentList,i)
            end
        end
    end
end

local cache_league_open = 0
-- 1、每分钟执行，判断排位赛是开了，还是关闭了。通知客户端
local function isLeagueStartOrEnd()
    local now = os.time()
    local hour = os.date("%H", now)
    hour = tonumber(hour)
    local zeroTime = date.GetTodayZeroTime(os.time())
    local isopen = 0 --关闭中
    local stopTime = 0
    for i=#PDEFINE.LEAGUE.HOUR, 1, -1 do
        if PDEFINE.LEAGUE.HOUR[i].stop > hour and PDEFINE.LEAGUE.HOUR[i].start <= hour then
            isopen = 1 --已开始
            stopTime = (zeroTime+ PDEFINE.LEAGUE.HOUR[i].stop * 3600) - now
            break
        end
    end
    if cache_league_open ~= isopen then
        CMD.syncLeagueState(isopen, stopTime)
    end 
    cache_league_open = isopen
end

-- 定时执行循环
local function update()
	local time_now = os.time()
	local time_info = os.date("*t", time_now)
	-- 每秒判定
	if last_check_sec ~= time_info.sec then

		last_check_sec = time_info.sec
		-- 每5秒处理
		if last_check_sec % 5 == 0 then
			waitExitUserAgent()
		--	local param = {}
		--
		--	-- 外部定时任务
		end
		---- 每10秒处理
		--if last_check_sec % 10 == 0 then
		--end

		-- 每分钟判定
		if last_check_min ~= time_info.min then
			last_check_min = time_info.min
            isLeagueStartOrEnd()

            skynet.send(".genuid","lua","runGenUid")

			-- 每2分钟处理
			if last_check_min % 2 == 0 then
				get_msg(nil, NOTIFY_NOTICE_HALL) --下推消息
			end

            if last_check_min % 10 == 0 then
				skynet.send(".genuid","lua","runMonitorQueueSize")
			end

			-- 每小时判定
			if last_check_hour ~= time_info.hour then
				local change_hour = false
				if last_check_hour ~= -1 then
					change_hour = true
				end
				last_check_hour = time_info.hour
				-- 小时变动
				if change_hour then
					-- 每4小时处理
					if last_check_hour % 4 == 0 then
						-- mysql keepalive
						pcall(cluster.call, "login", ".mysqlpool", "keepalive")
						pcall(cluster.call, "node", ".mysqlpool", "keepalive")
						pcall(cluster.call, "game", ".mysqlpool", "keepalive")
						pcall(cluster.call, "master", ".mysqlpool", "keepalive")
						pcall(cluster.call, "ai", ".mysqlpool", "keepalive")
                        pcall(cluster.call, "api", ".mysqlpool", "keepalive")
                        -- pcall(cluster.call, "loginhttp", ".mysqlpool", "keepalive")
					end
				end
			end
		end
	end
end

local function gameLoop()
	while true do
		update()
		skynet.sleep(100)
	end
end

--大厅玩家重启App
function CMD.ApiPushRestart()
    local retobj = { c = PDEFINE.NOTIFY.MUST_RESTART, code = PDEFINE.RET.SUCCESS}
    local servertable = skynet.call(".servermgr", "lua", "getServerByTag", "node")
    local sendmsg = cjson.encode(retobj)
    for _,server in pairs(servertable) do
        LOG_DEBUG("CMD.ApiPushRestart server:", server, retobj)
        pcall(cluster.call, server.name, server.serverinfo.address, "brodcast", nil, "sendToClient", sendmsg)
    end

    return PDEFINE.RET.SUCCESS
end

--玩家进入登录界面
function CMD.ApiPushAll2Login()
    LOG_DEBUG('ApiPushAll2Login start...')
    local retobj = { c = PDEFINE.NOTIFY.NOTIFY_SYS_KICK, code = PDEFINE.RET.SUCCESS}

    local servertable = skynet.call(".servermgr", "lua", "getServerByTag", "node")
    local sendmsg = cjson.encode(retobj)
    for _,server in pairs(servertable) do
        LOG_DEBUG("CMD.ApiPushAll2Login server:", server, retobj, hall_channel)
        pcall(cluster.call, server.name, server.serverinfo.address, "brodcast", hall_channel, "sendToClient", sendmsg)
    end

    return PDEFINE.RET.SUCCESS
end

--在线玩家数
function CMD.ApiUserNum()
	local retobj = { c = PDEFINE.NOTIFY.MUST_RESTART, code = PDEFINE.RET.SUCCESS}

	local all, hall = 0, 0
	for uid, _ in pairs(world_channel) do
		all = all + 1
	end
	for uid, _ in pairs(hall_channel) do
		hall = hall + 1
	end
	retobj.all = all
	retobj.hall= hall

    local loginTypeCnt = {  -- 10 谷歌  11 苹果 12 FB 13 华为 1游客
        ["fb"] = 0,
        ["apple"] = 0,
        ["google"] = 0,
        ["guest"] = 0,
        ["huawei"] = 0,
        ["other"] = 0
    }
    local platformCnt = {
        ["android"] = 0,
        ["ios"] = 0,
        ["other"] = 0,
    }
    for uid, row in pairs(online_user_data) do
        if row.logintype == 1 then
            loginTypeCnt["guest"] = loginTypeCnt["guest"] + 1
        elseif row.logintype == 10 then
            loginTypeCnt["google"] = loginTypeCnt["google"] + 1
        elseif row.logintype == 11 then
            loginTypeCnt["apple"] = loginTypeCnt["apple"] + 1
        elseif row.logintype == 12 then
            loginTypeCnt["fb"] = loginTypeCnt["fb"] + 1
        elseif row.logintype == 13 then
            loginTypeCnt["huawei"] = loginTypeCnt["huawei"] + 1
        else
            loginTypeCnt["other"] = loginTypeCnt["other"] + 1
        end

        if row.platform == 1 then
            platformCnt['android'] = platformCnt['android'] + 1
        elseif row.platform == 2 then
            platformCnt['ios'] = platformCnt['ios'] + 1
        else
            platformCnt['other'] = platformCnt['other'] + 1
        end
    end
    retobj.logintype = loginTypeCnt
    retobj.platform = platformCnt

	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

local function reloadUserInfo(uid)
    local agent = world_channel[uid]
	if nil ~= agent then
		--在线
		cluster.call(agent.server, agent.address, "clusterModuleCall", "player", "reloadPlayerInfo", uid)
	else
		--不在线
		OFFLINE_CMD(uid, "reloadPlayerInfo", {uid}, true)

		--不在线的用户 直接先改几个展示的属性
		local sql = string.format("select * from d_user where uid = %d ",uid)
		local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
		if #rs > 0 then
			local row = {}
			row["playername"]   = rs[1].playername
			row["agent"]        = rs[1].agent
			row["status"]       = rs[1].status
            row["kyc"]          = rs[1].kyc
            row["kycfield"]        = rs[1].kycfield
            row["isbindphone"]     = rs[1].isbindphone
            row["istest"]          = rs[1].istest
            row["nodislabelid"] = rs[1].nodislabelid
			local tbname = "d_user"
			do_redis({ "hmset", tbname .. ":" .. uid, row, true}, uid)
		end
	end
end

local function addBonusLog(orderid, title, coin, nowtime, rtype, uid, suid, dorepeat)
    if suid == nil then
        suid = 0
    end
    if nil == dorepeat then
        dorepeat = false
    end
    local sql = string.format("insert into d_log_cashbonus(orderid,title,coin,create_time,category,uid,useruid) values ('%s','%s', %.2f, %d, %d, %d,%d)", 
        orderid,title, coin, nowtime, rtype, uid, suid)
    if dorepeat then
        sql = sql .. string.format(",('%s','%s', %.2f, %d, %d, %d,%d)", orderid, title, -coin, nowtime+1, PDEFINE.TYPE.SOURCE.Transfer_Cash, uid, suid)
    end
    do_mysql_queue(sql)
end

-- 同步211到客户端，会触发客户端请求62协议
local function syncWallet(uid)
    local agent = CMD.getAgent(uid)
    if agent then
        pcall(cluster.send, agent.server, agent.address, "syncWallet", uid)
    end
end

local function addCoinByRate(parentid, addCoin, rate, actType, title, suid)
    addCoin = tonumber(addCoin)
    local rateArr = decodeRate(rate)
    local nowtime = os.time()
    local key = 'd_user:' .. parentid
    LOG_DEBUG('addCoinByRate key:', key, actType, ' rateArr:', rateArr)
    local agent = CMD.getAgent(parentid)
    if agent then
       local ok = pcall(cluster.call, agent.server, agent.address, "clusterModuleCall", "player", "addCoinByRate", parentid, addCoin, rate, actType, suid,nil,nil, title)
        if ok then
            return true
        end
    end

    local orderid = genOrderId('bonus')
    if nil == suid then
        suid = 0
    end

    if tonumber(rateArr[1]) > 0 then
        local alterType = PDEFINE.ALTERCOINTAG.AGENT_REG_REWARDS
        if actType == PDEFINE.TYPE.SOURCE.VIP_WEEK then
            alterType = PDEFINE.ALTERCOINTAG.VIP_WEEK
        elseif actType == PDEFINE.TYPE.SOURCE.VIP_MONTH then
            alterType = PDEFINE.ALTERCOINTAG.VIP_MONTH
        elseif actType == PDEFINE.TYPE.SOURCE.BUY then
            alterType = PDEFINE.ALTERCOINTAG.AGENT_BUY_REWARDS
        elseif actType == PDEFINE.TYPE.SOURCE.BET then
            alterType = PDEFINE.ALTERCOINTAG.AGENT_BET_REWARDS
        end

        local ra = tonumber(rateArr[1])
        local coin = math.round_coin(ra * addCoin)
        local code, beforecoin, aftercoin = player_tool.funcAddCoin(parentid, coin, title,
        alterType, PDEFINE.GAME_TYPE.SPECIAL.QUEST,  PDEFINE.POOL_TYPE.none, nil)

        local parent = player_tool.getPlayerInfo(parentid)
        local svip = 0 
        if parent then
            svip = parent.svip or 0
        end
        local sql = string.format("insert into s_send_coin(uid,coin,create_time,act, level, scale, diamond,svip) values (%d, %2.f, %d, '%s', %d, %2.f, %d, %d)", 
        parentid, coin, os.time(), actType, 0, 1, 0, svip)

        LOG_DEBUG('addCoinByRate parentid:', parentid, ' sql:', sql)
        do_mysql_queue(sql)
        addBonusLog(orderid, title, coin, nowtime, actType, parentid, suid, true)
    end
    
    if tonumber(rateArr[2]) > 0 then
        local ra = tonumber(rateArr[2])
        local coin = math.round_coin(ra * addCoin)
        local code, beforecoin, aftercoin = player_tool.funcAddCoin(parentid, coin, title,
        PDEFINE.ALTERCOINTAG.AGENT_REG_REWARDS, PDEFINE.GAME_TYPE.SPECIAL.QUEST,  PDEFINE.POOL_TYPE.none, nil)
        
        local sql1 = string.format("update d_user set gamedraw=gamedraw+%2.f where uid=%d", coin, parentid)
        LOG_DEBUG('addCoinByRate draw parentid:', parentid, ' sql:', sql1)
        do_mysql_queue(sql1)
        do_redis({"hincrbyfloat", key, 'gamedraw', coin})

        local sql = string.format("insert into d_log_senddraw(orderid,title,coin,create_time,category,uid,useruid) values ('%s','%s', %.2f, %d, %d, %d, %d)", 
        orderid, title, coin, nowtime, actType, parentid, suid)
        LOG_DEBUG('addCoinByRate draw parentid:', parentid, ' sql:', sql)
        do_mysql_queue(sql)
    end
    if tonumber(rateArr[3]) > 0 then
        local ra = tonumber(rateArr[3])
        local coin = math.round_coin(ra * addCoin)
        local sql1 = string.format("update d_user set cashbonus=cashbonus+%2.f where uid=%d", coin, parentid)
        LOG_DEBUG('addCoinByRate bonus parentid:', parentid, ' sql:', sql1)
        do_mysql_queue(sql1)
        do_redis({"hincrbyfloat", key, 'cashbonus', coin})
        addBonusLog(orderid, title, coin, nowtime, actType, parentid, suid)
    end
    return syncWallet(parentid)
end

function CMD.clearRebateGameids()
    rebate_gamelist = {}
end

-- 游戏中下注返利
function CMD.gameRebate(uid, actType, coin, gameid, issue)
    gameid = tonumber(gameid or 0)
    if table.empty(rebate_gamelist) then
        local cfg = skynet.call(".configmgr", "lua", "getRebateCfg")
        LOG_DEBUG('invite cfg:', cfg)
        if cfg and cfg.bet and cfg.bet.gameids then
            local str = cfg.bet.gameids or ""
            rebate_gamelist = string.split(str, ',')
            LOG_INFO('gameRebate rebate_gamelist:', rebate_gamelist)
        end
    end
    for key, gid in pairs(rebate_gamelist) do
        if tonumber(gid) == gameid then
            CMD.AddSuperiorRewards(uid, actType, coin, 2, gameid, issue)
            break
        end
    end
end

-- 判断可转金额是否大于cash bonus了
local function getDiffCashBonus(uid, addCoin)
    local playerInfo  = player_tool.getPlayerInfo(uid)
    local gamebonus   = tonumber(playerInfo.gamebonus or 0) --累计的输钱
    local svip        = tonumber(playerInfo.svip or 0) --vip等级
    local cashbonus   = tonumber(playerInfo.cashbonus or 0) --优惠钱包
    local tranedBonus = tonumber(playerInfo.dcashbonus or 0) --已转走的cash bonus
    local vipCfgList  = skynet.call(".configmgr", "lua", "getVipUpCfg")
    if vipCfgList[svip] and vipCfgList[svip].tranrate > 0 then
        local rate = vipCfgList[svip].tranrate
        local hadBonus = math.round_coin((rate * math.abs(gamebonus)) - tranedBonus) -- (累计gamebonus - 已转的)
        local shouldAddCoin = math.round_coin(rate * addCoin)
        if (hadBonus + shouldAddCoin) > cashbonus then
            return math.round_coin((cashbonus + tranedBonus)/rate - gamebonus)
        end
    end
    if nil == vipCfgList[svip] or  vipCfgList[svip].tranrate == 0 then
        return 0
    end
    return addCoin
end

-- 游戏记录时候，完成相关任务，分成以及累计可提金额和bonus
--[[
    local data = {
        betcoin = betcoin,
        wincoin = wincoin,
        uid = user.uid,
        actType = PDEFINE.TYPE.SOURCE.BET,
        gameid = deskInfo.gameid,
        tasks = {},
        issue = deskInfo.issue,
    }

     -- pcall(cluster.send, user.cluster_info.server, user.cluster_info.address, "clusterModuleCall", "maintask", "updateTask", user.uid, updateMainObjs)

    -- pcall(cluster.send, "master", ".userCenter", "gameRebate", user.uid, PDEFINE.TYPE.SOURCE.BET, betcoin, tonumber(deskInfo.gameid), deskInfo.issue)
]]

--累计可转和可提金额
local function recordWinningsOffline(uid, data, maxGameDrawCoin)
    if data.wincoin >= 0 then
        if data.wincoin > data.betcoin then
            local diffcoin = math.round_coin(data.wincoin - data.betcoin)
            if maxGameDrawCoin > 0 then
                local fields = {'ispayer', 'gamedraw', 'drawsucctimes'}
                local cacheData = do_redis({ "hmget", "d_user:".. uid, table.unpack(fields)})
                cacheData = make_pairs_table_int(cacheData, fields)
                if cacheData.ispayer == 0 and (cacheData.gamedraw + diffcoin) > maxGameDrawCoin then --是未付款新会员 且有设置的最大提现的时候
                    diffcoin = math.round_coin(maxGameDrawCoin - cacheData.gamedraw)
                end
                if cacheData.ispayer == 0 and cacheData.drawsucctimes and cacheData.drawsucctimes > 0 then --未付款会员，提现1次之后不能再累计
                    return
                end
            end
            local sql = string.format("update d_user set gamedraw=gamedraw+%.2f where uid = %d ", diffcoin, uid)
            skynet.call(".mysqlpool", "lua", "execute", sql)
            do_redis({"hincrbyfloat", 'd_user:'..uid , 'gamedraw', diffcoin})
        elseif data.wincoin < data.betcoin then
            local diffcoin = math.round_coin(data.betcoin - data.wincoin)
            local shouldAdd = getDiffCashBonus(uid, diffcoin)
            if shouldAdd > 0 then
                local sql = string.format("update d_user set gamebonus=gamebonus+%.2f where uid = %d ", shouldAdd, uid)
                skynet.call(".mysqlpool", "lua", "execute", sql)
                do_redis({"hincrbyfloat", 'd_user:'..uid , 'gamebonus', shouldAdd})
            end
        end
    elseif data.wincoin < 0 then
        local diffcoin = math.round_coin(data.betcoin + math.abs(data.wincoin))
        local shouldAdd = getDiffCashBonus(uid, diffcoin)
        if shouldAdd > 0 then
            local sql = string.format("update d_user set gamebonus=gamebonus+%.2f where uid = %d ", shouldAdd, uid)
            skynet.call(".mysqlpool", "lua", "execute", sql)
            do_redis({"hincrbyfloat", 'd_user:'..uid , 'gamebonus', shouldAdd})
        end
    end
end

--累计可转和可提金额(Rummy Vip)
local function recordWinningsOfflineRummyVip(uid, data, maxGameDrawCoin)
    -- 增加可提金额
    local coin = math.round_coin(data.betcoin)
    if data.wincoin < 0 then
        coin = math.round_coin(math.abs(data.wincoin))
    end
    local sql = string.format("update d_user set gamedraw=gamedraw+%.2f where uid = %d ", coin, uid)
    skynet.call(".mysqlpool", "lua", "execute", sql)
    do_redis({"hincrbyfloat", 'd_user:'..uid , 'gamedraw', coin})

    -- 增加可转金额
    if data.wincoin >= 0 then
        if data.wincoin < data.betcoin then
            local diffcoin = math.round_coin(data.betcoin - data.wincoin)
            local shouldAdd = getDiffCashBonus(uid, diffcoin)
            if shouldAdd > 0 then
                local sql = string.format("update d_user set gamebonus=gamebonus+%.2f where uid = %d ", shouldAdd, uid)
                skynet.call(".mysqlpool", "lua", "execute", sql)
                do_redis({"hincrbyfloat", 'd_user:'..uid , 'gamebonus', shouldAdd})
            end
        end
    elseif data.wincoin < 0 then
        local diffcoin = math.round_coin(data.betcoin + math.abs(data.wincoin))
        local shouldAdd = getDiffCashBonus(uid, diffcoin)
        if shouldAdd > 0 then
            local sql = string.format("update d_user set gamebonus=gamebonus+%.2f where uid = %d ", shouldAdd, uid)
            skynet.call(".mysqlpool", "lua", "execute", sql)
            do_redis({"hincrbyfloat", 'd_user:'..uid , 'gamebonus', shouldAdd})
        end
    end
    
    local cfg = skynet.call(".configmgr", "lua", "batchGet",{'check_stop','check_recharge','check_discount'})
    if cfg then
        local check_stop = 0
        if cfg['check_stop'] then
            check_stop  = tonumber(cfg['check_stop'].v) or 0 --阔值
        end
        if check_stop > 0 then
            local userInfo = CMD.getPlayerInfo(uid)
            local coin = userInfo.coin or 0
            local check_recharge = 0 
            if cfg['check_recharge'] then
                check_recharge = tonumber(cfg['check_recharge'].v) or 0 --充值稽核倍数
            end
            local check_discount = 0
            if cfg['check_discount'] == 0 then
                check_discount = tonumber(cfg['check_discount'].v) or 0 --优惠稽核倍数
            end
            local ckrechargecoin = tonumber(userInfo.ckrechargecoin or 0) * check_recharge
            local cksendcoin = tonumber(userInfo.cksendcoin or 0) * check_discount
            local gamedraw = tonumber(userInfo.gamedraw or 0)
            local diffcoin = ckrechargecoin + cksendcoin - gamedraw --稽核差额
            if (coin <= check_stop) or (diffcoin <= check_stop) then
                local sql = string.format("update d_user set ckrechargecoin=0,cksendcoin=0 where uid = %d ",  uid)
                skynet.call(".mysqlpool", "lua", "execute", sql)
                local tmp = {
                    ['ckrechargecoin'] = 0,
                    ['cksendcoin'] = 0,
                }
                do_redis({ "hmset", "d_user:" .. uid, tmp, true })
            end
        end
    end
end

function CMD.gameResult(data)
    LOG_DEBUG('gameResult data:', data)
    local uid = data.uid

    if data.gameid >= 200 and data.gameid < 400 and data.playername then
        sysmarquee.onConsecutiveWin(data.playername, data.uid, data.wincoin)
    end

    local effbet = data.betcoin - data.wincoin
    if APP == PDEFINE.APPID.RUMMYVIP then
        --Rummy Vip已用户投注计算打码(返利需确认)
        --effbet = data.betcoin
    end
    if effbet > 0 then --按照有效下注的概念，给上级返利
        CMD.gameRebate(uid, PDEFINE.TYPE.SOURCE.BET, effbet, data.gameid, data.issue)
    end

    local maxGameDrawCoin = 0 --未付费新会员被限制的最大可提现基恩
    local cfg = skynet.call(".configmgr", "lua", "get",'newuser_no_pay_drawlimit')
    if not table.empty(cfg) then
        maxGameDrawCoin = math.floor(cfg.v)
    end

    local agent = CMD.getAgent(uid)
    if agent then
        --累计可提，可转bonus, 任务
        if not table.empty(data.tasks) then
            pcall(cluster.send, agent.server, agent.address, "clusterModuleCall", "maintask", "updateTask", uid, data.tasks)
        end
        if APP == PDEFINE.APPID.RUMMYVIP then
            local checkcfg = skynet.call(".configmgr", "lua", "batchGet",{'check_stop','check_recharge','check_discount'})
            local params = {
                check_stop = tonumber(checkcfg['checkcfg'].v) or 0,
                check_recharge = tonumber(checkcfg['check_recharge'].v) or 0,
                check_discount = tonumber(checkcfg['check_discount'].v) or 0
            }
            pcall(cluster.send, agent.server, agent.address, "recordWinningsRummyVip", data.betcoin, data.wincoin, params)
        else
            pcall(cluster.send, agent.server, agent.address, "recordWinnings", data.betcoin, data.wincoin, maxGameDrawCoin)
        end
    else
        --累计可转和可提金额
        if APP == PDEFINE.APPID.RUMMYVIP then
            recordWinningsOfflineRummyVip(uid, data, maxGameDrawCoin)
        else
            recordWinningsOffline(uid, data, maxGameDrawCoin)
        end
    end
end

-- 是否有无优惠标签，根据标签计算是否停止返优惠
local function stopDiscount(uid, dis_type)
    local invitInfo = CMD.getPlayerInfo(uid)
    if invitInfo and invitInfo.nodislabelid then
        local labelInfo = skynet.call(".configmgr", "lua", "getDiscountLabel", invitInfo.nodislabelid)
        if labelInfo and table.contain(labelInfo, dis_type) then
            LOG_DEBUG('stopDiscount: uid:',uid,   ' nodislabelid:', invitInfo.nodislabelid)
            return true
        end
    end
    return false
end

-- 添加上级奖励
function CMD.AddSuperiorRewards(uid, actType, coin, rtype, gameid, issue, ispayer)
    gameid = tonumber(gameid or 0)
    issue = issue or ""
    coin = tonumber(coin or 0)
    rtype = tonumber(rtype or 1) --注册返利的开关点, 1:充值时候返， 2:立即绑定就返
    local playerInfo = CMD.getPlayerInfo(uid)
    if ispayer == nil then
        ispayer = tonumber(playerInfo.ispayer or 0)
    end
    local invit_uid = tonumber(playerInfo.invit_uid or 0)
    
    local flag = false
    if actType == PDEFINE.TYPE.SOURCE.REG then
        if rtype == 1 then
            if invit_uid > 0 and ispayer==1 then
                flag = true
            end
        else
            if invit_uid > 0 then
                flag = true
            end
        end
    else
        if invit_uid > 0 and ispayer==1 then
            flag = true
        end
    end
    if flag and stopDiscount(invit_uid, PDEFINE.DISCOUNTLABEL.AGENT) then --应该给上级优惠的时候，判断下上级是否有标签
        flag = false
        LOG_DEBUG('userkYCED: uid:',uid,  ' invit_uid:', invit_uid, ' flag change 2 false')
    end
    LOG_DEBUG('userkYCED: uid:',uid,  ' invit_uid:', invit_uid, ' actType:',actType, ' ispayer:', ispayer, ' rtype:',rtype, ' flag:',flag)
    if flag then
        local parentuid = invit_uid
        local data = skynet.call(".configmgr", "lua", "getRebateCfg")
        if data then
            local title= '下级:'..uid..',首充:'..coin
            local coin1 = 0
            local rate1 = ''
            local coin2 = 0
            local rate2 = ''
            if actType == PDEFINE.TYPE.SOURCE.REG then
                if data.invite and data.invite.coin1 > 0 then
                    coin1 = data.invite.coin1
                    rate1 = data.invite.rate1
                end
                if data.invite and data.invite.coin2 > 0 then
                    coin2 = data.invite.coin2
                    rate2 = data.invite.rate2
                end
            elseif actType == PDEFINE.TYPE.SOURCE.BUY then
                title = '下级:'..uid..',充值:' .. coin
                coin1 = math.round_coin(coin * data.recharge.rrate1)
                coin2 = math.round_coin(coin * data.recharge.rrate2)
                rate1 = data.recharge.rate1
                rate2 = data.recharge.rate2
            elseif actType == PDEFINE.TYPE.SOURCE.BET then
                title = '下级:'..uid..',下注:' .. coin
                coin1 = math.round_coin(coin * data.bet.rrate1)
                coin2 = math.round_coin(coin * data.bet.rrate2)
                rate1 = data.bet.rate1
                rate2 = data.bet.rate2
            end
            coin2 = 0
            local added1 = false
            if coin1 > 0 then --上级奖励
                LOG_DEBUG('AddSuperiorRewards: addCoinByRate1 :', coin1)
                local pInfo = player_tool.getPlayerInfo(parentuid)
                if nil == pInfo.stopregrebat or tonumber(pInfo.stopregrebat) == 0 then
                    added1 = true
                    addCoinByRate(parentuid, coin1, rate1, actType, title, uid)
                end
            end
            local ppid = 0
            local added2 = false
            if coin2 > 0 then --上上级奖励
                LOG_DEBUG('AddSuperiorRewards addCoinByRate2 :', coin2)
                local sql = string.format("select * from d_user_tree where descendant_id=%d and ancestor_h=2 limit 1", uid)
                local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
                if #rs > 0 and nil ~= rs[1].ancestor_id then
                    ppid = rs[1].ancestor_id
                    local ppInfo = player_tool.getPlayerInfo(ppid)
                    if nil == ppInfo.stopregrebat or tonumber(ppInfo.stopregrebat) == 0 then
                        added2 = true
                        addCoinByRate(ppid, coin2, rate2, actType, title, uid)
                    end
                end
            end
            LOG_DEBUG('AddSuperiorRewards: coin1 :', coin1, ' coin2:', coin2, ' added1:', added1, ' added2:',added2, ' parentuid:',parentuid)
            if coin1 > 0 or coin2 > 0 then
                local rechargeCoin = 0
                local bettimes = 1
                if actType == PDEFINE.TYPE.SOURCE.BUY then
                    rechargeCoin = coin
                    bettimes = 0
                    coin = 0
                end
                
                if actType == PDEFINE.TYPE.SOURCE.REG then
                    bettimes = 0
                    coin = 0
                end
                local begintime = calRoundBeginTime()
                if coin1 > 0 and added1 then
                    local cacheKey = 'first_comm:' .. parentuid
                    local geted = do_redis({"get", cacheKey})
                    geted = tonumber(geted or 0)
                    local sqlFirst = string.format( "select count(1) as t from d_commission where parentid=%d and coin1>0", parentuid)
                    local rst = skynet.call(".mysqlpool", "lua", "execute", sqlFirst)
                    if #rst > 0 and rst[1].t == 0 and geted == 0 then
                        do_redis({"setex", cacheKey, 1, 3600})
                        triggerSendMail(parentuid, PDEFINE.MAIL_TYPE.FIRSTCOMMISSION)
                    end
                    local sql = string.format("insert into d_commission(uid, betcoin, rechargecoin, bettimes, parentid, pparentid, coin1, coin2, create_time,type,datetime,gameid,issue)"
                                                .." values(%d, %.2f, %.2f, %d, %d, %d, %.2f, %.2f, %d, %d, %d,%d,'%s')",
                                uid, coin, rechargeCoin, bettimes, parentuid, 0, coin1, 0, os.time(), actType, begintime, gameid, issue)
                    do_mysql_queue(sql)
                    do_redis({"hincrbyfloat", PDEFINE_REDISKEY.LOBBY.INVITE_USER .. parentuid, 'totalbonus', coin1})
                    do_redis({"hincrbyfloat", PDEFINE_REDISKEY.LOBBY.INVITE_USER .. parentuid, 'bonus_'..actType, coin1})
                end
                if coin2 > 0 and added2 then
                    local cacheKey = 'first_comm:' .. ppid
                    local geted = do_redis({"get", cacheKey})
                    geted = tonumber(geted or 0)
                    local sqlFirst = string.format( "select count(1) as t from d_commission where pparentid=%d and coin2>0", ppid)
                    local rst = skynet.call(".mysqlpool", "lua", "execute", sqlFirst)
                    if #rst > 0 and rst[1].t == 0 and geted == 0 then
                        do_redis({"setex", cacheKey, 1, 3600})
                        triggerSendMail(ppid, PDEFINE.MAIL_TYPE.FIRSTCOMMISSION)
                    end
                    local sql = string.format("insert into d_commission(uid, betcoin, rechargecoin, bettimes, parentid, pparentid, coin1, coin2, create_time,type,datetime,gameid,issue)"
                                                .." values(%d, %.2f, %.2f, %d, %d, %d, %.2f, %.2f, %d, %d, %d, %d,'%s')",
                                uid, coin, rechargeCoin, bettimes, 0, ppid, 0, coin2, os.time(), actType, begintime,gameid, issue)
                    do_mysql_queue(sql)
                    -- do_redis({"hincrby", PDEFINE_REDISKEY.LOBBY.INVITE_USER .. ppid, 'totalbonus', coin1})
                end
            end
        else
            LOG_INFO('userkYCED: cfg is nil')
        end
    end
end

--发送vip 周/月bonus
function CMD.vipBonus(uid, coin, rate, actType)
    local vip = getUserAttrRedis(uid, "svip")
    --改成手动领取
    --local title = 'VIP'..vip ..',彩金:'..coin
    --addCoinByRate(uid, coin, rate, actType, title)
    local rediskey = (PDEFINE.REDISKEY.VIP.periodbonus)..actType..':'..uid
    local data = {
        vip = tonumber(vip) or 1,
        coin = coin,
        rate = rate,
        actType = actType,
        status = 1,
    }
    do_redis({"set", rediskey, cjson.encode(data), 86400*30})

    return PDEFINE.RET.SUCCESS
end

-- 凭借订单备注
local function genOrderRemark(shopitem, actor)
    local remark = ''
    if nil == shopitem then
        return remark
    end
    if shopitem.category == 1 then --线上订单
        local channelSql = string.format("select id,otherid from s_pay_cfg_channel where id=%d", shopitem.channelid)
        local ret = skynet.call(".mysqlpool", "lua", "execute", channelSql)
        local channel = ret[1]
        remark = '操作人:System,第3方:'
        if channel ~= nil then
            local sql = string.format("select id,title from s_pay_cfg_other where id=%d", channel.otherid)
            local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
            if #rs > 0 then
                remark = remark .. rs[1].title
            end
        end
    else
        local channelSql = string.format("select id,title from s_pay_bank where id=%d", shopitem.channelid)
        local ret = skynet.call(".mysqlpool", "lua", "execute", channelSql)
        if string.len(actor) > 0 then
            remark = '操作人:'..actor..','
        end
        if #ret > 0 then
            remark = remark .. '支付通道:' .. ret[1].title
        end
    end
    if shopitem.status == 3 or shopitem.status == 2 then
        remark = remark .. ' 备注:' .. shopitem.memo
    end
    return remark
end

local function triggerMail(uid, shopitem, totalcoin)
    local isfirst = 1 --首次充值
    local sqlFirst = string.format( "select count(1) as t from d_user_recharge where uid=%d and status in (2,3)", uid)
    local rst = skynet.call(".mysqlpool", "lua", "execute", sqlFirst)
    if #rst > 0 and rst[1].t > 0 then
        isfirst = 0
    end
    if isfirst == 1 then
        triggerSendMail(uid, PDEFINE.MAIL_TYPE.FIRSTRECHARGE) --首次充值到账
    else
        if shopitem.groupid == 4 then --线上支付成功
            triggerSendMail(uid, PDEFINE.MAIL_TYPE.SHOP, totalcoin)
        end
    end
    return isfirst
end

--订单到账异步回调处理
function CMD.orderAsynCallback(orderid, agentno, actor)
    local sql = string.format("select * from d_user_recharge where orderid='%s' limit 1", orderid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs == 0 then
        LOG_ERROR(" pay.orderAsynCallback 订单号找不到记录:", orderid)
        return PDEFINE.RET.ERROR.ORDER_PAID_ORDER_NOT_FOUND
    end
    local shopitem = rs[1]
    if shopitem.status == 2 or shopitem.status == 3 then
        LOG_ERROR(string.format("The same orderid %s  verify again.", orderid))
        return PDEFINE.RET.SUCCESS --已经支付成功的订单
    end
    local uid = shopitem.uid

    local sendcoin = 0
    local sendArr = {0, 0, 0} --赠送的金币分到不同的钱包
    if nil ~= shopitem.discoin and tonumber(shopitem.discoin) > 0 then --直接赠送固定额度
        sendArr  = decodeRate(shopitem.rate)
        sendcoin = tonumber(shopitem.discoin)
    end
    if nil ~= shopitem.disrate and tonumber(shopitem.disrate) > 0 then --按比例赠送
        sendcoin = math.round_coin(tonumber(shopitem.disrate) * shopitem.count) --赠送的金币数
        sendArr  = decodeRate(shopitem.rate)
        for idx, rate in pairs(sendArr) do
            sendArr[idx] = math.round_coin(sendcoin * rate)
        end
    end
    LOG_DEBUG('orderid:', orderid, ' count:', shopitem.count, ' sendarr:', sendArr)

    local totalcoin = shopitem.count --金币
    local cointype = PDEFINE.ALTERCOINTAG.SHOP_RECHARGE
    local gameid = PDEFINE.GAME_TYPE.SPECIAL.STORE_BUY

    local transferAmount = 0 --需要从cash balance中转到cash bonus中的金额
    -- local playerInfo = CMD.getPlayerInfo(uid)
    -- if playerInfo.ispayer == 0 then --未充值的新会员 第1次充值的时候
    --     local cashblanace = 0 --现金余额
    --     local gamedraw = playerInfo.gamedraw or 0
    --     local dcoin = gamedraw
    --     if dcoin < 0 then
    --         dcoin = 0 --可提现金额
    --     end
    --     if dcoin > playerInfo.coin then
    --         dcoin = playerInfo.coin --可提现金额 不能超过现金余额
    --     end
    --     cashblanace = playerInfo.coin - dcoin --不可提现金余额
    --     if totalcoin < cashblanace then
    --         transferAmount = cashblanace
    --     end
    -- end
    --订单到账
    local remark = genOrderRemark(shopitem, actor)
    local code,before_coin,after_coin = player_tool.funcAddCoin(uid, totalcoin, remark, cointype, gameid, PDEFINE.POOL_TYPE.none, true, nil)
    if code ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("apiAddCoin err.code", code, " uid", uid, 'cointype', cointype)
        return PDEFINE.RET.ERROR.CALL_FAIL
    end

    local nowtime = os.time()
    local cachekey = 'd_user:' .. uid
    local agent = CMD.getAgent(uid)
    remark = remark .. ',赠送比例:'..shopitem.rate
    if stopDiscount(uid, PDEFINE.DISCOUNTLABEL.RECHARGE) then
        remark = remark .. ',停止充值优惠'
        sendcoin = 0
        sendArr = {0, 0, 0}
    end
    local runFlag = true
    if agent then
        local notify = {
            coin = after_coin,
            count = totalcoin,
        }
        local ok = pcall(cluster.call, agent.server, agent.address, "clusterModuleCall", "player", "addCoinByRate", uid, sendcoin, sendArr, PDEFINE.TYPE.SOURCE.BUY_SELF, nil, notify, transferAmount, remark)
        if ok then
            runFlag = false
        end
    end
    if runFlag then
        local coin = tonumber(sendArr[1]) --金币
        if coin > 0 then
            code,before_coin,after_coin = player_tool.funcAddCoin(uid, coin, remark, PDEFINE.ALTERCOINTAG.RECHARGE_SELF_BONUS, gameid, PDEFINE.POOL_TYPE.none, nil, nil)
            addBonusLog(orderid, 'recharge_realcash', coin, nowtime, PDEFINE.TYPE.SOURCE.BUY_SELF, uid, 0, true)
        end
        local orderid = genOrderId('bonus')
        local drawcoin = tonumber(sendArr[2] or 0)
        if drawcoin > 0 then --draw coin
            code,before_coin,after_coin = player_tool.funcAddCoin(uid, drawcoin, "订单赠送可提", PDEFINE.ALTERCOINTAG.RECHARGE_SELF_BONUS, gameid, PDEFINE.POOL_TYPE.none, nil, nil)

            local sql1 = string.format("update d_user set gamedraw=gamedraw+%.2f where uid=%d", drawcoin, uid)
            LOG_DEBUG('orderAsynCallback draw uid:', uid, ' sql:', sql1)
    
            do_mysql_queue(sql1)
            do_redis({"hincrbyfloat", cachekey, 'gamedraw', drawcoin})
    
            local sql = string.format("insert into d_log_senddraw(orderid,title,coin,create_time,category,uid) values ('%s','%s', %.2f, %d, %d, %d)", 
            orderid, 'recharge', drawcoin, nowtime, PDEFINE.TYPE.SOURCE.BUY_SELF, uid)
            do_mysql_queue(sql)
        end
        local bonus = tonumber(sendArr[3] or 0)
        if bonus > 0 then --bonus coin
            local sql1 = string.format("update d_user set cashbonus=cashbonus+%.2f where uid=%d", bonus, uid)
            LOG_DEBUG('orderAsynCallback bonus uid:', bonus, ' sql:', sql1)
            
            do_mysql_queue(sql1)
            do_redis({"hincrbyfloat", cachekey, 'cashbonus', bonus})
            local title = '金额:' .. totalcoin
            addBonusLog(orderid, title, bonus, nowtime, PDEFINE.TYPE.SOURCE.BUY_SELF, uid)
        end
        if transferAmount > 0 then --现金余额转去bonus
            local cointype = PDEFINE.ALTERCOINTAG.FREE_WINNS2BONUS
            local gameid = PDEFINE.GAME_TYPE.SPECIAL.FREE_WINNS2BONUS
            -- cash balance = total balance - withdraw balance
            code,before_coin,after_coin = player_tool.funcAddCoin(uid, -transferAmount, "转移到cashbonus", cointype, gameid, PDEFINE.POOL_TYPE.none, nil, nil)
            if code == PDEFINE.RET.SUCCESS then
                --加cash bonus
                local sql1 = string.format("update d_user set cashbonus=cashbonus+%.2f where uid=%d", transferAmount, uid)
                LOG_DEBUG('orderAsynCallback bonus uid:', transferAmount, ' sql:', sql1)
                do_mysql_queue(sql1)
                do_redis({"hincrbyfloat", cachekey, 'cashbonus', transferAmount})
                addBonusLog(orderid, 'Free Winnings transfer', transferAmount, nowtime, PDEFINE.TYPE.SOURCE.FREE_WINNING, uid)
            else
                LOG_ERROR('转移到cashbonus uid:',uid, ' coin:', transferAmount)
            end
        end

        local updateUserSql = string.format('update d_user set ispayer=1 where uid=%d', uid)
        LOG_DEBUG('updateUserSql :', updateUserSql, ' cachekey:', cachekey)

        do_mysql_queue(updateUserSql)
        do_redis({ "hset", "d_user:" .. uid, "ispayer", 1}, uid)
    end
    
    local isfirst  = triggerMail(uid, shopitem, totalcoin)
    local backcoin = sendcoin + totalcoin
    local update_sql = string.format("update d_user_recharge set status=2, sendcoin=%.2f,backcoin=%.2f,pay_time=%d,isfirst=%d where orderid='%s'", sendcoin, backcoin,nowtime, isfirst, orderid)
    skynet.call(".mysqlpool", "lua", "execute", update_sql)

    if APP == PDEFINE.APPID.RUMMYVIP then
        local cfg = skynet.call(".configmgr", "lua", "getBatchItems",{'check_recharge','check_discount'})
        if cfg then
            local chrechargerate  = tonumber(cfg['check_recharge'] or 0) --充值稽核倍数
            local chdiscountrate  = tonumber(cfg['check_discount'] or 0) --优惠稽核倍数
            if chrechargerate > 0 or chdiscountrate > 0 then
                local chrechargecoin = math.floor(totalcoin*chrechargerate)
                local cksendcoin = math.floor(sendcoin*chdiscountrate)
                local sql = string.format("update d_user set ckrechargecoin=ckrechargecoin+%f,cksendcoin=cksendcoin+%f where uid=%d", chrechargecoin, cksendcoin, uid)
                local res = skynet.call(".mysqlpool", "lua", "execute", sql)
                if res then
                    do_redis({"hincrby", "d_user:"..uid, 'ckrechargecoin', chrechargecoin}, uid)
                    do_redis({"hincrby", "d_user:"..uid, 'cksendcoin', cksendcoin}, uid)
                end
            end
        end
    end

    --配合推appsfly，先丢队列中
    local res = {uid = uid, coin = totalcoin, orderid=orderid}
    do_redis({"lpush", PDEFINE.REDISKEY.QUEUE.PAY_SUCC, cjson.encode(res)})

    skynet.timeout(120, function ()
        CMD.AddSuperiorRewards(uid, PDEFINE.TYPE.SOURCE.BUY, shopitem.count, 1, 0, '', 1) --下级充值需要给上级返利
        local data = skynet.call(".configmgr", "lua", "getRebateCfg")
        if data and data.invite ~= nil and data.invite.rtype~=nil and tonumber(data.invite.rtype) == 1 then --充值的时候返注册奖励
            -- 如果之前绑定上级码的时候未给返佣给上级，这里再次触发一下
            local regSql = string.format("select count(*) as t from d_commission where uid=%d and type=1", uid)
            local rst = skynet.call(".mysqlpool", "lua", "execute", regSql)
            LOG_DEBUG('支付到账', uid, ' 是否需要给上级返佣注册的:', rst)
            if nil ~= rst and nil~=rst[1] and rst[1].t == 0 then
                LOG_DEBUG('orderAsynCallback before AddSuperiorRewards uid:', uid)
                CMD.AddSuperiorRewards(uid, PDEFINE.TYPE.SOURCE.REG, shopitem.count, data.invite.rtype,0, '', 1)
            end
        end
    end)
    
    local flag = true --是否要离线执行的标志
    if agent ~= nil then
        -- 更新bonus 任务
        local updateMainObjs = {
            {kind=PDEFINE.MAIN_TASK.KIND.Pay, count=shopitem.count},
        }
        local ok, retok = pcall(cluster.call, agent.server, agent.address, "packTaskAndVIP", updateMainObjs , shopitem.count, totalcoin)
        if ok and retok then
            flag = false
            syncWallet(uid)
        end
    end
    if flag then
        --用户离线状态
        OFFLINE_CMD(uid, "upgradeVIP", {shopitem.count}, true)
        OFFLINE_CMD(uid, "doMaintask", {PDEFINE.MAIN_TASK.KIND.Pay, shopitem.count}, true)
    end
    return code
end

--更新玩家信息
function CMD.ApiUserInfo(uid)
	local retobj = { c = PDEFINE.NOTIFY.MUST_RESTART, code = PDEFINE.RET.SUCCESS}
	reloadUserInfo(uid)
	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--更新玩家开关(赠送金币、兑换码、举报)
function CMD.ApiSetUserSwitch(uid, rtype, switch)
	local agent = world_channel[uid]
	if nil ~= agent then
		--在线
        LOG_DEBUG("ApiSetUserSwitch online uid:", uid, ' rtype:', rtype, ' switch:', switch)
        pcall(cluster.send, agent.server, agent.address, "setSwitch", rtype, switch)
	else
		--不在线
        LOG_DEBUG("ApiSetUserSwitch offline uid:", uid, ' rtype:', rtype, ' switch:', switch)
		OFFLINE_CMD(uid, "setSwitch", {rtype, switch}, true)
	end
	return PDEFINE.RET.SUCCESS
end

function CMD.ApiReloadVipInfo(uid)
    LOG_DEBUG("ApiReloadVipInfo uid:", uid)
	local agent = world_channel[uid]
	if nil ~= agent then
        LOG_DEBUG("ApiReloadVipInfo online uid:", uid, ' reloadVipInfo:')
        cluster.call(agent.server, agent.address, "clusterModuleCall", "player", "reloadVipInfo", uid)
	else
		OFFLINE_CMD(uid, "reloadVipInfo", {uid}, true)
	end
	return PDEFINE.RET.SUCCESS
end

--把uid从排行版中隐藏
function CMD.ApiHideUser(uid)
	local retobj = { c = PDEFINE.NOTIFY.MUST_RESTART, code = PDEFINE.RET.SUCCESS}

	if "" == uid then
		do_redis({"del","noranklist"})
	else
		do_redis({"set","noranklist", uid})
	end

	return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--刷新fbtoken
function CMD.ApiRefreshfbtoken(uid, token, expire)
    local agent = world_channel[uid]
	if nil ~= agent then
        pcall(cluster.send, agent.server, agent.address, "clusterModuleCall", "player", "upFBAccessToken", uid, token, expire)
	else
        local sql = string.format("update d_user set fbtoken=%s,fbendtime=%d where id=%d", token, expire, uid)
        skynet.call(".mysqlpool", "lua", "execute", sql)
        do_redis({"hset", "data_change:" .. uid, 'd_user', 1})
    end
    return true
end

-- 全服推系统公告
function CMD.pushAllNotice(message, svipArr)
    if not loginshutdownFlag then
        local retobj = { c = PDEFINE.NOTIFY.PUBLIC_NOTICE, code = PDEFINE.RET.SUCCESS, message = message}
        LOG_DEBUG("pushAllNotice retobj:", retobj, ' svipArr:', svipArr)
        for _,cluster_info in pairs(world_channel) do
            pcall(cluster.call, cluster_info.server, cluster_info.address, "sendNoticeToClient", cjson.encode(retobj), svipArr) --广播玩家
        end
	end
end

--全服推消息
function CMD.pushAll2Client(retobj)
    if not loginshutdownFlag then
        local msg = cjson.encode(retobj)
        for _,cluster_info in pairs(world_channel) do
            pcall(cluster.call, cluster_info.server, cluster_info.address, "sendToClient", msg) --广播玩家
        end
	end
end

--执行全服推送
--@param msg 消息内容
--@param type 1系统后台推送 2游戏本地触发 5公告
--@param count
--@param msgid
--@param playername
local function sendAllServerNoticeDo( msg,type,count,msgid, playername, extra_info)
    if not loginshutdownFlag then
        local t = PDEFINE.NOTICE_TYPE.USER --玩家
        if "" == playername or nil == playername then
            t = PDEFINE.NOTICE_TYPE.SYS --系统
            -- 系统暂时不指定昵称，因为客户端语种有可能不统一
            playername = ''
        end
        if type == 5 then
            t = 3 --系统公告
            type = 3 --level也要改掉
        end

        for language,msg_v in pairs(msg) do
            local retobj = { c = PDEFINE.NOTIFY.MARQUEE_ALL, code = PDEFINE.RET.SUCCESS, type=t, notices = {count = count, msg = msg_v, level = type, type=t, playername=playername,extra_info=extra_info}}
            local servertable = skynet.call(".servermgr", "lua", "getServerByTag", "node")
            LOG_DEBUG("CMD.sendAllServerNotice servers:", servertable, retobj)
            for _,server in pairs(servertable) do
                pcall(cluster.call, server.name, server.serverinfo.address, "brodcast", nil, "sendToClientCheckLan", language, cjson.encode(retobj))
            end
        end
    end
end

--timout的闭包实现 outtime*0.01S之后执行func
--@param outtime 
--@param func执行的函数
--@param other 参数
--@return 返回停止这个定时操作的函数
local function timeout(outtime, func, msg, type, count, msgid, playername,extra_info)
    local function t()
        if func then
            func(msg, type, count, msgid, playername,extra_info)
        end
    end
    skynet.timeout(outtime, t)
    return function() func = nil end
end

--全服推送
--@param msg 消息内容
--@param type 1系统后台推送 2游戏本地触发
--@param count
--@param msgid
--@param playername
--@param extra_info 额外信息
function CMD.sendAllServerNotice(msg, type, count, msgid, playername, delay_sec, extra_info)
    if msg == nil then
        LOG_ERROR("sendAllServerNotice msg isnil")
        return
    end
	if not loginshutdownFlag then
        if delay_sec == nil then
            delay_sec = 5 --默认延迟推送时间
        end
        if delay_sec == 0 then
            sendAllServerNoticeDo(msg, type, count, msgid, playername, extra_info)
        else
            LOG_DEBUG("sendAllServerNotice timeout delay_sec:", delay_sec, os.time())
            timeout(delay_sec*100, sendAllServerNoticeDo, msg, type, count, msgid, playername,extra_info)
        end
	end
end

-- 给所有玩家推送bigwin大奖通知
function CMD.sendBigWinNotice(uid, msg, type, count, msgid, playername, delay_sec, gameid, coin)
    timeout(1000, presentJackpot, uid, gameid, coin)
    CMD.sendAllServerNotice(msg, type, count, msgid, playername, delay_sec)
end

--全服同步排位赛状态变化给客户端
function CMD.syncLeagueState(isopen, stopTime)
    for _,cluster_info in pairs(world_channel) do
		pcall(cluster.send, cluster_info.server, cluster_info.address, "notifyLeagueState", isopen, stopTime) --广播玩家
	end
end

--全服推送聊天消息
--msg消息内容
--游戏本地触发
function CMD.sendAllServerChat(msg, uid, playername, time)
	CMD.sendAllServerNotice(msg,2, 2, 0, hidePlayername(playername))

	local retobj = { c = PDEFINE.NOTIFY.NOTIFY_CAHT_ALL, code = PDEFINE.RET.SUCCESS, notices = {msg=msg, playername=playername, uid=uid, type=PDEFINE.NOTICE_TYPE.USER, time=time}}
	for _,cluster_info in pairs(world_channel) do
		LOG_INFO("推送消息:",retobj)
		pcall(cluster.call, cluster_info.server, cluster_info.address, "sendToClient", cjson.encode(retobj)) --广播玩家
	end
end

-- 赠送礼物时，推送走马灯
function CMD.sendGiftNotice(sendUid, recvUid, num, giftName, giftName_al)
    local sendName = getUserAttrRedis(sendUid, "playername")
    if not sendName or sendName == "" then
        return
    end
    -- 被赠送人如果没有找到，则尝试找找机器人
    local recvName = getUserAttrRedis(recvUid, "playername")
    if not recvName then
        local ok, aiUsers = pcall(cluster.call, "ai", ".aiuser", "getAiInfoByUid", {recvUid})
        if not ok or table.empty(aiUsers) or not aiUsers[recvUid] then
            return
        end
        recvName = aiUsers[recvUid].playername
    end
    local type = 5  -- 系统公告
    local count = 1  -- 循环次数
    local msgid = 0  -- 不需要msgid
    local msg = {
        [PDEFINE.USER_LANGUAGE.Arabic] = string.format("!ونال تصفيق الجميع %dواحد%s  %s أعطى %s", num, giftName_al, hidePlayername(recvName), hidePlayername(sendName)),
        [PDEFINE.USER_LANGUAGE.English] = string.format("%s send %d %s to %s,let's clap!", hidePlayername(sendName), num, giftName, hidePlayername(recvName))
    }
    CMD.sendAllServerNotice(msg, type, count, msgid, nil)
end

-- 赢取金币时，推送走马灯
function CMD.winCoinNotice(uid, gameid, num)
    LOG_DEBUG("winCoinNotice: ", "uid: ", uid, "gameid: ", gameid, "num: ", num)
    local playername = do_redis({"hget", "d_user:"..uid, "playername"}, uid)
    if not playername or playername == "" then
        local ok, aiUsers = pcall(cluster.call, "ai", ".aiuser", "getAiInfoByUid", {uid})
        if ok and aiUsers[uid] then
            playername = aiUsers[uid].playername
        end
        if not playername or playername == "" then
            return
        end
    end
    local gameName = nil
    local gameName_al = nil
    if PDEFINE_GAME.GAME_NAME[gameid] then
        gameName = PDEFINE_GAME.GAME_NAME[gameid].en
        gameName_al = PDEFINE_GAME.GAME_NAME[gameid].al
    end
    if not gameName or not gameName_al then
        return
    end
    local type = 5  -- 系统公告
    local count = 1  -- 循环次数
    local msgid = 0  -- 不需要msgid
    local msg = {
        -- [PDEFINE.USER_LANGUAGE.Arabic] = string.format("%sفي لعبة %s فزت%d عملة ذهبية .تهانينا!", hidePlayername(playername), gameName_al, num),
        [PDEFINE.USER_LANGUAGE.Arabic] = '',
        [PDEFINE.USER_LANGUAGE.English] = string.format("%s won %d coins in %s, congratulations!", hidePlayername(playername), num, gameName)
    }
    CMD.sendAllServerNotice(msg, type, count, msgid, nil)
end

-- vip等级提升时，推送走马灯
function CMD.vipLevelUpNotice(uid, level)
    local playername = do_redis({"hget", "d_user:"..uid, "playername"},uid)
    if not playername or playername == "" then
        return
    end
    local msg = "I nickname the player who made the gift. Give xxxx the nickname of the player who received the gift. And everyone applauded!"
    local type = 5  -- 系统公告
    local count = 1  -- 循环次数
    local msgid = 0  -- 不需要msgid
    msg = {
        [PDEFINE.USER_LANGUAGE.Arabic] = string.format("%sسيتم ترقية مستوى VIP إلى المستوى %d وقم بتنشيط المزيد من مزايا VIP المتقدمة!", hidePlayername(playername), level),
        [PDEFINE.USER_LANGUAGE.English] = string.format("%s upgrade the VIP level to level %d and activate more advanced VIP features!", hidePlayername(playername), level)
    }
    CMD.sendAllServerNotice(msg, type, count, msgid, nil)
end

-- 在沙龙房提升等级，推送走马灯
function CMD.levelUpInPrivateNotice(msg, extra_info)
    local type = 5  -- 系统公告
    local count = 1  -- 循环次数
    local msgid = 0  -- 不需要msgid
    CMD.sendAllServerNotice(msg, type, count, msgid, nil, nil, extra_info)
end

--bigbang 子游戏状态维护，整体广播
function CMD.ApiSendAllGameChange(msg, uidarr)
	local retobj = { c = PDEFINE.NOTIFY.NOTIFY_GAMELIST_INFO, code = PDEFINE.RET.SUCCESS, gamelist = msg}
    local servertable = skynet.call(".servermgr", "lua", "getServerByTag", "node")
    for _,server in pairs(servertable) do
        -- pcall(cluster.send, server.name, server.serverinfo.address, "brodcast", uidarr, "changeGamelist", retobj)
        pcall(cluster.send, server.name, server.serverinfo.address, "brodcast", uidarr, "sendToClient", cjson.encode(retobj))
    end
end

-- 重置玩家某封邮件的状态
function CMD.resetUserMail(uid, mailid, offline)
    local agent = world_channel[uid]
    if nil ~= agent and not offline then
        cluster.call(agent.server, agent.address, "clusterModuleCall", "mailbox", "resetMail", uid, mailid)
    else
        OFFLINE_CMD(uid, "resetMail", {uid, mailid}, true)
    end
    return true
end

--当前用户给其他玩家发送邮件
function CMD.addUsersMail(uid, mail, offline)
    local agent = world_channel[uid]
    LOG_DEBUG("userCenter addUsersMail uid:", uid, " mail:", mail, ' offline:', offline, ' agent:', agent)
    -- 如果offline，说明这个用户已经不在了，直接离线发送
	if nil ~= agent and not offline then
        --在线
        LOG_DEBUG("在线发送邮件：uid:", uid)
        cluster.call(agent.server, agent.address, "clusterModuleCall", "mailbox", "addMail", uid, mail)
	else
        --不在线
        LOG_DEBUG("离线发送邮件：uid:", uid)
        OFFLINE_CMD(uid, "addMail", {uid, cjson.encode(mail)}, true)
    end
    return true
end

-- 添加赠送日志
function CMD.addSendCoinLog(uid, coin, act)
    local agent = world_channel[uid]
    -- 如果offline，说明这个用户已经不在了，直接离线发送
	if nil ~= agent then
        --在线
        cluster.call(agent.server, agent.address, "clusterModuleCall", "player", "addSendCoinLog", uid, coin, act)
	else
        --不在线
        local level, diamond, svip = 0, 0, 0
        local sql = string.format("select * from d_user where uid = %d ",uid)
		local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
		if #rs > 0 then
            level = rs[1].level or 1
            diamond = rs[1].diamond or 0
            svip = rs[1].svip or 0
		end
        local sql = string.format("insert into s_send_coin(uid,coin,create_time,act, level, scale, diamond,svip) values (%d, %2.f, %d, '%s', %d, %2.f, %d, %d)", uid, coin, os.time(), act, level, 1, diamond, svip)
        do_mysql_queue(sql)
    end
    return true
end

function CMD.addInviteCount(uid)
    local agent = world_channel[uid]
    -- 如果offline，说明这个用户已经不在了，直接离线发送
	if nil ~= agent then
        --在线
        pcall(cluster.call, agent.server, agent.address, "addInviteCount", uid)
	else
        --不在线
        local sql = string.format("update d_user set invitednum=invitednum+1 where uid=%d", uid)
		skynet.call(".mysqlpool", "lua", "execute", sql)
        do_redis({"hincrby", "d_user:"..uid, 'invitednum', 1}, uid)
        local invitednum = do_redis({"hget", "d_user:"..uid, 'invitednum'},uid)
        if tonumber(invitednum) == 1 then
            triggerSendMail(uid, PDEFINE.MAIL_TYPE.FIRSTAGENT)
        end

        do_redis({"incrby", PDEFINE_REDISKEY.OTHER.invite_count_offline..uid, 1})
    end
    return PDEFINE.RET.SUCCESS
end

--暂停返佣
function CMD.ApiSuspendagent(uid)
    local agent = world_channel[uid]
	if nil ~= agent then
        --在线
        pcall(cluster.call, agent.server, agent.address, "suspendAgent", uid)
	else
        local sql = string.format("select uid,suspendagent from d_user where uid = %d ",uid)
		local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs > 0 then
            local tag = 1
            if nil ~=rs[1].suspendagent and rs[1].suspendagent > 0 then
                tag = 0
            end
            local sql = string.format("update d_user set suspendagent=%d where uid=%d", tag, uid)
            skynet.call(".mysqlpool", "lua", "execute", sql)
            do_redis({"hset", "d_user:"..uid, 'suspendagent', tag}, uid)
        end
    end
    return true
end

function CMD.wealthRewards(uid, mail)
    local agent = world_channel[uid]
    if nil ~= agent then
        cluster.call(agent.server, agent.address, "clusterDcCall", "user_dc", "setvalue", uid, "avatarframe", PDEFINE.SKIN.RANKDIAMOND.AVATAR.img)
    end
    CMD.addUsersMail(uid, mail)
end

--后台发邮件
function CMD.systemMail(mail_message)
    LOG_DEBUG("systemMail mail_message:", mail_message)
    local uids = mail_message.uids
    local msg = mail_message.msg
    if not uids or uids == "" then --全服发放邮件
        local bonus_type = 0
        if mail_message.attach[1] then
            bonus_type = mail_message.attach[1].type
        end
        local mailid = player_tool.addSysMail({
            title = mail_message.title,
            msg = msg,
            attach = cjson.encode(mail_message.attach),
            timestamp = os.time(),
            stype = mail_message.type,
            bonus_type = bonus_type,
            title_al = mail_message.title_al or "",
            msg_al = mail_message.msg_al or "",
            svip = mail_message.svip or "",
            rate = mail_message.rate or "",
            remark = mail_message.remark or "",
            creator = mail_message.creator or "" --发件人
        })
        if not mailid then
            return PDEFINE.RET.ERROR.DB_FAIL
        end

        local delay = 1
        for uid, agent in pairs(world_channel) do
            local ok = pcall(cluster.send, agent.server, agent.address, 'notifySystemMail', delay)
            if not ok then
                LOG_ERROR("notifySystemMail error", uid, ok)
            end
            delay = delay + 2
        end
        LOG_INFO("send system mail succ, mailid:", mailid)
    else
        local uidList = string.split_to_number(uids, ",")
        LOG_DEBUG("MAIL uidList:", uidList)
        for _,uid in pairs(uidList) do
            local mailid = genMailId()
            local mailobj = {
                mailid = mailid,
                uid = uid,
                fromuid = math.floor(mail_message.fromuid or 0),
                msg  = msg,
                type = mail_message.type,
                title = mail_message.title,
                attach = cjson.encode(mail_message.attach),
                sendtime = os.time(),
                received = 0,
                hasread = 0,
                sysMailID= 0,
                svip = mail_message.svip or "",
                rate = mail_message.rate or "",
                remark = mail_message.remark or "",
                creator = mail_message.creator or ""
            }
            CMD.addUsersMail(uid, mailobj)
        end
    end
    return PDEFINE.RET.SUCCESS
end

function CMD.start()
	skynet.fork(gameLoop)
end

--注册用户 暂时只支持单条  线上以后有需求再改成支持批量
function CMD.registeruser( jsondata )
    do_redis({"hset", "data_change:" .. jsondata.uid, 'd_mail', 1})
    LOG_DEBUG("registeruser ", jsondata)
    local sendcoin = 0 --send coin
    local usericon = jsondata.usericon or "" --没有头像就采用系统默认的
    local invit_uid = jsondata.invit_uid or 0 --邀请人
    local appid = jsondata.appid or 0 --渠道包id
    local isbindfb = jsondata.isbindfb or 0 
    local isbindgg = jsondata.isbindgg or 0 
    local kouuid = jsondata.kouuid or ""
    local platform = jsondata.platform or 0
    local from_channel = jsondata.from_channel or 0 
    local fbicon = jsondata.fbicon or ""
    local device = jsondata.device or '' --设备型号
    local ddid   = jsondata.client_uuid or ''
    local ip = jsondata.ip or ''
    local code = jsondata.code or '' --邀请码 
    if isempty(code) then
        code = jsondata.uid
    end
    local adchannel = 'google-play'
    local fgamelist = table.concat(PDEFINE_GAME.F_GAME_LIST,',')
    if platform == 2 then
        adchannel = 'iOS'
    end
    if from_channel == 13 then
        adchannel = 'huawei'
    end
    local avatarframe = PDEFINE.SKIN.DEFAULT.AVATAR.img
    local chatskin = PDEFINE.SKIN.DEFAULT.CHAT.img
    local tableskin = PDEFINE.SKIN.DEFAULT.TABLE.img
    local pokerskin = PDEFINE.SKIN.DEFAULT.POKER.img
    local frontskin = PDEFINE.SKIN.DEFAULT.FRONT.img
    local emojiskin = PDEFINE.SKIN.DEFAULT.EMOJI.img
    local faceskin = PDEFINE.SKIN.DEFAULT.FACE.img
    
    -- 默认开启沙龙房
    local salonskin = PDEFINE.SKIN.DEFAULT.SALON.img

    local sql = string.format("insert into d_user( uid, coin, dcoin, usericon, create_time, playername, red_envelope,level,levelexp,invit_uid,code, appid, justreg,isbindfb, isbindgg, kouuid,create_platform,from_channel,adchannel,fgamelist,avatarframe,chatskin,tableskin,pokerskin,frontskin,emojiskin,faceskin,salonskin,fbicon,device,ddid,reg_ip) "..
                    "values (%d, %d, %d, '%s', %d, '%s', %0.4f, %d, %d, %d, '%s', %d, %d, %d, %d, '%s', %d, %d,'%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s','%s')", 
                    jsondata.uid, sendcoin, 0, usericon, os.time(), jsondata.pid, 0, 1, 0,invit_uid,code, appid, 1, isbindfb, isbindgg, kouuid, platform, from_channel, adchannel, fgamelist,avatarframe,chatskin,tableskin,pokerskin,frontskin,emojiskin,faceskin,salonskin,fbicon,device,ddid,ip)
    -- LOG_DEBUG("regsql:", sql)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    do_redis({"hset", "data_change:" .. jsondata.uid, 'd_user', 1}) --设置修改标志，node服强制从mysql拉取数据
    if platform == 1 then
        do_redis({"rpush", PDEFINE_REDISKEY.ADCHANNEL.ANDROID, jsondata.uid}) --将安卓注册uid推到队列中
    end
    local res = {uid = jsondata.uid, level = 0}
    do_redis({"lpush", PDEFINE.REDISKEY.QUEUE.VIP_UPGRADE, cjson.encode(res)}) --去订阅vip0的主题

    LOG_DEBUG("registeruser end rs:", rs)
end

function CMD.getGameDraw(uid)
    local coin = 0
    coin  = do_redis({"hget", "d_user:" .. uid, "gamedraw"}, uid)
    if nil ~= coin then
        coin = tonumber(coin)
    end

    if nil == coin then
        local sql = "select gamedraw from d_user where uid=" .. uid
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs > 0 then 
            coin = rs[1]['gamedraw']
        else
            print("can't find uid gamedraw:", uid)
        end
        if nil == coin then
            coin = 0
        end
    end
    return coin
end

function CMD.updateGameDrawInDraw(uid, alterCoin)
    local gamedraw = CMD.getGameDraw(uid)
    if (gamedraw + alterCoin) < 0 then
        alterCoin = -gamedraw
    end
    do_redis({"hincrbyfloat", 'd_user:'..uid, 'gamedraw', alterCoin})
    local sql = string.format("update d_user set gamedraw =gamedraw+ %.2f where uid = %d", alterCoin, uid)
    skynet.call(".mysqlpool", "lua", "execute", sql)
    return true
end

--先从本地获取，如果没有从redis中获取
function CMD.getUserCoin(uid)
    if nil == uid then
        print('userCenter getUserCoin uid is nil')
        return 0
    end
    local coin = user_coin_data[uid]
    if nil == coin then
        coin  = do_redis({"hget", "d_user:" .. uid, "coin"}, uid)
		if nil ~= coin then
			coin = tonumber(coin)
            user_coin_data[uid] = coin
		end
    end
    if nil == coin then
        local sql = "select coin from d_user where uid=" .. uid
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs > 0 then 
            coin = tonumber(rs[1]['coin'] or 0)
            user_coin_data[uid] = coin
        else
            print("can't find uid:", uid)
        end
        if nil == coin then
            coin = 0
        end
    end
    return coin
end

--离线修改玩家金币数据
function CMD.alterUserCoinOffLine( func, uid, altercoin, alterlog, type, issync, altercoin_id, gameid )
    --离线
    LOG_DEBUG("CMD.alterUserCoinOffLine uid:", uid, 
        "altercoin:", altercoin,
        "alterlog", alterlog, 
        "type:", type, 
        "issync:", issync, 
        "altercoin_id:", altercoin_id, 
        "gameid:", gameid
        )

    --检查玩家是否已经在线
    -- local cluster_info = CMD.getAgent(uid)
    -- if cluster_info ~= nil then
    --     LOG_ERROR("alterUserCoinOffLine player online")
    --     --已经在线了 不能从这里操作了

    --     ok,code,beforecoin,aftercoin = pcall(cluster.call, cluster_info.server, cluster_info.address,
    --                     "clusterModuleCall", "player", "calUserCoin", uid, altercoin, alterlog, type, issync, altercoin_id, gameid)
    --     if not ok or code ~= PDEFINE.RET.SUCCESS then
    --         LOG_ERROR("CMD.alterUserCoinOffLine calUserCoin user not found code:", code)
    --     end

    --     return code, beforecoin,aftercoin
    -- end

    local beforecoin = CMD.getUserCoin(uid)
    local aftercoin = Double_Add(beforecoin, altercoin)
    if aftercoin < 0 then
        aftercoin = 0
        LOG_ERROR("alterUserCoinOffLine player uid:", uid, ' beforecoin:', beforecoin ,' aftercoin: ', aftercoin)
        -- return PDEFINE.RET.COIN_NOT_ENOUGH
    end
    user_coin_data[uid]  = aftercoin
    local key = "d_user:"..uid
    do_redis({"hset", key, 'coin', aftercoin}, uid)

    local sql = "update d_user set coin="..aftercoin .. " where uid=" .. uid
    altercoin = math.abs(altercoin)
    if type == PDEFINE.ALTERCOINTAG.BET then --下注
        sql = "update d_user set coin="..aftercoin .. ", totalbet = totalbet + "..altercoin .." where uid=" .. uid
        -- do_redis({"hincrbyfloat", key, 'totalbet', altercoin})
        skynet.send(".usergamedraw", "lua", "updateDraw", uid, beforecoin, -altercoin)
        
    elseif type == PDEFINE.ALTERCOINTAG.WIN then --赢分
        sql = "update d_user set coin="..aftercoin .. ", totalwin = totalwin + "..altercoin .." where uid=" .. uid
    elseif type == PDEFINE.ALTERCOINTAG.SHOP_RECHARGE then --充值到账
        sql = "update d_user set coin="..aftercoin .. ", totalrecharge = totalrecharge + "..altercoin .." where uid=" .. uid
    elseif type == PDEFINE.ALTERCOINTAG.DRAW then --提分
        sql = "update d_user set coin="..aftercoin .. ", totaldraw = totaldraw + "..altercoin .." where uid=" .. uid
        skynet.send(".usergamedraw", "lua", "updateDraw", uid, beforecoin, -altercoin)
    elseif type == PDEFINE.ALTERCOINTAG.DRAWRETURN then --提现拒绝
        sql = "update d_user set coin="..aftercoin .. ", totaldraw = totaldraw - "..altercoin .." where uid=" .. uid
    end
    skynet.call(".dbsync", "lua", "sync", sql)

	LOG_DEBUG("user_coin_data["..uid.."] : " .. user_coin_data[uid]);

    return PDEFINE.RET.SUCCESS,beforecoin,aftercoin
end

--获取加载用户信息权限
--@param uid
--@param func = {iscluster = true, node = NODE_NAME, addr = skynet.self(), fuc_name="loaduser"}
--@param ...其他参数
--@return func的返回
function CMD.alterUserQueue( uid, func, ... )
    --TODO: MZH这里应该去控制user_dc.load(uid) 而不是控制登录事件和修改金币事件 但是考虑到修改量问题 先简单控制
    -- LOG_DEBUG("alterUserQueue uid:", uid, "func:", func, ...)
    local userqueue = queuemgr.getQueue(uid)
    local param = {func, ...}
    local ret
    userqueue(
        function()
            -- LOG_DEBUG("alterUserQueue queue func:", func, param)
            if func ~= nil then
                if func.iscluster then
                    ret = {pcall(cluster.call, func.node, func.addr, func.fuc_name, table.unpack(param))}
                else
                    ret = {pcall(skynet.call, func.addr, "lua", func.fuc_name, table.unpack(param))}
                end
            end
        end
    )
    return table.unpack(ret)
end

--新增一条金币日志
--@param uid
--@param altercoin
--@param alterlog
--@param gameid
--@param type
--@param state 0新生成  1自己游戏端修改成功 2已经通知完api服
--@return 数据库自增id
local function insertCoinLog(uid, altercoin, alterlog, gameid, type, state)
    LOG_INFO("insertCoinLog uid:", uid, "altercoin:", altercoin, "alterlog:", alterlog, "gameid:", gameid, "type:", type, "state:", state)
    local uniqueid = do_redis({'incr', PDEFINE.CACHE_LOG_KEY.coin_log})
    local sql = string.format(
        "insert into coin_log(uid,type,game_id,before_coin,coin,after_coin,log,state,updatetime,time, cache_uniqueid) values(%d,%d,%d,0,%0.4f,0,'%s',%d,%d,%d, %d) ", 
         uid, type, gameid, altercoin, alterlog, state, os.time(), os.time(), uniqueid)
    skynet.call(".dbsync", "lua", "sync", sql)
    return uniqueid
end

--修改金币日志状态
--@param altercoin_id
--@param state 0新生成  1自己游戏端修改成功 2已经通知完api服
local function alterCoinLog( altercoin_id, state, beforecoin, aftercoin )
    local sql = string.format("update coin_log set state = %d,updatetime = %d,before_coin = %0.4f,after_coin = %0.4f where cache_uniqueid = %d",
        state, os.time(), beforecoin, aftercoin, altercoin_id)
    skynet.call(".dbsync", "lua", "sync", sql)
end

--通知对方该上报数据了
local function getNodeNotify(servername)
    local server_notify = node_notify_table[servername]
    if server_notify == nil then
        node_notify_table[servername] = {}
        server_notify = node_notify_table[servername]
        server_notify.isnotify = false
    end

    return server_notify
end

--node上的数据是否都通知到usercenter了 在node启动的时候会让node通知一下
function CMD.setNodeNotify(servername, usertable, isend)
    -- LOG_DEBUG("usertable:", usertable)
    local server_notify = node_notify_table[servername] --node上的数据是否通知到usercenter了 在node启动的时候会让node通知一下
    if usertable ~= nil then
        for i,user in ipairs(usertable) do
            LOG_DEBUG("joinPlayer:", user)
            CMD.joinPlayer(user.cluster_info, user.data)
        end
    end
    if isend then
        server_notify.isnotify = true
    end
    LOG_DEBUG("setNodeNotify servername:", servername, "isend:", isend, "usertable size:", #usertable)
end

--通知对方该上报在线用户数据了
--@param servername
--@param serveradress
local function notifyreportuser(servername, serveradress)
    pcall(cluster.call, servername, serveradress, "otherhandler", "reportOnlineUser")
end

--检查这个服务器是否数据都报完了
--@param servername
--@param nilthensync true 表示如果对方还没上报完 通知对方继续上报
local function checkNodeNotify( servername, nilthensync )
    LOG_DEBUG("servername:", servername, "nilthensync:", nilthensync)
    if servername == nil or servername == "" then
        return false
    end

    local server_notify = getNodeNotify(servername)
    if nil ==server_notify or  server_notify.server == nil then
        return false
    end

    LOG_DEBUG("server_notify.server:", server_notify.server)
    if server_notify.server.status == PDEFINE.SERVER_STATUS.stop then
        return false
    end

    if server_notify.isnotify == false then
        if nilthensync then
            LOG_DEBUG("checkNodeNotify nilthensync:")
            --通知对方该上报在线用户数据了
            notifyreportuser(servername, server_notify.server.serverinfo.address)
        end
        return false
    end
    
    return true
end

function CMD.brodcastcoin2client( uid, altercoin )
    local cluster_info = CMD.getAgent(uid)
    if cluster_info ~= nil then
        pcall(cluster.call, cluster_info.server, cluster_info.address,
                                "clusterModuleCall", "player", "brodcastcoin2client", uid, altercoin)
    end
end

-- 通知金币不足的提示，要弹框了
--@param forcepop 强制弹窗
--@param first 1 or 0 表示当天第1次从子游戏退出
--@param bankrupt 是否破产，破产要带上商城(6)
function CMD.notifyPoP(uid, forcepop, first, bankrupt)
    if nil == forcepop then
        forcepop = 0
    end
    local cluster_info = CMD.getAgent(uid)
    if cluster_info then
        local poplist = CMD.getPoPList(uid)
        if bankrupt then  --破产
            -- if not table.contain(poplist, 6) then
            --     table.insert(poplist, 6)
            -- end
            -- -- 判断今天是否分享分享弹窗
            -- local lastShareTime = do_redis({"hget", PDEFINE.REDISKEY.LOBBY.fbshare, "last:uid:"..uid})
            -- local dt = 0
            -- if lastShareTime ~= nil then
            --     dt = date.DiffDay(os.time(), math.floor(lastShareTime))
            -- end
            -- -- 如果今天还没有分享，则需要弹窗显示分享界面
            -- if not lastShareTime or dt >= 1 then
            --     if not table.contain(poplist, 14) then
            --         table.insert(poplist, 14)
            --     end
            -- end
        end
        local retobj = {c = PDEFINE.NOTIFY.POP_LIST, code = PDEFINE.RET.SUCCESS, uid = uid, poplist=poplist, forcepop = forcepop, first = first} --forcepop 强制立即弹窗
        pcall(cluster.call, cluster_info.server, cluster_info.address, "sendToClient", cjson.encode(retobj))
    end
end

-- 关闭弹窗的倒计时，再推送下次应该弹的弹窗
function CMD.closePoP(uid, rtype)
    if rtype == PDEFINE.SHOPSTYPE.ONETIME then
        local retobj = {c = PDEFINE.NOTIFY.ONE_TIME_ONLY_OVER, code=PDEFINE.RET.SUCCESS, uid = uid}
        CMD.pushInfoByUid(uid, cjson.encode(retobj))
    elseif rtype == PDEFINE.SHOPSTYPE.LEVEL then
    end
    CMD.notifyPoP(uid, 0)
end

--通知客户端已破产,直接给20000金币
local function notifyBankrupt(uid)
    -- return cs(
    --     function()
    --         local cacheKey = 'bankrupt_notice:'..uid
    --         local cacheTimes = do_redis({"get", cacheKey}) or 0
    --         cacheTimes = math.floor(cacheTimes)
    --         if cacheTimes < PDEFINE.BANKRUPT.TIMES then
    --             local retobj = {c = PDEFINE.NOTIFY.BANKRUPT_NOTICE, code = PDEFINE.RET.SUCCESS, uid = uid, coin=PDEFINE.BANKRUPT.COIN}
    --             local cluster_info = CMD.getAgent(uid)
    --             if cluster_info then
    --                 pcall(cluster.call, cluster_info.server, cluster_info.address, "sendToClient", cjson.encode(retobj))
    --             end
    --             local timeout = getTodayLeftTimeStamp()
    --             cacheTimes = cacheTimes + 1
    --             do_redis({"setex", cacheKey, cacheTimes, timeout})
    --             do_redis({"set", cacheKey .. ':coin', PDEFINE.BANKRUPT.COIN})
    --         end
    --         return PDEFINE.RET.SUCCESS
    --     end
    -- )
end

--修改玩家coin  log不能包含 , " ' 会被替换为空格
--@param other{logtoken, coin_pool_normal, coin_pool_jp} 这些是非必须字段 可以选择传
--@param ipaddr 产生修改的ipaddr
--[[
altercoin_para={
    alter_coin=xx,
    type=xx,
    alterlog=xx,
}
gameinfo_para={
    gameid=xx,
    subgameid=xx,
}
poolround_para = {
    uniid = xx, --唯一id
    pooltype = xx, --pooltype  PDEFINE.POOL_TYPE
    poolround_id = xx, --pr的唯一id
}
]]
function CMD.calUserCoin(uid, issync, ipaddr, altercoin_para, gameinfo_para, poolround_para, extend1)
    local gameid = gameinfo_para.gameid
    local subgameid = gameinfo_para.subgameid

    local altercoin = altercoin_para.alter_coin
    if nil == altercoin then
        LOG_ERROR("usercenter calUserCoin uid:", uid, " altercoin is nil")
        LOG_ERROR("usercenter calUserCoin issync:", issync, " altercoin_para :", altercoin_para, " gameinfo_para:", gameinfo_para, " poolround_para:",poolround_para)
    end
    if tonumber(altercoin) == 0 then
        --修改0金币就不继续走了
        LOG_WARNING("calUserCoin altercoin=0", altercoin_para)
        return PDEFINE.RET.SUCCESS,0,0
    end

    local type = altercoin_para.type
    local alterlog = altercoin_para.alterlog

    local uniid = poolround_para.uniid
    local pooltype = poolround_para.pooltype
    local poolround_id = poolround_para.poolround_id

    local paramlog = concatStr(uid,altercoin,alterlog,gameid,subgameid,type,uniid,pooltype,issync,ipaddr,poolround_id)
    if ipaddr == nil then
        ipaddr = "unkown"
    end
    if alterlog == nil then
        LOG_ERROR("calUserCoin alterlognil", paramlog)
        return PDEFINE.RET.CALCOIN_LOG_MUST
    end
    LOG_DEBUG("calUserCoin paramlog", paramlog)
    --log不能包含 , " '
    alterlog = string.gsub(alterlog, ",", " ");
    alterlog = string.gsub(alterlog, "\"", " ");
    alterlog = string.gsub(alterlog, "'", " ");

    local cluster_info = CMD.getAgent(uid)
    --本次修改记录到数据库 state = 0
    local altercoin_id = insertCoinLog(uid, altercoin, alterlog, gameid, type, 0)
    if altercoin_id == nil then
        LOG_ERROR("calUserCoin altercoin_id nil", paramlog)
        return PDEFINE.RET.ERROR.CALL_FAIL
    end

    local ok,code,beforecoin,aftercoin
    local userqueue = queuemgr.getQueue(uid)
    userqueue(
        function()
            ok,code,beforecoin,aftercoin = pcall(CMD.alterUserCoinOffLine, "", uid, altercoin, alterlog, type, issync, altercoin_id, gameid)
        end
    )
    LOG_DEBUG("calUserCoin ok:", ok, "code:", code, "beforecoin:", beforecoin, "aftercoin:", aftercoin)
    if not ok then
        LOG_ERROR("calUserCoin okfalse", paramlog)
        return PDEFINE.RET.ERROR.CALL_FAIL
    end
    if code ~= PDEFINE.RET.SUCCESS then
        LOG_ERROR("calUserCoin codefail", code, paramlog)
        return code
    end
    if cluster_info ~= nil and issync then
        pcall(cluster.send, cluster_info.server, cluster_info.address,
            "clusterModuleCall", "player", "brocastCalUserCoin", uid, altercoin, aftercoin, issync)
    end

    --通知后台结束记录到数据库 state = 2 通知完后台了
    alterCoinLog(altercoin_id, 2, beforecoin, aftercoin)

    return PDEFINE.RET.SUCCESS, beforecoin, aftercoin, altercoin_id
end

--获取玩家数据
function CMD.getPlayerInfo( uid )
    if nil == uid then
        LOG_ERROR("getPlayerInfo uid is nil")
        return
    end
    local playerData
    local cluster_info = CMD.getAgent(uid)
    if cluster_info then
        local ok,playerinfo = pcall(cluster.call, cluster_info.server, cluster_info.address,
                                "clusterModuleCall", "player", "getPlayerInfo", uid)
        if not ok then
            LOG_ERROR("CMD.getPlayerInfo fail, ok:false")
            playerData = nil
        else
            playerData = playerinfo
        end
    end
    if not playerData then
        local d_user = require "d_user"
        d_user:Init()
        d_user:Load(uid)
        local info = d_user:Get(uid)
        if info then
            playerData = table.copy(info)
            if playerData == nil or table.empty(playerData) then
                LOG_ERROR("getPlayerInfo player nil.uid:", uid)
            end
            d_user:UnLoad(uid)
        else
            return playerData
        end
    end
    local userqueue = queuemgr.getQueue(uid)
    userqueue(
        function()
            if nil ~= playerData then
                playerData.coin = CMD.getUserCoin(uid)
            end
        end
    )
    return playerData
end

function onnodechange( server )
    local servername = server.name
    local server_notify = getNodeNotify(servername)
    server_notify.server = server

    --[[
        server的结构
        server={
            name=xx,
            status=xx,
            tag=xx,
            freshtime=xx,
            serverinfo = {}
        }
    ]]
    if server.status == PDEFINE.SERVER_STATUS.stop then
        server_notify.isnotify = false
    elseif server.status == PDEFINE.SERVER_STATUS.run then
        server_notify.isnotify = false
        --通知对方该上报数据了
        notifyreportuser(servername, server.serverinfo.address)
    end

    LOG_DEBUG("onnodechange server:", server, "server_list:", server_list)
end

function CMD.onserverchange( server )
    LOG_DEBUG("onserverchange server:",server)
    --[[
        server的结构
        server={
            name=xx,
            status=xx,
            tag=xx,
            freshtime=xx，
            serverinfo = {}
        }
    ]]
    if server.tag == "node" then
        onnodechange(server)
    end
end

--系统启动完成后的通知
function CMD.start_init( ... )
    local callback = {}
    callback.method = "onserverchange"
    callback.address = skynet.self()

    skynet.call(".servernode", "lua", "regEventFun", PDEFINE.SERVER_EVENTS.changestatus, callback)
end

local function init_cache_log_key()
    local cache_key_table = PDEFINE.CACHE_LOG_KEY
    for k , v in pairs(cache_key_table) do 
        local sql = string.format("select * from %s order by id desc limit 1", k)
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs > 0 then 
            local lastid = rs[1]['id']
            do_redis({'getset', v, lastid})
        end
    end
end

function CMD.broadcastWorld(msg)
    for uid, cluster_info in pairs(world_channel) do
        if msg.info == nil or msg.info.uid == nil or (msg.info.uid and uid ~= msg.info.uid) then
            msg.uid = uid
            sendChat(cluster_info, cjson.encode(msg)) 
        end
    end
end

-- 随机发送赢钱跑马灯
-- 每3-10分钟发送一个
local function randWinCoinNotice()
    LOG_DEBUG("start randWinCoinNotice")
    -- 获取一个随机的机器人
    local ok, robot = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", 1)
    if ok and #robot > 0 then
        -- 随机获奖金额(20W-200W)
        local coin = math.random(20, 200) * 10000
        -- 随机一个游戏gameid
        local allGameid = {}
        for gameid, _ in pairs(PDEFINE_GAME.GAME_NAME) do
            table.insert(allGameid, gameid)
        end
        local gameid = allGameid[math.random(#allGameid)]
        CMD.winCoinNotice(robot[1].uid, gameid, coin)
    end
    local delayTime = math.random(3, 10)*60*100
    skynet.timeout(delayTime, function ()
        randWinCoinNotice()
    end)
end

-- 随机赠送魅力值道具, 每天总共20次，每次间隔不少于10分钟
-- 每个人最多获得一次
-- 从登录表中查出最近10分钟登录的用户，随机赠送
local function autoSendGift()
    LOG_DEBUG("start autoSendGift")
    -- 获取一个随机的机器人
    local ok, robot = pcall(cluster.call, "ai", ".aiuser", "getAiListByNum", 1)
    if ok and #robot > 0 then
        -- 获取随机礼物
        local row = skynet.call(".configmgr", "lua", "getCharmPropList")
        local ids = {}
        for id, item in pairs(row) do
            -- 只送小额的
            if item.charm > 0 and item.charm < 1000 then
                table.insert(ids, id)
            end
        end
        if #ids > 0 then
            local item = row[ids[math.random(#ids)]]
            -- 找到最近10分钟登录的，且3天内没送过的玩家
            local sql = string.format("select distinct(uid) from d_user_login_log where create_time > %d", os.time()-600)
            local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
            local uid = nil
            if rs and #rs > 0 then
                for _, r in pairs(rs) do
                    local _uid = r['uid']
                    local redis_key = PDEFINE.REDISKEY.OTHER.recent_send_charm.._uid
                    local isSend = do_redis({'get', redis_key})
                    if not isSend or isSend == "" then
                        do_redis({"setex", redis_key, "1", 3*24*60*60})
                        uid = _uid
                        break
                    end
                end
            end
            if uid then
                local userInfo = CMD.getPlayerInfo(uid)
                if userInfo then
                    CMD.updateFriendCharm(uid, item.charm)
                    CMD.updateFriendCharm(robot[1].uid, item.charm)
                    local sql = string.format("insert into d_user_sendcharm(uid1, uid2, create_time, charmid,title,title_al,img,coin,charm) values (%d, %d, %d, %d,'%s','%s','%s',%d,%d)", robot[1].uid, uid, os.time(), item.id, item.title, item.title_al,item.img, item.count, item.charm)
                    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
                    if rs and rs.insert_id then
                        if math.random(1, 1000) < 300 then
                            local content = string.format("%d;%d;%d", uid, item.id, rs.insert_id)
                            pcall(cluster.send, "node", ".chat", "chat", robot[1].uid, nil, nil, content, PDEFINE.CHAT.MsgType.CHARM)
                        end
                    end
                    if item.lamp > 0 then
                        -- 全服广播魅力值赠送消息跑马灯
                        CMD.sendGiftNotice(robot[1].uid, uid, item.charm, item.title, item.title_al)
                        -- 播放动画
                        local sender = {
                            uid = robot[1].uid,
                            playername = robot[1].playername,
                            usericon = robot[1].usericon,
                            level = robot[1].level,
                            svip = robot[1].svip,
                            charm = robot[1].charm or 0,
                            avatarframe = robot[1].avatarframe or '',
                        }
                        local recevier = {
                            uid = uid,
                            playername = userInfo.playername or '',
                            usericon = userInfo.usericon or '',
                            level = userInfo.level or 1,
                            svip = userInfo.svip or 0,
                            charm = userInfo.charm or 0,
                            avatarframe = userInfo.avatarframe or '',
                        }
                        local msg = {c=PDEFINE.NOTIFY.CHARM_INFO, code=PDEFINE.RET.SUCCESS, receive= recevier, send=sender,}
                        msg.info = {
                            id = item.id,
                            img = item.img,
                            title = item.title,
                            title_al = item.title_al,
                            coin = item.coin,
                            charm = item.charm
                        }
                        CMD.pushInfo(cjson.encode(msg))
                    end
                end
            end
        end
    end
    local delayTime = math.random(10, 20)*60*100
    skynet.timeout(delayTime, function ()
        autoSendGift()
    end)
end

-- 获取可提现金额
local function getDrawCoin(uid)
    local coin = CMD.getUserCoin(uid)
    local gamedraw = CMD.getGameDraw(uid)
    local dcoin = gamedraw
    if dcoin < 0 then
        dcoin = 0
    end
    if dcoin > coin then
        dcoin = coin
    end
    return dcoin, coin
end

local function doDrawJob(uid, coin, bankinfo)
    return cs(
        function()
            local dcoin, userCoin = getDrawCoin(uid)
            local transferAmount = 0
            if APP ~= PDEFINE.APPID.RUMMYVIP then   --RummyVip 取消新会员在没有充值的情况下发起提现之后余额直接转到优惠钱包的限制
                local userInfo = CMD.getPlayerInfo(uid)
                if userInfo.ispayer == 0 then
                    local sql = string.format('select count(*) as t from d_user_draw where uid=%d and status!=3', uid) --被拒绝的订单不算
                    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
                    if #rs==0 or rs[1].t == 0 then --未付费用户，第一次提现
                        transferAmount = userCoin - dcoin
                    end
                end
            end
            LOG_DEBUG('doDrawJob getDrawCoin:' , dcoin, ' uid:', uid, ' drawcoin:',coin, ' userCoin:', userCoin)
            if dcoin < coin then
                return PDEFINE_ERRCODE.ERROR.DRAW_COIN_NOT_ENOUGH --金币不足
            end
            coin = math.round_coin(coin)
            local addCoin = -coin

            local altercoin_para={
                alter_coin=addCoin,
                type=PDEFINE.ALTERCOINTAG.DRAW,
                alterlog="发起提现",
            }
            local gameinfo_para={
                gameid=PDEFINE.GAME_TYPE.SPECIAL.DRAW_COIN,
                subgameid=0,
            }
            local poolround_para = {
                uniid = '', --唯一id
                pooltype = '', --pooltype  PDEFINE.POOL_TYPE
                poolround_id = '', --pr的唯一id
            }
            local bankid = bankinfo.bankid
            local code, beforecoin, aftercoin, altercoin_id = CMD.calUserCoin(uid, false, nil, altercoin_para, gameinfo_para, poolround_para, nil)
            if code == PDEFINE.RET.SUCCESS then
                --减去gamedraw
                local orderid = genOrderId('draw')
                local agent = CMD.getAgent(uid)
                if agent then
                    pcall(cluster.send, agent.server, agent.address, "updateGameDrawInDraw", uid, -coin, transferAmount, orderid)
                else
                    CMD.updateGameDrawInDraw(uid, -coin)
                    if transferAmount > 0 then --现金余额转去bonus
                        local cointype = PDEFINE.ALTERCOINTAG.FREE_WINNS2BONUS
                        local gameid = PDEFINE.GAME_TYPE.SPECIAL.FREE_WINNS2BONUS
                        local code,before_coin,after_coin = player_tool.funcAddCoin(uid, -transferAmount, "转移到cashbonus", cointype, gameid, PDEFINE.POOL_TYPE.none, nil, nil)
                        if code == PDEFINE.RET.SUCCESS then
                            --加cash bonus
                            local sql1 = string.format("update d_user set cashbonus=cashbonus+%.2f where uid=%d", transferAmount, uid)
                            LOG_DEBUG('drawverify bonus uid:', transferAmount, ' sql:', sql1)
                            do_mysql_queue(sql1)
                            do_redis({"hincrbyfloat", 'd_user:'..uid, 'cashbonus', transferAmount})
                            addBonusLog(orderid, 'Free Winnings transfer', transferAmount, os.time(), PDEFINE.TYPE.SOURCE.FREE_WINNING, uid)
                        else
                            LOG_ERROR('转移到cashbonus uid:',uid, ' coin:', transferAmount)
                        end
                    end
                end
                
                local taxthird = 0
                local ptax = 0
                local inserLogSql = string.format([[
                    insert into d_user_draw (uid,orderid,cat,bankid,userbankid,account,create_time,coin,status,taxthird, tax, channelid) 
                    values(%d,'%s', %d, %d,%d,'%s', %d, %d, %d,%.2f,%.2f,%d)
                    ]], uid, orderid, bankinfo.cat, bankid, bankinfo.id, bankinfo.account, os.time(), coin, 0, taxthird,ptax,0)            
                LOG_INFO(" draw log sql:", inserLogSql)
                skynet.call(".mysqlpool", "lua", "execute", inserLogSql)
                syncWallet(uid)
                return PDEFINE.RET.SUCCESS
            end
            return code
        end)
end

--后台加减cashbonus
function CMD.apiActCashBonus(uid, coin, remark)
    local agent = CMD.getAgent(uid)
    if agent then
        local ok, ret = pcall(cluster.call, agent.server, agent.address, "clusterModuleCall", "player", "apiActCashBonus", uid, coin, remark)
        LOG_DEBUG('ok, ret:',ok, ret)
        if ok then
            return ret
        end
    else
        if coin ~= 0 then
            coin = tonumber(coin)
            local orderid = genOrderId('bonus')
            local title = 'admin'
            local actType = PDEFINE.TYPE.SOURCE.Admin

            local sql1 = string.format("update d_user set cashbonus=cashbonus+%2.f where uid=%d", coin, uid)
            LOG_DEBUG('addCoinByRate bonus parentid:', uid, ' sql:', sql1)
            do_mysql_queue(sql1)
            do_redis({"hincrbyfloat", 'd_user:'..uid, 'cashbonus', coin})

            local sql = string.format("insert into d_log_cashbonus(orderid,title,coin,create_time,category,uid,useruid,remark) values ('%s','%s', %.2f, %d, %d, %d,%d,'%s')", 
            orderid,title, coin, os.time(), actType, uid, 0, mysqlEscapeString(remark))
            LOG_DEBUG('addCoinByRate bonus parentid:', uid, ' sql:', sql)
            do_mysql_queue(sql)
            return PDEFINE.RET.SUCCESS
        end
    end
    return 500
end

-- kyc审核
function CMD.kycverify(uid, cat, status, id)
    if cat <= 0 then
        return PDEFINE_ERRCODE.ERROR.KYC_INFO_ERR
    end
    local sql = string.format("select * from d_kyc where id=%d ", id)
    local ret = skynet.call(".mysqlpool", "lua", "execute", sql)
    if ret==nil or ret[1] == nil then
        return PDEFINE_ERRCODE.ERROR.KYC_INFO_ERR --账户信息
    end
    if status == 2 then
        if cat == 2 then
            triggerSendMail(uid, PDEFINE.MAIL_TYPE.KYCPANSUCC)
        elseif cat == 3 then
            triggerSendMail(uid, PDEFINE.MAIL_TYPE.KYCBANKSUCC)
        end
    else
        if cat == 2 then
            triggerSendMail(uid, PDEFINE.MAIL_TYPE.KYCPANFAIL, 0, ret[1].memo)
        elseif cat == 3 then
            triggerSendMail(uid, PDEFINE.MAIL_TYPE.KYCBANKFAIL, 0, ret[1].memo)
        end
    end
end

-- 拒绝提现
local function rejectDraw(uid, id, memo)
    return cs(
        function()
            local sql = string.format("select * from d_user_draw where id=%d ", id)
            local ret = skynet.call(".mysqlpool", "lua", "execute", sql)
            if ret==nil or ret[1] == nil then
                return PDEFINE_ERRCODE.ERROR.DRAW_ERR_BANKINFO --账户信息
            end
            if ret[1].status ~= 0 then
                LOG_DEBUG('rejectDraw status maybe err:', ret[1].status, uid, id)
            end
            local log = ret[1]
            local orderid = log.orderid --提现订单id
            local addCoin = math.round_coin(log.coin)
            local agent   = CMD.getAgent(uid)
            local runoffline  = true
            if agent then
               local ok , code = pcall(cluster.call, agent.server, agent.address, "updateGameDrawAndCoin", uid, addCoin, orderid, memo) --可能会归还bonus
               LOG_DEBUG('rejectDraw online updateGameDrawAndCoin start. uid:', uid, ' coin:', addCoin, ok, code)
                if ok and code == PDEFINE.RET.SUCCESS then
                    runoffline = false
               end
            end
            if runoffline then
                LOG_DEBUG('rejectDraw offline calUserCoin start. uid:', uid, ' coin:', addCoin)
                local altercoin_para={
                    alter_coin=addCoin,
                    type=PDEFINE.ALTERCOINTAG.DRAWRETURN,
                    alterlog= memo or "拒绝提现",
                }
                local gameinfo_para={
                    gameid=PDEFINE.GAME_TYPE.SPECIAL.DRAW_RETURN,
                    subgameid=0,
                }
                local poolround_para = {
                    uniid = '', --唯一id
                    pooltype = '', --pooltype  PDEFINE.POOL_TYPE
                    poolround_id = '', --pr的唯一id
                }
                local code, beforecoin, aftercoin, altercoin_id = CMD.calUserCoin(uid, true, nil, altercoin_para, gameinfo_para, poolround_para, nil)
                if code ~= PDEFINE.RET.SUCCESS then
                    LOG_DEBUG('rejectDraw offline calUserCoin coin failed. uid:', uid, ' coin:', addCoin)
                    return code
                else
                    CMD.updateGameDrawInDraw(uid, addCoin)

                    local sql = string.format("select * from d_log_cashbonus where uid=%d and orderid='%s' and category=%d limit 1", uid, orderid, PDEFINE.TYPE.SOURCE.FREE_WINNING)
                    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
                    if #rs == 1 then
                        local coin = rs[1].coin
                        local userInfo = CMD.getPlayerInfo(uid)
                        if userInfo.cashbonus < coin then
                            LOG_DEBUG('uid:', uid, ' cashbonus less than coin:', userInfo.cashbonus, coin)
                            coin = userInfo.cashbonus
                        end

                        do_redis({"hincrbyfloat", 'd_user:'..uid, 'cashbonus', -coin})
                        local sql = string.format("update d_user set cashbonus =cashbonus+ %.2f where uid = %d", -coin, uid)
                        skynet.call(".mysqlpool", "lua", "execute", sql)

                        local altercoin_para={
                            alter_coin=coin,
                            type=PDEFINE.ALTERCOINTAG.BONUS2BALANCE,
                            alterlog="Bonus转移到Balance",
                        }
                        local gameinfo_para={
                            gameid=PDEFINE.GAME_TYPE.SPECIAL.BONUS2BALANCE,
                            subgameid=0,
                        }
                        local poolround_para = {
                            uniid = '', --唯一id
                            pooltype = '', --pooltype  PDEFINE.POOL_TYPE
                            poolround_id = '', --pr的唯一id
                        }
                        local code, beforecoin, aftercoin, altercoin_id = CMD.calUserCoin(uid, true, nil, altercoin_para, gameinfo_para, poolround_para, nil)
                        if code ~= PDEFINE.RET.SUCCESS then
                            LOG_ERROR('Bonus转移到Balance error:', orderid, ' uid:', uid, ' coin:', coin, ' cashbonus:', userInfo.cashbonus)
                        end

                        local orderid = genOrderId('bonus')
                        local sql = string.format("insert into d_log_cashbonus(orderid,title,coin,create_time,category,uid,useruid) values ('%s','%s', %.2f, %d, %d, %d,%d)", 
                                                    orderid,'Transfer to Cash Balance', -coin, os.time(), PDEFINE.TYPE.SOURCE.DRAW_BONUS2CASH, uid, 0)
                        do_mysql_queue(sql)
                    end
                end
                LOG_DEBUG('rejectDraw offline calUserCoin end. uid:', uid, ' coin:', addCoin)
            end
            
            local sql = string.format("update d_user_draw set status=3,chanstate=4 where id =%d", id)
            LOG_INFO(" draw log sql:", sql)
            skynet.call(".mysqlpool", "lua", "execute", sql)

            return PDEFINE.RET.SUCCESS
        end)
end

-- 提现审核
function CMD.drawverify(uid, id, status)
    if id <= 0 then
        return PDEFINE_ERRCODE.ERROR.DRAW_ERR_PARAM_COIN
    end
    if status == 2 then
        local sql = string.format( "select id from d_user_draw where uid=%d and status=2",  uid)
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        local send = false
        if #rs == 0 then
            triggerSendMail(uid, PDEFINE.MAIL_TYPE.FIRSTDRAW) --首次提现
            send = true
        end
        local sqlFirst = string.format( "select id,coin from d_user_draw where id=%d and uid=%d", id, uid)
        local rst = skynet.call(".mysqlpool", "lua", "execute", sqlFirst)
        local drawcoin = rst[1].coin
        if not send then
            triggerSendMail(uid, PDEFINE.MAIL_TYPE.DRAWSUCC, rst[1].coin)
        end
        syncWallet(uid)
        local daytimeKey = PDEFINE_REDISKEY.OTHER.today_draw_times ..uid
        do_redis({"incrby", daytimeKey, 1}) --今日成功提现次数
        do_redis({"expire", daytimeKey, 86400})
        local agent = CMD.getAgent(uid)
        if agent then
            pcall(cluster.send, agent.server, agent.address, "addDrawTimes", uid, drawcoin)
        else
            local sql1 = string.format("update d_user set drawsucctimes=drawsucctimes+1,drawsucccoin=drawsucccoin+ %.2f where uid=%d", drawcoin, uid)
            do_mysql_queue(sql1)
            do_redis({"hincrbyfloat", 'd_user:'..uid, 'drawsucctimes', 1})
            do_redis({"hincrbyfloat", 'd_user:'..uid, 'drawsucccoin', drawcoin})
        end
    else --拒绝提现
        local sqlFirst = string.format( "select id,coin,memo,orderid,status from d_user_draw where id=%d ", id)
        local rst = skynet.call(".mysqlpool", "lua", "execute", sqlFirst)
        if rst[1].status ~= 3 then
            triggerSendMail(uid, PDEFINE.MAIL_TYPE.DRAWFAIL, rst[1].coin, rst[1].memo)
            local errCode = rejectDraw(uid, id, rst[1].memo)
            if errCode ~= PDEFINE.RET.SUCCESS then
                return errCode
            end
        end
    end
    return PDEFINE.RET.SUCCESS
end

-- 充值审核
function CMD.rechargeVerify(uid, id, rtype)
    if id <= 0 then
        return PDEFINE_ERRCODE.ERROR.DRAW_ERR_PARAM_COIN
    end
    if rtype == 2 then --拒绝
        local sqlFirst = string.format( "select id, `count`, memo,groupid from d_user_recharge where id=%d ", id)
        local rst = skynet.call(".mysqlpool", "lua", "execute", sqlFirst)
        local chanName = ''
        if rst[1].groupid > 0 then
            local sql = string.format( "select id,title from s_pay_group where id=%d ", rst[1].groupid)
            local res = skynet.call(".mysqlpool", "lua", "execute", sql)
            if #res == 1 then
                chanName = res[1].title
            end
        end
        triggerSendMail(uid, PDEFINE.MAIL_TYPE.RECHARGEFAIL, rst[1].count, rst[1].memo, chanName)
    else --恢复
        -- local sqlFirst = string.format( "select id,coin,memo from d_user_draw where id=%d ", id)
        -- local rst = skynet.call(".mysqlpool", "lua", "execute", sqlFirst)
        -- triggerSendMail(uid, PDEFINE.MAIL_TYPE.DRAWFAIL, rst[1].coin, rst[1].memo)
        -- local errCode = rejectDraw(uid, id)
        -- if errCode ~= PDEFINE.RET.SUCCESS then
        --     return errCode
        -- end
    end
    return PDEFINE.RET.SUCCESS
end

--! 用户提交取现（H5通过api服调用过来）
function CMD.draw(uid, bankid, coin, chanid)
    LOG_DEBUG('CMD.draw', string.format("user %d drawcoin: %s from bank: %s chanid: %s", uid, coin, bankid, chanid))
    if coin <= 0 then
        return PDEFINE_ERRCODE.ERROR.DRAW_ERR_PARAM_COIN
    end
    if bankid <= 0 then
        return PDEFINE_ERRCODE.ERROR.DRAW_ERR_BANKINFO
    end

    local desk = skynet.call(".agentdesk", "lua", "getDesk", uid)
    if desk ~= nil and not table.empty(desk) then
        --在游戏内
        LOG_ERROR("apiAddCoin gaming uid", uid, ' deskid:', desk)
        return PDEFINE.RET.ERROR.GAME_ING_ERROR
    end

    local dcoin = getDrawCoin(uid)
    LOG_DEBUG('CMD.draw dcoin:', dcoin , ' drawcoin:', coin)
    if dcoin < coin then
        return PDEFINE_ERRCODE.ERROR.COIN_NOT_ENOUGH --可提现金币不足
    end

    local sql = string.format("select * from d_kyc where id=%d and uid=%d and category=3 and status=2", bankid, uid) --银行卡
    local ret = skynet.call(".mysqlpool", "lua", "execute", sql)
    local bankinfo = {}
    if ret==nil or ret[1] == nil then
        sql = string.format("select * from d_user_bank where id=%d and uid=%d", bankid, uid) --upi
        ret = skynet.call(".mysqlpool", "lua", "execute", sql)
        if ret==nil or ret[1] == nil then
            return PDEFINE_ERRCODE.ERROR.DRAW_ERR_BANKINFO --账户信息
        else
            bankinfo = {
                id = ret[1].id,
                bankid = tonumber(ret[1].bankid or 0),
                cat = 2,
                account = ret[1].cardnum,
                username= ret[1].username
            }
        end
    else
        bankinfo = {
            id = ret[1].id,
            bankid = tonumber(ret[1].bankid or 0),
            cat = 1,
            account = ret[1].cardnum,
            username= ret[1].username
        }
    end
    if table.empty(bankinfo) then
        return PDEFINE_ERRCODE.ERROR.DRAW_ERR_BANKINFO --账户信息
    end

    local errCode = doDrawJob(uid, coin, bankinfo)
    LOG_DEBUG('CMD.draw dcoin:', dcoin , ' drawcoin:', coin, ' errCode:', errCode, 'uid:',uid)
    if errCode ~= PDEFINE.RET.SUCCESS then
        return errCode
    end
    --全服广播
    if coin > 0 then
        local playername = do_redis({"hget", "d_user:"..uid, "playername"},uid)
        sysmarquee.onWithdrawCoin(playername, coin)
    end

    return PDEFINE.RET.SUCCESS
end

function CMD.sendChat2Global(uid, content)
    pcall(cluster.send, "node", ".chat", "chat", uid, nil, 0, content, 1)
end

function CMD.updateRoomStatusInChat(deskid, gameid, cid)
    pcall(cluster.send, "node", ".chat", "roomStart", deskid, gameid, cid)
end

--每天0点自动刷新任务
local function autoResetMainTask()
    LOG_DEBUG("start autoResetMainTask")
    
    CMD.apiResetMainTask()

    local endtime = calRoundEndTime()
    local delayTime = (endtime - os.time() + 1) * 100
    skynet.timeout(delayTime, function ()
        autoResetMainTask()
    end)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
		skynet.retpack(f(...))
    end)
    init_cache_log_key()
    -- skynet.timeout(5*60*100, function ()
    --     randWinCoinNotice()
    -- end)

    local endtime = calRoundEndTime()
    local lefttime = endtime - os.time() + 1
    skynet.timeout(lefttime * 100, function ()
        autoResetMainTask()
    end)
	skynet.register(".userCenter")
end)