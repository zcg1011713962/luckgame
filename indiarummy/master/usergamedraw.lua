--更新用户的gamedraw信息等
local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"

local CMD = {}

--从userCenter获取用户的agent
local function getAgent(uid)
    return skynet.call(".userCenter", "lua", "getAgent", uid)
end

--获取用户的gamedraw字段值
local function getGameDraw(uid)
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

-- alter
local function updateGameDraw(uid, coin, alterCoin)
    local gamedraw = getGameDraw(uid)
    if (coin - gamedraw) < math.abs(alterCoin) then
        local leftAlterCoin = math.abs(alterCoin) - (coin - gamedraw) --应该从可提现里扣多少
        leftAlterCoin = -1 * leftAlterCoin
        if (gamedraw + leftAlterCoin) < 0 then
            leftAlterCoin = -gamedraw
        end
        do_redis({"hincrbyfloat", 'd_user:'..uid, 'gamedraw', leftAlterCoin})
        local sql = string.format("update d_user set gamedraw =gamedraw+ %.2f where uid = %d", leftAlterCoin, uid)
        skynet.call(".mysqlpool", "lua", "execute", sql)
        return true
    end
end

-- 下注更新gamedraw
function CMD.updateDraw(uid, beforecoin, altercoin)
    local agent = getAgent(uid)
    if agent then
        pcall(cluster.send, agent.server, agent.address, "updateGameDraw", uid, beforecoin, altercoin)
    else
        updateGameDraw(uid, beforecoin, altercoin)
    end
    return true
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
		skynet.retpack(f(...))
	end)
	skynet.register(".usergamedraw")
end)