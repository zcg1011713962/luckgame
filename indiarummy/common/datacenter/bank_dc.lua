local entity = require "Entity"
local bank_dc = {}
local Entuser_bank

---
--- 玩家银行功能
---

function bank_dc.init()
    Entuser_bank = entity.Get("d_bank")
    Entuser_bank:Init()
end

function bank_dc.load(uid)
    if not uid then return end
    Entuser_bank:Load(uid)
end

function bank_dc.unload(uid)
    if not uid then return end
    --这里不能卸载, 玩家退出过程中，立马登录，会导致重新add一条记录，刷掉内存数据，导致bank表错乱
    return
    -- Entuser_bank:UnLoad(uid)
end

function bank_dc.getvalue(uid, key)
    return Entuser_bank:GetValue(uid, key)
end

function bank_dc.setvalue(uid, key, value)
    return Entuser_bank:SetValue(uid, key, value)
end

function bank_dc.add(row)
    return Entuser_bank:Add(row)
end

function bank_dc.delete(row)
    return Entuser_bank:Delete(row)
end

function bank_dc.get(uid)
    return Entuser_bank:Get(uid)
end


return bank_dc