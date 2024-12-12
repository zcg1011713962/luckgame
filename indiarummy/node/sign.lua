-- 签到 daily bonus
local sign = {}
local handle
local skynet = require "skynet"
local cjson = require "cjson"
local cluster = require "cluster"
local queue = require "skynet.queue"
local cs = queue()

cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local DEBUG = skynet.getenv("DEBUG")  -- 是否是调试阶段
local SIGN_KEY_PREFIX = 'vip_sign_info'
local MAX_SIGN_TIMES = 7 --最大签到次数

function sign.init(uid)
end

function sign.bind(agent_handle)
	handle = agent_handle
end

--成功返回
local function resp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--检测玩家是否需要弹出签到提示
--redis保存玩家签到时间和已经累计签到次数
--{signCount = 3,signTime = 时间戳}
--@return 1:不能签到,今日已签到或已关闭  0:可以签到，今日未签到或从未签到 2:不用显示签到了
local function checkSignInfo(uid)
    local ok, row = pcall(cluster.call, "master", ".rewardswitchmgr", "getRow", 1) --签到
    if ok and not table.empty(row) then
        if tonumber(row.value) == 0 then
            return 1
        end
    end
    local signInfo = do_redis({ "hgetall", SIGN_KEY_PREFIX .. uid},uid)
    signInfo = make_pairs_table_int(signInfo)
    if not signInfo or table.empty(signInfo) then
        return 0
    else
        local signTimes = tonumber(signInfo.signCount)
        if signTimes >= MAX_SIGN_TIMES then
            return 2
        end

        if nil == signInfo.signTimeStamp then
            return 0
        end
        
        local beginTime = calRoundBeginTime()
        if tonumber(signInfo.signTimeStamp) < beginTime then
            return 0
        end
    end
    -- if DEBUG then
    --     return 0
    -- end
    return 1
end

local function getSignInfo(uid)
    local signInfo = do_redis({ "hgetall", SIGN_KEY_PREFIX .. uid},uid)
    signInfo = make_pairs_table_int(signInfo)
    local signCount = 1
    local signTimes = 0 --累计签到次数, 新用户默认为0
    local signFlag = checkSignInfo(uid)
    if signInfo and not table.empty(signInfo) then
        if signFlag == 0 then
            signCount = tonumber(signInfo.signCount) + 1
            signTimes = signInfo.signTimes or 0
            signTimes = tonumber(signTimes)
            if signCount > MAX_SIGN_TIMES then
                signCount = 1
            end
            if signTimes > MAX_SIGN_TIMES then
                signTimes = MAX_SIGN_TIMES
            end
        else
            signCount = tonumber(signInfo.signCount)
            signTimes = signInfo.signTimes or 0
            signTimes = tonumber(signTimes)
        end
    end
    signCount = math.min(signCount, MAX_SIGN_TIMES)
    local signData
    local ok, rs = pcall(cluster.call, "master", ".configmgr", "getVipSignInfo")
    signData = {}
    for i, row in pairs(rs) do
        table.insert(signData, {
            ['day'] = i,
            ['prize'] = row.prize,
            ['svip'] = row.svip
        })
    end
    -- retobj.signFlag = signFlag  --0 未签到  1已签到
    -- retobj.signCount = signCount --第几天签到
    -- retobj.signTimes = signTimes --累计签到天数，1 - 30
    -- retobj.signData = signData --签到数据
    return signFlag, signCount, signTimes, signData
end

-- 签到
local function doSignJob(uid, iscache)
    local signFlag = checkSignInfo(uid)
    local retobj = {}
    if signFlag >= 1 then
        retobj['spcode'] = 101
        return retobj
    else
        local signInfo = do_redis({ "hgetall", SIGN_KEY_PREFIX .. uid},uid)
        signInfo = make_pairs_table_int(signInfo)
        local curSignCount = 1 --当前签到次数
        local signTimes = 1 --累计签到次数
        local now = os.time()
        local ok, rs = pcall(cluster.call, "master", ".configmgr", "getVipSignInfo")
        local signData = rs[curSignCount]
        -- LOG_DEBUG('doSignJob rs:', rs) 
        -- LOG_DEBUG('doSignJob signData:', signData, ' signInfo:',signInfo) 
        local playerInfo = handle.moduleCall("player", "getPlayerInfo", uid)
        if not signInfo or table.empty(signInfo) then
            signInfo = {}
            signInfo.signCount = curSignCount --已经签了多少次
            signInfo.signTimes = signTimes --累计签了多少次
            signInfo.signTimeStamp = now
            do_redis({ "hmset", SIGN_KEY_PREFIX..uid, signInfo }, uid)
        else
            signTimes = signInfo.signTimes or 0
            signTimes    = signTimes + 1
            curSignCount = signInfo.signCount + 1
            curSignCount = math.floor(curSignCount)
            signData = rs[curSignCount]
            if nil ~=signData.svip and signData.svip > 0 then
                if playerInfo.svip < signData.svip then
                    retobj['spcode'] = PDEFINE_ERRCODE.ERROR.SIGN_NOT_VIP
                    return retobj
                end
            end
            local tmp = {
                ['signCount'] = curSignCount,
                ['signTimes'] = signTimes,
                ['signTimeStamp'] = now
            }
           
            do_redis({ "hmset", SIGN_KEY_PREFIX ..uid, tmp}, uid)
        end
        handle.moduleCall('player', 'syncLobbyInfo', uid)
        
        local userCoin, userDiamond = playerInfo.coin, playerInfo.diamond
        local act = 'vipsign'.. curSignCount
        
        local prize = signData.prize
        local rewardCoin = 0
        retobj.rewards = {}
        for _, item in pairs(prize) do --签到奖励
            if item.type == PDEFINE.PROP_ID.COIN then
                rewardCoin = rewardCoin + item.count
            elseif item.type == PDEFINE.PROP_ID.SKIN_POKER or item.type == PDEFINE.PROP_ID.SKIN_TABLE or item.type == PDEFINE.PROP_ID.SKIN_CHAT or item.type == PDEFINE.PROP_ID.SKIN_FRAME then --牌桌
                local endtime = 86400*item.days
                handle.moduleCall("upgrade", "sendSkins", item.img, endtime) --赠送道具商品
            elseif item.type == PDEFINE.PROP_ID.SKIN_CHARM then
                local count = item.count
                for i=1, count do
                    add_send_charm_times(uid, item.img)
                end
            end
            table.insert(retobj.rewards, item)
        end
        if rewardCoin > 0 then
            if rewardCoin > 0 then
                handle.addProp(PDEFINE.PROP_ID.COIN, rewardCoin, 'dailybonus','',string.format("第%d天", signTimes))
                local orderid = os.date("%Y%m%d%H%M%S", os.time()) .. payId()
                handle.moduleCall("player", "addBonusLog", orderid, string.format("签到彩金，第%d天", signTimes), rewardCoin, os.time(), PDEFINE.TYPE.SOURCE.Sign, uid, 0)
            end
            handle.notifyCoinChanged((userCoin + rewardCoin),(userDiamond+0), rewardCoin, 0)

            local sql = string.format("insert into d_log_sign(uid,signtimes,svip,coin,create_time) values(%d,%d,%d,%.2f,%d)", uid, curSignCount, playerInfo.svip, rewardCoin, os.time())
            do_mysql_queue(sql)
        end
        if not iscache then
            handle.addStatistics(uid, act, '')
        end

        retobj.rewardCoin = rewardCoin
        retobj.curSignCount = curSignCount

        return retobj
    end
end

--! 获取vip周登录签到详情
function sign.getVIPInfo(msg)
    local recvobj = cjson.decode(msg)
    local uid   = math.floor(recvobj.uid)
    local retobj = {}
    retobj.c     = math.floor(recvobj.c)
    retobj.code  = PDEFINE.RET.SUCCESS
    retobj.signFlag, retobj.signCount, retobj.signTimes, retobj.signData = getSignInfo(uid)
    if retobj.signFlag == 2 then
        retobj.signFlag = 1
    end
    return resp(retobj)
end

--! 周登录领取改为普通周签到
function sign.doVIPSign(msg)
    local recvobj = cjson.decode(msg)
    local uid   = math.floor(recvobj.uid)
    local iscache = recvobj.cache --是否缓存请求

    local retobj = {['c'] = math.floor(recvobj.c), ['code'] = PDEFINE.RET.SUCCESS, ['spcode'] = 0}
    local ispopbindphone = 0
    local ok, row = pcall(cluster.call, "master", ".configmgr", "get", "popbindphone")
    if ok then
        ispopbindphone = tonumber(row.v or 0)
    end

    local userInfo = handle.moduleCall("player", "getPlayerInfo", uid)
    if (nil==userInfo.isbindphone or userInfo.isbindphone == 0) and ispopbindphone == 1 then
        retobj.code = PDEFINE.RET.ERROR.GAME_NOT_BIND_PHONE
        return resp(retobj)
    end
    local data = cs(function()
        return doSignJob(uid, iscache)
    end)
    table.merge(retobj, data)
    return resp(retobj)
end

--登录时候，自动签到
function sign.autoSign(uid)
    -- local cacheKey = 'autoSign:'..uid
    -- local flag = do_redis({"get", cacheKey})
    -- flag = tonumber(flag or 0)
    -- if flag == 0 then
    --     local data = doSignJob(uid)
    --     local timeout = getTodayLeftTimeStamp()
    --     do_redis({"setex", cacheKey, 1, timeout})
    --     return data.rewards
    -- end
    return nil
end

function sign.checkSignInfo(uid)
    return checkSignInfo(uid)
end

return sign