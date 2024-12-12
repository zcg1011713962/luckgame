--[[
    一定时间段内，只允许N个ip登录游戏
]]

local TimeQuantum = 24*60*60  --限制时间段，24小时

local iplimit = {}

iplimit.ip_map = {}

--@param uuid: 客户端唯一id
--@param ip: ip地址
function iplimit.add(uuid, ip)
    local ip_map = iplimit.ip_map
    if not ip_map[ip] then
        ip_map[ip] = {}
    end
    local ts = os.time()
    local list = ip_map[ip]
    for _, item in ipairs(list) do
        if item.uuid == uuid then
            item.ts = ts
            return
        end
    end
    table.insert(list, {
        uuid = uuid,
        ts = ts
    })
end

--@param uuid: 客户端唯一id
--@param ip: ip地址
--@param count: 限制同ip的个数
--@return: 是否限制登录
function iplimit.check(uuid, ip, count)
    local list = iplimit.ip_map[ip]
    if not list then
        return true
    end
    if TimeQuantum > 0 then
        local ts = os.time()
        for i = #list, 1, -1 do
            if list[i].ts + TimeQuantum < ts then
                table.remove(list, i)
            end
        end
    end
    for _, item in ipairs(list) do
        if item.uuid == uuid then
            return true
        end
    end
    if #list < count then return true end
    return false, #list
end

return iplimit
