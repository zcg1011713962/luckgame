require "UserSingleEntity"

local EntityType = class(UserSingleEntity)

function EntityType:ctor()
    self.tbname = "d_pass"
end

return EntityType.new()
