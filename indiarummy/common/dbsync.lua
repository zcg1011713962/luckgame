local skynet = require "skynet"
require "skynet.manager"
local cjson   = require "cjson"
local queue = {}
local worker_index = ...

local CMD = {}

function CMD.start()
end

function CMD.stop()
end

function CMD.size()
    return #queue
end

function CMD.sync(sql)
    table.insert(queue, sql)
end

local function sync_impl()
    while true do
        --local combine_count = 20
        --local tmp = 0
        --local combine_sql = ""
        for i = 1, 1000 do
            if #queue <= 0 then
                break
            end
            local sql = table.remove(queue, 1)
            LOG_DEBUG("sync_execute", sql)
            local rs = skynet.call(".mysqlpool" .. worker_index, "lua", "execute", sql)
            if rs.errno ~=nil and tonumber(rs.errno) > 0 then
                LOG_ERROR("error_sql: ".. sql .."----- result:----'%s'",cjson.encode(rs))
            end
        end
        --if combine_sql ~= "" then
        --    combine_sql = "START TRANSACTION;" .. combine_sql .. ";COMMIT;"
        --    LOG_DEBUG("-------TRANSACTION1 sql:----------")
        --    print("-------TRANSACTION1 sql:----------")
        --    print(os.date("%Y-%m-%d %H:%M:%S", os.time()), " sql:", combine_sql)
        --    print("------TRANSACTION sql end-----------")
        --    local rs = skynet.call(".mysqlpool", "lua", "execute", combine_sql)
        --
        --    local rs_str = cjson.encode(rs)
        --    LOG_DEBUG("------rs_str-----------'%s'",rs_str)
        --    --if error then
        --    --    skynet.call(".mysqlpool", "lua", "execute", "ROLLBACK")
        --    --end
        --    tmp = 0
        --    combine_sql = ""
        --end
        skynet.sleep(5) --每5秒同步到db
    end
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd .. "not found")
        skynet.retpack(f(...))
    end)
    skynet.fork(sync_impl)
    if nil == worker_index then 
        worker_index = ""
    end
    skynet.register("." .. SERVICE_NAME .. worker_index)
end)
