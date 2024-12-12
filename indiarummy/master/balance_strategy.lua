--
-- Author: mz
-- Date: 2019-02-16
-- 登录路由策略管理

local balance_strategy = {}

--以后可以改成配置文件注入策略
--@param userinfo 玩家信息
--[[
     local userinfo = {}
    userinfo.uid = uid
    userinfo.version = version
    userinfo.unionid = auth_info.unionid
    userinfo.playercoin = auth_info.playercoin
    userinfo.access_token = auth_info.access_token
    userinfo.language = language
    userinfo.client_uuid = client_uuid
    userinfo.account = auth_info.account
    userinfo.ip = addr
    userinfo.vip = auth_info.vip
]]
--@param servertable 服务器列表
--[[
{
    [1]={
        name=xx,
        status=xx,
        tag=xx,
        freshtime=xx，
        serverinfo = {}
    }
}
]]
--@return server nil表示没有找到合适的服务器
--[[
server={
    name=xx,
    status=xx,
    tag=xx,
    freshtime=xx，
    serverinfo = {}
}
--根据玩家是否是VIP,区分不同的服(VIP服/普通玩家服)
]]
function balance_strategy.balance(userinfo, servertable)
    --servertable 区分是否vip
    local vip = userinfo.vip
    local viptable = {}
    local normaltable = {}
    for k, server in pairs(servertable) do
        for k,usertype in pairs(server.serverinfo.usertypetable) do
            if usertype == PDEFINE.USER_TYPE.vip then
                table.insert(viptable, server)
            elseif usertype == PDEFINE.USER_TYPE.normal then
                table.insert(normaltable, server)
            end
        end
    end

    --没有服务器可以用的
    if #viptable == 0 and #normaltable == 0 then
        LOG_DEBUG("balance_strategy balance server is empty:")
        return nil
    end

    local btable = normaltable
    if vip == 1 and #viptable > 0 then --如果存在VIP服且玩家是VIP,就选用VIP服
        btable = viptable
    end

    local min = -1
    local minserver --当前在线人数最少的服
    for i, server in pairs(btable) do
        if min == -1 or server.serverinfo.onlinenum < min then
            min = server.serverinfo.onlinenum
            minserver = server
        end
    end
    -- LOG_DEBUG("balance_strategy balance minserver:", minserver)

    return minserver
end    

return balance_strategy