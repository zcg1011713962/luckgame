local skynet = require "skynet"
require "skynet.manager"
local httpc = require "http.httpc"
local cjson = require "cjson"
cjson.encode_sparse_array(true)
cjson.encode_empty_table_as_object(false)
local snax = require "snax"
local cluster = require "cluster"
local webclient

-- sms 短信通道

local CMD = {}

function CMD.sendmsg(uid, phone)
    assert(uid)
    assert(phone)

    -- local API_URL = 'http://sms.xxxxx.com/sms.php'

    local ok, cfg = pcall(cluster.call, "master", ".configmgr", 'get', "sms_url")
    if nil == cfg or "" == cfg.v then
        return
    end
    local API_URL = cfg.v
    local url = string.format(API_URL .. '?phone=%s&uid=%s', phone, uid)

    if nil == webclient then
        webclient = skynet.newservice("webreq")
    end
    local ok, body = skynet.call(webclient, "lua", "request", url, nil, nil, false)
    LOG_DEBUG(" sms.sendmsg结果:", ok, body)
    

    if not ok then
        local sql = string.format("insert into d_log_sms(uid,phone,remark,create_time,status) values(%d,'%s','%s',%d,%d)",uid,mysqlEscapeString(phone),'请求接口失败:'..mysqlEscapeString(body), os.time(),0)
        do_mysql_queue(sql)
        assert("sms.sendmsg结果 server error!")
    else
        local sql = string.format("insert into d_log_sms(uid,phone,remark,create_time) values(%d,'%s','%s',%d)",uid,mysqlEscapeString(phone),'请求接口成功:'..mysqlEscapeString(body), os.time())
        do_mysql_queue(sql)
    end

    local retobj = {
        spcode = 0,
        msg    = '',
        voice  = 0
    }
    local ok, result = pcall(jsondecode, body)
    if ok and nil ~= result["code"] then
        local retcode = tonumber(result['code'] or 0)
        if retcode == 0 then --请求接口成功(自己封装的)
            local smsapicode = result['data']['code'] --第3方短信接口
            if smsapicode ~= nil and (smsapicode == 200 or smsapicode == '0000') then
                local smscode = result['smscode']
                if smscode then --文字短信才有，语音短信没有
                    local cacheKey = 'code:' .. phone
                    do_redis({"setex", cacheKey, smscode, 1800}) --缓存30分钟
                end
                local voice = math.floor(result['data']['voice'] or 0) --是否是语音验证码, 默认否
                retobj.voice = voice
            end
        else
            retobj.spcode = retcode
            retobj.msg    = result['msg']
        end
    else
        retobj.spcode = PDEFINE_ERRCODE.ERROR.SMS_GET_FAILED
    end
    return PDEFINE.RET.SUCCESS, retobj
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
        skynet.register(".sms")
    end
)
