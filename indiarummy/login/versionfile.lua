local skynet = require "skynet"
local cluster = require "cluster"
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
    LOG_ERROR("function loadVersionFile()1")
    local ok, res = pcall(cluster.call, "master", ".configmgr", "get", "version_manifest_url")
    LOG_ERROR("function loadVersionFile()2")
    if not ok then
        return true
    end
    local url = res.v
    local cacheUrl = do_redis({"get", "version_manifest_url"})
    if nil ~= cacheUrl and cacheUrl ~= "" then
        url = cacheUrl
    end
    LOG_DEBUG('version_manifest_url:', url)
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
    LOG_DEBUG('version data:', resp)
    versionData = resp
end


-- 重新读取version.manifest到内存
function CMD.reload()
    return loadVersionFile()
end

function CMD.getVersion()
    -- return '200.200.200.200'
    LOG_DEBUG('CMD.getVersion()')
    if table.empty(versionData) then
        loadVersionFile()
    end
    if versionData.version ~= nil then
        return versionData.version
    end
    return nil
end

function CMD.getData()
    if table.empty(versionData) then
        loadVersionFile()
    end
    return versionData
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = CMD[cmd]
		skynet.retpack(f(...))
	end)
    skynet.register(".versionfile")
    CMD.reload()
end)
