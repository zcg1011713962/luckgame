local msgserver = require "snax.wsmsg_server"
local skynet    = require "skynet"
local cluster   = require "cluster"

local server = {}
local users = {}		-- uid -> u
local username_map = {}		-- username -> u
local internal_id = 0
local servername
local agent_pool = {}
local cur_agent
local agent_uid = {}
local nodename  = skynet.getenv("nodename")
local tmpserverinfo = {}
local isreportonline2master = false --正在上报本服在线玩家的数据给master

local max_agent = tonumber(skynet.getenv("maxclient")) or 1024

--local desk_uid = {} --uid跟桌子对象关系
local function addAgent(size)
    for i=1,size do
        cur_agent = cur_agent + 1
        LOG_INFO(string.format("wsgated addAgent cur_agent 加1之后 is %d", cur_agent))
        local agent = skynet.newservice "wsmsgagent"
        table.insert(agent_pool, agent)
    end
end

local function getAgent(uid)
    LOG_INFO(string.format("wsgated getAgent uid:%s cur_agent is %d vs max_agent:%d", uid, cur_agent, max_agent))
    local ret = table.remove(agent_pool)
    if not ret then
        LOG_INFO(string.format("wsgated getAgent uid:%s agent_pool 没有 cur_agent is %d", uid, cur_agent))
        if cur_agent < max_agent then
            addAgent(1)
            return getAgent(uid)
        else
            LOG_INFO(string.format("wsgated getAgent uid:%s agent_pool 没有 cur_agent is %d 将要返回nil", uid, cur_agent))
            return nil
        end
    end
    return ret
end

--获取在线人数
local function onlinenum()
    local num = 0
    for uid,u_agent in pairs(agent_uid) do
        if u_agent ~= nil then
            num = num + 1
        end
    end
    return num
end

--修改服务器信息里面的 在线人数
local function alteronlinenum( ... )
    tmpserverinfo.onlinenum = onlinenum()
    pcall(skynet.call, ".servernode", "lua", "freshServerInfo", tmpserverinfo)
end

local function asyncAddAgent(size)
    addAgent(size)
end

--玩家定时器异步增加agent
local function agent_set_timeout(ti, f,parme)
    local function t()
        if f then
            f(parme)
        end
    end
    skynet.timeout(ti, t)
    return function(parme) f=nil end
end

local function userSetAutoState(autoTime,size)
    LOG_INFO(autoTime , "后添加一个agent")
    agent_set_timeout(autoTime, asyncAddAgent, size)
end

local function logindo( userinfo, secret, agent )
    -- print("logindo usernameinfo:", userinfo, ' secret:', secret, ' agent:', agent)
    --[[
    local userinfo = {}
    userinfo.uid = uid
    userinfo.version = version
    userinfo.unionid = unionid
    userinfo.playercoin = playercoin
    userinfo.access_token = access_token
    userinfo.language = language
    userinfo.client_uuid = client_uuid
    ]]
    local uid = userinfo.uid
    local token = userinfo.access_token
    local clientid = userinfo.client_uuid
    -- local newcoin_para = userinfo.playercoin
    -- local language = userinfo.language

    uid = tonumber(uid)
    internal_id = internal_id + 1
    local sub_id = internal_id
    local username = msgserver.username(uid, sub_id, servername)
    local u = {
        username = username,
        agent = agent,
        uid = uid,
        subid = sub_id,
        token = token, --登录服对应用户下发的token
        clientuuid = clientid,
    }

    local ok, cluster_info = pcall(cluster.call, "master", ".agentdesk", "getDesk", uid)
    -- print("wsgated logindo", uid, sub_id, cluster_info)
    skynet.call(agent, "lua", "login", userinfo, sub_id, secret, cluster_info)
    if agent_uid[uid] then
        pcall(skynet.call, agent_uid[uid], "lua", "setClusterDesk", {})
    end
    agent_uid[uid] = agent
    users[uid] = u
    username_map[username] = u

    -- print("logindo call msgserver.login")
    msgserver.login(username, secret, token)

    return sub_id
end

--[[
-- login server disallow multi login, so login_handler never be reentry
--当一个用户登陆后，登陆服务器会转交给你这个用户的 uid 和 serect ，最终会触发 login_handler 方法。
--在这个函数里，你需要做的是判定这个用户是否真的可以登陆。（一般是可以的，如果想阻止用户多重登陆，
--在登陆服务器里就完成了），然后为用户生成一个 subid ，使用 msgserver.username(uid, subid,
--servername) 可以得到这个用户这次的登陆名。这里 servername 是当前登陆点的名字。
--接着你应该做好用户进入的准备。常规做法是启动一个 agent 服务，然后命令它从数据库加载这个用户的数据。
--如果启动 agent 需要消耗大量的 CPU 时间，你也可以预先启动好多份 agent 放在一个池中，
--这里只需要简单的取出一个可用的空 agent 即可。
--当一切准备好后，把 subid 返回。
--在这个过程中，如果你发现一些意外情况，不希望用户进入，只需要用 error 抛出异常。
]]
function server.login_handler(userinfo, secret)
    -- print("wsgated server.login_handler userinfo:", userinfo, ' secret:', secret)
    --[[
    local userinfo = {}
    userinfo.uid = uid
    userinfo.version = version
    userinfo.unionid = unionid
    userinfo.playercoin = playercoin
    userinfo.access_token = access_token
    userinfo.language = language
    userinfo.client_uuid = client_uuid
    ]]
    local uid = userinfo.uid
    local token = userinfo.access_token
    local clientid = userinfo.client_uuid
    -- local newcoin_para = userinfo.playercoin
    -- local language = userinfo.language

    LOG_INFO("wsgated server.login_handler uid:", uid, " secret:", secret, " token:", token, " cur_agent:",cur_agent)

    uid = tonumber(uid)
    if users[uid] ~= nil and users[uid].clientuuid ~= clientid then
        --玩家已经在线
        return PDEFINE.RET.ERROR.ALREADY_LOGIN
    end
    if agent_uid[uid] ~= nil then
        --玩家退出
        LOG_DEBUG("uid is online but agent is offline, will kick, uid:", uid)
        local isok,islogout = pcall(skynet.call, agent_uid[uid], "lua", "kick", clientid)
        if not isok then
            --这个账号卡在这里退不出去
            LOG_ERROR("kick call fail", uid, userinfo)
        end
        if isok and not islogout then
            --islogout = nil可能是出错了
            --islogout = false 现在有其他登出操作在进行 稍后在来登录
            return PDEFINE.RET.ERROR.FORBIDDEN
        end
    end

    local agent = getAgent(uid)
    if not agent then
        LOG_ERROR("wsgated server.login_handler too many agents uid:", uid, " cur_agent:",cur_agent)
    end

    -- print("wsgated server.login_handler call logindo:", userinfo, ' secret:', secret)
    local ok, sub_id = pcall(logindo, userinfo, secret, agent)
    if not ok then
        return PDEFINE.RET.ERROR.CALL_FAIL
    end

    alteronlinenum()

    return PDEFINE.RET.SUCCESS,sub_id
end

--当一个用户想登出时，这个函数会被调用，你可以在里面做一些状态清除的工作。
--这个事件通常是由 agent 的消息触发
function server.logout_handler(uid, subid)
    LOG_INFO("wsgated logout_handler uid:",uid, " subid:",subid, " cur_agent:",cur_agent, " users[uid]:",users[uid])
    local u = users[uid]
    if u then
        msgserver.logout(u.username)
        users[uid] = nil
        username_map[u.username] = nil

        -- LOG_INFO(" wsgated 开始调用 wslogind中的 logout ...")
        -- pcall(cluster.call, "login", ".login_master", "logout", uid, subid)

        --释放或者回收之前必须判断是否还在房间中
        local ret = skynet.call(u.agent, "lua", "stdesk")
        LOG_INFO("uid:",uid, "stdesk, ret:", ret)
        cur_agent = cur_agent - 1
        alteronlinenum()
        -- if ret == 0 then
            agent_uid[uid] = nil

            userSetAutoState(math.random(50,200), 1)

            --if #agent_pool >= max_poolsize then
            --    -- 释放agent
            --    pcall(skynet.call, u.agent, "lua", "exit")
            --    cur_agent = cur_agent - 1
            --    print(string.format("wsgated server.logout_handler uid:%s 退出agent cur_agent 减1之后 is %d", uid, cur_agent))
            --else
            --    -- 回收agent
            --    table.insert(agent_pool, u.agent)
            --    print(string.format("wsgated server.logout_handler uid:%s 回收agent cur_agent is %d", uid, cur_agent))
            --end
        -- else
        --     local deskAgent = skynet.call(u.agent, "lua", "getClusterDesk")
        --     if not table.empty(deskAgent) then
        --         pcall(cluster.call, "master", ".agentdesk", "joinDesk", deskAgent, uid)
        --     end

        --     local server = skynet.getenv("nodename") or "node"
        --     pcall(cluster.call, "master", ".userCenter", "insetUserAgent", server, u.agent)
            
        --     userSetAutoState(math.random(100,1000), 1)
        --     LOG_INFO(string.format("wsgated server.logout_handler uid:%s 抛弃agent cur_agent 减1之后 is %d", uid, cur_agent))
        -- end

        LOG_INFO("logout poolsize :", #agent_pool, uid, " cur_agent is:", cur_agent)
    end
end

--[[
--当外界（通常是登陆服务器）希望让一个用户登出时，会触发这个事件。
--通常你需要在里面通知 agent 将用户数据写数据库，并且让它在善后工作完成后，
--发起一个 logout 消息（最终会触发 logout_handler）
]]
function server.kick_handler(uid, subid, client_uuid)
    LOG_INFO("kick_handler:" , uid, subid, client_uuid, " cur_agent:",cur_agent)
    local u = users[uid]
    if u then
        local username = msgserver.username(uid, subid, servername)
        LOG_INFO(" username:", username, " u.username:", u.username, " uid:", uid, " subid:", subid, "servername:", servername, ' uid:', u.uid , ' agentid:',u.agent)
        --TODO 后续再验证退出问题
        --assert(u.username == username)
        pcall(skynet.call, u.agent, "lua", "kick", client_uuid)
    else
        pcall(cluster.call, "login", ".login_master", "logout", uid, subid)
    end
    LOG_INFO(string.format("wsgated server.kick_handler uid:%s cur_agent is %d", uid, cur_agent))
end

-- 跟node握手成功回调
-- 先login_handler 再执行connect_handler
function server.connect_handler(username, fd)
    local u = username_map[username]
    local ip = msgserver.ip(username)
    if u then
        skynet.call(u.agent, "lua", "connect", fd, ip)
        LOG_INFO("wsgated server.connect_handler uid:", u.uid, " ip:", ip ," uid:", u.uid, " agentid:", u.agent)
    else
        LOG_WARNING("wsgated server.connect_handler uid:", u.uid, " u is nil", username)
    end
end

--[[
当用户的通讯连接断开后，会触发这个事件。你可以不关心这个事件，也可以利用这个事件做超时管理。
（比如断开连接后一定时间不重新连回来就主动登出
]]
function server.disconnect_handler(username)
    -- print('server.disconnect_handler username:', username)
    local u = username_map[username]
    if u then
        LOG_INFO("disconnect_handler call afk wsmsgagent: uid:", u.uid, ' agentid:', u.agent)
        pcall(skynet.call, u.agent, "lua", "afk")
    else
        LOG_WARNING("disconnect_handler u is nil", username)
    end
end

--[[
--如果用户提起了一个请求，就会被这个 request_handler 捕获到。这里隐藏了 session 信息，
--因为你可以在这个函数中调用 skynet.call 等 RPC 调用，但一般的做法是简单的把 msg,sz
--转发给 agent 即可。这里使用的是 client 协议通道，agent 只需要处理这个协
--具体的业务层通讯协议并无限制。
--等请求处理完后，只需要返回一个字符串，这个字符串会回到框架，加上 session 回应客户端。
--这个函数中允许抛出异常，框架会正确的捕获这个异常，并通过协议通知客户端。
]]
function server.request_handler(username, msg)
    local u = username_map[username]
    return skynet.tostring(skynet.rawcall(u.agent, "client", msg))
end

--[[
--因为 snax.msgserver 实际上是 snax.gateserver 的一个特殊实现。同样有打开监听端口的指令。
--在打开端口时，会触发这个 register_handler name 是在配置信息中配置的当前登陆点的名字，
--你需要把这个名字注册到登陆服务器(其实就是通过发送lua消息给登录服务器)。
--登陆服务器就可以按约定，在用户登陆你的时候把消息转发给你。
]]
function server.register_handler(name, netinfo)
    servername = name
    -- skynet.call(".servernode","lua","setmyinfo",servername,netinfo)

    -- pcall(cluster.call, "login", ".login_master", "register_gate", servername, skynet.self(), netinfo)
    -- pcall(cluster.call, "master", ".userCenter", "register_node", servername, skynet.self(), netinfo)
    -- node启动注册好先开辟一次agentpool
    cur_agent = 0
    addAgent(math.min(200, max_agent))
    LOG_INFO(string.format("server.register_handler name:%s cur_agent:%d, max_agent:%d, poolsize: %d", name, cur_agent, max_agent, #agent_pool))
end

function server.brodcast_handler( uidtable, cmd, ... )
    LOG_DEBUG( "brodcast_handler cmd:", cmd, ... , uidtable)
    for uid,u_agent in pairs(agent_uid) do
        local send = true
        if u_agent == nil then
            send = false
        end
        if send and (type(uidtable)=="table" and table.contain(uidtable, math.floor(uid)==false)) then
            send = false
        end
        if send then
            pcall(skynet.call, u_agent, "lua", cmd, ... )
        end
    end
end

function server.resetloginstarttime( uid )
    if agent_uid[uid] ~= nil then
         pcall(skynet.call, agent_uid[uid], "lua", "resetloginstarttime")
    end
end

--清除掉缓存的桌子
function cleardesk( servername )
    for uid,u_agent in pairs(agent_uid) do
        if u_agent ~= nil then
            pcall(skynet.call, u_agent, "lua", "deskBackByName", servername)
        end
    end
end

function ongamechange( server )
    LOG_DEBUG("ongamechange start server:", server)
    --[[
        server的结构
        server={
            name=xx,
            status=xx,
            tag=xx,
            freshtime=xx,
            serverinfo = {}
        }
    ]]
    if server.status == PDEFINE.SERVER_STATUS.stop then
        --清除掉缓存的桌子
        cleardesk(server.name)
    end

    LOG_DEBUG("ongamechange end server:", server)
end

function callrelogin( ... )
    LOG_DEBUG("onmychange callrelogin")
    for uid,u_agent in pairs(agent_uid) do
        if u_agent ~= nil then
            pcall(skynet.call, u_agent, "lua", "callrelogin")
        end
    end
end

function onmychange( server )
    LOG_DEBUG("onmychange start server:", server)
    --[[
        server的结构
        server={
            name=xx,
            status=xx,
            tag=xx,
            freshtime=xx,
            serverinfo = {}
        }
    ]]
    if server.status == PDEFINE.SERVER_STATUS.weihu then
        --重新登录
        callrelogin()
    else
        
    end

    LOG_DEBUG("ongamechange end server:", server)
end

function server.onserverchange( server )
    LOG_DEBUG("onserverchange server:",server)
    --[[
        server的结构
        server={
            name=xx,
            status=xx,
            tag=xx,
            freshtime=xx，
            serverinfo = {}
        }
    ]]
    if server.tag == "game" then
        ongamechange(server)
    elseif server.name == nodename then
        onmychange(server)
    end
end

-- agent_uid元素个数 
-- agent_pool元素个数
-- cur_agent
-- wmsgagent中的UID和agent_uid 对应不上的数据信息(uid不相等) 2个UID都打印
-- 正在等待关闭的wmsgagent 数量 
function server.infoFun( ... )
    local print_table = {}

    local agentnum = 0
    for uid,u_agent in pairs(agent_uid) do
        if u_agent ~= nil then
            agentnum = agentnum + 1
        end
    end
    local agent_pool_num = #agent_pool
    table.insert(print_table, string.format("agentnum:%d agent_pool_num:%d cur_agent:%d", agentnum, agent_pool_num, cur_agent))

    local MAX_UIDERROR = 10 --最多打印10个出来 
    local uiderror_num = 0
    for uid,u_agent in pairs(agent_uid) do
        if u_agent ~= nil then
            local isok,agentuid = pcall(skynet.call, u_agent, "lua", "getUid" )
            if agentuid ~= uid then
                uiderror_num = uiderror_num + 1
                if uiderror_num <= MAX_UIDERROR then
                    table.insert(print_table, string.format("uiderror isok:%s agentuid:%s uid:%s agentid:", tostring(isok), agentuid, uid, skynet.address(u_agent)))
                end
            end
        end
    end
    table.insert(print_table, "uiderror_num:"..uiderror_num)

    local isok,waitnum,waitlist = pcall(cluster.call, "master", ".userCenter", "getWaitExitUserAgent", 10)
    if isok then
        for _,cluster_info in pairs(waitlist) do
            table.insert(print_table, string.format("waitclose agentid:", skynet.address(cluster_info.address)))
        end
        table.insert(print_table, "waitnum:"..waitnum)
    else
        table.insert(print_table, "get waitnum error")
    end
    
    return print_table
end

--系统启动完成后的通知
function server.start_init( info )
    tmpserverinfo = info

    local callback = {}
    callback.method = "onserverchange"
    callback.address = skynet.self()
    skynet.call(".servernode", "lua", "regEventFun", PDEFINE.SERVER_EVENTS.changestatus, callback)

    local infocallback = {}
    infocallback.method = "infoFun"
    infocallback.address = skynet.self()
    skynet.call(".servernode", "lua", "regInfoFunction", infocallback)
end

--上报本服在线玩家的数据给master
function server.reportOnlineUser( ... )
    LOG_INFO("reportOnlineUser start isreportonline2master:", isreportonline2master)
    if isreportonline2master then
        return
    end

    isreportonline2master = true
    local report_table = {}
    local offline_table = {}
    for uid,u_agent in pairs(agent_uid) do
        if u_agent ~= nil then
            -- LOG_DEBUG("reportOnlineUser uid:", uid, "u_agent:", u_agent)
            local ok,issendjoin = pcall(skynet.call, u_agent, "lua", "getIsjoinPlayer2Master")
            --如果issendjoin=true说明已经发送过join之后不会发送了  这里需要发送一下 如果为false那么等下他自己会去发送
            if ok and issendjoin then
                local ok,code,data = pcall(skynet.call, u_agent, "lua", "getUser2MasterInfo")
                if ok and code == PDEFINE.RET.SUCCESS then
                    table.insert(report_table, data)
                else
                    --下线去
                    table.insert(offline_table, u_agent)
                    LOG_ERROR("reportOnlineUser fail getUser2MasterInfo add offline_table", uid)
                end
            else
                if not ok then
                     LOG_ERROR("reportOnlineUser fail add offline_table", uid)
                    --下线去
                    table.insert(offline_table, u_agent)
                end
                LOG_ERROR("reportOnlineUser fail getIsjoinPlayer2Master:", uid)
            end
        end
    end

    for i,v in ipairs(offline_table) do
        pcall(skynet.call, v, "lua", "callrelogin")
    end

    --分批发给master
    local send_table = {} --一次发1000
    local j = 0
    for i,v in ipairs(report_table) do
        j = j + 1
        table.insert(send_table, v)
        if j >= 1000 then
            pcall(cluster.call, "master", ".userCenter", "setNodeNotify", nodename, send_table, false)
            send_table = {}
            j = 0
        end
    end
    
    pcall(cluster.call, "master", ".userCenter", "setNodeNotify", nodename, send_table, true)
    
    isreportonline2master = false
    LOG_INFO("reportOnlineUser end")
end

function server.otherhandler( cmd, ... )
    if cmd == "otherhandler" then
        return
    end
    server[cmd](...)
end

msgserver.start(server)
