--面向游戏内部服务的转发
local skynet = require "skynet"
require "skynet.manager"
local snax = require "snax"
local cluster = require "cluster"
local CMD = {}

function dispatchMsg( cmd, ... )
    --中间增加转发是为以后扩展方便，现在写死
    return skynet.call(".you9apisdk", "lua", cmd, ...)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        LOG_DEBUG("servicecall receive cmd:", cmd)
        skynet.retpack(dispatchMsg( cmd, ... ))
    end)
    skynet.register(".servicecall")
end)