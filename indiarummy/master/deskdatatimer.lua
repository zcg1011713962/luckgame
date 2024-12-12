local skynet = require "skynet"
require "skynet.manager"
local cjson = require "cjson"
local snax = require "snax"
local cluster = require "cluster"
local game_tool = require "game_tool"
local api_service = require "api_service"
local player_tool = require "base.player_tool"
local CMD = {}
local UPDATE_TIME_OUT  = 1000
local LIMIT_NUM = 1000
local pauseupdate = true --暂停update 只有api服务器状态正常的时候才会update

--处理过期数据
local function expireLoanDesk(redis_key, expiretime)
    local gameid,uid = game_tool.data.getinfofromRedisKey(redis_key)
    LOG_DEBUG("expireLoanDesk", gameid, uid, redis_key, expiretime)
    if gameid ~= nil and uid ~= nil then
        local delcount = do_redis({"zrem", PDEFINE.REDISKEY.GAME.expire_sortedset, redis_key})
        if delcount > 0 then
            local deskdata = do_redis({"get", redis_key})
            LOG_DEBUG("deskdata", deskdata)
            if deskdata ~= nil then
                --如果api服务器突然挂掉 那这个账会对不上这种情况先不考虑 到时候出了问题再加上逻辑
                deskdata = cjson.decode(deskdata)
                --1,删除数据redis
                do_redis({"del", redis_key})
                --2,还钱
                local loan_coin=deskdata.loan_data.loan_coin
                local uniid=deskdata.loan_data.uniid
                local deskid=deskdata.loan_data.deskid
                local poolround_id=deskdata.loan_data.poolround_id
                local bet_coin=deskdata.loan_data.bet_coin
                local poolround_para = {
                    uniid = uniid, --唯一id
                    pooltype = PDEFINE.POOL_TYPE.none, --pooltype  PDEFINE.POOL_TYPE
                    poolround_id = poolround_id, --pr的唯一id
                }
                local gameinfo_para = {
                    gameid = gameid, --游戏id
                    deskid = deskid, --桌子id
                    subgameid = 0, --子游戏id
                }
                --发送结束日志
                if bet_coin ~= nil and bet_coin > 0 then
                    local player = player_tool.getPlayerInfo(math.floor(uid))
                    local after_coin = 0
                    local before_coin = 0
                    if player == nil then
                        LOG_ERROR("player is nil, uid = ", uid, deskdata)
                    else
                        after_coin = player.coin
                        before_coin = after_coin
                    end

                    local gameinfo_para_log = {
                        gameid = gameid, --游戏id
                        deskid = deskid, --桌子id
                        subgameid = 0, --子游戏id
                        deskuuid = uniid, --桌子唯一id
                        roundinfo = {
                            bet = tonumber(bet_coin), --下注
                            win = 0, --赢钱
                            result = "data expire", --游戏结果
                        }
                    }
                    pcall(api_service.callAPIMod,
                        "sendGameLog", 
                        uid, 
                        before_coin, 
                        after_coin, 
                        gameinfo_para_log, 
                        poolround_para
                    )
                end
            else
                LOG_ERROR("expireLoanDesk haskey,nodata key:", redis_key)
            end
        end
    end
end

--检查是否过期
local function checkexpire( ... )
    --拿出redis数据
    local nowtime = os.time()
    local rslist = do_redis({"zrangebyscore", PDEFINE.REDISKEY.GAME.expire_sortedset, LIMIT_NUM, 1, 0, nowtime})
    if rslist ~= nil and #rslist > 0 then
        rslist = make_pairs_table_int(rslist)
        for key,expiretime in pairs(rslist) do
            pcall(expireLoanDesk, key, expiretime)
        end
    end
end

function update( )
    while true do
        if not pauseupdate then
            pcall(checkexpire)
        end

        skynet.sleep(UPDATE_TIME_OUT)
    end
end

function onapichange( server )
    local servername = server.name
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
        pauseupdate = true
        LOG_DEBUG("pauseupdate:", pauseupdate)
    elseif server.status == PDEFINE.SERVER_STATUS.run then
        pauseupdate = false
        LOG_DEBUG("pauseupdate:", pauseupdate)
    end

    LOG_DEBUG("onapichange server:", server, "server_list:", server_list)
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
    if server.tag == "api" then
        onapichange(server)
    end
end

--系统启动完成后的通知
function CMD.start_init( ... )
    local callback = {}
    callback.method = "onserverchange"
    callback.address = skynet.self()

    skynet.call(".servernode", "lua", "regEventFun", PDEFINE.SERVER_EVENTS.changestatus, callback)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".deskdatatimer")

    skynet.fork(update)
end)