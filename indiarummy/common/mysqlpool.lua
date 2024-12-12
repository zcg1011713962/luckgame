local skynet = require "skynet"
require "skynet.manager"
local mysql = require "mysql"

local worker_index = ...
local CMD = {}
local pool = {}

local maxconn
local index = 2
local function getconn(sync)
	local db
	if sync then
		db = pool[1]
	else
		db = pool[index]
		assert(db)
		index = index + 1
		if index > maxconn then
			index = 2
		end
	end
	return db
end

function CMD.start()
	maxconn = tonumber(skynet.getenv("mysql_maxconn")) or 10
	assert(maxconn >= 2)
	for i = 1, maxconn do
		local function on_connect(db)
			db:query("set charset utf8mb4");
		end
		local db = mysql.connect({
			host = skynet.getenv("mysql_host"),
			port = tonumber(skynet.getenv("mysql_port")),
			database = skynet.getenv("mysql_db"),
			user = skynet.getenv("mysql_user"),
			password = skynet.getenv("mysql_pwd"),
			max_packet_size = 1024 * 1024,
			charset="utf8mb4",
			on_connect = on_connect
		})
		if db then
			table.insert(pool, db)
		else
			skynet.error("mysql connect error")
		end
	end
end

-- sync为false或者nil，sql为读操作，如果sync为true用于数据变动时同步数据到mysql，sql为写操作
-- 写操作取连接池中的第一个连接进行操作
function CMD.execute(sql, sync)
	local db = getconn(sync)
	return db:query(sql)
end

function CMD.stop()
	for _, db in pairs(pool) do
		db:disconnect()
	end
	pool = {}
end

function CMD.keepalive()
	for _, db in pairs(pool) do
		db:query("select 1")
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
		local f = assert(CMD[cmd], cmd .. "not found")
		skynet.retpack(f(...))
	end)
	if nil == worker_index then 
        worker_index = ""
    end
	skynet.register("."..SERVICE_NAME .. worker_index)
end)
