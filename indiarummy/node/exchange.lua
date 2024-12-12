--[[
    兑换码功能
    1、后台会生成一批兑换码(给渠道或赠送)
    2、用户获取到兑换码后，直接在客户端使用兑换码，兑换成钻石或金币
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
local conf = {
    ['err_limit_time'] = 300, --5分充内错误次数超过次数就ban掉
    ['err_max_times'] = 5, --错误次数
    ['err_ban_time'] = 300, --ban掉禁用时间

    ["ok_limit_time"] = 60, --成功兑换的单位时间, 单位s
    ["ok_max_times"] = 10, --单位时间内，最大兑换次数
    ["ok_ban_time"] = 300, --超过阀值，ban的时间
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

local function warpResp(retobj)
    return PDEFINE.RET.SUCCESS, cjson.encode(retobj)
end

-- 激活
local function activate(code)
    return cs(
        function()
            local spcode = 0
            local can = do_redis({"sismember", PDEFINE.REDISKEY.LOBBY.exchange, code})
            if not can then
                spcode = PDEFINE.RET.ERROR.CODE_HAD_USED
                return spcode, 0, 0
            end
            do_redis({"srem", PDEFINE.REDISKEY.LOBBY.exchange, code})

            local sql = string.format("select * from d_exchange_code where code='%s' limit 1", code)
            local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
            if #rs == 0 then
                spcode = PDEFINE.RET.ERROR.NOT_FOUND_CODE
                return spcode, 0, 0
            end
            local exchange = rs[1]
            sql = string.format("update d_exchange_code set state=%d,consume_time=%d,uid=%d where id=%d", 2, os.time(), UID, exchange.id)
            skynet.call(".mysqlpool", "lua", "execute", sql)

            if exchange.total > 0 then
                handle.addProp(exchange.type, exchange.total, 'cdkey')
                if exchange.type == PDEFINE.PROP_ID.DIAMOND then
                    local diamond = handle.dcCall("user_dc", "getvalue", UID, "diamond")
                    local coin = handle.dcCall("user_dc", "getvalue", UID, "coin")
                    local notifyobj = {}
                    notifyobj.c = PDEFINE.NOTIFY.coin
                    notifyobj.code = PDEFINE.RET.SUCCESS
                    notifyobj.uid = UID
                    notifyobj.deskid = 0
                    notifyobj.count = 0
                    notifyobj.coin = coin
                    notifyobj.diamond = diamond
                    notifyobj.addDiamond = 0
                    notifyobj.type = 1
                    notifyobj.rewards = {}
                    handle.sendToClient(cjson.encode(notifyobj))

                    -- handle.moduleCall("quest", 'updateQuest', UID, PDEFINE.QUEST_TYPE.NEWER, PDEFINE.QUESTID.NEW.REDEMPOTION, 1)
                end
            end
            return spcode, exchange.type, exchange.total
        end
    )
end

-- 激活兑换码
function cmd.activate(msg)
    local recvobj = cjson.decode(msg)
    local code    = recvobj.code or ''
    local retobj = {c = math.floor(recvobj.c), code=PDEFINE.RET.SUCCESS, spcode =0}

    local errBanKey = PDEFINE.REDISKEY.LOBBY.exchange_err_ban .. UID
    local times = do_redis({"get", errBanKey}) or 0 --ban剩余时长
    LOG_DEBUG('activate errBanKey :', errBanKey, ' times:', times)
    times = tonumber(times or 0)
    if times > 0 then
        retobj.spcode = PDEFINE.RET.ERROR.CODE_FREQUENT_ERR --错误次数太多，被ban xxx秒
        retobj.second = times
        return warpResp(retobj)
    end
    local okBanKkey = PDEFINE.REDISKEY.LOBBY.exchange_ok_ban .. UID
    times = do_redis({"get", okBanKkey}) or 0 --ban剩余时长
    LOG_DEBUG('activate errBanKey :', errBanKey, ' times:', times)
    times = tonumber(times or 0)
    if times > 0 then
        retobj.spcode = PDEFINE.RET.ERROR.CODE_FREQUENT_OK --使用太频繁，被ban xxx秒
        retobj.second = times
        return warpResp(retobj)
    end

    local spcode, prod_id, count = activate(code)
    if spcode > 0 then
        retobj.spcode = spcode
        --单位时间内，错误次数超过XX次，就ban掉xx分钟
        local cache_key = PDEFINE.REDISKEY.LOBBY.exchange_times_err .. UID
        times = do_redis({"get", cache_key}) or 0 --错误次数的计数器
        times = math.floor(times)
        if times <= 0 then
            do_redis({"setex", cache_key , 1, conf.err_limit_time})
        else
            do_redis({"incr", cache_key })
        end
        LOG_DEBUG("exchange activate uid:", UID, ' error_times:', times)
        if times >= conf.err_max_times then
            LOG_DEBUG("exchange activate uid:", UID, ' error times baned')
            do_redis({"setex", errBanKey , 1, conf.err_ban_time})
        end
        return warpResp(retobj)
    else
        --单位时间内，使用次数超过XX次，就停用xx分钟
        local cache_key = PDEFINE.REDISKEY.LOBBY.exchange_times_use .. UID
        times = do_redis({"get", cache_key}) or 0 --错误次数的计数器
        times = math.floor(times)
        if times <= 0 then
            do_redis({"setex", cache_key , 1, conf.ok_limit_time})
        else
            do_redis({"incr", cache_key })
        end
        LOG_DEBUG("exchange activate uid:", UID, ' ok_times:', times)
        if times >= conf.ok_max_times then
            LOG_DEBUG("exchange activate uid:", UID, ' too frequent baned')
            do_redis({"setex", okBanKkey , 1, conf.ok_ban_time})
        end
    end

    local playerInfo = handle.moduleCall("player", "getPlayerInfo", UID)
    local resp = {
        uid = UID,
    }
    if prod_id == PDEFINE.PROP_ID.COIN then
        resp.coin = playerInfo.coin
    else
        resp.diamond = playerInfo.diamond
    end
    handle.syncUserInfo(resp)

    retobj.ecode = code
    retobj.rewards = {}
    table.insert(retobj.rewards, {type=prod_id, count=count})
    return warpResp(retobj)
end

return cmd