local skynet = require "skynet"
local cluster = require "cluster"

local common = {
    { name = "s_game", key = "id"},
    { name = "s_quest", key = "id"},
}

local user = {
    { name = "d_user", key = "uid" },
}

local function clear_online_cache()
    local login_type_list = {1,10,11,12} -- 1游客 10 谷歌  11 苹果 12 FB
    for _, item in pairs(login_type_list) do
        do_redis({"del", "online_logintype_"..item})
    end
    local platform_list = {1, 2} --1安卓  2iOS 客户端在线人数
    for _, platform in pairs(platform_list) do
        do_redis({"del", "online_platform_"..platform})
    end

    local country_list = do_redis({"smembers", "online_all_country_list"}) --国家列表
    for _, country in pairs(country_list) do
        do_redis({"del", "online_country_"..country})
    end
end

skynet.start(function()
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

        --登录流程桌子信息
        skynet.uniqueservice("agentdesk")

        local debug_port = skynet.getenv("debug_port")
    if debug_port then
        skynet.newservice("debug_console",debug_port)
    end

        local log = skynet.uniqueservice("log")
        skynet.call(log, "lua", "start")
        cluster.open(nodename)

        local dbmgr = skynet.uniqueservice("dbmgr")
    skynet.call(dbmgr, "lua", "start", {}, user, common)

        --数据同步
        local dbsync = skynet.uniqueservice("dbsync")
        skynet.call(dbsync, "lua", "start")

        --桌子服务
        skynet.uniqueservice("mgrdesk")

        skynet.uniqueservice("orderdeliver")
    --config_dc服
    local configmgr = skynet.uniqueservice("configmgr")
    skynet.call(configmgr, "lua", "start")

    -- 中心节点玩家地址管理服务
    skynet.uniqueservice("agentmgr")

    --在线奖励时间配置
    skynet.uniqueservice("rewardonlinemgr")

    --FB奖励配置
    skynet.uniqueservice("fbawardmgr")

        --game_dc服
    local gamemgr = skynet.uniqueservice("gamemgr")
    skynet.call(gamemgr, "lua", "start")


    -- local activitymgr = skynet.uniqueservice("activitymgr")
    -- skynet.call(activitymgr, "lua", "start")

    

    -- local gametask = skynet.uniqueservice("gametask")
    -- skynet.call(gametask, "lua", "start")

    local questmgr = skynet.uniqueservice("questmgr")
    skynet.call(questmgr, "lua", "start")

    --获取开关
    skynet.uniqueservice("rewardswitchmgr")

    -- 用户集合服务
    local userCenter = skynet.uniqueservice("userCenter")
    skynet.call(userCenter, "lua", "start")

    local cfgleaguemgr = skynet.uniqueservice("cfgleague")
    skynet.call(cfgleaguemgr, "lua", "reload")
    local cfglevelmgr = skynet.uniqueservice("cfglevel")
    skynet.call(cfglevelmgr, "lua", "reload")

    --商品初始化
    local shopmgr = skynet.uniqueservice("shopmgr")
    skynet.call(shopmgr, "lua", "start")

    local genuid = skynet.uniqueservice("genuid") --生成uid
    skynet.call(genuid, "lua", "start")

    skynet.uniqueservice("levelgiftmgr") --等级礼包弹窗倒计时

    skynet.uniqueservice("servermgr")

    local servernode = skynet.uniqueservice("servernode", "true")
    local info={
        servername=nodename,
        tag="master",
        watchtaglist={"game","node","api"}
    }
    skynet.call(".servernode", "lua", "setMyInfo", info)

    skynet.uniqueservice("loginmaster")
    skynet.uniqueservice("deskdatatimer")

    local balmatchmgr = skynet.uniqueservice("balmatchmgr")
    skynet.call(balmatchmgr, "lua", "start")
    skynet.uniqueservice("invitemgr")
    skynet.uniqueservice("balviproommgr")
    skynet.uniqueservice("balclubroommgr")
    skynet.uniqueservice("balprivateroommgr")
    skynet.uniqueservice("tournamentmgr")
    skynet.uniqueservice("raceroommgr")
    skynet.uniqueservice("sessmgr")
    skynet.uniqueservice("usergamedraw")

    -- skynet.uniqueservice("clubmgr")

    --TODO 以后改成注册形式
    skynet.call(".mgrdesk", "lua", "start_init")
    skynet.call(".agentmgr", "lua", "start_init")
    skynet.call(".agentdesk", "lua", "start_init")
    skynet.call(".loginmaster", "lua", "startInit")
    skynet.call(".userCenter", "lua", "start_init")
    skynet.call(".deskdatatimer", "lua", "start_init")

    --策略服务
    local strategymgr = skynet.uniqueservice("strategymgr")
    skynet.call(strategymgr, "lua", "start")

    local friend = skynet.uniqueservice("friend")
    skynet.call(friend, "lua", "start")

    -- 排行榜
    local winrankmgr = skynet.uniqueservice("winrankmgr")
    skynet.call(winrankmgr, "lua", "start")
    
    clear_online_cache()
        skynet.exit()
end)
