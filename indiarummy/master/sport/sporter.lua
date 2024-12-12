local skynet = require "skynet"
local cluster = require "cluster"
local cjson = require "cjson"
local sportutil = require "sport.sportutil"

-- 参赛者
Sporter = class()

function Sporter:ctor(sport_id, sport_tid, user_id, nick, icon)
    self.sport_id = sport_id     -- 赛场ID
    self.sport_tid = sport_tid  -- 赛场模版ID
    self.user_id = user_id     -- 玩家ID
    self.nick = nick            -- 玩家昵称
    self.icon = icon            -- 玩家头像
    self.score = 0              -- 积分
    self.ranking = 0            -- 名次
    self.games = 0              -- 局数
    self.desk_id = 0             -- 当前桌子ID
    self.is_inserted = false    -- 是否已插入db
end

function Sporter:insertIntoDb()
    local sql = string.format("INSERT INTO d_sport_user(sport_id, tid, user_id, score, ranking, create_time) VALUES('%d', '%d', '%d', '%d', '%d', '%d')",
        self.sport_id, self.sport_tid, self.user_id, self.score, self.ranking, os.time())
    sportutil.mysql_exec(sql)
    self.is_inserted = true
end

function Sporter:deleteFromDb()
    if not self.is_inserted then return end
    local sql = string.format("DELETE FROM d_sport_user WHERE sport_id = '%d' AND user_id = '%d'",
        self.sport_id, self.user_id)
    sportutil.mysql_exec_async(sql)
end

function Sporter:saveToDb()
    -- 延迟插入
    if not self.is_inserted then
       self:insertIntoDb()
       return
    end
    -- 更新分数和排名
    local sql = string.format("UPDATE d_sport_user SET score='%d', ranking='%d' WHERE sport_id = '%d' AND user_id = '%d'",
        self.score, self.ranking, self.sport_id, self.user_id)
    sportutil.mysql_exec_async(sql)
end

--结算
function Sporter:settle(score)
    self.games = self.games + 1
    self.score = self.score + score
    self:saveToDb()
end

--排名
function Sporter:setRanking(ranking)
    self.ranking = ranking
    self:saveToDb()
end

function Sporter:isOut()
    return self.ranking < 0
end

function Sporter:getAgent()
    return skynet.call(".userCenter", "lua", "getAgent", self.user_id)
end

function Sporter:sendMsg(msg)
    local cluster_info = self:getAgent()
    if cluster_info then
        return pcall(cluster.call, cluster_info.server, cluster_info.address, "sendToClient", cjson.encode(msg))
    end
    return false
end

--记录奖励金币发放记录
function Sporter:addSendCoinLog(addCoin)
    local cluster_info = self:getAgent()
    if cluster_info then
        return pcall(cluster.call, cluster_info.server, cluster_info.address, "clusterModuleCall", "player", "addSendCoinLog", self.user_id, addCoin, "sport")
    end
    return false
end
