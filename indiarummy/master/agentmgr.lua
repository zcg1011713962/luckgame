local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
-- 玩家的agent管理
local CMD = {}
-- 管理玩家所在节点信息 玩家对应的node中的agent服
local client_agents = {}

function CMD.joinPlayer(cluster_info, uid)
	client_agents[uid] = cluster_info;
end

function CMD.removePlayer(uid)
	client_agents[uid] = nil
end

function CMD.getPlayer(uid)
	return client_agents[uid]
end

function CMD.getAllAgent()
	return client_agents
end

function CMD.callAgentFun(uid, fun, ...)
	local client_agent = assert(client_agents[uid])
	if client_agent then
		return cluster.call(client_agent.server, client_agent.address, fun, ...)
	end
	return nil
end

--清除掉缓存的桌子
local function cleardesk( servername )
    for uid,cluster_info in pairs(client_agents) do
        if cluster_info.server == servername then
            client_agents[uid] = nil
        end
    end
end

local function ongamechange( server )
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

    LOG_DEBUG("ongamechange server:", server)
end

function CMD.onserverchange( server )
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
    end
end

--系统启动完成后的通知
function CMD.start_init( ... )
    local callback = {}
    callback.method = "onserverchange"
    callback.address = skynet.self()

    skynet.call(".servernode", "lua", "regEventFun", PDEFINE.SERVER_EVENTS.changestatus, callback)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
		skynet.retpack(f(...))
	end)
	skynet.register(".agentmgr")
end)
