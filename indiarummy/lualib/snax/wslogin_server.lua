--websocket login_server
local skynet = require "skynet"
require "skynet.manager"
local netpack = require "websocketnetpack"
local socketdriver = require "skynet.socketdriver"
local socket = require "socket"
local crypt = require "crypt"
local wbsocket = require "wbsocket"
local websocket = require "websocket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local cjson = require "cjson"

local MessagePack = require "MessagePack"
local checksum = require "checksum"

local table = table
local string = string
local assert = assert

local function send_msg(fd, msg)
    local info
    if USE_PROTOCOL_MSGPACK then
        info = '00000000'.. MessagePack.pack(msg)
    else
        info = '00000000'.. MessagePack.pack(cjson.encode(msg))
    end
    wbsocket:send_binary(fd, info)
end


local socket_error = {}

local function launch_slave(auth_handler)

    local function auth(fd, addr, message)
        local secret = crypt.base64encode(message.user)
        -- local ok, server, uid, version, errorCode, unionid, playercoin, token = pcall(auth_handler, message)
        local ok, errorCode, userinfo = pcall(auth_handler, message, addr)

        LOG_INFO("launch_slave auth ok ", ok, errorCode, userinfo)
        return secret, ok, errorCode, userinfo
    end

    local function ret_pack(ok, err, ...)
        if ok then
            skynet.ret(skynet.pack(err, ...))
        else
            if err == socket_error then
                skynet.ret(skynet.pack(nil, "socket error"))
            else
                skynet.ret(skynet.pack(false, err))
            end
        end
    end

    skynet.dispatch("lua", function(_, _, ...)
        ret_pack(pcall(auth, ...))
    end)
end

local user_login = {}    -- key:uid value:true 表示玩家登录记录

local function accept(conf, s, fd, addr, message)
    if #message < 9 then
        LOG_ERROR("message size too short, size:", #message)
        wbsocket:close(fd)
        return
    end
    local head = message:sub(1, 8)
    local size = string.byte(head, 1) * 256 + string.byte(head, 2)
    if size ~= #message - 8 then  --包大小不对
        LOG_ERROR("message size error", size, #message-8, message)
        wbsocket:close(fd)
        return
    end

    --TODO 包头先不解析 包头占8位
    local taildata = message:sub(9, #message)

    checksum.check(head, taildata)

    local msg
    if USE_PROTOCOL_MSGPACK then
        msg = MessagePack.unpack(taildata)
    else
        local jsonmsg = MessagePack.unpack(taildata)
        msg = cjson.decode(jsonmsg)
    end
    local bwss = msg.bwss or 0
    local app = msg.app or 0 --客户端底包标志
    --secret, ok, errorCode, server, userinfo
    LOG_DEBUG(string.format(" yrp_test s= %s fd= %s addr= %s", s,fd,addr))
    --print(" msg:"..msg)
    local secret, ok, errorCode, userinfo = skynet.call(s, "lua", fd, addr, msg)

    -- local ok, server, uid, secret, version, errorCode, unionid, playercoin, access_token = skynet.call(s, "lua", fd, addr, msg)
    socket.start(fd)
    if errorCode ~= 200 then
        if errorCode == nil then
            errorCode = 500
        end
        local spcode = 0
        if errorCode ~= 200 then
            spcode = errorCode
            errorCode = 200
        end
	LOG_ERROR("12345")
        send_msg(fd, {c=msg.c, code= errorCode, spcode=spcode, errinfo="login fail"})
        --socket.close(fd)
        wbsocket:close(fd)
        return
    end

    if not ok then
        LOG_DEBUG("402 Unauthorized")
        send_msg(fd, {c=msg.c, code= 402, errinfo="Unauthorized"})
        --socket.close(fd)
        wbsocket:close(fd)
        return
    end

    local uid = userinfo.uid
    if not uid then
        LOG_ERROR("auth failed")
        send_msg(fd, {c=msg.c, code= 402, errinfo="auth failed"})
        --socket.close(fd)
        wbsocket:close(fd)
        return
    end

    local version = userinfo.version
    local unionid = userinfo.unionid
    local playercoin = userinfo.playercoin
    local access_token = userinfo.access_token
    local language = userinfo.language

    if not conf.multilogin then
        local isset = do_redis({"setnx", PDEFINE.REDISKEY.GAME.loginlock..":"..uid, 1, 10}, uid) --10s还没解锁就过期
        if isset == nil then
            --没得到锁
            send_msg(fd, {c=msg.c, code= 406, errinfo="Not Acceptable"})
            LOG_ERROR("406 Not Acceptable uid=%d is already login", uid)
            --socket.close(fd)
            wbsocket:close(fd)
            return
         end
    end
    local ok, err, subid, netinfo, server = pcall(conf.login_handler, secret, bwss, userinfo, app) --h5的要使用wss, bwss参数为1 表示h5调用
    
    do_redis({"del", PDEFINE.REDISKEY.GAME.loginlock..":"..uid}, uid)
    user_login[uid] = nil
    if ok then
        if err == PDEFINE.RET.SUCCESS then
            subid = subid or ""
            unionid = unionid or ""
            local result = {c = msg.c, code = 200 }
            result.net = netinfo
            result.uid = uid
            result.server = server
            result.subid = subid
            result.token = access_token
            result.unionid = unionid
            send_msg(fd,result)
        else
            send_msg(fd, {c=msg.c, code= err, errinfo="other err"})
        end
    else
        local result = {c = msg.c, code = 405, errinfo=string.format(" Forbidden uid=%d", uid) }
        send_msg(fd,result)
        LOG_DEBUG("405 Forbidden uid=%d", uid, err)
    end

    --socket.close(fd)
    LOG_DEBUG("wbsocket:close(fd)")
    wbsocket:close(fd)
end

local function launch_master(conf)
    local instance = conf.instance or 8
    assert(instance > 0)
    local slave = {}
    local balance = 1
    local conf = conf

    for i = 1, instance do
        table.insert(slave, skynet.newservice(SERVICE_NAME))
    end

    --lua暴露接口 给 websocket
    local MSG = {}

    function MSG.login(source, fd, addr, msg)
        fd = tonumber(fd)
        local s = slave[balance]
        balance = balance + 1
        if balance > #slave then
            balance = 1
        end

        local ok, err = pcall(accept, conf, s, fd, addr, msg)
        if not ok then
            if err ~= socket_error then
                LOG_DEBUG(string.format("invalid client (fd = %d) error = %s", fd, err))
            end
            -- socket.start(fd)
        end
    end

    skynet.dispatch("lua", function(_, source, command, ...)
        if command:lower() == "login" then
            local f = MSG[command]
            if f then
                skynet.retpack(f(source, ...))
            end
        else
            skynet.ret(skynet.pack(conf.command_handler(command, ...)))
        end
    end)
end

local function login(conf)
    local name = "." .. (conf.name or "login")
    skynet.start(function()
        local loginmaster = skynet.localname(name)
        if loginmaster then
            local auth_handler = assert(conf.auth_handler)
            launch_master = nil
            conf = nil
            launch_slave(auth_handler)
        else
            launch_slave = nil
            conf.auth_handler = nil
            assert(conf.login_handler)
            assert(conf.command_handler)
            skynet.register(name)
            launch_master(conf)
        end
    end)
end

return login
