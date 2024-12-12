local entity = require "Entity"

local mail_attach_dc = {}
local EntMailAttach

function mail_attach_dc.init()
    EntMailAttach = entity.Get("d_mail")
    EntMailAttach:Init()
end

function mail_attach_dc.load(uid)
    if not uid then return end
    EntMailAttach:Load(uid)
end

function mail_attach_dc.unload(uid)
    if not uid then return end
    EntMailAttach:UnLoad(uid)
end

function mail_attach_dc.getvalue(uid, id, key)
    return EntMailAttach:GetValue(uid, id, key)
end

function mail_attach_dc.setvalue(uid, id, key, value)
    return EntMailAttach:SetValue(uid, id, key, value)
end

function mail_attach_dc.add(row)
    return EntMailAttach:Add(row)
end

function mail_attach_dc.delete(row)
    return EntMailAttach:Delete(row)
end

function mail_attach_dc.get(uid)
    return EntMailAttach:Get(uid)
end

function mail_attach_dc.get_list(uid,key,value,flag)
    return EntMailAttach:GetMultiByField(uid, key, value, flag)
end

function mail_attach_dc.get_info(uid, mailid)
    return EntMailAttach:Get(uid, mailid)
end


return mail_attach_dc