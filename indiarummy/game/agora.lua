local skynet = require "skynet"
require "skynet.manager"
local httpc = require "http.httpc"
local cjson = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local snax = require "snax"
local cluster = require "cluster"
local webclient

-- 声网token获取代理

local CMD = {}

function CMD.getToken(uid, channel)
    assert(uid)
    assert(channel)

    local ok, cfg = pcall(cluster.call, "master", ".configmgr", 'get', "agoraurl")
    if nil == webclient then
        webclient = skynet.newservice("webreq")
    end

    local API_ONLINE  = cfg.v .. string.format( "?uid=%s&channel=%s", uid, channel)
    LOG_DEBUG('agora getToken API_ONLINE:', API_ONLINE)
    local ok, body = skynet.call(webclient, "lua", "request", API_ONLINE, nil, nil, false, 3000) --get 请求
    LOG_DEBUG(" agora getToken result:", ok, body)
    if not ok then
        assert("get token from agora server error!")
    end

    local ok,data = pcall(jsondecode, body)

    return PDEFINE.RET.SUCCESS, data.token
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
        skynet.register(".agora")
    end
)