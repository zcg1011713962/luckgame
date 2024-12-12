

-- ai user

data.code = 200
local send_data = cjson.encode(data)
pcall(cluster.call, user.cluster_info.server, user.cluster_info.address, "sendToClient", send_data)

return function(uid, coin, desk_cmd)
    
    local user = {}

    local function recv(data)
        local c = data.c -- 协议
        if user.cmd and user.cmd[c] then
            user.cmd[c](data)
        end
    end

    function user.send(self, data)
        recv(data)
    end

    function user.ai_send(data)
        desk_cmd.dispace()
    end

    -- 加入到房间里面
    function user.join(max)
        desk_cmd.aijoin(user, max)
    end

    return user
end


