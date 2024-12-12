local skynet = require "skynet"
local cluster = require "cluster"

skynet.start(function()
    LOG_INFO("Server start")
    local nodename = skynet.getenv("nodename")
    assert(nodename)

    local emmylua_port = skynet.getenv("emmylua_port")
    if emmylua_port then
        local dbg = require("emmy_core")
		local ret = dbg.tcpListen("localhost", emmylua_port)
		print("dbg.tcpListen", emmylua_port, ret)
		-- dbg.waitIDE()
		-- dbg.breakHere()
    end

    local debug_port = skynet.getenv("debug_port")
    if debug_port then 
        skynet.newservice("debug_console",debug_port)
    end

    local log = skynet.uniqueservice("log")
    skynet.call(log, "lua", "start")

    -- 数据库服务
    local dbmgr = skynet.uniqueservice("dbmgr")
    skynet.call(dbmgr, "lua", "start", config, user, common)

    local api_redispool = skynet.newservice("redispool","api_")
    skynet.call(api_redispool, "lua", "start")

    skynet.uniqueservice("apiweb")

    cluster.open(nodename)
    
    skynet.uniqueservice("servernode", "true")
    local info={
        servername=nodename,
        tag="api"
    }
    skynet.call(".servernode", "lua", "setMyInfo", info)

    for i= 1, PDEFINE.MAX_APIWORKER do
        local mysqlpool = skynet.newservice("mysqlpool", i)
        skynet.call(mysqlpool, "lua", "start")
    end

    for i=1, PDEFINE.MAX_APIWORKER do 
        local dbsync = skynet.newservice("dbsync", i)
        skynet.call(dbsync, "lua", "start")
    end
    
    skynet.uniqueservice("you9apisdk")

    skynet.exit()
end)