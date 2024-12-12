local skynet  = require "skynet"
local cluster = require "cluster"

local config = {
}

local user = {
}

local common = {
    { name = "d_account", key = "id", indexkey = "pid"},
}

skynet.start(function()
    LOG_INFO("Server start")
    -- 服务开启端口
    local cport = tonumber(skynet.getenv("port"))
    assert(cport)
    local nodename  = skynet.getenv("nodename")
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

    -- 日志服务
    local log = skynet.uniqueservice("log")
    skynet.call(log, "lua", "start")

    local dbmgr = skynet.uniqueservice("dbmgr")
    skynet.call(dbmgr, "lua", "start", config, user, common)

    skynet.uniqueservice("wslogind")
    cluster.open(nodename)

    skynet.uniqueservice("webservice", cport)

    skynet.uniqueservice("accountdata")

    -- 昵称管理
    skynet.uniqueservice("nickmgr")

    skynet.uniqueservice("servernode", "true")
    local info={
        servername=nodename,
        tag="login",
        watchtaglist={"api"}
    }
    skynet.call(".servernode", "lua", "setMyInfo", info)
    --TODO 以后改成注册形式
    skynet.call(".login_master", "lua", "start_init")
    -- skynet.uniqueservice("facebook") --facebook
    -- skynet.uniqueservice("wechat") --wechat
    skynet.uniqueservice("versionfile")

    skynet.exit()
end)
