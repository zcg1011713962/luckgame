require "UserMultiEntity"

local EntityType = class(UserSingleEntity)

function EntityType:ctor()
    self.tbname = "d_mail_attach"
end

return EntityType.new()