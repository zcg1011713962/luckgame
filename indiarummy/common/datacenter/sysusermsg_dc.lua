local entity = require "Entity"

local sysusermsg_dc = {}
local EntMail

function sysusermsg_dc.init()
    EntMail = entity.Get("d_sys_user_msg")
    EntMail:Init()
end

function sysusermsg_dc.load(uid)
    if not uid then return end
    EntMail:Load(uid)
end

function sysusermsg_dc.unload(uid)
    if not uid then return end
    EntMail:UnLoad(uid)
end

function sysusermsg_dc.getvalue(uid, id, key)
    return EntMail:GetValue(uid, id, key)
end

function sysusermsg_dc.setvalue(uid, id, key, value)
    return EntMail:SetValue(uid, id, key, value)
end

function sysusermsg_dc.add(row)
    return EntMail:Add(row)
end

function sysusermsg_dc.delete(row)
    return EntMail:Delete(row)
end

function sysusermsg_dc.get(uid)
    return EntMail:Get(uid)
end

function sysusermsg_dc.get_list(uid,key,value,flag)
    return EntMail:GetMultiByField(uid, key, value, flag)
end

function sysusermsg_dc.get_info(uid, mailid)
    return EntMail:Get(uid, mailid)
end


return sysusermsg_dc