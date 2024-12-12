local entity = require "Entity"

local pass_dc = {}
local EntPass

function pass_dc.init()
    EntPass = entity.Get("d_pass")
    EntPass:Init()
end

function pass_dc.load(uid)
    if not uid then return end
    EntPass:Load(uid)
end

function pass_dc.unload(uid)
    if not uid then return end
    EntPass:UnLoad(uid)
end

function pass_dc.getvalue(uid, key)
    return EntPass:GetValue(uid, key)
end

function pass_dc.setvalue(uid, key, value)
    return EntPass:SetValue(uid, key, value)
end

function pass_dc.add(row)
    return EntPass:Add(row)
end

function pass_dc.delete(row)
    return EntPass:Delete(row)
end

function pass_dc.get(uid)
    return EntPass:Get(uid)
end

return pass_dc