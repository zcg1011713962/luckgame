--[[
    玩家基类
]]

local skynet    = require "skynet"
local cluster   = require "cluster"
local player_tool = require "base.player_tool"
local sysmarquee = require "sysmarquee"
local utils = require "cashslots.common.utils"

---@class BetUser
local BetUser = class()

-- 创建新的玩家对象
function BetUser:ctor(playerInfo, deskInfo)
    self.uid=playerInfo.uid
    self.playername=playerInfo.playername
    self.usericon=playerInfo.usericon
    self.coin=playerInfo.coin or 0
    self.diamond=playerInfo.diamond or 0
    self.level = playerInfo.level or 1
    self.avatarframe = playerInfo.avatarframe or PDEFINE.SKIN.DEFAULT.AVATAR.img
    self.levelexp = playerInfo.levelexp or 0
    self.leaguelevel = 1
    self.leagueexp = 0
    self.svip = playerInfo.svip or 0
    self.rp = playerInfo.rp or 0
    self.istest = playerInfo.istest
    self.offline           = 0 -- 是否掉线 1是 0否
    self.isexit            = 0 -- 是否已退出
    self.leavetime = (os.time() + math.random(600, 7200)) --离开时刻,机器人有效

    self.race_id           = 0  -- 是否是赛事局
    self.race_type         = 0  -- 计分类型
    self.coin              = playerInfo.coin  -- 携带金币数
    self.wincoin      = 0  --输赢金币(真实)
    self.betcoin      = 0  --押注金币
    self.seatid       = 0  --座位号
    self.round = nil       -- 玩家此轮游戏信息
end

-- 初始化用户身上的特殊字段
function BetUser:init(seatid, deskInfo, cluster_info)
    -- 特殊判断下排位等级
    if self.leaguelevel <= 0 then
        self.leaguelevel = 1
    end
    
    -- 设置用户连接信息
    if cluster_info then
        self.cluster_info = cluster_info
    end
    -- 设置座位号
    self.seatid = seatid

    return nil
end

-- 更改用户金币
function BetUser:changeCoin(type, coin, deskInfo)
    if coin == 0 then return true end
    local ret = true
    if self.cluster_info then
        LOG_INFO(self.uid.." => changeCoin type:", type, ' coin:', coin)
        ret = player_tool.calUserCoin(self.uid, coin, deskInfo.issue, type, deskInfo)
    end
    if ret then
        self.coin = self.coin + coin
    end
    return ret
end

-- 播放走马灯
function BetUser:notifyLobby(coin, gameid, delaySec)
    delaySec = delaySec or 15
    sysmarquee.onGameWin(self.playername, gameid, coin, delaySec)
end

function BetUser:sendMsg(retobj)
    if self.cluster_info and self.isexit == 0 then
        pcall(cluster.send, self.cluster_info.server, self.cluster_info.address, "sendToClient", retobj)
    end
end

-- 更新某个用户信息
function BetUser:syncUserInfo(playerInfo)
    self.svip = playerInfo.svip or 0
    self.svipexp = playerInfo.svipexp or 0
    self.rp = playerInfo.rp or 0
    self.level = playerInfo.level or 1
    self.levelexp = playerInfo.levelexp or 0
    self.coin = playerInfo.coin or 0
    self.diamond = playerInfo.diamond or 0
    self.playername = playerInfo.playername
    self.usericon     = playerInfo.usericon
    self.charm = playerInfo.charm or 0
    self.avatarframe = playerInfo.avatarframe
end

--config.Chips 筹码配置
--config.Places 区域配置
--config.Multiples 倍数配置
function BetUser:autoBet(gamelogic, config)
    if self.cluster_info then return end
    if gamelogic.autoBet then
        return gamelogic.autoBet(self)
    end

    --位置概率
    local placeProb = {}
    for i, mult in ipairs(config.Multiples) do
        table.insert(placeProb, {weight=math.floor(10000/mult+0.5)})
    end
    --筹码概率
    local chipProb = {}
    for i = 1, #config.Chips do
        local val = #config.Chips-i+1
        table.insert(chipProb, {weight = val * val})
    end

    --最多可下注区域
    local maxplacecnt = math.min(5, config.PlaceCount - 1)
    --下注区域个数
    local placecnt = math.random(1, maxplacecnt)

    local msg =   {
        c =   37,
        uid = self.uid,
    }
    msg.chips = {}
    for i = 1, config.PlaceCount do
        local chipcnt = {}
        table.fill(chipcnt, 0, #config.Chips)
        table.insert(msg.chips, chipcnt)
    end

    local betcoin = 0
    for i = 1, placecnt do
        local placeidx = utils.randByWeight(placeProb)
        local cnt = math.random(2, 5)
        for j = 1, cnt do
            local chipidx = utils.randByWeight(chipProb)
            msg.chips[placeidx][chipidx] = msg.chips[placeidx][chipidx] + 1
        end
    end
    if self.coin < betcoin then
        self.coin = self.coin + betcoin
        if math.random()<0.1 then
            self.coin = self.coin + math.random(20, 200)*10
        end
    end
    gamelogic.bet(msg)
end

return BetUser