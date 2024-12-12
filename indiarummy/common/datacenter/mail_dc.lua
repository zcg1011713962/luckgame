local entity = require "Entity"

local mail_dc = {}
local EntMail

function mail_dc.init()
    EntMail = entity.Get("d_mail")
    EntMail:Init()
end

function mail_dc.load(uid)
    if not uid then return end
    EntMail:Load(uid)
end

function mail_dc.unload(uid)
    if not uid then return end
    EntMail:UnLoad(uid)
end

function mail_dc.getvalue(uid, id, key)
    return EntMail:GetValue(uid, id, key)
end

function mail_dc.setvalue(uid, id, key, value)
    return EntMail:SetValue(uid, id, key, value)
end

function mail_dc.add(row)
    return EntMail:Add(row)
end

function mail_dc.delete(row)
    return EntMail:Delete(row)
end

function mail_dc.get(uid)
    return EntMail:Get(uid)
end

function mail_dc.get_list(uid,key,value,flag)
    return EntMail:GetMultiByField(uid, key, value, flag)
end

function mail_dc.get_list_by_uid(uid)
    return EntMail:GetMulti(uid)
end

function mail_dc.get_info(uid, mailid)
    return EntMail:Get(uid, mailid)
end


return mail_dc