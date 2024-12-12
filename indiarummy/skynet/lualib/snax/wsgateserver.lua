local skynet = require "skynet"
local netpack = require "websocketnetpack"
local socketdriver = require "socketdriver"
local MessagePack = require "MessagePack"
local httpd = require "http.httpd"
local urllib = require "http.url"
local string = require "string"
local crypt = require "crypt"
local cjson = require "cjson"
local gateserver = {}

local max_packsize = 10*1024
local max_headersize = 1024
local socket	-- listen socket
local queue		-- message queue
local maxclient	-- max client
local client_number = 0
local CMD = setmetatable({}, { __gc = function() netpack.clear(queue) end })
local nodelay = false
local connection = {}  --{ isconnect, iswebsocket_handeshake (default 1) }

-------------websocket 握手时解析http请求头--------------------------------
local function parse_httpheader(http_str)
    local header = {}
    local i = 0
    local start = 0
    local str
    i = string.find(http_str, "\r\n", i+1)
    while true  and i ~= nil do
        start = i + 2
        i = string.find(http_str, "\r\n", start)
        if i ~= nil then
            str = string.sub(http_str, start, i-1)
            local key, value = string.match(str, "([%a-]+)%s*: (.*)")
            if key ~= nil then
                header[key:lower()] = value
            end
        end
    end

    return header
end

------------------websocket 握手时使用的相关接口  begin----------------------
local function getwebsocket_response(key, protocol)
    protocol = protocol or ""
    if protocol ~= "" then
        protocol = protocol .. "\r\n"
    end

    local accept = crypt.base64encode(crypt.sha1(key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
    return string.format("HTTP/1.1 101 Switching Protocols\r\n" ..
    "Upgrade: websocket\r\n" ..
    "Connection: Upgrade\r\n" ..
    "Sec-WebSocket-Accept: %s\r\n" ..
    "%s\r\n", accept, protocol)

end

local function checkwebsocket_valid(header, check_origin, check_origin_ok)
    -- Upgrade header should be present and should be equal to WebSocket
    if not header["upgrade"] or header["upgrade"]:lower() ~= "websocket" then
        return 400, "Can \"Upgrade\" only to \"WebSocket\"."
    end

    -- Connection header should be upgrade. Some proxy servers/load balancers
    -- might mess with it.
    if not header["connection"] or not header["connection"]:lower():find("upgrade", 1,true) then
        return 400, "\"Connection\" must be \"Upgrade\"."
    end

    -- Handle WebSocket Origin naming convention differences
    -- The difference between version 8 and 13 is that in 8 the
    -- client sends a "Sec-Websocket-Origin" header and in 13 it's
    -- simply "Origin".
    local origin = header["origin"] or header["sec-websocket-origin"]
    if origin and check_origin and not check_origin_ok(origin, header["host"]) then
        return 403, "Cross origin websockets not allowed"
    end

    if not header["sec-websocket-version"] or header["sec-websocket-version"] ~= "13" then
        return 400, "HTTP/1.1 Upgrade Required\r\nSec-WebSocket-Version: 13\r\n\r\n"
    end

    local key = header["sec-websocket-key"]
    if not key then
        return 400, "\"Sec-WebSocket-Key\" must not be  nil."
    end

    local protocol = header["sec-websocket-protocol"] 

    return nil, getwebsocket_response(key, protocol)

end

local function writefunc(fd)
    return function(content)
        local ok = socketdriver.send(fd, content)
        if not ok then
            error(socket_error)
            socketdriver.close(fd)
        end
    end
end
------------------websocket 握手时使用的相关接口  end----------------------

--websocket下行
--默认fin和mask
function gateserver.send_frame(fd, opcode, data)
    local finbit, mask_bit = 0x80,0
    -- if fin then finbit = 0x80 else finbit = 0 end
    -- if self.mask_outgoing then mask_bit = 0x80 else mask_bit = 0 end
    local frame = string.pack("B", finbit | opcode)
    local len = #data
    if len < 126 then
        frame = frame .. string.pack("B", len | mask_bit)
    elseif len < 0xFFFF then
        frame = frame .. string.pack(">BH", 126 | mask_bit, len)
    else
        frame = frame .. string.pack(">BL", 127 | mask_bit, len)
    end
    frame = frame .. data
    socketdriver.send(fd, frame)
end

function gateserver.send_text(fd,data)
    gateserver.send_frame(fd, 0x1, data)
end

function gateserver.send_binary(fd,data)
    gateserver.send_frame(fd, 0x2, data)
end

function gateserver.send_msg(fd, msg)
    local info
    LOG_DEBUG("websocket send info : ", msg)
    if USE_PROTOCOL_MSGPACK then
        info = '00000000'.. MessagePack.pack(cjson.decode(msg))
    else
        info = '00000000'.. MessagePack.pack(msg)
    end
    gateserver.send_binary(fd, info)
end

function gateserver.openclient(fd)
    print("gateserver.openclient fd:", fd)
    if connection[fd] ~= nil  and  connection[fd].isconnect then
        socketdriver.start(fd)
        print("gateserver.openclient socketdriver.start fd:", fd, ' return ture')
        return true
    end
    -- print("gateserver.openclient socketdriver.start fd:", fd, ' return false')
    return false
end

function gateserver.closeclient(fd)
    print("gateserver.closeclient fd:", fd)
    local c = connection[fd]
    if c then
        client_number = client_number - 1
        connection[fd] = nil
        socketdriver.close(fd)
        print("gateserver.closeclient in if fd:", fd)
    end
end

function gateserver.checkwebsocket(fd, header)

    local code, result = checkwebsocket_valid(header, nil, nil)
    if code then
        httpd.write_response(writefunc(fd), code, result)
        print("gateserver.checkwebsocket close fd:", fd)
        gateserver.closeclient(fd)
        return false
    else
        socketdriver.send(fd, result)
    end
    return true
end

function gateserver.start(handler)
    assert(handler.message)
    assert(handler.connect)

    function CMD.open( source, conf )
        assert(not socket)
        local address = conf.address or "0.0.0.0"
        local port = assert(conf.port)
        maxclient = conf.maxclient or 1024
        nodelay = conf.nodelay
        LOG_INFO(string.format("Listen on %s:%d", address, port))
        --skynet.error(string.format("Listen on %s:%d", address, port))
        socket = socketdriver.listen(address, port)
        -- print("CMD.open socket:", socket, string.format("Listen on %s:%d", address, port))
        socketdriver.start(socket)
        if handler.open then
            return handler.open(source, conf)
        end
    end

    function CMD.close()
        -- print('CMD.close socket:', socket)
        assert(socket)
        socketdriver.close(socket)
    end

    local MSG = {}

    local function dispatch_msg(fd, msg, sz)
        if connection[fd] ~= nil and connection[fd].isconnect then
            if connection[fd].iswebsocket_handeshake == 1 then
                --websocket 握手回包处理
                if sz >= max_headersize then
                    gateserver.closeclient(fd)
                    return
                end

                local str_msg = netpack.tostring(msg, sz)
                local header = parse_httpheader(str_msg)
                if (gateserver.checkwebsocket(fd, header)) then
                    connection[fd].iswebsocket_handeshake = 0
                end
                return								
            end

            if sz >= max_packsize then				
                gateserver.closeclient(fd)
                return
            end

            handler.message(fd, msg, sz)			
        else
            skynet.error(string.format("Drop message from fd (%d) : %s", fd, netpack.tostring(msg,sz)))
        end
    end

    MSG.data = dispatch_msg

    local function dispatch_queue()
        local fd, msg, sz = netpack.pop(queue)
        if fd then
            -- may dispatch even the handler.message blocked
            -- If the handler.message never block, the queue should be empty, so only fork once and then exit.
            skynet.fork(dispatch_queue)
            dispatch_msg(fd, msg, sz)

            for fd, msg, sz in netpack.pop, queue do
                dispatch_msg(fd, msg, sz)
                if not msg then
                    print("dispatch_msg fd:", fd, ' not msg')
                end
            end
        end
    end

    MSG.more = dispatch_queue

    function MSG.open(fd, msg)
        -- print("MSG.open fd:", fd, ' msg:', msg , ' client_number:', client_number, ' maxclient:',maxclient)
        if client_number >= maxclient then
            socketdriver.close(fd)
            return
        end
        if nodelay then
            socketdriver.nodelay(fd)
        end
        connection[fd] = {}
        connection[fd].isconnect = true
        connection[fd].iswebsocket_handeshake = 1
        client_number = client_number + 1
        -- print("MSG.open fd:", fd, ' call handler.connect:')
        handler.connect(fd, msg)
    end

    local function close_fd(fd)
        local c = connection[fd]
        if c ~= nil then
            connection[fd] = nil
            client_number = client_number - 1
        end
    end

    function MSG.close(fd)
        -- print("MSG.close fd:", fd, ' socket:', socket)
        if fd ~= socket then
            -- print("MSG.close fd ~= socket  fd:", fd, ' socket:', socket)
            if handler.disconnect then
                handler.disconnect(fd)
            end
            close_fd(fd)
        else
            -- print("MSG.close fd == socket  fd:", fd, ' socket:', socket)
            socket = nil
        end
    end

    function MSG.error(fd, msg)
        if fd == socket then
            socketdriver.close(fd)
            skynet.error(msg)
        else
            if handler.error then
                handler.error(fd, msg)
            end
            close_fd(fd)
        end
    end

    function MSG.warning(fd, size)
        if handler.warning then
            handler.warning(fd, size)
        end
    end

    skynet.register_protocol {
        name = "socket",
        id = skynet.PTYPE_SOCKET,	-- PTYPE_SOCKET = 6
        unpack = function ( msg, sz )
            local _, fd = socketdriver.unpack(msg, sz)
            if (connection[fd] == nil ) then
                return netpack.filter( queue, msg, sz, 1)
            elseif connection[fd].isconnect then
                return netpack.filter( queue, msg, sz, connection[fd].iswebsocket_handeshake)
            end
            return netpack.filter( queue, msg, sz, 1)
        end,
        dispatch = function (_, _, q, type, ...)
            queue = q
            if type then
                -- print("socket protocol dispatch type:", type)
                MSG[type](...)
            end
        end
    }

    skynet.start(function()
        skynet.dispatch("lua", function (_, address, cmd, ...)
            local f = CMD[cmd]
            if f then
                skynet.ret(skynet.pack(f(address, ...)))
            else
                skynet.ret(skynet.pack(handler.command(cmd, address, ...)))
            end
        end)
    end)
end

return gateserver
