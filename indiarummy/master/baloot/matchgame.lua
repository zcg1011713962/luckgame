local skynet = require "skynet"
local cluster = require "cluster"
local cjson = require "cjson"

--匹配
MatchGame = class()

function MatchGame:ctor(delegate, id, stype, single)
    -- self.delegate = delegate      -- 代理接口
    self.id = id                   -- 匹配id
    self.single = single           --单人或多人匹配
    self.stype = stype             --类型
    self.wait_time = 10            -- 玩家等待时间
    self.wait_users = {}           -- 等待中玩家
    self.desk_list = {}            -- 房间表
    self.page_users = {}           -- 用户停留的页面
end

--TODO 关闭app或断线要清理掉

-- 加入
function MatchGame:join()
end

-- 取消
function MatchGame:cancel(uid)
    for idx, uid in ipairs(self.wait_users) do
        if uid == user_id then
            table.remove(self.wait_users, idx)
            break
        end
    end
end

function MatchGame:genAssignObj(stype, entry)
    local matchid = do_redis({ "incr", "baloot_assign"})
    if nil == entry then
        entry = 0
    end
    local item = {
        id = matchid,
        bet = entry,
        type = stype,
        users = {}
    }
    return item
end

function MatchGame:getAgent(uid)
    return skynet.call(".userCenter", "lua", "getAgent", uid)
end

function MatchGame:sendMatchUsersMsg(users, uid, matchid)
    local agent = self:getAgent(uid)
    local ok, info = pcall(cluster.call, agent.server, agent.address, "getPlayerInfo")
    table.insert(users, {
        ['uid'] = uid,
        ['playername'] = info.playername,
        ['usericon'] = info.usericon,
        ['agent'] = agent,
    })
    for _, muser in pairs(users) do --匹配1个通知1次
        local retobj = {}
        retobj.c = PDEFINE.NOTIFY.BALOOT_MATH_RESULT
        retobj.code = PDEFINE.RET.SUCCESS
        retobj.users = users
        retobj.matchid= matchid
        pcall(cluster.call, muser.agent.server, muser.agent.address, "sendToClient", cjson.encode(retobj))
    end
end

-- 分配
function MatchGame:assign()
    for entry, sess_wait_users in pairs(self.wait_users) do
        local tryTimes = 0
        local count = #sess_wait_users
        LOG_DEBUG(" entry" .. entry .. " 的等待人数: " .. count)
        while count > 0 do
            if count >= 4 then
                local assignObj = self:genAssignObj('match', entry)
                assignUsers[assignObj.id] = assignObj
                local users = {}
                for i=1,4 do
                    local uid = removeWaitUsers(entry, 1)
                    creating_users[uid] = 1 --正在进入房间
                    table.insert(assignObj.users, uid)
                    self:sendMatchUsersMsg(users, uid, assignObj.id)
                end
                entryDesk(users, entry, nil, assignObj.id)
            end
            tryTimes = tryTimes + 1
            if tryTimes >= 4 then
                if count < 4 then
                    local assignObj = self:genAssignObj('match', entry)
                    assignUsers[assignObj.id] = assignObj
                    local users = {}
                    for i=1, count do
                        local uid = removeWaitUsers(entry, 1)
                        creating_users[uid] = 1 --正在进入房间
                        table.insert(assignObj.users, uid)
                        self:sendMatchUsersMsg(users, uid, assignObj.id)
                    end
                    entryDesk(users, entry, nil, assignObj.id)
                end
                break
            end
            skynet.sleep(50)
            count = #sess_wait_users
        end
    end
end