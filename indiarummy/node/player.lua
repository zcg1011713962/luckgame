local skynet = require "skynet"
local cluster = require "cluster"
local cjson = require "cjson"
local date = require "date"
local md5 = require "md5"
local snax = require "snax"
local queue = require "skynet.queue"
local mailbox = require "mailbox"
local friend = require "friend"
local api_service = require "api_service"
local raceCfg = require "conf.raceCfg"
local msgParser = require "MsgParser"
cjson.encode_sparse_array(true)
local cs = queue()
local player = {}
local handle

local jsondecode = cjson.decode
local playerdatamgr = require "datacenter.playerdatamgr"
local player_tool = require "base.player_tool"
local s_goldpiggy = require "conf.s_goldpiggy"
local N77 = require "N77"
local DEBUG = skynet.getenv("DEBUG")  -- 是否是调试阶段
local APP = skynet.getenv("app") or 1
APP = tonumber(APP)
local ServerId = skynet.getenv("serverid") or 0
local RED_DOT_COIN = 100000
local VIP_LIST

local stay_in_synclobbyinfo = nil  -- 是否在同步过程中
local delay_for_synclobbyinfo = 2  -- 同步延迟时间，防止一次性调用多次
local bindmobileTime = 0 --绑定手机号时间

function player.bind(agent_handle)
    handle = agent_handle
end

function player.heartBeat(recvobj)
    return PDEFINE.RET.SUCCESS
end

--成功返回
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

local function getMoneyBagLevel(moneybag)
    local level = 1
    for lv, item in ipairs(s_goldpiggy) do
        if moneybag >= item.coin then
            level = math.max(level, lv)
        end
    end
    return math.min(level, #s_goldpiggy)
end


local function getMaxMoneyBag()
    local val = 0
    for _, item in ipairs(s_goldpiggy) do
        val = math.max(val, item.coin)
    end
    return val
end

-- 获取今天的bonus
local function getTodayBonusCoin(uid)
    local startime = calRoundBeginTime()
    local total = 0
    local sql = string.format("select sum(coin) as t from d_log_cashbonus where uid=%d and create_time>=%d and coin>0 ", uid, startime)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 and rs[1].t then
        total = tonumber(rs[1].t)
    end
    if total < 0 then
        total = 0;
    end
    return total   
end


-- 获取vip配置
local function getVipCfg()
    if not VIP_LIST then
        local ok , datalist = pcall(cluster.call, "master", ".configmgr", "getVipUpCfg")
        if ok then
            VIP_LIST = datalist
        else
            return {}
        end
    end
    return VIP_LIST
end

-- 获取沙龙房开房配置
local function getVipRoomCnts()
    local vipcfg = getVipCfg()
    local roomcnt = {}
    for level, cfg in pairs(vipcfg) do
        if tonumber(cfg.level) == 0 then
            table.insert(roomcnt, 1, cfg.salonrooms)
        else
            table.insert(roomcnt, cfg.salonrooms)
        end
    end
    return roomcnt
end

-- 模拟在线人数 先模拟出5个值，目前前端用4个值
---@param gameid int 游戏id
local function getOnlineCount(gameid)
    local redis_key = PDEFINE.REDISKEY.GAME.online..gameid
    local cntRange = {
        {2000, 2500},
        {1500, 2500},
        {1000, 2000},
        {1000, 1500},
        {500, 1500},
    }
    local cntStr = do_redis({"get", redis_key})
    local cnts = {}
    if not cntStr then
        for _, r in ipairs(cntRange) do
            table.insert(cnts, math.random(r[1], r[2]))
        end
        cntStr = table.concat(cnts, ',')
        do_redis({"set", redis_key, cntStr})
        return cnts
    else
        cnts = string.split_to_number(cntStr, ',')
        local newCnts = {}
        -- 每个值随机增加或者减少50以内的数字
        for i, r in ipairs(cntRange) do
            local randNum = math.random(1, 50)
            local currCnt = cnts[i] or 0
            if currCnt <= r[1] then
                currCnt = currCnt+randNum
            elseif currCnt >= r[2] then
                currCnt = currCnt - randNum
            elseif math.random() < (currCnt - r[1])/(r[2] - currCnt) then
                currCnt = currCnt-randNum
            else
                currCnt = currCnt+randNum
            end
            table.insert(newCnts, currCnt)
        end
        cntStr = table.concat(newCnts, ',')
        do_redis({"set", redis_key, cntStr})
        return newCnts
    end
end

-- 创建角色
function player.create(message, agent, clientIP)
    LOG_INFO("player.create get message data: ", message)
    local recvobj = cjson.decode(message)
    local uid = math.floor(recvobj.uid)
    local cmd = math.floor(recvobj.c)
    local code, playerInfo = playerdatamgr.create(uid, clientIP)
    if code ~= true then
        return code
    end
    skynet.call(agent, "lua", "create")
    --更新account用户表 注册账号完成
    pcall(cluster.call, "login", ".accountdata", "set_account_item",uid, "status", 1)
    return playerInfo
end

--大厅版本号
function player.getVersion(msg)
    local recvobj = cjson.decode(msg)
    local retobj = {}
    retobj.c     = math.floor(recvobj.c)
    retobj.code  = PDEFINE.RET.SUCCESS

    local ok, res = pcall(cluster.call, "master", ".configmgr", "get", "version")
    retobj.version = res.v
    return resp(retobj)
end

local function floorVal(uid)
    local userid = math.floor(uid) or 0
    return userid
end

-- 统一计算用户金币相关
local function formatPlayerCoin(userInfo) 
    -- local vip = userInfo.svip or 1 --支付vip等级
    -- local vipexp = userInfo.svipexp or 0 --当前充值金额
    -- local nextvipexp = handle.getNextVipInfoExp(vip) --下一级vip需要充值的金额

    local bonus = userInfo.cashbonus or 0 --优惠总金额
    local tranedBonus = userInfo.dcashbonus or 0 --已提现到现金余额的金额
    local win_coin = userInfo.gamebonus or 0 --用户输钱
    local dbonus = 0
    if userInfo.svip and userInfo.svip > 0 and win_coin > 0 then
        local cfg = getVipCfg()
        if cfg[userInfo.svip] and cfg[userInfo.svip].tranrate > 0 then
            local tranrate = cfg[userInfo.svip].tranrate
            dbonus = math.round_coin(tranrate * win_coin) - tranedBonus
        end
        if dbonus < 0 then
            dbonus = 0
        end
        if dbonus > bonus then
            dbonus = bonus
        end
    end

    -- local fields = {'totalwin', 'totalbet','totaldraw','gamedraw'}
    -- local cacheData = do_redis({ "hmget", "d_user:"..userInfo.uid, table.unpack(fields)})
    -- cacheData = make_pairs_table_int(cacheData, fields)
    local gamedraw = userInfo.gamedraw or 0
    local dcoin = gamedraw
    if dcoin < 0 then
        dcoin = 0 --可提现金额
    end
    if dcoin > userInfo.coin then
        dcoin = userInfo.coin --可提现金额 不能超过现金余额
    end

    local bankcoin = 0 --保险箱余额
    -- local bankinfo = handle.dcCall("bank_dc","get", userInfo.uid)
    -- if bankinfo and bankinfo.coin then
    --     bankcoin = math.floor(bankinfo.coin)
    -- end
    -- local totalcoin = userInfo.coin + dcoin + bonus + bankcoin --账户总额
    return dcoin, bonus, dbonus, bankcoin
end

local function getLimited(userInfo)
    local islimited = 0
    local maxcoin = 0
    if nil == userInfo then
        return islimited, maxcoin
    end
    local ok, drawLimitCfg = pcall(cluster.call, 'master','.configmgr','getDrawLimitInfo', userInfo.svip, userInfo.uid)
    if ok then
        LOG_DEBUG('drawLimitCfg:', cjson.encode(drawLimitCfg))
        maxcoin = tonumber(drawLimitCfg.maxcoin or 0) --未付费用户最大可提金额
        local drawsucccoin = tonumber(userInfo.drawsucccoin or 0)
        local ispayer = tonumber(userInfo.ispayer or 0)
        if maxcoin > 0 and drawsucccoin >= maxcoin and ispayer == 0 then
            islimited = 1
        end
        if islimited == 0 then
            local limitDaytimes = tonumber(drawLimitCfg.daytimes)
            if limitDaytimes > 0 then --今日提现次数
                local todaytimes = do_redis({'get', PDEFINE_REDISKEY.OTHER.today_draw_times .. userInfo.uid})
                todaytimes = tonumber(todaytimes or 0)
                if todaytimes and (todaytimes >=  limitDaytimes) then
                    islimited = 1
                end
            end
        end
        if islimited == 0 then
            local limitTotalTimes = tonumber(drawLimitCfg.totaltimes)
            local totalSuccTimes = tonumber(userInfo.drawsucctimes or 0)
            if limitTotalTimes > 0 and (totalSuccTimes >= limitTotalTimes) then --总提现次数
                islimited = 1
            end
        end
    end
    return islimited, maxcoin
end

--协议接口获取玩家信息
function player.getUserInfo(msg)
    local recvobj = cjson.decode(msg)
    local myself = tonumber(recvobj.uid or 0)
    local ok, uid = pcall(floorVal, recvobj.otheruid) --被查找的人
    if not ok then
        local retobj = {}
        retobj.c     = math.floor(recvobj.c)
        retobj.code  = PDEFINE.RET.SUCCESS
        retobj.spcode= PDEFINE.RET.ERROR.USER_NOT_FOUND
        return resp(retobj)
    end
    uid = math.floor(uid) or 0
    local actfind   = recvobj.act or 0 --是否通过输入uid查好友
    actfind = math.floor(actfind)
    local retobj = {}
    retobj.c     = math.floor(recvobj.c)
    retobj.code  = PDEFINE.RET.SUCCESS
    retobj.spcode= 0
    local userInfo = player.getPlayerInfo(uid)
    if userInfo.uid == nil and actfind == 1 then
        retobj.spcode  = PDEFINE.RET.ERROR.USER_NOT_FOUND
        return resp(retobj)
    end
    local stateData = nil
    local playerInfo = {}
    local leagueExp, leagueLevel = player_tool.getPlayerLeagueInfo(uid)
    playerInfo = table.copy(userInfo)
    if playerInfo.isbindfb == 1 and playerInfo.fbtoken then
        playerInfo.usericon = playerInfo.usericon .. '&access_token='..playerInfo.fbtoken
    end
    playerInfo.rp = userInfo.rp or 0
    playerInfo.charm = userInfo.charm or 0
    playerInfo.leagueexp = leagueExp
    playerInfo.leaguelevel = leagueLevel
    -- playerInfo.country = playerInfo.country or 0
    playerInfo.avatarframe = playerInfo.avatarframe or ''
    -- playerInfo.vipendtime = playerInfo.vipendtime or 0
    playerInfo.wincoin = userInfo.wincoin or 0
    playerInfo.isbindgoogle = userInfo.isbindgg or 0
    playerInfo.isonline = 0
    local ok, online_list = pcall(cluster.call, "master", ".userCenter", "checkOnline",  {uid})
    if ok and nil ~= online_list and online_list[playerInfo.uid] then
        playerInfo.isonline = 1
    end
    playerInfo.drawinfo = {
        islimited = 0, --提现被限制
        maxcoin = 0, --设置的最高可提现金额
        isfirstdraw = 0, --是否首次提现
        isfirstdeposit  = 0, --是否首次充值
    }
    playerInfo.drawinfo.islimited, playerInfo.drawinfo.maxcoin = getLimited(playerInfo)
    if playerInfo.ispayer == nil or playerInfo.ispayer == 0 then
        playerInfo.drawinfo.isfirstdeposit = 1
    end
    
    if (nil ==userInfo.drawsucctimes or tonumber(userInfo.drawsucctimes) == 0) and (playerInfo.ispayer == nil or playerInfo.ispayer == 0) then
        playerInfo.drawinfo.isfirstdraw = 1
    end
    -----------------------
    -- 字段说明:
    -- coin: 对应客户端 Total Balance
    -- dcoin: 对应客户端 Withdrawable Balance 
    -- ecoin: 对应客户端 Cash Balance
    -- cashbonus: 对应客户端 Cash Bonus
    -----------------------
    playerInfo.coin = playerInfo.coin or 0 --对应客户端: Total balance
    playerInfo.svip = userInfo.svip or 1 --支付vip 等级
    playerInfo.svipexp = userInfo.svipexp --svipexp 等级经验(充值的总金额)
    playerInfo.nextvipexp = handle.getNextVipInfoExp(playerInfo.svip)
    playerInfo.dcoin, playerInfo.cashbonus, playerInfo.dcashbonus, playerInfo.bankcoin = formatPlayerCoin(userInfo)
    -- playerInfo.totalcoin = userInfo.coin +  playerInfo.cashbonus + playerInfo.bankcoin
    playerInfo.ecoin = userInfo.coin - playerInfo.dcoin --不可提现金余额  对应客户端 Cash balance
    playerInfo.todaybonus = getTodayBonusCoin(userInfo.uid)
    playerInfo.kyc = userInfo.kyc or 0 --kyc验证

    -- playerInfo.diamond = playerInfo.diamond or 0 --钻石
    local favorite_games = do_redis({"zrevrangebyscore", PDEFINE.REDISKEY.GAME.favorite..playerInfo.uid, 5})
    playerInfo.favorite_games = {}
    if favorite_games then
        for _, gameid in ipairs(favorite_games) do
            if gameid then
                table.insert(playerInfo.favorite_games, math.floor(gameid))
            end
            if #playerInfo.favorite_games >= 4 then
                break
            end
        end
    end
    playerInfo.topscore = 100
    
    if nil ~= playerInfo.memo then
        playerInfo.memo = string.gsub(playerInfo.memo, "\n\r", "")
        playerInfo.memo = string.gsub(playerInfo.memo, "\n", "")
        playerInfo.memo = string.gsub(playerInfo.memo, "\r", "")
    end
    playerInfo.vip   = userInfo.svip or 0 --当前玩家vip等级
    if userInfo.usericon then
        playerInfo.usericon = userInfo.usericon or "" -- 玩家头像
    end

    playerInfo.expbuffer = 0
    playerInfo.expbuffertime = 0
    
    local flag, _ = handle.moduleCall("friend","canAddFriend", handle.getUid(), playerInfo.uid)
    playerInfo.friend = flag
    local removeAttr = {
        'iswhite','login_days','token','firstbuylist','totalpay','isblack','from_channel','justreg','wintimes','ispayer','platform',
        'status','create_time','login_time','idcard','realname','invit_uid','login_ip','lrwardstate','deviceToken','invitednum','sysMsgID',
        'points','hadshowredenvelope','red_envelope','alltimes','update_time','code','identity','create_platform','uuid',
        'isgetinitgift','logintype','active','spread','buffcoin','appid','kouuid','svip','sysMailID','agent',
        'invitedfb','praisetime','ticket','fbtoken','fbendtime','fcmtoken','level','isrobot','totalbet','totalwin','candraw','maxdraw','gamedraw'
    }
    for _, key in pairs(removeAttr) do
        if nil ~= playerInfo[key] then
            playerInfo[key] = nil
        end
    end
    
    -- retobj.charmlist = get_send_charm_list(myself) --赠送的魅力值道具使用次数
    retobj.playerInfo = playerInfo
    retobj.charmlist = {}
    local onlineStat = {
        playedtime = 0,
        total = 0,
        win =0,
        win_rate =0,
        abandom = 0, --逃跑
    }
    local leagueStat = {
        current = {
            leagueexp = 0,
            win = 0,
            total = 0,
        },
        last = {
            leagueexp = 0,
            win = 0,
            total = 0,
        },
        high = {
            leagueexp = 0,
            win = 0,
            total = 0,
        },
    }
    retobj.stat = {online= onlineStat, league = leagueStat}
    return resp(retobj)
end

-- 内部接口获取玩家信息
function player.getPlayerInfo(uid)
    local playerData = handle.dcCall("user_dc", "get", uid)
    if not playerData then
        LOG_WARNING("get user data fail", uid)
        return nil
    end
    local ok, coin = pcall(cluster.call, "master", ".userCenter", "getUserCoin", uid)
    if ok then
        playerData.coin = coin
    else
        LOG_WARNING("get user coin fail", uid)
    end
    -- 这里处理下排位分
    -- local leagueExp, leagueLevel = player_tool.getPlayerLeagueInfo(uid)
    playerData.leagueexp = 0
    playerData.leaguelevel = 0
    return playerData
end

-- 已开启的等级礼包弹窗，计算剩余时间
local function calLevelGiftTimeout(uid)
    local left_timeout = 0 --默认未开启
    local isBuying = do_redis({"get", "levelgift:"..uid})
    if isBuying then
        local difftime = os.time() - isBuying
        local ok, shoplist = pcall(cluster.call, "master", ".shopmgr", "getShopList", PDEFINE.SHOPSTYPE.LEVEL)
        if ok then
            if difftime>0 and difftime < shoplist[1].discountTime then
                left_timeout = (shoplist[1].discountTime - difftime) --未过期，大于0
            else
                left_timeout = -1  --已过期的标记
            end
        end
    end
    return left_timeout
end

--[[
    编号：2one time(新手礼包) 
]] 
local function calPoPList(playerInfo)
    local popcnt = 3
    local curcnt = 0
    local poplist = {}

    local welcome_gift = 0 --新手礼包金额
    local one_time_only_left_time = 0 --one time only left time
    if not playerInfo.isgetinitgift or playerInfo.isgetinitgift == 0 then
        table.insert(poplist, 1) --新手礼包，一生只有1次；领取过了就不再弹出
        welcome_gift = 1
        one_time_only_left_time = 1 --是否可以购买新手礼包
        return poplist, welcome_gift, one_time_only_left_time
    -- else
        -- 计算one time only
        -- if nil == playerInfo.isonetime or 0 >= playerInfo.isonetime then -- 没有购买过新手礼包
        --     table.insert(poplist, 2)
        --     one_time_only_left_time = 1 --是否可以购买新手礼包
        --     curcnt = curcnt + 1
        --     if curcnt >= popcnt then
        --         return poplist, welcome_gift, one_time_only_left_time
        --     end
        -- end
        -- return poplist, welcome_gift, one_time_only_left_time
    end
    return poplist, welcome_gift, one_time_only_left_time
end

-- 提供接口，获取poplist 
function player.getPoPList(uid)
    local userInfo = player.getPlayerInfo(uid)
    return calPoPList(userInfo)
end


local game_list_type = {
    [1] = {256,265,257,264,289,287,290}, --外面的
    [2] = {266,286}, --内面的
    [3] = {} --ludo, uno
}

--从db获取游戏信息
local function getGameList(uid)
    local ok, all_game_list = pcall(cluster.call, "master", ".gamemgr", "get2ClientGameList")
    -- LOG_DEBUG('all_game_list:', all_game_list)
    if ok then
        for gametype, gamelist in pairs(all_game_list) do
            gametype = math.floor(gametype)
            if gametype == 1 then
                for i, v in pairs(gamelist) do
                    v.ctype = 2
                    if table.contain(game_list_type[1], v.id) then
                        v.ctype = 1
                    elseif table.contain(game_list_type[3], v.id) then
                        v.ctype = 3
                    end
                    v.country = 0 --我投票的国家
                    local country = handle.dcCall("user_data_dc","get_common_value", uid, tonumber(v.id))
                    if country > 0 then
                        v.country = country
                    end
                    local redis_key = string.format('rank_list:%s:%d', PDEFINE.RANK_TYPE.GAME_LEAGUE, v.id)
                    local score = do_redis({"zscore", redis_key, uid})
                    v.leagueexp = tonumber(score or 0)
                    v.topCountry = 0

                    v.sess = {}
                    -- if PDEFINE_GAME.SESS['match'][v.id] then
                    --     v.sess = PDEFINE_GAME.SESS['match'][v.id]
                    -- end
                    v.room = {entry={}, score={}, reward={}}
                    if PDEFINE_GAME.SESS['vip'][v.id] then
                        local entry = {}
                        local score = {}
                        local reward = {}
                        local vipCfg = PDEFINE_GAME.SESS['vip'][v.id]
                        for _, item in pairs(vipCfg) do
                            if item.entry then
                                table.insert(entry, item.entry)
                            end
                            if item.score then
                                table.insert(score, item.score)
                            end
                            if item.reward then
                                table.insert(reward, item.reward)
                            end
                        end
                        v.room.entry = entry
                        v.room.score = score
                        v.room.reward = reward
                    end
                end
            elseif gametype == 2 then --slots
                local rs = handle.moduleCall("jackpot","getGameJackpot")
                for _,gameinfo in pairs(gamelist) do
                    local gameid_n = math.floor(tonumber(gameinfo.id))
                    local gameid = tostring(gameid_n)
                    if rs[gameid_n] then
                        gameinfo.jp = rs[gameid_n].jp
                    else
                        LOG_WARNING("gameid:"..gameid.." not in jackpot list")
                        gameinfo.jp = {10,50,100,500}
                    end
                end
            end
        end
    end
    return all_game_list
end

-- 获取登录时机的弹窗
local function getLoginPoPList(playerInfo, cmd)
    local poplist, welcome_gift, one_time_only_left_time = calPoPList(playerInfo)

   
    -- 新手
    if (not playerInfo.reservecoin or playerInfo.reservecoin == 0) and (playerInfo.isgetinitgift == 0) then
            handle.dcCall("user_dc", "setvalue", playerInfo.uid, "reservecoin", 1)

            --TODO 要注释掉
            local sendFalg = DEBUG or handle.isTiShen()
            local ok, loginData = pcall(cluster.call, "master", ".userCenter", "getOnlineData", playerInfo.uid)
            if ok and loginData and loginData.platform == PDEFINE.PLATFORM.WEB then
                sendFalg = true
            end
            -- if sendFalg then
            --     -- handle.dcCall("user_dc", "setvalue", playerInfo.uid, "diamond", 2000000)
            --     handle.dcCall("user_dc", "setvalue", playerInfo.uid, "coin", 20000)
            -- end

        return poplist, welcome_gift, one_time_only_left_time, 0
    end

    if cmd == 3 then
        poplist = {} --断线重连，不弹窗
    end

    return poplist, welcome_gift, one_time_only_left_time, 0
end


-- one time only 或 等级礼包 设置倒计时
function player.setPoPTimeout(uid)
    local levelgift_timeout = calLevelGiftTimeout(uid)
    if levelgift_timeout > 0 then
        pcall(cluster.call, "master", ".levelgiftmgr", "setTimeOut", uid, levelgift_timeout) 
    end
end

function player.upFBAccessToken(uid, token, endtime, img)
    if not token or token=='' then
        print("player.upFBAccessToken uid",uid, ' not token')
        return
    end
    handle.dcCall("user_dc", "setvalue", uid, "fbtoken", token)
    if not endtime or endtime == 0 then
        endtime = os.time() + 7200
    end
    handle.dcCall("user_dc", "setvalue", uid, "fbendtime", endtime)
    if img then
        local resp = {
            uid = uid,
            usericon = img .. '&access_token=' .. token
        }
        handle.syncUserInfo(resp)
    end
end

--check fcmToken 和 AppsFlyer的id
local function checkFCMToken(uid, userFCMToken, kouuid)
    if userFCMToken and userFCMToken ~= "" then
        handle.dcCall("user_dc", "setvalue", uid, "fcmtoken", userFCMToken)
    end
    local fbtoken = do_redis({"get", "fbtoken_" .. uid}) or ""
    if fbtoken ~= nil and fbtoken ~= "" then
        player.upFBAccessToken(uid, fbtoken)
    end
    if kouuid ~= '' then
        handle.dcCall("user_dc", "setvalue", uid, "kouuid", kouuid) --将提审包 会员的AppsFlyer_Id关联到这个字段上
    end
end

--客户端更新fcmtoken
function player.updateFcmToken(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local token = recvobj.token or ''
    if token and token ~= "" then
        local vip_level = handle.dcCall("user_dc", "getvalue", uid, "svip")
        vip_level = tonumber(vip_level or 0)

        local oldtoken = handle.dcCall("user_dc", "getvalue", uid, "fcmtoken")
        if oldtoken and oldtoken ~= token then
            --通知队列取消订阅
            local res = {level = vip_level, token=oldtoken}
            local vipListKey= PDEFINE.REDISKEY.QUEUE.UNSUB_FIREBASE_TOPIC
            do_redis({"lpush", vipListKey, cjson.encode(res)})
        end

        handle.dcCall("user_dc", "setvalue", uid, "fcmtoken", token)
        --通知队列重新订阅
        local vipListKey= PDEFINE.REDISKEY.QUEUE.VIP_UPGRADE
        local res = {uid = uid, level = vip_level}
        do_redis({"lpush", vipListKey, cjson.encode(res)})
    end
    local retobj  = {}
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.c      = math.floor(recvobj.c)
    retobj.uid    = uid
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end
--[[
    登录即获取bonus页面该展示哪些模块
    1 sign签到
    2 每日在线时长任务
    3 每日游戏任务
    4 升级任务
    5 在线奖励转盘
    6 vip签到(周奖励)
    7 vip升级任务 
]]
local function getBonusPageList(user)
    local list = {2,3,4,5} 
    local cache_bonuslist = do_redis({"get", "bonuslist"})
    if cache_bonuslist then
        local ok, bonuslist = pcall(jsondecode, cache_bonuslist)
        if ok then
            list = bonuslist
        end
    end
    -- if nil~=user.svip and user.svip > 0 then
        table.insert(list, 6)
        table.insert(list, 7)
    -- end
    return list
end

-- 检查是否是IOS提审版本，如果是的话，游戏列表只下发1个势力,且全部等级都为0
local function checkTishenState(ver)
    if nil == ver then
        return
    end
    local ver_flag = do_redis({"get", 'ios_examine_version'})
    LOG_DEBUG("setting tishen state ver:", ver, ' ver_flag:', ver_flag)
    if ver_flag and ver == ver_flag then
        LOG_DEBUG("setting tishen state")
        handle.setTishenState()
    end
end

local function initModule(uid)
    handle.dcCall("user_dc", "setvalue", uid, "justreg", 0) --设置登录标记，配合打点
    handle.moduleCall("quest","init", uid)
    handle.moduleCall("pay","init", uid)
    handle.moduleCall('friend', 'init', uid)
    handle.moduleCall('league', 'init', uid)
    handle.moduleCall('upgrade', 'init', uid)
    handle.moduleCall('invite', 'init', uid)
    -- handle.moduleCall("club", "init", uid)
    handle.moduleCall("privateroom", "init", uid)
    handle.moduleCall("charm", "init", uid)
    handle.moduleCall("exchange", "init", uid)
    handle.moduleCall("knapsack", "init", uid)
    handle.moduleCall("maintask", "init", uid)
    -- handle.moduleCall("bank", "init", uid)
    handle.moduleCall("viplvtask", "init", uid)
    -- skynet.call(".simpledb", "lua", "SET", "test",'alibaba')

    -- local val = skynet.call(".simpledbcd", "lua", "GET", "test")
    -- LOG_DEBUG("player init test key:test value:", val)
end

local function getLinks()
    local urls = PDEFINE.APPS.URLS[APP]
    for k, v in pairs(urls) do
        if k =='adtime' then
            local cache = do_redis({ "hgetall", "urls_" .. k}) --玩家缓存的转盘领取数据
            cache = make_pairs_table(cache)
            if cache then
                urls[k] = cache
            end
        else 
            local url = do_redis({ "get", "urls_"..k})
            if url then
                urls[k] = url
            end
        end
    end
    return urls
end

local function getEmojilist(userInfo, emojilist)
    emojilist = emojilist or {}
    local ok, hadSkins = pcall(jsondecode, userInfo.skinlist)
    if ok then
        if #hadSkins[6] > 0 then
            for _, img in pairs(hadSkins[6]) do
                table.insert(emojilist, img)
            end
        end
    end
    local cacheKey = PDEFINE.REDISKEY.TASK.SKIN_SEND .. userInfo.uid --签到赠送的道具加入到已有列表中
    local sendSkinList = do_redis({"get", cacheKey})
    if nil ~= sendSkinList and "" ~= sendSkinList then
        local sendList = cjson.decode(sendSkinList)
        local now = os.time()
        for i=#sendList, 1, -1 do
            local item = sendList[i]
            if item.endtime <= now then
                table.remove(sendList, i)
            else
                if string.find(item.img,"^emoji") == 1 then
                    table.insert(emojilist, item.img)
                end
            end
        end
    end
    return emojilist
end

 --大厅广告图片
local function getADPics()
    local adsList = {}
    local cachePics = do_redis({ "get", "pk_adpics"}) --玩家缓存的转盘领取数据
    if cachePics then
        local ok, imgs = pcall(jsondecode, cachePics)
        if ok then
            for k, item in pairs(imgs) do
                table.insert(adsList, item)
            end
        end
    end
    if table.size(adsList) == 0 then
        table.insert(adsList, {
            ['id'] = 1,
            ['img'] = 'btn_share_en',
            ['url'] = 'download',
        })

        table.insert(adsList, {
            ['id'] = 2,
            ['img'] = 'icon_hall_morocoin',
            ['url'] = '',
        })
        table.insert(adsList, {
            ['id'] = 3,
            ['img'] = 'icon_hall_find_bug',
            ['url'] = '',
        })
    end
    return adsList
end

-- 获取用户钱包金额
function player.getWallet(uid)
    local userInfo = player.getPlayerInfo(uid)
    local dcoin, cashbonus, dcashbonus, bankcoin = formatPlayerCoin(userInfo)
    local ecoin = userInfo.coin - dcoin --不可提现金余额
    local wallet = {
        ['coin'] = userInfo.coin, --total balance
        ['ecoin'] = ecoin , -- cash balance
        ['dcoin'] = dcoin, -- withdrawable balance
        ['bonus'] = cashbonus, -- cash bonus
    }
    return wallet
end

-- 直属下级通过KYC审核后，增加上级的奖励转盘次数
function player.updateTurntableTimes(uid)
    local suns = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.KYC_OF_SUN)
    suns = tonumber(suns or 0)
    suns = suns + 1 --多加1个
    local remainder = suns % 5
    if remainder == 0 then --每5个有效kyc下级就+1
        local times = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.TIMES_OF_TURNTABLE)
        times = tonumber(times or 0)
        times = times + 1
        handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.TIMES_OF_TURNTABLE, times)
        do_redis({"set", PDEFINE_REDISKEY.QUEUE.bonus_wheel_step..uid, 5})
    else
        do_redis({"set", PDEFINE_REDISKEY.QUEUE.bonus_wheel_step..uid, remainder})
    end
    
    handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.KYC_OF_SUN, suns)
    return PDEFINE.RET.SUCCESS
end

local function getFbShareTag(uid)
    local fbsharewheels = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.SHARE_TURNTABLE)
    local fbshare = tonumber(fbsharewheels or 0) --免费转盘(免费的)可转次数
    if fbshare == 0 and not handle.moduleCall("quest", "todayHadShared", uid) then --没有免费转的次数，但今日未分享
        fbshare = 1
    end
    return fbshare
end

--1.2.2.2
local function getVersionNum(version)
    local nums = {}
    local _ = string.gsub(version, "[^.]+",
        function(w)
            table.insert(nums, w)
        end
    )
    local vernum = 0
    for _, num in ipairs(nums) do
        vernum = vernum * 100 + num
    end
    return math.floor(vernum)
end

-- 检查协议1和协议2的时间间隔
local function checkUserRegTime(uid, timestamp)
    local key = PDEFINE_REDISKEY.LOBBY.REG_ONE_TIME .. uid
    local regtime = do_redis({"get",key})
    regtime = tonumber(regtime or 0)
    if regtime == 0 then
        return
    end
    local difftime = timestamp - regtime
    key = PDEFINE_REDISKEY.LOBBY.REG_DIFF_TIME .. uid
    do_redis( {"setex", key, difftime, 3600}) --新用户协议1的时间
    do_redis({"del", PDEFINE_REDISKEY.LOBBY.REG_ONE_TIME .. uid})
end

-- 请求登录信息
function player.getLoginInfo(message, deskAgent, agent, clientIP)
    LOG_INFO(" player.getLoginInfo get message data: ", message)
    local recvobj = cjson.decode(message)
    local uid = math.floor(recvobj.uid)
    local cmd = math.floor(recvobj.c)
    local kouuid = recvobj.kouuid or ''
    checkTishenState(recvobj.appver)
    if not handle.dcCall("user_dc", "check_player_exists", uid) then
        LOG_ERROR(" player.getLoginInfo 找不到玩家 ", message)
        handle.addStatistics(uid, 'Node_login_fail', 'data not found')
        return PDEFINE.RET.ERROR.PLAYER_NOT_FOUND
    end
    local nowtime = os.time()
    skynet.timeout(50, function ()
        checkUserRegTime(uid, nowtime)
    end)

    local retobj = {}
    retobj.gameid= recvobj.gameid
    retobj.code  = PDEFINE.RET.SUCCESS
    retobj.reg = 0
    if recvobj.language ~= nil then
        local language = math.floor(recvobj.language)
        handle.changeLanguage(language)
    end
    local userInfo = player.getPlayerInfo(uid)
    local playerInfo = {}
    playerInfo.status = userInfo.status
    
    playerInfo.uid    = userInfo.uid
    playerInfo.playername = userInfo.playername
    playerInfo.usericon     = userInfo.usericon
    playerInfo.rp = userInfo.rp or 0
    if userInfo.isbindfb == 1 and string.find(userInfo.usericon,"http") == 1 and (userInfo.fbtoken ~= nil and userInfo.fbtoken~="") then
        playerInfo.usericon     = userInfo.usericon .. '&access_token=' .. userInfo.fbtoken
    end
    if playerInfo.status ~= 1 then
        LOG_INFO("从user_dc获取用户信息，判断status值：",playerInfo.status, "uid:",uid)
        handle.addStatistics(uid, 'Node_login_fail', 'baned')
        return PDEFINE.RET.ERROR.ACCOUNT_ERROR --玩家被禁掉了
    end
    if math.floor(userInfo.justreg) == 1 then --配合华为端打点
        retobj.reg = 1
    end
    initModule(uid)
    skynet.timeout(100, function ()
        handle.offlineCmd()
    end)
    local ok,deskInfo = false, nil
    if deskAgent and not table.empty(deskAgent) then
        retobj.deskFlag = 1
        ok,deskInfo = pcall(cluster.call, deskAgent.server, deskAgent.address, "getDeskInfo", recvobj) --可能需要展示当前玩家的牌
        if not ok or nil==deskInfo or nil==deskInfo.deskid then
            LOG_INFO(" 获取房间数据异常, 错误信息:", deskInfo, "uid:",uid)
            retobj.deskFlag = 0
            handle.deskBack()
        else
            retobj.deskInfo = deskInfo
        end
    else
        retobj.deskFlag = 0
        handle.changeGstatus(0) --辅助改一下用户的游戏状态
    end

    local hadDone = handle.moduleCall("quest","hasDone",uid)
    playerInfo.hasQuest = hadDone
    playerInfo.svip = userInfo.svip or 0 --支付vip 等级
    playerInfo.svipexp = userInfo.svipexp --svipexp 等级经验(充值的总金额)
    playerInfo.nextvipexp = handle.getNextVipInfoExp(playerInfo.svip)
    playerInfo.dcoin, playerInfo.cashbonus, playerInfo.dcashbonus, playerInfo.bankcoin = formatPlayerCoin(userInfo)
    playerInfo.ecoin = userInfo.coin - playerInfo.dcoin --不可提现金余额
    playerInfo.todaybonus = getTodayBonusCoin(userInfo.uid)

    playerInfo.verifyfriend = userInfo.verifyfriend or 0 --被添加好友是否需要验证
    playerInfo.level    = userInfo.level or 1 --当前玩家等级
    playerInfo.levelexp = userInfo.levelexp or 0
    playerInfo.levelup  = 0
    playerInfo.charm = userInfo.charm or 0 --魅力值
    playerInfo.isbindphone = userInfo.isbindphone or 0 --是否绑定手机号
    local fcmtoken = recvobj.fmcToken or userInfo.fcmtoken --协议里是fmcToken, db里是 fcmtoken
    checkFCMToken(uid, fcmtoken, kouuid) --google 推送 
    if recvobj.deviceToken then --ios推送token
        handle.dcCall("user_dc","setvalue", uid, "deviceToken", recvobj.deviceToken)
    end
    playerInfo.isbindfb    = userInfo.isbindfb or 0
    playerInfo.isbindapple = userInfo.isbindapple or 0 --绑定苹果标记
    playerInfo.isbindgoogle    = userInfo.isbindgg or 0 --绑定谷歌
    playerInfo.kyc = userInfo.kyc or 0
    local fbrewards = handle.moduleCall("quest","getFBShrareCoin")
    playerInfo.fbrewards = fbrewards

    playerInfo.bindfbcoin = 0
    playerInfo.bindfbdiamond = 0
    playerInfo.leagueexp = userInfo.leagueexp or 0
    playerInfo.leaguelevel = userInfo.leaguelevel or 1
    if not player.isbindfb or  player.isbindfb == 0 then
        local ok, row = pcall(cluster.call, "master", ".configmgr", "batchGet",{"bindfbcoin", "bindfbdiamond", "min_version", "app_download_url"})
        if ok then
            playerInfo.bindfbcoin = tonumber(row['bindfbcoin'].v)
            playerInfo.bindfbdiamond = tonumber(row['bindfbdiamond'].v)

            if recvobj.v then
                local clientvernum = getVersionNum(recvobj.v)
                local minvernum = getVersionNum(row["min_version"].v)
                if clientvernum < minvernum then
                    retobj.newappurl = row["app_download_url"].v
                end
            end
        end
    end
    playerInfo.fbicon = userInfo.fbicon or "" --绑定的fb头像
    playerInfo.logintype = handle.getLoginType() or 1
    local poplist, initgift, newerpack, back_game_coin = getLoginPoPList(userInfo, cmd)
    playerInfo.coin   = tonumber(userInfo.coin)
    playerInfo.diamond= userInfo.diamond or 0 --钻石
    playerInfo.moneybag = userInfo.moneybag or 0 -- 金猪
    playerInfo.nextbag = 0
    playerInfo.avatarframe = userInfo.avatarframe or PDEFINE.SKIN.DEFAULT.AVATAR.img --头像框
    playerInfo.chatskin = userInfo.chatskin or PDEFINE.SKIN.DEFAULT.CHAT.img --聊天框
    playerInfo.tableskin = userInfo.tableskin or PDEFINE.SKIN.DEFAULT.TABLE.img --牌桌
    playerInfo.pokerskin = userInfo.pokerskin or PDEFINE.SKIN.DEFAULT.POKER.img --牌背
    playerInfo.frontskin = userInfo.frontskin or PDEFINE.SKIN.DEFAULT.FRONT.img --字体颜色
    playerInfo.emojiskin = userInfo.emojiskin or PDEFINE.SKIN.DEFAULT.EMOJI.img --聊天表情
    playerInfo.faceskin = userInfo.faceskin or PDEFINE.SKIN.DEFAULT.FACE.img --牌花
    playerInfo.salonskin = userInfo.salonskin or "" 
    playerInfo.salontesttime =tonumber(userInfo.salontesttime or 0)

    local offlineInvites = do_redis({"get", PDEFINE_REDISKEY.OTHER.invite_count_offline..uid}) --我离线时候，绑我邀请码的人数
    playerInfo.invits = tonumber(offlineInvites or 0)
    if playerInfo.invits > 0 then
        do_redis({"del", PDEFINE_REDISKEY.OTHER.invite_count_offline..uid}) 
    end

    -- 默认开启
    if playerInfo.salonskin == "" then
        playerInfo.salonskin = 'coffee_1'
        handle.dcCall("user_dc","setvalue", uid, "salonskin", 'coffee_1')
    end
    --是否领取了测试3天沙龙道具
    local now = os.time()
    if playerInfo.salontesttime > now then
        playerInfo.salonskin = 'coffee_1'
    end
    playerInfo.sex = userInfo.sex or 1
    playerInfo.code = userInfo.code --邀请码
    playerInfo.invit_uid = userInfo.invit_uid --上级uid
    playerInfo.ticket = userInfo.ticket
    -- playerInfo.vipendtime = userInfo.vipendtime
    local viptmpexp = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.TEMP_VIP_EXP)
    playerInfo.tmpvip = 1
    if viptmpexp and (viptmpexp > 0 or viptmpexp == -1) then
        playerInfo.tmpvip = 0
    end
    -- playerInfo.country = userInfo.country or 0 --国家
    local _, _, getviplist = handle.moduleCall("upgrade","canGetVipRewards", userInfo.uid)
    playerInfo.getviplv = getviplist
    playerInfo.emojilist = getEmojilist(userInfo, {PDEFINE.SKIN.DEFAULT.EMOJI.img})
    retobj.rate = 0 
    
    -- local rateTime = tonumber(userInfo.praisetime) or 0
    -- if rateTime >= 4 or rateTime <=0 then
    --     retobj.rate = 0
    --     if rateTime <=0 then
    --         handle.dcCall("user_dc", "setvalue", uid, "praisetime", 1)
    --     end
    -- end
    if handle.isTiShen() then
        retobj.rate = 0 --提审不诱导评分
    end
    retobj.maxbet = 5000--TODO:配合slots
    retobj.poplist = poplist
    retobj.backGameCoin = back_game_coin  -- 召回推送奖励
    retobj.newbiedone = 0 --新手任务是否全部完成
    local newbieflag = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.DONE_NEWBIE)
    if newbieflag and newbieflag > 0 then
        retobj.newbiedone = 1
    end
    retobj.shoptimeout = 0 --显示商品倒计时
    local first = do_redis({ "get", 'timelimit_today:' .. uid})
    first = math.floor(first or 0)
    if first == 0 then
        retobj.shoptimeout = 1
    else
        local cacheKey = "timelimitgoods:" .. uid 
        local leftseconds = do_redis({"ttl", cacheKey})
        leftseconds = math.floor(leftseconds or 0)
        if leftseconds > 0 then
            retobj.shoptimeout = 1
        end
    end

    local maxpops = 2 --最多弹2个
    local currpops = 0 --本次弹框个数，默认限制为2个

    playerInfo.charmpack = 1 --是否显示赠送新人的礼包
    local getTime = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.CHARM_GIFT_PACK)
    if getTime > 0 then
        playerInfo.charmpack = 0
    end
    if playerInfo.charmpack > 0 then
        if userInfo.create_time ==nil or userInfo.create_time < 1660910400 then --老用户就不给了
            playerInfo.charmpack = 0
        end
    end
    if playerInfo.charmpack == 1 then
        local ok, row = pcall(cluster.call, "master", ".configmgr", "get", 'charmpack')
        if not ok then
            playerInfo.charmpack = 0
        else
            playerInfo.charmpack = tonumber(row.v)
        end
    end
    if playerInfo.charmpack > 0 then
        currpops = currpops + 1 --弹1个弹框
    end
    
    -- retobj.signrewards = handle.moduleCall('sign', 'autoSign', uid)
    retobj.vipsign = handle.moduleCall("sign", "checkSignInfo", uid)
    if retobj.vipsign == 0 then
        currpops = currpops + 1 --弹了签到，标记再加1个
    end

    if currpops >= maxpops then
        retobj.fbshare = 0
        retobj.bonuswheel = 0
    else
        retobj.fbshare = getFbShareTag(uid) 
        local times = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.TIMES_OF_TURNTABLE)
        retobj.bonuswheel = tonumber(times or 0) --邀请次数转盘

        if retobj.fbshare == 1 or retobj.bonuswheel == 1 then
            currpops = currpops + 1 --弹了转盘，标记再加1个
        end
    end
    

    retobj.todayrewards = 0 --今天是否有奖励可以领取
    if currpops < maxpops then
        if player.hasRakeBackReward(uid) then
            retobj.todayrewards = 1
        else
            local viprewards = handle.moduleCall("viplvtask", "getVipRewards", uid)
            for _, item in pairs(viprewards) do
                if item > 0 then
                    retobj.todayrewards = 1
                    break
                end
            end
        end
        if retobj.todayrewards == 1 then
            currpops = currpops + 1 --弹了rewardstoday，标记再加1个
        end
    end

    retobj.verify = {
        redem = PDEFINE.SWITCH.REDEMPTION, --兑换码开关
        sender = PDEFINE.SWITCH.SEND, --sender显示开关
        report =  PDEFINE.SWITCH.REPORT, --举报功能入口
    }
    local sendSwitch = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.SWITCH_SENDER)
    if sendSwitch > 0 then
        retobj.verify.sender = 1
    end
    local giftSwitch = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.SWITCH_GIFTCODE)
    if giftSwitch > 0 then
        retobj.verify.redem = 1
    end
    local reportSwitch = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.SWITCH_REPORT)
    if reportSwitch > 0 then
        retobj.verify.report = 1
    end
    -- if DEBUG then
    --     retobj.verify = {
    --         redem = 1,
    --         sender = 1,
    --         report = 1
    --     }
    -- end
    

    playerInfo.novice = initgift --是否是新人的标记
    if handle.isTiShen() then
        playerInfo.novice = 0
    end
    playerInfo.newerpack = newerpack --新手礼包是否显示购买入口 1显示 0不显示
    playerInfo.guide = {}
    local ok, guideData = pcall(jsondecode, userInfo.guide)
    if ok then
        playerInfo.guide = guideData
    end
    -- 好友房列表
    playerInfo.pinlist, playerInfo.fgamelist = player_tool.getPlayerGameList(userInfo.fgamelist)
    local ok, roomcnt = pcall(cluster.call, "master", ".balprivateroommgr", "getOwnerDeskCnt", playerInfo.uid)
    playerInfo.roomcnt = 0
    if ok then
        playerInfo.roomcnt = roomcnt
    end

    playerInfo.charmlist = get_send_charm_list(playerInfo.uid) --赠送的魅力值道具使用次数

    local ok, blockuids = pcall(jsondecode, userInfo.blockuids) --我屏蔽的uid列表
    if not ok then
        blockuids = {}
    end
    playerInfo.blockuids = blockuids
    playerInfo.viproomcnt = getVipRoomCnts() --VIP开房数

    retobj.voice = 0 --0关闭房间内语聊  1:打开语聊
    -- local openvoice = do_redis({"get","openvoice"})
    -- openvoice = tonumber(openvoice or 0)
    -- if openvoice > 0 then
    --     retobj.voice = 1
    -- end
    retobj.playerInfo = playerInfo
    retobj.servertime = os.time()
    retobj.country = 0 --老虎机的国家投票
    local country = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.SLOTS_COUNTRY) --老虎机gameid固定为100
    if country > 0 then
        retobj.country = country
    end
    handle.addStatistics(uid, 'Node_login_succ', cmd)

    --更新fbtoken
    if userInfo.isbindfb==1 and userInfo.fbendtime and userInfo.fbendtime < (retobj.servertime + 86400) then
        skynet.send(".facebook", "lua", "refreshToken", userInfo.uid, userInfo.fbtoken)
    end
    --删除推送标记
    -- local popkey = "hall_pop:"..uid
	-- do_redis({"del", popkey}, uid)
    return resp(retobj)
end

--获取桌子信息
function player.getDeskInfo(msg, deskAgent)
    local recvobj = cjson.decode(msg)

    local retobj = {}
    retobj.gameid= recvobj.gameid
    retobj.code  = PDEFINE.RET.SUCCESS
    retobj.deskFlag = 0

    if deskAgent and not table.empty(deskAgent) then
        local ok, deskInfo = pcall(cluster.call, deskAgent.server, deskAgent.address, "getDeskInfo", recvobj) --可能需要展示当前玩家的牌
        if ok then
            if deskInfo and deskInfo.deskid then
                retobj.deskInfo = deskInfo
                retobj.gameid = deskInfo.gameid
                retobj.deskFlag = 1
            else
                handle.deskBack()
            end
        end
    end
    return resp(retobj)
end

--获取玩家金币
function player.getCoin(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local playerInfo = player.getPlayerInfo(uid)
    local retobj  = {}
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.c      = math.floor(recvobj.c)
    retobj.uid    = uid
    retobj.coin   = playerInfo.coin
    retobj.diamond= playerInfo.diamond or 0
    retobj.level  = playerInfo.level or 1
    retobj.levelexp = playerInfo.levelexp or 0
    retobj.levelup = 0
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--大厅跑马灯
function player.pushmsg(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)

    pcall(cluster.call, "master", ".userCenter", "joinHall", uid)

    local retobj = { c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, notices = {}}
    local rs = do_redis({ "zrevrange", "pushnotices" , 0, 1 }, nil)
    if #rs > 0 then
        for _, noticeid in pairs(rs) do
            local msg   = do_redis({"hget", "push_notice:" .. noticeid, "msg"}, nil) --消息内容
            local speed   = do_redis({"hget", "push_notice:" .. noticeid, "speed"}, nil) --消息速度
            table.insert(retobj.notices, { speed = speed, msg = msg})
            break
        end
    end

    return resp(retobj)
end

function player.getPlayerCoin(uid)
    return playerdatamgr.getPlayerCoin(uid)
end

-------- 添加玩家个人等级经验值或vip点数--------
function player.setPersonalExp(uid, param)
    local playerInfo = player.getPlayerInfo(uid)
    if nil ~= playerInfo then
        local levelChanged, leagueChanged = false, false
        if nil ~= param.level and playerInfo.level ~= param.level then
            levelChanged = true
        end
        if nil ~= param.diamond and 0 ~= param.diamond then 
            local diamond = playerInfo.diamond or 0
            if diamond ~= 0 then
                LOG_DEBUG("leftdiamond:", (diamond + param.diamond), ' param.diamond:', param.diamond)
                handle.dcCall("user_dc", "setvalue", uid, "diamond", (diamond + param.diamond))
            end

            local leftDiamond = (diamond + param.diamond)
            local act = param.act or "add"
            local content= ""
            if act =='ticket' then
                content = 'buy_league_ticket'
            end
            handle.moduleCall("player", "addDiamondLog", uid, param.diamond, leftDiamond, act, content)
            if leftDiamond < 0 then
                leftDiamond = 0
            end
            handle.notifyCoinChanged(playerInfo.coin, leftDiamond, 0, 0)
        end
        
        --vip点数
        if nil ~= param.addsvipexp and tonumber(param.addsvipexp) > 0 then
            local curr_svipexp = playerInfo.svipexp or 0
            -- if nil ~= param.svip then
            --     handle.dcCall("user_dc", "setvalue", uid, "svip", param.svip)
            -- end
            -- handle.dcCall("user_dc", "setvalue", uid, "svipexp", (curr_svipexp + param.addsvipexp))

            handle.dcCall("user_dc", "user_addvalue", uid, "svipexp", param.addsvipexp)

            handle.syncUserInfo({uid= uid, svipexp=(curr_svipexp + param.addsvipexp)})
        end
        --league 
        if nil ~= param.leaguelevel then
            if param.leaguelevel ~= playerInfo.leaguelevel then
                leagueChanged = true
            end
            handle.dcCall("user_dc", "setvalue", uid, "leaguelevel", param.leaguelevel)
        end
        if nil ~= param.leagueexp then
            handle.dcCall("user_dc", "setvalue", uid, "leagueexp", param.leagueexp)
        end
        if nil ~= param.ticket then
            handle.dcCall("user_dc", "setvalue", uid, "ticket", param.ticket)
        end
        if levelChanged or leagueChanged then
            local userInfo = handle.dcCall("user_dc", "get", uid)
            skynet.send('.chat', 'lua', 'changeUserData', userInfo)
        end
        return true
    end
    return false
end

--添加个人累计输赢金币和消耗
function player.setPersonalWinCoin(uid, param)
    return false
end

local function brodcastcoin(uid, altercoin, coin, issend2game)
    if issend2game then
        handle.notifySyncAlterCoin(altercoin, coin)
    end
    -- --如果玩家在大厅才通知客户端金币修改了
    -- LOG_INFO("brodcastcoin issend2game:", issend2game, "handle.checkhasdesk():", handle.checkhasdesk())
    -- if not handle.checkhasdesk() then
    --     local retobj  = {}
    --     retobj.c      = PDEFINE.NOTIFY.coin
    --     retobj.code   = PDEFINE.RET.SUCCESS
    --     retobj.uid    = uid
    --     retobj.deskid = 0
    --     retobj.count  = altercoin
    --     retobj.coin   = coin
    --     retobj.type   = 2
    --     handle.sendToClient(cjson.encode(retobj))
    -- end
end

--广播金币变化给客户端
function player.brodcastcoin2client(uid, altercoin)
    local playerInfo = player.getPlayerInfo(uid)
    --如果玩家在大厅才通知客户端金币修改了
    if not handle.checkhasdesk() then
        local retobj  = {}
        retobj.c      = PDEFINE.NOTIFY.coin
        retobj.code   = PDEFINE.RET.SUCCESS
        retobj.uid    = uid
        retobj.deskid = 0
        retobj.count  = altercoin
        retobj.coin   = playerInfo.coin
        retobj.diamond = playerInfo.diamond or 0
        retobj.addDiamond = 0 --增加的钻石
        retobj.type   = 2
        handle.sendToClient(cjson.encode(retobj))
    else
        LOG_INFO("brodcastcoin2client checkhasdesk")
    end
end

-------- 计算玩家金币(累加累减) --------
function player.calUserCoin(uid_p, altercoin, log, type, isSync)
    print("error calling player.calUserCoin")
end

function player.brocastCalUserCoin(uid_p, altercoin, coin, isSync)
    brodcastcoin(uid_p, altercoin, coin, isSync)
    return PDEFINE.RET.SUCCESS,0,coin
end

--type: settle, 结算 (settleCoin: 结算金币, taxCoin: 税收金币)
function player.setPlayerCoin(uid_p, coin, log, type, isSync)
    print("error calling player.setPlayerCoin")
end

--从新加载用户信息
function player.reloadPlayerInfo(uid)
    local playerInfo = playerdatamgr.reloadPlayerInfo(uid)
    if playerInfo then
        handle.syncUserInfo(playerInfo)
    end
end

function player.reloadVipInfo(uid)
    LOG_DEBUG("player.reloadVipInfo uid:", uid)
    local playerInfo = playerdatamgr.reloadPlayerInfo(uid, false)
    handle.moduleCall("upgrade", "activeVip", playerInfo.vipendtime)
    if playerInfo then
        playerInfo = player.getPlayerInfo(uid)
        local vipInfo = {
            ['uid'] = uid,
            ['playername'] = playerInfo.playername or "",
            ['svip'] = playerInfo.svip or 0,
            ['svipexp'] = playerInfo.svipexp or 0,
            ['vipendtime'] = playerInfo.vipendtime or 0,
        }
        handle.syncUserInfo(vipInfo)
    end
end

--调用apiservice
function player.callapiservice(modname, ...)
    local UID = handle.getUid()
    local token = handle.getToken()
    if token == nil or token == "" then
        return PDEFINE.RET.ERROR.TOKEN_ERR
    end
    return api_service.callAPIMod( modname, UID, token, ... )
end

local function getOnlineMult(uid)
    local mult = 0
    local total = do_redis({"get","online_bet_num:"..uid})
    if total then
        total = math.floor(total)
    end
    
    if not total then
        total = 0
    end
    mult = getMultFromTimes(total)
    return mult
end

local function getDotInfo(uid)
    local totalDot = {}  -- 已经点的页签,数字由前端定
    -- 从数据库中取出纪录
    local lastUpdateTime = do_redis({ "get", PDEFINE.REDISKEY.OTHER.reddot.."last:"..uid}, uid)  -- 最后更新时间
    local dotRecord = do_redis({ "get", PDEFINE.REDISKEY.OTHER.reddot.."record:"..uid}, uid) or 0 --今天的小红点
    local dotReward = do_redis({ "get", PDEFINE.REDISKEY.OTHER.reddot.."reward:"..uid}, uid) -- 今天是否已领取
    -- 如果是同一天，则记录有效
    if lastUpdateTime then
        local zeroTime = date.GetTodayZeroTime(lastUpdateTime)
        local nowZeroTime = date.GetTodayZeroTime(os.time())
        if zeroTime == nowZeroTime then
            totalDot = string.split_to_number(dotRecord, '.')
        end
        return totalDot, dotReward ~= nil
    end
    return {}, false
end

local function setDotInfo(uid, totalDot)
    local timeout = date.GetTodayZeroTime(os.time()) + 24*60*60 - os.time()
    do_redis({"setex", PDEFINE.REDISKEY.OTHER.reddot.."last:"..uid, os.time(), timeout}, uid)
    local dotRecord = table.concat(totalDot, '.')
    do_redis({"setex", PDEFINE.REDISKEY.OTHER.reddot.."record:"..uid, dotRecord, timeout}, uid)
end

--计算红点的奖金
local function getRedDotReward(uid)
    local playerInfo = player.getPlayerInfo(uid)
    return RED_DOT_COIN
end

--点击标签页全部小红点后获得奖励
function player.getDotBonus(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local type    = recvobj.type or 1
    type    = math.floor(type)
    local totalDot, alreadyReward = getDotInfo(uid)

    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = math.floor(recvobj.c)
    retobj.type = type
    local target = 3 --全部点满就是3个标签
    if type == 1 then
        local dotType  = recvobj.dotType
        dotType  = math.floor(dotType)
        retobj.dotType = dotType
        retobj.alreadyReward = alreadyReward --是否领取过奖励
        if not table.contain(totalDot, dotType) then
            table.insert(totalDot, dotType)
        end
        setDotInfo(uid, totalDot)
        retobj.totalDot = totalDot
    elseif type == 2 then
        -- 获取信息
        local totalDot, alreadyReward = getDotInfo(uid)
        if alreadyReward then
            retobj.spcode = PDEFINE.RET.ERROR.BONUS_HAD_GET
            return resp(retobj)
        end
        -- 记录领取记录
        local delay = date.GetTodayZeroTime(os.time()) + 24*60*60 - os.time()
        do_redis({"setex", PDEFINE.REDISKEY.OTHER.reddot.."reward:"..uid, 1, delay}, uid)
        local addCoin = getRedDotReward(uid)
        retobj.addCoin = addCoin
        local code,beforecoin, aftercoin = player_tool.funcAddCoin(uid, addCoin, "标签页奖励", PDEFINE.ALTERCOINTAG.TAG, PDEFINE.GAME_TYPE.SPECIAL.TAG_REAWARD, PDEFINE.POOL_TYPE.none, nil, nil)
        retobj.coin = aftercoin
        do_redis({"set", PDEFINE.REDISKEY.OTHER.reddot..uid, 100}, uid) --标记已经领取完了
        player.addSendCoinLog(uid, addCoin, "tagreward")
    end
    return resp(retobj)
end

--! 玩家在线奖励
function player.rewardOnline(msg, params)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local rtype   = math.floor(recvobj.rtype)--1领取在线时长奖励 2领取登录奖励 3.游戏内获取在线奖励   (1,3都是刮刮乐)
    local playerInfo = player.getPlayerInfo(uid)
    if rtype == 1 or rtype == 3 then
        local ok, list = pcall(cluster.call, "master", ".rewardonlinemgr", "getAll")
        local level = 1
        local now = os.time()
        if playerInfo ~= nil and playerInfo.level ~= nil then
            level = playerInfo.level
        end
        
        local retobj = {}
        retobj.c = math.floor(recvobj.c)
        retobj.luckSpine = false
        local mult = getOnlineMult(uid)
        for k, v in ipairs(list) do     --v.itemid == 2 默认是15分钟
            local itemid = math.floor(v.itemid)
            local _result = do_redis({"hget", "onlineAward", "uid:"..uid..":type:"..itemid})
            local result = cjson.decode(_result)
            local _lastTime = result.lastTime
            local energyCnt = result.energyCnt or 0
            local time_gap = (now - _lastTime)/60 --分钟数
            local coinPool =  math.floor(v.count*mult) 
            local randomLlist = cjson.decode(v.random) 
            local random = math.floor(randomLlist.e)
            local resetTime = getTodayLeftTimeStamp()
            coinPool = coinPool * random
            if time_gap >= v.time then    
                if itemid == 1 then  --在线4小时可以领取一次
                    if energyCnt >= 4 then  
                        energyCnt = 0
                        retobj.luckSpine = true
                        -- 玩家需要弹出幸运大转盘，
                        local retobj_spine  = {}
                        retobj_spine.c      = PDEFINE.NOTIFY.LUNCKSPINE_ONLINE
                        retobj_spine.code   = PDEFINE.RET.SUCCESS
                        handle.sendToClient(cjson.encode(retobj_spine))
                    else
                        energyCnt = energyCnt + 1
                    end
                end
                local data = {lastTime = result.lastTime, energyCnt = energyCnt}
                data.energyCnt = energyCnt
                do_redis({"hset", "onlineAward","uid:"..uid..":type:".. itemid, cjson.encode(data)})
                retobj["award_"..v.time] = {remainTime = 0, rtype = itemid, coinPool = coinPool, energyCnt = (itemid == 1 and nil or energyCnt), resetTime = resetTime}
            else
                local remainTime = (v.time - time_gap)*60
                retobj["award_"..v.time] = {remainTime = remainTime, rtype = itemid, coinPool = coinPool, addCoin = 0,energyCnt = energyCnt, resetTime = resetTime}
            end
        end
        retobj.upoints = handle.moduleCall('palace', 'getSendPoints', 'scratch')
        retobj.mult = mult
        return resp(retobj)
    elseif rtype == 2 then
        local pid = params.pid
        local ret, account = pcall(skynet.call, ".accountdata", "lua", "getUserAccount", pid)
        if playerInfo.lrwardstate == 1 then
            local ok, coin = true, 0
            if APP == 1 then
                local ok, row = pcall(cluster.call, "master", ".configmgr", "get", "rewardlogin")
                coin = tonumber(row.v)
            elseif APP == 2 then
                coin = handle.moduleCall("award","getLoinFirstCoin", account.logintype)
            end

            local noty_retobj  = {}
            noty_retobj.c      = PDEFINE.NOTIFY.coin
            noty_retobj.code   = PDEFINE.RET.SUCCESS
            noty_retobj.uid    = uid
            noty_retobj.count  = coin
            noty_retobj.coin   = (playerInfo.coin + coin)
            player_tool.calUserCoin_nogame(uid, coin, "领取登录奖励"..(coin), PDEFINE.ALTERCOINTAG.ONLINEAWARD, 0)
            player.addSendCoinLog(uid, coin, "onlinereward", playerInfo.level)
            handle.sendToClient(cjson.encode(noty_retobj))
            local retobj = { c = math.floor(recvobj.c), rtype = rtype, code = PDEFINE.RET.SUCCESS,coin = coin,spcode = PDEFINE.RET.SUCCESS}
            handle.dcCall("user_dc", "setvalue", uid, "lrwardstate", 2) --充值用户
            return resp(retobj)
        else
           local retobj = { c = math.floor(recvobj.c), rtype = rtype, code = PDEFINE.RET.SUCCESS,spcode = PDEFINE.RET.ERROR.ALREADY_AWARD}
           return resp(retobj)
        end
    end
end

--设置1次免费大转盘的数据接口
local function setTurnTableData(uid)
    local ret = false
    local setKey = "turntable_settimes:" .. uid
    local hadSetTimes = do_redis({ "get", setKey}) or 0
    hadSetTimes = math.floor(hadSetTimes)
    if hadSetTimes > 0 then
        local ok, configmgr = pcall(cluster.call, "master", ".configmgr", 'get', "turntable")
        local conf  = cjson.decode(configmgr.v)
        local now = os.time()
        local data = {}
        data.times = 1
        data.nextType = 2
        data.openTime = now - conf.delay - 86400 --上一步打开时间
        do_redis({ "hmset", "turntable:" .. uid, data, true })
        do_redis({ "incrby", setKey, -1})
        ret = true
    end
    return ret
end

--给玩家直接设定免费大转盘的数据接口(任务主线使用)
function player.setTurnTableData(uid, times)
    if times == nil then
        times = 1
    end
    do_redis({ "set", "turntable_settimes:" .. uid, times})
    setTurnTableData(uid)
    return true
end

--test 购买转盘 接口
function player.setTurnTableBuyData(uid)
    local ok, configmgr = pcall(cluster.call, "master", ".configmgr", 'get', "turntable")
        local conf  = cjson.decode(configmgr.v)
        local now = os.time()
        local data = {}
        data.times = 1
        data.nextType = 3
        data.openTime = now - conf.delay - 86400 --上一步打开时间
        do_redis({ "hmset", "turntable:" .. uid, data, true })
        do_redis({ "set", "turntable_buytimes:" .. uid, 1})
    return true
end

--! 玩家大厅领取转盘奖金，3次机会，领取2次后，可以领取大转盘
function player.collectionCoins(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local rtype   = math.floor(recvobj.type)--1.收集金币  2免费大转盘
    local playerInfo = player.getPlayerInfo(uid)
    local ok, configmgr = pcall(cluster.call, "master", ".configmgr", 'get', "turntable")
    local conf  = cjson.decode(configmgr.v)
    local nextTime = 0 --下一次领取时间
    local idx = 0
    local  tmp = 0
    local retobj = {}
    retobj.c = math.floor(recvobj.c)
    retobj.rewards = {}
    retobj.type = rtype
    retobj.nextType = 1 --1:1小时候收集金币  2：幸运大转盘
    local turntableCacheData = do_redis({ "hgetall", "turntable:" .. uid}) --玩家缓存的转盘领取数据
    turntableCacheData = make_pairs_table(turntableCacheData)
    local openTime, times, nextType, abortTime, resetTime
    if nil ~= turntableCacheData then
        times     = turntableCacheData["times"] --这1轮的剩余次数
        nextType  = turntableCacheData["nextType"] --下次操作的类型: 1:1小时候收集金币  2：幸运大转盘
        openTime  = turntableCacheData["openTime"] --领取开始的时间
        abortTime = turntableCacheData["abortTime"]
        resetTime = turntableCacheData["resetTime"]
    end
    local collect = false
    if rtype ~= 3 then  -- 1. 2类型抽奖需要时间间隔。
        local now = os.time()
        local data = {}
        if openTime == nil or times == nil then
            tmp = 1
            data.times = conf.times
            data.openTime = now
            data.nextType = 1
            nextTime = conf.delay
        else
            LOG_DEBUG("times:", times, ' openTime:', openTime, "abortTime:", abortTime, ' resetTime:', resetTime)
            times = math.floor(times)
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
                do_redis({"hdel", "turntable:" .. uid, "abortTime"})
                do_redis({"hdel", "turntable:" .. uid, "resetTime"})
            end
            
            LOG_DEBUG("spendTime:", spendTime, ' conf.delay:', conf.delay)
            local needProcessSetTimes = false
            if spendTime >= conf.delay then
                collect = true
                data.times = times - 1
                tmp = conf.times - times + 1
                nextTime = conf.delay
                data.openTime = now
                data.nextType = 1
                if data.times == 1 then -- 最后一次是幸运大转盘
                    retobj.nextType = 2  --幸运大转盘
                    data.nextType = 2
                end
                if data.times == 0 then
                    data.times = conf.times
                    data.nextType = 1   --回到在线奖励
                    retobj.nextTime = conf.delay         ---回到在线奖励
                    retobj.nextType = 1
                    needProcessSetTimes = true
                end
            else
                nextTime = conf.delay - (now - openTime)
                retobj.idx = idx
                retobj.addCoin = 0
                retobj.addDiamond = 0
                retobj.nextTime = nextTime > 0 and nextTime or 0
                retobj.code = PDEFINE.RET.ERROR.TIMEOUT
                return resp(retobj)
            end  
            if needProcessSetTimes then
                local boolResult = setTurnTableData(uid) --任务里可能需要设置多个
                if not boolResult then
                    do_redis({ "hmset", "turntable:" .. uid, data, true })
                end
            else
                do_redis({ "hmset", "turntable:" .. uid, data, true })
            end
        end
    else
        if nextType and math.floor(nextType) == rtype then
            collect = true
        end
    end

    if times then
        times = math.floor(times)
    end
    local addDiamond, addCoin = 0, 0
    if collect then
        if rtype == 1 and (times == nil or (times > 1 and times <= conf.times) ) then
            if tmp > #conf.coins then
                assert()
            end
            addCoin = conf.coins[tmp]
            handle.addProp(1, addCoin, 'turntable')
        elseif rtype == 2 and (times ~= nil and times == 1) then --只剩最后一次了

            idx = lottery(conf.rate_1)
            local item = conf.cfg_1[idx]
            if item.s == PDEFINE.PROP_ID.COIN then
                addCoin = item.n
            else
                addDiamond = item.n
            end
            handle.addProp(item.s, item.n, 'turntable')
            idx = idx -1 --兼容客户端数据，配置数据js会转成从0开始
        end
        player.syncLobbyInfo(uid)
    end

    if addDiamond > 0 or addCoin > 0 then
        if addDiamond > 0 then
            table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.DIAMOND, count=addDiamond})
        end
        if addCoin > 0 then
            table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN, count=addCoin})
        end
        handle.notifyCoinChanged(playerInfo.coin, playerInfo.diamond, addCoin, addDiamond)
        if nextTime > 0 then
            handle.rewardTurntable(nextTime * 100)
        end
    end

    retobj.idx = idx
    retobj.addCoin = addCoin
    retobj.addDiamond = addDiamond
    retobj.nextTime = nextTime
    retobj.code = PDEFINE.RET.SUCCESS
    local msgs = "turntable"
    if times then
        msgs = msgs .. times
    end
    player.addSendCoinLog(uid, addCoin, msgs, playerInfo.level, addDiamond)
    
    return resp(retobj)
end

--! 获取大转盘的配置数据
function player.getSpineConf(msg)
    local recvobj = cjson.decode(msg)
    local ok, configmgr  = pcall(cluster.call, "master", ".configmgr", 'get', "turntable")
    local conf  = cjson.decode(configmgr.v)
    local retobj = {}
    retobj.c = math.floor(recvobj.c)
    local tmp_conf = {}
    for _, item in pairs(conf.cfg_1) do
        item.type = item.s
        item.count = item.n
        item.s = nil
        item.n = nil
        table.insert(tmp_conf, item)
    end
    retobj.conf = tmp_conf
    return resp(retobj)
end

-- 计算转盘这次能获得多少金币
local function calTurnTableAddCoin(uid)
    local addCoin = 0
    local openTime, times, abortTime, resetTime
    local ok, configmgr = pcall(cluster.call, "master", ".configmgr", 'get', "turntable")
    local conf  = cjson.decode(configmgr.v)
    local turntableCacheData = do_redis({ "hgetall", "turntable:" .. uid}) --玩家缓存的转盘领取数据
    turntableCacheData = make_pairs_table(turntableCacheData)
    if nil ~= turntableCacheData then
        times     = turntableCacheData["times"] --这1轮的剩余次数
        openTime  = turntableCacheData["openTime"] --领取开始的时间
        abortTime = turntableCacheData["abortTime"]
        resetTime = turntableCacheData["resetTime"]
    end
    local now = os.time()
    local tmp = 1
    if openTime == nil or times == nil then
        tmp = 1
    else
        openTime = math.floor(openTime)
        --离线停止时间
        local spendTime = now - openTime 
        if abortTime ~= nil and resetTime ~= nil then
            abortTime = math.floor(abortTime)
            resetTime = math.floor(resetTime)
            local t_1 = abortTime - openTime
            local t_2 = now - resetTime
            spendTime = t_1 + t_2
        end
        
        if spendTime >= conf.delay then
            tmp = conf.times - times + 1
        end  
    end
    if times then
        times = math.floor(times)
    end
    if (times == nil or (times > 1 and times <= 3) ) then
        if tmp > #conf.coins then
            tmp = 1
        end
        addCoin = conf.coins[tmp]
    end
    return addCoin
end

-- 大转盘相关
function player.getTurnTableData(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local ok, configmgr = pcall(cluster.call, "master", ".configmgr", 'get', "turntable")
    local conf  = cjson.decode(configmgr.v)

    local turntableCacheData = do_redis({ "hgetall", "turntable:" .. uid}) --玩家缓存的转盘领取数据
    turntableCacheData = make_pairs_table(turntableCacheData)
    local openTime, times, nextType, abortTime, resetTime
    if nil ~= turntableCacheData then
        times     = turntableCacheData["times"] --这1轮的剩余次数
        nextType  = turntableCacheData["nextType"] --下次操作的类型: 1:1小时候收集金币  2：免费转盘
        openTime  = turntableCacheData["openTime"] --领取开始的时间
        abortTime = turntableCacheData["abortTime"]
        resetTime = turntableCacheData["resetTime"]
    end

    local now = os.time()
    local data = {}
    if openTime ~= nil and nextType ~= nil then
        local tmp
        if abortTime ~= nil and resetTime ~= nil  then
            tmp = conf.delay - ((now - resetTime) + (abortTime - openTime))
        else
            tmp = conf.delay - ( now- openTime)
        end
        data.time = tmp > 0 and tmp or 0 --倒计时
        if math.floor(nextType) == 2 then
            data.nextType = 2
            data.times = conf.times - 1
        else
            data.nextType = math.floor(nextType)
            data.times = 0 --已经领取的次数
            if nil ~= times then
                data.times = conf.times - times
            end
        end
    else
        local tmp_data = {}
        tmp_data.openTime = now - conf.delay -- 确保新用户进游戏能转一次, 将opentime往前推delay
        tmp_data.nextType = 1
        tmp_data.times = conf.times
        data.time = 0
        data.times = 0 --已经领取次数
        data.nextType = 1
        do_redis({ "hmset", "turntable:" .. uid, tmp_data, true })
    end
    data.coin = calTurnTableAddCoin(uid)
    local retobj  = {}
    retobj.c      = math.floor(recvobj.c)
    retobj.code   = PDEFINE.RET.SUCCESS
    retobj.data = data
    return resp(retobj)
end

-- 主动同步大厅红点信息给客户端
local function syncLobbyInfo(uid)
    if nil == uid then
        return
    end
    local retobj = {}
    retobj.c =  PDEFINE.NOTIFY.SYNCLOBBYINFO
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.uid = uid

    retobj.friendsmsg = {} --最近好友聊天消息
    local beginTime = os.time() - 30 * 86400
    local sql = string.format( "select sum(unread) as unt, md5 from d_chat_user where uid2=%d and unread=1 and create_time>=%d and blocked=0 and del2=0 group by md5;", uid, beginTime)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        local tmp = {}
        local md5List = {}
        for _, row in pairs(rs) do
            tmp[row.md5] = row.unt
            table.insert(md5List, "'"..row.md5.."'")
        end
        local sql2 = string.format( "select uid1,uid2,md5 from d_chat_user where md5 in (%s) and create_time>=%d and blocked=0", table.concat( md5List, ","), beginTime)
        local rs2 = skynet.call(".mysqlpool", "lua", "execute", sql2)
        local added = {}
        if #rs2 > 0 then
            for _, row in pairs(rs2) do
                if added[row.md5] == nil then
                    local tuid = row.uid1
                    if row.uid1 == uid then
                        tuid = row.uid2
                    end
                    retobj.friendsmsg[tuid] = tmp[row.md5]
                    added[row.md5] = 1
                end
            end
        end
    end

    retobj.friendscnt =0
    local beginTime = os.time() - 30 * 86400
    local sql = string.format( "select sum(unread) as unt from d_chat_user where uid2=%d and unread=1 and del2=0 and create_time>=%d and blocked=0", uid, beginTime)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        retobj.friendscnt = rs[1].unt
    end
    local mailTypes  = mailbox.getUnRecieved(uid) --未读消息
    retobj.mail_notify = mailTypes['notify']
    retobj.mail_gift = mailTypes['gift']
    retobj.mail_activity = mailTypes['activity']
    
    retobj.social = 1 --今日聊天红点标记，每天1次
    local social_today = do_redis({'get', 'today_social'..uid})
    if social_today then
        retobj.social = 0
    else
        local leftTime = getTodayLeftTimeStamp()
        do_redis( {"setex", 'today_social'..uid, 1, leftTime})
    end

    retobj.friend = 0 --好友请求列表
    local sql= string.format("select count(*) as t from d_friend_request where frienduid=%d", uid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        retobj.friend = rs[1].t
    end

    local dailyCnt, dailyGet = handle.moduleCall("quest","hasDoneByType",uid)
    retobj.daily = dailyCnt --每日任务
    retobj.dailyGet = dailyGet --每日任务上面的红点
    
    retobj.vipbonus = handle.moduleCall("viplvtask", "getBonusCnt", uid) --vip可领取的
    retobj.freediamond = 0 --商城免费钻石领取
    retobj.freecoin = 0 --商城免费金币领取
    retobj.invite = handle.moduleCall("invite", "canClaim", uid) --累计邀请好友的奖励是否可以领取
    
    --沙龙房红点
    retobj.fall = 0
    local ok, gameidList = pcall(cluster.call, "master", ".balprivateroommgr", "getOwnerDeskGameIdList", uid)
    if ok then
        if table.size(gameidList) > 0 then
            for gameid, cnt in pairs(gameidList) do
                retobj['f'..gameid] = cnt
                retobj.fall = retobj.fall + cnt
            end
        end
    end

    -- 主线任务
    local userLevel = handle.dcCall("user_dc", "getvalue", uid, "level")
    local mainTaskCnt = handle.moduleCall("maintask", "reddot", uid, userLevel)
    retobj.maintask = mainTaskCnt

    --是否可以在线领取大转盘类的奖励了 1是 0否
    local turntable = 0 
    local cacheKey = "turntable:" .. uid
    local ok, configmgr = pcall(cluster.call, "master", ".configmgr", 'get', "turntable")
    local conf = cjson.decode(configmgr.v)
    local turntableCacheData = do_redis({ "hgetall", cacheKey}) --玩家缓存的转盘领取数据
    turntableCacheData = make_pairs_table(turntableCacheData)
    local openTime, times, abortTime, resetTime
    if nil ~= turntableCacheData then
        times = turntableCacheData.times --这1轮的剩余次数
        openTime = turntableCacheData.openTime --上次开始的时间
        abortTime = turntableCacheData.abortTime --上次开始后中断的时间
        resetTime = turntableCacheData.resetTime --这次重新接着开始的时间
    end
    if openTime ~= nil and times ~= nil then
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
        end
        
        if spendTime >= conf.delay then
            turntable = 1
        end
    end
    retobj.turntable = turntable

    retobj.getviplv = 0 --是否有vip道具可以领取

    retobj.rakeback = 0 --下注返利的领取红点
    if player.hasRakeBackReward(uid) then
        retobj.rakeback = 1
    end
    retobj.fbshare = getFbShareTag(uid)

    -- 金转盘可转次数
    local times = handle.dcCall("user_data_dc","get_common_value", uid, PDEFINE.USERDATA.COMMON.TIMES_OF_TURNTABLE)
    retobj.bonuswheel = tonumber(times or 0)

    --邀请码被绑定奖励是否领取
    local sql = string.format("select count(1) cnt from d_user_invite where status = 0 and invit_uid = %d", uid)
    local res = skynet.call(".mysqlpool", "lua", "execute", sql)
    retobj.fbinvite = res[1].cnt

    -- 通行证是否有可领取任务
    retobj.pass = 0

    -- 俱乐部是否有申请用户
    -- local club = handle.moduleCall("club", "syncStatus", uid)
    -- retobj.club = club

    local doneCnt = handle.moduleCall("quest", "noviceTaskDone", uid)
    retobj.novice = doneCnt --新手任务

    retobj.proom = 1 --私人房创建按钮上,需要亮红点
    local guideData = handle.dcCall("user_dc", "getvalue", uid, "guide")
    if guideData~=nil and type(guideData) =="string" then
        local ok, guide = pcall(jsondecode, guideData)
        if ok and table.size(guide) > 0 then
            retobj.proom = 0 --不需要亮红点
        end
        
    end

    -- 每日特殊任务
    retobj.salon, retobj.salonp = handle.moduleCall("quest", "getSpecialQuestRedot", uid)
    retobj.saloncoin = handle.moduleCall("privateroom", "getIncomeDot", uid) --是否有沙龙收益

    --签到
    retobj.sign = 0
    local sign = handle.moduleCall("sign", "checkSignInfo", uid)
    if sign == 0 then
        retobj.sign = 1
    end

    --transbonus可转移金额红点
    retobj.transbonus = 0
    if handle.moduleCall("viplvtask", "getTransableCoin", uid) > 0 then
        retobj.transbonus = 1
    end

    handle.sendToClient(cjson.encode(retobj))
end

-- 包装一层
function player.syncLobbyInfo(uid)
    -- 这里做一下处理，2秒内，只会发送一次
    if stay_in_synclobbyinfo or not uid then
        return
    end
    stay_in_synclobbyinfo = 1
    local uid = uid
    skynet.timeout(delay_for_synclobbyinfo*100, function()
        stay_in_synclobbyinfo = nil
        syncLobbyInfo(uid)
    end)
end

--！ 获取排行榜前三
function player.getRankTop5(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local rtype     = math.floor(recvobj.type)
    local gameid     = math.floor(recvobj.gameid or 0)
    local limit     = math.floor(recvobj.limit or 5)
    local iscache = recvobj.cache --是否缓存请求
    local ok, dataList, aiUserData = pcall(cluster.call, "master", ".winrankmgr", "getRankTop3ByType", uid, rtype, gameid, limit)
    local data = {}
    if #dataList > 0 then
        for i=1, #dataList do
            if i >5 then
                break
            end
            dataList[i].rankscore = 0
            local userid = dataList[i].uid
            if aiUserData[userid] then
                dataList[i].playername = aiUserData[userid].playername
                dataList[i].usericon = aiUserData[userid].usericon
                dataList[i].avatarframe = 0
            else
                local userInfo = player_tool.getSimplePlayerInfo(userid)
                if nil == dataList[i].playername or ""==dataList[i].playername or #dataList[i].playername == 0 then
                    dataList[i].playername = "Guest"
                    dataList[i].usericon = ""
                    LOG_DEBUG("user no usericion or playername:", userid)
                end
                if userInfo then
                    dataList[i].playername = userInfo.playername
                    dataList[i].usericon = userInfo.usericon
                    dataList[i].avatarframe = userInfo.avatarframe
                    dataList[i].rankscore = userInfo.leagueexp
                end
            end
            -- 获取的是总排行，显示的头像框不同
            if gameid == 0 then
                if i == 1 then
                    dataList[i].avatarframe = PDEFINE.SKIN.RANKDIAMOND.TOP1.AVATAR.img
                elseif i == 2 then
                    dataList[i].avatarframe = PDEFINE.SKIN.RANKDIAMOND.TOP2.AVATAR.img
                elseif i == 3 then
                    dataList[i].avatarframe = PDEFINE.SKIN.RANKDIAMOND.TOP3.AVATAR.img
                end
            else
                if i == 1 then
                    dataList[i].avatarframe = PDEFINE.SKIN.LEAGUE.TOP1.AVATAR.img
                elseif i == 2 then
                    dataList[i].avatarframe = PDEFINE.SKIN.LEAGUE.TOP2.AVATAR.img
                elseif i == 3 then
                    dataList[i].avatarframe = PDEFINE.SKIN.LEAGUE.TOP3.AVATAR.img
                end
            end
            dataList[i].ord = i
            if rtype == 1 then
                dataList[i].king = 0
                if isKing(userid) then
                    dataList[i].king = 1 --king标志
                end
            end
            table.insert(data, dataList[i])
        end
    end

    if rtype == 12 then --子游戏排位列表，用户打开了场次入口
        if not iscache then
            handle.addStatistics(uid, 'open_game_sess', '', gameid)
        end
    end

    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, datalist = data, gameid=gameid}
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 获取排行榜概要
function player.getTopRankList(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local ok, ret, aiUserData = pcall(cluster.call, "master", ".winrankmgr", "getTopRankList", uid)
    local data = {}
    for rtype,dataList in pairs(ret) do
        local key = 'datalist'.. rtype
        if nil == data[key] then
            data[key] = {}
        end
        if #dataList > 0 then
            for i=1, #dataList do
                if i >3 then
                    break
                end
                dataList[i].rankscore = 0
                local userid = dataList[i].uid
                if aiUserData[userid] then
                    dataList[i].playername = aiUserData[userid].playername
                    dataList[i].usericon = aiUserData[userid].usericon
                    dataList[i].avatarframe = 0
                else
                    local userInfo = player_tool.getSimplePlayerInfo(userid)
                    if nil == dataList[i].playername or ""==dataList[i].playername or #dataList[i].playername == 0 then
                        dataList[i].playername = "Guest"
                        dataList[i].usericon = ""
                        LOG_DEBUG("user no usericion or playername:", userid)
                    end
                    if userInfo then
                        dataList[i].playername = userInfo.playername
                        dataList[i].usericon = userInfo.usericon
                        dataList[i].avatarframe = userInfo.avatarframe
                        dataList[i].rankscore = userInfo.leagueexp
                        
                    end
                end
                if i == 1 then
                    dataList[i].avatarframe = PDEFINE.SKIN.RANKDIAMOND.TOP1.AVATAR.img
                elseif i == 2 then
                    dataList[i].avatarframe = PDEFINE.SKIN.RANKDIAMOND.TOP2.AVATAR.img
                elseif i == 3 then
                    dataList[i].avatarframe = PDEFINE.SKIN.RANKDIAMOND.TOP3.AVATAR.img
                end
                dataList[i].ord = i
                if rtype == 1 then
                    dataList[i].king = 0
                    if isKing(userid) then
                        dataList[i].king = 1 --king标志
                    end
                end
                table.insert(data[key], dataList[i])
            end
        end
    end
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, datalist = data}
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

local function changeVipExp2Lv(svipexp, vipendtime)
    -- if vipendtime == nil or vipendtime == 0 then
    --     return 0
    -- end
    local vipCfg = getVipCfg()
    local now = os.time()
    -- if vipendtime < now then
    --     return 0
    -- end

    for i=#vipCfg, 1, -1 do
        if vipCfg[i].diamond <= svipexp then
            return i
        end
    end
    return 0
end

-- 排行榜(按天刷新)
-- 总赢榜，总押注榜单, 赢最大奖排序
-- type: 1=财富版 2=当日赢取排行 3=排位分数 4=好友财富排行 5=好友排位分 10=钻石消耗排行榜
function player.getRankList(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local rtype = recvobj.type or 1
    local iscache = recvobj.cache --是否缓存请求
    local gameid = recvobj.gameid or 257
    local user_order = 101
    local playerInfo = player.getPlayerInfo(uid)
    local ok, dataList, user_score, aiUsersData  = pcall(cluster.call, "master", ".winrankmgr", "getRankList", rtype, uid, gameid)
    -- LOG_DEBUG("player.getRankList ok:",ok, ' dataList:', dataList, ' user_score:', user_score)
    if ok and #dataList > 0 then
        if rtype == PDEFINE.RANK_TYPE.VIP_WEEK then
            table.sort(dataList, function (a, b)
                if a.coin > b.coin then
                    return true
                end
                return false
            end)
        end
        for i=1, #dataList do
            local userid = dataList[i].uid
            dataList[i].level = 1
            dataList[i].vip = 0
            dataList[i].avatarframe = 0
            dataList[i].country = 0
            dataList[i].rankscore = dataList[i].coin

            if aiUsersData[userid] then
                dataList[i].playername = aiUsersData[userid].playername
                dataList[i].usericon = aiUsersData[userid].usericon

                local random_level = do_redis({"get", "ai_user_tmp_level"..userid})
                if not random_level then
                    random_level = math.random(5, 110)
                    do_redis({"setnx", "ai_user_tmp_level"..userid, random_level, 3600})
                end
                dataList[i].level = random_level
            else
                local userInfo = player_tool.getSimplePlayerInfo(userid)
                if nil == dataList[i].playername or ""==dataList[i].playername or #dataList[i].playername == 0 then
                    dataList[i].playername = "Guest"
                    dataList[i].usericon = ""
                end
                if userInfo then
                    dataList[i].playername = userInfo.playername
                    dataList[i].usericon = userInfo.usericon
                    dataList[i].level = userInfo.level
                    dataList[i].vip = changeVipExp2Lv(userInfo.svipexp, userInfo.vipendtime)
                    dataList[i].avatarframe = userInfo.avatarframe
                    dataList[i].country = userInfo.country
                end
            end
            if i == 1 then
                dataList[i].avatarframe = PDEFINE.SKIN.RANKDIAMOND.TOP1.AVATAR.img
                if rtype == PDEFINE.RANK_TYPE.GAME_LEAGUE then
                    dataList[i].avatarframe = PDEFINE.SKIN.LEAGUE.TOP1.AVATAR.img
                end
            elseif i == 2 then
                dataList[i].avatarframe = PDEFINE.SKIN.RANKDIAMOND.TOP2.AVATAR.img
                if rtype == PDEFINE.RANK_TYPE.GAME_LEAGUE then
                    dataList[i].avatarframe = PDEFINE.SKIN.LEAGUE.TOP2.AVATAR.img
                end
            elseif i == 3 then
                dataList[i].avatarframe = PDEFINE.SKIN.RANKDIAMOND.TOP3.AVATAR.img
                if rtype == PDEFINE.RANK_TYPE.GAME_LEAGUE then
                    dataList[i].avatarframe = PDEFINE.SKIN.LEAGUE.TOP3.AVATAR.img
                end
            end
            dataList[i].ord = i
            if rtype == 1 then
                dataList[i].king = 0
                if isKing(userid) then
                    dataList[i].king = 1 --king标志
                end
            end
            if user_order==101 and dataList[i].uid == uid then
                user_order = i
            end
        end
    end

    local act = 'rank_totalwin'
    if rtype == 2 then
        act = 'rank_totalbet'
    elseif rtype == 3 then
        act = 'rank_winning'
    elseif rtype == 4 then
        act = 'rank_friends_coin'
    elseif rtype == 5 then
        act = "rank_friends_league"
    elseif rtype == 6 then
        act = "rank_week_charm"
    elseif rtype == 7 then
        act = "rank_month_charm"
    elseif rtype == 8 then
        act = "rank_total_charm"
    elseif rtype == 10 then
        act = "rank_week_diamond"
    elseif rtype == 13 then
        act = "rand_vipexp"
    end
    if not iscache then
        handle.addStatistics(uid, act, '')
    end
    -- 构造用户排名
    if user_order == 0 and #dataList > 0 then
        if tonumber(user_score) <= tonumber(dataList[#dataList].coin) then
            user_order = 101
        end
    end
    local myself = {
        ["ord"] = user_order, --排名
        ["uid"] = uid,
        ["playername"] = playerInfo.playername,
        ["usericon"] = playerInfo.usericon,
        ["coin"] = user_score,
        ['country'] = playerInfo.country,
        ['level'] = playerInfo.level,
        ['vip'] = changeVipExp2Lv(playerInfo.svipexp, playerInfo.vipendtime),
        ['avatarframe'] = playerInfo.avatarframe, --头像框id
        ['rankscore'] = playerInfo.leagueexp or 0,
    }
    local ok, leagueArr = pcall(cluster.call, "master", ".cfgleague", "getCurAndNextLvInfo", playerInfo.leaguelevel)
    if ok then
        myself.rankscore = leagueArr[1].score + myself.rankscore
    end
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, datalist = dataList, myself= myself, type=rtype}
    retobj['end'], retobj['start'] = getWeekEndTimestamp()
    -- retobj['end'] = getWealthRankNextSettleTime() --财富榜下次结算时间

    -- 更新主线任务
    -- local updateMainObjs = {
    --     {kind=PDEFINE.MAIN_TASK.KIND.ViewRank, count=1},
    -- }
    -- handle.moduleCall("maintask", "updateTask", uid, updateMainObjs)

    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--游客登录绑定FB
function player.bindFaceBook(msg, params)
    local pid = params.pid
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid) --当前登录的uid
    local accesstoken = recvobj.accesstoken --accesstoken 从客户端的
    local token  = recvobj.token or ""  --授权token
    if token == "" then
        token = accesstoken
    end
    local bpid   = recvobj.user   --玩家fb pid
    local type = recvobj.type or 12 -- type: fb or google
    type = math.floor(type)

    local userinfo
    local playerInfo = player.getPlayerInfo(uid)
    if type == 12 then
        --此账号已绑定过FB
        if playerInfo.isbindfb and playerInfo.isbindfb > 0 then
            local retobj = { c = math.floor(recvobj.c), type=type, code = PDEFINE.RET.SUCCESS, spcode = PDEFINE.RET.ERROR.BIND_FB_AGAIN, accesstoken=accesstoken,token=token, user=bpid, fbtoken=accesstoken, fbuid=bpid}
            retobj.account = bpid
            retobj.playername = playerInfo.playername
            retobj.usericon = playerInfo.usericon
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end

        --此FB账号已经绑定过
        local ok, hasBind, bindUid = pcall(cluster.call, "login", ".accountdata", "get_account_by_indexkey",bpid)
        if ok and hasBind then
            --如果绑定的fb已经绑定过其他账号，直接采用fb登录新账号
            local retobj = { c = math.floor(recvobj.c), type=type, code = PDEFINE.RET.SUCCESS, spcode = PDEFINE.RET.ERROR.BIND_FB_USEAGAIN, accesstoken=accesstoken,token=token, user=bpid, fbtoken=accesstoken, fbuid=bpid}
            retobj.account = bpid
            local bindUserInfo = player.getPlayerInfo(bindUid)
            retobj.playername = bindUserInfo.playername
            retobj.usericon = bindUserInfo.usericon
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end

        local ok , ret = pcall(skynet.call, ".facebook", "lua", "verify", bpid, token)
        if not ok or not ret then
            return PDEFINE.RET.ERROR.BIND_FB_VALIDATE
        end
        local ok, ret
        ok, ret, userinfo = pcall(skynet.call, ".facebook", "lua", "userinfo", token)
        if not ok or ret ~= 200 then
            return PDEFINE.RET.ERROR.BIND_FB_DATA
        end
        player.upFBAccessToken(uid, token, 0, userinfo.pic)
        do_redis_withprename("", {"lpush", PDEFINE_REDISKEY.QUEUE.USER_BIND, string.format("%s|%s|fb", uid, token)}) --将fb头像保存到本地
    elseif type == 10 then
        -- 谷歌绑定
        if playerInfo.isbindgg and playerInfo.isbindgg > 0 then
            return PDEFINE.RET.ERROR.BIND_FB_AGAIN
        end
        --此谷歌账号已经绑定过
        local ok, hasBind = pcall(cluster.call, "login", ".accountdata", "get_account_by_indexkey",bpid)
        if ok and hasBind then
            --如果绑定过已经绑定过其他uid账号，直接登录
            local retobj = { c = math.floor(recvobj.c), type=type, code = PDEFINE.RET.SUCCESS, spcode = PDEFINE.RET.ERROR.BIND_FB_USEAGAIN, accesstoken=accesstoken,token=token, user=bpid, fbtoken=accesstoken, fbuid=bpid}
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end
        local ok, ret
        ok, ret, userinfo = pcall(skynet.call, ".google", "lua", "verifyAndGetInfo", bpid, token)
        if not ok or not ret then
            return PDEFINE.RET.ERROR.BIND_FB_VALIDATE
        end
    elseif type == 11 then
        if playerInfo.isbindapple and playerInfo.isbindapple > 0 then
            return PDEFINE.RET.ERROR.BIND_FB_AGAIN
        end
        local ok, hasBind = pcall(cluster.call, "login", ".accountdata", "get_account_by_indexkey",bpid)
        if ok and hasBind then
            --如果绑定过已经绑定过其他uid账号，直接登录
            local retobj = { c = math.floor(recvobj.c), type=type, code = PDEFINE.RET.SUCCESS, spcode = PDEFINE.RET.ERROR.BIND_FB_USEAGAIN, accesstoken=accesstoken,token=token, user=bpid, fbtoken=accesstoken, fbuid=bpid}
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end
    end
    --临时存储，登录的时候跳过第三方验证
    do_redis({"setex", "t_" .. accesstoken, uid, 3600}) 

    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, addcoin = 0, type=type}
    local row = {}
    row["uid"]        = uid
    row["pid"]        = bpid
    row["logintype"]     = type
    if type == 12 or type == 10 then
        userinfo.name = filter_spec_chars(userinfo.name)
        row["playername"] = userinfo.name
        row["usericon"]   = userinfo.pic
        row["sex"] = userinfo.sex
    end
    local ok = pcall(cluster.call, "login", ".accountdata", "set_account_data", uid, row)
    if ok then
        local msg = "绑定fb"
        if type == 12 then
            handle.dcCall("user_dc", "setvalue", uid, "isbindfb", 1) 
            handle.dcCall("user_dc", "setvalue", uid, "playername", userinfo.name) 
            -- handle.dcCall("user_dc", "setvalue", uid, "usericon", userinfo.pic.. '&access_token='..accesstoken) 
            handle.dcCall("user_dc", "setvalue", uid, "fbicon", userinfo.pic.. '&access_token='..accesstoken) --fb头像地址
            retobj.playername = userinfo.name
            retobj.usericon = userinfo.pic
        elseif type == 10 then
            if not playerInfo.isbindfb or playerInfo.isbindfb ==0 then --只有没有绑定过fb的情况下，绑定谷歌才更新用户名和头像
                handle.dcCall("user_dc", "setvalue", uid, "playername", userinfo.name) 
                handle.dcCall("user_dc", "setvalue", uid, "usericon", userinfo.pic)
            end
            handle.dcCall("user_dc", "setvalue", uid, "isbindgg", 1) 
            msg = "绑定google"
            retobj.playername = userinfo.name
            retobj.usericon = userinfo.pic
        elseif type == 11 then --苹果登录
            handle.dcCall("user_dc", "setvalue", uid, "isbindapple", 1) 
        end
        retobj.rewards = {}
        retobj.account = bpid
        retobj.user = bpid 
        retobj.accesstoken = recvobj.accesstoken
        retobj.token = token
        if type == 12 then --fb头像带access_token
            retobj.usericon = userinfo.pic .. '&access_token='..token
            -- 更新主线任务
            -- local updateMainObjs = {
            --     {kind=PDEFINE.MAIN_TASK.KIND.BindFB, count=1},
            -- }
            -- handle.moduleCall("maintask", "updateTask", uid, updateMainObjs)
            handle.moduleCall("quest", 'updateQuest', uid, PDEFINE.QUEST_TYPE.NEWER, PDEFINE.QUESTID.NEW.LINKFB, 1)
        end
        retobj.rewards = handle.moduleCall("quest", 'getRewards', uid, {PDEFINE.QUESTID.NEW.LINKFB})
        pcall(cluster.send, "master", ".agentdesk", "callAgentFun", playerInfo.uid, 'updateUserInfo', playerInfo.uid)
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end


--游客登录绑定FB 测试
function player.testbindFaceBook(msg, params)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid) --当前登录的uid
    local accesstoken = recvobj.accesstoken --accesstoken 从客户端的
    local token  = recvobj.token or ""  --授权token

    local retobj = {c = 244, code = PDEFINE.RET.SUCCESS, addcoin = 0, type=12, spcode = PDEFINE.RET.ERROR.BIND_FB_USEAGAIN}
    local row = {}
    row["uid"]        = uid
    row['account'] = '23432424234323242342'
    row["logintype"]     = 12
    row["playername"] = 'testBindFB'
    row["usericon"]   = '1'
    retobj.account = '23432424234323242342'
    retobj.playername = 'testBindFB2323'
    retobj.usericon = '23'
    retobj.accesstoken = "6946d03e6240bcdbfaf345119aec2aca"
    retobj.token = "1660817472643_38192296"
    local ok = pcall(cluster.call, "login", ".accountdata", "set_account_data", uid, row)
    if ok then

        local msg = "绑定fb"
        local testfbicon = 'https://img0.baidu.com/it/u=2125945748,287691266&fm=253&fmt=auto&app=138&f=JPEG?w=500&h=500'
        handle.dcCall("user_dc", "setvalue", uid, "isbindfb", 1) 
        handle.dcCall("user_dc", "setvalue", uid, "playername", row["playername"]) 
        handle.dcCall("user_dc", "setvalue", uid, "usericon", testfbicon) 
        handle.dcCall("user_dc", "setvalue", uid, "fbicon", testfbicon) --fb头像地址

        retobj.playername = row["playername"]
        retobj.usericon = testfbicon
        -- 更新主线任务
        -- local updateMainObjs = {
        --     {kind=PDEFINE.MAIN_TASK.KIND.BindFB, count=1},
        -- }
        -- handle.moduleCall("maintask", "updateTask", uid, updateMainObjs)
        handle.moduleCall("quest", 'updateQuest', uid, PDEFINE.QUEST_TYPE.NEWER, PDEFINE.QUESTID.NEW.LINKFB, 1)
        retobj.rewards = handle.moduleCall("quest", 'getRewards', uid, {PDEFINE.QUESTID.NEW.LINKFB})
    end
    handle.sendToClient(cjson.encode(retobj))
    return PDEFINE.RET.SUCCESS
end

--发送短信验证码
function player.sendsms(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid) --当前登录的uid
    local phone  = recvobj.phone or "" --手机号

    --TODO:需要加一些频率控制策略

    local retobj = {c=math.floor(recvobj.c), code= PDEFINE.RET.SUCCESS, spcode = 0, uid=uid, phone = phone, voice=0, msg=''}
    if isempty(phone) then --手机号不能为空，必须是纯数字的字符串
        -- (string.match(phone,"%d+") ~= phone)
        retobj.spcode = PDEFINE_ERRCODE.ERROR.PARAM_MOBILE
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    local playerInfo = player.getPlayerInfo(uid)
    if playerInfo.isbindphone and playerInfo.isbindphone > 0 then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.HAD_BANDING_MOBILE
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    local ok, retCode, result = pcall(skynet.call, ".sms", "lua", "sendmsg", uid, phone)
    retobj.voice = 0
    if retCode == PDEFINE.RET.SUCCESS then
        retobj.spcode = result.spcode
        retobj.msg    = result.msg
        retobj.voice  = result.voice
    end
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end


--游客绑定手机号
function player.bindmobile(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid) --当前登录的uid
    local mobile  = recvobj.phone or "" --手机号
    local code    = recvobj.code or "" --验证码
    local pwd     = recvobj.pwd or '' --密码
    local name = recvobj.name or ''
    local dinfo = recvobj.dinfo or '' --设备信息

    local retobj = {c=math.floor(recvobj.c), code= PDEFINE.RET.SUCCESS, spcode = 0, uid=uid, phone = mobile}
    if os.time() < bindmobileTime + 30 then
        retobj.spcode = PDEFINE.RET.ERROR.PARAM_SMSCODE
        return resp(retobj)
    end
    bindmobileTime = os.time()
    if isempty(mobile) then --手机号不能为空，必须是纯数字的字符串
        -- (string.match(mobile,"%d+") ~= mobile)
        retobj.spcode = PDEFINE_ERRCODE.ERROR.PARAM_MOBILE
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    if isempty(pwd) then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.PARAM_PASSWD
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    if isempty(name) then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.PARAM_NAME
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    --TODO:临时关闭
    local cacheKey = 'code:'..mobile
    local cacheCode = do_redis({"get", cacheKey}) or 0
    if cacheCode ~= code then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.PARAM_SMSCODE
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    local playerInfo = player.getPlayerInfo(uid)
    if playerInfo.isbindphone and playerInfo.isbindphone > 0 then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.HAD_BANDING_MOBILE
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    -- 手机号已经被绑定过
    local sql =string.format("select count(*) as t from d_user_bind where unionid='%s'", mobile)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if rs[1] and rs[1].t > 0 then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.MOBILE_HAD_BANDING
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    do_redis({"del", cacheKey})
    local update = {
        ['isbindphone'] = 1,
        ['phone'] = mobile,
        ['username'] = name,
    }
    local nickname = SubStringUTF8(name, 1, 16)
   
    playerInfo.playername = nickname
    update['playername'] = nickname
    handle.dcCall("user_dc","setvalue", uid, update)

    local gid = ''
    local sid = ''
    local clientuuid = ''
    if isempty(dinfo) then
        local sql = string.format("select gid,sid,unionid from d_user_bind where uid=%d and logintype=1", uid)
        local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs == 1 and rs[1]~= nil then
            if rs[1].gid ~= '' then
                gid = rs[1].gid
            end
            if rs[1].sid ~= '' then
                sid = rs[1].sid
            end
            clientuuid = rs[1].unionid
        end
    else
        local ok , data = pcall(jsondecode, dinfo)
        if ok and data then
            gid = data.gid or ''
            sid = data.sid or ''
        end
        local sql = string.format("select gid,sid,unionid from d_user_bind where uid=%d and logintype=1", uid)
        local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
        clientuuid = rs[1].unionid
    end
    

    local pwdmd5 = genPwd(uid, pwd)
    local nowtime = os.time()
    local sql = string.format("INSERT INTO `d_user_bind`(uid,unionid,nickname,sex,platform,passwd,create_time,gid,sid,logintype,email) VALUE(%d, '%s', '%s', %d, %d,'%s', %d,'%s','%s', %d,'%s');", 
                    uid, mobile, playerInfo.playername, playerInfo.sex, handle.getPlatForm(), pwdmd5, nowtime, gid, sid, PDEFINE.LOGIN_TYPE.MOBILE, clientuuid)
    skynet.call(".dbsync", "lua", "sync", sql)

    addBindCache(uid, mobile, playerInfo.playername, handle.getPlatForm(), nowtime, pwdmd5)

    sql = string.format("select count(*) as t from d_kyc where uid=%d and category=1 and status=2", uid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if rs == nil or rs[1]['t'] == 0 then
        local sql2 = string.format("INSERT INTO `d_kyc`(username,cardnum,status,category,create_time,uid) VALUE('%s', '%s', %d, %d, %d, %d);", 
                        name, mobile, 2, 1, nowtime, uid)
        skynet.call(".dbsync", "lua", "sync", sql2)
    end

    handle.syncUserInfo({uid=uid, isbindphone=1}) --同步用户字段到客户端

    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 游客账号登录，修改系统头像
function player.changeUserInfo(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid) --当前登录的uid

    local nickname = recvobj.nickname
    local gender = recvobj.gender
    local introduction = recvobj.introduction
    local country = recvobj.country
    local avatarframe = recvobj.avatarframe
    local avatar = recvobj.usericon
    local chatskin = recvobj.chatskin --聊天框
    local tableskin = recvobj.tableskin --桌背
    local pokerskin = recvobj.pokerskin --牌背
    local frontskin = recvobj.frontskin --字体颜色
    local emojiskin = recvobj.emojiskin --表情包
    local faceskin = recvobj.faceskin --牌花
    local fgamelist = recvobj.fgamelist  -- 好友房游戏列表
    local verifyfriend = recvobj.verifyfriend --是否开启被加好友验证，如果开启，别人加你好友，需要你验证通过 0:关闭  1:开启
    local blockuids = recvobj.blockuids --我屏蔽的uids
    local tbl = {}
    local questIds = {}

    -- 检测玩家是否在黑名单中
    -- 黑名单用户无法更改头像和昵称
    local isBan = do_redis({"zscore", PDEFINE.REDISKEY.LOBBY.BanUserList, uid})
    if isBan then
        local nowAvatar = handle.dcCall("user_dc", "getvalue", uid, 'usericon')
        local nowName = handle.dcCall("user_dc", "getvalue", uid, 'playername')
        avatar = nowAvatar
        nickname = nowName
    end
    local nowtime = os.time()
    if nil ~=verifyfriend then
        tbl.verifyfriend = tonumber(verifyfriend or 0)
    end
    if nil ~= nickname then
        -- 只能输入印度语和英文和数字
        if not isIndiaLimit(nickname) then
            local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=PDEFINE.RET.ERROR.NICKNAME_INCLUCE_ILLEGAL_CHARACTER}
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end
       
        local stop = msgParser:IncludeSensitiveWords(nickname)
        LOG_DEBUG('player.changeUserInfo stop:', stop, ' nickname:', nickname)
        if stop then
            local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode=PDEFINE.RET.ERROR.NICKNAME_INCLUCE_ILLEGAL_CHARACTER}
            return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
        end
         -- 去掉名字中的屏蔽字
        -- nickname = msgParser:getString(nickname)
        tbl.playername = nickname
        -- table.insert(questIds, PDEFINE.QUESTID.NEW.CHANGENICKNAME)
        local isgetinitgift = handle.dcCall("user_dc", "getvalue", uid, "isgetinitgift")
        isgetinitgift = math.floor(isgetinitgift or 0)
        if isgetinitgift == 0 then
            handle.dcCall("user_dc", "setvalue", uid, "isgetinitgift", 1)
        end
        handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.CHANGE_NICK, nowtime)
    end
    if nil ~= avatar then
        tbl.usericon = avatar
        -- table.insert(questIds, PDEFINE.QUESTID.NEW.CHANGEAVATAR)
        handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.CHANGE_AVATAR, nowtime)
    end
    if nil ~= gender then 
        if gender == 0 or gender == 1 then
            tbl.sex = gender
        end
    end
    
    if nil ~= introduction then
        tbl.memo = introduction
    end
    if nil ~= country then
        tbl.country = country
        -- table.insert(questIds, PDEFINE.QUESTID.NEW.CHANGECOUNTRY)
        handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.CHANGE_COUNTRY, nowtime)
    end
    if nil ~= avatarframe then
        tbl.avatarframe = avatarframe
        -- table.insert(questIds, PDEFINE.QUESTID.NEW.CHANGEAVATARFRAME)
    end
    if nil ~= chatskin then
        tbl.chatskin = chatskin
        -- table.insert(questIds, PDEFINE.QUESTID.NEW.CHANGECHATBOX)
    end
    if nil ~= tableskin then
        tbl.tableskin = tableskin
    end
    if nil ~= blockuids then
        if type(blockuids) == "table" then
            tbl.blockuids = cjson.encode(blockuids)
        end
    end
    if nil ~= pokerskin then
        tbl.pokerskin = pokerskin
    end
    if nil ~= frontskin then
        tbl.frontskin = frontskin
    end
    if nil ~= emojiskin then
        tbl.emojiskin = emojiskin
    end
    if nil ~= faceskin then
        tbl.faceskin = faceskin
    end

    local user = nil
    if not table.empty(tbl) then
        tbl.uid = uid
        if #questIds > 0 then
            handle.moduleCall("quest", 'updateBatchQuest', PDEFINE.QUEST_TYPE.NEWER, questIds, 1)
        end

        handle.dcCall("user_dc", "update", tbl, false)
        
        
        local userInfo = player.getPlayerInfo(uid)
        if tbl.chatskin or tbl.playername or tbl.usericon or tbl.avatarframe or tbl.frontskin then
            skynet.send('.chat', 'lua', 'changeUserData', userInfo)
        end
        handle.updateInfoInGame() --可能要同步到游戏内
        
        -- local userInfo = player.getPlayerInfo(uid)
        user = {
            uid = userInfo.uid,
            playername = userInfo.playername,
            usericon = userInfo.usericon,
            sex = userInfo.sex,
            avatarframe = userInfo.avatarframe,
            memo = userInfo.memo,
            country = userInfo.country,
            chatskin = userInfo.chatskin,
            tableskin = userInfo.tableskin,
            pokerskin = userInfo.pokerskin,
            frontskin = userInfo.frontskin,
            emojiskin = userInfo.emojiskin,
            faceskin = userInfo.faceskin,
            verifyfriend = userInfo.verifyfriend,
            nextvipexp = handle.getNextVipInfoExp(userInfo.svip),
            blockuids = {}
        }
        local ok, tmp = pcall(jsondecode, userInfo.blockuids)
        if ok then
            user.blockuids = tmp
        end
    end

    if fgamelist then
        local gameListStr = table.concat(fgamelist, ',')
        handle.dcCall("user_dc", "setvalue", uid, "fgamelist", gameListStr)
        if not user then
            user = {}
        end
        user.pinlist, user.fgamelist = player_tool.getPlayerGameList(gameListStr)
    end
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, user=user}
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--增加赠送明细记录
function player.addSendCoinLog(uid, coin, act, level, diamond)

    local playerInfo = player.getPlayerInfo(uid)
    level = playerInfo.level or 1
    local svip = playerInfo.svip or 0
    -- if level == nil or level < 0 then
    --     level = playerInfo.level
    -- end
    if diamond == nil then
        diamond = 0
    end
    local sql = string.format("insert into s_send_coin(uid,coin,create_time,act, level, scale, diamond,svip) values (%d, %.2f, %d, '%s', %d, %2.f, %d, %d)", uid, coin, os.time(), act, level, 1, diamond, svip)
    do_mysql_queue(sql)
end

--[[
    响应wss打点协议
    msg = {
        act : 事件类型,
        gameid: 游戏id 可能为0,
        uid: 用户id,
        tab: 可能为0,
        id: 当前对象id 可能为0,
        ext: 扩展字段
    }
]]
function player.statistics(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local cmd = math.floor(recvobj.c)
    local datas = {}
    if recvobj.batchs then
        for _, batch in pairs(recvobj.batchs) do
            table.insert(datas, {
                gameid=batch.gameid, tab=batch.tab, id=batch.id,
                act=batch.act, ext=batch.ext, ts=batch.ts
            })
        end
    else
        table.insert(datas, {
            gameid=recvobj.gameid, tab=recvobj.tab, id=recvobj.id,
            act=recvobj.act, ext=recvobj.ext, ts=recvobj.ts
        })
        if recvobj.act == 'Entry_Main' then
            pcall(cluster.call, "master", ".userCenter", "joinHall", uid)         
        end
    end
    for _, data in pairs(datas) do
        local gameid, tab, id  = 0, 0, 0
        if data.gameid == "null" then
            data.gameid = 0
        end
        if nil ~= data.gameid and type(data.gameid) =="number" then
            gameid = math.floor(data.gameid)
        else
            gameid = 0
        end
        if nil ~= data.id then
            id = math.floor(data.id)
        end
        if nil ~= data.tab then
            tab = math.floor(data.tab)
        end
        handle.addStatistics(uid, data.act, data.ext, gameid, tab, id, data.ts)
    end

    -- local gameid, tab, id  = 0, 0, 0
    -- if recvobj.gameid == "null" then
    --     recvobj.gameid = 0
    -- end
    -- if nil ~= recvobj.gameid and type(gameid) =="number" then
    --     gameid = math.floor(recvobj.gameid)
    -- else
    --     gameid = 0
    -- end
    -- if nil ~= recvobj.id then
    --     id = math.floor(recvobj.id)
    -- end
    -- if nil ~= recvobj.tab then
    --     tab = math.floor(recvobj.tab)
    -- end
    -- local ok, ret = handle.addStatistics(uid, recvobj.act, recvobj.ext, gameid, tab, id)
   
    local retobj = {c = recvobj.c, uid = uid, code = PDEFINE.RET.SUCCESS}
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 用户获取可领取的破产信息
function player.getBankruptInfo(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local iscache = recvobj.cache --是否缓存请求
    if not iscache then
        handle.addStatistics(uid, 'bankruptinfo', '')
    end
    local cacheKey = 'bankrupt_notice:'..uid
    local retobj = {c = recvobj.c, uid = uid, coin = 0, times=0, spcode=0}
    local coin = do_redis({"get", cacheKey .. ':coin'}) or 0 --是否可以领取了
    local times = do_redis({"get", cacheKey})
    times = tonumber(times or 0)
    retobj.times = PDEFINE.BANKRUPT.TIMES - times
    if retobj.times < 0 then
        retobj.times = 0
    end
    local playerInfo = player.getPlayerInfo(uid)
    if playerInfo.coin > 2000 then
        retobj.spcode = PDEFINE_ERRCODE.ERROR.CAN_NOT_GETBANKRUPT
        return resp(retobj)
    end
    if retobj.times > 0 then
        retobj.coin = PDEFINE.BANKRUPT.COIN
    end
    return resp(retobj)
end

local function addBankruptRewards(uid)
    return cs(
        function()
            local playerInfo = player.getPlayerInfo(uid)
            local retobj = {uid = uid, coin = playerInfo.coin, rewards = {}, spcode=0}
            if playerInfo.coin > 2000 then
                retobj.spcode = PDEFINE_ERRCODE.ERROR.CAN_NOT_GETBANKRUPT
                return retobj
            end

            local cacheKey = 'bankrupt_notice:'..uid
            local cacheTimes = do_redis({"get", cacheKey}) or 0
            cacheTimes = math.floor(cacheTimes)
            if cacheTimes < PDEFINE.BANKRUPT.TIMES then
                local cointype = PDEFINE.ALTERCOINTAG.BANKRUPT
                local gameid = PDEFINE.GAME_TYPE.SPECIAL.BANKRUPT
                local coin = PDEFINE.BANKRUPT.COIN
                local code, before_coin, after_coin = player_tool.funcAddCoin(uid, coin, "破产补助", cointype, gameid, PDEFINE.POOL_TYPE.none, nil, nil)
                player.addSendCoinLog(uid, coin, 'bankrupt')
                handle.addCoinInGame(coin) --给游戏里的玩家加上

                retobj.coin = after_coin
                table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN, count= coin})
                handle.notifyCoinChanged(after_coin, playerInfo.diamond, coin, 0)
                local timeout = getTodayLeftTimeStamp()
                cacheTimes = cacheTimes + 1
                do_redis({"setex", cacheKey, cacheTimes, timeout})
            else
                retobj.spcode = PDEFINE_ERRCODE.ERROR.NOT_BANKRUPT_COIN
            end
            return retobj
        end
    )
end

--! 用户领取破产补助
function player.collectBankrupt(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local iscache = recvobj.cache --是否缓存请求

    local retobj = {c = recvobj.c, rewards = {}, spcode=0}
    if not iscache then
        handle.addStatistics(uid, 'bankrupt', '') --领取
    end
    local result = addBankruptRewards(uid)
    table.merge(retobj, result)
    return resp(retobj)
end

function player.setGinLamiCount(uid, count)
    return handle.dcCall("user_dc", "setvalue", uid, "ginlamicount", count)
end

--! 获取bonus页 信息
function player.getBonusInfo(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)

    local DAILY_MISSION_TOTAL_COIN = 440000
    local ONLINE_REWARD_COIN = 15000

    --奖励倍数
    local scale = 1
    -- local playerInfo = player.getPlayerInfo(uid)

    -- 剩余时间
    local leftTime = getTodayLeftTimeStamp()

    local retobj = {}
    retobj.c = recvobj.c
    retobj.code = PDEFINE.RET.SUCCESS

    --daily bonus
    if recvobj.sign then
        local signed = false
        retobj.sign = {count=0, coin=0, next=leftTime}
        local signInfo = do_redis({ "hgetall", "uid_sign_info" .. uid},uid)
        signInfo = make_pairs_table_int(signInfo)
        local times = 0 --当前周期累计签到次数
        if signInfo and not table.empty(signInfo) then
            times = signInfo.signTimes or 0
            times = tonumber(times)

            local beginTime = calRoundBeginTime()
            if nil == signInfo.signTimeStamp then
                signInfo.signTimeStamp = 0
            end
            if tonumber(signInfo.signTimeStamp) < beginTime then -- 未签
                retobj.sign.count = tonumber(signInfo.signCount) + 1
            else  -- 已签
                retobj.sign.count = tonumber(signInfo.signCount)
                signed = true
            end
        else
            retobj.sign.count = 1
        end
        retobj.sign.count = math.min(retobj.sign.count , 7)
        if not signed then  --本次签到可得奖励
            local ok, rs = pcall(cluster.call, "master", ".configmgr", "getNewSignList", times, scale)
            if ok then
                local rewardCoin = 0
                for _, row in pairs(rs['signData']) do
                    if retobj.sign.count == row['day'] then
                        for _, val in pairs(row['prize']) do
                            if val['type'] == PDEFINE.PROP_ID.COIN then
                                rewardCoin = val['count']
                                break
                            end
                        end
                        break
                    end
                end
                retobj.sign.coin = rewardCoin * scale
            end
        end
    end

    --daily mission
    if recvobj.mission then
        retobj.mission = {}
        retobj.mission.coin = scale * DAILY_MISSION_TOTAL_COIN
        retobj.mission.next = leftTime
    end

    -- pass 通行证
    -- if recvobj.pass then
    --     local pass_data =  handle.moduleCall("pass", "getData", uid)
    --     if pass_data then
    --         retobj.pass = pass_data
    --     end
    -- end

    --fb
    if recvobj.fb then
        local fb_share = handle.moduleCall("quest","getFBShrareCoin", uid)
        retobj.fb = {coin = fb_share.addCoin}
    end

    --在线奖励
    if recvobj.online then
        retobj.online = {coin=scale * ONLINE_REWARD_COIN, time=0}
        local res = do_redis({"hget", "onlineAward", "uid:"..uid..":type:"..1})
        if res then
            local result = cjson.decode(res)
            if result and result.lastTime then
                local ok, list = pcall(cluster.call, "master", ".rewardonlinemgr", "getAll")
                if ok and list and #list>0 then
                    local cfg = list[1]
                    retobj.online.time = math.max(0, cfg.time*60 - (os.time()-result.lastTime))
                    local rand = cjson.decode(cfg.random)
                    retobj.coin = scale * cfg.count * rand.e
                end

            end
        end
    end

    -- 红点相关
    retobj.redDot = {
        resetTime = date.GetTodayZeroTime(os.time()) + 24*60*60 - os.time(),  -- 重置倒计时
        totalDot = nil,  -- 列表，存放已经点击的红点
        alreadyReward = nil,  -- 是否已经领取
        coin = RED_DOT_COIN * scale,  -- 能获得的奖励
    }
    retobj.redDot.totalDot, retobj.redDot.alreadyReward = getDotInfo(uid)
    return resp(retobj)
end

--! 记录玩家完成新手引导的步骤
function player.addGuide(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local step = recvobj.step
    local guideJsonData = handle.dcCall("user_dc", "getvalue", uid, "guide")
    local ok, guideData = pcall(jsondecode, guideJsonData)
    if not ok then
        guideData = {}
    end
    if step ~= nil then
        if type(step) == 'table' then
            for _, id in pairs(step) do
                local item = tonumber(id)
                if not table.contain(guideData, item) then
                    table.insert(guideData, item)
                end
            end
        else
            local item = tonumber(step)
            if not table.contain(guideData, item) then
                table.insert(guideData, item)
            end
        end
    end
    handle.dcCall("user_dc", "setvalue", uid, "guide", cjson.encode(guideData))
    player.syncLobbyInfo(uid)
    local retobj = {}
    retobj.c = recvobj.c
    retobj.code = PDEFINE.RET.SUCCESS
    return resp(retobj)
end

--! 用户聊天
function player.chat(msg)
    local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local cid       = tonumber(recvobj.cid)
    local lastMsgID = recvobj.lastid or 0 --客户端上一次的id
    local content   = recvobj.content or ''
    local stype     = recvobj.stype
    lastMsgID = math.floor(lastMsgID)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, cid=cid}
    if nil~=content and content ~="" then
        if stype == 1 then
            content = msgParser:getString(content)
        end
        local ban_flag = do_redis({'get', 'chat_ban_all'})
        if not ban_flag then
            ban_flag = do_redis({'get', 'chat_ban:'..uid})
        end
        if ban_flag then
            retobj.spcode = PDEFINE.RET.ERROR.CHAT_BANED
            return resp(retobj)
        end
        -- local cacheKey = 'chat_user:'..uid
        -- local t = do_redis({"get", cacheKey})
        -- if t ~= nil then
        --     retobj.code = PDEFINE.RET.ERROR.CHAT_FREQUENTLY
        --     return resp(retobj)
        -- end
        -- do_redis({"setnx", cacheKey, 1, 10}) --距离上次发言10s
    end
    local social_today = do_redis({'get', 'today_social'..uid})
    if social_today then
        player.syncLobbyInfo(uid)
    end
    local resItems = skynet.call(".chat", "lua", "chat", uid, cid, lastMsgID, content, stype)
    local rpcRes = {
        ["items"] = resItems,
        ["uid"] = uid,
        ["cid"] = cid,
    }
    retobj.data = rpcRes

    -- 当天的一次俱乐部聊天，会增加一点俱乐部分数
    if cid and content ~= '' then
        retobj.club_score = handle.moduleCall("club","chat")
    else
        -- 更新主线任务
        -- local updateMainObjs = {
        --     {kind=PDEFINE.MAIN_TASK.KIND.GlobalChat, count=1},
        -- }
        -- handle.moduleCall("maintask", "updateTask", uid, updateMainObjs)
    end
    return resp(retobj)
end

--! 在房间内，发邀请加入房间到世界聊天
function player.invite2Room(msg)
    local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local gameid    = tonumber(recvobj.gameid)
    local deskid    = tonumber(recvobj.deskid)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, gameid=gameid, deskid=deskid, spcode=0}

    local cacheKey = string.format('invite:%d:%d', gameid, deskid)
    local flag = do_redis({"get", cacheKey})
    if nil ~= flag then
        retobj.spcode = PDEFINE.RET.ERROR.INVITE_FREQUENTLY
        return resp(retobj)
    end
    do_redis({"setex", cacheKey, 1, 300})

    local content = string.format("%d;%d;%d", gameid, deskid, 0)
    handle.sendInviteMsg(content, PDEFINE.CHAT.MsgType.PrivateRoom)
    return resp(retobj)
end

--! 聊天室心跳包
function player.chatHeartbeat(msg)
    local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local cid       = tonumber(recvobj.cid)
    if uid > 0 then
        skynet.send(".chat", "lua", "heartbeat", uid, cid)
    end
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, cid=cid}
    return resp(retobj)
end

--! 离开了聊天室
function player.leaveChat(msg)
    local recvobj   = cjson.decode(msg)
    local uid       = math.floor(recvobj.uid)
    local cid       = tonumber(recvobj.cid)
    if uid > 0 then
        skynet.send(".chat", "lua", "leave", uid, cid)
    end
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, cid=cid}
    return resp(retobj)
end

--! 用户反馈
function player.feedback(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid) --当前登录的uid
    local stype   = recvobj.stype or 1 --类型
    local content = recvobj.content or ''--反馈内容
    local iscache = recvobj.cache --是否缓存请求
    local phone   = recvobj.phone or '' --手机号码
    local lang = recvobj.lang or '' --语言
    local imgs = recvobj.imgs or {}

    if not iscache then
        handle.addStatistics(uid, 'feedback', '')
    end
    imgs = cjson.encode(imgs)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS}

    content = mysqlEscapeString(content)
    phone = mysqlEscapeString(phone)
    lang = mysqlEscapeString(lang)
    local playerInfo = player.getPlayerInfo(uid)
    local sql = string.format("insert into d_feedback(uid,playername,usericon,language,phone,stype,imgs,content,create_time) value(%d,'%s','%s','%s','%s','%s','%s','%s',%d)",
        uid, playerInfo.playername, playerInfo.usericon, lang, phone, stype, imgs, content, os.time())
    do_mysql_queue(sql)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 获取指定类型的皮肤道具
function player.getCatSkin(uid, category)
    local ok, datalist  = pcall(cluster.call, "master", ".configmgr", 'getSkinList', category)
    LOG_DEBUG('getCatSkin uid:',uid, ' category:', category, datalist)
    local userInfo = player.getPlayerInfo(uid)
    local ok, hadSkins = pcall(jsondecode, userInfo.skinlist)
    if not ok then
        hadSkins = {}
    end
    local hadSkinImgs = {}
    local isEnglish = handle.isEnglish()
    local itemlist = {}
    for _, row in pairs(datalist) do
        row.have = 0
        row.free = 0
        if type(hadSkins[row.category]) == 'table' then
            if table.contain(hadSkins[row.category], row.img) or table.contain(hadSkins[row.category], row.id) then
                row.have = 1
            end
        end
        if row.subcat == 5 then
            if row.stype == 2 then
                if row.category == PDEFINE.SKINKIND.FRAME then --临时用，把vip的调整位置4
                    row.subcat = 4
                end
                if row.category == PDEFINE.SKINKIND.EMOJI then --国王表情包(财富榜榜首)
                    if isKing(uid) then
                        row.have = 1
                        row.free = 1
                    end
                elseif row.category == 7 then
                    row.free = 0
                else
                    if userInfo.svip == 1 then
                        row.have = 1 --骑士会员
                        row.free = 1
                    end
                end
            elseif row.stype == 3 then
                if userInfo.svip == 2 then
                    row.have = 1 --爵士会员
                    row.free = 1
                end
                if row.category == 1 then
                    row.subcat = 4 --临时用，把vip的调整位置4
                end
            end
        end

        row.hours = 0
        row.buffer = 0
        if row.category == PDEFINE.SKINKIND.EXPCAT then
            local content = string.split(row.content, '|')
            if #content >= 2 then
                row.hours = math.floor(content[1])
                row.buffer = math.floor(content[2])
            end
        end
        row.title = row.title_al
        if isEnglish then
            row.title = row.title_en
        end
        if row.category == 1 or row.category == 2 or row.category == 6 or row.category == 7 or row.category== 8 then
            row.content = row.title
        end
        row.title_en = nil
        row.title_al = nil
        row.title = nil
        if row.have == 1 then
            table.insert(hadSkinImgs, row.img) --已有的皮肤列表
        end
        if row.coin > 0 then
            table.insert(itemlist, row)
        end
    end
    return itemlist
end

--! 获取所有皮肤商品列表
function player.getSkins(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local stypeStr   = recvobj.type or "" --列表
    local agentLanguage = recvobj.language or 1 -- 1:阿拉伯 2:英文
    local ok, datalist  = pcall(cluster.call, "master", ".configmgr", 'getSkinList')

    local platform = recvobj.platform or 2 --平台 1安卓 2IOS
    platform = math.floor(platform)
    local UNIT_STRING = '$'
    local userInfo = player.getPlayerInfo(uid)
    local ok, hadSkins = pcall(jsondecode, userInfo.skinlist)
    if not ok then
        hadSkins = {}
    end
    local hadSkinImgs = {}
    local language = handle.getNowLanguage()
    if tonumber(language) ~= tonumber(agentLanguage) then
        handle.changeLanguage(agentLanguage)
    end
    local cacheKey = PDEFINE.REDISKEY.TASK.SKIN_SEND .. uid --签到赠送的道具加入到已有列表中
    local sendSkinList = do_redis({"get", cacheKey})
    if nil ~= sendSkinList and "" ~= sendSkinList then
        local sendList = cjson.decode(sendSkinList)
        local now = os.time()
        for i=#sendList, 1, -1 do
            local item = sendList[i]
            if item.endtime <= now then
                table.remove(sendList, i)
            else
                table.insert(hadSkinImgs, item.img)
            end
        end
    end
    local isEnglish = handle.isEnglish()
    local itemlist = {}
    for _, row in pairs(datalist) do
        if itemlist['data'.. row.category] == nil then
            itemlist['data'.. row.category] = {}
        end
        
        if row.amount and row.amount > 0 then
            row.unit = UNIT_STRING
        else
            row.unit= "COIN" --单位钻石
            -- row.productid = handle.moduleCall('pay', 'getProductId', row, platform)
            row.productid = ''
        end
        row.productid_huawei = nil
        row.productid_ios2   = nil
        row.productid_gp     = nil
        row.productid_gp2    = nil
        row.have = 0
        row.free = 0
        if type(hadSkins[row.category]) == 'table' then
            if table.contain(hadSkins[row.category], row.img) or table.contain(hadSkins[row.category], row.id) then
                row.have = 1
            end
        end
        if row.subcat == 5 then
            if row.stype == 2 then
                if row.category == PDEFINE.SKINKIND.FRAME then --临时用，把vip的调整位置4
                    row.subcat = 4
                end
                if row.category == PDEFINE.SKINKIND.EMOJI then --国王表情包(财富榜榜首)
                    if isKing(uid) then
                        row.have = 1
                        row.free = 1
                    end
                elseif row.category == 7 then
                    row.free = 0
                else
                    if userInfo.svip == 1 then
                        row.have = 1 --骑士会员
                        row.free = 1
                    end
                end
            elseif row.stype == 3 then
                if userInfo.svip == 2 then
                    row.have = 1 --爵士会员
                    row.free = 1
                end
                if row.category == 1 then
                    row.subcat = 4 --临时用，把vip的调整位置4
                end
            end
        end

        row.hours = 0
        row.buffer = 0
        if row.category == PDEFINE.SKINKIND.EXPCAT then
            local content = string.split(row.content, '|')
            if #content >= 2 then
                row.hours = math.floor(content[1])
                row.buffer = math.floor(content[2])
            end
        end
        row.title = row.title_al
        if isEnglish then
            row.title = row.title_en
        end
        if row.category == 1 or row.category == 2 or row.category == 6 or row.category == 7 or row.category== 8 then
            row.content = row.title
        end
        row.title_en = nil
        row.title_al = nil
        row.title = nil
        
        if row.have == 0 then
            if table.contain(hadSkinImgs, row.img) then --已有
                row.have = 1
            end
        end
        if row.have == 1 then
            table.insert(hadSkinImgs, row.img) --已有的皮肤列表
        end
        -- if row.diamond > 0 then
            table.insert(itemlist['data'.. row.category], row)
        -- end
    end
    for _, datalist in pairs(itemlist) do
        table.sort(datalist, function(a, b)
            if a.coin < b.coin then
                return true
            else
                if a.coin == b.coin then
                    if a.id < b.id then
                        return true
                    else
                        return false
                    end
                else
                    return false
                end
            end
        end)
    end
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, shoplist=itemlist}
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 用户增加头像框皮肤等
function player.addSkin(uid, frameid)
    local ok, itemList = pcall(cluster.call, "master", ".configmgr", "getSkinList")
    local item =  itemList[frameid]
    if nil == item then
        LOG_ERROR("addSkin error")
        return false
    end

    player.addSkinImg(uid, item.img, item.category)
    return true
end

-- 加永久的道具图片
function player.addSkinImg(uid, img, category)
    local userInfo = player.getPlayerInfo(uid)
    local ok, hadSkins = pcall(jsondecode, userInfo.skinlist)
    if not ok then
        hadSkins = {{},{},{},{},{},{},{},{},{},{}}    -- 1:头像框，2:聊天边框, 3:牌桌背景, 4:扑克牌背景 5:牌花 6:表情包 7:聊天文字颜色
    end
    if nil == hadSkins[category] or type(hadSkins[category])~= "table"  then
        hadSkins[category] = {} -- 1:头像框，2:聊天边框, 3:牌桌背景, 4:扑克牌背景 5:牌花 6:表情包 7:聊天文字颜色
    end
    if category == PDEFINE.SKINKIND.SALON then
        for i=1, category do
            if hadSkins[i] == nil then
                hadSkins[i] = {}
            end
        end
    end
    if not table.contain(hadSkins[category], img) then
        table.insert(hadSkins[category], img)
    end
    
    local tbl = {
        ['uid'] = uid,
        ['skinlist'] = cjson.encode(hadSkins)
    }
    if category == PDEFINE.SKINKIND.SALON then
        tbl['salonskin'] =  img
    end
    handle.dcCall("user_dc", "update", tbl, false)
    del_timeout_skin(uid, img)
    if category == PDEFINE.SKINKIND.EMOJI then --表情包
        local userInfo = player.getPlayerInfo(uid)
        local emojilist = getEmojilist(userInfo, {PDEFINE.SKIN.DEFAULT.EMOJI.img})
        handle.syncUserInfo({uid=uid, emojilist=emojilist})
    end

    return hadSkins
end

--! 用户兑换头像框
function player.exchangeSkin(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid) --当前登录的uid
    local frameid = recvobj.id or 0 
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, spcode =0, id = frameid, rewards={}}
    if frameid == 0 then
        retobj.spcode = 1 --请选择正确的皮肤
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    local userInfo = player.getPlayerInfo(uid)
    
    local ok, itemList = pcall(cluster.call, "master", ".configmgr", "getSkinList")
    LOG_DEBUG("avataitemListrList:", itemList)
    local item =  itemList[frameid]
    if nil == item then
        retobj.spcode = 1 --请选择正确的头像框
        handle.addStatistics(uid, 'exchange_skin', '1', 0, 1, frameid)
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    if userInfo.coin < item.coin then
        retobj.spcode = 2 -- 金币不够，不能兑换
        handle.addStatistics(uid, 'exchange_skin', '2', 0, 1, frameid)
        return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
    end

    --扣钻石，给头像框 TODO
    local leftCoin = userInfo.coin - item.coin
    local skin = {
        ['id'] = frameid,
        ['title'] = item.title_en or item.title,
        ['img'] = item.img or "",
        ['coin'] = item.coin or 0,
        ['tbl'] = 's_shop_skin',
    }
    handle.addProp(PDEFINE.PROP_ID.COIN, -item.coin, 'shop', 'shop_exchange_skin', cjson.encode(skin))

    -- local hadSkins = {}
    if item.category == PDEFINE.SKINKIND.EXPCAT then
        add_send_charm_times(uid, item.img, true)
    else
        -- hadSkins = player.addSkinImg(uid, item.img, item.category)
        local leftTime = getTodayLeftTimeStamp()
        local endtime = 86400 * item.days + leftTime
        send_timeout_skin(item.img, endtime, uid)
    end
    retobj.item = item

    local notifyobj = {}
    notifyobj.c = PDEFINE.NOTIFY.coin
    notifyobj.code = PDEFINE.RET.SUCCESS
    notifyobj.uid = uid
    notifyobj.deskid = 0
    notifyobj.count = 0
    notifyobj.coin = leftCoin
    notifyobj.diamond = userInfo.diamond
    notifyobj.addDiamond = 0
    notifyobj.type = 1
    notifyobj.rewards = {}
    handle.sendToClient(cjson.encode(notifyobj))
    handle.addStatistics(uid, 'exchange_skin', '0', 0, 1, frameid)
   if item.category == PDEFINE.SKINKIND.SALON then
        handle.syncUserInfo({uid=uid, salonskin=item.img})
    end

    local attach = {}
    local typeId = 0
    if item.category == PDEFINE.SKINKIND.FRAME then
        typeId = PDEFINE.PROP_ID.SKIN_FRAME
    elseif item.category == PDEFINE.SKINKIND.CHAT then
        typeId = PDEFINE.PROP_ID.SKIN_CHAT
    elseif item.category == PDEFINE.SKINKIND.TABLE then
        typeId = PDEFINE.PROP_ID.SKIN_TABLE
    elseif item.category == PDEFINE.SKINKIND.POKER then
        typeId = PDEFINE.PROP_ID.SKIN_POKER
    elseif item.category == PDEFINE.SKINKIND.FACE then
        typeId = PDEFINE.PROP_ID.SKIN_FACE
    elseif item.category == PDEFINE.SKINKIND.EMOJI then
        typeId = PDEFINE.PROP_ID.SKIN_EMOJI
    elseif item.category == PDEFINE.SKINKIND.EXPCAT then
        typeId = PDEFINE.PROP_ID.SKIN_EXP --个人经验值加速道具
    end
    if typeId > 0 then
        table.insert(attach, {type = typeId, count=1, img=item.img})
        table.insert(retobj.rewards, {type = typeId, count=1, img=item.img})
    end
    -- local msgObj = {
    --     title_al = 'إشعار شراء ',
    --     title = "Purchased Notice",
    --     msg_al = "لقد قمت بشراء  العناصر بنجاح ، يمكنك التحقق منها  في حقيبة الشخصية  واستخدامه.",
    --     msg = "You have successfully purchased items, you can view and use them in your backpack.",
    --     attach = attach
    -- }
    -- handle.sendBuyOrUpGradeEmail(msgObj, PDEFINE.MAIL_TYPE.SHOP)
    if item.category == PDEFINE.SKINKIND.EXPCAT then
        local charmlist = get_send_charm_list(uid)
        handle.syncUserInfo({uid=uid, charmlist = charmlist})
    end

    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 客户端切换语言
function player.changeLanguage(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid) --当前登录的uid
    local language = math.floor(recvobj.language or 1) -- 1:阿拉伯  2:英语

    handle.addStatistics(uid, 'change_lang', '')
    handle.changeLanguage(language)
    local retobj = {c = math.floor(recvobj.c), code = PDEFINE.RET.SUCCESS, language = language}
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 获取随机在线用户
function player.getRandUsers(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local limit = math.floor(recvobj.limit)
    local retobj = {
        c = math.floor(recvobj.c),
        code = PDEFINE.RET.SUCCESS,
        limit = limit,
        spcode = 0
    }
    if limit > 20 then
        limit = 20
    end
    local ok, users = pcall(cluster.call, "master", ".userCenter", "getRankOnlineUser", uid, limit)
    if not ok then
        retobj.spcode = 1
        return resp(retobj)
    else
        retobj.users = users
        return resp(retobj)
    end
end

--! 根据游戏id获取每个场次的用户
function player.getSessUser(msg)
    local recvobj = cjson.decode(msg)
    local reqgameid = math.floor(recvobj.gameid or 0)
    
    local retobj = {
        c = math.floor(recvobj.c),
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        data = {}
    }

    local ok, allGameList = pcall(cluster.call, "master", ".gamemgr", "getGameList")
    local gameIds = {}
    for _, gamelist in pairs(allGameList) do
        for _, row in pairs(gamelist) do
            table.insert(gameIds, row.id)
        end
    end
    

    local gameList = PDEFINE_GAME.SESS.match
    for gameid, sessList in pairs(gameList) do
        if table.contain(gameIds, gameid) then
            local item = {
                gameid = gameid,
                sess = {}
            }
            local cnts = getOnlineCount(gameid)
            for _, row in pairs(sessList) do
                table.insert(item.sess, {
                    ssid = row.ssid,
                    num = table.remove(cnts, 1)
                })
            end
            table.insert(retobj.data, item)
        end
    end
    return resp(retobj)
end

-- 玩家所在房间开始游戏
function player.roomStart(uid, deskid, gameid)
    local clubInfo = handle.moduleCall('club', 'findClubByUid', uid)
    if clubInfo then
        skynet.send('.chat', 'lua', 'roomStart', deskid, gameid, clubInfo.cid)
    else
        skynet.send('.chat', 'lua', 'roomStart', deskid, gameid)
    end
    return PDEFINE.RET.SUCCESS
end

--! 五星好评
function player.rateStar(msg)
    local recvobj = cjson.decode(msg)
    local uid = math.floor(recvobj.uid)
    local stype = math.floor(recvobj.type or 1) -- 1去评分了 2拒绝
    local retobj = {
        c = math.floor(recvobj.c),
        code = PDEFINE.RET.SUCCESS,
        type = stype,
        spcode = 0
    }
    if stype == 2 then
        local raise = handle.dcCall("user_dc", "getvalue", uid, "praisetime")
        handle.dcCall("user_dc", "setvalue", uid, "praisetime", (raise+1))
    else
        handle.dcCall("user_dc", "setvalue", uid, "praisetime", os.time())
    end
    -- handle.moduleCall("quest", 'updateQuest', uid, PDEFINE.QUEST_TYPE.RATEUS, PDEFINE.QUESTID.NEW.ADDFRIEND, 1)
    return resp(retobj)
end

--获取最大能购买的金猪金币数量
function player.getMaxCanBuyCoin(moneybag)
    local val = s_goldpiggy[1].coin  --第一档固定开放
    if nil == moneybag then
        return val
    end
    for _, item in ipairs(s_goldpiggy) do
        if moneybag >= item.coin then
            val = math.max(val, item.coin)
        end
    end
    return val
end

--! 游戏内使用互动表情
function player.expression(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local idx = math.floor(recvobj.id or 0)
    local iscache = recvobj.cache --是否缓存请求
    local frienduid = math.floor(recvobj.frienduid or 0)
    local min_coin = recvobj.min_coin or 0
    local retobj  = {c=math.floor(recvobj.c), code=PDEFINE.RET.SUCCESS, spcode=0, uid=uid, id = idx, frienduid=frienduid}

    local ok, charmCfg = pcall(cluster.call, "master", ".configmgr", "getCharmPropList")
    if not ok or nil == charmCfg[idx] then
        retobj.spcode = PDEFINE.RET.ERROR.EXPRESS_ID_ERR --id参数错误
        return resp(retobj)
    end
    
    if not iscache then
        handle.addStatistics(uid, 'send_express', idx..','..frienduid)
    end
    local phiz = charmCfg[idx]

    local playerInfo = player.getPlayerInfo(uid)
    retobj.diamond, retobj.coin, retobj.adddiamond, retobj.addcoin = 0, 0, 0, 0
    
    local caltimes = minus_send_charm_time(uid, phiz.img)
    LOG_DEBUG("caltimes:",caltimes , ' uid:', uid, ' img:', phiz.img, ' ret:', caltimes)

    retobj.coin = playerInfo.coin
    retobj.diamond = playerInfo.diamond
    if not caltimes then
        local isvip = tonumber(phiz['isvip'] or 0)
        if isvip > 0 then --vip使用条件
            if playerInfo.svip < phiz['level'] then
                retobj.spcode = PDEFINE.RET.ERROR.EXPRESS_VIP_LEVEL --vip等级不够，用不了
                return resp(retobj)
            end
            return resp(retobj)
        else
            local leftDiamond = playerInfo.diamond
            retobj.coin = playerInfo.coin
            retobj.diamond = leftDiamond
            retobj.addCoin = 0
            local prize = phiz['count']
            if phiz['type'] == PDEFINE.PROP_ID.COIN and prize > 0 then
                if playerInfo.coin < min_coin + prize then
                    retobj.spcode = PDEFINE.RET.ERROR.MIN_COIN_LIMIT --金币不够
                    return resp(retobj)
                end
                if playerInfo.coin < prize then
                    retobj.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH --金币不够
                    return resp(retobj)
                end
                
                if prize > 0 then
                    local code, before_coin, after_coin = player_tool.funcAddCoin(uid, -prize, "游戏内道具消耗:-"..prize, PDEFINE.ALTERCOINTAG.PHIZ, PDEFINE.GAME_TYPE.SPECIAL.PHIZ, PDEFINE.POOL_TYPE.none, nil, nil)
                    player.addSendCoinLog(uid, -prize, 'phiz')
                    handle.addCoinInGame(-prize) --给游戏里的玩家加上
                    retobj.coin = after_coin
                end
                
                retobj.addCoin = -prize
                handle.notifyCoinChanged(retobj.coin, leftDiamond, retobj.addCoin, retobj.addDiamond)
            end
        end
    else
        local charmlist = get_send_charm_list(uid)
        handle.syncUserInfo({uid=uid, charmlist=charmlist})
    end
    
    -- pcall(cluster.send, "master", ".userCenter", "updateQuest", uid, PDEFINE.QUESTID.DAILY.EMOJI, 1)

    -- 更新主线任务
    -- local updateMainObjs = {
    --     {kind=PDEFINE.MAIN_TASK.KIND.Expression, count=1},
    -- }
    -- handle.moduleCall("maintask", "updateTask", uid, updateMainObjs)

    return resp(retobj)
end


-- 领取离线收益
function player.collectOfflineAwards(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)

    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = math.floor(recvobj.c)
    local playerInfo = player.getPlayerInfo(uid)
    retobj.rewards = {}
    local addCoin = 0
    local cache_coin = do_redis({"get", 'offline_coin:'..uid}, uid)
    if cache_coin ~= nil then
        do_redis({"del", 'offline_coin:'..uid}, uid)
        addCoin = tonumber(cache_coin)
    end
    if addCoin > 0 then
        local code,beforecoin, aftercoin = player_tool.funcAddCoin(uid, addCoin, "离线奖励", PDEFINE.ALTERCOINTAG.OFFLINEAWARDS, PDEFINE.GAME_TYPE.SPECIAL.OFFLINEAWARDS, PDEFINE.POOL_TYPE.none, nil, nil)
        handle.dcCall("user_data_dc","set_common_value", uid, PDEFINE.USERDATA.COMMON.LASTLOGOUTTIME, os.time())
        table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN, count=addCoin})
        handle.notifyCoinChanged(aftercoin, playerInfo.diamond, addCoin, 0)
    end
    return resp(retobj)
end

--! 用户举报，配合提审
function player.report(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local stype = math.floor(recvobj.stype or 0) --举报类型 1:Porn 2:Fraud 3: Violence 4:lllegal 5:Abuse, 6:Others
    local otheruid = math.floor(recvobj.otheruid or 0) --被举报人
    local content = recvobj.content or "" --举报内容

    local sql = string.format("insert into d_report(uid,otheruid,category,content,create_time,status,stype) values(%d,%d,%d,'%s',%d,%d,%d)",
            uid, otheruid, 1, content, os.time(), 0, stype)
    LOG_DEBUG("player.report sql:", sql)
    skynet.call(".mysqlpool", "lua", "execute", sql)

    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = math.floor(recvobj.c)
    retobj.otheruid = otheruid
    retobj.content = content

    retobj.spcode = 0
    return resp(retobj)
end

--! 用户举报聊天内容
function player.reportmsg(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local stype = math.floor(recvobj.stype or 0)
    local msgid   = math.floor(recvobj.msgid or 0) --消息id
    local otheruid = math.floor(recvobj.otheruid or 0)
    local content = recvobj.content or ""
    local retobj = {code = PDEFINE.RET.SUCCESS, c = math.floor(recvobj.c), spcode=0}

    local key = string.format("report:%d:%d:%d", uid, otheruid, msgid)
    local flag   = do_redis({"get", key})
    flag = tonumber(flag or 0)
    if flag > 0 or otheruid == 0 then
        retobj.spcode = PDEFINE.RET.ERROR.REPORT_THESAME_MSG
        return resp(retobj)
    end
    do_redis({"setnx", key, 1, 3600})
    content = mysqlEscapeString(content)
    
    local sql = string.format("insert into d_report(uid,otheruid,category,content,create_time,status,stype,msgid) values(%d,%d,%d,'%s',%d,%d,%d,%d)",
            uid, otheruid, 2, content, os.time(), 0, stype, msgid)
    LOG_DEBUG("player.reportmsg sql:", sql)
    skynet.call(".mysqlpool", "lua", "execute", sql)

    retobj.msgid = msgid
    retobj.stype = stype
    return resp(retobj)
end

--! 子游戏回大厅，刷新leagueexp
function player.refreshLeagueExp(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local leagueExp, _ = player_tool.getPlayerLeagueInfo(uid)
    handle.syncUserInfo({uid=uid, leagueexp=leagueExp})
    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = math.floor(recvobj.c)
    return resp(retobj)
end

-- 获取玩家最近10场历史战绩
function player.getRecentGameRecord(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local ouid     = math.floor(recvobj.ouid)
    local iscache = recvobj.cache --是否缓存请求
    local gameid  = recvobj.gameid and math.floor(recvobj.gameid) or nil
    local limit   = recvobj.limit and math.floor(recvobj.limit) or nil

    local records = player_tool.getRecentGameRecord(ouid, limit, gameid)

    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = math.floor(recvobj.c)
    retobj.gameid = gameid
    retobj.limit = limit
    retobj.ouid = ouid
    retobj.records = records
    if not iscache then
        handle.addStatistics(uid, 'gamerecord','', gameid)
    end
    return resp(retobj)
end

--! 获取游戏内结算FB分享奖励
function player.getFBShareRewardsInGame(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local gameid = math.floor(recvobj.gameid)
    local cat = math.floor(recvobj.cat or 1) --1:累计赢的次数 2:连续赢的次数, 3:牌型

    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = math.floor(recvobj.c)
    retobj.spcode = 0
    if cat ~= PDEFINE.SHARE.TYPE.CONT and cat ~= PDEFINE.SHARE.TYPE.TOTAL and cat ~= PDEFINE.SHARE.TYPE.SPECIAL then
        return resp(retobj)
    end
    
    local today = os.date("%Y%m%d",os.time())
    local getTimesKey =string.format(PDEFINE_REDISKEY.SHARE.TYPE.CONTGET, today, uid, gameid)
    if cat == PDEFINE.SHARE.TYPE.CONT then
        local collectTimes = do_redis({"get", getTimesKey})
        collectTimes = tonumber(collectTimes or 0)
        if collectTimes > 0 then --连续赢的只能领取1次
            return resp(retobj)
        end

    end
    local fbshareCoin = do_redis({"get", string.format(PDEFINE_REDISKEY.SHARE.COINKEY, uid, gameid)})
    if DEBUG then
        fbshareCoin = 2000000
    end
    fbshareCoin = tonumber(fbshareCoin or 0)
    if fbshareCoin == 0 then
        return resp(retobj)
    end
     
    if cat == PDEFINE.SHARE.TYPE.TOTAL then
        local cacheKey = string.format(PDEFINE_REDISKEY.SHARE.TYPE.TOTAL, today, uid)
        do_redis({"del", cacheKey})
    else
        do_redis({"set", getTimesKey, 1})
    end
    retobj.rewards = {
        {
            type = PDEFINE.PROP_ID.COIN,
            count = fbshareCoin
        }
    }
    local cointype = PDEFINE.ALTERCOINTAG.FBSAHRE_IN_GAME
    local code, _, _ = player_tool.funcAddCoin(uid, fbshareCoin, "fbshareingame", cointype, gameid, PDEFINE.POOL_TYPE.none, nil, nil)
    if code == PDEFINE.RET.SUCCESS then
        handle.addCoinInGame(fbshareCoin)
    end
    return resp(retobj)
end

--! 注销账号
function player.cancelAccount(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)

    -- 删除账号
    local sql ="select * from d_user_bind where uid="..uid
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            local unionid = row['unionid']
            if unionid then
                do_redis({"srem", "{bigbang}:sets:username", unionid})
                do_redis({"srem", "{bigbang}:sets:useremail", unionid})
            end
        end
        sql = string.format("delete from d_user_bind where uid = %d", uid) --删除
        skynet.call(".mysqlpool", "lua", "execute", sql)
    end

    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = math.floor(recvobj.c)
    retobj.spcode = 0
    return resp(retobj)
end

-- 添加钻石明细记录
function player.addDiamondLog(uid, diamond, afterDiamond, act, content, remark)
    local playerInfo = player.getPlayerInfo(uid)
    afterDiamond = afterDiamond or 0
    if afterDiamond == 0 then
        afterDiamond = playerInfo.diamond
    end

    local rs = {
        ['uid'] = uid,
        ['content'] = content or "",
        ['act'] = act or "",
        ['remark'] = remark or "",
        ['diamond'] = diamond or 0,
        ['afterDiamond'] = afterDiamond,
        ['coin'] = playerInfo.coin or 0,
        ['level'] = playerInfo.level or 1,
        ['levelexp'] = playerInfo.levelexp or 0,
        ['svip'] = playerInfo.svip or 0,
        ['svipexp'] = playerInfo.svipexp or 0,
        ['ticket'] = playerInfo.ticket or 0,
        ['leagueexp'] = playerInfo.leagueexp or 0,
        ['leaguelevel'] = playerInfo.leaguelevel or 0,
    }
    return player_tool.addDiamondLog(rs)
end

-- 获取toady rewards弹框
local function getRewardsToday(uid)
    local rewards = handle.moduleCall('viplvtask', 'getVipRewards', uid)
    local startTime = date.GetTodayZeroTime()
    startTime = startTime - 86400
    local sql = string.format("select sum(backcoin) as t from d_rake_back where uid=%d and create_time>=%d and state=1", uid, startTime)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    rewards['rakeback']  = rs[1].t or 0
    return rewards
end

-- 获取返水的游戏id列表
local function getRakeBackGameids()
    local data = {}
    local cachekey = 'rakebackgameids'
    local dataStr = do_redis({"get", cachekey})
    if dataStr then
        local ok, jsonobj = pcall(jsondecode, dataStr)
        if ok then
            data = jsonobj
        end
    else
        local sql = "select distinct gameid from s_rake_back where status=1"
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        if #rs > 0 then
            for _, row in pairs(rs) do
                table.insert(data, row.gameid)
            end
        end
        do_redis({"setex", cachekey, cjson.encode(data), 86400})        
    end
    return data
end

-- 获取大厅配置数据
function player.getCfgData(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local retobj = {code = PDEFINE.RET.SUCCESS, c = math.floor(recvobj.c), spcode=0}
    local favorite_games = do_redis({"zrevrangebyscore", PDEFINE.REDISKEY.GAME.favorite..uid, 5})
    retobj.favorite_games = {}
    if favorite_games then
        for _, gameid in ipairs(favorite_games) do
            if gameid then
                table.insert(retobj.favorite_games, math.floor(gameid))
            end
            if #retobj.favorite_games >= 4 then
                break
            end
        end
    end
    retobj.poponetime = 0 --标记开关：1 游戏内没钱要弹出onetime, 0游戏内没钱了也不弹
    
    
    local ok, propdata = pcall(cluster.call, "master", ".configmgr", "getCharmPropList")
    if ok then
        retobj.proplist = {}
        for _, row in pairs(propdata) do
            if tonumber(row.cat) == 2 and tonumber(row.level) == 0 then
                table.insert(retobj.proplist, {
                    id = row.id,
                    coin = row.count
                })
            end
        end
    end
    retobj.salonvip = 4
    retobj.lbgames = {} 
    retobj.promoopen = 0 --促销信息是否打开
    local ok, data = pcall(cluster.call, "master", ".configmgr", 'getBatchItems', {PDEFINE_REDISKEY.LEADERBOARD.GAMEIDS, "salonvip", "worldchat",'promo_open'})
    if ok and data then
        if data[PDEFINE_REDISKEY.LEADERBOARD.GAMEIDS] then
            retobj.lbgames = string.split_to_number(data[PDEFINE_REDISKEY.LEADERBOARD.GAMEIDS], ",")
        end
        if data['salonvip'] then 
            retobj.salonvip = tonumber(data['salonvip'])
        end
        if data['promo_open'] then
            local promoopen = tonumber(data['promo_open'])
            if promoopen > 0 then
                retobj.promoopen = 1
            end
        end
        if data['worldchat'] then
            retobj.pinmsg = {}
            if string.find(data['worldchat'], 'http') then
                retobj.pinmsg.url = data['worldchat']
            else
                retobj.pinmsg.text = data['worldchat']
            end
        end
    end
  
    retobj.rbgameids = getRakeBackGameids() --rakebake 的gameids列表

    local gamelist = getGameList(uid)
    retobj.gamelist = gamelist[1]
    retobj.slotslist = gamelist[2]
    retobj.adpics = getADPics()
    local playerInfo = player.getPlayerInfo(uid)
    local viproomcnt = getVipRoomCnts()
    local now = os.time()
    playerInfo.salontesttime = tonumber(playerInfo.salontesttime or 0)
    if playerInfo.salontesttime>now then
        --试用道具，加2个房间限制
        for k, value in pairs(viproomcnt) do
            if value < 3 then
                viproomcnt[k] = 3
            end
        end
    end
    retobj.viproomcnt = viproomcnt --VIP开房数

    -- local rewards = handle.moduleCall('quest', 'getRewardsById', 141, uid)--修改名称的奖励
    -- retobj.namerewards = rewards
    retobj.namerewards = {}

    retobj.bonuslist = getBonusPageList(playerInfo)
    -- retobj.charmList = handle.moduleCall("charm", "propList", 1) --只显示魅力值道具
    local urls = getLinks()
    local code = playerInfo.code or ''
    retobj.sharelink= urls['fbshare'] .. '?code='..code --fb分享地址
    
    retobj.uploadlink  = urls['upload'] --头像上传地址
    retobj.payurl      = urls['payurl'] --支付网关地址
    retobj.kyc         = urls['kyc'] --kyc验证入口
    retobj.drawurl     = urls['draw'] --draw 入口
    retobj.transaction = urls['transaction'] --transaction入口
    retobj.payment = urls['payment'] --managepayment入口
    retobj.contactus = urls['contactus']

    retobj.todayrewards = getRewardsToday(uid)

    --公告弹框
    --[[
    -- notice格式
    retobj.notice = {
        title = "notice title",
        content = "notice content",
        img = "https://alifei01.cfp.cn/creative/vcg/veer/1600water/veer-368621010.jpg", --有img优先显示img，img为""显示content
        jumpto = "Bank", --Bank/Salon/Game/ReferEarn/Social/https:www.baidu.com（如果以http开头则跳转到网址）
    }
    ]]--
    --注册赠送金币
    retobj.reg_bonus_coin = 10
    --签到总金币
    retobj.sign_bonus_coin = 100
    local ok, data = pcall(cluster.call, "master", ".configmgr", "getLoginCfgData", playerInfo.svip or 0)
    if ok then
        if table.size(data.notice) > 0 then
            retobj.notice = data.notice
        end
        
        retobj.reg_bonus_coin = data.reg_bonus_coin
        retobj.sign_bonus_coin = data.sign_bonus_coin
    end
    return resp(retobj)
end

--! 获取沙龙道具3天试用期
function player.getSalonTest(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local retobj = {code = PDEFINE.RET.SUCCESS, c = math.floor(recvobj.c), spcode=0}

    -- local playerInfo = player.getPlayerInfo(uid)
    -- playerInfo.salontesttime = tonumber(playerInfo.salontesttime or 0)
    -- if playerInfo.salontesttime == 0 then
    --     local frameid = 70
    --     local ok, itemList = pcall(cluster.call, "master", ".configmgr", "getSkinList")
    --     LOG_DEBUG("getSalonTest avataitemListrList:", itemList)
    --     local item =  itemList[frameid]

    --     local todayEndTime = calRoundEndTime()
    --     local endTime = todayEndTime + 86400 * 2
    --     handle.dcCall("user_dc", "setvalue", playerInfo.uid, "salontesttime", endTime)
    --     retobj.salontesttime = endTime

    --     local viproomcnt = getVipRoomCnts()
    --     --试用道具，加2个房间限制
    --     for k, value in pairs(viproomcnt) do
    --         if value < 3 then
    --             viproomcnt[k] = 3
    --         end
    --     end

    --     handle.syncUserInfo({uid=uid, salonskin=item.img,salontesttime=endTime, viproomcnt=viproomcnt})
    -- else
    --     retobj.spcode = PDEFINE.RET.ERROR.HAND_GET_TESTSALON
    -- end
    
    return resp(retobj)
end

--!更新赢家coin
function player.updateWinCoin(uid, coin)
    LOG_DEBUG('updateWinCoin uid :'..uid .. ' coin: ' .. coin)
    handle.dcCall("user_dc", "user_addvalue", uid, "wincoin", coin)
end

--!被邀请加入沙龙房的处理
function player.acceptInvite(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local fromuid = math.floor(recvobj.from)
    local idx = math.floor(recvobj.idx)
    local ctype = math.floor(recvobj.type or 0) --1:同意 0:拒绝
    local gameid = math.floor(recvobj.gameid or 0) 
    local deskid = math.floor(recvobj.deskid or 0)

    local playerInfo = player.getPlayerInfo(uid)
    local ok, friendAgent = pcall(cluster.call, "master", ".userCenter", "getAgent",  fromuid) --主动邀请人
    if friendAgent then
        local resp = {
            c = PDEFINE.NOTIFY.FRIEND_INVITE_BACK,
            code = PDEFINE.RET.SUCCESS,
            deskid = deskid,
            gameid = gameid,
            friendid = uid,
            playername  = playerInfo.playername,
            usericon = playerInfo.usericon,
            idx = idx,
            type=ctype,
        }
        pcall(cluster.call, friendAgent.server, friendAgent.address, "sendToClient", cjson.encode(resp))
    end

    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = math.floor(recvobj.c)
    retobj.spcode = 0
    return resp(retobj)
end

-- 获取比赛积分信息
function player.getRaceInfo(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local race_id = math.floor(recvobj.race_id)
    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = math.floor(recvobj.c)
    retobj.spcode = 0
    local redis_key = raceCfg.getRedisKey(race_id)
    local cfg = raceCfg.getGameInfo(race_id)
    local score = do_redis({"zscore", redis_key, uid})
    if not score then
        score = 0
    else
        score = tonumber(score)
    end
    local rankId = do_redis({ "zrevrank", redis_key, uid})
    if rankId then
        rankId = rankId + 1  -- 这里需要+1, 因为排名从1开始
    end
    -- 这里有一个默认分数段，少于这个分数，就随机名次，大于这个分数，就取真实名次信息
    rankId = raceCfg.getRankId(cfg, score, rankId)
    retobj.score = score
    retobj.rankId = rankId
    retobj.restTime = cfg.restTime
    retobj.config = cfg
    return resp(retobj)
end

-- 获取777游戏结果
function player.player777Game(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local retobj = {}
    retobj.code = PDEFINE.RET.SUCCESS
    retobj.c = math.floor(recvobj.c)
    retobj.uid = uid
    retobj.spcode = 0

    local cards, mult = N77.generate()
    retobj.cards = cards
    retobj.mult = mult
    return resp(retobj)

end

--! 获取客服信息
function player.getCustomerService(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.floor(recvobj.uid)
    local showpage = math.floor(recvobj.position or 1) --显示的页面
    local retobj = {c=math.floor(recvobj.c), spcode=0, code=PDEFINE.RET.SUCCESS, data={}}
    local playerData = handle.dcCall("user_dc", "get", uid)
    if not playerData then
        return resp(retobj)
    end
    local medialist = {}
    local svip = tonumber(playerData.svip) or 0
    local sql = string.format("select * from s_config_customer where status=1 and FIND_IN_SET(%d,svip) and showpage=%d order by ord asc,id asc", svip, showpage)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            local item = {
                ['id'] = row['id'],
                ['title'] = row['title'],
                ['url']  = row['url'],
                ['type'] = row['category'],
                ['ord']  = row['ord'],
                ['memo'] = row['memo'],
            }
            if row.category == 2 or row.category==9 or row.category == 10 or row.category == 11 then
                table.insert(medialist, item)
            else
                table.insert(retobj.data, item)
            end
        end
    end
    local website = {
        ['id'] = 1000,
        ['title'] = 'website',
        ['url'] = GetAPPUrl('www'), --官网地址
        ['type'] = 1000,
        ['ord'] = 10000,
        ['memo'] = 'Visit our official website',
    }
    table.insert(retobj.data, website)
    retobj.medialist = medialist
    return resp(retobj)
end

local function getPlayerNum(gameid)
    local now = os.time()
    local hour = tonumber(os.date("%H", now))+1
    local hour_num = {25, 20, 10, 5, 0, 0, 5, 15, 20, 30, 35, 40, 45, 50, 50, 40, 35, 30, 30, 40, 50, 60, 80, 50}
    local pnum = 400 + hour_num[hour] + now%20 + math.random(0, 30) + gameid%10
    return pnum
end

--! 获取游戏场次列表（牌类）
function player.getGameSessList(msg)
    local recvobj = cjson.decode(msg)
    local gameid  = math.sfloor(recvobj.gameid)
    local retobj  = {
        c = recvobj.c,
        spcode = 0,
        code = PDEFINE.RET.SUCCESS,
        gameid = gameid,
        sess = {},
    }
    local ok, sess = pcall(cluster.call, "master", ".sessmgr", 'getSessByGameId', gameid)
    if ok and sess then
        for _, s in ipairs(sess) do
            s.pnum = getPlayerNum(s.gameid)
        end
        retobj.sess = sess
    end
    return resp(retobj)
end

--! 获取游戏房间列表（百人类）
function player.getGameRoomList(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.sfloor(recvobj.uid)
    local gameid  = math.sfloor(recvobj.gameid)
    local retobj  = {
        c= recvobj.c,
        spcode = 0,
        code = PDEFINE.RET.SUCCESS,
        gameid = gameid,
        rooms = {}
    }
    local playerData = handle.dcCall("user_dc", "get", uid)
    local svip = tonumber(playerData.svip) or 0
    local tagid = tonumber(playerData.tagid) or 0
    local ok, rooms = pcall(cluster.call, "master", ".strategymgr", 'getDeskList', gameid, svip, tagid)
    if ok and rooms then
        retobj.rooms = rooms
    end
    return resp(retobj)
end

--! 获取游戏投注记录
function player.getBetRecords(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.sfloor(recvobj.uid)
    local gameid  = math.sfloor(recvobj.gameid) or 0
    local limit   = math.sfloor(recvobj.limit) or 50

    local records = {}
    local sql
    if gameid < 200 then --押注类游戏
        sql = "select issue, create_time, bet, wincoin, settle, betinfo from d_desk_user"
    else
        sql = "select issue, create_time, bet, wincoin from d_desk_user"
    end
    sql = sql .. string.format(" where uid=%d and gameid=%d order by id desc limit %d", uid, gameid, limit)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if rs and #rs > 0 then
        for _, r in ipairs(rs) do
            local record = {
                i = r['issue'],         --序列号
                t = r['create_time'],   --时间戳
                bet = r['bet'],         --押注金额
                win = r['wincoin']      --赢取金额
            }
            if gameid < 200 then
                record.result = r['settle'] --开奖结果
                local betinfo = cjson.decode(r['betinfo'])
                if type(betinfo)=='table' and #betinfo>0 then
                    for _, bi in ipairs(betinfo) do
                        table.insert(records, {
                            i = record.i,
                            t = record.t,
                            result = record.result,
                            bet = bi.bet,
                            win = bi.win,
                            p = bi.p,   --下注区域
                        })
                    end
                    if #records >= limit then
                        break
                    end
                else
                    table.insert(records, record)
                end
            else
                table.insert(records, record)
            end
        end
    end

    local retobj = {
        code = PDEFINE.RET.SUCCESS,
        c = recvobj.c,
        gameid = gameid,
        records = records,
    }
    return resp(retobj)
end

--! 获取游戏历史开奖记录
function player.getGameRecords(msg)
    local recvobj = cjson.decode(msg)
    local gameid  = math.sfloor(recvobj.gameid) or 0
    local ssid    = math.sfloor(recvobj.ssid) or 0
    local limit   = math.sfloor(recvobj.limit) or 50

    local records = {}
    local key = PDEFINE.REDISKEY.GAME.resrecords..ServerId..":"..gameid..":"..ssid
    local res = do_redis({"lrange", key, 0, limit})
    if res then
        for _, r in ipairs(res) do
            local record = cjson.decode(r)
            table.insert(records, record)
        end
    end
    local retobj = {
        code = PDEFINE.RET.SUCCESS,
        c = recvobj.c,
        gameid = gameid,
        records = records,
    }
    return resp(retobj)
end

-- 获取当前反水数据
function player.getRakeBackInfo(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.sfloor(recvobj.uid)
    local rtype   = math.sfloor(recvobj.rtype or 2) -- 1 今天 2 昨天 3 本周 4 本月

    local retobj = {
        c = recvobj.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        uid = uid,
        rtype = rtype,
        list = {},
        recived = 0,  -- 已领取
        unclaimed = 0,  -- 未领取
    }

    local startTime = date.GetTodayZeroTime()
    if rtype == 2 then
        startTime = startTime - 86400
    elseif rtype == 3 then
        startTime = startTime - 7 * 86400
    elseif rtype == 4 then
        startTime = startTime - 30 * 86400
    end

    local sql = string.format("select * from d_rake_back where uid=%d and create_time>=%d", uid, startTime)
    if rtype == 3 and rtype == 4 then
        sql = sql.." and state in (2,3)" --已领取或已过期
    elseif rtype == 2 then
        sql = sql .. " and state in (1,2,4)" --待领取、已领取、暂时不能领的
    end

    LOG_DEBUG('getRakeBackInfo:', sql)

    
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if rs and #rs > 0 then
        for _, item in ipairs(rs) do
            local info = {
                id = item.id,
                gameid =item.gameid,
                bet=item.bet,
                wincoin=item.wincoin,
                state=item.state,  -- 1:待领取, 2:已领取, 3:过期作废, 4:只能看还不能领取
                rate=item.rate,
                backcoin=item.backcoin,
                atime = item.available_time,
            }
            table.insert(retobj.list, info)
        end
    end

    -- 查看统计数据
    local tsql = string.format("select sum(backcoin) as total, state from d_rake_back where uid=%d group by state", uid)
    local trs = skynet.call(".mysqlpool", "lua", "execute", tsql)

    if trs and #trs > 0 then
        for _, r in ipairs(trs) do
            if r.state == 2 then
                retobj.recived = r.total
            elseif r.state == 1 then
                retobj.unclaimed = r.total
            elseif r.state == 4 then
                retobj.unclaimed = r.total --只能看的也是待领取的
            end
        end
    end

    return resp(retobj)
end

function player.hasRakeBackReward(uid)
    local startTime = date.GetTodayZeroTime() - 86400
    local sql = string.format("select count(*) as t from d_rake_back where uid=%d and create_time>=%d and state=1", uid,startTime)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    local count = rs[1]['t']
    if count >= 1 then
        return true
    end
    return false
end

-- 领取奖励
function player.getRakeBackReward(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.sfloor(recvobj.uid)
    local rid  = math.sfloor(recvobj.rid)
    local isall   = math.sfloor(recvobj.isall)
    local retobj = {
        c = recvobj.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        uid = uid,
        rid = rid,
        isall = isall,
        rewards = {},
        recived = 0,  -- 已领取
        unclaimed = 0,  -- 未领取
    }
    if not rid and isall ~= 1 then
        retobj.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return resp(retobj)
    end
    local startTime = date.GetTodayZeroTime() - 86400
    local sql = string.format("select * from d_rake_back where uid=%d and create_time>=%d", uid,startTime)
    if isall ~= 1 then
        sql = string.format("select * from d_rake_back where uid=%d and id=%d", uid, rid)
    end
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs or #rs == 0 then
        retobj.spcode = PDEFINE.RET.ERROR.RAKE_BACK_NOT_FOUND
        return resp(retobj)
    end
    local betcoin = 0 --投注金额
    local coin = 0 --进入现金钱包
    local coin_can_draw = 0 --进入提现钱包
    local coin_bonus = 0 --进入优惠钱包
    if isall == 1 then
        local ids = {}
        for _, item in ipairs(rs) do
            if item.state == 1 then
                table.insert(ids, item.id)
                betcoin = betcoin + item.bet
                local bonusRemark = "投注金额:".. betcoin .. ',返水:'.. item.backcoin
                local coins = player.addCoinByRate(uid, item.backcoin, item.frate, PDEFINE.TYPE.SOURCE.Rebate, nil, nil, nil, nil, bonusRemark)
                coin = coin + coins[1]
                coin_can_draw = coin_can_draw + coins[2]
                coin_bonus = coin_bonus + coins[3]
            end
        end
        local ids_str = "("
        for idx, id in ipairs(ids) do
            if idx == #ids then
                ids_str = ids_str..id
            else
                ids_str = ids_str..id..","
            end
        end
        ids_str = ids_str..")"
        local update_sql = string.format("update d_rake_back set state=2 where id in %s", ids_str)
        skynet.call(".mysqlpool", "lua", "execute", update_sql)
    else
        local item = rs[1]
        if item.state == 2 then
            -- 已领取
            retobj.spcode = PDEFINE.RET.ERROR.ALREADY_AWARD
            return resp(retobj)
        elseif item.state == 3 then
            -- 已过期
            retobj.spcode = PDEFINE.RET.ERROR.RAKE_BACK_EXPIRE
            return resp(retobj)
        elseif item.state == 4 then
            -- 还不能领取
            retobj.spcode = PDEFINE.RET.ERROR.RAKE_BACK_ONLY_VIEW
            return resp(retobj)
        end
        local update_sql = string.format("update d_rake_back set state=2 where id=%d", item.id)
        skynet.call(".mysqlpool", "lua", "execute", update_sql)
        local bonusRemark = "投注金额:".. betcoin .. ',返水:'.. item.backcoin
        local coins = player.addCoinByRate(uid, item.backcoin, item.frate, PDEFINE.TYPE.SOURCE.Rebate, nil, nil, nil, nil, bonusRemark)
        coin = coin + coins[1]
        coin_can_draw = coin_can_draw + coins[2]
        coin_bonus = coin_bonus + coins[3]
        betcoin = betcoin + item.bet
    end

    if coin > 0 then table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN, count=coin}) end
    if coin_can_draw > 0 then table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN_CAN_DRAW, count=coin_can_draw}) end
    if coin_bonus > 0 then table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.COIN_BONUS, count=coin_bonus}) end

    -- 查看统计数据
    local tsql = string.format("select sum(backcoin) as total, state from d_rake_back where uid=%d group by state", uid)
    local trs = skynet.call(".mysqlpool", "lua", "execute", tsql)

    if trs and #trs > 0 then
        for _, r in ipairs(trs) do
            if r.state == 2 then
                retobj.recived = r.total
            elseif r.state == 1 then
                retobj.unclaimed = r.total
            end
        end
    end
    player.syncLobbyInfo(uid)

    return resp(retobj)
end

-- 给其他3种(签到、分享、沙龙)增加bonus日志
function player.addBonusLog(orderid, title, coin, nowtime, rtype, uid, suid)
    if suid == nil then
        suid = 0
    end
    local sql = string.format("insert into d_log_cashbonus(orderid,title,coin,create_time,category,uid,useruid) values ('%s','%s', %.2f, %d, %d, %d,%d)", 
        orderid,title, coin, nowtime, rtype, uid, suid)
    sql = sql .. string.format(",('%s','%s', %.2f, %d, %d, %d,%d)", orderid, title, -coin, nowtime+1, PDEFINE.TYPE.SOURCE.Transfer_Cash, uid, suid)
    do_mysql_queue(sql)
end

local function syncUserWallet(uid)
    local userInfo = player.getPlayerInfo(uid)
    local dcoin, cashbonus, dcashbonus, bankcoin = formatPlayerCoin(userInfo)
    local item = {
        uid        = uid,
        coin  = userInfo.coin,
        dcoin      = dcoin,
        ecoin = math.round_coin(userInfo.coin - dcoin),
        cashbonus  = cashbonus,
        bankcoin   = bankcoin,
    }
    local drawinfo = {
        isfirstdraw = 0, --是否首次提现
        islimited = 0,
        maxcoin = 0,
    }
    drawinfo.islimited, drawinfo.maxcoin = getLimited(userInfo)
    if (nil ==userInfo.drawsucctimes or tonumber(userInfo.drawsucctimes) == 0) and (userInfo.ispayer == nil or userInfo.ispayer == 0) then
        drawinfo.isfirstdraw = 1
    end
    item.drawinfo = drawinfo
    handle.syncUserInfo(item)
end

-- 拒绝提现，从bonus转移到balance中
function player.transferBonus2Cash(uid, orderid)
    local sql = string.format("select * from d_log_cashbonus where uid=%d and orderid='%s' and category=%d limit 1", uid, orderid, PDEFINE.TYPE.SOURCE.FREE_WINNING)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs == 1 then
        local coin = rs[1].coin
        local cashbonus = handle.dcCall("user_dc", "getvalue", uid, "cashbonus")
        if cashbonus < coin then
            LOG_DEBUG('uid:', uid, ' cashbonus less than coin:', cashbonus, coin)
            handle.dcCall("user_dc", "user_addvalue", uid, "cashbonus", -cashbonus)
            coin = cashbonus
        else
            handle.dcCall("user_dc", "user_addvalue", uid, "cashbonus", -coin)
        end

        local cointype = PDEFINE.ALTERCOINTAG.BONUS2BALANCE
        local gameid = PDEFINE.GAME_TYPE.SPECIAL.BONUS2BALANCE
        local code,before_coin,after_coin = player_tool.funcAddCoin(uid, coin, "Bonus转移到Balance", cointype, gameid, PDEFINE.POOL_TYPE.none, nil, nil)
        if code ~= PDEFINE.RET.SUCCESS then
            LOG_ERROR('Bonus转移到Balance error:', orderid, ' uid:', uid, ' coin:', coin, ' cashbonus:', cashbonus)
        end

        local orderid = os.date("%Y%m%d%H%M%S", os.time()) .. payId()
        local sql = string.format("insert into d_log_cashbonus(orderid,title,coin,create_time,category,uid,useruid) values ('%s','%s', %.2f, %d, %d, %d,%d)", 
                                    orderid,'Transfer to Cash Balance', -coin, os.time(), PDEFINE.TYPE.SOURCE.DRAW_BONUS2CASH, uid, 0)
        do_mysql_queue(sql)
        syncUserWallet(uid)
    end
end

-- 转移现金余额到cash bonus
function player.transferCash2Bonus(uid, transferAmount, orderid, nowtime, sync)
    if nil ~=transferAmount and transferAmount > 0 then
        if nil == orderid then
            orderid = os.date("%Y%m%d%H%M%S", os.time()) .. payId()
        end
        if nil == nowtime then
            nowtime = os.time()
        end
        local cointype = PDEFINE.ALTERCOINTAG.FREE_WINNS2BONUS
        local gameid = PDEFINE.GAME_TYPE.SPECIAL.FREE_WINNS2BONUS
        -- cash balance = total balance - withdraw balance
        local code,before_coin,after_coin = player_tool.funcAddCoin(uid, -transferAmount, "转移到cashbonus", cointype, gameid, PDEFINE.POOL_TYPE.none, nil, nil)
        if code == PDEFINE.RET.SUCCESS then
            --加cash bonus
            handle.dcCall("user_dc", "user_addvalue", uid, "cashbonus", transferAmount) 
            local sql = string.format("insert into d_log_cashbonus(orderid,title,coin,create_time,category,uid,useruid) values ('%s','%s', %.2f, %d, %d, %d,%d)", 
                                    orderid,'Free Winnings transfer', transferAmount, nowtime, PDEFINE.TYPE.SOURCE.FREE_WINNING, uid, 0)
            do_mysql_queue(sql)
        else
            LOG_ERROR('转移到cashbonus uid:',uid, ' coin:', transferAmount)
        end

        -- 是否同步211
        if sync then
            syncUserWallet(uid)
        end
    end
end



function player.addCoinByRate(uid, addCoin, rateStr, actType, suid, notifyCoinObj, transferAmount, remark, bonusRemark)
    if nil ~= notifyCoinObj then --如果用户在线，直接同步订单到账金币给客户端
        handle.notifyCoinChanged(notifyCoinObj.coin, 0, notifyCoinObj.count, 0)
    end
    if nil == transferAmount then
        transferAmount = 0
    end

    -- LOG_DEBUG('player.addCoinByRate ', uid, addCoin, rateStr, actType, suid)
    local sendArr = { 0, 0, 0}
    if type(rateStr) == 'table' then
        sendArr = table.copy(rateStr)
        handle.dcCall("user_dc", "setvalue", uid, "ispayer", 1) --订单支付到账
    else
        local rateArr = decodeRate(rateStr)
        sendArr[1] = math.round_coin(tonumber(rateArr[1]) * addCoin)
        sendArr[2] = math.round_coin(tonumber(rateArr[2]) * addCoin)
        sendArr[3] = math.round_coin(tonumber(rateArr[3]) * addCoin)
    end
    LOG_DEBUG('player.addCoinByRate ', uid, addCoin, rateStr, actType, sendArr)
    local nowtime = os.time()
    local title = ''
    local rewardsType = 0
    if actType == PDEFINE.TYPE.SOURCE.REG then
        title = 'reg'
        rewardsType = PDEFINE.ALTERCOINTAG.AGENT_REG_REWARDS
    elseif actType == PDEFINE.TYPE.SOURCE.BUY then
        title = 'buy'
        rewardsType = PDEFINE.ALTERCOINTAG.AGENT_BUY_REWARDS
    elseif actType == PDEFINE.TYPE.SOURCE.BUY_SELF then
        title = 'buy'
        rewardsType = PDEFINE.ALTERCOINTAG.RECHARGE_SELF_BONUS
    elseif actType == PDEFINE.TYPE.SOURCE.BET then
        title = 'bet'
        rewardsType = PDEFINE.ALTERCOINTAG.AGENT_BET_REWARDS
    elseif actType == PDEFINE.TYPE.SOURCE.QUEST then
        title = 'quest'
        rewardsType = PDEFINE.ALTERCOINTAG.VIP_REWARDS
    elseif actType == PDEFINE.TYPE.SOURCE.Mail then
        title = 'mail'
        rewardsType = PDEFINE.ALTERCOINTAG.MAIL_REWARDS
    elseif actType == PDEFINE.TYPE.SOURCE.VIP or actType == PDEFINE.TYPE.SOURCE.VIP_MONTH or actType == PDEFINE.TYPE.SOURCE.VIP_WEEK then
        title = 'vipbonus'
        rewardsType = PDEFINE.ALTERCOINTAG.VIP_BONUS
        if actType == PDEFINE.TYPE.SOURCE.VIP_MONTH then
            rewardsType = PDEFINE.ALTERCOINTAG.VIP_MONTH
        elseif actType == PDEFINE.TYPE.SOURCE.VIP_WEEK then
            rewardsType = PDEFINE.ALTERCOINTAG.VIP_WEEK
        end
        if not isempty(bonusRemark) then
            title = bonusRemark
        end
    elseif actType == PDEFINE.TYPE.SOURCE.QUEST_WINCOIN then
        title = 'quest'
        rewardsType = PDEFINE.ALTERCOINTAG.QUEST_WINCOIN
        if not isempty(bonusRemark) then
            title = bonusRemark
        end
    elseif actType == PDEFINE.TYPE.SOURCE.QUEST_GAMES then
        title = 'quest'
        rewardsType = PDEFINE.ALTERCOINTAG.QUEST_GAMES
        if not isempty(bonusRemark) then
            title = bonusRemark
        end
    elseif actType == PDEFINE.TYPE.SOURCE.QUEST_RECHARGE then 
        title = 'quest'
        rewardsType = PDEFINE.ALTERCOINTAG.QUEST_RECHARGE
        if not isempty(bonusRemark) then
            title = bonusRemark
        end
    elseif actType == PDEFINE.TYPE.SOURCE.QUEST_BET then
        title = 'quest'
        rewardsType = PDEFINE.ALTERCOINTAG.QUEST_BET
        if not isempty(bonusRemark) then
            title = bonusRemark
        end
    elseif actType == PDEFINE.TYPE.SOURCE.Rebate then
        title = 'rebate'
        rewardsType = PDEFINE.ALTERCOINTAG.RAKEBACK
    else
        title = 'other'
        rewardsType = PDEFINE.ALTERCOINTAG.OTHER_REWARDS
    end
    local orderid = os.date("%Y%m%d%H%M%S", os.time()) .. payId()
    if nil == suid then
        suid = 0
    end
    if remark ~= nil then
        title = remark
    end
    sendArr[1] = tonumber(sendArr[1])
    if sendArr[1] > 0 then
        local coin = sendArr[1]
        local code, beforecoin, aftercoin = player_tool.funcAddCoin(uid, coin, title,
            rewardsType, PDEFINE.GAME_TYPE.SPECIAL.QUEST,  PDEFINE.POOL_TYPE.none, true)
        player.addSendCoinLog(uid, coin, actType)

        local sql = string.format("insert into d_log_cashbonus(orderid,title,coin,create_time,category,uid,useruid) values ('%s', '%s', %.2f, %d, %d, %d, %d)", 
                    orderid, title, coin, nowtime, actType, uid, suid)
            sql = sql .. string.format(",('%s', '%s', %.2f, %d, %d, %d, %d)", orderid, title, -coin, nowtime+1, PDEFINE.TYPE.SOURCE.Transfer_Cash, uid, suid)
        do_mysql_queue(sql)
        handle.notifyCoinChanged(aftercoin, 0, coin, 0)
    end
    
    sendArr[2] = tonumber(sendArr[2])
    if sendArr[2] > 0 then
        local coin = sendArr[2]
        handle.dcCall("user_dc", "user_addvalue", uid, "gamedraw", coin) 
        local code, beforecoin, aftercoin = player_tool.funcAddCoin(uid, coin, title..coin,
            rewardsType, PDEFINE.GAME_TYPE.SPECIAL.QUEST,  PDEFINE.POOL_TYPE.none, nil)
        handle.notifyCoinChanged(aftercoin, 0, coin, 0)
        local sql = string.format("insert into d_log_senddraw(orderid,title,coin,create_time,category,uid,useruid) values ('%s','%s', %.2f, %d, %d, %d, %d)", 
        orderid, title, coin, nowtime, actType, uid, suid)
        do_mysql_queue(sql)
    end
    local todaybonus = getTodayBonusCoin(uid)
    sendArr[3] = tonumber(sendArr[3])
    if sendArr[3] > 0 then
        local coin = sendArr[3]
        handle.dcCall("user_dc", "user_addvalue", uid, "cashbonus", coin) 
        if not isempty(bonusRemark) then
            title = bonusRemark
        end
        
        local sql = string.format("insert into d_log_cashbonus(orderid,title,coin,create_time,category,uid,useruid) values ('%s', '%s', %.2f, %d, %d, %d, %d)", 
        orderid, title, coin, nowtime, actType, uid, suid)
        skynet.call(".mysqlpool", "lua", "execute", sql)
        todaybonus = todaybonus + coin
    end
    player.transferCash2Bonus(uid, transferAmount, orderid, nowtime, true)
    
    local userInfo = player.getPlayerInfo(uid)
    if not userInfo then
        return sendArr
    end
    local dcoin, cashbonus, dcashbonus, bankcoin = formatPlayerCoin(userInfo)
    local item = {
        uid        = uid,
        coin  = userInfo.coin,
        dcoin      = dcoin,
        ecoin = math.round_coin(userInfo.coin - dcoin),
        cashbonus  = cashbonus,
        bankcoin   = bankcoin,
        todaybonus = todaybonus, 
    }
    local drawinfo = {
        isfirstdeposit = 0, --是否首次充值
        isfirstdraw    = 0, --是否首次提现
        islimited = 0,
        maxcoin = 0
    }
    drawinfo.islimited, drawinfo.maxcoin = getLimited(userInfo)
    if userInfo.ispayer == nil or userInfo.ispayer == 0 then
        drawinfo.isfirstdeposit = 1
    end
    if (nil ==userInfo.drawsucctimes or tonumber(userInfo.drawsucctimes) == 0) and (userInfo.ispayer == nil or userInfo.ispayer == 0) then
        drawinfo.isfirstdraw = 1
    end
    item.drawinfo = drawinfo
    handle.syncUserInfo(item)
    return sendArr
end

-- 后台给个人加减cashbonus
function player.apiActCashBonus(uid, addCoin, remark)
    LOG_DEBUG('player.apiActCashBonus ', uid, addCoin)
    local nowtime = os.time()
    local todaybonus = getTodayBonusCoin(uid)
    if addCoin ~= 0 then
        local orderid = os.date("%Y%m%d%H%M%S", os.time()) .. payId()
        local coin = tonumber(addCoin)
        local cashbonus = handle.dcCall("user_dc", "getvalue", uid, "cashbonus")
        cashbonus = tonumber(cashbonus or 0)
        cashbonus = cashbonus + coin
        if cashbonus < 0 then
            cashbonus = 0
        end
        handle.dcCall("user_dc", "setvalue", uid, "cashbonus", cashbonus) 
        local title = 'admin'
        local actType = PDEFINE.TYPE.SOURCE.Admin
        local sql = string.format("insert into d_log_cashbonus(orderid,title,coin,create_time,category,uid,useruid,remark) values ('%s', '%s', %.2f, %d, %d, %d, %d,'%s')", 
        orderid, title, coin, nowtime, actType, uid, 0, mysqlEscapeString(remark))
        do_mysql_queue(sql)
        todaybonus = todaybonus + coin
        if todaybonus < 0 then
            todaybonus = 0
        end

        local gamedraw = handle.dcCall("user_dc", "getvalue", uid, "gamedraw")
        local userInfo = player.getPlayerInfo(uid)
        local dcoin, cashbonus, dcashbonus, bankcoin = formatPlayerCoin(userInfo)
        local totalcoin = userInfo.coin +  cashbonus + bankcoin
        local item = {
            uid        = uid,
            dcoin      = dcoin,
            dcashbonus = dcashbonus,
            cashbonus  = cashbonus,
            totalcoin  = totalcoin,
            bankcoin   = bankcoin,
            candraw    = gamedraw,
            todaybonus = todaybonus, 
        }
        handle.syncUserInfo(item)
        return PDEFINE.RET.SUCCESS
    end
    return 500
end

-- 获取排行榜配置信息
function player.getLeaderBoardCfg(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.sfloor(recvobj.uid)
    local rtype  = math.sfloor(recvobj.rtype or PDEFINE.LEADER_BOARD.TYPE.DAY)  -- 类型 1:日榜 2:周榜 3:月榜
    local retobj = {
        c = recvobj.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        uid = uid,
        rtype = rtype,
        config = {},
    }
    local ok, data = pcall(cluster.call, "master", ".configmgr", 'getLeaderBoardData')
    if not ok or table.empty(data) or table.empty(data.cfg) then
        retobj.spcode = PDEFINE.RET.ERROR.LEADERBOARD_CONFIG_ERROR
        return resp(retobj)
    end
    retobj.config = data.cfg
    retobj.pics = data.pics
    local timeInfo = getLeaderBorderRangeTime(os.time())
    for _, cfg in ipairs(retobj.config) do
        if cfg.rtype == PDEFINE.LEADER_BOARD.TYPE.DAY then
            cfg.start_time = timeInfo.day.start
            cfg.stop_time = timeInfo.day.stop
        elseif cfg.rtype == PDEFINE.LEADER_BOARD.TYPE.WEEK then
            cfg.start_time = timeInfo.week.start
            cfg.stop_time = timeInfo.week.stop
        elseif cfg.rtype == PDEFINE.LEADER_BOARD.TYPE.MONTH then
            cfg.start_time = timeInfo.month.start
            cfg.stop_time = timeInfo.month.stop
        elseif cfg.rtype == PDEFINE.LEADER_BOARD.TYPE.REFERRALS then
            cfg.start_time = timeInfo.week.start
            cfg.stop_time = timeInfo.week.stop
        end
    end
    return resp(retobj)
end

--获取排行榜奖励配置
function player.getLeaderBoardRewards(msg)
    local recvobj = cjson.decode(msg)
    local rtype  = math.sfloor(recvobj.rtype or PDEFINE.LEADER_BOARD.TYPE.DAY)  -- 类型 1:日榜 2:周榜 3:月榜
    local retobj = {
        c = recvobj.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        rtype = rtype,
        rewards = {},
    }
    local ok_, rewards = pcall(cluster.call, "master", ".configmgr", "getLeaderBoardRewards", rtype)
    if ok_ and rewards then
        retobj.rewards = rewards
    end
    return resp(retobj)
end

-- 获取排行榜
function player.getLeaderBoard(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.sfloor(recvobj.uid)
    local rtype  = math.sfloor(recvobj.rtype or PDEFINE.LEADER_BOARD.TYPE.DAY)  -- 类型 1:日榜 2:周榜 3:月榜
    local retobj = {
        c = recvobj.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        uid = uid,
        rtype = rtype,
        list = {},
        myInfo = {ord=nil, score=0, reward_coin=0},
        -- gameids = {} --支持排行榜的游戏id列表
    }

    local redis_key, timeInfo = player_tool.getLeaderBoardInfo(rtype)
    if not redis_key then
        retobj.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return resp(retobj)
    end

    local ok, gameidstrs = pcall(cluster.call, "master", ".configmgr", 'getVal', PDEFINE_REDISKEY.LEADERBOARD.GAMEIDS)
    -- if not isempty(gameidstrs) then
    --     -- retobj.gameids = string.split_to_number(gameidstrs, ",")
    --     gameidstrs = gameidstrs
    -- end

    local cacheData = player_tool.getLeaderBoardList(rtype, redis_key,
                        timeInfo.scan.start, timeInfo.scan.stop, gameidstrs)
    -- 目前只暂时前50名，自己在100名也展示
    for ord, item in ipairs(cacheData) do
        item.ord = ord
        if ord <= 50 then
            table.insert(retobj.list, item)
        end
        if ord > 100 then
            break
        end
        if item.uid == uid then
            retobj.myInfo.ord = ord
            retobj.myInfo.score = item.score
            retobj.myInfo.playername = item.playername
            retobj.myInfo.usericon = item.usericon
            retobj.myInfo.reward_coin = item.reward_coin
        end
    end
    
    retobj.list = cacheData

    --看看自己有没有报名
    local sql = string.format([[
        select * from d_lb_register 
        where uid=%d and rtype=%d and create_time between %d and %d
    ]], uid, rtype, timeInfo.scan.start, timeInfo.scan.stop)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs or #rs == 0 then
        retobj.spcode = PDEFINE.RET.ERROR.LEADERBOARD_NOT_REGISTER
    end

    return resp(retobj)
end

-- 开启排行榜
function player.registerLeaderBoard(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.sfloor(recvobj.uid)
    local rtype  = math.sfloor(recvobj.rtype or 1)  -- 类型 1:日榜 2:周榜 3:月榜
    local retobj = {
        c = recvobj.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        uid = uid,
        rtype = rtype,
        coin = nil, -- 扣款金额
        limit = nil,  -- 限制金额
    }

    local redis_key, timeInfo = player_tool.getLeaderBoardInfo(rtype)
    if not redis_key then
        retobj.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return resp(retobj)
    end

    -- 先看自己有没有报名
    local sql = string.format([[
            select * from d_lb_register 
            where uid=%d and rtype=%d and create_time between %d and %d
        ]], uid, rtype, timeInfo.scan.start, timeInfo.scan.stop)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs or #rs == 0 then
        local user = player.getPlayerInfo(uid)
        local ok, row = pcall(cluster.call, "master", ".configmgr", 'get', "leaderboard")
        if not ok or table.empty(row) then
            retobj.spcode = PDEFINE.RET.ERROR.LEADERBOARD_CONFIG_ERROR
            return resp(retobj)
        end
        local allcfg = cjson.decode(row.v)
        -- 判断是否有资格(携带金币数)
        local cfg
        for _, item in pairs(allcfg) do
            if item.rtype == rtype then
                cfg = item
                break
            end
        end
        if not cfg then
            retobj.spcode = PDEFINE.RET.ERROR.LEADERBOARD_CONFIG_ERROR
            return resp(retobj)
        end
        retobj.coin = cfg.register
        retobj.limit = cfg.limit
        if user.coin < cfg.limit or user.coin < cfg.register then
            retobj.spcode = PDEFINE.RET.ERROR.COIN_NOT_ENOUGH
            return resp(retobj)
        end
        -- 扣除金币，报名
        local sql = string.format([[
            insert into d_lb_register 
                (rtype, uid, coin, own_coin, create_time) 
            values (%d, %d, %0.2f, %0.2f, %d)
        ]], rtype, uid, cfg.register, user.coin, os.time())
        skynet.call(".mysqlpool", "lua", "execute", sql)
        handle.addProp(PDEFINE.PROP_ID.COIN, -1*cfg.register, 'leaderboard', '', "排行榜报名")
    else
        retobj.spcode = PDEFINE.RET.ERROR.LEADERBOARD_REGISTERED
        return resp(retobj)
    end

    return resp(retobj)
end

--bonus log
function player.bonuslog(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.sfloor(recvobj.uid)
    local rtype  = math.floor(recvobj.rtype or 0)  -- 类型 

    local retobj = {
        c = recvobj.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        uid = uid,
        rtype = rtype,
        data = {}, -- 列表数据
    }

    local sql = string.format([[
        select id,title,coin,category,create_time,useruid from d_log_cashbonus where uid=%d order by id desc limit 100
    ]], uid)
    if rtype > 0 then
        sql = string.format("select id,title,coin,category,create_time,useruid from d_log_cashbonus where uid=%d and category=%d order by id desc limit 100", uid, rtype)
    end
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    for _, row in pairs(rs) do
        row['category'] = tonumber(row['category'])
        local item = {
            ['id'] = row['id'],
            ['time'] = row['create_time'],
            ['coin'] = row['coin'],
            ['title'] = row['title'],
            ['rtype']  = row['category'],
        }
        if nil~= row['useruid'] and row['useruid'] > 0 then
            if row['category'] == 1 or row['category'] ==2  or row['category'] == 3 then
                item['rtype'] = 100 * row['category'] + 1
            end
        end
        table.insert(retobj.data, item)
    end

    return resp(retobj)
end

--!promo list
function player.promolist(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.sfloor(recvobj.uid)

    local retobj = {
        c = recvobj.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        uid = uid,
        open = 0,
        data = {}, -- 列表数据
    }
    local ok, res = pcall(cluster.call, "master", ".configmgr", "get", "promo_open")
    local open = tonumber(res.v or 0)
    if open == 0 then --开关未开
        return resp(retobj)
    end
    retobj.open = 1

    local sql = "select id,title,ord,banner,memo from d_promo where status=1 order by `ord` desc limit 20"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    for _, row in pairs(rs) do
        local item = {
            ['id'] = row['id'],
            ['title'] = row['title'],
            ['ord'] = row['ord'],
            ['banner'] = '',
            ['memo']  = {},
        }
        local uploadurl = GetAPPUrl('upload')
        if not isempty(row['banner']) then
            item['banner'] = uploadurl .. row['banner'] 
        end
        if not isempty(row['memo']) then
            local memos = {}
            local imgs = string.split(row['memo'], ',')
            for k, v in pairs(imgs) do
                table.insert(memos, uploadurl .. v)
            end
            item['memo'] = memos
        end
        
        table.insert(retobj.data, item)
    end

    return resp(retobj)
end

--!promo detail
function player.promodetail(msg)
    local recvobj = cjson.decode(msg)
    local uid     = math.sfloor(recvobj.uid)
    local id = math.floor(recvobj.id)
    local retobj = {
        c = recvobj.c,
        code = PDEFINE.RET.SUCCESS,
        spcode = 0,
        uid = uid,
        data = {}, -- 单条数据
    }
    if not id or id <= 0 then
        retobj.spcode = PDEFINE.RET.ERROR.PARAM_ILLEGAL
        return resp(retobj)
    end
    local ok, res = pcall(cluster.call, "master", ".configmgr", "get", "promo_open")
    local open = tonumber(res.v or 0)
    if open == 0 then --开关未开
        retobj.spcode = PDEFINE.RET.ERROR.PROMO_NOT_OPEN
        return resp(retobj)
    end

    local sql = string.format("select id,title,ord,banner,memo from d_promo where id=%d", id)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if not rs then
        retobj.spcode = PDEFINE.RET.ERROR.PROMO_NOT_FOUND
        return resp(retobj)
    end
    local uploadurl = GetAPPUrl('upload')
    local item = rs[1]
    if not isempty(item['banner']) then
        item['banner'] = uploadurl.. item['banner'] 
    end
    if not isempty(item['memo']) then
        local memos = {}
        local imgs = string.split(item['memo'], ',')
        for k, v in pairs(imgs) do
            table.insert(memos, uploadurl .. v)
        end
        item['memo'] = memos
    end
    retobj.data = item
    return resp(retobj)
end

return player