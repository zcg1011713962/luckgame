require "UserIndexEntity"
---
--- 银行
---

local EntityType = class(UserSingleEntity)

function EntityType:ctor()
    self.tbname = "d_bank"
end

return EntityType.new()