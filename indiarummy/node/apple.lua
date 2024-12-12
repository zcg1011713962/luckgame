local skynet = require "skynet"
require "skynet.manager"
local cjson = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)

--苹果支付服务端验证服务

local webclient
local CMD = {}

local API_SANDBOX = 'https://sandbox.itunes.apple.com/verifyReceipt' --沙盒环境
local API_ONLINE  = 'https://buy.itunes.apple.com/verifyReceipt' --正式环境
local IS_APPLE_SANDBOX = 21007

function CMD.verify(receipt, orderid)
    assert(receipt)

    local post = {}
    post["receipt-data"] = receipt
    LOG_DEBUG("post apple data------------>", post)
    local data = cjson.encode(post)

    --获取微信配置信息
    if nil == webclient then
        webclient = skynet.newservice("webreq")
    end
    local ok, body = skynet.call(webclient, "lua", "request", API_ONLINE, nil, data, false, 10000)
    LOG_DEBUG("Verify apple return:", body)
    if not ok then
        assert("Verify token from apple server error!")
    end
    local _ok, resp = pcall(jsondecode, body)

    --测试服的单子，要去测试服验证
    if nil~=resp.status and math.floor(resp.status) == IS_APPLE_SANDBOX then
        local sql = string.format( "update s_shop_order set istest=1 where orderid='%s'", orderid)
        do_mysql_queue(sql)
        local ok, body2 = skynet.call(webclient, "lua", "request", API_SANDBOX, nil, data, false, 10000)
        if not ok then
            assert("Verify token from apple server error!")
        end
        _ok, resp = pcall(jsondecode, body2)
    end

    return PDEFINE.RET.SUCCESS, cjson.encode(resp)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".apple")
end)