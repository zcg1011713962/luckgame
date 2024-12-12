local skynet = require "skynet"
local cluster = require "cluster"

local config = {
}

local user = {
}

local common = {
    { name = "s_game", key = "id"},
}

skynet.start(function()
	LOG_INFO("Server start")
    local nodename = skynet.getenv("nodename")
    assert(nodename)

	local debug_port = skynet.getenv("debug_port")
    if debug_port then 
        skynet.newservice("debug_console",'127.0.0.1',debug_port)
    end
	-- 日志服务
	local log = skynet.uniqueservice("log")
	skynet.call(log, "lua", "start")
	
	cluster.open(nodename)

    local servernode = skynet.uniqueservice("servernode", "true")
    local info={
        servername=nodename,
        tag="game"
    }
    skynet.call(".servernode", "lua", "setMyInfo", info)

    local dbmgr = skynet.uniqueservice("dbmgr")
	skynet.call(dbmgr, "lua", "start", config, user, common)
	
    skynet.uniqueservice("agora") --agora token

    local jackpotmgr = skynet.uniqueservice("jackpotmgr")
    skynet.call(jackpotmgr, "lua", "start")
    
    local gamedatamgr = skynet.uniqueservice("gamedatamgr")
	skynet.call(gamedatamgr, "lua", "start")

	--创建桌子agent
	local dsmgr = skynet.uniqueservice("dsmgr")
	skynet.call(dsmgr, "lua", "start")

    local gamepostmgr = skynet.uniqueservice("gamepostmgr")
	skynet.call(gamepostmgr, "lua", "start")
	skynet.exit()
end)
