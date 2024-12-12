local skynet = require "skynet"
local cluster = require "cluster"
local cjson = require "cjson"

-- 参赛者
BalootUser = class()

function BalootUser:ctor(sport_id, sport_tid, user_id, nick, icon)
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