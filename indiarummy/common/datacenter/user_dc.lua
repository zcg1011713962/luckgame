local entity = require "Entity"

local user_dc = {}
local EntUser

function user_dc.init()
	EntUser = entity.Get("d_user")
	EntUser:Init()
end

function user_dc.load(uid)
	if not uid then return end
	EntUser:Load(uid)
end

function user_dc.unload(uid)
	if not uid then return end
	EntUser:UnLoad(uid)
end

function user_dc.getvalue(uid, key)
	return EntUser:GetValue(uid, key)
end

function user_dc.setvalue(uid, key, value)
	return EntUser:SetValue(uid, key, value)
end

function user_dc.add(row)
	return EntUser:Add(row)
end

function user_dc.delete(row)
	return EntUser:Delete(row)
end

function user_dc.user_addvalue(uid, key, n)
	local value = EntUser:GetValue(uid, key)
	value = value or 0 --新增的属性，可能老用户没有值
	value = value + n
	local ret = EntUser:SetValue(uid, key, value)
	return ret, value
end

function user_dc.get(uid)
	return EntUser:Get(uid)
end

function user_dc.check_player_exists(uid)
	if not EntUser:GetValue(uid, "uid") then
		return false
	end
	return true
end

function user_dc.set_data_change(uid)
	return EntUser:set_data_change(uid)
end

function user_dc.update(record, nosync)
	return EntUser:Update(record, nosync)
end

return user_dc