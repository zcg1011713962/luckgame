local skynet = require "skynet"
local dcmgr = require "dcmgr"
local cluster = require "cluster"
local cjson = require "cjson"
local player_tool = require "base.player_tool"
local wbsocket = require "wbsocket"
local MessagePack = require "MessagePack"
local api_service = require "api_service"
local is_release = skynet.getenv('isrelease')
local DEBUG = skynet.getenv("DEBUG")
local heart_time = 10*60*100 --心跳检测时间 20分钟
local date = require "date"

local APP = tonumber(skynet.getenv("app")) or 1

cjson.encode_empty_table_as_object(false)

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = skynet.tostring,
}

-- 功能模块
local sign = require "sign"
local pay    = require "pay"
local player = require "player"
local mailbox= require "mailbox"
local quest  = require "quest"
local friend = require "friend"
local jackpot  = require "jackpot"
local league = require "league"
local upgrade = require "upgrade"
local invite = require "invite"
local club  = require "club"
local privateroom  = require "privateroom"
local charm = require "charm"
local exchange = require "exchange"
local knapsack = require "knapsack"
local maintask = require "maintask"
local bank  = require "bank"
-- local withdraw = require "withdraw"
local viplvtask = require "viplvtask" --vip等级塔

local module_list = {
    ['sign']       = sign, --签到
    ["pay"]        = pay, --支付
    ["quest"]      = quest, --任务
    ["player"]     = player,
    ["mailbox"]    = mailbox, --邮件
    ["friend"]     = friend, --好友
    ["league"]     = league,
    ["upgrade"]    = upgrade, --升级
    ["invite"]     = invite,
    ["club"]       = club,  -- 俱乐部
    ["privateroom"]       = privateroom,  -- 俱乐部
    ['charm'] = charm, --魅力值道具
    ['exchange'] = exchange, --兑换码功能
    ['knapsack'] = knapsack, --背包
    ['maintask'] = maintask, -- 主线任务
    ['jackpot'] = jackpot,
    ["bank"] = bank,
    -- ["withdraw"] = withdraw,
    ["viplvtask"]= viplvtask,
}

local NODE_NAME = skynet.getenv("nodename") or "noname"

-- node节点的全局服务
-- 玩家信息
local gate
local UID, SUBID
local CLIENT_FD
local SECRET
local CLIENT_UUID
local tmp_data = {}
local online = false -- 在线标志
local PLATFORM = 1 --登录平台(iOS/Android/Web)
local ChannelID = 5 --渠道包id(客户端当前登录的渠道包id)
local BUNDLEID --登录的bundle id (多个马甲包appid可能重复了)
local IP = ""
local cluster_desk = {}
local autoFuc
local autoLoginFuc --在线登录奖励倒计时函数
local autoTurntableFunc --在线大转盘奖励：登录即设置倒计时，倒计时到了发送通知；领取成功后才继续设置倒计时
local autoUpdateQuestFunc --在线时长任务更新
-- 接口函数组
local CMD = {}
local handle = {}
local OFFLINE = {}
local flag = false
local kicking = false --正在T人
local msgIdx = 0
local newcoin = -1 --从api拿到的最新的coin数据 负数表示没有收到这个数据的最新值 不需要处理
local TOKEN --token数据
local NOW_LANGUAGE = 1 --玩家当前使用的语言标识 暂时不用入库，如果之后有需求再看 默认为1：阿拉伯 (2：英语)
local ACCOUNT --玩家账号
local Login_StartCounTime --登录计时 开始时间 注意这个不是登录时间，因为多次登录的情况下 这个值是有可能被修改的 只是用于统计在线时长
local isjoinPlayer2Master = false --是否已经发送给master join信息了
-- local lgoutCnt = 5 --等待登出计数 --3次定时器等待还未处理处理完登录就退出
local isLogout = false --是否正在登出 如果在登出了 就不会新处理消息了
local isiOSCheck = false --是否是提审版本
local DEVICE_TOKEN 
local LOGIN_TYPE
local GSTATUS = 0 --游戏状态 0：无  1：等待进入中 (在邀请好友一起游戏时使用)
local DRAW_RETURN  = 'drawreturn' 

--心跳定时器
local function set_timeout(ti, f)

    local function t()
        if f then
            f()
        end
    end
    skynet.timeout(ti, t)
    return function() 
        f=nil
    end
end

--增加正在处理消息计数
--@return true/false 返回false的时候不能继续处理消息 应该退出
local function addDealMsgCount()
    if isLogout then
        LOG_DEBUG("isLogout adddealmsgcount fail")
        return false
    end
    msgIdx = msgIdx + 1
    return true
end

--减少正在处理消息计数
local function delDealMsgCount()
    msgIdx = msgIdx - 1
end

--重置正在处理消息计数
local function resetDealMsgCount()
    msgIdx = 0
end

--减少正在处理消息计数
local function isDealingMsg()
    if msgIdx > 0 then
        return true
    end
    return false
end

--设置登出状态
local function setLogoutFlag(flag)
    isLogout = flag
end

--获取登出状态
local function getLogoutFlag()
    return isLogout
end

-- 玩家退出，更新他的在线时长
local function updateOnlineTime(uid, user_data)
    LOG_DEBUG("updateOnlineTime uid:", uid)
    if nil == uid then
        return
    end
    local nowTime = os.time()
    local time = do_redis({"get", "login_time" .. uid}) --记录登录退出时间
    if time then
        time = tonumber(time)
        local sql = string.format("select * from d_user_login_log where create_time=%d and uid=%d", time, uid)
        local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
        LOG_DEBUG("updateOnlineTime sql:", sql, ' rs:', #rs)
        if #rs > 0 then
            local onlineTime = nowTime - rs[1].create_time
            if onlineTime < 0 then
                onlineTime = 0
            end
            local coin, level = 0, 0
            if nil ~= user_data then
                coin = user_data.coin
                level = user_data.level
            end
            sql = string.format("update d_user_login_log set logout_time=%d,onlinetime=%d,coin=%2.f,logout_level=%d where id=%d", nowTime, onlineTime, coin, level, rs[1].id)
            do_mysql_queue(sql)
            sql = string.format("update d_user set onlinestate=0 where uid =%d", uid)
            do_mysql_queue(sql)
        end
    end
end

local function logout_do( isjihao )
    LOG_INFO("logout_do", msgIdx, 'agentid:', skynet.self(), "UID:", UID, "subid:", SUBID)
    local lgoutCnt = 20
    while isDealingMsg() and lgoutCnt ~= 0 do
       lgoutCnt = lgoutCnt - 1
       LOG_INFO("logout_do isDealingMsg",UID)
       skynet.sleep(25) --250ms之后再检测
    end
    resetDealMsgCount()

    if nil == UID then
        LOG_WARNING("logout_do UID is nil")
        return 
    end

    -- 通知gate登出并回收agent为空闲，不再exit()
    if gate then
        skynet.call(gate, "lua", "logout", UID, SUBID)
        LOG_INFO("wsmsgagent call gate.logout:", UID, " subid:", SUBID)
    else
        LOG_ERROR(string.format("%s logout but gate cannot find", UID))
    end

    --发出登出日志
    local onlinetime = os.time()-Login_StartCounTime
    if onlinetime < 0 then
        onlinetime = 0
    end 
    if not isjihao then
        pcall(api_service.callAPIMod, "logout", UID, TOKEN, onlinetime)
    end
    -- --检测是否有重复的agent wsgated里面存放的对应关系是最新的wsmsgagent不一定是自己
    -- skynet.call(gate, "lua", "resetloginstarttime", UID)

    if autoFuc then autoFuc() end
    if autoLoginFuc then autoLoginFuc() end
    if autoTurntableFunc then autoTurntableFunc() end
    if autoUpdateQuestFunc then autoUpdateQuestFunc() end

    pcall(cluster.call, "master", ".userCenter", "removePlayer", {uid=UID})

    local user_data = dcmgr.user_dc.get(UID)
    updateOnlineTime(UID, user_data)
    do_redis({"del", "utoken_" .. UID})
    dcmgr.unload(UID) -- 卸载玩家数据
    CLIENT_FD = nil
    SUBID  = nil
    SECRET = nil
    msgIdx = 0
    -- if table.empty(cluster_desk) then
        UID = nil
        gate = nil
        ChannelID = 5
    -- end

end

local function logout(isjihao)
    if getLogoutFlag() then
        return false
    end
    setLogoutFlag(true)
    pcall(logout_do, isjihao)
    CMD.exit()
    return true
end

-- 初始化模块的UID
local function initModuleUID(uid)
    for _, m in pairs(module_list) do
        if m['initUid'] then
            m['initUid'](uid)
        end
    end
end

--- 获取超级大奖配置
function CMD.getSuperRewardByGameId(gameId)
    -- return jackpot.getGameJackpotByGameId(gameId)
end

--检查是否有房间
function handle.checkhasdesk()
    if nil==cluster_desk or table.empty(cluster_desk) then
        return false
    end
    return true
end

function handle.setTishenState()
    isiOSCheck = true
end

function handle.isTiShen()
    return isiOSCheck
end

-- 获取登录平台
function handle.getPlatForm()
    return PLATFORM
end

-- ios提审显示的游戏id列表
function handle.getTishenGameIDs()
    return {458,460,447,442,433,454,440,436,443,459,511,490}
end

function CMD.stdesk()
    if table.empty(cluster_desk) then
        return 0
    end
    return 1
end

--获取玩家桌子对象
function CMD.getClusterDesk()
    if not table.empty(cluster_desk) then
        return cluster_desk
    end
    return {}
end

--获取玩家桌子对象
function CMD.setClusterDesk(source, desk)
    LOG_INFO("setClusterDesk:", desk, "UID:", UID)
    cluster_desk = desk or {}
    handle.changeGstatus(1)
end

function handle.sendInviteMsg(content, stype)
    LOG_DEBUG("handle.sendInviteMsg", content, stype)
    skynet.send('.chat', 'lua', 'chat', UID, nil, nil, content, stype)
end

-- 发送房间邀请到聊天室
function CMD.sendInviteMsg(source, content, stype)
    LOG_DEBUG("sendInviteMsg", source, content, stype)
    handle.sendInviteMsg(content, stype)
end

local function disconnect_heart()
    LOG_INFO("disconnect_heart---- agentid:", skynet.self(), UID)
    --
    CMD.afk()
end

local function sendToClient(retobj)
    LOG_DEBUG("sendToClient FD:", CLIENT_FD, retobj)
    if CLIENT_FD ~= nil then
        local info
        if USE_PROTOCOL_MSGPACK then
            info = '00000000'.. MessagePack.pack(cjson.decode(retobj))
        else
            info = '00000000'.. MessagePack.pack(retobj)
        end
        wbsocket:send_binary(CLIENT_FD, info)
    end
end

local function syncLobbyInfo()
    handle.moduleCall("player","syncLobbyInfo",UID)
end

--通知用户可以领取在线大转盘奖励了
local function getTurntableReward()
    if nil == UID then
        return
    end
    LOG_DEBUG("wsmsgagent in getTurntableReward call player UID:", UID)
    player.syncLobbyInfo(UID)
end

--登录后直接检查在线大转盘倒计时奖励
local function checkTurntable()
    if nil == UID then
        return
    end
    if autoTurntableFunc then
        autoTurntableFunc()
    else
        local cacheKey = "turntable:" .. UID
        local ok, configmgr = pcall(cluster.call, "master", ".configmgr", 'get', "turntable")
        local conf = cjson.decode(configmgr.v)

        local turntableCacheData = do_redis({ "hgetall", cacheKey}) --玩家缓存的转盘领取数据
        turntableCacheData = make_pairs_table(turntableCacheData)
        local openTime, times, abortTime, resetTime
        if nil ~= turntableCacheData then
            times = turntableCacheData.times --这1轮的剩余次数
            openTime = turntableCacheData.openTime --领取开始的时间
            abortTime = turntableCacheData.abortTime
            resetTime = turntableCacheData.resetTime
        end

        if openTime == nil or times == nil then
            LOG_DEBUG("wsmsgagent rewardTurntable openTime nil timeout:", conf.delay, ' UID:', UID)
            handle.rewardTurntable(conf.delay * 100)
        else
            local nextTime = 0 --下一次领取时间
            local now = os.time()
            openTime = math.floor(openTime)
            --离线停止时间
            local spendTime = now - openTime
            if abortTime ~= nil and resetTime ~= nil then
                abortTime = math.floor(abortTime)
                resetTime = math.floor(resetTime)
                local t_1 = abortTime - openTime
                local t_2 = now - resetTime
                spendTime = t_1 + t_2
                -- 删除这俩数据
                do_redis({"hdel", cacheKey, "abortTime"})
                do_redis({"hdel", cacheKey, "resetTime"})
            end
            
            if spendTime >= conf.delay then
                LOG_DEBUG("wsmsgagent rewardTurntable call getTurntableReward() UID:", UID)
                getTurntableReward()
            else
                nextTime = conf.delay - (now - openTime)
                LOG_DEBUG("wsmsgagent rewardTurntable nextTime timeout:", nextTime, ' UID:', UID)
                handle.rewardTurntable(nextTime * 100)
            end
        end
    end
end

local function doUpdateTask()
    pcall(cluster.send, "master", ".userCenter", "updateBatchQuest", UID, {PDEFINE.QUESTID.DAILY.ONLINE}, 60) --没分钟更新一下
    -- 更新主线任务
    -- handle.moduleCall("maintask", "updateTask", UID, {{kind=PDEFINE.MAIN_TASK.KIND.OnlineTime, count=1}})
    -- 如果在游戏中，则算游戏时长
    if not table.empty(cluster_desk) then
        -- if cluster_desk.roomtype == PDEFINE.BAL_ROOM_TYPE.MATCH then
        --     handle.moduleCall("maintask", "updateTask", UID, {{kind=PDEFINE.MAIN_TASK.KIND.MatchGameTime, count=1}})
        -- elseif cluster_desk.roomtype == PDEFINE.BAL_ROOM_TYPE.PRIVATE then
        --     handle.moduleCall("maintask", "updateTask", UID, {{kind=PDEFINE.MAIN_TASK.KIND.PrivateGameTime, count=1}})
        -- end
    end
    updateQuestTask()
end

function updateQuestTask()
    -- autoUpdateQuestFunc = set_timeout(60 * 100, doUpdateTask)
end

local function updateOnlineQuest()
    if nil == UID then
        return
    end
    if autoUpdateQuestFunc then
        autoUpdateQuestFunc()
    else

        updateQuestTask()
    end
end

function CMD.packTaskAndVIP(_, tbl, count, totalcoin)
    handle.moduleCall("maintask", "updateTask", UID, tbl)

    return handle.moduleCall("upgrade","useVipDiamond", count) --积累vip经验值
end

function CMD.setSwitch(_, rtype, switch)
    -- 设置开关
    switch = switch or 0
    LOG_DEBUG('设置开关 setSwitch uid:', UID, ' rtype:', rtype, ' switch:', switch)
    handle.dcCall("user_data_dc","set_common_value", UID, rtype, switch)
    local info = nil
    if rtype == PDEFINE.USERDATA.COMMON.SWITCH_SENDER then
        info = {uid = UID, sender = switch}
    elseif rtype == PDEFINE.USERDATA.COMMON.SWITCH_GIFTCODE then
        info = {uid = UID, redem = switch}
    elseif rtype == PDEFINE.USERDATA.COMMON.SWITCH_REPORT then
        info = {uid = UID, report = switch}
    end
    if info then
        handle.syncUserInfo(info)
    end
end

function CMD.login(source, userinfo, sid, secret, deskAgent)
    local uid = userinfo.uid
    local clientid = userinfo.client_uuid
    local newcoin_para = userinfo.playercoin
    local token = userinfo.access_token
    local language = userinfo.language
    local deviceToken = userinfo.deviceToken
    local logintype = userinfo.logintype
    if language == nil then
        language = 1
    end
    gate   = source
    UID = math.floor(uid)
    SUBID  = sid
    SECRET = secret
    CLIENT_UUID = clientid
    newcoin = tonumber(newcoin_para) or 0
    TOKEN = token
    NOW_LANGUAGE = language
    ACCOUNT = userinfo.account
    PLATFORM = userinfo.platform
    Login_StartCounTime = os.time()
    if nil ~= deskAgent then
        CMD.setClusterDesk(source, deskAgent)
        pcall(cluster.call, cluster_desk.server, cluster_desk.address, "updateUserClusterInfo", UID, skynet.self())
    else
        cluster_desk = {}
    end

    if autoFuc then autoFuc() end
    autoFuc = set_timeout(heart_time, disconnect_heart)

    --登录就设置在线奖励倒计时
    if autoLoginFuc then
        autoLoginFuc() 
    end

    checkTurntable()
    updateOnlineQuest()
    -- 每次登陆重置折扣商品的时间
    -- do_redis({"del", "discountShop:uid:"..uid})
    do_redis({"del", "showmail:uid:"..uid})
    do_redis({ "hset", "turntable:" .. uid, "resetTime", os.time(), true})

    -- 延时一秒发
    set_timeout(1*100, syncLobbyInfo)

    if deviceToken ~= nil then
        DEVICE_TOKEN = deviceToken
    end
    if logintype ~= nil then
        LOGIN_TYPE = logintype
    end
    LOG_INFO("wsmsgagent CMD.login uid:", uid, " secret:", secret, " subid:", sid, ' agentid:', skynet.self(), " deskAgent:", deskAgent, " language:", language, " ACCOUNT:", ACCOUNT)
end

function CMD.logout()
    if nil == UID then
        LOG_ERROR("wsmsgagent CMD.logout UID is nil")
        return true
    end

    LOG_INFO("wsmsgagent CMD.logout UID:", UID, " agentid:", skynet.self())
    do_redis({ "hset", "turntable:" .. UID, "abortTime", os.time(), true})
    dcmgr.user_data_dc.set_common_value(UID, PDEFINE.USERDATA.COMMON.LASTLOGOUTTIME, os.time())

    return logout()
    --collectgarbage("collect")
end

function autoExit()
    collectgarbage("collect")
    skynet.exit()
end

function CMD.exit()
    LOG_INFO("wsmsgagent CMD.exit agentid:", skynet.self())
    if autoFuc then autoFuc() end
    if autoLoginFuc then autoLoginFuc() end
    if autoTurntableFunc then autoTurntableFunc() end
    skynet.timeout(5000, autoExit) --主要作用是等当前消息处理完成 下一次处理来exit
end

local function recycleDeskAgent()
    pcall(cluster.call, cluster_desk.server, cluster_desk.address, "resetDesk")
end

function CMD.afk(_)
    LOG_INFO("CMD.afk uid:", UID, "agentid:", skynet.self())
    if UID == nil then
        return
    end
    local user_data = dcmgr.user_dc.get(UID)
    if user_data then
        -- 退出中心管理服务器
        if cluster_desk then
            if not table.empty(cluster_desk) then
                local temp_gameid = math.floor(cluster_desk.gameid/100)
                local ok = pcall(cluster.call, cluster_desk.server, cluster_desk.address, "offline",2,UID)
                if temp_gameid == 1 or temp_gameid >= 4 then
                    skynet.send(".statistics", "lua", "expExitG", temp_gameid, UID)
                    recycleDeskAgent()
                    --skynet.timeout(10, recycleDeskAgent)
                end
                if not ok then
                    CMD.deskBack(_, cluster_desk.gameid)
                end
            end
        end
    else
        LOG_WARNING("CMD.afk user_data is nil")
    end
    online = false
    CMD.logout()
end

function CMD.setUserCardType(_, gameid, multi, count)
    if cluster_desk and not table.empty(cluster_desk) then
        if cluster_desk.gameid == 12 then
            pcall(cluster.call, cluster_desk.server, cluster_desk.address, "setUserCardType",multi, count, UID)
        end    
    end
end

local function triggerMail(ctype, tpl) 
    local ok
    if nil == tpl then
        ok, tpl = pcall(cluster.call, "master", ".configmgr", "getMailTPL", ctype)
    else
        ok = true
    end
    if ok and nil ~= tpl then
        local mailInfo = {
            title = tpl.title,
            msg = tpl.content,
            title_al = '',
            msg_al = '',
            attach = {},
            rate = tpl.rate,
            svip = tpl.svip,
        }
        if tpl.coin ~= nil and tpl.coin > 0 then
            mailInfo.attach = {
                type = PDEFINE.PROP_ID.COIN,
                count = tpl.coin
            }
        end
        handle.sendBuyOrUpGradeEmail(mailInfo, ctype)
    end
end

function CMD.addInviteCount(_, uid)
    handle.dcCall("user_dc", "user_addvalue", UID, "invitednum", 1)
    local invitednum = handle.dcCall("user_dc", "getvalue", UID, "invitednum")
    if tonumber(invitednum) == 1 then
        triggerMail(PDEFINE.MAIL_TYPE.FIRSTAGENT) 
    end
    local info = {
        invits = 1
    }
    handle.syncUserInfo(info)
end

-- 判断可转金额是否大于cash bonus了
local function getDiffCashBonus(uid, addCoin)
    local playerInfo = handle.moduleCall("player","getPlayerInfo",uid)
    local gamebonus = tonumber(playerInfo.gamebonus or 0)
    local svip = tonumber(playerInfo.svip or 0)
    local cashbonus = tonumber(playerInfo.cashbonus or 0)
    local tranedBonus = tonumber(playerInfo.dcashbonus or 0)
    local ok, vipCfgList  = pcall(cluster.call, "master", ".configmgr", 'getVipUpCfg')
    if vipCfgList[svip] and vipCfgList[svip].tranrate > 0 then
        local rate = vipCfgList[svip].tranrate
        local hadBonus = math.round_coin((rate * math.abs(gamebonus)) - tranedBonus) -- (累计gamebonus - 已转的)
        local shouldAddCoin = math.round_coin(rate * addCoin)
        -- LOG_DEBUG("hadBonus:", hadBonus , ' shouldAddCoin:', shouldAddCoin, ' cashbonus:', cashbonus)
        if (hadBonus + shouldAddCoin) > cashbonus then
            local leftbonus = (cashbonus + tranedBonus)/rate - gamebonus
            -- LOG_DEBUG("leftbonus:", leftbonus, ' (cashbonus + tranedBonus)/rate:', ((cashbonus + tranedBonus)/rate), ' gamebonus:', gamebonus)
            return math.round_coin(leftbonus)
        end
    end
    if nil == vipCfgList[svip] or  vipCfgList[svip].tranrate == 0 then
        return 0
    end
    return addCoin
end

-- 提现成功，增加次数
function CMD.addDrawTimes(_, uid, drawcoin)
    handle.dcCall("user_dc", "user_addvalue", UID, "drawsucctimes", 1)
    handle.dcCall("user_dc", "user_addvalue", UID, "drawsucccoin", drawcoin)
end

--Yono Games 打码方式
function CMD.recordWinnings(_, betcoin, wincoin, maxGameDrawCoin)
    LOG_DEBUG('recordWinnings uid:', UID, ' betcoin:', betcoin, ' wincoin:', wincoin )
    if wincoin >= 0 then
        if wincoin > betcoin then
            local diffcoin = math.round_coin(wincoin-betcoin)
            
            if maxGameDrawCoin > 0 then
                local gamedraw        = handle.dcCall("user_dc", "getvalue", UID, "gamedraw")
                local ispayer         = handle.dcCall("user_dc", "getvalue", UID, "ispayer")
                local totalDrawTimes  = handle.dcCall("user_dc", "getvalue", UID, "drawsucctimes")
                ispayer        = tonumber(ispayer or 0)
                totalDrawTimes = tonumber(totalDrawTimes or 0)
                gamedraw       = tonumber(gamedraw or 0)
                if ispayer == 0 and (gamedraw + diffcoin) > maxGameDrawCoin then
                    diffcoin = math.round_coin(maxGameDrawCoin-gamedraw)
                end
                if ispayer == 0 and totalDrawTimes > 0 then --未充值的会员，提现1次之后，不再累计
                    return
                end
            end
            handle.dcCall("user_dc", "user_addvalue", UID, "gamedraw", diffcoin)
        elseif wincoin < betcoin then
            local diffcoin = math.round_coin(betcoin - wincoin)
            local addcoin = getDiffCashBonus(UID, diffcoin)
            LOG_DEBUG('recordWinnings1 uid:', UID, ' addcoin:', addcoin, ' diffcoin:', diffcoin)
            if addcoin > 0 then
                handle.dcCall("user_dc", "user_addvalue", UID, "gamebonus", addcoin)
            end
        end
    elseif wincoin < 0 then
        local diffcoin = math.round_coin(betcoin + math.abs(wincoin))
        local addcoin = getDiffCashBonus(UID, diffcoin)
        LOG_DEBUG('recordWinnings2 uid:', UID, ' addcoin:', addcoin, ' diffcoin:', diffcoin)
        if addcoin > 0 then
            handle.dcCall("user_dc", "user_addvalue", UID, "gamebonus", addcoin)
        end
    end
end

-- Rummy Vip 打码方式
function CMD.recordWinningsRummyVip(_, betcoin, wincoin, params)
    LOG_DEBUG('recordWinningsRummyVip uid:', UID, ' betcoin:', betcoin, ' wincoin:', wincoin )
    -- 增加可提金额
    local coin = math.round_coin(betcoin)
    if wincoin < 0 then
        coin = math.round_coin(math.abs(wincoin))
    end
    handle.dcCall("user_dc", "user_addvalue", UID, "gamedraw", coin)

    -- 增加可转金额
    if wincoin >= 0 then
        if wincoin < betcoin then
            local diffcoin = math.round_coin(betcoin - wincoin)
            local addcoin = getDiffCashBonus(UID, diffcoin)
            LOG_DEBUG('recordWinnings1 uid:', UID, ' addcoin:', addcoin, ' diffcoin:', diffcoin)
            if addcoin > 0 then
                handle.dcCall("user_dc", "user_addvalue", UID, "gamebonus", addcoin)
            end
        end
    elseif wincoin < 0 then
        local diffcoin = math.round_coin(betcoin + math.abs(wincoin))
        local addcoin = getDiffCashBonus(UID, diffcoin)
        LOG_DEBUG('recordWinnings2 uid:', UID, ' addcoin:', addcoin, ' diffcoin:', diffcoin)
        if addcoin > 0 then
            handle.dcCall("user_dc", "user_addvalue", UID, "gamebonus", addcoin)
        end
    end

    if params.check_stop > 0 then
        local userInfo = handle.moduleCall("player","getPlayerInfo",UID)
        local ckrechargecoin = tonumber(userInfo.ckrechargecoin or 0) * params.check_recharge
        local cksendcoin = tonumber(userInfo.cksendcoin or 0) * params.check_discount
        local gamedraw = tonumber(userInfo.gamedraw or 0)
        local diffcoin = ckrechargecoin + cksendcoin - gamedraw --稽核差额
        if (ckrechargecoin > 0 or cksendcoin > 0) and (userInfo.coin or 0 <= params.check_stop or diffcoin <= params.check_stop) then
            local updata = {
                ckrechargecoin = 0,
                cksendcoin = 0,
            }
            handle.dcCall("user_dc", "setvalue", UID, updata)
        end
    end
end

function CMD.suspendAgent(_, uid)
    local suspendAgent = handle.dcCall("user_dc", "getvalue", UID, "suspendagent")
    if suspendAgent == 1 then
        suspendAgent = 0
    else
        suspendAgent = 1
    end
    handle.dcCall("user_dc", "setvalue", UID, "suspendagent", suspendAgent)
end

function CMD.updateRaceStatus(_, msg)
    if cluster_desk and not table.empty(cluster_desk) then
        pcall(cluster.call, cluster_desk.server, cluster_desk.address, "updateRaceStatus", msg)  
    end
end

--后台获取用户信息
function CMD.apiUserInfo()
    local playerInfo = handle.moduleCall("player","getPlayerInfo",UID)
    if nil == playerInfo then
        return PDEFINE.RET.ERROR.CALL_FAIL
    end
    playerInfo.gameid = 0
    playerInfo.deskid = 0
    if cluster_desk then
        playerInfo.gameid = cluster_desk.gameid
        playerInfo.deskid = cluster_desk.deskid
    end
    return PDEFINE.RET.SUCCESS, playerInfo
end

function CMD.getGameDraw(_, uid)
    local coin = handle.dcCall("user_dc", "getvalue", uid, "gamedraw")
    return tonumber(coin or 0)
end

function CMD.updateGameDraw(_, uid, beforeCoin, alterCoin)
    local gamedraw = CMD.getGameDraw(_, uid)
    if (beforeCoin - gamedraw) < math.abs(alterCoin) then
        local leftAlterCoin = math.abs(alterCoin) - (beforeCoin - gamedraw) --应该从可提现里扣多少
        leftAlterCoin = -1 * leftAlterCoin
        if (gamedraw + leftAlterCoin) < 0 then
            leftAlterCoin = -gamedraw
        end
        LOG_DEBUG("uid:", uid, " user_addvalue gamedraw", leftAlterCoin)
        handle.dcCall("user_dc", "user_addvalue", uid, "gamedraw", leftAlterCoin) 
    end
end

function CMD.syncWallet(_, uid)
    local coin = handle.dcCall("user_dc", "getvalue", uid, "coin")
    coin = tonumber(coin or 0)
    local gamedraw = handle.dcCall("user_dc", "getvalue", uid, "gamedraw")
    gamedraw = tonumber(gamedraw or 0)
    local dcoin = gamedraw
    if dcoin < 0 then
        dcoin = 0 --可提现金额
    end
    if dcoin > coin then
        dcoin = coin --可提现金额 不能超过现金余额
    end
    local info = {
        uid = uid,
        coin = coin,
        dcoin = dcoin, --可提现金额
        ecoin = math.round_coin(coin - dcoin) --不可提金额
    }
    handle.syncUserInfo(info)
end

function CMD.updateGameDrawInDraw(_, uid, alterCoin, transferAmount, orderid)
    local gamedraw = CMD.getGameDraw(_, uid)

    if (gamedraw + alterCoin) < 0 then
        alterCoin = -gamedraw
    end
    LOG_DEBUG("uid:", uid, " user_addvalue gamedraw", alterCoin)
    handle.dcCall("user_dc", "user_addvalue", uid, "gamedraw", alterCoin) 
    if nil~=transferAmount and transferAmount > 0 then
        player.transferCash2Bonus(uid, transferAmount, orderid, nil, true)
    end
    return PDEFINE.RET.SUCCESS
end

function CMD.updateGameDrawAndCoin(_, uid, alterCoin, orderid, remark)
    LOG_DEBUG('updateGameDrawAndCoin:', uid, ' alterCoin:',alterCoin, ' orderid:', orderid)
    local ret1 = handle.addProp(PDEFINE.PROP_ID.COIN, alterCoin, DRAW_RETURN, '', remark)
    if ret1 ~= PDEFINE.RET.SUCCESS then
        LOG_DEBUG('updateGameDrawAndCoin addProp failed. uid:', uid, ' coin:', alterCoin)
        return ret1
    end

    local coin = handle.dcCall("user_dc", "getvalue", uid, "coin")
    handle.notifyCoinChanged(coin, 0, alterCoin, 0)

    local ret2 = CMD.updateGameDrawInDraw(_, uid, alterCoin)
    if ret2 ~= PDEFINE.RET.SUCCESS then
        LOG_DEBUG('updateGameDrawAndCoin updateGameDrawInDraw failed. uid:', uid, ' coin:', alterCoin)
        return ret2
    end

    CMD.syncWallet(_, uid)
    
    if nil ~= orderid then
        player.transferBonus2Cash(uid, orderid)
    end

    return PDEFINE.RET.SUCCESS
end

-- 离线事件处理
local function offlineCmd(offlineTable)
    if nil == UID then
        return
    end
    local sql = "select id,cmd,param from "..offlineTable.." where uid="..UID
    local rs = do_mysql_direct(sql)
    local ids = {}
    for _,data in pairs(rs) do
        if nil == UID then
            break
        end
        local f = OFFLINE[data.cmd]
        LOG_DEBUG("OFFLINE. UID:",UID, " data.cmd:",data.cmd,"data.param:",data.param)
        if not f then
            LOG_ERROR(string.format("unknown cmd %s", data.cmd))
        else
            local params = string.split(data.param, "|")
            -- LOG_DEBUG("OFFLINE. data.cmd:",data.cmd,"params:",params)
            f(table.unpack(params))
        end
        table.insert(ids, data.id)
    end
    if #rs > 0 and not table.empty(ids) then
        sql = "delete from "..offlineTable.." where id in (".. table.concat(ids,",")  ..")"
        LOG_INFO(sql)
        do_mysql_direct(sql)
    end
end

function handle.offlineCmd()
    offlineCmd("d_offline_multi_cmd")
end


-- 心跳包续传可继续加入中心服
local function heartBeat()
    if autoFuc then autoFuc() end
    if not online then
        if not table.empty(cluster_desk) then
            pcall(cluster.call, cluster_desk.server, cluster_desk.address, "offline",1,UID)
        end
        online = true
    end
    autoFuc = set_timeout(heart_time,disconnect_heart)
end

--获取玩家join到master的信息
function CMD.getUser2MasterInfo()
    local cluster_info = {server = NODE_NAME, address = skynet.self(), gateaddress = gate}
    local user_data = dcmgr.user_dc.get(UID) 
    if user_data == nil then
	LOG_DEBUG("yrp user_data == nil")
        return PDEFINE.RET.ERROR.PLAYER_NOT_FOUND
    end
    return PDEFINE.RET.SUCCESS, {cluster_info = cluster_info, data = user_data}
end

--获取这个用户从加载以来是否发送过joinplayer给master
function CMD.getIsjoinPlayer2Master( ... )
    return isjoinPlayer2Master
end

local function initChannel(uid)
    if not uid then return end
    local appid = do_redis({"get", "appid_" .. uid})
    if appid then
        ChannelID = math.floor(appid)
    end
end

-- 登录的时候初始化默认语言(未登录前用户已选定语言)
local function iniLanguage(uid)
    if not uid then return end
    local ok, loginData = pcall(cluster.call, "master", ".userCenter", "getOnlineData", uid)
    if ok and loginData then
        BUNDLEID = loginData.bundleid
        local client_uuid = loginData.client_uuid
        if client_uuid then
            local lang = do_redis({ "get", client_uuid})
            if lang then
                handle.changeLanguage(tonumber(lang))
            end
        end
        if loginData.logintype and loginData.logintype == PDEFINE.LOGIN_TYPE.FB then
            handle.moduleCall("quest", 'updateQuest', uid, PDEFINE.QUEST_TYPE.NEWER, PDEFINE.QUESTID.NEW.LINKFB, 1)
        end
    end
end

function CMD.loaduser( _, fd, ip )
    LOG_DEBUG("CMD loaduser:", TOKEN, UID, fd, ip)
    if isLogout or not UID then
        LOG_WARNING("loaduser user is logout", UID)
        delDealMsgCount()
        return
    end
    GSTATUS = 0
    dcmgr.load(UID) -- 加载玩家数据
    local user_data = dcmgr.user_dc.get(UID)
    if user_data and not table.empty(user_data) then
        --注意  下面joinPlayer 必须最开始执行，牵扯到金币修改对queue的锁
        LOG_INFO("loaduser master_userCenter joinPlayer: ", UID)
        local code,user2masterdata = CMD.getUser2MasterInfo()
        pcall(cluster.send, "master", ".userCenter", "joinPlayer", user2masterdata.cluster_info, user2masterdata.data)
        isjoinPlayer2Master = true

        local login_time = user_data.login_time
        if nil ~= login_time then
            local dt = date.DiffDay(os.time(),login_time)
            if dt > 0 then --重置隔日任务
                local up = {}
                up["daytime"]     = 0
                -- up["onlinestate"] = 1
                up["curonlinejd"] = 1
                up["lrwardstate"]= 0
                handle.dcCall("user_dc", "setvalue", UID, up, nil)
                handle.moduleCall("quest","reset",UID)

                local ok, tpl = pcall(cluster.call, "master", ".configmgr", "getMailTPL", PDEFINE.MAIL_TYPE.LOGINBACK)
                if ok and nil ~= tpl then
                    if dt > tonumber(tpl.param1) then --再次登录超过N天
                        triggerMail(PDEFINE.MAIL_TYPE.LOGINBACK, tpl)
                    end
                end
            end
        end
        user_data.token = TOKEN --修改token值

        local updata = {
            token = TOKEN,
            login_time = os.time(),
            onlinestate = 1,
        }
        if DEVICE_TOKEN then
            updata.deviceToken = DEVICE_TOKEN
        end
        if LOGIN_TYPE then
            updata.logintype = LOGIN_TYPE
        end
        handle.dcCall("user_dc", "setvalue", UID, updata)

        mailbox.addSystemMail(UID) --系统邮件
    else
        LOG_WARNING("loaduser user_data is nil", UID)
    end

    if autoFuc then 
        autoFuc() 
    end
    autoFuc = set_timeout(heart_time, disconnect_heart)

    if not table.empty(cluster_desk) then
        pcall(cluster.send, cluster_desk.server, cluster_desk.address, "offline",1,UID) --上线
    end

    initChannel(UID)

    iniLanguage(UID)

    delDealMsgCount()

    LOG_INFO("CMD loaduser finish", UID)
end

function CMD.connect(sth, fd, ip)
    if not addDealMsgCount() then
        return
    end
    LOG_INFO("agent connect UID: ", UID, ' agentid:', skynet.self(), "fd:", fd)
    online = true
    CLIENT_FD = fd
    IP = ip

    initModuleUID(UID)
    --CMD.getuserqueue(sth, "", "loaduser", fd, ip)
    CMD.loaduser(_, fd, ip)
end

function CMD.getuserqueuebak( sth, func )
    local modname = func.modparam.modname
    local modfuc = func.modparam.modfuc
    if modname == "" then
        --本地方法
        return CMD[modfuc](sth, table.unpack(func.func_param))
    else
        --模块方法
        return handle.moduleCall(modname, modfuc, table.unpack(func.func_param))
    end
end

function CMD.getuserqueue(_, modname, modfuc, ...)
    if modname == nil then
        modname = ""
    end
    local func = {
        iscluster = true, 
        node = NODE_NAME, 
        addr = skynet.self(), 
        fuc_name= "getuserqueuebak", 
        func_param = {...}, 
        modparam = {modname = modname, modfuc = modfuc}
    }
    return pcall(cluster.call, "master", ".userCenter", "alterUserQueue", UID, func)
end

function CMD.create()
    if not addDealMsgCount() then
        return
    end
    local user_data = dcmgr.user_dc.get(UID)
    if nil~=user_data and not table.empty(user_data) then
        local code,user2masterdata = CMD.getUser2MasterInfo()
        -- 加入中心管理服务器
        pcall(cluster.call, "master", ".userCenter", "joinPlayer", user2masterdata.cluster_info, user2masterdata.data)
    end
    delDealMsgCount()
end

function CMD.kick(_, clientid)
    local islogout = true
    kicking = true
    LOG_INFO("wsmsgagent CMD.kick UID:", UID, " clientid:", clientid, " CLIENT_UUID:", CLIENT_UUID, " agentid:", skynet.self())

    if clientid == nil or clientid ~= CLIENT_UUID then
        local retobj    = {}
        retobj.code     = PDEFINE.RET.SUCCESS
        retobj.c        = PDEFINE.NOTIFY.otherlogin
        retobj.spcode   = PDEFINE.NOTIFY.otherlogin
        retobj.uid      = UID
        sendToClient(cjson.encode(retobj))
        LOG_INFO("notify otherlogin:", UID)
    end
    if nil ~= UID then
        islogout = logout(true)
    end
    kicking = false
    return islogout
end

function CMD.resetMaintask(_, uid)
    handle.moduleCall("maintask","reset",uid)
end

-- 每周重置
function CMD.adminWeeklyReset(_)
    dcmgr.user_data_dc.clear(UID, "WEEKLY")
end

-- 通知
function CMD.sendToClient(_, info)
    -- LOG_DEBUG("-----------------------------------------------------------------agentid:", skynet.self())
    sendToClient(info)
    return true
end

--后端推送公告弹窗到客户端，可能指定的svip等级才能收到
function CMD.sendNoticeToClient(_, info, svipArr)
    if nil ~= svipArr and table.size(svipArr) > 0 then
        local userSvip = handle.dcCall("user_dc", "getvalue", UID, "svip")
        if table.contain(svipArr, userSvip) then --指定的支付vip等级才能收到弹框
            sendToClient(info)
        end
    else
        sendToClient(info)
    end
end

--检查是否语言相符 并通知
function CMD.sendToClientCheckLan(_, language, info )
    if not handle.isTiShen() then
        if tonumber(NOW_LANGUAGE) == language then
            sendToClient(info)
        end
    end
end

-- 退出桌子
function CMD.deskBack(_, gameid, deskid)
    if nil ~= gameid and nil~=cluster_desk and nil ~= cluster_desk.gameid and math.floor(gameid) == math.floor(cluster_desk.gameid) then
        LOG_INFO("deskBack UID:", UID, "agentid:", skynet.self(), "gameid:", gameid, "cluster_desk:", cluster_desk)
        local desk_id = cluster_desk["desk_id"]
        if not deskid or deskid == desk_id then
            cluster_desk = {}
            handle.changeGstatus(0)
        else
            LOG_WARNING("deskBack deskid not equal, UID:", UID, "gameid:", gameid, "deskid: ", deskid, "cluster_desk:", cluster_desk)
        end
        if UID then
            pcall(cluster.send, "master", ".agentdesk", "removeDesk", UID, desk_id)
        end
    else
        LOG_WARNING("deskBack gameid not equal, UID:", UID, "gameid:", gameid, "cluster_desk:", cluster_desk)
    end
end

-- 退出桌子
function CMD.deskBackByName(_, servername)
    if servername == cluster_desk.server then
        LOG_INFO("deskBackByName UID:", UID, "servername:", servername, "cluster_desk:", cluster_desk)
        local desk_id = cluster_desk["desk_id"]
        cluster_desk = {}
        pcall(cluster.send, "master", ".agentdesk", "removeDesk", UID, desk_id)
    else
        LOG_WARNING("deskBackByName servername not equal, UID:", UID, "servername:", servername, "cluster_desk:", cluster_desk)
    end
end

--切换桌子
function CMD.deskSwitch(_, gameid, ssid)
    if cluster_desk.gameid==nil or (math.floor(gameid) == math.floor(cluster_desk.gameid)) then
        LOG_INFO("deskSwitch UID:", UID, "old cluster_desk:", cluster_desk)
        local desk_id = cluster_desk.desk_id
        cluster_desk = {}
        handle.changeGstatus(0)
        pcall(cluster.call, "master", ".agentdesk", "removeDesk", UID, desk_id)

        local cluster_info = { server = NODE_NAME, address = skynet.self()}
        local recvobj = {c= 43, uid = UID, gameid = gameid, ssid = ssid}
        local retok, retcode, retobj, deskAddr = pcall(cluster.call, "master", ".mgrdesk", "matchSess", cluster_info, recvobj, IP)
        if retok and retcode == 200 then
            cluster_desk = deskAddr or {}
        else
            LOG_INFO("deskSwitch matchSess fail, retok:"..(retok and 1 or 0).." retcode:"..retcode)
            retobj = {}
        end
        retobj.c = PDEFINE.NOTIFY.NOTIFY_SWITCH_DESK
        retobj.code = retcode or PDEFINE.RET.UNDEFINE
        retobj.gameid = gameid
        sendToClient(cjson.encode(retobj))
        LOG_INFO("deskSwitch UID:", UID, "new cluster_desk:", cluster_desk)
    else
        LOG_WARNING("deskSwitch gameid not equal, UID:", UID, "gameid:", gameid, "cluster_desk:", cluster_desk)
    end
end

-- 远程节点调用模块
function CMD.clusterModuleCall(_, module, fun, ...)
    -- print("module:")
    -- print(module)
    -- print("fun")
    -- print(fun)
    return module_list[module][fun](...)
end

function CMD.clusterDcCall(_, dc, fun, ...)
    return handle.dcCall(dc, fun, ...)
end

-- --有新邮件
function CMD.addMail(_, mail)
    assert(mail)
    mailbox.addMail(UID, mail)
end

function CMD.addRandomStampPackage(_)
    return stamp.addRandomStampPackage(UID)
end

-- 增加rp值
-- 如果是双倍时间，就奖励双倍
-- DOMINO玩法、HAND、HAND SAUDI玩法获胜后增加150RP值，BALOOT、TARNEEB 玩法获胜后增加100RP值。
function CMD.addRp(_, rp)
    handle.addProp(PDEFINE.PROP_ID.RP, rp)
end

function CMD.notifySystemMail(_, delay)
    skynet.timeout(delay, function()   --延时操作，防止群发时并发太大
        mailbox.addSystemMail(UID) --系统邮件
        local retobj = {c = PDEFINE.NOTIFY.NOTIFY_MAIL, code=PDEFINE.RET.SUCCESS, uid = UID}
        handle.sendToClient(cjson.encode(retobj))
    end)
end

--同步排位赛开启了或关闭了给客户端
function CMD.notifyLeagueState(_, isopen, stopTime)
    LOG_DEBUG("notifyLeagueState isopen:", isopen)
    if not table.empty(cluster_desk) then
        LOG_DEBUG("notifyLeagueState  in game uid:", UID, " isopen:", isopen)
        local isSignup = 0 --1:已经报名，0：未报名
        local cacheKey = PDEFINE.LEAGUE.SIGN_UP_KEY.. UID
        local signed = do_redis({"get", cacheKey})
        signed = tonumber(signed or 0)
        if signed > 0 then
            isSignup = 1
        end
        local retobj = {c = PDEFINE.NOTIFY.LEAGUE_STATUS, code=PDEFINE.RET.SUCCESS, uid = UID, isopen = isopen, signed=isSignup, stopTime=stopTime}
        handle.sendToClient(cjson.encode(retobj))
    end
end

function CMD.stopRegRebat(_, val)
    val = tonumber(val or 0)
    handle.dcCall("user_dc", "setvalue", UID, 'stopregrebat', val)
end

--修改绑定信息
function CMD.apiUpdateBindInfo(_, uid, field)
    local field_type = {'bindbank','bindusdt','bindupi','isbindphone','kyc'}
    LOG_DEBUG('apiUpdateBindInfo uid:', uid, ' field:', field)
    for k, item in pairs(field_type) do
        if item == field then
            handle.dcCall("user_dc", "setvalue", uid, item, 1)
            LOG_DEBUG('apiUpdateBindInfo syncUserInfo uid:', uid, ' field:', field)
            local syncData = {uid = UID}
            if field == 'bindbank' then
                syncData['bindbank'] = 1
            elseif field == 'bindusdt' then
                syncData['bindusdt'] = 1
            elseif field == 'bindupi' then
                syncData['bindupi'] = 1
            elseif field == 'isbindphone' then
                syncData['isbindphone'] = 1
            elseif field == 'kyc' then
                syncData['kyc'] = 1
            end
            handle.syncUserInfo(syncData)
        end
    end
end

-- 后台给用户加属性值
function CMD.apiAddUserProperty(_, type, num)
    if type =='points' then
        handle.addProp(PDEFINE.PROP_ID.PALACE_POINT, num, 'admin')
    elseif type == 'diamond' then
        handle.addProp(PDEFINE.PROP_ID.DIAMOND, num, 'admin')
    elseif type == 'charm' then
        handle.addProp(PDEFINE.PROP_ID.CHARM, num, 'admin')
    elseif type == 'rp' then
        handle.addProp(PDEFINE.PROP_ID.RP, num, 'admin')
    end
end

-- 完成每日特殊任务
function CMD.updateSpecialQuest(_, uid, type, num)
    handle.moduleCall("quest", "updateSpecialQuest", uid, type, num)
end

-------- 是否在创建猜拳的白名单中(可以不用绑定fb) --------
local function isInWhiteList(uid, type)
	local result = false
    local key
    if type == "FB" then
        key = "nofblist"
    end
	local ok, filterItem = pcall(cluster.call, "master", ".configmgr", "get", key)
	if ok and not table.empty(filterItem) then
		local filterList = string.split(filterItem.v, ',')
        for _, setuid in pairs(filterList) do
            LOG_INFO(" setuid vs uid:", setuid, uid)
			if tonumber(setuid) == tonumber(uid) then
				result = true 
				break
			end
		end
	end
	return result
end

--把用户从大厅列表中删除
local function delUidFromHall(uid)
    pcall(cluster.send, "master", ".userCenter", "removeHall", math.floor(uid))
end

-- 远程调用游戏模块接口
local function clusterGameModuleCall(f_method,recvobj)
    -- 调用远程服务
    local cluster_info = { server = NODE_NAME, address = skynet.self()}
    local retok, retcode, retobj, deskAddr
    local cluster_name, cluster_service, cluster_method = f_method:match("([^.]+).([^.]+).(.+)")
    recvobj.uid = UID --指定uid
    local msg = cjson.encode(recvobj)
    -- 判断是否创建房间
    if cluster_method == "createDeskInfo" then
        local gameid = math.floor(recvobj.gameid)
        local ok, gameName = pcall(cluster.call, "master", ".mgrdesk", "getGameName", gameid)
        retok, retcode, retobj, deskAddr = pcall(cluster.call, gameName, ".dsmgr", cluster_method, cluster_info,msg,IP)
        if retcode == 200 then
            cluster_desk = deskAddr or {}
            delUidFromHall(recvobj.uid)
        end
    elseif cluster_method == "joinDeskInfo" then
        retok, retcode, retobj, deskAddr = pcall(cluster.call, "master", ".mgrdesk", cluster_method, cluster_info,msg,IP)
        if retcode == 200 then
            cluster_desk = deskAddr or {}
            delUidFromHall(recvobj.uid)
        end
    elseif cluster_method == "matchSess" or cluster_method == "joinRace" then
        if flag then
            retok = true
            retcode = PDEFINE.RET.ERROR.JOINING_DESK
        end
        if cluster_desk and not table.empty(cluster_desk) then
            local ok,deskInfo = pcall(cluster.call, cluster_desk.server, cluster_desk.address, "getDeskInfo", recvobj)
            if ok and deskInfo and deskInfo.deskid ~= nil then
                retobj = retobj or {}
                retobj.code = PDEFINE.RET.SUCCESS
                retobj.gameid   = deskInfo.gameid
                retobj.deskinfo = deskInfo
                retok = true
                retcode = 200
                flag = false
                delUidFromHall(recvobj.uid)
            else
                LOG_INFO("matchSess getDeskInfo fail", UID)  -- 玩家已经不在房间里
                cluster_desk = {}
                pcall(cluster.call, "master", ".agentdesk", "removeDesk", UID)

                retok = true
                retcode = 200
                recvobj = {code=PDEFINE.RET.SUCCESS, gameid=0}
            end
        else
            local newplayercount = nil
            local gameid = math.floor(recvobj.gameid)
            flag = true
            if cluster_method == "joinRace" then
                retok, retcode, retobj, deskAddr = pcall(cluster.call, "master", ".raceroommgr", cluster_method, cluster_info, recvobj, IP, newplayercount)
            else
                retok, retcode, retobj, deskAddr = pcall(cluster.call, "master", ".mgrdesk", cluster_method, cluster_info, recvobj, IP, newplayercount)
            end
            flag = false
            if retcode == 200 then
                cluster_desk = deskAddr or {}
                delUidFromHall(recvobj.uid)
                handle.addStatistics(UID, 'entergame', 'match', gameid)
            end
        end
    elseif cluster_service == 'balmatchmgr' or cluster_service == 'balviproommgr' or cluster_service == 'tournamentmgr' or cluster_service == 'balprivateroommgr' or cluster_service == 'raceroommgr' then -- 匹配入口
        if cluster_method == "join" then
            if cluster_desk and not table.empty(cluster_desk) then --已经在游戏中
                retok = true
                retcode = 200
                retobj = {code=PDEFINE.RET.SUCCESS, res=3}
                delUidFromHall(recvobj.uid)
                return retok, retcode, retobj
            end
            local user_data = dcmgr.user_dc.get(UID)
            if user_data then
                recvobj.nick = user_data.playername
                recvobj.icon = user_data.usericon
                recvobj.coin = user_data.coin
            end
            handle.addStatistics(UID, 'entergame', 'salon', recvobj.gameid)
        end
        retok, retcode, retobj = pcall(cluster.call, cluster_name, "."..cluster_service, cluster_method, recvobj)
        if retobj then
            delUidFromHall(recvobj.uid)
        end
    else
        if not table.empty(cluster_desk) then
            local gameid = cluster_desk.gameid
            retok, retcode, retobj = pcall(cluster.call, cluster_desk.server, cluster_desk.address, cluster_method, recvobj)
            if retcode == 200 and cluster_method == "exitG" then
                handle.addStatistics(UID, 'exitgame', '', gameid)
            end
        else
            LOG_DEBUG("用户桌子信息为空啦 empty cluster_desk", UID)
            if cluster_method == "exitG" then --如果用户确实不在房间卡死在房间中,点退出照样给用户退出去
                retok = true
                retcode = 200
                pcall(cluster.call, "master", ".userCenter", "joinHall", UID)
            else
                retok = true
                -- retcode = 931
                retcode = PDEFINE_ERRCODE.ERROR.ROOM_NOT_EXIST
            end
        end
    end
    return retok, retcode, retobj
end

local function __TRACKBACK__(errmsg)
    local track_text = debug.traceback(tostring(errmsg), 6)
    print(track_text)
    LOG_ERROR(track_text)
    return false
end

--msg 是table
local function processClient(message)
    local begin = skynet.time()
    local recvobj = cjson.decode(message) --json object
    local cmd = math.floor(recvobj.c)
    local c_idx = recvobj.c_idx
    if 11 == cmd then
        heartBeat()
    end
    if 12 == cmd then --12退出游戏
        CMD.logout()
        return
    end
    if 2 == cmd then
        if autoFuc then autoFuc() end
        autoFuc = set_timeout(heart_time, disconnect_heart)
    end

    if kicking and (2 == cmd or 3 == cmd) then
        return cjson.encode({c= cmd, uid =UID, code=PDEFINE.RET.ERROR.FORBIDDEN, c_idx=c_idx})
    end

    if not recvobj then
        return cjson.encode({c= 400, uid =UID, code=408, c_idx=c_idx})
    end
    if 11 ~= cmd then --心跳包不带uid
        local uid = recvobj.uid
         uid = math.floor(uid)
        if not uid or uid ~= UID then
            LOG_ERROR("uid is not equal UID， uid:", uid, "UID:", UID)
            return cjson.encode({c= 11, code=408, c_idx=c_idx})
        end
    end

    local f = PDEFINE.PROTOFUN[tostring(cmd)]

    if f then
        local retok, retcode, retobj
        local f_module, f_method = f:match "([^.]*).(.*)"
        if f_module == "cluster" then
            -- 玩家前提条件判断
            retok, retcode, retobj = clusterGameModuleCall(f_method,recvobj)
        else
            -- 调用本地模块函数
            local m = module_list[f_module]
            if not m then
                LOG_ERROR(string.format("unknown module %s", f_module))
            else
                local deskAddr = nil
                retok, retcode, retobj, deskAddr = xpcall(
                        m[f_method], __TRACKBACK__, message, cluster_desk, skynet.self(), IP
                )
                if f_method == 'joinRoom' and deskAddr then
                    cluster_desk = deskAddr
                end
            end
        end
        local usedtime = skynet.time()-begin
        LOG_DEBUG(string.format("cmd: %d func: %s usedtime: %f retok: %s retcode: %s", cmd, f, usedtime, retok, retcode))
        -- 结果发包
        if retok then
            if tonumber(retcode) ~= 200 then
                local ret = retobj
                retobj = {c = cmd, code = retcode, c_idx = c_idx}
                if retcode == PDEFINE.RET.ERROR.CREATE_AT_THE_SAME_TIME then
                    retobj.gameid = ret
                elseif retcode == PDEFINE.RET.ERROR.GAME_SVIP_LOW then
                    retobj.minsvip = ret
                end
                return cjson.encode(retobj)
            end
            if retobj == nil then
                retobj = {c = cmd, code = retcode, c_idx = c_idx}
            else
                if type(retobj) == "string" then
                    local ok, tmp = pcall(jsondecode, retobj)
                    if not ok or type(tmp) ~= "table" then
                        tmp = {}
                    end
                    retobj = tmp
                elseif type(retobj) == "number" then
                    LOG_ERROR("cmd:"..cmd.." retobj:", recvobj)
                    local code = tonumber(retobj)
                    retobj = {code = code}
                end
                retobj.c = cmd
                retobj.c_idx = c_idx
                if nil == retobj.code then
                    retobj.code = PDEFINE.RET.SUCCESS
                end
                if retobj.code ~= PDEFINE.RET.SUCCESS then
                    if nil == retobj.spcode then
                        retobj.spcode = retobj.code
                        retobj.code = PDEFINE.RET.SUCCESS
                    end
                end
            end
            return cjson.encode(retobj)
        else
            LOG_ERROR(string.format("%s call_fail", cmd))
            return cjson.encode({c = cmd, uid = UID, code = 400, c_idx = c_idx})
        end
    else
        LOG_ERROR(string.format("%s no function", recvobj.c))
    end
end

function OFFLINE.resetMail(uid, mailid)
    handle.moduleCall("mailbox","resetMail",UID, mailid)
end

function OFFLINE.addMail(uid, mailstr)
    local ok, mail = pcall(jsondecode, mailstr)
    if ok then
        handle.moduleCall("mailbox","addMail",UID, mail)
    end
end

function OFFLINE.updateUserExp(uid, exp)
        -- 延迟执行，可能有些模块还没有加载成功
        handle.moduleCall("upgrade","bet",UID, tonumber(exp))
end

-- 离线后设置用户的开关, 38:赠送开发 39:举报，40:兑换码
function OFFLINE.setSwitch(rtype, switch)
    CMD.setSwitch(nil, rtype, switch)
end

function OFFLINE.upgradeVIP(count)
        handle.moduleCall("upgrade","useVipDiamond",count)
end

function OFFLINE.doMaintask(type, count)
    local updateMainObjs = {
        {kind=PDEFINE.MAIN_TASK.KIND.Pay, count=count},
    }
    handle.moduleCall("maintask", "updateTask", UID, updateMainObjs)
end

function OFFLINE.settleLeagueSendRewards(endtime, cnt)
    if tonumber(cnt) >=1 and tonumber(cnt) <=3 then
        local img = PDEFINE.SKIN.LEAGUE["TOP"..cnt].AVATAR.img
        local now = os.time()
        if endtime > now then
            endtime = endtime - now
            handle.moduleCall("upgrade","sendSkins",img, endtime, UID)
        end
    end
end

function OFFLINE.updateQuest(questid, count)
    handle.moduleCall("quest","updateQuest",UID, 1, tonumber(questid), tonumber(count))
end

function OFFLINE.reloadPlayerInfo(uid)
    handle.moduleCall("player","reloadPlayerInfo",UID)
end

function OFFLINE.resetLeagueInfo(uid, leagueInfo)
    local ok, update_data = pcall(jsondecode, leagueInfo)
    if ok then
        handle.moduleCall("player","setPersonalExp",UID, update_data)
    end
end

function OFFLINE.resetBankPasswd(uid, passwd)
    handle.moduleCall("bank","resetBankPasswd",UID, passwd)
end

-------- 协议2还在认证，协议3直接请求数据 导致直接注册 --------
function handle.dcLoad(uid)
    return dcmgr.load(uid)
end

function handle.dcCall(dc, fun, ...)
    local addrefer = addDealMsgCount()
    if not addrefer then
        LOG_DEBUG("adddealmsgcount dcCall offline dc:", dc, ' fun:', fun)
        -- return
    end
    local ret = dcmgr[dc][fun](...)
    if addrefer then
        delDealMsgCount()
    end
    return ret
end

function handle.moduleCall(module, fun, ...)
    local addrefer = addDealMsgCount()
    if not addrefer then
        LOG_DEBUG("adddealmsgcount moduleCall offline module:", module, ' fun:', fun)
        -- return
    end
    local ret = {module_list[module][fun](...)}
    if addrefer then
        delDealMsgCount()
    end
    return table.unpack(ret)
end

function handle.addProp(propid, propnum, act, contentStr, remark)
    local propType = math.floor(propid / PDEFINE.PROP_TYPE_FACTOR)
    if propType == PDEFINE.PROP_TYPE.COMMON then
        local txt = "玩家领取奖励:"..propnum
        if propid == PDEFINE.PROP_ID.COIN then
            local type = PDEFINE.ALTERCOINTAG.STAMPSHOP
            local type_special = PDEFINE.GAME_TYPE.SPECIAL.STAMPSHOP
            if act == 'shop' then
                type = PDEFINE.ALTERCOINTAG.NEWBIE
            elseif act == 'mail' then
                type = PDEFINE.ALTERCOINTAG.MAILATTACH
                txt = '邮件附件'
            elseif act == 'dailybonus' then
                type = PDEFINE.ALTERCOINTAG.DAILYBONUS
            elseif act =='turntable' then
                type = PDEFINE.ALTERCOINTAG.LUCK_TURNTABLE
            elseif act =='bindcode' then
                type = PDEFINE.ALTERCOINTAG.BINDCODE
            elseif act == 'questfb' then
                type = PDEFINE.ALTERCOINTAG.FBSHARE
            elseif act =='cdkey' then
                type = PDEFINE.ALTERCOINTAG.CDKEY
            elseif act == 'task' then
                type = PDEFINE.ALTERCOINTAG.MAIN_TASK
            elseif act == 'rp' then
                type = PDEFINE.ALTERCOINTAG.RP
            elseif act == 'league' then
                type = PDEFINE.ALTERCOINTAG.LEAGUE
            elseif act == 'rakeback' then
                type = PDEFINE.ALTERCOINTAG.RAKEBACK
            elseif act == 'tn_reward' then
                type = PDEFINE.ALTERCOINTAG.RAKEBACK
            elseif act == 'leaderboard' then
                type = PDEFINE.ALTERCOINTAG.LEADERBOARD
            elseif act == 'transfer' then
                type = PDEFINE.ALTERCOINTAG.BONUS_TRANSFER
            elseif act == DRAW_RETURN then
                type = PDEFINE.ALTERCOINTAG.DRAWRETURN
                txt = '拒绝提现:' .. propnum
            end
            if not isempty(remark) then
                txt = remark
            end

            local ok, code, altercoin_id, beforecoin, aftercoin = player_tool.calUserCoin_nogame(UID, propnum, txt, type, 0, PDEFINE.POOL_TYPE.none, false, false)
            if code ~= PDEFINE.RET.SUCCESS then
                LOG_ERROR("addProp funcAddCoin error", code, UID, propid, propnum)
                return code
            end
            if act ~= DRAW_RETURN then
                player.addSendCoinLog(UID, propnum, act)
            end
        elseif propid == PDEFINE.PROP_ID.DIAMOND then --钻石
            handle.dcCall("user_dc", "user_addvalue", UID, "diamond", propnum) --dc层直接加
            handle.moduleCall("player", "addDiamondLog", UID, propnum, 0, act, contentStr, remark)
            if propnum < 0 then --消耗钻石排行榜
                pcall(cluster.send, "master", ".winrankmgr", "updateDiamondOrRpRank", UID, math.abs(propnum), PDEFINE.RANK_TYPE.DIAMOND_WEEK)
                -- 更新主线任务
                -- local updateMainObjs = {
                --     {kind=PDEFINE.MAIN_TASK.KIND.UseDiamond, count=-1*propnum},
                -- }
                -- handle.moduleCall("maintask", "updateTask", UID, updateMainObjs)
            else
                handle.addDiamondInGame(propnum)
            end
        elseif propid == PDEFINE.PROP_ID.RP then --rp
            handle.dcCall("user_dc", "user_addvalue", UID, "rp", propnum) --dc层直接加
            if propnum > 0 then
                pcall(cluster.send, "master", ".winrankmgr", "updateDiamondOrRpRank", UID, propnum, PDEFINE.RANK_TYPE.RP_MONTH)
            end
            local curr_rp = handle.dcCall("user_dc", "getvalue", UID, "rp")
            handle.syncUserInfo({uid=UID, rp = curr_rp})
        elseif propid == PDEFINE.PROP_ID.CHARM then --魅力值
            handle.dcCall("user_dc", "user_addvalue", UID, "charm", propnum) --dc层直接加
        else
            LOG_ERROR("addProp unknown propid", UID, propid, propnum)
            return PDEFINE.RET.ERROR.PARAM_ILLEGAL
        end
    else
        LOG_ERROR("addProp unknown propid", UID, propid, propnum)
        return PDEFINE.RET.ERROR.PARAM_ILLEGAL
    end
    return PDEFINE.RET.SUCCESS
end

function handle.addProps(props, act)
    for _, prop in ipairs(props) do
        handle.addProp(prop.id, prop.num, act)
    end
end

function handle.setPlayerTmpData(key, value)
    tmp_data[key] = value
end

function handle.getPlayerTmpData(key, value)
    return tmp_data[key]
end

function handle.sendToClient(retobj)
    sendToClient(retobj)
end

function handle.getUid()
    return UID
end

function handle.notifyCoinChanged(totalCoin, totalDiamond, addCoin, addDiamond, addType, bankcoin)
    local retobj = {}
    retobj.c = PDEFINE.NOTIFY.coin
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.uid = UID
    retobj.deskid = 0
    retobj.count = addCoin --此次添加的金币
    retobj.coin = totalCoin --加玩后玩家身上的金币
    retobj.addDiamond = addDiamond or 0 --此次增加的钻石
    retobj.diamond = totalDiamond --加玩后，玩家身上的钻石
    if addType ~=nil then
        addType = addType or 1
        retobj.type = addType
    end
    retobj.rewards = {}
    -- if bankcoin == nil then
    --     local bankinfo = handle.dcCall("bank_dc","get", UID)
    --     bankcoin = bankinfo.coin
    -- end
    retobj.bankcoin = 0 --保险箱金额
    handle.sendToClient(cjson.encode(retobj))
end

-- 是华为渠道登录
function handle.isHuaWei()
    if ChannelID == PDEFINE.APPID.POKERHEROHUAWEI then
        return true
    end
    return false
end

function handle.getBundleid()
    return BUNDLEID
end

function handle.getLoginType()
    return LOGIN_TYPE
end

function handle.getIP()
    return IP
end

function handle.getAccount()
    return ACCOUNT
end

--领取在线奖励重置下一局
function handle.rewardOnline(time)
    -- autoLoginFuc = set_timeout(time, getOnlineReward)
end

--领取在线大转盘奖励下一局
function handle.rewardTurntable(time)
    autoTurntableFunc = set_timeout(time, getTurntableReward)
end

--供player里回收桌子使用
function handle.deskBack()
    if nil ~= cluster_desk and  not table.empty(cluster_desk) then
        CMD.deskBack(nil, cluster_desk.gameid)
    end
end

-- 获取玩家在哪个游戏里
function handle.getGameId()
    if nil ~=cluster_desk and  not table.empty(cluster_desk) then
        return cluster_desk.gameid
    end
    return 0
end

--获取桌子对象
function handle.getClusterDesk()
    return cluster_desk
end

--内部记录打点
function handle.addStatistics(uid, act, ext, gameid, tab, id, ts)
    if nil == ext then
        ext = ''
    end
    if nil == gameid then
        gameid = handle.getGameId()
    end
    local log = {
        ["uid"] = UID,
        ["act"] = act,
        ["ext"] = ext,
        ["gameid"] = gameid,
        ["menu"] = tab,
        ["itemid"] = id,
        ["ts"] = ts,
    }
    skynet.send('.statistics', 'lua', 'addActionsDot', log)
end

function handle.isInWhiteList(uid, type)
    return isInWhiteList(uid, type)
end

local function addCoinInGame(coin, diamond)
    if not table.empty(cluster_desk) then
        local ok, ret = pcall(cluster.call, cluster_desk.server, cluster_desk.address, "addCoinInGame", UID, coin, diamond)
        LOG_INFO("addCoinInGame:", UID, " Coin:", coin, ' Diamond:', diamond, ok, ret)
        if ok then 
            return PDEFINE.RET.SUCCESS
        end
    else
        LOG_INFO("addCoinInGame:", UID, "cluster_desk is empty")
    end
    return PDEFINE.RET.ERROR.USER_IN_GAME
end

--同步金币变化 changecoin：金币修改值 nowcoin：金币最终值
function handle.notifySyncAlterCoin(changecoin, nowcoin)
    LOG_DEBUG("notifySyncAlterCoin", changecoin, nowcoin, cluster_desk)
    return addCoinInGame(changecoin)
end

function handle.syncUserInfo(info)
    LOG_DEBUG("syncUserInfo:",  ' info:', info)
    local notify = {c = 211, code = PDEFINE.RET.SUCCESS, user=info}
    handle.sendToClient(cjson.encode(notify))
end

--获取下一级支付vip等级需要充值的金额
function handle.getNextVipInfoExp(svip)
    local exp = 0
    local ok, viplist  = pcall(cluster.call, "master", ".configmgr", 'getVipUpCfg')
    if ok then
        if svip == 0 or svip == nil then
            svip = 0
        end
        if nil ~= viplist[svip+1] then
            exp = viplist[svip+1].diamond
        end
        if svip == 20 then
            exp = viplist[svip].diamond
        end
    end
    return exp
end

-- 发送邮件
function handle.sendBuyOrUpGradeEmail(msgObj, mail_type)
    if not UID then return end
    mail_type = mail_type or PDEFINE.MAIL_TYPE.RANKING
    local mailid = genMailId()
    local mail_message = {
        mailid = mailid,
        uid = UID,
        fromuid = 0,
        msg  = msgObj.msg,
        type = mail_type,
        title = msgObj.title,
        attach = cjson.encode(msgObj.attach),
        sendtime = os.time(),
        received = 1,
        hasread = 0,
        sysMailID= 0,
        title_al = msgObj.title_al,
        msg_al = msgObj.msg_al,
        svip = msgObj.svip,
        rate = msgObj.rate
    }
    handle.moduleCall("mailbox", 'addMail', UID, mail_message)
    skynet.timeout(50, function ()
        handle.moduleCall("player", "syncLobbyInfo", UID)
    end)
end

function CMD.addProps(props, act)
    return handle.addProps(props, act)
end

function CMD.updateCharm(_, cnt)
    LOG_DEBUG("cmd.updateCharm cnt:", cnt, ' uid:', UID)
    handle.addProp(PDEFINE.PROP_ID.CHARM, cnt)
    local charm = handle.dcCall("user_dc", "getvalue", UID, "charm")
    local resp = {
        uid = UID,
        charm = charm or 0
    }
    handle.syncUserInfo(resp)
    return charm
end

function CMD.syncUserInfo(source, info, syncreddot)
    handle.syncUserInfo(info)
    if syncreddot then
        syncLobbyInfo()
    end
    return true
end

-- 封装接口给master服调用
function CMD.getGameId()
    return handle.getGameId()
end

function handle.getGstatus()
    if handle.checkhasdesk() then
        LOG_DEBUG("changeGstatus in game: 1")
        GSTATUS = 1
    end
    return GSTATUS
end

function CMD.getGstatus()
    return handle.getGstatus()
end


function handle.changeGstatus(status)
    LOG_DEBUG("changeGstatus:", status, ' UID:', UID)
    if nil == status then
        status = 0
    end
    GSTATUS = status
end

-- 获取好友的排位赛信息
function CMD.getLeagueInfo()
    LOG_DEBUG("getLeagueInfo uid:", UID)
    return handle.moduleCall('league', 'getInfo')
end

--排位赛邀请好友，同意了
function CMD.leagueInvite(_, friendUid)
    LOG_DEBUG("leagueInvite uid:", UID, ' friendUid:', friendUid)
    return handle.moduleCall('league', 'invitRet', friendUid)
end

function CMD.leagueKick(_, friendUid)
    LOG_DEBUG("leagueKick uid:", UID, ' friendUid:', friendUid)
    return handle.moduleCall('league', 'kicked', friendUid)
end

function CMD.leagueLeave(_, friendUid)
    LOG_DEBUG("leagueLeave uid:", UID, ' friendUid:', friendUid)
    return handle.moduleCall('league', 'leaved', friendUid)
end

function CMD.leavePage()
    return handle.moduleCall('league', 'leavePage')
end

function CMD.leagueResume(_)
    return handle.moduleCall('league', 'resume')
end

-- 通过agent获取用户信息
function CMD.getPlayerInfo()
    local playerInfo = handle.moduleCall("player","getPlayerInfo",UID)
    local gameid = handle.getGameId()
    playerInfo.gameid = gameid
    return playerInfo
end

function CMD.brodcastcoin( _,coin)
    --广播金币变化
    local playerInfo = handle.moduleCall("player","getPlayerInfo",UID)
    local retobj  = {}
    retobj.coin = playerInfo.coin
    retobj.c      = PDEFINE.NOTIFY.coin
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.uid    = UID
    retobj.deskid = 0
    retobj.count  = coin
    retobj.type   = 1
    handle.sendToClient(cjson.encode(retobj))

    --通知桌子里加金币
    if coin > 0 then
        handle.notifySyncAlterCoin(coin, retobj.coin)
    end
end

--给桌子上玩家加金币
function handle.addCoinInGame(coin)
    return addCoinInGame(coin)
end

function handle.addDiamondInGame(diamond)
    return addCoinInGame(0, diamond)
end

function handle.updateInfoInGame()
    LOG_DEBUG("updateInfoInGame uid:", UID)
    if not table.empty(cluster_desk) then
        pcall(cluster.send, cluster_desk.server, cluster_desk.address, "updateUserInfo", UID)
        return PDEFINE.RET.SUCCESS
    else
        LOG_INFO("updateInfoInGame:", UID, "cluster_desk is empty")
    end
    return PDEFINE.RET.ERROR.USER_IN_GAME
end

-- 将addCoinInGame包装成接口
-- @param coin 玩家要增加的金币
-- @param msg 要推送给客户端的协议内容
function CMD.addCoinInGame(_, coin, msg)
    LOG_INFO("addCoinInGame:", UID, " coin:",coin, " msg:", msg)
    addCoinInGame(coin)
    LOG_INFO("addCoinInGame after:", UID, " coin:",coin, " msg:", msg)
    if msg ~= nil then
        sendToClient(msg)
    end
end

function CMD.resetloginstarttime( )
    Login_StartCounTime = os.time()
end

function CMD.addStatistics(_, uid, act, ext, gameid, tab, id)
    return handle.addStatistics(uid, act, ext, gameid, tab, id)
end

-- 通知客户端重新登录
function CMD.callrelogin()
    LOG_INFO("callrelogin UID:", UID, " agentid", skynet.self())
    local retobj  = {}
    retobj.c      = PDEFINE.NOTIFY.NOTIFY_RELOGIN
    retobj.code   = PDEFINE.RET.SUCCESS
    handle.sendToClient(cjson.encode(retobj))

    CMD.kick(0, CLIENT_UUID)
end

function CMD.getUid()
    return UID
end

-- 获取当前使用的语言
function handle.getNowLanguage( ... )
    if NOW_LANGUAGE == nil then
        NOW_LANGUAGE = 1
    end
    NOW_LANGUAGE = math.floor(tonumber(NOW_LANGUAGE))
    return NOW_LANGUAGE
end

-- 是否是英语
function handle.isEnglish()
    if NOW_LANGUAGE == 2 then
        return true
    end
    return false
end

-- 切换语言
function handle.changeLanguage(language)
    NOW_LANGUAGE = language
    handle.dcCall("user_dc", "setvalue", UID, "lang", language) --记录语言
end

function handle.getToken( ... )
    return TOKEN
end

function CMD.getToken( ... )
    return TOKEN
end

skynet.start(function()
    -- If you want to fork a work thread , you MUST do it in CMD.login
    skynet.dispatch("lua", function(session, source, command, ...)
        if not CMD[command] then
            print("CMD:", command)
        end
        local f = assert(CMD[command])
        skynet.retpack(f(source, ...))
    end)


    skynet.dispatch("client", function(session, address, msg)
        local retobj = processClient(msg)
        skynet.ret(retobj)
    end)

    -- 绑定各模块
    for _, m in pairs(module_list) do
        m.bind(handle)
    end

    -- 启动agent自己的数据中心
    dcmgr.start()
    cluster_desk = {}
    collectgarbage("collect")
end)
