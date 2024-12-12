require "UserIndexEntity"

local EntityType = class(UserIndexEntity)

function EntityType:ctor()
    self.tbname = "d_mail"
end

return EntityType.new()