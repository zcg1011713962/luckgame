local skynet = require "skynet"
require "skynet.manager"
local snax = require "snax"

local webclient
local versionData = {}
local CMD = {}
--[[
    专门读取热更新文件地址version.manifest
    redis key:version_manifest_url
]]

local function initWebClient()
    if nil == webclient then
        webclient = skynet.newservice("webreq")
    end
end

-- 读取文件
local function loadVersionFile()
    local url = do_redis({"get", "version_manifest_url"})
    if not url or url =="" then
        LOG_ERROR("未配置version文件路径")
        return
    end
    initWebClient()

    local ok, body, resp
    ok, body = skynet.call(webclient,"lua", "request", url, nil, nil, false, 10000) --10s超时
    if not ok then
        LOG_ERROR("读取 version文件出错 url:" , url)
        return
    end
    ok, resp = pcall(jsondecode,body)
    if not ok then
        LOG_ERROR("解析version文件出错:" , url, body)
        return 
    end
    versionData = resp
end


-- 重新读取version.manifest到内存
function CMD.reload()
    return loadVersionFile()
end

function CMD.getData()
    if table.empty(versionData) then
        loadVersionFile()
    end
    return versionData
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
        loadVersionFile()
        skynet.register(".versionfile")
    end
)
