local skynet = require "skynet"
require "skynet.manager"
local snax = require "snax"
local CMD = {}

local account_dc

function CMD.get_account_dc(username)
    if nil == account_dc then
        account_dc = snax.queryservice("accountdc")
    end
    local account = account_dc.req.get(username)
    return account
end

function CMD.set_account_item(id, field, data)
    if nil == account_dc then
        account_dc = snax.queryservice("accountdc")
    end

    return account_dc.req.setValue(id, field, data)
end

--绑定第三方登录，这里落地
function CMD.set_account_data(uid, row)
    --注册成功
    local sql = string.format("INSERT INTO `d_user_bind`(uid,unionid,nickname,sex,platform,create_time) VALUE(%d, '%s', '%s', %d, %d, %d);",
        row.uid,
        row.pid,
        row.playername,
        0,
        row.logintype,
        os.time())
    skynet.call(".dbsync", "lua", "sync", sql)
    return true
end

--重新才从db加载单条数据
function CMD.reload(uid)
    local sql = string.format("select * from d_account where id=%d", uid)
    local rs = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        if not account_dc then
            account_dc = snax.uniqueservice("accountdc")
        end
        uid = tonumber(uid)
        local account = account_dc.req.get(uid)
        if account == nil or table.empty(account) then
            account_dc.req.add(rs[1], true)
        else
            for _, row in pairs(rs) do
                for field, value in pairs(row) do
                    if value ~= account[field] then
                        account_dc.req.setValue(row.id, field, value)
                    end
                end
            end
        end
    end
end

function CMD.addUserAccount(playername, uid)
    do_redis({"zadd", "d_account:index:" .. tostring(playername), 0, tostring(uid)}, uid)
end

function CMD.addGuestPicId(uid, picid)
    do_redis({"setex", "user_" .. uid .. "_picid", picid, 3600}, uid)
end

function CMD.getGuestPicId(uid)
    local picid = do_redis({"get", "user_" .. uid .. "_picid"}, uid)
    if picid == nil then
        picid = 0
    end
    picid = math.floor(picid)
    return picid
end

function CMD.apiReleaseAccount(uid, pid)
    local row = {}
    row["deled"] = 1
    row["pid"] = "del" .. tostring(uid)
    CMD.set_account_data(uid, row)

    do_redis({"del", "d_account:index:" .. pid})
    do_redis({"del", "d_account:" .. uid})
end

--根据indexkey值获取account数量
function CMD.get_account_by_indexkey(pid)
    if not pid then
        return false
    end
    local sql = string.format("select * from d_user_bind where unionid='%s'", pid)
    local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        return true
    end
    return false
end

-- 根据uid 和 平台 获取绑定的信息
function CMD.get_account_by_uid(uid, platform)
    if not uid then
        return false
    end
    local sql = string.format("select * from d_user_bind where uid=%d and platform=%d", uid, platform)
    local rs  = skynet.call(".mysqlpool", "lua", "execute", sql)
    if #rs > 0 then
        return rs[1]
    end
    return false
end

skynet.start(
    function()
        skynet.dispatch(
            "lua",
            function(session, address, cmd, ...)
                local f = CMD[cmd]
                skynet.retpack(f(...))
            end
        )
        skynet.register(".accountdata")
    end
)
