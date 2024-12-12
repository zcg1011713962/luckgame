local skynet  = require "skynet"
local cluster = require "cluster"
local cjson   = require "cjson"
local config = {}
local user = {
    { name = "d_user", key = "uid" },
    { name = "d_user_daily_data", key = "uid,datatype", baseid = "datatype", indexkey = "uid"},
    { name = "d_user_common_data", key = "uid,datatype", baseid = "datatype", indexkey = "uid"},
    { name = "d_mail", key = "uid,mailid", baseid = "mailid", indexkey = "uid", autoincrease = "1" },
    { name = "d_quest", key = "uid,questid", baseid = "questid", indexkey = "uid"},
    { name = "d_game_task", key = "uid" },
    { name = "d_sys_user_msg", key = "uid,msgid", baseid = "msgid", indexkey = "uid", autoincrease = "1" },
    { name = "d_pass", key = "uid"},
    { name = "d_bank", key = "uid", baseid = "uid"},
}

local common = {
    {name = "s_quest", key="id"},
}

skynet.start(function()
    LOG_INFO("Server start")
    local ip = skynet.getenv "ip"
    assert(ip)
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

    -- 日志服务
    local log = skynet.uniqueservice("log")
    skynet.call(log, "lua", "start")

    -- 数据库服务
    local dbmgr = skynet.uniqueservice("dbmgr")
    skynet.call(dbmgr, "lua", "start", config, user, common)

    if debug_port then
        skynet.newservice("debug_console",debug_port)
    end

    local gate  = skynet.uniqueservice("wsgated")
    skynet.call(gate, "lua", "open" , {
        port = cport,
        maxclient  = tonumber(skynet.getenv("maxclient")) or 1024, -- 允许客户端最大连接数
        resize     = 30, -- agent扩容参数
        servername = nodename,
        netinfo    = ip..":"..cport
    })
    cluster.open(nodename)

    local usertype_s = skynet.getenv("usertype") or PDEFINE.USER_TYPE.normal
    local usertype_t = {}
    local usertype_arr = string.split(usertype_s, ',')
    for k,v in pairs(usertype_arr) do
        table.insert(usertype_t, v)
    end

    -- skynet.uniqueservice("apple") --apple iap
    -- skynet.uniqueservice("google") --google iap
    
    -- skynet.uniqueservice("facebook") --facebook
    -- skynet.uniqueservice("huawei") --huawei
    skynet.uniqueservice("pushmsg") 
    skynet.uniqueservice("sms")
    
    -- 彩池服务
    local jackpotmgr = skynet.uniqueservice("jackpotmgr")
    skynet.call(jackpotmgr, "lua", "start")
    skynet.uniqueservice("statistics")

    local chatService = skynet.uniqueservice("chat")
    skynet.call(chatService, "lua", "start")

    local clubidmgrService = skynet.uniqueservice("clubidmgr")
    skynet.call(clubidmgrService, "lua", "start")

    local cacheService = skynet.uniqueservice("cache")
    skynet.call(cacheService, "lua", "run")

    local servernode = skynet.uniqueservice("servernode", "true")
    local info = {
        servername = nodename,
        tag = "node",
        netinfo = ip..":"..cport,
        address = gate,
        onlinenum = 0,--在线人数
        watchtaglist = {"game"},
        watchlist = {nodename}, --监听自己的事件
        usertypetable = usertype_t
    }
    skynet.call(".servernode", "lua", "setMyInfo", info)

    skynet.call(gate, "lua", "start_init", info)

    skynet.exit()
end)
