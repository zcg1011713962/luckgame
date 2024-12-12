local skynet = require "skynet"
require "skynet.manager"
local httpc = require "http.httpc"
local cjson = require "cjson"
local jsondecode = cjson.decode

local snax = require "snax"
local cluster = require "cluster"
local webclient
local CMD = {}
local url_head = "http://192.168.50.124/game/"
local MAX_REGISTER_NUM = 100 --最多同时创建的用户数量
local TIME_OUT  = 3000
--1=正常，0=游戏维护中
local game_switch = 0
--白名单列表 用,分割
local game_swl = ""
local LOCAL_POOL_CHECK = false --是否检查本地水线
----为生成唯一id使用的变量
----为生成唯一id使用的变量

local MAX_SUBGAME_LOSE = 10000 --子游戏保底到1W，如果低于这个值 那么借钱或者扣款不成功

--[[
请求游戏开关接口
]]
function requestgameswitch( )
    local url = url_head.."/game/system/gameswitch"
    local ok, body = skynet.call(webclient, "lua", "request", url, nil, nil, false,TIME_OUT)
    local resp = nil
    local needrecall = false
    if not ok or body == nil then
	LOG_DEBUG("not ok or body == nil body:",body)
        needrecall = true
    else
        LOG_DEBUG("requestgameswitch body:", body)
        ok,resp = pcall(jsondecode,body)
        if not ok then
            needrecall = true
        else
            if resp.errcode ~= 0 then
                --启动一个定时服务 有可能后台在维护
                needrecall = true
            end
        end
    end

    if needrecall then
        --启动一个定时服务 有可能后台在维护
        local function t()
            requestgameswitch()
        end
        --6000 60秒之后再请求一次 不用太频繁
        skynet.timeout(6000, t)
        return
    end

    game_switch = resp.data.game_switch
    game_swl = resp.data.game_swl
    if game_swl == nil then
        game_swl = ""
    end
    if game_switch == 0 then
        --关闭
        ok, retok, result = pcall(cluster.call, "master", ".mgrdesk", "apiCloseServer")
        --T人下线
        ok,retok,result = pcall(cluster.call, "master", ".userCenter", "ApiPushRestart")
    elseif game_switch == 1 then
        --开启
        ok, retok, result = pcall(cluster.call, "master", ".mgrdesk", "apiStartServer")
    end

end

--后台上下分
--@param uid
--@param coin
--@param ipaddr
--@return code
function CMD.addCoin(uid, coin, ipaddr, addType, extend1)
    LOG_DEBUG("-->-->-->addCoin uid", uid, "coin", coin, ' addType:', addType, " extend1:", extend1)
    coin = tonumber(coin)
    local ok, retok, result = pcall(cluster.call, "master", ".userCenter", "apiAddCoin", uid, coin, ipaddr, addType, extend1)
    if not ok or retok~=PDEFINE.RET.SUCCESS then
        LOG_ERROR("addCoin CALL_FAIL uid", uid, "coin", coin, ' addType:', addType)
        return PDEFINE.RET.ERROR.CALL_FAIL
    end

    LOG_ERROR("addCoin retok", retok)
    return retok
end

--[[
检查是否有用户需要创建
根据后台API服的队列通知，建立游戏服账号
]]
local function checkregister( )
    local registernum = 0
    local rediskey = "{bigbang}:logs:players"
    local result = do_redis_withprename( "api_", {"lpop", rediskey} )
    while result ~= nil do
        registernum = registernum + 1
        if registernum > MAX_REGISTER_NUM then
            break
        end
        LOG_DEBUG( "checkregister registeruser:", result )
        local ok,jsondata = pcall(jsondecode,result)
        if not ok then
            LOG_ERROR( "checkregister fail,jsondata error:", result )
        else
            local ok = pcall(cluster.call, "master", ".userCenter", "registeruser", jsondata)
            LOG_DEBUG( "checkregister call userCenter ok:", ok)
            if not ok then
                --失败了
                LOG_ERROR( "checkregister fail,registeruser:", result )
                --可能是服务出错了 先不继续执行了
                return
            end
            --创建成功了 开始上下分
            if tonumber(jsondata.coin) > 0 then
                --上下分
                local ok, code = pcall(CMD.addCoin, math.floor(tonumber(jsondata.uid)), tonumber(jsondata.coin), jsondata.ipaddr)
                if not ok or code ~= PDEFINE.RET.SUCCESS then
                    LOG_ERROR( "checkregister fail,addCoin error ok:", ok, "code:", code)
                end
            end
            --BB红包用户，代理创建完账号,直接就给玩家红包，玩家登录只展示红包打开动作
            if nil~=jsondata.red_envelope and tonumber(jsondata.red_envelope) > 0 then
                --上下分
                local ok, code = pcall(CMD.addCoin, math.floor(tonumber(jsondata.uid)), tonumber(jsondata.red_envelope), jsondata.ipaddr, 'red_envelope')
                if not ok or code ~= PDEFINE.RET.SUCCESS then
                    LOG_ERROR( "checkregister red_envelope fail ,addCoin error ok:", ok, "code:", code)
                end
            end
        end

        result = do_redis_withprename( "api_", {"lpop", rediskey} )
    end
end

--1S执行一次
function update( )
    while true do
        pcall(checkregister)
        skynet.sleep(20)
    end
end

--设置游戏状态
function CMD.setgameswitch(game_switch_p, game_swl_p)
    game_switch = tonumber(game_switch_p) or 1
    game_swl = game_swl_p
    return PDEFINE.RET.SUCCESS
end

--获取游戏状态
function CMD.getgameswitch()
    LOG_DEBUG( "getgameswitch game_switch:", game_switch, " game_swl:", game_swl )
    return game_switch, game_swl
end

--导入库存量
--@param gameid
--@return 库存量
local function reloadSubGamePool(gameid)
    local pool = do_redis({"get", string.format("%s:%s", PDEFINE.REDISKEY.YOU9API.subgame_localpool, gameid)})
    if pool == nil then
        pool = 0
    end
    return pool
end

--获取库存量
--@param gameid
--@return 库存量
local function getSubgamePool(gameid)
    local local_pool = reloadSubGamePool(gameid)
    return local_pool
end

--设置库存量
--@param gameid
--@param pool 库存量
local function setSubgamePool(gameid, pool)
    do_redis({"set", string.format("%s:%s", PDEFINE.REDISKEY.YOU9API.subgame_localpool, gameid), pool})
end

--设置库存量
--@param gameid
--@param pool 库存量
function CMD.addSubgamePool(gameid, num)
    local local_pool = getSubgamePool(math.floor(tonumber(gameid)))
    do_redis({"set", string.format("%s:%s", PDEFINE.REDISKEY.YOU9API.subgame_localpool, math.floor(tonumber(gameid))), local_pool + num})
end

skynet.start(function()
    local apiurl = cluster.call( "master", ".configmgr", "get", "apiurl" )
    if apiurl == nil then
        LOG_ERROR("you9apisdk apiurl isnil.")
    end
    url_head = apiurl.v
    --url_head = "http://47.238.169.232:9638"
    for i= 1, PDEFINE.MAX_APIWORKER do
        skynet.newservice("you9api_worker", i)
    end
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    webclient = skynet.newservice("webreq")
    requestgameswitch()

    skynet.register(".you9apisdk")

    skynet.fork(update)
end)
