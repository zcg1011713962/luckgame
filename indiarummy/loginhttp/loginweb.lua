local skynet = require "skynet"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local api_service = require "api_service"
local urllib = require "http.url"
local cluster = require "cluster"
local crypt = require "crypt"
local table = table
local string = string
local cjson = require "cjson"

local mode = ...

local respheader = {}
respheader["Content-Type"] = "text/html;Charset=utf-8"

if mode == "agent" then

    local function response(id, ...)
        LOG_DEBUG(" datas:", ...)
        local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
        if not ok then
            skynet.error(string.format("fd = %d, %s", id, err))
        end
    end

    -- 处理是否要热更新
    local function processHotupdate(id, query, body, clientIP)
        local os = query.os or 'android'
        local appVer = query.appVer or ''
        if body.os then --post里的优先级高
            os = body.os
        end
        if body.appVer then
            appVer = body.appVer
        end
        os = string.lower(os)
        local lan = query.lan or 'zh'
        local isWhiteIP = false
        local msg = ''
        local resp = {['state'] = 0, ['msg']='', ['la'] = 'buhao'}

        --维护内容
        local cfgjson = do_redis({"get", "{bigbang}:system:setting"})
        local ok, cfg = pcall(jsondecode, cfgjson)
        if ok then
            msg = (lan == 'zh') and cfg.game_swl_content or cfg.game_swl_contenten
            if cfg.game_swl_ip and string.find(cfg.game_swl_ip, clientIP) then
                isWhiteIP = true
            end
        end
        resp.msg = msg

        local cache = do_redis({ "hgetall", "reviewinfo"}) --玩家缓存的转盘领取数据
        cache = make_pairs_table(cache)

        -- 维护状态
        local state = tonumber(cache['maintain'] or 0)
        if state == 1 then
            if not isWhiteIP then
                resp.state = 1
            end
        else
            resp.msg = ''
        end

        resp.la = "hao" --热更
        local reviewVersion = 0
        if os=='ios' then
            reviewVersion = cache['ver_ios'] or ""
        else
            reviewVersion = cache['ver_android'] or ""
        end
        if appVer == reviewVersion then
            resp.la = "buhao" --提审版本不要热更
        end

        return resp
    end

    --请求数据
    local function processRequest(id, query, body, addr)
        LOG_DEBUG("query：", query, ' body:', body)
        --[[
            {"c":1,"user":"Guest2951","passwd":"Guest2951","app":12,"v":"1.6.0.0","t":1,"accessToken":"","platform":"Windows","token":"47c3e77028784d06c514b1b37e80e7a6","bwss":0,"LoginExData":2,"language":2,"client_uuid":"1650800141688.392","c_ts":1650800311758,"c_idx":97,"uid":9860}
        ]]
        local ok, token = pcall(jsondecode, body['req'])
        local result = {
            ['code'] = 200,
            ['version'] = {},
        }
        local ok, versionData =  pcall(skynet.call, ".versionfile", "lua", "getData")
        if ok then
            result['version'] = versionData
        end

        local hotupdateResp = processHotupdate(id, query, body, addr)
        table.merge(result, hotupdateResp)

        local os = body['os']
        if os ~= 'web' then
            local close = do_redis({"get", "close_httplogin"})
            if close then
                return response(id, PDEFINE.RET.SUCCESS, cjson.encode(result), respheader)
            end
        end
        
        result['data'] = {}

        -------------------------- auth -----------------------------
        local ok, errorCode, userinfo = pcall(cluster.call, "login", ".login_master", "auth_handler", token, addr)
        if not ok then
            errorCode = PDEFINE.RET.ERROR.REGISTER_FAIL
        end
        if errorCode ~= PDEFINE.RET.SUCCESS then
            return response(id, errorCode, result, respheader)
        end
        --------------------- 处理登录 -----------------------------

        local bwss = token.bwss
        local secret = crypt.base64encode(token.user)
        local clientapp = token.app or 0 
        local ok, errorCode, subid, servernetinfo, servername = pcall(cluster.call, "login", ".login_master", "login_handler", secret, bwss, userinfo, clientapp) 
        local access_token = userinfo.access_token
        if not ok then
            errorCode = PDEFINE.RET.ERROR.REGISTER_FAIL
        end
        if errorCode ~= PDEFINE.RET.SUCCESS then
            return response(id, errorCode, result, respheader)
        end

        LOG_INFO("loginhttp_handler subid:", subid, "servernetinfo:", servernetinfo, "server.name:", servername)
        result['data'] = {
            ['server'] = servername,
            ['net'] = servernetinfo,
            ['subid'] = subid,
            ['token'] = access_token,
            ['uid'] = userinfo.uid,
            ['unionid'] = "",
        }
        return response(id, PDEFINE.RET.SUCCESS, cjson.encode(result), respheader)
    end

    --重新加载version文件
    local function processReloadVersion(id, query)
        pcall(skynet.call, ".versionfile", "lua", "reload")
        return response(id, PDEFINE.RET.SUCCESS, cjson.encode({['code']=PDEFINE.RET.SUCCESS}), respheader)
    end

    skynet.start(function()
        skynet.dispatch("lua", function (_, _, id, addr)
            socket.start(id)
            local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 65536)
            if code then
                if code ~= 200 then
                    response(id, code)
                else
                    local path, query = urllib.parse(url)
                    LOG_DEBUG("path:", path, ' query:', query, ' body:', body)
                    if query then
                        local q = urllib.parse_query(query)
                        if q.mod and q.mod == "reload" then
                            processReloadVersion(id, q)
                        else
                            local body_data = urllib.parse_query(body)
                            local idx = string.find(body, '&req={')
                            local reqjson = string.sub(body, idx+5, string.len(body))
                            body_data['req'] = reqjson --防止json串中有&符号导致json解析错乱
                            processRequest(id, q, body_data, addr)
                        end
                    else
                        local result = {
                            ['version'] = {},
                            ['data'] = {}
                        }
                        response(id, PDEFINE.RET.ERROR.ACCOUNT_ERROR, result, respheader)
                    end
                end
            else
                if url == sockethelper.socket_error then
                    skynet.error("socket closed")
                else
                    skynet.error(url)
                end
            end
            socket.close(id)
        end)
    end)
else

    skynet.start(function()
        local agent = {}
        for i= 1, 20 do
            agent[i] = skynet.newservice(SERVICE_NAME, "agent")
        end
        local balance = 1
        local port = skynet.getenv("web_port")
        local id = socket.listen("0.0.0.0", port)
        skynet.error("Listen web port " .. port)
        socket.start(id , function(id, addr)
            -- skynet.error(string.format("%s connected, pass it to agent :%08x", addr, agent[balance]))
            skynet.send(agent[balance], "lua", id, addr)
            balance = balance + 1
            if balance > #agent then
                balance = 1
            end
        end)
    end)

end