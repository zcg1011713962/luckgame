--[[
    Double
]]

local config = {
    minbet = 1,
    maxbet = 1000,
}

local gamelogic = {}

function gamelogic.create(gameid)
end

function gamelogic.initDeskInfo(deskInfo)
    deskInfo.config = config
end

function gamelogic.getResult()
end

function gamelogic.tryGetRestrictiveResult()
end

---@param deskInfo any
---@param msg any
---@param delegate StandaloneAgentDelegate
function gamelogic.start(deskInfo, msg, delegate)
end

return gamelogic