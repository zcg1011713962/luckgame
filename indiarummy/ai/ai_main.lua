local skynet = require "skynet"
local cluster = require "cluster"

local config = {
}

local user = {
}

local common = {
	{ name = "d_robot", key = "id"},
    { name = "s_game", key = "id"},
}

skynet.start(function()
    
	LOG_INFO("Server start")

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
	
	local name = skynet.getenv("mastername") or "ai"
	cluster.open(name)
    
    local dbmgr = skynet.uniqueservice("dbmgr")
    skynet.call(dbmgr, "lua", "start", config, user, common)

	local ai = skynet.uniqueservice("aiuser")
	skynet.call(ai, "lua", "start")
    
    --TODO 修复数据
	local mysqlpool = skynet.uniqueservice("mysqlpool")
	skynet.call(mysqlpool, "lua", "start")
	
	skynet.exit()
end)
