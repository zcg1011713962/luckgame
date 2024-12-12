local skynet = require "skynet"
require "skynet.manager"
local httpc = require "http.httpc"
local cjson = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local snax = require "snax"
local cluster = require "cluster"
local webclient

--[[
    服务端推送服务
    符合一定的条件，游戏服主动触发推送
]]

local CMD = {}

function CMD.send(uids, msgid, nickname)
    assert(uids)
    assert(msgid)
    local uid = uids
    if type(uids) == 'table' then
        uid = table.concat(uids, ',')
    end
    local ok, cfg = pcall(cluster.call, "master", ".configmgr", 'get', "push_url")
    if nil == cfg or "" == cfg.v then
        return
    end

    local post = {}
    post["uid"] = uid
    post["id"] = msgid
    if nickname then
        post["title"] = nickname
    end
    local data = cjson.encode(post)
    LOG_DEBUG("push get url:", cfg.v, ' data:', data)
    if nil == webclient then
        webclient = skynet.newservice("webreq")
    end
    local ok, body = skynet.call(webclient, "lua", "request", cfg.v, nil, data, false)
    LOG_DEBUG(" push msg 结果:", ok, body)
    if not ok then
        assert("push msg server error!")
    end

    local ok, resp = pcall(jsondecode, body)
    if ok then
        if resp.code == 200 then
            return PDEFINE.RET.SUCCESS
        end
    end
    return 500
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
        skynet.register(".pushmsg")
    end
)
