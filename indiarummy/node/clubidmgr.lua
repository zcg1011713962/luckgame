local skynet = require "skynet"
require "skynet.manager"

local redisKey = "club:id:pool"
local CMD = {}

-- 如果redis中没有ID池，则从数据库中读取ID池
function CMD.start()
    local pool = do_redis({"scard", redisKey})
    if not pool or pool == 0 then
        -- 读取数据库中的id
        local sql = "select cid from d_club order by cid";
        local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
        if not rs then
            LOG_ERROR("读取d_club中的cid失败")
            return nil
        end
        local min = 100000
        local max = 999999
        -- 如果数据库中还没有值，则直接加载所有id池
        if #rs == 0 then
            for i = min, max do
                do_redis({"sadd", redisKey, i})
            end
        else
            -- 绕过数据库中的id, 将未用的id放入redis池中
            for _, _r in ipairs(rs) do
                local cid = _r['cid']
                if cid >= min and cid <= max then
                    for i = min, max do
                        if i == cid then
                            break
                        end
                        do_redis({"sadd", redisKey, i})
                    end
                    min = cid + 1
                end
            end
        end
    end
end

-- 获取一个club id
function CMD.genClubId()
    local cid = do_redis({"spop", redisKey})
    if not cid then
        LOG_ERROR("生成cid失败")
        return nil
    end
    return cid
end


skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".clubidmgr")
end)