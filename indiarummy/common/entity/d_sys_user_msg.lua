require "UserIndexEntity"

local EntityType = class(UserIndexEntity)

function EntityType:ctor()
    self.tbname = "d_sys_user_msg"
end

return EntityType.new()