--[[
    gamelogic模板
    1, gamelogic为纯逻辑，不保存玩家游戏数据
    2, 游戏数据保存在deskInfo里，从接口传进来
    3，gamelogic需要实现create和initDeskInfo方法
    4，前端请求通过CMD接口处理
]]


local gamelogic = {}

--创建游戏房间时调用
function gamelogic.create(gameid)
end

--玩家进入房间时调用
function gamelogic.initDeskInfo(deskInfo)
end

---@param deskInfo any
---@param msg any
---@param delegate StandaloneAgentDelegate
function gamelogic.start(deskInfo, msg, delegate)
end

return gamelogic