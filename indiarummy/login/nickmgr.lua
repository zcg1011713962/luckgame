local skynet = require "skynet"
require "skynet.manager"
local cluster = require "cluster"
local snax = require "snax"
local cjson   = require "cjson"
local queue = require "skynet.queue"
local CMD = {}
local cs = queue()

-- 昵称管理
local all_list     = {} --当前所有未被使用的昵称

-- 加载所有未被使用的昵称
local function loadData()
    local tmp_all_list = {}

    local sql = "select * from s_nickname where state=0"
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        for _, row in pairs(rs) do
            table.insert(tmp_all_list, {["id"]=row.id, ["title"]= row.title})
        end
    end
    all_list = tmp_all_list
end

-- 获取1个没使用过的昵称, 获取完就标记为已使用
function CMD.getOne()
    if table.empty(all_list) then
        loadData()
    end
    if #all_list > 0 then
        local item = table.remove(all_list)
        local sql = string.format("update s_nickname set state = %d where id=%d", 1, item.id)
        do_mysql_queue(sql)
        return item.title
    else
        LOG_ERROR("没有昵称可用了")
        return "Player"
    end
end

--重新从库里加载配置到游戏
function CMD.reload()
    loadData()
end

function CMD.start()
    if table.empty(all_list) then
        loadData()
    end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
		skynet.retpack(f(...))
	end)
    skynet.register(".nickmgr")
    
    CMD.start()
end)