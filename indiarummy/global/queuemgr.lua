local queue = require "skynet.queue"

local MAX_QUEUE_SIZE = 10000

--队列集合 key,queue
local queuetable = {}

local queuemgr = {}

--获取一个已经设置的队列
--@param uid 玩家id
--@return 队列
function queuemgr.getQueue(uid)
    local key = math.floor(uid) % MAX_QUEUE_SIZE
    local q = queuetable[key]
    if not q then
        q = queue()
        queuetable[key] = q
    end
    return q
end

return queuemgr