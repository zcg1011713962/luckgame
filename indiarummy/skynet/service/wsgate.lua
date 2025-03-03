local skynet = require "skynet"
local gateserver = require "snax.wsgateserver"
--local netpack = require "websocketnetpack"

local watchdog
local connection = {}	-- fd -> connection : { fd , client, agent , ip, mode }
local forwarding = {}	-- agent -> connection

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

local handler = {}

function handler.open(source, conf)
	print(" handler.open 开启: source:", source, ' conf:', conf.watchdog)
	watchdog = conf.watchdog or source
end

function handler.message(fd, msg, sz)
	-- recv a package, forward it
	local c = connection[fd]
	print("handler.message fd:", fd, ' msg:', msg, ' sze:',sz)
	if c == nil then
		skynet.redirect(watchdog, fd, "client", 0, msg, sz)
		return		
	end
	
	local agent = c.agent
	if agent then
		skynet.redirect(agent, c.client, "client", 0, msg, sz)
	else
		skynet.redirect(watchdog, fd, "client", 0, msg, sz)
	end
end

function handler.connect(fd, addr)
	print("handler.connect fd:", fd, ' addr:', addr)
	local c = {
		fd = fd,
		ip = addr,
	}
	connection[fd] = c
	skynet.send(watchdog, "lua", "socket", "open", fd, addr)
end

local function unforward(c)
	if c.agent then
		forwarding[c.agent] = nil
		c.agent = nil
		c.client = nil
	end
end

local function close_fd(fd)
	local c = connection[fd]
	if c then
		unforward(c)
		connection[fd] = nil
	end
end

function handler.disconnect(fd)
	print("handler.disconnect fd:", fd)
	close_fd(fd)
	print("handler.disconnect send to watchdog to close df:", fd)
	skynet.send(watchdog, "lua", "socket", "close", fd)
end

function handler.error(fd, msg)
	close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "error", fd, msg)
end

function handler.warning(fd, size)
	skynet.send(watchdog, "lua", "socket", "warning", fd, size)
end

local CMD = {}

function CMD.forward(source, fd, client, address)
	local c = connection[fd]
	if c == nil then
		return false
	end
	unforward(c)
	if watchdog == source then
		return gateserver.openclient(fd)
	end
	c.client = client or 0
	c.agent = address or source
	forwarding[c.agent] = c
	return gateserver.openclient(fd)
end

function CMD.accept(source, fd)
	local c = assert(connection[fd])
	unforward(c)
	gateserver.openclient(fd)
end

function CMD.kick(source, fd)
	gateserver.closeclient(fd)
end

function handler.command(cmd, source, ...)
	local f = assert(CMD[cmd])
	return f(source, ...)
end

gateserver.start(handler)
