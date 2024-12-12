local entity = require "Entity"
local cjson   = require "cjson"

local game_task_dc = {}
local EntGameTask

function game_task_dc.init()
	EntGameTask = entity.Get("d_game_task")
	EntGameTask:Init()
end

function game_task_dc.load(uid)
	if not uid then return end
	EntGameTask:Load(uid)
end

function game_task_dc.unload(uid)
	if not uid then return end
	EntGameTask:UnLoad(uid)
end

function game_task_dc.getvalue(uid, key)
	return EntGameTask:GetValue(uid, key)
end

function game_task_dc.setvalue(uid, key, value)
	return EntGameTask:SetValue(uid, key, value)
end

function game_task_dc.add(row)
	return EntGameTask:Add(row)
end

function game_task_dc.delete(row)
	return EntGameTask:Delete(row)
end

function game_task_dc.user_addvalue(uid, key, n)
	local value = EntGameTask:GetValue(uid, key)
	value = value + n
	local ret = EntGameTask:SetValue(uid, key, value)
	return ret, value
end

function game_task_dc.get(uid)
	return EntGameTask:Get(uid)
end

function game_task_dc.set_data_change(uid)
	return EntGameTask:set_data_change(uid)
end

local function newGameTask(uid)
    return {
        uid = uid,
        data = cjson.encode({}),
		gameover = 0,
    }
end

function game_task_dc.gameover(uid)
	return EntGameTask:SetValue(uid, "gameover", 1)
end

function game_task_dc.getdata(uid)
    local ent = EntGameTask:Get(uid)
    if not ent then
		LOG_DEBUG("for debug getdata (nil)")
        ent = newGameTask(uid)
        EntGameTask:Add(ent)
    end
    return cjson.decode(ent.data)
end

function game_task_dc.setdata(uid, data)
	return EntGameTask:SetValue(uid, "data", cjson.encode(data))
end

return game_task_dc
