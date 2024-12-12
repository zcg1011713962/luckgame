local skynet = require "skynet"
local cluster = require "cluster"

skynet.start(function()
    LOG_INFO("Server start")
    local nodename = skynet.getenv("nodename")
    assert(nodename)

    local debug_port = skynet.getenv("debug_port")
    if debug_port then 
        skynet.newservice("debug_console",debug_port)
    end

    local log = skynet.uniqueservice("log")
    skynet.call(log, "lua", "start")

    -- 数据库服务
    local dbmgr = skynet.uniqueservice("dbmgr")
    skynet.call(dbmgr, "lua", "start", config, user, common)

    skynet.uniqueservice("accountdata")
    skynet.uniqueservice("versionfile")
    skynet.uniqueservice("loginweb")

    cluster.open(nodename)
    
    skynet.uniqueservice("servernode", "true")
    local info={
        servername=nodename,
        tag="loginhttp"
    }
    skynet.call(".servernode", "lua", "setMyInfo", info)
    skynet.exit()
end)