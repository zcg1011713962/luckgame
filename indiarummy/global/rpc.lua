local skynet = require "skynet"
require "skynet.manager"
local httpc = require "http.httpc"
local cjson   = require "cjson"

local headerKeyRoute = "_r_"
local headerKeyCode  = "_c_"

local rpc = {}
httpc.timeout = 200 -- 2s超时

function rpc.call(host, url, route, req)
    local header = {
        [headerKeyRoute] = route
    }
    local recvheader = {
    }
    local statuscode, body = httpc.request("POST", host, url, recvheader, header, cjson.encode(req))
    if statuscode ~= 200 then
        return PDEFINE.RET.ERROR.CALL_FAIL
    end
    local codeStr = recvheader[headerKeyCode]
    if codeStr and #codeStr > 0 then
        local code = math.floor(codeStr)
        if code ~= 0 then
            return PDEFINE.RET.ERROR_API.CLUB + code
        end
    end
    return PDEFINE.RET.SUCCESS, cjson.decode(body)
end

return rpc