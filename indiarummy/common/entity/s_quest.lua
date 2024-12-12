require "CommonEntity"

local EntityType = class(CommonEntity)

function EntityType:ctor()
    self.tbname = "s_quest"
end

return EntityType.new()