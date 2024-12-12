--等级礼包 弹窗专用计时器

local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local snax = require "snax"
local cjson   = require "cjson"

local CMD = {}
local timer_list = {}

-- 清理定时器
local function clearTimer(uid)
    if timer_list[uid] then
        skynet.remove_timeout(timer_list[uid])
        timer_list[uid] = nil
    end
end

--异步通知
local function sendNotify(uid)
    skynet.call(".userCenter", "lua", "closePoP", uid, PDEFINE.SHOPSTYPE.LEVEL)
    timer_list[uid] = nil
end

--真正的定时器
local function user_set_timeout(ti, f, uid)
    local function t()
        if f then
            f(uid)
        end
    end
    if timer_list[uid] == nil then
        timer_list[uid] = skynet.timeout(ti, t)
    end
    return function(parme) f=nil end
end

--清理玩家的定时器
function CMD.clearTimeout(uid)
    clearTimer(uid)
end

-- 给玩家设置定时器
function CMD.setTimeOut(uid, timeout)
    local playerinfo = skynet.call(".userCenter", "lua", "getPlayerInfo", uid)
    if nil == playerinfo then
        error("user data is nil: ", uid)
        return false
    end
    
    user_set_timeout(timeout * 100, sendNotify, uid)
    return true
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
		skynet.retpack(f(...))
	end)
	skynet.register(".levelgiftmgr")
end)