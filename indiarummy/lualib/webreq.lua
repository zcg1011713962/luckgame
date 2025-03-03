--- webclient. (skynet服务).
--
-- @module webclient
-- @usage local webclient = skynet.newservice("webclient")

local skynet = require "skynet"
local webclientlib = require "webclient"
local webclient = webclientlib.create()
local requests = nil

local function respond(request)
    LOG_DEBUG("respond")
    if not request.response then
        return
    end
    LOG_DEBUG("respond2")
    local content, errmsg = webclient:get_respond(request.req)
    if not errmsg then
	LOG_DEBUG("respond3")
        request.response(true, true, content)
    else
	LOG_DEBUG("respond4 errmsg:",errmsg)
        local info = webclient:get_info(request.req)
        if info.response_code == 200 and not info.content_save_failed then
	    LOG_DEBUG("respond5")
            request.response(true, true, content, errmsg)
        else
            LOG_DEBUG("respond6")
            request.response(true, false, errmsg, info)
        end
    end
end

local function query()
    LOG_DEBUG("query")
    while next(requests) do
        local finish_key = webclient:query()
        if finish_key then
            local request = requests[finish_key];
            assert(request)

            xpcall(respond, function() skynet.error(debug.traceback()) end, request)

            webclient:remove_request(request.req)
            requests[finish_key] = nil
        else
            skynet.sleep(1)
        end
    end
    requests = nil
end

--- 请求某个url
-- @function request
-- @string url url
-- @tab[opt] get get的参数
-- @param[opt] post post参数，table or string类型
-- @bool[opt] no_reply 使用skynet.call则要设置为nil或false，使用skynet.send则要设置为true
-- @return bool 请求是否成功
-- @return string 当成功时，返回内容，当失败时，返回出错原因
-- @usage skynet.call(webclient, "lua", "request", "http://www.dpull.com")
-- @usage skynet.send(webclient, "lua", "request", "http://www.dpull.com", nil, nil, true)
local function request(url, get, post, no_reply, timeout)
    LOG_DEBUG("url:",url,"get:",get,"post:",post,"no_reply:",no_reply)

    if get then
	LOG_DEBUG("if get then")
        local i = 0
        for k, v in pairs(get) do
            k = webclient:url_encoding(k)
            --v = webclient:url_encoding(v)

            url = string.format("%s%s%s=%s", url, i == 0 and "?" or "&", k, v)
            i = i + 1
        end
    end

    if post and type(post) == "table" then
	LOG_DEBUG("post and type(post) == table")
        local data = {}
        for k,v in pairs(post) do
            k = webclient:url_encoding(k)
            v = webclient:url_encoding(v)

            table.insert(data, string.format("%s=%s", k, v))
        end
        post = table.concat(data , "&")
    end

    if timeout == nil then
        timeout = 5000
    end
    LOG_DEBUG("timeout",timeout)

    local req, key = webclient:request(url, post, nil, timeout)
    if not req then
        LOG_DEBUG("not req")
        return skynet.ret()
    end
    assert(key)
    LOG_DEBUG("key",key)

    local response = nil
    if not no_reply then
        response = skynet.response()
    end

    if requests == nil then
        requests = {}
        skynet.fork(query)
    end

    requests[key] = {
        url = url,
        req = req,
        response = response,
    }
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, ...)
        assert(command == "request")
        request(...)
    end)
end)
