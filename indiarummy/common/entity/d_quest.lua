require "UserIndexEntity"

local EntityType = class(UserIndexEntity)

function EntityType:ctor()
    self.tbname = "d_quest"
end

return EntityType.new()