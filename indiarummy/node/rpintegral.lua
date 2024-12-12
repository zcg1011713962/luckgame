--[[
    rp值积分
    1、玩游戏可以获得一定的rp值
    2、rp值可以兑换金币或道具奖品
]]
local cjson   = require "cjson"
local skynet = require "skynet"
local queue = require "skynet.queue"
local cluster = require "cluster"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local cs = queue()
local cmd = {}
local handle
local UID = 0

-- rp兑换配置
local shopList = {
    {id = 1, diamond = 640, rp = 5000},
    {id = 2, diamond = 1440, rp = 10000},
    {id = 3, diamond = 4000, rp = 25000},
}

function cmd.bind(agent_handle)
	handle = agent_handle
end

function cmd.initUid(uid)
    UID = uid
end

function cmd.init(uid)
    UID = uid
end

--成功返回
local function resp(retobj)
    LOG_DEBUG("RETURN resp:", retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

--! 获取rp值兑换金币列表
function cmd.getShopList(msg)
    local recvobj = cjson.decode(msg)
    local uid = recvobj.uid
    local iscache = recvobj.cache --是否缓存请求
    local retobj = {c = math.floor(recvobj.c), code=PDEFINE.RET.SUCCESS, spcode =0}
    local rp_key = PDEFINE_REDISKEY.OTHER.rpendtime .. uid
    local ttl = do_redis({"ttl", rp_key})
    LOG_DEBUG("getShopList rp_key:", rp_key, ' ttl:', ttl)
    if ttl <= 0 or ttl == nil then
        ttl = 0
    end
    retobj.endtime = ttl + os.time() + 3600
    retobj.data = shopList

    if not iscache then
        handle.addStatistics(uid, 'open_rp_pop', '')
    end
    return resp(retobj)
end

function cmd.info(msg)
    local recvobj = cjson.decode(msg)
    local gameid = math.floor(recvobj.gameid or 0)
    local uid = recvobj.uid
    local retobj = {c = math.floor(recvobj.c), code=PDEFINE.RET.SUCCESS, spcode =0}

    local rp_key = PDEFINE_REDISKEY.OTHER.rpendtime .. uid
    local ttl = do_redis({"ttl", rp_key})
    LOG_DEBUG("getShopList rp_key:", rp_key, ' ttl:', ttl)
    if ttl <= 0 or ttl == nil then
        ttl = 0
    end
    retobj.endtime = ttl + os.time() + 3600

    retobj.data = {}
    for k, rowlist in pairs(PDEFINE.RP.TIME) do
        if retobj.data[k] == nil then
            retobj.data[k] = {}
        end
        for _, row in pairs(rowlist) do
            table.insert(retobj.data[k], string.format("%d:00-%d:00", row.start, row.stop))
        end
    end
    retobj.winrp = 0
    if PDEFINE.RP_CONFIG.REWARD[gameid] ~= nil then
        retobj.winrp = table.maxn(PDEFINE.RP_CONFIG.REWARD[gameid])
    else
        retobj.winrp = table.maxn(PDEFINE.RP_CONFIG.REWARD.default)
    end
    return resp(retobj)
end

--! rp值兑换金币
function cmd.exchange(msg)
    local recvobj = cjson.decode(msg)
    local id = math.floor(recvobj.id) --列表id
    local uid = math.floor(recvobj.uid)
    local iscache = recvobj.cache --是否缓存请求
    local retobj = {c = math.floor(recvobj.c), code=PDEFINE.RET.SUCCESS, spcode =0, rewards={}}

    local item
    for _, row in pairs(shopList) do
        if row.id == id then
            item = row
            break
        end
    end
    if nil == item then
        retobj.spcode = PDEFINE.RET.ERROR.SHOP_NOT_FOUND --商品id错误
        if not iscache then
            handle.addStatistics(uid, 'exchange_rp', 'fail_' ..id)
        end
        return resp(retobj)
    end
   
    local diamond = item.diamond
    local userInfo = handle.moduleCall("player", "getPlayerInfo", UID)
    userInfo.rp = tonumber(userInfo.rp or 0)
    if userInfo.rp < item.rp then
        retobj.spcode = PDEFINE.RET.ERROR.RP_NOT_ENOUGH
        if not iscache then
            handle.addStatistics(uid, 'exchange_rp', 'fail_0')
        end
        return resp(retobj)
    end
    handle.addProp(PDEFINE.PROP_ID.RP, -item.rp, 'rp') --扣rp
    handle.addProp(PDEFINE.PROP_ID.DIAMOND, diamond, 'rp') --加金币
    table.insert(retobj.rewards, {type=PDEFINE.PROP_ID.DIAMOND, count=diamond})

    userInfo = handle.moduleCall("player", "getPlayerInfo", UID)

    local notifyobj = {}
    notifyobj.c = PDEFINE.NOTIFY.coin
    notifyobj.code = PDEFINE.RET.SUCCESS
    notifyobj.uid = UID
    notifyobj.deskid = 0
    notifyobj.count = 0
    notifyobj.coin = userInfo.coin
    notifyobj.diamond = userInfo.diamond
    notifyobj.addDiamond = 0
    notifyobj.type = 1
    notifyobj.rewards = {}
    handle.sendToClient(cjson.encode(notifyobj))

    handle.syncUserInfo({uid= UID, rp=userInfo.rp})
    if not iscache then
        handle.addStatistics(uid, 'exchange_rp', 'succ')
    end
    return resp(retobj)
end

return cmd