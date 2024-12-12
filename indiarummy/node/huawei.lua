local skynet = require "skynet"
require "skynet.manager"
local cjson = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local snax = require "snax"
local cluster = require "cluster"
local queue     = require "skynet.queue"
local cs = queue()
local api_service = require "api_service"

-- huawei 支付服务端验证服务

local CMD = {}

local function requestHuaWei(purchaseToken, productId)
    return cs(function()
        local ok, body = api_service.callAPIMod("validateHuaweiOrder", purchaseToken, productId)
        LOG_INFO(" huawei.ipayVerify CMD.verify huawei验证结果:", ok, body)
        if not ok then
            assert("Verify token from huawei server error!")
        end
        return ok, body['data']
    end)
end

function CMD.verify(purchaseToken, productId)
    assert(purchaseToken)
    assert(productId)
    local ok, body = requestHuaWei(purchaseToken, productId)
    LOG_DEBUG("huawei pay verify result: ", ok, body)
    local jsonok, jsonobj = pcall(jsondecode, body)
    if not ok or math.floor(jsonobj["responseCode"]) ~= 0 then
        LOG_ERROR("Verify body from huawei failed.", ok, body)
        LOG_ERROR("verify responseCode: ", jsonobj["responseCode"])
        return PDEFINE.RET.ERROR.ORDER_PAID_VERIFY_RECEIPT_FAILED
    end
    local purchaseTokenDataHuawei = jsonobj.purchaseTokenData
    local purchaseData
    jsonok, purchaseData = pcall(jsondecode, purchaseTokenDataHuawei)
    if jsonok then
        if purchaseData.purchaseType and purchaseData.purchaseType == 0 then --普通付费不会有这个字段
            --测试订单
            local orderid = purchaseData.developerPayload
            if orderid then
                local sql = string.format( "update s_shop_order set istest=1 where orderid='%s'", orderid)
                do_mysql_queue(sql)
            end
        end
        return PDEFINE.RET.SUCCESS, purchaseTokenDataHuawei
    end
    return PDEFINE.RET.ERROR.ORDER_PAID_VERIFY_RECEIPT_FAILED
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, cmd, ...)
        local f = CMD[cmd]
        skynet.retpack(f(...))
    end)
    skynet.register(".huawei")
end)